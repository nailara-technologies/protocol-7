#!/usr/bin/env perl
use v5.24;
use strict;
use English;
use warnings;

## the production runtime [ bin/Protocol-7 : use utf8 + Encode ] loads the ##
## bytes pragma transitively ; 39 src modules call bytes::length. mirror   ##
## that here so the compiled frame writer resolves it.                     ##
use bytes;

## link-upgrade client handshake + activation [ 2026-10-06 ] compiles the   ##
## real protocol.protocol-7.link-upgrade.handshake and runs it against a    ##
## fake server over a socketpair [ AF_UNIX, SOCK_STREAM ] : a forked child  ##
## speaks the exact server lines and reports its own DH result and the      ##
## received nonce sid through a temp file. also exercises client_activate   ##
## and encryption.init with stubbed session init + perlmod lookups, and the ##
## frame-<id> writer the init installs. no zenka started, restarted or      ##
## reloaded. binding [ AUTH-LINK-BINDING ] : the fake server checks the     ##
## client_bind_sig over its own pack of the transcript and answers with a   ##
## server_bind_sig ; a wrong \ missing one and a missing context fail.      ##

use File::Spec;
use Cwd        qw| abs_path |;
use FindBin    qw| $RealBin |;
use File::Temp qw| tempfile |;
use Socket     qw| AF_UNIX SOCK_STREAM |;

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
use Crypt::Curve25519;
use Crypt::Ed25519;
use Digest::SHA qw| sha256 |;

use constant TRUE  => 5;
use constant FALSE => 0;

our %code;
our %data;

my $fail_count = 0;

sub ok {
    my ( $cond, $label ) = @ARG;
    if ($cond) { say "  ok   : $label"; return }
    $fail_count++;
    say "  FAIL : $label";
    return;
}

sub compile_module {
    my $module_name = shift;
    my $src_path
        = File::Spec->catfile( $main::root_path, 'src', $module_name );
    open( my $fh, '<', $src_path ) or die "cannot read $src_path : $!";
    my $src = join( '', <$fh> );
    close($fh);
    my $translated = p7_syntax__translate($src);
    my $cref       = eval "sub {\n# line 1 \"$module_name\"\n$translated\n}";
    die "compile failed for $module_name : $EVAL_ERROR"
        if not defined $cref;
    $code{$module_name} = $cref;
    return $cref;
}

## stubs : what handshake, client_activate and encryption.init look up ##
my @logged;
$code{'base.logs'} = sub { push @logged, [@ARG]; return };
$code{'base.log'}  = sub {return};
my @complaints;
$code{'base.s_warn'}
    = sub { push @complaints, sprintf( shift, @ARG ); return };
$code{'base.caller'}         = sub { return '[ test ]' };
$code{'base.perlmod.loaded'} = sub {
    my $module = shift;
    my $path   = $module;
    $path =~ s|::|/|go;
    $path .= qw| .pm |;
    return exists $INC{$path} ? TRUE : FALSE;
};
$code{'base.perlmod.load'} = sub {
    my $module = shift;
    eval "require $module";    ## no critics ##
    return length $EVAL_ERROR ? FALSE : TRUE;
};
## watcher re-registration at the end of encryption.init ##
$code{'event.add_var'} = sub {
    return sub {return}
};

compile_module('auth.binding.message');
compile_module('protocol.protocol-7.link-upgrade.handshake');

