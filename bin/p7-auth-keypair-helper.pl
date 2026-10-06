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
use Digest::BMW;
use Fcntl      qw(O_WRONLY O_CREAT O_EXCL);
use File::Path qw(make_path);

## wire v2 [ data/md/design/AUTH-LINK-BINDING.md ] : every argv value of the
## verbs below is PUBLIC [ username, nonce, S_pub, ephemeral pubkeys,
## nonce_sid, encoding, host, port, signatures, delegation ] ; the client's
## secret is loaded from its key file by this helper, never passed in

## host-root delegation [ data/md/design/HOST-ROOT-DELEGATION.md ] : the
## select reply's 4th field. upper bound on its b32 length -- the SAME number
## p-7-r.c uses [ DLG_B32_MAX ]
use constant DLG_LABEL   => "p7 delegation v1\0";
use constant DLG_B32_MAX => 2048;

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
        . "<port> <s_pub> <delegation> [strict]\n  gen-bind    "
        . "<username> <server_nonce> <s_pub> <server_eph> <client_eph> "
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

##[ Host-root delegation [ HOST-ROOT-DELEGATION.md ] ]########################

## the statement bytes [ the spec's pack template ; self-test builds with it ]
sub delegation_statement {
    my ( $issuer_pub, $subject_pub, $name, $not_before, $not_after, $scope )
        = @_;
    die "delegation : issuer \\ subject must be 32 bytes\n"
        unless length($issuer_pub) == 32 and length($subject_pub) == 32;
    return pack(
        'Z* a32 a32 n/a* N N n/a*',
        'p7 delegation v1',
        $issuer_pub, $subject_pub, $name, $not_before, $not_after, $scope
    );
}

## host-root fingerprint : bmw384 of the raw 32 byte public key, b32 [ 77 ]
sub host_root_fingerprint {
    my ($pub) = @_;
    die "fingerprint : expected a 32 byte public key\n"
        unless defined $pub and length($pub) == 32;
    return encode_b32r( Digest::BMW::bmw_384($pub) );
}

## wire bytes [ statement . sig ] -> fields ; dies with a reason. exact parse
## : literal label, every length checked, no trailing bytes
sub parse_delegation {
    my ($wire) = @_;
    my $label = DLG_LABEL;
    die "too short\n"
        unless defined $wire
        and length($wire) >= length($label) + 32 + 32 + 2 + 4 + 4 + 2 + 64;

    my $statement = substr( $wire, 0, length($wire) - 64 );
    my $sig       = substr( $wire, -64 );
    die "wrong label\n"
        unless substr( $statement, 0, length($label) ) eq $label;

    my $pos  = length($label);
    my $take = sub {
        my ($n) = @_;
        die "truncated statement\n" if $pos + $n > length($statement);
        my $bytes = substr( $statement, $pos, $n );
        $pos += $n;
        return $bytes;
    };
    my %dlg;
    $dlg{'issuer_pub'}  = $take->(32);
    $dlg{'subject_pub'} = $take->(32);
    $dlg{'name'}        = $take->( unpack( 'n', $take->(2) ) );
    $dlg{'not_before'}  = unpack( 'N', $take->(4) );
    $dlg{'not_after'}   = unpack( 'N', $take->(4) );
    $dlg{'scope'}       = $take->( unpack( 'n', $take->(2) ) );
    die "trailing bytes in statement\n" if $pos != length($statement);

    $dlg{'statement'} = $statement;
    $dlg{'sig'}       = $sig;
    return \%dlg;
}

