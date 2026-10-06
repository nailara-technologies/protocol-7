#!/usr/bin/env perl
# Protocol-7 Auth-Keypair Helper for C Client (p-7-r.c)
# Provides auth-keypair credentials (C25519 pubkey + Ed25519 signature)
#
# This helper is called by p-7-r.c via popen() to perform operations
# that are complex to implement directly in C code.

use strict;
use warnings;
use FindBin qw($RealBin);
use File::Spec;
use Cwd qw(abs_path);
use English;

##[ Setup Library Paths ]#####################################################

BEGIN {
    # Add Protocol-7 lib path
    my $up_dir   = File::Spec->updir;
    my $root     = abs_path( File::Spec->catdir( $RealBin, $up_dir ) );
    my $lib_path = File::Spec->catdir( $root, 'data', 'lib-path', 'pm' );

    die "Library path not found: $lib_path\n" unless -d $lib_path;
    unshift @INC, $lib_path;
}

# Import crypto modules
use Crypt::Misc qw(encode_b32r decode_b32r);
use Crypt::PRNG::Fortuna;
use Crypt::Curve25519 qw(curve25519_public_key);
use Crypt::Ed25519;
use IO::AIO;
use Fcntl      qw(O_WRONLY O_CREAT O_EXCL);
use File::Path qw(make_path);

## wire v2 [ data/md/design/AUTH-LINK-BINDING.md ] : every argv value of the
## verbs below is PUBLIC [ username, nonce, S_pub, ephemeral pubkeys,
## nonce_sid, encoding, host, port, signatures ] ; the client's secret is
## loaded from its key file by this helper, never passed in

##[ Main Entry Point ]########################################################

my $operation = shift @ARGV // 'help';

if ( $operation eq 'gen-auth' ) {
    op_gen_auth(@ARGV);
} elsif ( $operation eq 'check-pin' ) {
    op_check_pin(@ARGV);
} elsif ( $operation eq 'gen-bind' ) {
    op_gen_bind(@ARGV);
} elsif ( $operation eq 'verify-bind' ) {
    op_verify_bind(@ARGV);
} elsif ( $operation eq 'self-test' ) {
    op_self_test();
} elsif ( $operation eq 'help'
    || $operation eq '-h'
    || $operation eq '--help' ) {
    print "Usage: p7-auth-keypair-helper.pl <verb> [args]\n  gen-auth    "
        . "<username> <server_nonce> <s_pub>\n  check-pin   <host> "
        . "<port> <s_pub> [strict]\n  gen-bind    <username> "
        . "<server_nonce> <s_pub> <server_eph> <client_eph> "
        . "<nonce_sid> <encoding>\n  verify-bind <server_bind_sig> "
        . "<username> <server_nonce> <s_pub> <server_eph> <client_eph> "
        . "<nonce_sid> <encoding>\n  self-test\n  [ keys \\ nonces \\ "
        . "sigs : b32, RFC 4648, no padding ]\n";
    exit 0;
} else {
    print STDERR "Unknown operation: $operation\n";
    exit 1;
}

##[ Message builders : the ONE place for the pack templates ]#################

sub auth_message {
    my ( $server_nonce, $s_pub, $session_pub, $username ) = @_;
    return pack(
        'Z* a32 a32 a32 n/a*',
        'p7 auth-keypair v2',
        $server_nonce, $s_pub, $session_pub, $username
    );
}

sub bind_transcript {
    my ( $server_nonce, $s_pub, $server_eph, $client_eph, $nonce_sid,
        $encoding, $username )
        = @_;
    return pack( 'a32 a32 a32 a32 N n/a* n/a*',
        $server_nonce, $s_pub, $server_eph, $client_eph, $nonce_sid,
        $encoding,     $username );
}

sub bind_message {
    my ( $role, $transcript ) = @_;
    die "bind role must be client or server\n"
        unless defined $role and $role =~ m{^(?:client|server)\z};
    return pack( 'Z*', "p7 link-bind v1 $role" ) . $transcript;
}

