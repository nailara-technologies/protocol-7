#!/usr/bin/env perl
# Protocol-7 Link-Upgrade Helper for C Client (p7.c)
# Provides crypto operations for client-side link-upgrade encryption
#
# This helper is called by p7.c via popen() to perform operations
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
use Crypt::Misc;
use Crypt::AuthEnc::ChaCha20Poly1305;
use Crypt::Curve25519;
use Digest::SHA qw(sha256);
use AMOS7;    # For key derivation functions

##[ Main Entry Point ]########################################################

my $operation = shift @ARGV // 'help';

if ( $operation eq 'gen-ephemeral' ) {
    op_gen_ephemeral();
} elsif ( $operation eq 'compute-dh' ) {
    op_compute_dh();
} elsif ( $operation eq 'derive-key' ) {
    op_derive_key();
} elsif ( $operation eq 'encrypt' ) {
    op_encrypt();
} elsif ( $operation eq 'decrypt' ) {
    op_decrypt();
} elsif ( $operation eq 'self-test' ) {
    op_self_test();
} elsif ( $operation eq 'help'
    || $operation eq '-h'
    || $operation eq '--help' ) {
    show_help();
} else {
    die "Unknown operation: $operation\n";
}

exit 0;

##[ Operations ]##############################################################

sub op_gen_ephemeral {

    # Generate ephemeral C25519 keypair for client
    # Returns: base32(pubkey) on line 1, base32(secret) on line 2

    # Generate a random secret (32 bytes for Curve25519)
    my $secret = Crypt::Misc::random_bytes(32);

    # Compute public key from secret
    my $pubkey = Crypt::Curve25519::curve25519_public_key($secret);

    die "Failed to generate ephemeral keypair\n"
        unless $secret
        and $pubkey
        and length($secret) == 32
        and length($pubkey) == 32;

    # Output in base32 format for easy transmission
    print Crypt::Misc::encode_b32r($pubkey) . "\n";
    print Crypt::Misc::encode_b32r($secret) . "\n";
}

sub op_compute_dh {

    # Compute Diffie-Hellman shared secret using Curve25519
    # argv  : server_pubkey_b32 [ public ]
    # stdin : client_secret_b32 line [ secret -- never argv ]
    # Returns: base32(shared_secret)

    die "Usage: $0 compute-dh <server_pubkey_b32> < client_secret_b32\n"
        unless @ARGV == 1;
    my $server_pubkey_b32 = shift @ARGV;
    my $client_secret_b32 = read_secret_line('client_secret');

    # Decode from base32
    my $client_secret = Crypt::Misc::decode_b32r($client_secret_b32);
    my $server_pubkey = Crypt::Misc::decode_b32r($server_pubkey_b32);
    die "server_pubkey : expected 32 bytes b32\n"
        unless defined $server_pubkey and length($server_pubkey) == 32;

    # Compute DH shared secret using Curve25519
    my $shared_secret
        = Crypt::Curve25519::curve25519_shared_secret( $client_secret,
        $server_pubkey );

    die "Failed to compute DH shared secret\n"
        unless $shared_secret and length($shared_secret) == 32;

    # Return in base32 format
    print Crypt::Misc::encode_b32r($shared_secret) . "\n";
}

sub op_derive_key {

    # Derive encryption key from shared secret
    # argv  : session_id [ public ]
    # stdin : shared_secret_b32 line [ secret -- never argv ]
    # Returns: base32(encryption_key)
    #
    # Uses simple SHA256-based KDF: key = SHA256(shared_secret || session_id)
    # For production, this should use a proper KDF like PBKDF2

    die "Usage: $0 derive-key <session_id> < shared_secret_b32\n"
        unless @ARGV == 1 and $ARGV[0] =~ m|^[0-9]{1,10}\z|;
    my $session_id        = shift @ARGV;
    my $shared_secret_b32 = read_secret_line('shared_secret');

    # Decode shared secret
    my $shared_secret = Crypt::Misc::decode_b32r($shared_secret_b32);

    # Derive encryption key: SHA256(shared_secret || session_id)
    # This produces a 32-byte key suitable for ChaCha20-Poly1305
    my $key = sha256( $shared_secret . pack( 'N', $session_id ) );

    die "Failed to derive encryption key\n"
        unless $key and length($key) == 32;

    # Return in base32 format
    print Crypt::Misc::encode_b32r($key) . "\n";
}