## one-hop verify [ anchor = the issuer, scope '*' ] of a delegation for the
## announced S at time now -> ( { fingerprint, name }, undef ) or ( undef,
## reason ). the pin compare is the CALLER's step, after this
sub verify_delegation {
    my ( $wire, $s_pub, $now ) = @_;

    my $dlg = eval { parse_delegation($wire) };
    if ( not defined $dlg ) {
        ( my $why = $@ || 'unparsable' ) =~ s{\s+\z}{};
        return ( undef, "statement $why" );
    }
    return ( undef, 'bad signature' )
        unless Crypt::Ed25519::verify( $dlg->{'statement'},
        $dlg->{'issuer_pub'}, $dlg->{'sig'} );
    return ( undef, 'not_before after not_after' )
        if $dlg->{'not_before'} > $dlg->{'not_after'};
    return ( undef, 'not yet valid' ) if $now < $dlg->{'not_before'};
    return ( undef, 'expired' )       if $now > $dlg->{'not_after'};
    return ( undef, 'subject is not the announced server key' )
        unless length($s_pub) == 32 and $dlg->{'subject_pub'} eq $s_pub;

    ## name : the anchor's scope is '*' [ this step ] -> any name is within it
    ## ; the charset only keeps it safe to print \ log
    return ( undef, 'name not printable' )
        unless $dlg->{'name'} =~ m|^[A-Za-z0-9][A-Za-z0-9._-]{0,254}\z|;
    ## scope : S certifies nothing in this step [ leaf scope must be '' ]
    return ( undef, 'subject scope not empty' )
        unless $dlg->{'scope'} eq '';

    return (
        {   'fingerprint' => host_root_fingerprint( $dlg->{'issuer_pub'} ),
            'name'        => $dlg->{'name'},
        },
        undef
    );
}

