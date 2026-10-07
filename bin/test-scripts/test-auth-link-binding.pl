#!/usr/bin/env perl
use v5.24;
use strict;
use English;
use warnings;

## the production runtime [ bin/Protocol-7 : use utf8 + Encode ] loads the ##
## bytes pragma transitively ; keep it so compiled modules resolve it.     ##
use bytes;

## auth-keypair + link-upgrade mutual binding [ 2026-10-06, data/md/design/ ##
## AUTH-LINK-BINDING.md ] compiles the real modules and drives them with    ##
## stubs : the spec test vector [ auth.binding.message ], the server plugin ##
## [ v2 only ], base.handler.auth [ pending, not registered ], the state 1  ##
## gate [ base.handler.command ], base.handler.link-upgrade [ client \      ##
## server bind sigs ], send.local \ cfg_bool visibility and the client pin  ##
## + select-reply order [ auth.client.auth-keypair.authenticate ]. keys are ##
## throwaway fixed-seed pairs, the pin store a File::Temp dir behind a      ##
## stubbed base.get_homedir. no zenka started, restarted or reloaded, no    ##
## network, no real key dirs touched.                                       ##

use File::Spec;
use Cwd        qw| abs_path |;
use FindBin    qw| $RealBin |;
use File::Temp qw| tempdir |;
use Socket     qw| AF_UNIX SOCK_STREAM PF_UNSPEC |;
use IO::Socket;

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

## $prefix : source prepended inside the compiled sub [ the .cmd. header ]  ##
## mirrored from bin/Protocol-7 [ use open :encoding(UTF-8), File::stat ] : ##
## a bare list-context stat or a sysread on a default handle fails here too ##
my $runtime_pragmas
    = q{no bytes; use File::stat; use open qw| :encoding(UTF-8) |;};

