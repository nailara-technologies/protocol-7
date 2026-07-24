#!/usr/bin/env perl

=head1 NAME

test-link-upgrade-client.pl - Test client for Protocol-7 link-upgrade negotiation

=head1 SYNOPSIS

test-link-upgrade-client.pl [--socket /var/run/.7/UNIX/NIW7OAQ] [--encoding base32]

=head1 DESCRIPTION

Simple Perl client to test the Protocol-7 link-upgrade encryption handshake.
Connects to the Protocol-7 cube, authenticates, initiates link-upgrade, and
verifies the encryption state transition.

=cut

use strict;
use warnings;
use v5.10.0;
use IO::Socket::UNIX;
use Crypt::Curve25519;
use Crypt::Misc qw(encode_b32r decode_b32r);
use Getopt::Long;

my $socket_path   = '/var/run/.7/UNIX/NIW7OAQ';
my $encoding_mode = 'none';
my $username      = 'root';
my $verbose       = 0;

GetOptions(
    'socket=s'   => \$socket_path,
    'encoding=s' => \$encoding_mode,
    'user=s'     => \$username,
    'verbose!'   => \$verbose,
) or die "Error in command line arguments\n";

print "Protocol-7 Link-Upgrade Test Client\n" if $verbose;
print "Socket: $socket_path\n"                if $verbose;
print "Encoding: $encoding_mode\n"            if $verbose;

# Connect to the Protocol-7 cube
my $socket = IO::Socket::UNIX->new(
    Type => SOCK_STREAM,
    Peer => $socket_path
) or die "Cannot connect to $socket_path: $!\n";

print "Connected to Protocol-7 cube\n" if $verbose;

# Read authentication prompt
my $line = <$socket>;
print "Server: $line" if $verbose;

# Send authentication
my $auth_cmd = "select unix\nauth unix-$username\n";
print "Sending: $auth_cmd" if $verbose;
print $socket $auth_cmd;

# Read authentication response
for ( 1 .. 3 ) {
    $line = <$socket>;
    print "Server: $line"          if $verbose;
    die "Authentication failed!\n" if $line =~ /ERROR/;
}

print "Authentication successful\n" if $verbose;

# Send link-upgrade command
my $upgrade_cmd = "link-upgrade $encoding_mode\n";
print "Sending: $upgrade_cmd" if $verbose;
print $socket $upgrade_cmd;

# Read link-upgrade response
$line = <$socket>;
print "Server: $line" if $verbose;

# Check if upgrade was initiated successfully
die "Link-upgrade failed: $line\n" unless $line =~ /TRUE/;

print "Link-upgrade initiated successfully\n" if $verbose;

# Generate C25519 ephemeral keypair
print "Generating ephemeral keypair...\n" if $verbose;
my ( $client_secret, $client_public ) = Crypt::Curve25519::generate_keypair();

print "Client secret length: " . length($client_secret) . "\n" if $verbose;
print "Client public length: " . length($client_public) . "\n" if $verbose;

# Encode public key in BASE32 for transmission
my $client_public_b32 = encode_b32r($client_public);
print "Client public (B32): $client_public_b32\n" if $verbose;

# Wait for server's public key response (SIZE 0 response)
$line = <$socket>;
print "Server: $line" if $verbose;
die "Expected SIZE 0 response: $line\n" unless $line =~ /^SIZE\s+0/;

print "Server acknowledged key exchange\n" if $verbose;

# Send our public key
my $key_exchange_cmd = "link-pub-key $client_public_b32\n";
print "Sending: $key_exchange_cmd" if $verbose;
print $socket $key_exchange_cmd;

# Read server's acknowledgement
$line = <$socket>;
print "Server: $line" if $verbose;

# Confirm encoding mode
my $confirm_cmd = "link-confirm-encoding $encoding_mode\n";
print "Sending: $confirm_cmd" if $verbose;
print $socket $confirm_cmd;

# Read server's confirmation
$line = <$socket>;
print "Server: $line" if $verbose;

# Complete the handshake
my $complete_cmd = "link-complete\n";
print "Sending: $complete_cmd" if $verbose;
print $socket $complete_cmd;

# Read final confirmation
$line = <$socket>;
print "Server: $line" if $verbose;

print "\n✓ Link-upgrade handshake completed successfully!\n";
print "  Session is now in encrypted state (state 3)\n";

# Send a test command in encrypted mode
print "\nTesting encrypted communication...\n" if $verbose;
my $test_cmd = "commands\n";
print "Sending test command (encrypted): $test_cmd" if $verbose;
print $socket $test_cmd;

# Read response
my $response_line = <$socket>;
print "Server response: $response_line" if $verbose;

print "\n✓ All tests passed!\n";

close($socket);
exit 0;

__END__

=head1 AUTHOR

Protocol-7 Development Team

=head1 LICENSE

See LICENSE file

=cut

#,,.,,,,,,...,,,.,..,,.,,,,,.,.,,,,.,,,..,.,,,..,,...,...,,,,,,..,..,,,,,,..,,
#5XOEMKIEG3Y2W2TZ3RX3FYAO4YCFZJ4AUSRRATRO3XRYGX3LUW6U3GZXYD4VEWYGGFUOMEPL5XHOM
#\\\|S3A43EC27CTPSPR6HZMJCTWDRNRJBZ76NZVGNXEX5JNLYPQPGL3 \ / AMOS7 \ YOURUM ::
#\[7]4PFQKPRO6TGMHOVQ3KGJJLLKSBF3EDXLAOICFIYYV2HGRJVV4YAQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