## true only for a 64 byte server_bind_sig valid under s_pub
sub verify_server_bind {
    my ( $sig, $s_pub, $transcript ) = @_;
    return 0 unless length($sig) == 64 and length($s_pub) == 32;
    return Crypt::Ed25519::verify( bind_message( 'server', $transcript ),
        $s_pub, $sig ) ? 1 : 0;
}

##[ Argument checks [ fail closed ] ]#########################################

sub arg_b32 {
    my ( $value, $bytes, $what ) = @_;
    my $chars = int( ( $bytes * 8 + 4 ) / 5 );
    die "$what : expected $chars b32 chars\n"
        unless defined $value and $value =~ m|^[A-Z2-7]{$chars}\z|;
    my $bin = decode_b32r($value);
    die "$what : b32 decode failed\n"
        unless defined $bin and length($bin) == $bytes;
    die "$what : non-canonical b32\n" unless encode_b32r($bin) eq $value;
    return $bin;
}

sub arg_username {
    my ($value) = @_;
    die "username : invalid\n"
        unless defined $value
        and $value =~ m|^[A-Za-z0-9_][A-Za-z0-9._-]{0,63}\z|;
    return $value;
}

sub arg_nonce_sid {
    my ($value) = @_;
    die "nonce_sid : expected 1 .. 4294967295\n"
        unless defined $value
        and $value =~ m|^[1-9][0-9]{0,9}\z|
        and $value <= 4294967295;
    return 0 + $value;
}

sub arg_encoding {
    my ($value) = @_;
    die "encoding : invalid\n"
        unless defined $value and $value =~ m|^[A-Za-z0-9._-]{1,64}\z|;
    return $value;
}

## the binding transcript from the seven public argv fields
sub transcript_from_args {
    my ($username,  $nonce_b32, $s_pub_b32, $s_eph_b32,
        $c_eph_b32, $nonce_sid, $encoding
    ) = @_;
    $username = arg_username($username);
    return (
        $username,
        bind_transcript(
            arg_b32( $nonce_b32, 32, 'server_nonce' ),
            arg_b32( $s_pub_b32, 32, 's_pub' ),
            arg_b32( $s_eph_b32, 32, 'server_eph' ),
            arg_b32( $c_eph_b32, 32, 'client_eph' ),
            arg_nonce_sid($nonce_sid),
            arg_encoding($encoding),
            $username
        )
    );
}

##[ Operations ]##############################################################

sub op_gen_auth {
    my ( $username, $nonce_b32, $s_pub_b32 ) = @_;

    die "Usage: p7-auth-keypair-helper.pl gen-auth "
        . "<username> <server_nonce> <s_pub>\n"
        unless @_ == 3;
    $username = arg_username($username);
    my $server_nonce = arg_b32( $nonce_b32, 32, 'server_nonce' );
    my $s_pub        = arg_b32( $s_pub_b32, 32, 's_pub' );

    my ( $ed25519_secret_bin, $ed25519_pubkey_bin, $ed25519_private_bin )
        = load_client_key($username);

    # Generate ephemeral C25519 keypair for session (new random secret)
    my $prng              = Crypt::PRNG::Fortuna->new();
    my $c25519_secret     = $prng->bytes(32);
    my $c25519_pubkey_bin = curve25519_public_key($c25519_secret);
    die "Failed to generate C25519 keypair\n"
        unless defined $c25519_pubkey_bin && length($c25519_pubkey_bin) == 32;

    # Lock C25519 secret in memory
    IO::AIO::aio_mlock( $c25519_secret, 0, 32 );

    my $c25519_pubkey_b32 = encode_b32r($c25519_pubkey_bin);

    ## v2 auth_sig : binds the server nonce, the announced S_pub, the session
    ## pubkey and the username [ no replay, no other server ]
    my $ed25519_sig_bin = Crypt::Ed25519::sign(
        auth_message( $server_nonce, $s_pub, $c25519_pubkey_bin, $username ),
        $ed25519_pubkey_bin,    # signer's public key (32 bytes)
        $ed25519_private_bin    # signer's private key (64 bytes)
    );
    die "Failed to generate Ed25519 signature\n"
        unless defined $ed25519_sig_bin && length($ed25519_sig_bin) == 64;
    my $ed25519_sig_b32 = encode_b32r($ed25519_sig_bin);

    # Output credentials (one per line)
    print "$c25519_pubkey_b32\n";
    print "$ed25519_sig_b32\n";

    # Securely wipe sensitive key material from memory before exit
    # Overwrite with random data to prevent key recovery from memory dumps
    erase_buffer_secure( \$ed25519_secret_bin );
    erase_buffer_secure( \$ed25519_private_bin );
    erase_buffer_secure( \$c25519_secret );

    exit 0;
}