## argv of encrypt \ decrypt : session_id counter direction [ all public ]
sub frame_args {
    my ($verb) = @_;
    die "Usage: $0 $verb <session_id> <counter> "
        . "<direction> < key_b32 line + data\n"
        unless @ARGV == 3
        and $ARGV[0] =~ m|^[0-9]{1,10}\z|
        and $ARGV[1] =~ m|^[0-9]{1,10}\z|
        and $ARGV[2] =~ m{^[12]\z};
    return @ARGV;
}

sub op_encrypt {

    # Encrypt message with ChaCha20-Poly1305
    # argv  : session_id counter direction [ public ]
    # stdin : key_b32 line [ secret -- never argv ], then the plaintext
    # Returns: ciphertext + auth_tag (binary) on stdout

    # direction : 1 client -> server, 2 server -> client
    my ( $session_id, $counter, $direction ) = frame_args('encrypt');

    # key line first, then the plaintext [ rest of stdin, binary ]
    my $key_b32   = read_secret_line('key');
    my $plaintext = read_rest_of_stdin();

    # Decode key from base32
    my $key = Crypt::Misc::decode_b32r($key_b32);

    # Generate nonce: 4-byte session_id + 4-byte counter + 4-byte direction
    # [ both directions share one key : the direction keeps the client's
    #   and the server's frame k from reusing key + nonce ]
    my $nonce
        = pack( 'N', $session_id )
        . pack( 'N', $counter )
        . pack( 'N', $direction );

    # Create cipher and encrypt
    my $cipher     = Crypt::AuthEnc::ChaCha20Poly1305->new( $key, $nonce );
    my $ciphertext = $cipher->encrypt_add($plaintext);
    my $auth_tag   = $cipher->encrypt_done();

    # Output binary ciphertext + auth_tag
    # Note: This is binary data, not base32
    binmode STDOUT;
    print STDOUT $ciphertext . $auth_tag;
}

sub op_decrypt {

    # Decrypt message with ChaCha20-Poly1305
    # argv  : session_id counter direction [ public ]
    # stdin : key_b32 line [ secret -- never argv ], then ciphertext + tag
    # Returns: plaintext on stdout (or error on stderr)

    # direction : 1 client -> server, 2 server -> client
    my ( $session_id, $counter, $direction ) = frame_args('decrypt');

    # key line first, then ciphertext + tag [ rest of stdin, binary ]
    my $key_b32             = read_secret_line('key');
    my $ciphertext_with_tag = read_rest_of_stdin();
    die "ciphertext shorter than the auth tag\n"
        unless length($ciphertext_with_tag) >= 16;

    # Decode key from base32
    my $key = Crypt::Misc::decode_b32r($key_b32);

    # Extract auth tag (last 16 bytes) and ciphertext
    my $auth_tag   = substr( $ciphertext_with_tag, -16 );
    my $ciphertext = substr( $ciphertext_with_tag, 0, -16 );

    # Generate nonce: 4-byte session_id + 4-byte counter + 4-byte direction
    # [ both directions share one key : the direction keeps the client's
    #   and the server's frame k from reusing key + nonce ]
    my $nonce
        = pack( 'N', $session_id )
        . pack( 'N', $counter )
        . pack( 'N', $direction );

    # Create cipher and decrypt
    my $cipher    = Crypt::AuthEnc::ChaCha20Poly1305->new( $key, $nonce );
    my $plaintext = $cipher->decrypt_add($ciphertext);
    my $success   = $cipher->decrypt_done($auth_tag);

    # Output plaintext or error
    if ($success) {
        binmode STDOUT;
        print STDOUT $plaintext;
        exit 0;
    } else {
        die "Authentication tag verification failed\n";
    }
}

##[ Stdin : secrets never travel on argv ]####################################

## first stdin line : one 32 byte secret, b32 [ 52 chars ]
sub read_secret_line {
    my ($what) = @_;
    binmode STDIN;
    my $line = <STDIN>;
    die "$what : expected b32 line on stdin\n" unless defined $line;
    chomp $line;
    die "$what : expected 52 b32 chars on stdin\n"
        unless $line =~ m|^[A-Z2-7]{52}\z|;
    return $line;
}