## binding [ data/md/design/AUTH-LINK-BINDING.md ] : throwaway identities ##
## from fixed seeds [ test only ] -- C = client base key, S = server key  ##
my ( $c_pub, $c_priv ) = Crypt::Ed25519::generate_keypair( "\x01" x 32 );
my ( $s_pub, $s_priv ) = Crypt::Ed25519::generate_keypair( "\x02" x 32 );
my ( $x_pub, $x_priv ) = Crypt::Ed25519::generate_keypair( "\x03" x 32 );
my $server_nonce = Crypt::Misc::random_bytes(32);
my @signed_with;
$code{'crypt.C25519.sign_data'} = sub {
    my ( $msg_ref, $key_name ) = @ARG;
    push @signed_with, $key_name;
    return Crypt::Ed25519::sign( $msg_ref->$*, $c_pub, $c_priv );
};
my $binding = {
    qw| server_nonce |  => $server_nonce,
    qw| server_pub |    => $s_pub,
    qw| username |      => qw| test-user |,
    qw| base_key_name | => qw| test-c.base |,
};

## the transcript as the server builds it : packed HERE, independent of ##
## auth.binding.message [ cross-checks the builder ]                    ##
sub fake_transcript {
    my ( $server_eph, $client_eph, $nonce_sid, $encoding ) = @ARG;
    return pack(
        'a32 a32 a32 a32 N n/a* n/a*',
        $server_nonce, $s_pub,    $server_eph, $client_eph,
        $nonce_sid,    $encoding, 'test-user'
    );
}
compile_module('protocol.protocol-7.encryption.init');
compile_module('protocol.protocol-7.link-upgrade.client_activate');

## session state init delegates to the compiled encryption.init ##
$code{'base.session.init_state'} = sub {
    my ( $session_id, $state_id ) = @ARG;
    return $code{'protocol.protocol-7.encryption.init'}
        ->( $session_id, qw| tcp |, $state_id );
};

my $handshake = $code{'protocol.protocol-7.link-upgrade.handshake'};
my $activate  = $code{'protocol.protocol-7.link-upgrade.client_activate'};
my $enc_init  = $code{'protocol.protocol-7.encryption.init'};

## forked fake server helpers [ child side ] ##
sub server_read_line {
    my $socket = shift;
    my $line   = readline($socket);
    return undef if not defined $line;
    $line =~ s{\r?\n\z}{};
    return $line;
}

## the correct conversation ; writes its DH secret + received sid       ##
## $server_sign : [ pub, priv ] signing the server_bind_sig [ //= S ] ; ##
## $reply_form  : 'ok' | 'no-sig' | 'bad-b32'                           ##
sub server_ok {
    my $socket      = shift;
    my $report_path = shift;
    my $server_sign = shift // [ $s_pub, $s_priv ];
    my $reply_form  = shift // qw| ok |;
    my $read_line   = sub { return server_read_line($socket) };
    my $send        = sub {
        print {$socket} shift, "\n" or die "server send : $!";
    };

    my $cmd = $read_line->() // die 'server : expected link-upgrade';
    die "server : unexpected '$cmd'" if $cmd ne 'link-upgrade';

    my $server_secret = Crypt::Misc::random_bytes(32);
    my $server_pub = Crypt::Curve25519::curve25519_public_key($server_secret);
    $send->(
        sprintf 'TRUE link-upgrade OK %s',
        Crypt::Misc::encode_b32r($server_pub)
    );

    my $key_line = $read_line->() // die 'server : expected link-pub-key';
    my ($client_pub_b32) = $key_line =~ m{^link-pub-key\s+(\S+)$}o
        or die "server : bad key line '$key_line'";
    my $client_pub = Crypt::Misc::decode_b32r($client_pub_b32)
        or die 'server : client key decode failed';
    my $shared
        = Crypt::Curve25519::curve25519_shared_secret( $server_secret,
        $client_pub );
    $send->('SIZE 0');

    my $enc_line = $read_line->() // die 'server : expected encoding line';
    my ($encoding) = $enc_line =~ m{^link-confirm-encoding (\S+)$}o
        or die "server : bad encoding line '$enc_line'";
    $send->('encoding-confirmed');

    my $done_line = $read_line->() // die 'server : expected link-complete';
    my ( $nonce_sid, $client_sig_b32 )
        = $done_line =~ m{^link-complete (\d+) ([A-Z2-7]+)$}o
        or die "server : bad link-complete line '$done_line'";

    my $transcript
        = fake_transcript( $server_pub, $client_pub, $nonce_sid, $encoding );
    my $client_ok
        = Crypt::Ed25519::verify(
        pack( 'Z*', 'p7 link-bind v1 client' ) . $transcript,
        $c_pub, Crypt::Misc::decode_b32r($client_sig_b32) ) ? 1 : 0;
    my $server_sig
        = Crypt::Ed25519::sign(
        pack( 'Z*', 'p7 link-bind v1 server' ) . $transcript,
        $server_sign->[0], $server_sign->[1] );
    $send->(
          $reply_form eq qw| no-sig |  ? 'link-complete-ok'
        : $reply_form eq qw| bad-b32 | ? 'link-complete-ok 1!!'
        :   'link-complete-ok ' . Crypt::Misc::encode_b32r($server_sig)
    );

    open( my $fh, '>', $report_path )
        or die "server : cannot write $report_path : $OS_ERROR";
    print {$fh} unpack( qw| H* |, $shared ), " $nonce_sid $client_ok";
    close($fh);
    return;
}

