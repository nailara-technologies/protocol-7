#!/usr/bin/env perl
# Protocol-7 TOFU Helper for C Client (p-7-r.c)
# Performs Trust-On-First-Use validation for remote server public keys
#
# This helper is called by p-7-r.c via popen() to perform TOFU operations
# that are complex to implement directly in C code.

use strict;
use warnings;
use FindBin qw($RealBin);
use File::Spec;
use Cwd qw(abs_path);
use English;

##[ Setup Library Paths ]#######################################################

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
use File::Spec::Functions qw(catfile);

##[ Main Entry Point ]##########################################################

my $operation = shift @ARGV // 'help';

if ( $operation eq 'validate' ) {
    op_validate_tofu();
} elsif ( $operation eq 'help' || $operation eq '-h' || $operation eq '--help' ) {
    print "Usage: p7-tofu-helper.pl validate <hostname> <port> <server_pubkey_b32>\n";
    exit 0;
} else {
    print STDERR "Unknown operation: $operation\n";
    exit 1;
}

##[ Operations ]################################################################

sub op_validate_tofu {
    my $hostname = shift @ARGV;
    my $port = shift @ARGV;
    my $server_pubkey_b32 = shift @ARGV;

    die "Usage: p7-tofu-helper.pl validate <hostname> <port> <server_pubkey_b32>\n"
        unless defined $hostname && defined $port && defined $server_pubkey_b32;

    my $key_dir = "$ENV{HOME}/.n/user-keys";
    mkdir($key_dir, 0700) unless -d $key_dir;

    # Normalize hostname:port for filename
    my $filename_base = "$hostname:$port";
    $filename_base =~ tr/:\//__/;  # Replace unsafe chars
    my $key_file = catfile( $key_dir, "remote.$filename_base.public" );

    # Validate server pubkey format
    my $server_pubkey_bin = eval { Crypt::Misc::decode_b32r($server_pubkey_b32) };
    die "Invalid server pubkey encoding\n" unless defined $server_pubkey_bin && length($server_pubkey_bin) == 32;

    # Check if key exists
    if ( -f $key_file ) {
        # Key file exists - validate it matches
        open my $fh, '<', $key_file or die "Cannot read key file: $!\n";
        chomp( my $stored_key_line = <$fh> );
        close $fh;

        # Extract stored pubkey (format: NTIME_B32:PUBKEY_B32)
        my ( $stored_ntime_b32, $stored_pubkey_b32 ) = split( ':', $stored_key_line );

        if ( $stored_pubkey_b32 eq $server_pubkey_b32 ) {
            # Keys match
            print "TOFU_VALID\n";
            exit 0;
        } else {
            # Keys mismatch - MITM detected!
            print "TOFU_MISMATCH\n";
            exit 1;
        }
    } else {
        # First-use - pin the key
        # Generate NTIME in base32 format (use current time)
        my $ntime = time();
        my $ntime_b32 = Crypt::Misc::encode_b32r( pack( 'N', $ntime ) );

        # Store key with format: NTIME_B32:PUBKEY_B32
        open my $fh, '>', $key_file or die "Cannot write key file: $!\n";
        chmod( 0600, $key_file );
        print $fh "$ntime_b32:$server_pubkey_b32\n";
        close $fh;

        print "TOFU_PINNED\n";
        exit 0;
    }
}

#,,,,,,,.,,,,,,..,...,.,.,,,,,,,,,.,.,,..,,..,..,,...,...,...,,,,,,.,,,.,,,,.,
#57TLV7XT474KVUIMMMIDDKB77CLOSGK55MNUJBB2O7D7BJ6V5VEA6WSZAWQHZQIK54WRWMDLQBGPO
#\\\|2NY7SBXFQQBHA2ONREBQSZNTBM2DN36YIERFITSIUFGCHVH52H6 \ / AMOS7 \ YOURUM ::
#\[7]FGBSEPQ7CMCL3VJ2CGJ2C7HAOB4BS7BCJDODYY2GHMUCSAIX7KCA 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