sub compile_module {
    my ( $module_name, $prefix ) = @ARG;
    $prefix //= '';
    my $src_path
        = File::Spec->catfile( $main::root_path, 'src', $module_name );
    open( my $fh, '<', $src_path ) or die "cannot read $src_path : $!";
    my $src = join( '', <$fh> );
    close($fh);
    my $translated = p7_syntax__translate($src);
    ## the runtime : File::stat object stat + :utf8 default open layer ##
    my $cref
        = eval "$runtime_pragmas sub {\n$prefix\n# "
        . "line 1 \"$module_name\"\n$translated\n}";
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

## generic stubs ##
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

sub logged_level0 {
    my $pattern = shift;
    return scalar grep {
                defined $ARG->[0]
            and $ARG->[0] eq '0'
            and do {    ## the rendered line [ format + arguments ] ##
            no warnings;
            sprintf( $ARG->[1] // '', @{$ARG}[ 2 .. $ARG->$#* ] );
            }
            =~ $pattern
    } @logged;
}

## the real regex cache ##
$code{'base.regex'} = undef;
compile_module('base.regex');
$data{'regex'}{'base'} = $code{'base.regex'}->();

compile_module('auth.binding.message');
my $message = $code{'auth.binding.message'};

## fixed-seed throwaway keys [ the spec test vector ] ##
my ( $c_pub, $c_priv ) = Crypt::Ed25519::generate_keypair( "\x01" x 32 );
my ( $s_pub, $s_priv ) = Crypt::Ed25519::generate_keypair( "\x02" x 32 );
my ( $x_pub, $x_priv ) = Crypt::Ed25519::generate_keypair( "\x03" x 32 );

my $b32 = sub { Crypt::Misc::encode_b32r(shift) };

######################################################################
say ': test vector [ auth.binding.message ]';

my %vector = (
    qw| server_nonce | => "\x11" x 32,
    qw| server_pub |   => $s_pub,
    qw| session_pub |  => "\x22" x 32,
    qw| server_eph |   => "\x33" x 32,
    qw| client_eph |   => "\x44" x 32,
    qw| nonce_sid |    => 305419896,
    qw| encoding |     => 'none',
    qw| username |     => 'test-user',
);

my $want_auth_hex
    = '703720617574682d6b6579706169722076320011111111111111111111111111111111'
    . '111111111111111111111111111111118139770ea87d175f56a35466c34c7ecc'
    . 'cb8d8a91b4ee37a25df60f5b8fc9b39422222222222222222222222222222222'
    . '222222222222222222222222222222220009746573742d75736572';
my $want_transcript_hex
    = '1111111111111111111111111111111111111111111111111111111111111111813977'
    . '0ea87d175f56a35466c34c7ecccb8d8a91b4ee37a25df60f5b8fc9b394333333'
    . '3333333333333333333333333333333333333333333333333333333333444444'
    . '4444444444444444444444444444444444444444444444444444444444123456'
    . '7800046e6f6e650009746573742d75736572';

ok( $b32->($c_pub) eq 'RKEOHXLUBHYZL7KS3MWTZOS5OLFGOCN7DWKBEG7TOSEADNAPN5OA',
    'C pub b32'
);
ok( $b32->($s_pub) eq 'QE4XODVIPULV6VVDKRTMGTD6ZTFY3CURWTXDPIS56YHVXD6JWOKA',
    'S pub b32'
);

my $auth_msg = $message->( qw| auth |, \%vector );
ok( defined $auth_msg && unpack( 'H*', $auth_msg ) eq $want_auth_hex,
    'auth msg hex' );
ok( $b32->( Crypt::Ed25519::sign( $auth_msg, $c_pub, $c_priv ) ) eq
        'NJHBPUDRFYSLYCCZ57DJN5OVNOIWSNWGU7QZZJU26ZT445Q3PBQ'
        . 'OUCUQS36W5KFEFYIBSDSY4XZD6FCWC6TETBCBSQWI7ICVRMTCUCI',
    'auth_sig b32'
);

my $client_msg = $message->( qw| client |, \%vector );
my $server_msg = $message->( qw| server |, \%vector );
my $c_label    = unpack( 'H*', "p7 link-bind v1 client\0" );
my $s_label    = unpack( 'H*', "p7 link-bind v1 server\0" );
ok( defined $client_msg
        && unpack( 'H*', $client_msg ) eq $c_label . $want_transcript_hex,
    'client message = label . transcript hex'
);
ok( defined $server_msg
        && unpack( 'H*', $server_msg ) eq $s_label . $want_transcript_hex,
    'server message = label . transcript hex'
);
ok( $b32->( Crypt::Ed25519::sign( $client_msg, $c_pub, $c_priv ) ) eq
        'ANRNMKHTKZ6QDI2EJOUZYXZSNKLQQY3TF57NXSNREYEX3PDVL6K'
        . 'EVQ2LLLTS3V26U4GSKYVC6XCFO2U7BU5JQXEGLHCGPKDJ6HLYSDA',
    'client_bind_sig b32'
);
ok( $b32->( Crypt::Ed25519::sign( $server_msg, $s_pub, $s_priv ) ) eq
        'KLXXZEZPHTKESLFK7NLYD4VZBXWEEP3WQG4T62UKGIFHNUOUW3A'
        . '7ZEVM4BIFC5TQUW3DJJG37XQYJRZFSVXWHPYZZYJ5RWJDVPKHUDA',
    'server_bind_sig b32'
);

say ': builder refuses invalid fields';
for my $case (
    [ 'short server_nonce',   'server_nonce', "\x11" x 31 ],
    [ 'long server_eph',      'server_eph',   "\x33" x 33 ],
    [ 'nonce_sid 0',          'nonce_sid',    0 ],
    [ 'nonce_sid 2**32',      'nonce_sid',    4294967296 ],
    [ 'nonce_sid not digits', 'nonce_sid',    '12a' ],
    [ 'empty encoding',       'encoding',     '' ],
    [ 'username with space',  'username',     'a b' ],
    [ 'wide char username',   'username',     "us\x{263a}r" ],
    [ 'undef client_eph',     'client_eph',   undef ],
) {
    my ( $label, $field, $value ) = @$case;
    my %bad = ( %vector, $field => $value );
    ok( !defined $message->( qw| client |, \%bad ), "client : $label" );
}
ok( !defined $message->( qw| other |, \%vector ), 'unknown kind' );
ok( !defined $message->( qw| auth |,  { %vector, session_pub => 'x' } ),
    'auth : short session_pub' );
ok( $message->( qw| auth |, \%vector ) ne
        $message->( qw| client |, \%vector ),
    'auth and client messages differ'
);

######################################################################
say ': server plugin [ plugin.auth.auth-keypair, v2 only ]';

compile_module('plugin.auth.auth-keypair');
my $plugin = $code{'plugin.auth.auth-keypair'};

$keys{'authorized-remote'}{'test-user'}
    = { 'public' => $c_pub, 'public_b32' => $b32->($c_pub) };

my $session_pub = "\x22" x 32;
my $next_id     = 100;

## a server session right after 'select auth-keypair' ##
sub selected_session {
    my $id = $next_id++;
    $data{'session'}{$id} = {
        'handle' => "FH$id",
        'buffer' => { 'input' => '', 'output' => '' },
        'auth'   => {
            'method'          => 'auth-keypair',
            'server_nonce'    => "\x11" x 32,
            'server_pub'      => $s_pub,
            'server_key_name' => 'srv.base',
        },
    };
    $data{'handle'}{"FH$id"} = { 'link' => 'unix' };    ## no ip TOFU ##
    return $id;
}

sub auth_line {
    my (%arg) = @ARG;
    my $msg = $arg{'v1'} ? $session_pub : $message->(
        qw| auth |,
        {   server_nonce => $arg{'nonce'} // "\x11" x 32,
            server_pub   => $arg{'s_pub'} // $s_pub,
            session_pub  => $session_pub,
            username     => 'test-user',
        }
    );
    my $sig = Crypt::Ed25519::sign( $msg, $c_pub, $c_priv );
    return sprintf "auth test-user %s %s\n", $b32->($session_pub),
        $b32->($sig);
}

{
    my $id = selected_session();
    $data{'session'}{$id}{'buffer'}{'input'} = auth_line();
    my ( $rc, $name ) = $plugin->( event_for($id) );
    my $s = $data{'session'}{$id};
    ok( $rc == 0 && ( $name // '' ) eq 'test-user',   'v2 line : accepted' );
    ok( $s->{'buffer'}{'output'} eq "AUTH_TRUE =)\n", 'v2 line : AUTH_TRUE' );
    ok( ( $s->{'link_binding'} // '' ) eq 'pending',
        'v2 line : link_binding pending' );
    ok( ( $s->{'auth'}{'client_pub'} // '' ) eq $c_pub,
        'v2 line : C public key kept for link-complete'
    );
    ok( defined $s->{'auth'}{'server_nonce'},
        'v2 line : nonce kept for link-complete'
    );
}

for my $case (
    [ 'v1 line [ sig over the bare session pubkey ]', v1    => 1 ],
    [ 'wrong nonce',                                  nonce => "\x12" x 32 ],
    [ 'wrong S_pub',                                  s_pub => $x_pub ],
) {
    my ( $label, @arg ) = @$case;
    my $id = selected_session();
    $data{'session'}{$id}{'buffer'}{'input'} = auth_line(@arg);
    my ( $rc, $name ) = $plugin->( event_for($id) );
    my $s = $data{'session'}{$id};
    ok( $rc == 2 && !defined $name,           "$label : refused [ 2 ]" );
    ok( !exists $s->{'link_binding'},         "$label : no binding state" );
    ok( !exists $s->{'auth'}{'server_nonce'}, "$label : nonce deleted" );
}

{
    my $id = selected_session();
    delete $data{'session'}{$id}{'auth'}{'server_nonce'};
    $data{'session'}{$id}{'buffer'}{'input'} = auth_line();
    my ($rc) = $plugin->( event_for($id) );
    ok( $rc == 2, 'no nonce selected : refused' );

    $id = selected_session();
    $data{'session'}{$id}{'buffer'}{'input'} = "auth test-user ONLYONE\n";
    ($rc) = $plugin->( event_for($id) );
    ok( $rc == 2, 'two fields : protocol mismatch, refused' );
    ok( !exists $data{'session'}{$id}{'auth'}{'server_nonce'},
        'two fields : nonce deleted' );
}

######################################################################
say ': base.handler.auth [ pending : not authenticated, not registered ]';

compile_module('base.session.register_authenticated');
compile_module('base.handler.auth');
my $handler_auth = $code{'base.handler.auth'};

$data{'protocol'}{'protocol-7'}{'connect'} = {
    'banner'          => "B\n",
    'timeout'         => "T\n",
    'protocol_error'  => "PE\n",
    'auth_method_wrn' => "W\n",
    'auth_method_err' => "E\n",
};
$data{'auth'}{'supported_methods'} = { 'auth-keypair' => 1, 'unix' => 1 };
$data{'base'}{'session'}{'uname'}
    = { 'client' => ':unauth:', 'server' => ':server:' };

my @init_states;
$code{'base.session.init_state'} = sub {
    push @init_states, [@ARG];
    return TRUE;
};

my %plugin_script;
$code{'plugin.auth.test-ok'} = sub {
    my $id = $ARG[0]->w->data;
    $data{'session'}{$id}{'buffer'}{'input'} = '';
    $data{'session'}{$id}{'link_binding'} = qw| pending |
        if $plugin_script{'pending'};
    return ( 0, 'test-user' );
};

sub auth_session {
    my $method = shift;
    my $id     = $next_id++;
    $data{'session'}{$id} = {
        'handle'          => "FH$id",
        'last-bytes-read' => 10,
        'buffer'  => { 'input'         => "anything\n", 'output' => '' },
        'auth'    => { 'method'        => $method },
        'watcher' => { 'input_handler' => FakeTimeoutWatcher->new },
    };
    $data{'user'}{':unauth:'}{'session'}{$id} = {};
    return $id;
}

## auth-keypair : the real plugin name is mapped onto the scripted one ##
my $real_plugin = $code{'plugin.auth.auth-keypair'};
$code{'plugin.auth.auth-keypair'} = $code{'plugin.auth.test-ok'};
$code{'plugin.auth.unix'}         = $code{'plugin.auth.test-ok'};

{
    %plugin_script = ( 'pending' => 1 );
    @init_states   = ();
    my $id = auth_session('auth-keypair');
    my $rc = $handler_auth->( event_for($id) );
    my $s  = $data{'session'}{$id};
    ok( $rc == 0, 'auth-keypair pending : state change [ 0 ]' );
    ok( $s->{'authenticated'} eq 'pending', 'authenticated = pending' );
    ok( !$s->{'initialized'},               'not initialized' );
    ok( !exists $data{'user'}{'test-user'}{'session'}{$id},
        'not registered for the user' );
    ok( !exists $data{'user'}{':unauth:'}{'session'}{$id},
        'removed from the unauthenticated user'
    );
    ok( defined $s->{'watcher'}{'input_handler'}{'timeout'},
        'auth timeout stays armed' );
    ok( @init_states == 1 && $init_states[0][1] == 1, 'state 1 entered' );

    %plugin_script = ( 'pending' => 0 );
    $id            = auth_session('auth-keypair');
    $rc            = $handler_auth->( event_for($id) );
    ok( $rc == 2, 'auth-keypair without pending binding : disconnect' );
    ok( !defined $data{'session'}{$id}{'authenticated'},
        'auth-keypair without pending : never authenticated'
    );

    $id = auth_session('unix');
    $rc = $handler_auth->( event_for($id) );
    $s  = $data{'session'}{$id};
    ok( $rc == 0 && $s->{'authenticated'} eq 'yes',
        'unix method : authenticated yes [ unchanged ]'
    );
    ok( exists $data{'user'}{'test-user'}{'session'}{$id},
        'unix method : registered for the user'
    );
    ok( $s->{'initialized'}, 'unix method : initialized' );
    ok( !defined $s->{'watcher'}{'input_handler'}{'timeout'},
        'unix method : auth timeout disarmed' );
    delete $data{'user'}{'test-user'};
}
$code{'plugin.auth.auth-keypair'} = $real_plugin;

######################################################################
say ': state 1 gate [ base.handler.command ]';

compile_module('base.handler.command');
my $handler_cmd = $code{'base.handler.command'};
$code{'base.session.user'}
    = sub { return $data{'session'}{ $ARG[0] }{'user'} };
my $gate_passed;
$code{'base.session.calc_cmd_stats'} = sub { $gate_passed++; return };

sub pending_session {
    my $id = $next_id++;
    $data{'session'}{$id} = {
        'handle'        => "FH$id",
        'user'          => 'test-user',
        'mode'          => 'client',
        'authenticated' => 'pending',
        'link_binding'  => 'pending',
        'buffer'        => { 'input' => '', 'output' => '' },
    };
    return $id;
}

for my $line (
    "list users\n",              "exit\n",
    "TRUE something\n",          "(12)link-upgrade\n",
    "link-upgrade+\n",           "link-upgrade-x\n",
    "!TRM!\n",                   "link-pub-key AAAA\n",
    "link-upgrade utf7 extra\n", "cube.link-upgrade\n",
    "SIZE 3\nabc",
) {
    my $id = pending_session();
    $data{'session'}{$id}{'buffer'}{'input'} = $line;
    $gate_passed = 0;
    my $rc = eval { $handler_cmd->( event_for($id) ) };
    ( my $shown = $line ) =~ s{\n}{\\n}g;
    ok( ( $rc // -1 ) == 2
            && !$gate_passed
            && $data{'session'}{$id}{'buffer'}{'output'}
            =~ m{^FALSE link binding pending},
        "pending : '$shown' refused [ FALSE + disconnect ]"
    );
}

{
    my $id = pending_session();
    $data{'session'}{$id}{'buffer'}{'input'} = 'link-upg';
    $gate_passed = 0;
    my $rc = $handler_cmd->( event_for($id) );
    ok( $rc == 1 && !$gate_passed, 'pending : incomplete line waits [ 1 ]' );

    for my $line ( "link-upgrade\n", "link-upgrade utf7\n" ) {
        $id                                      = pending_session();
        $data{'session'}{$id}{'buffer'}{'input'} = $line;
        $gate_passed                             = 0;
        $code{'base.session.calc_cmd_stats'}
            = sub { $gate_passed++; die "gate passed\n" };
        eval { $handler_cmd->( event_for($id) ) };
        ( my $shown = $line ) =~ s{\n}{\\n}g;
        ok( $gate_passed == 1, "pending : '$shown' passes the gate" );
    }
    $code{'base.session.calc_cmd_stats'} = sub { $gate_passed++; return };

    ## an alias must not turn link-upgrade into another command ##
    $data{'alias'}{'link-upgrade'}           = 'list users';
    $id                                      = pending_session();
    $data{'session'}{$id}{'buffer'}{'input'} = "link-upgrade\n";
    my $rc2 = eval { $handler_cmd->( event_for($id) ) };
    ok( ( $rc2 // -1 ) == 2
            && $data{'session'}{$id}{'buffer'}{'output'}
            =~ m{^FALSE link binding pending},
        'pending : aliased link-upgrade refused after resolution'
    );
    delete $data{'alias'};
}

######################################################################
say ': link-complete [ base.handler.link-upgrade ]';

compile_module('base.handler.link-upgrade');
my $handler_lu = $code{'base.handler.link-upgrade'};

my @written;
$code{'base.handler.write'} = sub {
    my $id = shift;
    push @written, $data{'session'}{$id}{'buffer'}{'output'};
    $data{'session'}{$id}{'buffer'}{'output'} = '';
    return;
};

$keys{'C25519'}{'srv.base'} = { 'public' => $s_pub, 'private' => $s_priv };

## a pending session right after 'link-upgrade' [ state 2 ] ##
sub state2_session {
    my (%opt)      = @ARG;
    my $id         = pending_session();
    my $eph_secret = Crypt::Misc::random_bytes(32);
    my $s          = $data{'session'}{$id};
    $s->{'auth'} = {
        'method'          => 'auth-keypair',
        'server_nonce'    => "\x11" x 32,
        'server_pub'      => $s_pub,
        'server_key_name' => 'srv.base',
        'client_pub'      => $c_pub,
    };
    $s->{'link_ephemeral_keypair'} = {
        'secret' => $eph_secret,
        'public' => Crypt::Curve25519::curve25519_public_key($eph_secret),
    };
    $s->{'link_ephemeral_pubkey'} = $s->{'link_ephemeral_keypair'}{'public'};
    $s->{'link_capabilities'}
        = { 'encoding' => [ 'utf7', 'base32', 'base32-xz' ] };
    $s->{'link_upgrade_timeout'} = time + 17;
    $s->{'watcher'} = { 'input_handler' => FakeTimeoutWatcher->new };

    if ( $opt{'not_pending'} ) {
        delete $s->{'link_binding'};
        $s->{'authenticated'} = 'yes';
    }
    return $id;
}

sub feed {
    my ( $id, $line ) = @ARG;
    $data{'session'}{$id}{'buffer'}{'input'} .= $line;
    return $handler_lu->( event_for($id) );
}

## client half : eph key, encoding, sig over the transcript ##
sub negotiate {
    my $id         = shift;
    my $c_secret   = Crypt::Misc::random_bytes(32);
    my $client_eph = Crypt::Curve25519::curve25519_public_key($c_secret);
    my $rc1 = feed( $id, sprintf "link-pub-key %s\n", $b32->($client_eph) );
    my $rc2 = feed( $id, "link-confirm-encoding none\n" );
    return ( $rc1, $rc2, $client_eph );
}

sub client_sig {
    my ( $id, $client_eph, $nonce_sid, %opt ) = @ARG;
    my $msg = $message->(
        qw| client |,
        {   server_nonce => "\x11" x 32,
            server_pub   => $s_pub,
            server_eph   => $data{'session'}{$id}{'link_ephemeral_pubkey'},
            client_eph   => $client_eph,
            nonce_sid    => $nonce_sid,
            encoding     => 'none',
            username     => 'test-user',
        }
    );
    my ( $k_pub, $k_priv )
        = $opt{'other_key'} ? ( $x_pub, $x_priv ) : ( $c_pub, $c_priv );
    return ( $b32->( Crypt::Ed25519::sign( $msg, $k_pub, $k_priv ) ), $msg );
}

{
    @written = @init_states = ();
    my $id = state2_session();
    my ( $rc1, $rc2, $client_eph ) = negotiate($id);
    ok( $rc1 == 1 && $rc2 == 1, 'pub key + encoding accepted' );
    ok( $data{'session'}{$id}{'link_client_eph'} eq $client_eph,
        'client eph key kept' );
    my ( $sig_b32, $c_msg ) = client_sig( $id, $client_eph, 4242 );
    my $rc = feed( $id, "link-complete 4242 $sig_b32\n" );
    my $s  = $data{'session'}{$id};
    ok( $rc == 0, 'valid client_bind_sig : complete [ 0 ]' );
    ## earlier replies [ SIZE 0, encoding-confirmed ] share the flush ##
    my ($srv_sig_b32)
        = ( $written[-1] // '' )
        =~ m{(?:\A|\n)link-complete-ok ([A-Z2-7]+)\n\z};
    ok( defined $srv_sig_b32, 'reply : link-complete-ok <server_bind_sig>' );
    ( my $s_msg = $c_msg )
        =~ s{\Ap7 link-bind v1 client\0}{p7 link-bind v1 server\0};
    ok( defined $srv_sig_b32 && Crypt::Ed25519::verify(
            $s_msg, $s_pub, Crypt::Misc::decode_b32r($srv_sig_b32)
        ),
        'server_bind_sig verifies with S over the same transcript'
    );
    ok( @init_states
            && $init_states[-1][0] == $id
            && $init_states[-1][1] == 3,
        'state 3 entered'
    );
    ok( $s->{'link_binding'} eq 'done', 'link_binding done' );
    ok( $s->{'authenticated'} eq 'yes', 'authenticated yes' );
    ok( exists $data{'user'}{'test-user'}{'session'}{$id},
        'registered for the user' );
    ok( !exists $s->{'auth'}{'server_nonce'},
        'nonce deleted ' . '[ single-use ]'
    );
    ok( !defined $s->{'watcher'}{'input_handler'}{'timeout'},
        'auth timeout disarmed once bound' );
    ok( $s->{'link_nonce_session_id'} == 4242, 'nonce sid stored' );
    delete $data{'user'}{'test-user'};
}

my @refusals = (
    [ 'missing client_bind_sig', sub {"link-complete 4242\n"} ],
    [ 'missing nonce_sid',       sub {"link-complete\n"} ],
    [   'client_bind_sig by another key',
        sub {
            sprintf "link-complete 4242 %s\n",
                ( client_sig( @_, 4242, other_key => 1 ) )[0];
        }
    ],
    [   'client_bind_sig over another nonce_sid',
        sub {
            sprintf "link-complete " . "4243 %s\n",
                ( client_sig( @_, 4242 ) )[0];
        }
    ],
    [   'nonce_sid 0',
        sub { sprintf "link-complete 0 %s\n", ( client_sig( @_, 1 ) )[0] }
    ],
    [   'nonce_sid 2**32',
        sub {
            sprintf "link-complete 4294967296 %s\n",
                ( client_sig( @_, 1 ) )[0];
        }
    ],
    [ 'client_bind_sig not base32', sub {"link-complete 4242 abc!def\n"} ],
);

for my $case (@refusals) {
    my ( $label, $make_line ) = @$case;
    @written = @init_states = ();
    my $id = state2_session();
    my ( undef, undef, $client_eph ) = negotiate($id);
    my $rc = feed( $id, $make_line->( $id, $client_eph ) );
    my $s  = $data{'session'}{$id};
    ok( $rc == 2, "$label : disconnect [ 2 ]" );
    ok( !grep( {m{link-complete-ok}} @written,
            $s->{'buffer'}{'output'} // '' ),
        "$label : no link-complete-ok"
    );
    ok( !@init_states,                        "$label : no state 3" );
    ok( !exists $s->{'auth'}{'server_nonce'}, "$label : nonce deleted" );
    ok( $s->{'authenticated'} eq 'pending',
        "$label : still " . "not authenticated"
    );
}

{
    ## the announced key is no longer the loaded one ##
    @written = @init_states = ();
    my $id = state2_session();
    my ( undef, undef, $client_eph ) = negotiate($id);
    local $keys{'C25519'}{'srv.base'}
        = { 'public' => $x_pub, 'private' => $x_priv };
    my $rc = feed(
        $id,
        sprintf "link-complete 4242 %s\n",
        ( client_sig( $id, $client_eph, 4242 ) )[0]
    );
    ok( $rc == 2 && !@written && !@init_states,
        'loaded server key ne announced S_pub : refused'
    );

    ## an unexpected line on a pending state 2 session ##
    $id = state2_session();
    $rc = feed( $id, "list users\n" );
    ok( $rc == 2 && !exists $data{'session'}{$id}{'auth'}{'server_nonce'},
        'pending state 2 : unexpected line disconnects, nonce deleted'
    );

    ## link-complete before the eph key \ encoding ##
    $id = state2_session();
    $rc = feed( $id, "link-complete 4242 AAAA\n" );
    ok( $rc == 2, 'pending : link-complete before negotiation refused' );

    ## timeout ##
    $id = state2_session();
    $data{'session'}{$id}{'link_upgrade_timeout'} = time - 1;
    $rc = feed( $id, "link-pub-key AAAA\n" );
    ok( $rc == 2 && !exists $data{'session'}{$id}{'auth'}{'server_nonce'},
        'pending : timeout disconnects, nonce deleted' );

    ## a short client eph key ##
    $id = state2_session();
    $rc = feed( $id, sprintf "link-pub-key %s\n", $b32->( 'x' x 16 ) );
    ok( $rc == 2, 'client eph key not 32 bytes : refused' );

    ## non-pending sessions [ unix, zenka ] : unchanged ##
    @written = @init_states = ();
    $id      = state2_session( not_pending => 1 );
    negotiate($id);
    $rc = feed( $id, "link-complete 77\n" );
    ok( $rc == 0
            && ( $written[-1] // '' ) =~ m{(?:\A|\n)link-complete-ok\n\z},
        'non-pending : link-complete without sig unchanged'
    );
}

######################################################################
say ': pending sessions invisible to send.local \ route_to_target';

compile_module('base.cfg_bool');
ok( !$code{'base.cfg_bool'}->('pending'),
    'route_to_target check : cfg_bool( pending ) is false' );
ok( $code{'base.cfg_bool'}->('yes'), 'route_to_target check : yes is true' );

compile_module('base.protocol-7.command.send.local');
my $send_local = $code{'base.protocol-7.command.send.local'};
$code{'base.caller'}                     = sub { return ('[ test ]') };
$code{'base.gen_id'}                     = sub { return 1 };
$code{'base.zenki.resolve_routing_sids'} = sub { return @{ $ARG[2] } };
my @routes;
$code{'base.route.add'} = sub {
    push @routes, [@ARG];
    return { 'target' => { 'cmd_id' => 9 } };
};
$data{'system'}{'zenka'}
    = { 'name' => 'cube', 'verbosity' => { 'console' => 0, 'buffer' => 0 } };

{
    my $id = pending_session();
    @routes = ();
    my $count
        = $send_local->( { 'command' => "$id.list", 'call_args' => {} } );
    ok( $count == 0 && !@routes, 'send.local : pending session skipped' );
    my $by_name
        = $send_local->(
        { 'command' => 'test-user.list', 'call_args' => {} } );
    ok( $by_name == 0 && !@routes,
        'send.local : pending session not reachable by user name' );
    $data{'session'}{$id}{'authenticated'} = 'yes';
    $count = $send_local->( { 'command' => "$id.list", 'call_args' => {} } );
    ok( $count == 1 && @routes == 1, 'send.local : control [ yes ] sent' );
}

######################################################################
say ': client [ auth.client.auth-keypair.authenticate + server pin ]';

my $home
    = tempdir( 'p7-auth-link-binding-XXXXXXXX', TMPDIR => 1, CLEANUP => 1 );
$code{'base.get_homedir'} = sub { return $home };
compile_module('trust.statement');
compile_module('trust.fingerprint');
compile_module('trust.verify');
compile_module('auth.client.server_pin.check');
compile_module('auth.client.auth-keypair.authenticate');
my $authenticate = $code{'auth.client.auth-keypair.authenticate'};

$data{'protocol'}{'protocol-7'}{'regex'}{'protocol-version'}
    = qr|^BANNER\n$|;
$data{'protocol'}{'protocol-7'}{'connect'}{'select-method'} = "select %s\n";
$data{'protocol'}{'protocol-7'}{'connect'}{'banner'}        = "BANNER\n";
$code{'base.is_defined_recursive'} = sub { return TRUE };
$code{'base.s_read'}               = sub {
    my ( $sock, $buf_ref ) = @ARG;
    $$buf_ref = readline($sock);
    return length( $$buf_ref // '' );
};
$code{'base.net.send_to_socket'} = sub {
    my ( $sock, $str ) = @ARG;
    print {$sock} $str;
    return TRUE;
};
$code{'auth.client.zenka.process_auth_reply'} = sub {
    my $line = readline( $ARG[0] ) // '';
    return $line eq "AUTH_TRUE =)\n" ? $ARG[0] : undef;
};
$keys{'C25519'}{'cli-session'} = { 'public' => $session_pub };
my @client_signed;
$code{'crypt.C25519.sign_data'} = sub {
    my ( $msg_ref, $key_name ) = @ARG;
    push @client_signed, [ $msg_ref->$*, $key_name ];
    return Crypt::Ed25519::sign( $msg_ref->$*, $c_pub, $c_priv );
};
sub main::max { my $m = shift; $m = $_ > $m ? $_ : $m for @_; return $m }

## run authenticate against a scripted server end ; returns ( result, every ##
## line the client sent )                                                   ##
sub run_client {
    my ( $select_reply, $server_id ) = @ARG;
    my ( $ours, $theirs )
        = IO::Socket->socketpair( AF_UNIX, SOCK_STREAM, PF_UNSPEC )
        or die "socketpair : $ERRNO";
    $ours->autoflush(1);
    $theirs->autoflush(1);
    print {$theirs} "BANNER\n", "$select_reply\n", "AUTH_TRUE =)\n";
    @client_signed = ();
    my $result = $authenticate->(
        $ours, 'test-user', 'cli-session', 'test-c.base',
        $server_id // { 'host' => 'peer.example', 'port' => 4242 }
    );
    close($ours);
    my @sent = readline($theirs);
    close($theirs);
    return ( $result, @sent );
}

## host-root delegation [ data/md/design/HOST-ROOT-DELEGATION.md ] : the    ##
## spec vector's host-root [ seed \x03 ] delegates S ; a foreign one [ seed ##
## \x04 ] too                                                               ##
my ( $hr_pub, $hr_priv ) = Crypt::Ed25519::generate_keypair( "\x03" x 32 );
my ( $fr_pub, $fr_priv ) = Crypt::Ed25519::generate_keypair( "\x04" x 32 );
my $hr_fp = $code{'trust.fingerprint'}->($hr_pub);

sub delegate {
    my ( $subject, %opt )  = @ARG;
    my ( $i_pub, $i_priv ) = ( $opt{'issuer'} // [ $hr_pub, $hr_priv ] )->@*;
    my $statement = $code{'trust.statement'}->(
        'build',
        {   issuer_pub  => $i_pub,
            subject_pub => $subject,
            name        => 'peer.cube',
            not_before  => time - 60,
            not_after   => $opt{'not_after'} // time + 86400,
            scope       => '',
        }
    );
    my $sig = Crypt::Ed25519::sign( $statement, $i_pub, $i_priv );
    return $code{'trust.statement'}->( 'wire', $statement, $sig );
}

my $nonce      = "\x55" x 32;
my $s_dlg      = delegate($s_pub);
my $good_reply = sprintf 'TRUE %s %s %s', $b32->($s_pub), $b32->($nonce),
    $s_dlg;
my $pin_path = "$home/.n/remote-keys/servers/peer.example_4242.public";

sub read_pin {
    open( my $pin_fh, '<', $pin_path ) or return '';
    my $pinned = readline($pin_fh) // '';
    close($pin_fh);
    return $pinned;
}

{
    @logged = ();
    my ( $ctx, @sent ) = run_client($good_reply);
    ok( ref $ctx eq 'HASH', 'first contact : binding context returned' );
    ok( -f $pin_path,       'first contact : pin file written' );
    ok( ( ( stat $pin_path )[2] & 07777 ) == 0600, 'pin file mode 0600' );
    ok( read_pin() eq "$hr_fp\n",
        'pin file holds the ' . 'host-root fingerprint' );
    ok( length($hr_fp) == 77, '  :.. 77 chars' );
    ok( logged_level0(qr{pinned host-root \Q$hr_fp\E \[ peer\.cube \]}),
        'pinned : logged at level 0 with fingerprint + name'
    );
    ok( $ctx->{'server_nonce'} eq $nonce
            && $ctx->{'server_pub'} eq $s_pub
            && $ctx->{'username'} eq 'test-user'
            && $ctx->{'base_key_name'} eq 'test-c.base',
        'context : server_nonce, server_pub, username, base_key_name'
    );
    my ($auth)    = grep {m{^auth }} @sent;
    my ($sig_b32) = ( $auth // '' ) =~ m{^auth test-user \S+ (\S+)\n\z};
    my $want      = $message->(
        qw| auth |,
        {   server_nonce => $nonce,
            server_pub   => $s_pub,
            session_pub  => $session_pub,
            username     => 'test-user'
        }
    );
    ok( defined $sig_b32 && Crypt::Ed25519::verify(
            $want, $c_pub, Crypt::Misc::decode_b32r($sig_b32)
        ),
        'auth line carries the v2 auth_sig'
    );
    ok( @client_signed == 1 && $client_signed[0][1] eq 'test-c.base',
        'signed with the explicit base key name' );
}

{
    my ( $ctx, @sent ) = run_client($good_reply);
    ok( ref $ctx eq 'HASH', 'pinned key matches : accepted' );

    ## S rotated : x_pub, delegated by the SAME host-root ##
    my $rotated_reply = sprintf 'TRUE %s %s %s', $b32->($x_pub),
        $b32->($nonce), delegate($x_pub);
    ( $ctx, @sent ) = run_client($rotated_reply);
    ok( ref $ctx eq 'HASH' && $ctx->{'server_pub'} eq $x_pub,
        'rotated S delegated by the pinned host-root : accepted'
    );
    ok( read_pin() eq "$hr_fp\n", '  :.. pin unchanged' );

    ## a foreign host-root delegating S ##
    my $other_reply = sprintf 'TRUE %s %s %s', $b32->($s_pub),
        $b32->($nonce), delegate( $s_pub, issuer => [ $fr_pub, $fr_priv ] );
    @logged = ();
    ( $ctx, @sent ) = run_client($other_reply);
    ok( !defined $ctx, 'foreign host-root : refused' );
    ok( logged_level0(qr{host-root MISMATCH}), '  :.. logged MISMATCH' );
    ok( !grep( {m{^auth }} @sent ) && !@client_signed,
        'foreign host-root : nothing signed, no auth line sent'
    );
    ok( read_pin() eq "$hr_fp\n", 'foreign host-root : pin NOT replaced' );

    ## S not the delegated subject ##
    ( $ctx, @sent ) = run_client( sprintf 'TRUE %s %s %s',
        $b32->($x_pub), $b32->($nonce), $s_dlg );
    ok( !defined $ctx && !grep( {m{^auth }} @sent ) && !@client_signed,
        'announced S != delegated subject : refused, nothing sent'
    );

    ## expired ##
    ( $ctx, @sent ) = run_client( sprintf 'TRUE %s %s %s',
        $b32->($s_pub), $b32->($nonce),
        delegate( $s_pub, not_after => time - 1 ) );
    ok( !defined $ctx && !grep( {m{^auth }} @sent ),
        'expired delegation : refused, no auth line'
    );

    ## no 4th field [ the v2 reply ] ##
    ( $ctx, @sent )
        = run_client( sprintf 'TRUE %s %s', $b32->($s_pub), $b32->($nonce) );
    ok( !defined $ctx && !grep( {m{^auth }} @sent ),
        'select reply without delegation : refused, no auth line' );

    ## a 4th field over 2048 chars ##
    ( $ctx, @sent ) = run_client(
        sprintf 'TRUE %s %s %s', $b32->($s_pub),
        $b32->($nonce),          'A' x 2049
    );
    ok( !defined $ctx && !grep( {m{^auth }} @sent ),
        'delegation over 2048 chars : refused'
    );

    ( $ctx, @sent ) = run_client( sprintf 'TRUE %s', $b32->($s_pub) );
    ok( !defined $ctx && !grep( {m{^auth }} @sent ),
        'select reply without nonce : refused, no auth line'
    );

    ( $ctx, @sent ) = run_client(
        sprintf 'TRUE %s %s %s', $b32->($s_pub),
        $b32->( 'x' x 16 ),      $s_dlg
    );
    ok( !defined $ctx && !grep( {m{^auth }} @sent ),
        'short nonce : refused, no auth line'
    );

    ( $ctx, @sent ) = run_client( $good_reply, undef );
    ( $ctx, @sent ) = run_client( $good_reply, {} );
    ok( !defined $ctx && !grep( {m{^auth }} @sent ),
        'no host \ port for the pin : refused'
    );

    ( $ctx, @sent )
        = run_client( $good_reply, { 'host' => '../evil', 'port' => 1 } );
    ok( !defined $ctx && !-e "$home/.n/remote-keys/evil_1.public",
        'host with a path : refused, nothing written'
    );

    ## a pin that exists but cannot be read ##
    my $locked = "$home/.n/remote-keys/servers/locked.example_1.public";
    open( my $lfh, '>', $locked ) or die "pin : $OS_ERROR";
    print {$lfh} $hr_fp, "\n";
    close($lfh);
    chmod 0000, $locked;
SKIP: {
        if ( open( my $probe, '<', $locked ) ) {
            close($probe);
            say '  skip : unreadable pin [ running as root ]';
            last SKIP;
        }
        ( $ctx, @sent )
            = run_client( $good_reply,
            { 'host' => 'locked.example', 'port' => 1 } );
        ok( !defined $ctx && !grep( {m{^auth }} @sent ),
            'unreadable pin file : refused' );
    }
    chmod 0600, $locked;

    ## a garbled pin ##
    my $garbled = "$home/.n/remote-keys/servers/garbled.example_1.public";
    open( my $gfh, '>', $garbled ) or die "pin : $OS_ERROR";
    print {$gfh} "not a key\n";
    close($gfh);
    ( $ctx, @sent )
        = run_client( $good_reply,
        { 'host' => 'garbled.example', 'port' => 1 } );
    ok( !defined $ctx && !grep( {m{^auth }} @sent ),
        'garbled pin file : refused' );

    ## an old 52 char S pin : refused, never migrated ##
    my $old_pin = "$home/.n/remote-keys/servers/old.example_1.public";
    open( my $ofh, '>', $old_pin ) or die "pin : $OS_ERROR";
    print {$ofh} $b32->($s_pub), "\n";
    close($ofh);
    @logged = ();
    ( $ctx, @sent )
        = run_client( $good_reply, { 'host' => 'old.example', 'port' => 1 } );
    ok( !defined $ctx && !grep( {m{^auth }} @sent ),
        'old 52 char S pin : refused' );
    ok( logged_level0(qr{old server key pin}), '  :.. logged as old pin' );
    open( $ofh, '<', $old_pin ) or die "pin : $OS_ERROR";
    ok( readline($ofh) eq $b32->($s_pub) . "\n", '  :.. NOT re-pinned' );
    close($ofh);
}

######################################################################
say ': client handshake refuses a bad server_bind_sig';

compile_module('protocol.protocol-7.link-upgrade.handshake');
my $handshake = $code{'protocol.protocol-7.link-upgrade.handshake'};

## forked fake server : correct up to link-complete, then answers with ##
## $form [ sig by S \ sig by another key \ no sig ]                    ##
sub run_handshake_vs {
    my $form = shift;
    my ( $cli, $srv )
        = IO::Socket->socketpair( AF_UNIX, SOCK_STREAM, PF_UNSPEC )
        or die "socketpair : $ERRNO";
    $cli->autoflush(1);
    $srv->autoflush(1);
    my $pid = fork // die "fork : $ERRNO";
    if ( $pid == 0 ) {
        close($cli);
        my $line = sub { my $l = readline($srv) // exit 0; chomp $l; $l };
        $line->();
        my $e_sec = Crypt::Misc::random_bytes(32);
        my $e_pub = Crypt::Curve25519::curve25519_public_key($e_sec);
        print {$srv} 'TRUE link-upgrade OK ', $b32->($e_pub), "\n";
        my ($c_eph_b32) = $line->() =~ m{^link-pub-key (\S+)$};
        print {$srv} "SIZE 0\n";
        $line->();
        print {$srv} "encoding-confirmed\n";
        my ($sid) = $line->() =~ m{^link-complete (\d+) };
        my $msg = $message->(
            qw| server |,
            {   server_nonce => $nonce,
                server_pub   => $s_pub,
                server_eph   => $e_pub,
                client_eph   => Crypt::Misc::decode_b32r($c_eph_b32),
                nonce_sid    => $sid,
                encoding     => 'none',
                username     => 'test-user',
            }
        );
        my ( $k_pub, $k_priv )
            = $form eq 'other' ? ( $x_pub, $x_priv ) : ( $s_pub, $s_priv );
        my $sig = Crypt::Ed25519::sign( $msg, $k_pub, $k_priv );
        print {$srv} $form eq 'none'
            ? "link-complete-ok\n"
            : 'link-complete-ok ' . $b32->($sig) . "\n";
        exit 0;
    }
    close($srv);
    my @r = $handshake->(
        $cli,
        {   'timeout' => 2,
            'binding' => {
                'server_nonce'  => $nonce,
                'server_pub'    => $s_pub,
                'username'      => 'test-user',
                'base_key_name' => 'test-c.base',
            }
        }
    );
    close($cli);
    waitpid( $pid, 0 );
    return @r;
}

{
    my @r = run_handshake_vs('good');
    ok( ( $r[0] // 0 ) == 1, 'server_bind_sig by the pinned S : accepted' );
    @r = run_handshake_vs('other');
    ok( ( $r[0] // 1 ) == 0 && $r[1]{'error'} =~ m{server_bind_sig},
        'server_bind_sig by another key : refused' );
    @r = run_handshake_vs('none');
    ok( ( $r[0] // 1 ) == 0 && !exists $r[1]{'shared_secret'},
        'link-complete-ok without server_bind_sig : refused'
    );
}

say '';
say "passed : $pass_count  failed : $fail_count";
exit( $fail_count ? 1 : 0 );

#,,..,,,.,,.,,.,.,,.,,,,.,..,,.,,,...,,,,,,..,..,,...,...,..,,.,.,,,,,,..,,,,,
#JKJYORCDUAF7C3Z25YXYI26YOSMF7EROUAQZPWBM2SEVZOQY7QPTVG3OLXXZ6KAAHBE3ZFL4EY3XQ
#\\\|BLTXMCQO5ROWGY5YNN5PANQZDPGLAXPASU77FN6JTMYKP7VJKH4 \ / AMOS7 \ YOURUM ::
#\[7]NUMNVT3HNEM5MN4ROCPED6XFDQEUAZ3KW3HDT4GUQFGY2JJPNACQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