sub read_rest_of_stdin {
    local $INPUT_RECORD_SEPARATOR = undef;
    my $rest = <STDIN>;
    return $rest // '';
}

##[ Self-test : stdin verbs == the old argv verbs ]###########################

## golden values captured from the PREVIOUS argv form [ compute-dh <secret>
## <pub>, derive-key <shared> <sid>, encrypt \ decrypt <key> ... ] with fixed
## inputs ; the verbs below run as real subprocesses with the secret on stdin
## and must reproduce them byte for byte
sub op_self_test {
    require IPC::Open2;

    my $self = File::Spec->catfile( $RealBin, $FindBin::RealScript );
    my %in   = (
        'client_secret' =>
            'O53XO53XO53XO53XO53XO53XO53XO53XO53XO53XO53XO53XO53Q',
        'server_pubkey' =>
            'EGPE3AANVFUNFJP4WAE4PBHUORWHCOHNXHXEQRFXHHUDBMC46QSA',
        'session_id' => '305419896',
        'counter'    => '7',
        'plaintext'  => "p7 self-test frame\n",
    );
    my %want = (
        'shared' => '6UJXJ5J5E2Y7QO2LZT6DBNOGBGV4VL55S7BQCR4UY62FYQVB6BMQ',
        'key'    => 'JFTCOSIFTQDJGBNTSREIC3JUL6MDYUO56IMRYBS4SP7ICPCAEFXA',
        'enc 1'  => 'b1ec0355e130517646160cb6f68b205527c'
            . '5339a9d44f688544b887ae7cf498d4d6217',
        'enc 2' => '15375703f04f3b766b8317abc9622d7b824'
            . 'd2427838de9b828c26beeba890e33825310',
    );

    ## run this helper : ( exit status, stdout )
    my $run = sub {
        my ( $stdin, @args ) = @_;
        my $pid = IPC::Open2::open2( my $out, my $in, $EXECUTABLE_NAME,
            $self, @args );
        binmode $in;
        binmode $out;
        print {$in} $stdin;
        close $in;
        my $got = do { local $INPUT_RECORD_SEPARATOR = undef; <$out> };
        close $out;
        waitpid( $pid, 0 );
        return ( $CHILD_ERROR >> 8, $got // '' );
    };

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

    my ( $rc, $got )
        = $run->( "$in{'client_secret'}\n", 'compute-dh',
        $in{'server_pubkey'} );
    $check->(
        'compute-dh [ secret on stdin ]',
        "$rc $got",
        "0 $want{'shared'}\n"
    );

    ( $rc, $got )
        = $run->( "$want{'shared'}\n", 'derive-key', $in{'session_id'} );
    $check->(
        'derive-key [ secret on stdin ]',
        "$rc $got", "0 $want{'key'}\n"
    );

    my %ct;
    foreach my $direction ( 1, 2 ) {
        ( $rc, $ct{$direction} ) = $run->(
            "$want{'key'}\n$in{'plaintext'}",
            'encrypt', $in{'session_id'}, $in{'counter'}, $direction
        );
        $check->(
            "encrypt direction $direction [ key on stdin ]",
            "$rc " . unpack( 'H*', $ct{$direction} ),
            "0 $want{qq|enc $direction|}"
        );
    }

    ( $rc, $got ) = $run->(
        "$want{'key'}\n$ct{1}", 'decrypt', $in{'session_id'},
        $in{'counter'},         1
    );
    $check->(
        'decrypt round trip [ key on stdin ]',
        "$rc $got",
        "0 $in{'plaintext'}"
    );

    ## a flipped tag must fail [ exit != 0, no plaintext ]
    my $bad = $ct{1};
    substr( $bad, -1, 1 ) ^= "\x01";
    ( $rc, $got ) = $run->(
        "$want{'key'}\n$bad", 'decrypt', $in{'session_id'}, $in{'counter'}, 1
    );
    $check->(
        'decrypt refuses a flipped tag',
        ( $rc != 0 and $got eq '' ) ? 1 : 0, 1
    );

    ## the old argv forms [ secret first ] are refused, not misread
    ( $rc, $got )
        = $run->( '', 'compute-dh', $in{'client_secret'},
        $in{'server_pubkey'} );
    $check->( 'old compute-dh argv form refused', $rc != 0 ? 1 : 0, 1 );
    ( $rc, $got )
        = $run->( '', 'derive-key', $want{'shared'}, $in{'session_id'} );
    $check->( 'old derive-key argv form refused', $rc != 0 ? 1 : 0, 1 );
    ( $rc, $got ) = $run->(
        $in{'plaintext'}, 'encrypt', $want{'key'}, $in{'session_id'},
        $in{'counter'},   1
    );
    $check->( 'old encrypt argv form refused', $rc != 0 ? 1 : 0, 1 );

    if (@failed) {
        print "self-test FAILED : " . join( ', ', @failed ) . "\n";
        exit 1;
    }
    print "self-test ok\n";
    exit 0;
}

##[ Help ]####################################################################

sub show_help {
    print <<'EOF';
Protocol-7 Link-Upgrade Helper for p-7-r.c

Usage: p7-link-upgrade-helper.pl <operation> [args]

secrets NEVER travel on argv [ /proc/<pid>/cmdline is world-readable ] :
each secret is the first stdin line [ b32, 52 chars ]

Operations:

  gen-ephemeral
    Generate ephemeral C25519 keypair for client
    Output: Two lines (base32 encoded)
            Line 1: Public key
            Line 2: Secret/Private key

  compute-dh <server_pubkey_b32>      stdin : client_secret_b32 line
    Compute Diffie-Hellman shared secret
    Output: Shared secret (base32)

  derive-key <session_id>             stdin : shared_secret_b32 line
    Derive ChaCha20 encryption key from shared secret
    Output: Encryption key (base32)

  encrypt <session_id> <counter> <direction>
                                      stdin : key_b32 line, then plaintext
    Encrypt message with ChaCha20-Poly1305
    Output: Ciphertext + Auth Tag (binary)

  decrypt <session_id> <counter> <direction>
                                      stdin : key_b32 line, then
                                              ciphertext + tag
    Decrypt message with ChaCha20-Poly1305
    Output: Plaintext (binary) ; exit != 0 on auth tag failure

  self-test
    stdin verbs reproduce the golden outputs of the former argv forms

direction : 1 client -> server, 2 server -> client

EOF
    exit 0;
}

__END__

=head1 NAME

p7-link-upgrade-helper.pl - Cryptographic helper for p-7-r.c link-upgrade

=head1 SYNOPSIS

    p7-link-upgrade-helper.pl gen-ephemeral
    p7-link-upgrade-helper.pl compute-dh <server_pubkey_b32>  < client_secret_b32
    p7-link-upgrade-helper.pl derive-key <session_id>         < shared_secret_b32
    p7-link-upgrade-helper.pl encrypt <session_id> <counter> <direction> < key_b32 + data
    p7-link-upgrade-helper.pl decrypt <session_id> <counter> <direction> < key_b32 + data
    p7-link-upgrade-helper.pl self-test

=head1 DESCRIPTION

Cryptographic operations for the p-7-r.c Protocol-7 client link-upgrade.
Public values come from argv ; every secret [ client ephemeral secret,
DH shared secret, link key ] is read as the first line of stdin, so it
never appears in /proc/<pid>/cmdline. p-7-r.c runs this helper without
a shell [ fork + execv ] and writes the secret into a pipe.

=head1 NONCE GENERATION

  pack('N', session_id) . pack('N', counter) . pack('N', direction)
  = 12 bytes [ direction 1 client -> server, 2 server -> client ]

=head1 LICENSE

As per Protocol-7

=cut

#,,,,,,..,,.,,,,.,...,,..,..,,...,.,,,,,,,.,,,..,,...,...,...,...,,,,,,,,,,.,,
#VLM25YCB22D3PO6S7VL26TYB52Z5NGXGHDJAF4ARFJQTQWW5J3DY6LIDABJX25KJJUP7TPNWWCS6C
#\\\|SI442OQQCIYBQFCUKWMAP4V5ESGAQOQANTWYJJLHU4IWIHJKHJT \ / AMOS7 \ YOURUM ::
#\[7]KPWN5ERHMMQZUBAQWPRW7QHID566XFWOJVIUYFVGTWQKHYG5Q6AQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