## the client identity key C [ <user>.base ] : ( seed, pub, private )
sub load_client_key {
    my ($username) = @_;

    die "HOME not set\n" unless defined $ENV{HOME} and length $ENV{HOME};
    my $key_dir = "$ENV{HOME}/.n/user-keys";
    die "Key directory not found: $key_dir\n" unless -d $key_dir;

    # Load user's Ed25519 secret key
    my $ed25519_secret_file = "$key_dir/$username.base.secret";
    die "Ed25519 secret not " . "found: $ed25519_secret_file\n"
        unless -f $ed25519_secret_file;

    open my $fh, '<', $ed25519_secret_file
        or die "Cannot read " . "secret key: $!\n";
    my $ed25519_secret_b32 = <$fh>;
    close $fh;
    die "Empty secret key file\n" unless defined $ed25519_secret_b32;
    chomp $ed25519_secret_b32;

    # Decode base32 secret to binary
    my $ed25519_secret_bin = decode_b32r($ed25519_secret_b32);
    erase_buffer_secure( \$ed25519_secret_b32 );
    die "Failed to decode Ed25519 secret\n"
        unless defined $ed25519_secret_bin
        && length($ed25519_secret_bin) >= 34;

    # Strip the 2-byte format prefix
    substr( $ed25519_secret_bin, 0, 2, '' );
    die "Failed to strip " . "format prefix\n"
        unless length($ed25519_secret_bin) == 32;

   # Generate Ed25519 keypair from secret (same as load_keys_from_secret does)
    my ( $ed25519_pubkey_bin, $ed25519_private_bin )
        = Crypt::Ed25519::generate_keypair($ed25519_secret_bin);
    die "Failed to generate Ed25519 keypair from secret\n"
        unless defined $ed25519_pubkey_bin && defined $ed25519_private_bin;
    die "Invalid public " . "key length\n"
        unless length($ed25519_pubkey_bin) == 32;
    die "Invalid private " . "key length\n"
        unless length($ed25519_private_bin) == 64;

    # Lock Ed25519 secret and private key in memory to prevent swapping
    IO::AIO::aio_mlock( $ed25519_secret_bin,  0, 32 );
    IO::AIO::aio_mlock( $ed25519_private_bin, 0, 64 );

    return ( $ed25519_secret_bin, $ed25519_pubkey_bin, $ed25519_private_bin );
}