## wrong-answer variants : reply one bad line where named, then go quiet ##
sub server_refused {
    my $socket = shift;
    server_read_line($socket);
    print {$socket} "FALSE link-upgrade denied\n" or die "server send : $!";
    return;
}

sub server_bad_key {
    my $socket = shift;
    server_read_line($socket);
    ## valid base32, decodes to 10 bytes -- not a curve25519 key ##
    print {$socket} "TRUE link-upgrade OK AAAAAAAAAAAAAAAA\n"
        or die "server send : $!";
    return;
}

sub server_bad_size {
    my $socket = shift;
    server_read_line($socket);
    my $server_secret = Crypt::Misc::random_bytes(32);
    print {$socket} sprintf(
        "TRUE link-upgrade OK %s\n",
        Crypt::Misc::encode_b32r(
            Crypt::Curve25519::curve25519_public_key($server_secret)
        )
    ) or die "server send : $!";
    server_read_line($socket);
    print {$socket} "SIZE 999\n" or die "server send : $!";
    return;
}

sub server_bad_encoding {
    my $socket = shift;
    server_read_line($socket);
    my $server_secret = Crypt::Misc::random_bytes(32);
    print {$socket} sprintf(
        "TRUE link-upgrade OK %s\n",
        Crypt::Misc::encode_b32r(
            Crypt::Curve25519::curve25519_public_key($server_secret)
        )
    ) or die "server send : $!";
    server_read_line($socket);
    print {$socket} "SIZE 0\n" or die "server send : $!";
    server_read_line($socket);
    print {$socket} "encoding-rejected\n" or die "server send : $!";
    return;
}

sub server_bad_complete {
    my $socket = shift;
    server_read_line($socket);
    my $server_secret = Crypt::Misc::random_bytes(32);
    print {$socket} sprintf(
        "TRUE link-upgrade OK %s\n",
        Crypt::Misc::encode_b32r(
            Crypt::Curve25519::curve25519_public_key($server_secret)
        )
    ) or die "server send : $!";
    server_read_line($socket);
    print {$socket} "SIZE 0\n" or die "server send : $!";
    server_read_line($socket);
    print {$socket} "encoding-confirmed\n" or die "server send : $!";
    server_read_line($socket);
    print {$socket} "link-complete-failed\n" or die "server send : $!";
    return;
}

sub server_silent {
    my $socket = shift;
    sleep 30;    ## never answers ##
    return;
}

