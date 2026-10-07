#!/usr/bin/env perl
use v5.24;
use strict;
use English;
use warnings;

## the production runtime [ bin/Protocol-7 : use utf8 + Encode ] loads the ##
## bytes pragma transitively ; keep it so compiled modules resolve it.     ##
use bytes;

## auth-keypair v2 + link-upgrade binding END TO END [ in-process ] [       ##
## 2026-10-06, data/md/design/AUTH-LINK-BINDING.md + HOST-ROOT-DELEGATION   ##
## .md ] : the REAL server modules and the REAL client modules talk to each ##
## other over a socketpair : fork, the CHILD drives auth.auth_select [      ##
## incl. the REQUIRED host-root delegation 4th field ], plugin.auth.        ##
## auth-keypair, base.handler.auth, base.handler.command [ the binding gate ##
## ], cube.cmd.link-upgrade, protocol.protocol-7.link-upgrade.init,         ##
## base.handler.link-upgrade and base.session.register_authenticated with a ##
## tiny read -> handler -> write loop ; the PARENT runs the REAL            ##
## auth.client.auth-keypair.authenticate + protocol.protocol-7.link-        ##
## upgrade.handshake against it [ incl. the REAL trust.statement \          ##
## trust.verify \ trust.fingerprint delegation check + the host-root pin    ##
## store ]. covers : success + pin file, a pinned re-run, a different       ##
## host-root, a rotated S under the same host-root, an unknown client key,  ##
## an eph-key tamper relay, a replayed auth line, the pending command gate  ##
## and a link-complete without client sig. no zenka started, restarted or   ##
## reloaded, no network, no real key dirs [ throwaway keys + tempdirs ].    ##

use File::Spec;
use Cwd        qw| abs_path |;
use FindBin    qw| $RealBin |;
use File::Temp qw| tempdir |;
use Socket     qw| AF_UNIX SOCK_STREAM PF_UNSPEC |;
use IO::Socket;
use IO::Select;
use POSIX qw| WNOHANG |;

BEGIN {
    my $up_dir    = File::Spec->updir;
    my $root_path = abs_path(
        File::Spec->rel2abs(
            File::Spec->catdir( $RealBin, $up_dir, $up_dir )
        )
    );
    my $local_lib_path
        = File::Spec->catdir( $root_path, qw| data lib-path pm | );
    die "not found : $local_lib_path" if !-d $local_lib_path;
    unshift( @INC, $local_lib_path );
    $main::root_path = $root_path;
}

use AMOS7::Protocol::P7Syntax qw| p7_syntax__translate |;
use Crypt::Misc;
use Crypt::Ed25519;
use Crypt::Curve25519;

use constant TRUE  => 5;
use constant FALSE => 0;

our %code;
our %data;
our %keys;

my $fail_count = 0;
my $pass_count = 0;

sub ok {
    my ( $cond, $label ) = @ARG;
    if ($cond) { $pass_count++; say "  ok   : $label"; return }
    $fail_count++;
    say "  FAIL : $label";
    return;
}

## $prefix : source prepended inside the compiled sub [ the .cmd. header ] ##
sub compile_module {
    my ( $module_name, $prefix ) = @ARG;
    $prefix //= '';
    my $src_path
        = File::Spec->catfile( $main::root_path, 'src', $module_name );
    open( my $fh, '<', $src_path ) or die "cannot read $src_path : $!";
    my $src = join( '', <$fh> );
    close($fh);
    my $translated = p7_syntax__translate($src);
    my $cref
        = eval "sub {\n$prefix\n# line 1 \"$module_name\"\n$translated\n}";
    die "compile failed for $module_name : $EVAL_ERROR"
        if not defined $cref;
    $code{$module_name} = $cref;
    return $cref;
}

my $cmd_header = 'my $call = {}; if ( ref( $ARG[0] ) eq q|HASH| ) { $call '
    . '= $ARG[0] } else { $call->{q|args|} = $ARG[0] }';

## fake event : ->w->data \ stop \ start \ cancel \ is_active ##
package FakeWatcher {
    sub new       { my ( $c, $id ) = @_; return bless { id => $id }, $c }
    sub data      { return $_[0]{id} }
    sub stop      {return}
    sub start     {return}
    sub cancel    {return}
    sub is_active { return 1 }
    sub w         { return $_[0] }
}

package FakeTimeoutWatcher {
    sub new     { return bless { timeout => 17 }, shift }
    sub timeout { $_[0]{timeout} = $_[1]; return }
}

package main;

sub event_for { return FakeWatcher->new(shift) }

## authenticate calls plain max() ; delegation_file calls plain catfile() ##
sub main::max     { my $m = shift; $m = $_ > $m ? $_ : $m for @_; return $m }
sub main::catfile { return File::Spec->catfile(@ARG) }

#######################################################################
## stubs : only what is NOT under test                               ##
#######################################################################

my @logged;
$code{'base.logs'} = sub { push @logged, [@ARG]; return };
$code{'base.log'}  = sub { push @logged, [@ARG]; return };
my @complaints;
$code{'base.s_warn'}
    = sub { push @complaints, sprintf( shift, @ARG ); return };