## pin store compare [ ONE fingerprint per <host>_<port> file ] -> PIN_VALID \
## PIN_MISMATCH \ PIN_UNPINNED [ strict, nothing written ] \ PIN_NEW [ written
## now, 0600, O_EXCL ]. a pin file that exists but is unreadable \ empty \ not
## a fingerprint -> die [ never re-pinned ]
sub pin_compare {
    my ( $pin_dir, $pin_file, $fingerprint, $strict ) = @_;

    if ( -e $pin_file or -l $pin_file ) {
        open my $fh, '<', $pin_file
            or die "pin file unreadable : $pin_file : $!\n";
        my $pinned = <$fh>;
        close $fh;
        die "pin file empty : $pin_file\n" unless defined $pinned;
        chomp $pinned;
        die "pin file holds a server key, not a host-root fingerprint [ pre "
            . "host-root pin ; verify the host-root out of band, then "
            . "remove it ] : $pin_file\n"
            if $pinned =~ m|^[A-Z2-7]{52}\z|;
        die "pin file corrupt : $pin_file\n"
            unless $pinned =~ m|^[A-Z2-7]{77}\z|;
        return $pinned eq $fingerprint ? 'PIN_VALID' : 'PIN_MISMATCH';
    }

    return 'PIN_UNPINNED' if $strict;

    make_path( $pin_dir, { mode => 0700 } )  unless -d $pin_dir;
    die "cannot create pin dir : $pin_dir\n" unless -d $pin_dir;
    sysopen( my $fh, $pin_file, O_WRONLY | O_CREAT | O_EXCL, 0600 )
        or die "cannot create pin file : $pin_file : $!\n";
    print {$fh} "$fingerprint\n" or die "pin write failed : $!\n";
    close $fh                    or die "pin write failed : $!\n";
    return 'PIN_NEW';
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

## variable length b32 [ 1 .. max chars ], canonical, no padding
sub arg_b32_var {
    my ( $value, $max, $what ) = @_;
    die "$what : expected 1 .. $max b32 chars\n"
        unless defined $value and $value =~ m|^[A-Z2-7]{1,$max}\z|;
    die "$what : invalid b32 length\n"
        unless grep { length($value) % 8 == $ARG } ( 0, 2, 4, 5, 7 );
    my $bin = decode_b32r($value);
    die "$what : b32 decode failed\n"
        unless defined $bin and length($bin);
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

## host-root pin [ HOST-ROOT-DELEGATION.md ] :
## ~/.n/remote-keys/servers/<host>_<port>.public holds the host-root
## FINGERPRINT [ 77 b32 chars ]. the delegation [ select reply field 4 ] is
## verified FIRST [ sig under its issuer pub, not_before <= now <=
## not_after, subject == s_pub, name \ scope ] -- only then the pin :
##   PIN_VALID <fp> <name>     exit 0 [ incl. a rotated S the pinned
##                                      host-root delegates ]
##   PIN_NEW <fp> <name>       exit 0 [ first contact, pinned now ]
##   PIN_UNPINNED <fp> <name>  exit 5 [ strict, nothing written ]
##   PIN_MISMATCH <fp> <name>  exit 6 [ other host-root, never re-pinned ]
##   DELEGATION_INVALID <why>  exit 7 [ nothing read \ written ]
##   PIN_ERROR <why>           exit 8 [ pin file present but unreadable \
##                                      corrupt \ an old S_pub pin ;
##                                      never re-pinned ]
sub op_check_pin {
    my ( $host, $port, $s_pub_b32, $dlg_b32, $mode ) = @_;

    die "Usage: p7-auth-keypair-helper.pl check-pin "
        . "<host> <port> <s_pub> <delegation> [strict]\n"
        unless @_ == 4
        or ( @_ == 5 and defined $mode and $mode eq 'strict' );
    die "host : invalid\n"
        unless defined $host
        and $host =~ m|^[A-Za-z0-9.:-]{1,253}\z|
        and $host =~ m{[A-Za-z0-9]};
    die "port : invalid\n"
        unless defined $port
        and $port =~ m|^[1-9][0-9]{0,4}\z|
        and $port <= 65535;
    my $s_pub = arg_b32( $s_pub_b32, 32, 's_pub' );
    my $dlg   = arg_b32_var( $dlg_b32, DLG_B32_MAX, 'delegation' );
    die "HOME not set\n" unless defined $ENV{HOME} and length $ENV{HOME};

    my ( $verified, $why ) = verify_delegation( $dlg, $s_pub, time() );
    if ( not defined $verified ) {
        print "DELEGATION_INVALID $why\n";
        exit 7;
    }

    ## same file name as auth.client.server_pin.check : lowercase, : -> _
    ( my $host_safe = lc $host ) =~ tr/:/_/;
    my $pin_dir  = "$ENV{HOME}/.n/remote-keys/servers";
    my $pin_file = "$pin_dir/${host_safe}_$port.public";

    my $result = eval {
        pin_compare(
            $pin_dir, $pin_file,
            $verified->{'fingerprint'},
            defined $mode
        );
    };
    if ( not defined $result ) {
        print STDERR $@;
        print 'PIN_ERROR '
            . (
            $@ =~ m{holds a server key}
            ? 'old server key pin'
            : 'pin file unreadable or invalid'
            ) . "\n";
        exit 8;
    }
    print "$result $verified->{'fingerprint'} $verified->{'name'}\n";
    exit(
        {   'PIN_VALID'    => 0,
            'PIN_NEW'      => 0,
            'PIN_UNPINNED' => 5,
            'PIN_MISMATCH' => 6,
        }->{$result}
    );
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

    delegation_self_test( $check, $refused, $s_pub );

    if (@failed) {
        print "self-test FAILED : " . join( ', ', @failed ) . "\n";
        exit 1;
    }
    print "self-test ok\n";
    exit 0;
}

## host-root delegation : the fixed vector, every refusal, the pin store [
## temp dir ] and the real check-pin verb as a subprocess
sub delegation_self_test {
    my ( $check, $refused, $s_pub ) = @_;

    ## SELF-BUILT vector [ lane 3 ; to be replaced by the spec's TEST VECTOR
    ## once lane 1 publishes it ] : host-root = seed 32 x \x03, S = seed 32 x
    ## \x02 [ the AUTH-LINK-BINDING S ], name test-host.cube, not_before
    ## 1700000000, not_after 1702592000 [ + 30 d ], scope ''
    my %want = (
        'root_pub'  => '5VESRRRI2HBMN2XJAM4JAWMVMEUVSJZ2LRR7SNRWYFDBJLEHG7IQ',
        'statement' => '70372064656c65676174696f6e20763100ed4928c628d1c2c6eae'
            . '90338905995612959273a5c63f93636c14614ac8737d181'
            . '39770ea87d175f56a35466c34c7ecccb8d8a91b4ee37a25'
            . 'df60f5b8fc9b394000e746573742d686f73742e63756265'
            . '6553f100657b7e000000',
        'sig' => 'LAL3UIQD4LJVCGNJWXL3TO7DZUD2PCAJ43B2XXPTNWQAQZDDX7G'
            . 'PYH3DYOFIJZUJEUDB2MKQSBZ4HSXBGCQX4GM5LOA4IOSEBMPFQAQ',
        'fingerprint' => 'ZF3ZY24EH66GU56YWPU2R2ZOXZLRVEUQJGHM3A'
            . 'WUQWVUNEJIYFOXRWF4XUSHAAXSUFOXWG2JGKC7G',
    );
    my ( $nb, $na ) = ( 1700000000, 1702592000 );
    my $now = 1701000000;

    my ( $root_pub, $root_priv )
        = Crypt::Ed25519::generate_keypair( "\x03" x 32 );
    my ( $rot_pub, $rot_priv )
        = Crypt::Ed25519::generate_keypair( "\x04" x 32 );
    my ( $foreign_pub, $foreign_priv )
        = Crypt::Ed25519::generate_keypair( "\x05" x 32 );
    $check->( 'host-root pub', encode_b32r($root_pub), $want{'root_pub'} );

    my $wire = sub {
        my ( $ipub, $ipriv, $subject, $from, $to, %opt ) = @_;
        my $st
            = delegation_statement( $ipub, $subject,
            $opt{'name'} // 'test-host.cube',
            $from, $to, $opt{'scope'} // '' );
        return $st . Crypt::Ed25519::sign( $st, $ipub, $ipriv );
    };
    my $statement = delegation_statement( $root_pub, $s_pub,
        'test-host.cube', $nb, $na, '' );
    $check->(
        'delegation statement hex',
        unpack( 'H*', $statement ),
        $want{'statement'}
    );
    $check->(
        'delegation sig',
        encode_b32r(
            Crypt::Ed25519::sign( $statement, $root_pub, $root_priv )
        ),
        $want{'sig'}
    );
    $check->(
        'host-root fingerprint',
        host_root_fingerprint($root_pub),
        $want{'fingerprint'}
    );

    ## the vector through the wire path [ b32 argv check + parse + verify ]
    my $vec_wire
        = arg_b32_var(
        encode_b32r( $statement . arg_b32( $want{'sig'}, 64, 'sig' ) ),
        DLG_B32_MAX, 'delegation' );
    my $verdict = sub {
        my ( $dlg, $subject, $at ) = @_;
        my ( $ok, $why ) = verify_delegation( $dlg, $subject, $at );
        return $ok ? "ok $ok->{'fingerprint'} $ok->{'name'}" : $why;
    };
    my $ok_line = "ok $want{'fingerprint'} test-host.cube";
    $check->(
        'delegation ok',
        $verdict->( $vec_wire, $s_pub, $now ), $ok_line
    );
    $check->(
        'delegation ok at not_before',
        $verdict->( $vec_wire, $s_pub, $nb ), $ok_line
    );
    $check->(
        'delegation ok at not_after',
        $verdict->( $vec_wire, $s_pub, $na ), $ok_line
    );
    $check->(
        'refuse expired',
        $verdict->( $vec_wire, $s_pub, $na + 1 ), 'expired'
    );
    $check->(
        'refuse not yet valid',
        $verdict->( $vec_wire, $s_pub, $nb - 1 ),
        'not yet valid'
    );
    $check->(
        'refuse wrong subject',
        $verdict->( $vec_wire, $rot_pub, $now ),
        'subject is not the announced server key'
    );

    my $bad_sig = $vec_wire;
    substr( $bad_sig, -20, 1 ) ^= "\x01";
    $check->(
        'refuse bad sig',
        $verdict->( $bad_sig, $s_pub, $now ),
        'bad signature'
    );
    my $bad_body = $vec_wire;
    substr( $bad_body, 90, 1 ) ^= "\x01";    ## inside the name
    $check->(
        'refuse altered statement',
        $verdict->( $bad_body, $s_pub, $now ),
        'bad signature'
    );
    $check->(
        'refuse sig by another key',
        $verdict->(
            substr( $vec_wire, 0, -64 )
                . Crypt::Ed25519::sign(
                $statement, $foreign_pub, $foreign_priv
                ),
            $s_pub, $now
        ),
        'bad signature'
    );

    ## structure refusals [ each correctly signed, so only the parser \ field
    ## rule can refuse ]
    my $signed = sub {
        my ( $st, $ipub, $ipriv ) = @_;
        return $st . Crypt::Ed25519::sign( $st, $ipub, $ipriv );
    };
    ( my $other_label = $statement )
        =~ s{^p7 delegation v1}{p7 delegation v2};
    $check->(
        'refuse wrong label',
        $verdict->(
            $signed->( $other_label, $root_pub, $root_priv ), $s_pub,
            $now
        ),
        'statement wrong label'
    );
    $check->(
        'refuse trailing byte',
        $verdict->(
            $signed->( $statement . "\0", $root_pub, $root_priv ),
            $s_pub, $now
        ),
        'statement trailing bytes in statement'
    );
    $check->(
        'refuse truncated statement',
        $verdict->(
            $signed->( substr( $statement, 0, -1 ), $root_pub, $root_priv ),
            $s_pub, $now
        ),
        'statement truncated statement'
    );
    $check->(
        'refuse too short',
        $verdict->( 'x' x 100, $s_pub, $now ),
        'statement too short'
    );
    $check->(
        'refuse not_before after not_after',
        $verdict->(
            $wire->( $root_pub, $root_priv, $s_pub, $na, $nb ),
            $s_pub, $now
        ),
        'not_before after not_after'
    );
    $check->(
        'refuse non-empty subject scope',
        $verdict->(
            $wire->(
                $root_pub, $root_priv, $s_pub, $nb, $na, 'scope' => '*'
            ),
            $s_pub, $now
        ),
        'subject scope not empty'
    );
    $check->(
        'refuse unprintable name',
        $verdict->(
            $wire->(
                $root_pub, $root_priv, $s_pub, $nb, $na,
                'name' => "evil\e[2Jhost.cube"
            ),
            $s_pub, $now
        ),
        'name not printable'
    );
    $check->(
        'refuse delegation b32 too long',
        $refused->(
            sub { arg_b32_var( 'A' x ( DLG_B32_MAX + 1 ), DLG_B32_MAX, 'x' ) }
        ),
        1
    );
    $check->(
        'refuse delegation b32 bad length',
        $refused->( sub { arg_b32_var( 'AAA', DLG_B32_MAX, 'x' ) } ), 1
    );

    ## pin store [ temp dir, never a real key dir ]
    require File::Temp;
    my $tmp      = File::Temp::tempdir( CLEANUP => 1 );
    my $pin_dir  = "$tmp/servers";
    my $pin_file = "$pin_dir/test-host_7.public";
    my $fp       = $want{'fingerprint'};
    my ($rot_ok)
        = verify_delegation(
        $wire->( $root_pub, $root_priv, $rot_pub, $nb, $na ),
        $rot_pub, $now );
    my ($foreign_ok)
        = verify_delegation(
        $wire->( $foreign_pub, $foreign_priv, $s_pub, $nb, $na ),
        $s_pub, $now );

    $check->(
        'pin strict unpinned',
        pin_compare( $pin_dir, $pin_file, $fp, 1 ),
        'PIN_UNPINNED'
    );
    $check->( 'pin strict wrote nothing', ( -e $pin_file ? 1 : 0 ), 0 );
    $check->(
        'pin first contact',
        pin_compare( $pin_dir, $pin_file, $fp, 0 ), 'PIN_NEW'
    );
    $check->(
        'pin file mode 0600',
        sprintf( '%04o', ( stat($pin_file) )[2] & 07777 ), '0600'
    );
    $check->(
        'pin same host-root',
        pin_compare( $pin_dir, $pin_file, $fp, 0 ), 'PIN_VALID'
    );
    $check->(
        'pin rotated S [ same host-root ]',
        ( $rot_ok and $rot_ok->{'fingerprint'} eq $fp )
        ? pin_compare( $pin_dir, $pin_file, $rot_ok->{'fingerprint'}, 0 )
        : 'rotated delegation refused',
        'PIN_VALID'
    );
    $check->(
        'pin refuse wrong fingerprint [ foreign host-root ]',
        $foreign_ok
        ? pin_compare( $pin_dir, $pin_file, $foreign_ok->{'fingerprint'}, 0 )
        : 'foreign delegation refused',
        'PIN_MISMATCH'
    );

    my $old_pin = "$pin_dir/old_7.public";
    open my $ofh, '>', $old_pin or die "cannot write $old_pin : $!\n";
    print {$ofh} encode_b32r($s_pub) . "\n";
    close $ofh;
    $check->(
        'pin refuse an old S_pub pin',
        $refused->( sub { pin_compare( $pin_dir, $old_pin, $fp, 0 ) } ), 1
    );

    ## the real verb, as p-7-r runs it [ temp HOME, times around now ]
    my $self = abs_path(__FILE__);
    my $t    = time();
    my $verb = sub {
        my ( $port, $subject, $dlg, @strict ) = @_;
        local $ENV{HOME} = $tmp;
        open( my $ph, '-|', $EXECUTABLE_NAME, $self, 'check-pin',
            'Test-Host', $port, encode_b32r($subject), encode_b32r($dlg),
            @strict )
            or return 'cannot run';
        my $line = <$ph> // '';
        close $ph;
        chomp $line;
        $line =~ s{ \S+ \S+\z}{}
            if $line =~ m{^PIN_(?:VALID|NEW|UNPINNED|MISMATCH) };
        return sprintf( '%s exit %d', $line, $CHILD_ERROR >> 8 );
    };
    my $live = $wire->( $root_pub, $root_priv, $s_pub, $t - 60, $t + 3600 );
    $check->(
        'check-pin strict unpinned',
        $verb->( 9, $s_pub, $live, 'strict' ),
        'PIN_UNPINNED exit 5'
    );
    $check->(
        'check-pin first contact',
        $verb->( 9, $s_pub, $live ),
        'PIN_NEW exit 0'
    );
    $check->(
        'check-pin second contact',
        $verb->( 9, $s_pub, $live ),
        'PIN_VALID exit 0'
    );
    $check->(
        'check-pin rotated S',
        $verb->(
            9, $rot_pub,
            $wire->( $root_pub, $root_priv, $rot_pub, $t - 60, $t + 3600 )
        ),
        'PIN_VALID exit 0'
    );
    $check->(
        'check-pin foreign host-root',
        $verb->(
            9, $s_pub,
            $wire->(
                $foreign_pub, $foreign_priv, $s_pub, $t - 60, $t + 3600
            )
        ),
        'PIN_MISMATCH exit 6'
    );
    $check->(
        'check-pin expired',
        $verb->(
            9, $s_pub,
            $wire->( $root_pub, $root_priv, $s_pub, $t - 7200, $t - 3600 )
        ),
        'DELEGATION_INVALID expired exit 7'
    );
    $check->(
        'check-pin subject != announced S',
        $verb->( 9, $rot_pub, $live ),
        'DELEGATION_INVALID subject is not the announced server key exit 7'
    );
    $check->(
        'check-pin pin file [ lowercased host ]',
        ( -f "$tmp/.n/remote-keys/servers/test-host_9.public" ? 1 : 0 ), 1
    );
    rename( $old_pin, "$tmp/.n/remote-keys/servers/test-host_10.public" )
        or die "cannot move $old_pin : $!\n";
    $check->(
        'check-pin old S_pub pin',
        do {
            open( my $save, '>&', \*STDERR )            or die "dup : $!\n";
            open( STDERR,   '>',  File::Spec->devnull ) or die "null : $!\n";
            my $got = $verb->( 10, $s_pub, $live );
            open( STDERR, '>&', $save ) or die "restore : $!\n";
            $got;
        },
        'PIN_ERROR old server key pin exit 8'
    );

    return;
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

#,,,,,,..,,,,,...,,,,,...,.,.,...,,,,,...,.,,,..,,...,...,,,,,...,.,,,..,,.,,,
#IQUNA4TDP5AKAKC5MMIOFOUY2GZQGQ4VBD5XIZLF64SYJME56ZBYXMV6XTG5GRKTOL345XWBQVN6O
#\\\|VE4PQMFZEE3CKD7EOS6MB2H3UT4NHXTIJCERQAKJJTW73JR7NB6 \ / AMOS7 \ YOURUM ::
#\[7]XNFLOU6WXUSFUZF6CFGHOTQ5PH6RTE27AP6UPGW4LQX2VJZ6QSAY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