## run the real handshake against a forked behavior ; guard with alarm ##
sub run_handshake {
    my $behavior = shift;
    socketpair( my $srv, my $cli, AF_UNIX, SOCK_STREAM, 0 )
        or die "socketpair failed : $OS_ERROR";
    $srv->autoflush(1);
    $cli->autoflush(1);
    my $pid = fork // die "fork failed : $OS_ERROR";
    if ( $pid == 0 ) {
        close($cli);
        eval { $behavior->($srv) };
        exit 0;
    }
    close($srv);
    my @result;
    my $died;
    eval {
        local $SIG{ALRM} = sub { die "test-side alarm\n" };
        alarm 15;
        @result = $handshake->(
            $cli, { qw| timeout | => 1, qw| binding | => $binding }
        );
        alarm 0;
    };
    $died = $EVAL_ERROR if $EVAL_ERROR;
    alarm 0;
    close($cli);
    kill( 'TERM', $pid ) if kill( 0, $pid );
    waitpid( $pid, 0 );
    return ( \@result, $died );
}

say ': handshake success';

my ( $tmp_fh, $tmp_path )
    = tempfile( 'p7-link-upgrade-XXXXXXXX', TMPDIR => 1, UNLINK => 1 );
close($tmp_fh);
my ( $result, $died )
    = run_handshake( sub { server_ok( shift, $tmp_path ) } );