## server key pin [ TOFU ] : ~/.n/remote-keys/servers/<host>_<port>.public
## holds the S_pub b32 line. first contact pins [ PIN_NEW, exit 0 ] ; match ->
## PIN_VALID exit 0 ; mismatch -> PIN_MISMATCH exit 6 [ never re-pinned ] ;
## strict + no pin -> PIN_UNPINNED exit 5 [ nothing written ] ; pin file
## present but unreadable \ corrupt -> die [ exit != 0 ]
sub op_check_pin {
    my ( $host, $port, $s_pub_b32, $mode ) = @_;

    die "Usage: p7-auth-keypair-helper.pl "
        . "check-pin <host> <port> <s_pub> [strict]\n"
        unless @_ == 3
        or ( @_ == 4 and defined $mode and $mode eq 'strict' );
    die "host : invalid\n"
        unless defined $host
        and $host =~ m|^[A-Za-z0-9.:-]{1,253}\z|
        and $host =~ m{[A-Za-z0-9]};
    die "port : invalid\n"
        unless defined $port
        and $port =~ m|^[1-9][0-9]{0,4}\z|
        and $port <= 65535;
    arg_b32( $s_pub_b32, 32, 's_pub' );
    die "HOME not set\n" unless defined $ENV{HOME} and length $ENV{HOME};

    ## same file name as auth.client.server_pin.check : lowercase, : -> _
    ( my $host_safe = lc $host ) =~ tr/:/_/;
    my $pin_dir  = "$ENV{HOME}/.n/remote-keys/servers";
    my $pin_file = "$pin_dir/${host_safe}_$port.public";

    if ( -e $pin_file or -l $pin_file ) {
        open my $fh, '<', $pin_file
            or die "pin file unreadable : $pin_file : $!\n";
        my $pinned = <$fh>;
        close $fh;
        die "pin file empty : $pin_file\n" unless defined $pinned;
        chomp $pinned;
        die "pin file corrupt : $pin_file\n"
            unless $pinned =~ m|^[A-Z2-7]{52}\z|;
        if ( $pinned eq $s_pub_b32 ) {
            print "PIN_VALID\n";
            exit 0;
        }
        print "PIN_MISMATCH\n";
        exit 6;
    }

    if ( defined $mode ) {
        print "PIN_UNPINNED\n";
        exit 5;
    }

    make_path( $pin_dir, { mode => 0700 } )  unless -d $pin_dir;
    die "cannot create pin dir : $pin_dir\n" unless -d $pin_dir;
    sysopen( my $fh, $pin_file, O_WRONLY | O_CREAT | O_EXCL, 0600 )
        or die "cannot create pin file : $pin_file : $!\n";
    print {$fh} "$s_pub_b32\n" or die "pin write failed : $!\n";
    close $fh                  or die "pin write failed : $!\n";

    ## fingerprint = the full S_pub b32
    print "PIN_NEW $s_pub_b32\n";
    exit 0;
}

## client_bind_sig b32 for the transcript given on argv [ public fields ]
sub op_gen_bind {
    die "Usage: p7-auth-keypair-helper.pl gen-bind <username> <server_nonce> "
        . "<s_pub> <server_eph> <client_eph> <nonce_sid> <encoding>\n"
        unless @_ == 7;
    my ( $username, $transcript ) = transcript_from_args(@_);

    my ( $secret, $pub, $private ) = load_client_key($username);
    my $sig = Crypt::Ed25519::sign( bind_message( 'client', $transcript ),
        $pub, $private );
    erase_buffer_secure( \$secret );
    erase_buffer_secure( \$private );

    die "Failed to generate bind signature\n"
        unless defined $sig and length($sig) == 64;
    print encode_b32r($sig) . "\n";
    exit 0;
}

## server_bind_sig check against the [ pinned ] s_pub : BIND_OK exit 0,
## anything else BIND_FAIL exit 1 [ argument errors die, exit != 0 ]
sub op_verify_bind {
    die "Usage: p7-auth-keypair-helper.pl verify-bind <server_bind_sig> "
        . "<username> <server_nonce> <s_pub> <server_eph> <client_eph> "
        . "<nonce_sid> <encoding>\n"
        unless @_ == 8;
    my ( $sig_b32, @fields ) = @_;
    my $sig = arg_b32( $sig_b32, 64, 'server_bind_sig' );
    my ( undef, $transcript ) = transcript_from_args(@fields);
    my $s_pub = arg_b32( $fields[2], 32, 's_pub' );

    if ( verify_server_bind( $sig, $s_pub, $transcript ) ) {
        print "BIND_OK\n";
        exit 0;
    }
    print "BIND_FAIL\n";
    exit 1;
}