$code{'base.caller'}         = sub { return '[ test ]' };
$code{'base.ntime'}          = sub { return 'NTIME' };
$code{'base.str.eval_error'} = sub { return $EVAL_ERROR };
$code{'base.clean_hashref'}  = sub {return};

## the client config lookups authenticate requires ##
$code{'base.is_defined_recursive'} = sub { return TRUE };
$code{'base.s_read'}               = sub {
    my ( $sock, $buf_ref ) = @ARG;
    $$buf_ref = readline($sock);
    return length( $$buf_ref // '' );
};
$code{'base.net.send_to_socket'} = sub {
    my ( $sock, $str ) = @ARG;
    syswrite( $sock, $str );
    return TRUE;
};

## pin store behind a stubbed home ##
my $home = tempdir(
    'p7-auth-link-binding-e2e-XXXXXXXX',
    TMPDIR  => 1,
    CLEANUP => 1
);
$code{'base.get_homedir'} = sub { return $home };

## randomness for the real select reply + the real state 2 init ##
$code{'base.prng.bytes'} = sub { return Crypt::Misc::random_bytes(shift) };
my @anum = ( 'a' .. 'z', 'A' .. 'Z', 0 .. 9 );
$code{'base.prng.chars-anum'} = sub {
    join '',
        map { $anum[ ord( Crypt::Misc::random_bytes(1) ) % @anum ] }
        1 .. ( shift // 8 );
};

## code + data lookups ##
$code{'base.code.exists'}        = sub { return exists $code{ $ARG[0] } };
$code{'base.code.call_optional'} = sub {
    my $name = shift;
    return unless exists $code{$name};
    return $code{$name}->(@ARG);
};
$code{'base.reverse-sort'} = sub {
    return sort { $b cmp $a } @ARG;
};
$code{'auth.auth_list'}    = sub { return "auth-keypair\n" };
$code{'base.list_matches'} = sub {
    my ( $list, $pattern ) = @ARG;
    return scalar grep {m{$pattern}} @$list;
};
$code{'base.has_access'}              = sub { return TRUE };
$code{'base.gen_id'}                  = sub { return 1 };
$code{'base.handler.hooks.has_hooks'} = sub { return FALSE };
$code{'base.sprint_t'}                = sub { return '' };
$code{'base.logt'}                    = sub {return};
$code{'base.format_error'}            = sub { return ( $ARG[0], undef ) };
$code{'base.parser.ellipse_center'}   = sub { return $ARG[0] };

## server identity for auth.auth_select : a per-child key name ##
my $server_key_name = qw| srv.base |;
$code{'crypt.C25519.key_vars'} = sub {
    return { 'key_name' => $server_key_name };
};

## the backend key dir plumbing : a throwaway tree, one per scenario ##
my $srv_root_key_dir = "$home/keys/root";
$code{'crypt.C25519.root_key_dir'} = sub { return $srv_root_key_dir };

## client identity signing : the explicit base key name is recorded ; the ##
## pair itself is a throwaway in-memory stand-in for the real key files [ ##
## never touches ~/.n/ ]                                                  ##
my ( $client_sign_pub, $client_sign_priv );
my @client_signed;
$code{'crypt.C25519.sign_data'} = sub {
    my ( $msg_ref, $key_name ) = @ARG;
    push @client_signed, [ $msg_ref->$*, $key_name ];
    return Crypt::Ed25519::sign( $msg_ref->$*, $client_sign_pub,
        $client_sign_priv );
};
$code{'crypt.C25519.key_exists'} = sub { die 'not expected : key_exists' };
$code{'crypt.C25519.load_keypair'}
    = sub { die 'not expected : load_keypair' };
$code{'crypt.C25519.gen_keys'}   = sub { die 'not expected : gen_keys' };
$code{'crypt.C25519.write_keys'} = sub { die 'not expected : write_keys' };

## the AUTH_TRUE reply parser [ records what the server answered ] ##
my @auth_replies;
$code{'auth.client.zenka.process_auth_reply'} = sub {
    my $line = readline( $ARG[0] );
    push @auth_replies, defined $line ? $line : '<eof>';
    return ( defined $line && $line eq "AUTH_TRUE =)\n" )
        ? $ARG[0]
        : undef;
};

## TOFU validator : never on the wire here [ unix link ] ##
$code{'plugin.auth.auth-keypair.validate-incoming-tofu'} = sub { return 0 };

## session helpers ##
$code{'base.session.user'} = sub {
    return $data{'session'}{ $ARG[0] }{'user'};
};
my $gate_stats = 0;
$code{'base.session.calc_cmd_stats'} = sub { $gate_stats++; return };

## TRUE \ FALSE \ WAIT reply framing [ template J4UEBUA : "%s%s %s\n" ] ##
$code{'base.stream.emit'} = sub {
    my $arg  = shift;
    my $sid  = $arg->{'sid'};
    my $mode = uc( $arg->{'mode'} // '' );
    my $msg  = $arg->{'data'} // '';
    $msg = $$msg if ref $msg eq qw| SCALAR |;
    $msg =~ s{\n}{\\n}go if $mode =~ m{^(?:TRUE|FALSE|WAIT)$};
    $data{'session'}{$sid}{'buffer'}{'output'} .= sprintf "%s %s\n", $mode,
        $msg;
    return length $msg;
};

## the server child writes its session output straight to its socket ##
my $server_sock;
my $flushed_complete_ok = 0;
$code{'base.handler.write'} = sub {
    my $id = shift;
    return unless defined $server_sock;
    my $out = $data{'session'}{$id}{'buffer'}{'output'};
    return unless length $out;
    $flushed_complete_ok = 1 if $out =~ m{link-complete-ok};
    syswrite( $server_sock, $out );
    $data{'session'}{$id}{'buffer'}{'output'} = '';
    return;
};

#######################################################################
## real modules : server + client                                    ##
#######################################################################

## the real regex cache ##
$code{'base.regex'} = undef;
compile_module('base.regex');
$data{'regex'}{'base'} = $code{'base.regex'}->();

compile_module('auth.binding.message');
my $message = $code{'auth.binding.message'};

compile_module('auth.client.server_pin.check');
compile_module('auth.client.auth-keypair.authenticate');
my $authenticate = $code{'auth.client.auth-keypair.authenticate'};
compile_module('protocol.protocol-7.link-upgrade.handshake');
my $handshake = $code{'protocol.protocol-7.link-upgrade.handshake'};

compile_module('auth.auth_select');
compile_module('plugin.auth.auth-keypair');
compile_module('base.session.register_authenticated');
compile_module('base.handler.auth');
compile_module('base.session.init_state');    ## real : handlers set by it ##
compile_module('base.handler.command');
compile_module( 'cube.cmd.link-upgrade', $cmd_header );
compile_module('protocol.protocol-7.link-upgrade.init');
compile_module('base.handler.link-upgrade');
compile_module('trust.statement');
compile_module('trust.verify');
compile_module('trust.fingerprint');
compile_module('crypt.C25519.delegation_file');

## client + server share the connect \ regex config data ##
$data{'protocol'}{'protocol-7'}{'connect'} = {
    'banner'          => "BANNER\n",
    'timeout'         => "T\n",
    'protocol_error'  => "PE\n",
    'auth_method_wrn' => "W\n",
    'auth_method_err' => "E\n",
    'select-method'   => "select %s\n",
};
$data{'protocol'}{'protocol-7'}{'regex'}{'protocol-version'}
    = qr|^BANNER\n$|;
$data{'auth'}{'supported_methods'} = { 'auth-keypair' => 1 };
$data{'base'}{'session'}{'uname'}
    = { 'client' => ':unauth:', 'server' => ':server:' };
$data{'base'}{'perlmod'}{'loaded'} = {};

## fixed-seed throwaway keys [ the spec test vector seeds ]  C \ S from   ##
## AUTH-LINK-BINDING, X another client \ server key, H \ H2 two host-root ##
## keys [ HOST-ROOT-DELEGATION ]                                          ##
my ( $c_pub, $c_priv )   = Crypt::Ed25519::generate_keypair( "\x01" x 32 );
my ( $s_pub, $s_priv )   = Crypt::Ed25519::generate_keypair( "\x02" x 32 );
my ( $x_pub, $x_priv )   = Crypt::Ed25519::generate_keypair( "\x03" x 32 );
my ( $h_pub, $h_priv )   = Crypt::Ed25519::generate_keypair( "\x04" x 32 );
my ( $h2_pub, $h2_priv ) = Crypt::Ed25519::generate_keypair( "\x05" x 32 );
$client_sign_pub  = $c_pub;
$client_sign_priv = $c_priv;

my $b32         = sub { Crypt::Misc::encode_b32r(shift) };
my $session_pub = "\x22" x 32;
$keys{'C25519'}{'cli-session'} = { 'public' => $session_pub };

my $pin_path = "$home/.n/remote-keys/servers/test-host_4242.public";

## the pin is the host-root fingerprint [ 77 chars ], not S ##
my $host_root_fp = $code{'trust.fingerprint'}->($h_pub);

## a fresh delegation statement for the given issuer \ subject, built and ##
## signed with the REAL trust.statement module [ valid around now ]       ##
sub delegation_wire {
    my ( $issuer_pub, $issuer_priv, $subject_pub, $expired ) = @ARG;
    my ( $not_before, $not_after )
        = $expired
        ? ( time - 2000, time - 1000 )
        : ( time - 100, time + 30 * 86400 );
    my $statement = $code{'trust.statement'}->(
        qw| build |,
        {   qw| issuer_pub |  => $issuer_pub,
            qw| subject_pub | => $subject_pub,
            qw| name |        => 'test-host.cube',
            qw| not_before |  => $not_before,
            qw| not_after |   => $not_after,
            qw| scope |       => '',
        }
    );
    my $sig = Crypt::Ed25519::sign( $statement, $issuer_pub, $issuer_priv );
    return $code{'trust.statement'}->( qw| wire |, $statement, $sig );
}

sub read_pin {
    open( my $pin_fh, '<', $pin_path ) or return '';
    my $pinned = readline($pin_fh) // '';
    close($pin_fh);
    return $pinned;
}

#######################################################################
## the server child : a tiny loop around the REAL handlers           ##
#######################################################################

my @child_pids;

sub server_child_main {
    my ( $sock, $opt ) = @ARG;

    $SIG{ALRM} = sub { exit 124 };
    alarm(30);
    $server_sock     = $sock;
    $server_key_name = $opt->{'server_key'} // qw| srv.base |;

    ## the host-root delegation of the announced S : written into the ##
    ## throwaway key dir as <name>.dlg, read fresh by the REAL        ##
    ## auth.auth_select on every select                               ##
    $srv_root_key_dir = sprintf qw| %s/keys-%s/root |,
        $home, $opt->{'tag'} // qw| srv |;
    my $dlg_issuer = $opt->{'dlg_issuer'} // qw| host-root |;
    my ( $issuer_pub, $issuer_priv )
        = $dlg_issuer eq qw| other-root |
        ? ( $h2_pub, $h2_priv )
        : ( $h_pub, $h_priv );
    my $announced_pub = $server_key_name eq qw| evil.base | ? $x_pub : $s_pub;
    my $dlg_wire      = delegation_wire(
        $issuer_pub, $issuer_priv, $announced_pub,
        $opt->{'dlg_expired'} // 0
    );
    my $dlg_path = $code{'crypt.C25519.delegation_file'}->($server_key_name);
    ( my $key_dir = $srv_root_key_dir ) =~ s|/root\z||;
    mkdir( $key_dir, 0700 ) if !-d $key_dir;
    open( my $dlg_fh, '>', $dlg_path ) or die "dlg write : $OS_ERROR";
    print {$dlg_fh} $dlg_wire, "\n";
    close($dlg_fh);

    ## server side key material ##
    my $authorized_pub = $opt->{'authorized_pub'} // $c_pub;
    $keys{'authorized-remote'}{'test-user'} = {
        'public'     => $authorized_pub,
        'public_b32' => $b32->($authorized_pub),
    };
    $keys{'C25519'}{qw| srv.base |}
        = { 'public' => $s_pub, 'private' => $s_priv };
    $keys{'C25519'}{qw| evil.base |}
        = { 'public' => $x_pub, 'private' => $x_priv };

    ## command registry + protocol states [ the production shape : 'input' ##
    ## \ 'output' handlers per state, 'init' at the top level ]            ##
    $data{'base'}{'cmd'}{qw| link-upgrade |} = qw| cube.cmd.link-upgrade |;
    $data{'protocol'}{'protocol-7'}{'state'} = {
        0 => { 'input' => { 'handler' => qw| base.handler.auth | } },
        1 => { 'input' => { 'handler' => qw| base.handler.command | } },
        2 => {
            'input'     => { 'handler' => qw| base.handler.link-upgrade | },
            'init'      => qw| protocol.protocol-7.link-upgrade.init |,
            'read-mode' => qw| linewise |,
        },
        3 => {
            'input'     => { 'handler' => qw| base.handler.command | },
            'read-mode' => qw| linewise |,

            ## the real state 3 init arms encrypted framing + event        ##
            ## watchers : outside this plaintext wire test [ the wire ends ##
            ## at link-complete-ok ]                                       ##
            'init' => sub { return TRUE },
        },
    };

    my $id = 4242;
    $data{'session'}{$id} = {
        'handle'          => $sock,
        'protocol'        => qw| protocol-7 |,
        'mode'            => qw| server |,
        'user'            => qw| :unauth: |,
        'last-bytes-read' => 1,
        'buffer'          => { 'input'   => '', 'output' => '' },
        'input'           => { 'handler' => qw| base.handler.auth | },
        'auth'            => {},
        'watcher'         => { 'input_handler' => FakeTimeoutWatcher->new },
    };
    $data{'handle'}{$sock}
        = { 'link' => qw| unix |, 'mode' => qw| input | };
    $data{'user'}{':unauth:'}{'session'}{$id} = {};

    syswrite( $sock, "BANNER\n" );

    my @recv;
    while (1) {
        my $chunk = '';
        my $read  = sysread( $sock, $chunk, 8192 );
        last if not defined $read or $read == 0;
        my $session = $data{'session'}{$id};
        $session->{'last-bytes-read'} = $read;
        $session->{'buffer'}{'input'} .= $chunk;
        push @recv, $session->{'buffer'}{'input'} =~ m{^(.*\n)}gm;
        my $handler_name = $session->{'input'}{'handler'} // '';
        my $rc           = eval { $code{$handler_name}->( event_for($id) ) };
        $rc //= 2;
        ## flush whatever the handler produced ##
        if ( length $session->{'buffer'}{'output'} ) {
            my $out = $session->{'buffer'}{'output'};
            $flushed_complete_ok = 1 if $out =~ m{link-complete-ok};
            syswrite( $sock, $out );
            $session->{'buffer'}{'output'} = '';
        }
        last if $rc == 2;
    }

    ## results for the parent ##
    my $session = $data{'session'}{$id};
    open( my $rfh, '>', $opt->{'result_path'} ) or exit 1;
    printf {$rfh} "recv %s",            $_ for @recv;
    printf {$rfh} "link_binding=%s\n",  $session->{'link_binding'}  // '-';
    printf {$rfh} "authenticated=%s\n", $session->{'authenticated'} // '-';
    printf {$rfh} "registered=%d\n",
        exists $data{'user'}{'test-user'}{'session'}{$id} ? 1 : 0;
    printf {$rfh} "nonce_deleted=%d\n",
        (
        ref $session->{'auth'} ne qw| HASH |
            or !exists $session->{'auth'}{'server_nonce'}
        ) ? 1 : 0;
    printf {$rfh} "shared_secret_b32=%s\n",
        defined $session->{'link_dh_shared_secret'}
        ? $b32->( $session->{'link_dh_shared_secret'} )
        : '-';
    printf {$rfh} "nonce_sid=%s\n",
        $session->{'link_nonce_session_id'} // '-';
    printf {$rfh} "link_complete_ok=%d\n", $flushed_complete_ok ? 1 : 0;
    close($rfh);
    exit 0;
}

sub read_results {
    my $path   = shift;
    my %result = ( 'recv' => [] );
    open( my $fh, '<', $path ) or return \%result;
    while ( my $line = <$fh> ) {
        chomp $line;
        if ( $line =~ s{\Arecv }{} ) { push $result{'recv'}->@*, $line }
        else {
            my ( $k, $v ) = split m{=}, $line, 2;
            $result{$k} = $v // '';
        }
    }
    close($fh);
    return \%result;
}

sub run_server {
    my (%opt) = @ARG;
    my ( $ours, $theirs )
        = IO::Socket->socketpair( AF_UNIX, SOCK_STREAM, PF_UNSPEC )
        or die "socketpair : $ERRNO";
    $ours->autoflush(1);
    $theirs->autoflush(1);
    my $pid = fork // die "fork : $ERRNO";
    if ( $pid == 0 ) {
        close($ours);
        server_child_main( $theirs, \%opt );
        exit 0;
    }
    close($theirs);
    push @child_pids, $pid;
    return ( $pid, $ours );
}

sub finish_children {
    my ($sock) = @ARG;
    close($sock) if defined $sock;
    while ( my $pid = shift @child_pids ) { waitpid( $pid, 0 ) }
    return;
}

sub cleanup_end {
    while ( my $pid = shift @child_pids ) {
        kill 'TERM', $pid;
        for ( 1 .. 30 ) {
            my $reaped = waitpid( $pid, WNOHANG );
            last if $reaped == $pid or $reaped == -1;
            select( undef, undef, undef, 0.1 );
        }
    }
    return;
}

$SIG{ALRM} = sub { cleanup_end(); die "test alarm : hung\n" };
$SIG{PIPE} = 'IGNORE';
alarm(120);
END { cleanup_end() }

## run the real client authenticate + handshake against a fresh server ##
sub client_auth_and_bind {
    my ($sock) = @ARG;
    my $ctx = $authenticate->(
        $sock, 'test-user', 'cli-session', 'test-c.base',
        { 'host' => 'test-host', 'port' => 4242 }
    );
    return $ctx if not ref $ctx;
    my @result = $handshake->(
        $sock,
        {   'timeout' => 5,
            'binding' => $ctx,
        }
    );
    return ( $ctx, @result );
}

######################################################################
say ': e2e success : real client <-> real server over a socketpair';

my $result_path = "$home/server-success.txt";
my ( $srv_pid, $sock ) = run_server(
    'result_path' => $result_path,
    'tag'         => 'success'
);
alarm(20);
my ( $ctx, $hs_rc, $hs_data ) = client_auth_and_bind($sock);
alarm(0);
my $clean = 1;
if ( !ref $ctx or !$hs_rc ) {
    $clean = 0;
    ok( 0,
        'success run died or refused : '
            . ( !ref $ctx ? 'authenticate' : $hs_data->{'error'} // '' ) );
}
if ($clean) {
    ok( ref $ctx eq qw| HASH |, 'authenticate : binding context returned' );
    ok( $hs_rc == 1,            'handshake : accepted [ 1 ]' );
    ok( ref $hs_data eq qw| HASH |
            and length( $hs_data->{'shared_secret'} // '' ) == 32,
        'handshake : shared_secret returned [ 32 bytes ]'
    );
    ok( ( $hs_data->{'nonce_sid'} // 0 ) > 0,
        'handshake : ' . 'nonce_sid returned'
    );
    ok( $client_signed[-1][1] eq 'test-c.base',
        'client_bind_sig signed with the explicit base key name' );
}
close($sock);
waitpid( $srv_pid, 0 );
shift @child_pids;

my $R = read_results($result_path);
if ($clean) {
    ok( $R->{'link_binding'} eq qw| done |, 'server : link_binding done' );
    ok( $R->{'authenticated'} eq qw| yes |,
        'server : authenticated yes after binding'
    );
    ok( $R->{'registered'} == 1, 'server : session registered for the user' );
    ok( $R->{'nonce_deleted'} == 1, 'server : single-use nonce deleted' );
    ok( $R->{'link_complete_ok'} == 1,
        'server : link-complete-ok <server_bind_sig> sent' );
    ok( $R->{'shared_secret_b32'} eq $b32->( $hs_data->{'shared_secret'} ),
        'both shared secrets equal [ dh agrees on the wire ]'
    );
    ok( $R->{'nonce_sid'} == $hs_data->{'nonce_sid'},
        'nonce_sid equal on both ends' );
}

say ': pin file';
ok( -f $pin_path,                              'pin file exists' );
ok( ( ( stat $pin_path )[2] & 07777 ) == 0600, 'pin file mode 0600' );
my $pin_is_fp = read_pin() eq $host_root_fp . "\n";
ok( $pin_is_fp,
    'pin file : one 77-char line == the host-root fingerprint' );
ok( length $host_root_fp == 77,
    'host-root fingerprint is 77 chars [ bmw384 b32 ]' );
my ( $pin_mtime, $pin_inode ) = ( stat $pin_path )[ 9, 1 ];

######################################################################
say ': second run against the SAME pinned home';

select( undef, undef, undef, 1.1 );    ## make a pin rewrite detectable ##
$result_path = "$home/server-rerun.txt";
( $srv_pid, $sock )
    = run_server( 'result_path' => $result_path, 'tag' => 'rerun' );
alarm(20);
( $ctx, $hs_rc, $hs_data ) = client_auth_and_bind($sock);
alarm(0);
ok( ref $ctx eq qw| HASH | && $hs_rc == 1,
    'pinned re-run : authenticate + handshake pass'
);
close($sock);
waitpid( $srv_pid, 0 );
shift @child_pids;
my $R2 = read_results($result_path);
ok( $R2->{'authenticated'} eq qw| yes |,
    'pinned re-run : server bound again'
);
my $pin_after_rerun = read_pin() eq $host_root_fp . "\n";
ok( $pin_after_rerun, 'pin unchanged : content' );
ok( ( stat $pin_path )[9] == $pin_mtime
        and ( stat $pin_path )[1] == $pin_inode,
    'pin unchanged : not rewritten'
);

######################################################################
say ': rotated S, delegated by the SAME pinned host-root';

$result_path = "$home/server-rot-s.txt";
( $srv_pid, $sock ) = run_server(
    'result_path' => $result_path,
    'server_key'  => 'evil.base',
    'tag'         => 'rot-s'
);
alarm(20);
my ( $rot_ctx, $rot_rc, $rot_data ) = client_auth_and_bind($sock);
alarm(0);
my $rot_accepted = ref $rot_ctx eq qw| HASH | && $rot_rc == 1;
ok( $rot_accepted,
    'rotated S : accepted under the same host-root [ rotation ]' );
my $rot_s_seen = ref $rot_ctx eq qw| HASH |
    && $rot_ctx->{'server_pub'} eq $x_pub;
ok( $rot_s_seen, 'rotated S : the new S reached the client' );
close($sock);
waitpid( $srv_pid, 0 );
shift @child_pids;
my $Rrot = read_results($result_path);
ok( $Rrot->{'authenticated'} eq qw| yes |, 'rotated S : server bound' );
my $pin_after_rot = read_pin() eq $host_root_fp . "\n";
ok( $pin_after_rot, 'rotated S : pin unchanged [ pinned to host-root ]' );

######################################################################
say ': a DIFFERENT host-root : refused before any auth line';

$result_path = "$home/server-other-root.txt";
( $srv_pid, $sock ) = run_server(
    'result_path' => $result_path,
    'dlg_issuer'  => 'other-root',
    'tag'         => 'other-root'
);
alarm(20);
@auth_replies    = ();
my $signed_count = scalar @client_signed;
my $bad_ctx      = $authenticate->(
    $sock,
    'test-user',
    'cli-session',
    'test-c.base',
    {   'host' => 'test-host',
        'port' => 4242
    }
);
alarm(0);
ok( !defined $bad_ctx,
    'different host-root : client refuses [ no context ]' );
my $nothing_signed
    = scalar(@client_signed) == $signed_count && !@auth_replies;
ok( $nothing_signed,
    'different host-root : nothing signed, no auth phase entered'
);
close($sock);
waitpid( $srv_pid, 0 );
shift @child_pids;
my $R3        = read_results($result_path);
my $seen_auth = grep {m{\Aauth }} $R3->{'recv'}->@*;
ok( !$seen_auth,
    'different host-root : the server child saw no auth line' );
my $pin_after_root = read_pin() eq $host_root_fp . "\n";
ok( $pin_after_root, 'different host-root : pin NOT replaced' );

######################################################################
say ': expired .dlg : the server refuses at select, no nonce drawn';

$result_path = "$home/server-expired.txt";
( $srv_pid, $sock ) = run_server(
    'result_path' => $result_path,
    'dlg_expired' => 1,
    'tag'         => 'expired'
);
alarm(20);
my $exp_banner = readline($sock);
print {$sock} "select auth-keypair\n";
my $exp_reply = readline($sock);
alarm(0);
ok( ( $exp_banner // '' ) eq "BANNER\n", 'expired : banner consumed first' );
my $exp_refused = ( $exp_reply // '' ) eq "FALSE server key not available\n";
ok( $exp_refused, 'expired : select answered FALSE, no nonce drawn' );
close($sock);
waitpid( $srv_pid, 0 );
shift @child_pids;
my $Rexp          = read_results($result_path);
my $exp_auth_seen = grep {m{\Aauth }} $Rexp->{'recv'}->@*;
ok( !$exp_auth_seen, 'expired : client never sent an auth line' );
ok( $Rexp->{'nonce_deleted'} == 1,
    'expired : no nonce stored for the session' );

######################################################################
say ': client signs with a key the server does not hold';

$result_path = "$home/server-unknown-key.txt";
( $srv_pid, $sock )
    = run_server( 'result_path' => $result_path, 'tag' => 'unknown' );
$client_sign_pub  = $x_pub;
$client_sign_priv = $x_priv;
@auth_replies     = ();
alarm(20);
my $x_ctx = $authenticate->(
    $sock,
    'test-user',
    'cli-session',
    'test-c.base',
    {   'host' => 'test-host',
        'port' => 4242
    }
);
alarm(0);
$client_sign_pub  = $c_pub;
$client_sign_priv = $c_priv;
ok( !defined $x_ctx, 'unknown client key : authenticate refused' );
ok( @auth_replies == 1 && $auth_replies[0] =~ m{\AAUTH_ERROR},
    'unknown client key : server answered AUTH_ERROR'
);
close($sock);
waitpid( $srv_pid, 0 );
shift @child_pids;
my $R4 = read_results($result_path);
my $auth_line_seen = grep {m{\Aauth }} $R4->{'recv'}->@*;
my $refused_at_auth = $auth_line_seen && $R4->{'link_binding'} eq '-';
ok( $refused_at_auth,
    'unknown client key : refused at auth, no binding state'
);

######################################################################
say ': mitm : one byte of the server eph pub tampered in transit';

sub relay_child_main {
    my ( $to_client, $to_server ) = @ARG;
    $to_client->autoflush(1);
    $to_server->autoflush(1);
    $SIG{ALRM} = sub { exit 124 };
    alarm(30);
    my $tampered = 0;
    while (1) {
        my $from_server = readline($to_server);
        last if not defined $from_server;
        if ( not $tampered
            and $from_server =~ m{\A(TRUE link-upgrade OK )([A-Z2-7]+)\n\z} )
        {
            my $first = $2;
            my $flip  = substr( $first, 0, 1 ) eq 'A' ? 'B' : 'A';
            $from_server = $1 . $flip . substr( $first, 1 ) . "\n";
            $tampered    = 1;
        }
        print {$to_client} $from_server;
        my $from_client = readline($to_client);
        last if not defined $from_client;
        print {$to_server} $from_client;
    }
    exit 0;
}

my ( $cli_end, $relay_client_end )
    = IO::Socket->socketpair( AF_UNIX, SOCK_STREAM, PF_UNSPEC )
    or die "socketpair : $ERRNO";
my ( $relay_server_end, $srv_end )
    = IO::Socket->socketpair( AF_UNIX, SOCK_STREAM, PF_UNSPEC )
    or die "socketpair : $ERRNO";
$cli_end->autoflush(1);
$relay_client_end->autoflush(1);
$relay_server_end->autoflush(1);
$srv_end->autoflush(1);

$result_path = "$home/server-mitm.txt";
my $relay_pid = fork // die "fork : $ERRNO";
if ( $relay_pid == 0 ) {
    close($cli_end);
    close($srv_end);
    relay_child_main( $relay_client_end, $relay_server_end );
    exit 0;
}
push @child_pids, $relay_pid;
my $srv_pid_mitm = fork // die "fork : $ERRNO";
if ( $srv_pid_mitm == 0 ) {
    close($cli_end);
    close($relay_client_end);
    close($relay_server_end);
    server_child_main( $srv_end,
        { 'result_path' => $result_path, 'tag' => 'mitm' } );
    exit 0;
}
push @child_pids, $srv_pid_mitm;
close($relay_client_end);
close($relay_server_end);
close($srv_end);

alarm(20);
my ( $m_ctx, $m_rc, $m_data ) = client_auth_and_bind($cli_end);
alarm(0);
my $mitm_err = !defined $m_ctx ? 'authenticate' : $m_data->{'error'} // '';
ok( !defined $m_ctx || $m_rc == 0,
    "tampered eph key : client refuses the link [ $mitm_err ]" );
ok( !defined $m_ctx
        || ref $m_data ne qw| HASH |
        || !length( $m_data->{'shared_secret'} // '' ),
    'tampered eph key : client returns no shared secret'
);
close($cli_end);
waitpid( $srv_pid_mitm, 0 );
waitpid( $relay_pid,    0 );
@child_pids = ();
my $R5 = read_results($result_path);
ok( $R5->{'link_binding'} ne qw| done |,
    'tampered eph key : server never reaches done' );
ok( $R5->{'link_complete_ok'} == 0,
    'tampered eph key : no link-complete-ok answered' );
ok( $R5->{'nonce_deleted'} == 1,
    'tampered eph key : nonce dropped with the refused binding' );

######################################################################
say ': replay : the run 1 auth line verbatim in a fresh session';

my ($captured_auth) = grep {m{\Aauth }} $R->{'recv'}->@*;
ok( defined $captured_auth, 'replay : run 1 auth line captured' );
$result_path = "$home/server-replay.txt";
( $srv_pid, $sock )
    = run_server( 'result_path' => $result_path, 'tag' => 'replay' );
alarm(20);
my $banner = readline($sock);
print {$sock} "select auth-keypair\n";
my $select_reply = readline($sock);
print {$sock} $captured_auth, "\n";
my $replay_reply = readline($sock);
my $after_replay = readline($sock);
alarm(0);
my $fresh_nonce_ok = ( $select_reply // '' )
    =~ m|\ATRUE [A-Z2-7]{52} [A-Z2-7]{52} [A-Z2-7]+\n\z|;
ok( ( $banner // '' ) eq "BANNER\n", 'replay : banner consumed first' );
ok( $fresh_nonce_ok,
    'replay : fresh 4-field select reply carries a fresh nonce' );
my $replay_refused = ( $replay_reply // '' ) =~ m{\AAUTH_ERROR};
ok( $replay_refused, 'replay : verbatim auth line refused [ new nonce ]' );
ok( !defined $after_replay,
    'replay : server disconnected after the refusal' );
close($sock);
waitpid( $srv_pid, 0 );
shift @child_pids;

######################################################################
say ': pending gate : anything but link-upgrade after AUTH_TRUE';

$result_path = "$home/server-gate.txt";
( $srv_pid, $sock )
    = run_server( 'result_path' => $result_path, 'tag' => 'gate' );
alarm(20);
my $g_ctx = $authenticate->(
    $sock,
    'test-user',
    'cli-session',
    'test-c.base',
    {   'host' => 'test-host',
        'port' => 4242
    }
);
my $gate_false = '';
my $gate_eof   = '<closed>';

if ( ref $g_ctx ) {
    print {$sock} "list users\n";
    $gate_false = readline($sock) // '';
    $gate_eof   = defined readline($sock) ? '<open>' : '<closed>';
}
alarm(0);
ok( ref $g_ctx, 'gate : authenticate reached AUTH_TRUE' );
ok( $gate_false eq "FALSE link binding pending [ link-upgrade only ]\n",
    'gate : other command answered FALSE' );
ok( $gate_eof eq '<closed>', 'gate : server disconnected' );
close($sock);
waitpid( $srv_pid, 0 );
shift @child_pids;
my $R7 = read_results($result_path);
my $stayed_pending = $R7->{'link_binding'} eq qw| pending |
    && $R7->{'authenticated'} eq qw| pending |;
ok( $stayed_pending,
    'gate : session stayed pending, never authenticated'
);

######################################################################
say ': link-complete without the client sig';

$result_path = "$home/server-nosig.txt";
( $srv_pid, $sock )
    = run_server( 'result_path' => $result_path, 'tag' => 'nosig' );
alarm(20);
my $n_ctx = $authenticate->(
    $sock,
    'test-user',
    'cli-session',
    'test-c.base',
    {   'host' => 'test-host',
        'port' => 4242
    }
);
my $nosig_disconnect = 0;

if ( ref $n_ctx ) {
    print {$sock} "link-upgrade\n";
    my $offer = readline($sock) // '';
    my $eph   = Crypt::Curve25519::curve25519_public_key(
        Crypt::Misc::random_bytes(32) );
    print {$sock} sprintf "link-pub-key %s\n", $b32->($eph);
    my $size_ack = readline($sock) // '';
    print {$sock} "link-confirm-encoding none\n";
    my $enc_ack = readline($sock) // '';
    print {$sock} "link-complete 7777\n";
    my $done_line = readline($sock);
    my $offer_ok  = $offer =~ m{\ATRUE link-upgrade OK};
    $nosig_disconnect = 1
        if $offer_ok
        and $size_ack eq "SIZE 0\n"
        and $enc_ack eq "encoding-confirmed\n"
        and !defined $done_line;
}
alarm(0);
ok( ref $n_ctx,        'no sig : authenticate reached AUTH_TRUE' );
ok( $nosig_disconnect, 'no sig : disconnect, no link-complete-ok' );
close($sock);
waitpid( $srv_pid, 0 );
shift @child_pids;
my $R8 = read_results($result_path);
ok( $R8->{'nonce_deleted'} == 1,         'no sig : nonce gone' );
ok( $R8->{'link_binding'} ne qw| done |, 'no sig : binding never done' );
ok( $R8->{'registered'} == 0, 'no sig : never registered for the user' );

alarm(0);

say '';
say "passed : $pass_count  failed : $fail_count";
exit( $fail_count ? 1 : 0 );

#,,.,,,..,.,.,.,,,...,.,,,.,.,.,,,.,,,,,.,.,.,..,,...,...,,.,,.,.,..,,.,.,.,.,
#UD4JBBN7VYL7TM5ZOB53Q7BUUYMK4TX7BZRUEYJQHGQUOBGU4RGXH7A4IMSOZBN5AKJNO7OJDQIX4
#\\\|SGS7Z6X26TJLSONBF7422UYLL6VTPVIIB3BSFZQ7IMKBEFAW4TD \ / AMOS7 \ YOURUM ::
#\[7]CKNUNWBQELK2PUMHFM5CDFAYBZT2MXXFCAO3PYQ5BDWETM3BMECA 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