ok( !length( $died // '' ) && ( $result->[0] // 0 ) == 1,
    'handshake success : ( 1, { .. } )' );
open( my $report_fh, '<', $tmp_path )
    or die "cannot read $tmp_path : $OS_ERROR";
my ( $server_secret_hex, $server_nonce_sid, $server_saw_sig ) = split m{\s+}o,
    scalar readline($report_fh);
close($report_fh);
ok( length( $result->[1]{'shared_secret'} // '' ) == 32,
    'shared secret is 32 bytes' );
ok( unpack( qw| H* |, $result->[1]{'shared_secret'} ) eq $server_secret_hex,
    'shared secret == the server DH result' );
ok( $result->[1]{'nonce_sid'} >= 1 && $result->[1]{'nonce_sid'} <= 4294967295,
    'nonce sid in 1 .. 2**32-1'
);
ok( $result->[1]{'nonce_sid'} == $server_nonce_sid,
    'nonce sid == what the server received'
);
ok( $server_saw_sig eq '1',
    'client_bind_sig verifies with C over the server-side transcript' );
ok( "@signed_with" eq 'test-c.base',
    'client signed with the context base key name' );

say ': binding failures';

foreach my $case (
    [ 'server_bind_sig by another key', [ $x_pub, $x_priv ], 'ok' ],
    [ 'link-complete-ok without sig',   undef,               'no-sig' ],
    [ 'server_bind_sig not base32',     undef,               'bad-b32' ],
) {
    my ( $label, $sign_with, $form ) = @$case;
    my ( $b_fh, $b_path )
        = tempfile( 'p7-link-upgrade-XXXXXXXX', TMPDIR => 1, UNLINK => 1 );
    close($b_fh);
    my ( $b_result, $b_died )
        = run_handshake(
        sub { server_ok( shift, $b_path, $sign_with, $form ) } );
    ok( !length( $b_died // '' )
            && ( $b_result->[0] // 1 ) == 0
            && length( $b_result->[1]{'error'} // '' )
            && !exists $b_result->[1]{'shared_secret'},
        "$label : ( 0, { error } ), no secret handed out"
    );
}

{
    ## no context : refused before a single byte is sent ##
    socketpair( my $srv, my $cli, AF_UNIX, SOCK_STREAM, 0 )
        or die "socketpair failed : $OS_ERROR";
    my @r = $handshake->( $cli, { qw| timeout | => 1 } );
    ok( ( $r[0] // 1 ) == 0 && $r[1]{'error'} =~ m{binding context},
        'no binding context : ( 0, { error } )' );
    my $bad = { %{$binding}, qw| server_pub | => 'short' };
    @r = $handshake->( $cli, { qw| timeout | => 1, qw| binding | => $bad } );
    ok( ( $r[0] // 1 ) == 0, 'context with a short server_pub : refused' );
    close($cli);
    $srv->blocking(0);
    my $got = sysread( $srv, my $buf, 64 );
    ok( !$got, 'nothing sent without a valid context' );
    close($srv);
}

say ': wrong answers';

my @wrong_cases = (
    [ 'first line has no OK',                         \&server_refused ],
    [ 'server key is invalid base32',                 \&server_bad_key ],
    [ 'answer to link-pub-key is not SIZE 0',         \&server_bad_size ],
    [ 'answer to encoding is not encoding-confirmed', \&server_bad_encoding ],
    [   'answer to link-complete ' . 'is not link-complete-ok',
        \&server_bad_complete
    ],
);

foreach my $case (@wrong_cases) {
    my ( $label,    $behavior ) = @$case;
    my ( $w_result, $w_died )   = run_handshake($behavior);
    ok( !length( $w_died // '' )
            && ( $w_result->[0] // 1 ) == 0
            && ref $w_result->[1]
            && length( $w_result->[1]{'error'} // '' ),
        "wrong answer [$label] : ( 0, { error } ), no die"
    );
}

say ': silent server';

my $start = time;
my ( $s_result, $s_died ) = run_handshake( \&server_silent );
my $elapsed = time - $start;
ok( !length( $s_died // '' ) && ( $s_result->[0] // 1 ) == 0,
    'silent server : fails instead of hanging' );
ok( $elapsed < 10,
    "silent server : failed within " . "the timeout [ ${elapsed}s ]" );

say ': client_activate on a minimal session';

my $secret = Crypt::Misc::random_bytes(32);
$data{'session'}{7} = {};
my $ok_flag = $activate->(
    7,
    {   qw| shared_secret | => $secret,
        qw| nonce_sid |     => 4242,
    }
);
ok( ( $ok_flag // 0 ) == TRUE, 'client_activate : TRUE' );
ok( ( $data{'session'}{7}{'link_role'} // '' ) eq qw| client |,
    'link_role client recorded' );
ok( ( $data{'session'}{7}{'link_nonce_dir_write'} // 0 ) == 1,
    'client writes direction 1' );
ok( ( $data{'session'}{7}{'link_nonce_dir_read'} // 0 ) == 2,
    'client reads direction 2' );
ok( !exists $data{'session'}{7}{'link_dh_shared_secret'},
    'dh secret deleted after key derivation' );

say ': client_activate input validation';

$data{'session'}{8} = {};
my $bad = $activate->( 8,
    { qw| shared_secret | => 'short', qw| nonce_sid | => 1 } );
ok( ( $bad // 1 ) == FALSE, 'wrong-length secret : FALSE' );
$bad = $activate->( 8, { qw| shared_secret | => $secret } );
ok( ( $bad // 1 ) == FALSE, 'missing nonce sid : FALSE' );
$bad = $activate->(
    99, { qw| shared_secret | => $secret, qw| nonce_sid | => 1 }
);
ok( ( $bad // 1 ) == FALSE, 'unknown session : FALSE' );

say ': encryption.init roles';

$data{'session'}{9} = {
    qw| link_dh_shared_secret | => $secret,
    qw| link_nonce_session_id | => 77,
    qw| link_role |             => qw| server |,
};
my $init_flag = $enc_init->( 9, qw| tcp |, 3 );
ok( ( $init_flag // 0 ) == TRUE, 'server-role encryption.init : TRUE' );
ok( ( $data{'session'}{9}{'link_nonce_dir_write'} // 0 ) == 2
        && ( $data{'session'}{9}{'link_nonce_dir_read'} // 0 ) == 1,
    'server role : write 2, read 1'
);

$data{'session'}{10} = { qw| link_dh_shared_secret | => $secret };
$init_flag = $enc_init->( 10, qw| tcp |, 3 );
ok( ( $init_flag // 0 ) == FALSE, 'no link role : refused' );
ok( ( scalar grep { $ARG->[1] =~ m{link role unknown}o } @logged ) >= 1,
    'no link role : complains' );

$data{'session'}{11} = { qw| link_role | => qw| client | };
$init_flag = $enc_init->( 11, qw| tcp |, 3 );
ok( ( $init_flag // 0 ) == FALSE, 'missing dh secret : refused' );

say ': encrypted frame direction [ bonus ]';

## session 7 was client-activated : writes with direction 1 ##
my $frame_handler_name = sprintf qw| base.handler.link-upgrade.frame-%d |, 7;
my $frame = $code{$frame_handler_name}->('hello protocol-7');
ok( defined $frame && length($frame) > 20, 'frame handler produced a frame' );
my $frame_len = unpack qw| N |, substr( $frame, 0, 4 );
ok( $frame_len == length($frame) - 4, 'frame length prefix matches' );
my $key        = sha256( $secret . pack( qw| N |, 4242 ) );
my $ct_and_tag = substr( $frame,      4 );
my $ct         = substr( $ct_and_tag, 0, length($ct_and_tag) - 16 );
my $tag        = substr( $ct_and_tag, length($ct_and_tag) - 16 );
## the server reads direction 1 with the same key + nonce sid ##
my $nonce_srv
    = pack( qw| N |, 4242 ) . pack( qw| N |, 0 ) . pack( qw| N |, 1 );
my $plain = eval {
    my $cipher = Crypt::AuthEnc::ChaCha20Poly1305->new( $key, $nonce_srv );
    my $data   = $cipher->decrypt_add($ct);
    return $cipher->decrypt_done($tag) ? $data : undef;
};
ok( defined $plain && $plain eq 'hello protocol-7',
    'client frame decrypts with the server read nonce [ direction 1 ]' );
my $nonce_wrong
    = pack( qw| N |, 4242 ) . pack( qw| N |, 0 ) . pack( qw| N |, 2 );
my $dec_ok = eval {
    my $cipher = Crypt::AuthEnc::ChaCha20Poly1305->new( $key, $nonce_wrong );
    $cipher->decrypt_add($ct);
    return $cipher->decrypt_done($tag);
};
ok( !( $dec_ok // 0 ), 'same frame does NOT decrypt with direction 2' );

say ': fail closed [ never plaintext on an encrypted link ]';

my $kept_key = $data{'session'}{7}{'link_encryption_key'};
foreach my $case ( [ 'no key', undef ], [ 'invalid key', 'short' ] ) {
    my ( $label, $bad_key ) = @$case;
    @complaints                                = ();
    $data{'session'}{7}{'shutdown'}            = 0;
    $data{'session'}{7}{'link_encryption_key'} = $bad_key;
    my $out = eval { $code{$frame_handler_name}->('secret text') };
    ok( defined $out && $out eq '',
        "$label : nothing sent, never the plaintext, no die" );
    ok( $data{'session'}{7}{'shutdown'}, "$label : session shut down" );
    ok( scalar( grep {m{not encrypted}o} @complaints ) == 1,
        "$label : complains" );
}
$data{'session'}{7}{'link_encryption_key'} = $kept_key;
$data{'session'}{7}{'shutdown'}            = 0;

say '';
if ($fail_count) {
    say "FAILED : $fail_count check[s]";
    exit 1;
}
say 'all checks passed';
exit 0;

#,,,,,.,,,...,.,.,,,,,,.,,,..,,..,.,.,,,.,,,.,.,.,...,...,,.,,,,.,,,.,,,.,...,
#H4W6BGBTBTQFAKWKN3PMRD4EZHGKMIF7TG3PNN2IIBZNY76FJW2CWLVA3BRDUT2XFN6K3WOH4J35O
#\\\|XNZ7IM2X4CWIMWOIQMFBBSLUX7TVDQNJ27JQLLGFHUATN77AMU3 \ / AMOS7 \ YOURUM ::
#\[7]NRYQLRCGJGMMNM3IEGBODDG2FJY5NSED6R2QGJGAIFRTFUPMSABY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