## spec test vector [ AUTH-LINK-BINDING.md ] through the same builders, plus
## negative cases ; exit 1 on any mismatch
sub op_self_test {
    my %want = (
        'c_pub'    => 'RKEOHXLUBHYZL7KS3MWTZOS5OLFGOCN7DWKBEG7TOSEADNAPN5OA',
        's_pub'    => 'QE4XODVIPULV6VVDKRTMGTD6ZTFY3CURWTXDPIS56YHVXD6JWOKA',
        'auth_msg' => '703720617574682d6b657970616972207632001111111111111111'
            . '111111111111111111111111111111111111111111111111'
            . '8139770ea87d175f56a35466c34c7ecccb8d8a91b4ee37a2'
            . '5df60f5b8fc9b39422222222222222222222222222222222'
            . '222222222222222222222222222222220009746573742d75'
            . '736572',
        'auth_sig' => 'NJHBPUDRFYSLYCCZ57DJN5OVNOIWSNWGU7QZZJU26ZT445Q3PBQOUC'
            . 'UQS36W5KFEFYIBSDSY4XZD6FCWC6TETBCBSQWI7ICVRMTCUC' . 'I',
        'transcript' => '1111111111111111111111111111111111111111111111111111'
            . '1111111111118139770ea87d175f56a35466c34c7ecccb'
            . '8d8a91b4ee37a25df60f5b8fc9b3943333333333333333'
            . '3333333333333333333333333333333333333333333333'
            . '3344444444444444444444444444444444444444444444'
            . '444444444444444444441234567800046e6f6e65000974'
            . '6573742d75736572',
        'client_bind_sig' =>
            'ANRNMKHTKZ6QDI2EJOUZYXZSNKLQQY3TF57NXSNREYEX3PDVL6K'
            . 'EVQ2LLLTS3V26U4GSKYVC6XCFO2U7BU5JQXEGLHCGPKDJ6HLYSDA',
        'server_bind_sig' =>
            'KLXXZEZPHTKESLFK7NLYD4VZBXWEEP3WQG4T62UKGIFHNUOUW3A'
            . '7ZEVM4BIFC5TQUW3DJJG37XQYJRZFSVXWHPYZZYJ5RWJDVPKHUDA',
    );

    my @failed;
    my $check = sub {
        my ( $name, $got, $expected ) = @_;
        if ( defined $got and $got eq $expected ) {
            print "ok   $name\n";
        } else {
            print "FAIL $name\n  got  "
                . ( $got // 'undef' )
                . "\n  want $expected\n";
            push @failed, $name;
        }
    };

    ## throwaway test keys [ fixed seeds, never real ]
    my ( $c_pub, $c_private )
        = Crypt::Ed25519::generate_keypair( "\x01" x 32 );
    my ( $s_pub, $s_private )
        = Crypt::Ed25519::generate_keypair( "\x02" x 32 );
    $check->( 'c_pub', encode_b32r($c_pub), $want{'c_pub'} );
    $check->( 's_pub', encode_b32r($s_pub), $want{'s_pub'} );

    my $auth_msg
        = auth_message( "\x11" x 32, $s_pub, "\x22" x 32, 'test-user' );
    $check->( 'auth_msg hex', unpack( 'H*', $auth_msg ), $want{'auth_msg'} );
    $check->(
        'auth_sig',
        encode_b32r( Crypt::Ed25519::sign( $auth_msg, $c_pub, $c_private ) ),
        $want{'auth_sig'}
    );

    ## transcript through the argv path [ covers argument decoding too ]
    my ( undef, $transcript ) = transcript_from_args(
        'test-user',                encode_b32r( "\x11" x 32 ),
        encode_b32r($s_pub),        encode_b32r( "\x33" x 32 ),
        encode_b32r( "\x44" x 32 ), '305419896',
        'none'
    );
    $check->(
        'transcript hex',
        unpack( 'H*', $transcript ),
        $want{'transcript'}
    );

    my $client_sig
        = Crypt::Ed25519::sign( bind_message( 'client', $transcript ),
        $c_pub, $c_private );
    my $server_sig
        = Crypt::Ed25519::sign( bind_message( 'server', $transcript ),
        $s_pub, $s_private );
    $check->(
        'client_bind_sig',
        encode_b32r($client_sig),
        $want{'client_bind_sig'}
    );
    $check->(
        'server_bind_sig',
        encode_b32r($server_sig),
        $want{'server_bind_sig'}
    );

    ## verify path [ the same sub verify-bind uses ]
    my $server_sig_vec = arg_b32( $want{'server_bind_sig'}, 64, 'sig' );
    $check->(
        'verify server_bind_sig',
        verify_server_bind( $server_sig_vec, $s_pub, $transcript ), 1
    );

    my $flipped = $transcript;
    substr( $flipped, 40, 1 ) ^= "\x01";
    $check->(
        'reject flipped transcript byte',
        verify_server_bind( $server_sig_vec, $s_pub, $flipped ), 0
    );
    my $bad_sig = $server_sig_vec;
    substr( $bad_sig, 7, 1 ) ^= "\x80";
    $check->(
        'reject flipped sig byte',
        verify_server_bind( $bad_sig, $s_pub, $transcript ), 0
    );
    $check->(
        'reject client sig as server sig',
        verify_server_bind( $client_sig, $c_pub, $transcript ), 0
    );
    $check->(
        'reject server sig under wrong key',
        verify_server_bind( $server_sig_vec, $c_pub, $transcript ), 0
    );

    ## argument checks fail closed
    my $refused = sub {
        my ($code) = @_;
        return eval { $code->(); 1 } ? 0 : 1;
    };
    $check->(
        'refuse nonce_sid ' . '0',
        $refused->( sub { arg_nonce_sid('0') } ), 1
    );
    $check->(
        'refuse nonce_sid 2**32',
        $refused->( sub { arg_nonce_sid('4294967296') } ), 1
    );
    $check->(
        'refuse short b32',
        $refused->( sub { arg_b32( substr( $want{'s_pub'}, 1 ), 32, 'x' ) } ),
        1
    );
    $check->(
        'refuse b32 shell chars',
        $refused->( sub { arg_b32( '$(id)' . ( 'A' x 47 ), 32, 'x' ) } ), 1
    );
    $check->(
        'refuse username slash',
        $refused->( sub { arg_username('../x') } ), 1
    );

    if (@failed) {
        print "self-test FAILED : " . join( ', ', @failed ) . "\n";
        exit 1;
    }
    print "self-test ok\n";
    exit 0;
}

##[ Helper: Secure buffer erasure ]###########################################

sub erase_buffer_secure {
    my ($buffer_sref) = @_;
    return 0 unless ref $buffer_sref eq 'SCALAR';
    return 0 unless defined $buffer_sref->$*;

    my $len = length( $buffer_sref->$* );
    return 0 if $len == 0;

    # Overwrite with random data multiple times for security
    my $prng = Crypt::PRNG::Fortuna->new();
    substr( $buffer_sref->$*, 0, $len, $prng->bytes($len) );
    substr( $buffer_sref->$*, 0, $len, $prng->bytes($len) );

    # Truncate to zero
    $buffer_sref->$* = '';

    return $len;
}

#,,..,.,.,,,.,...,,,.,.,,,.,,,,,.,.,.,,,,,.,,,..,,...,...,...,,,,,,..,..,,,,,,
#TBFHEQH6ZB7Z22VBHQNRLL5UZJNESBGZ337J44GUSCMA2LMOHJ4NNRB6KME237NCSIH7RYWFXFW6A
#\\\|ZG4ZNNYEA6XQR4JHZJ46H6J6GRGPGTTGLG2I4AJ6LVELGJPM5FG \ / AMOS7 \ YOURUM ::
#\[7]I63AW33MAW4AERR4XMZS3PCLJBCM6MWNMJAC6WOSS2PUSSV67OBA 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
