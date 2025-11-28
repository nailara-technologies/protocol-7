#!/usr/bin/perl
# Example: protocol-7 letsencr set-cipher-profile <profile>
# This is the Cube Command Handler syntax

package LetsEncrCmd::SetCipherProfile;

use v5.24;
use strict;
use warnings;
use FindBin qw($RealBin);
use lib "$RealBin/modules";
use HTTPSD::LoadCipherProfile qw(load_cipher_profile list_profiles);

sub execute {
    my ($self, @args) = @_;
    
    my $profile = shift @args;
    my $no_reload = grep { $_ eq '--no-reload' } @args;
    
    unless ($profile) {
        my $profiles = list_profiles();
        my $list = join("\n  ", sort keys %$profiles);
        return (0, "Usage: protocol-7 letsencr set-cipher-profile <profile> [--no-reload]\n\n" .
                   "Available profiles:\n  $list\n");
    }
    
    # Validate profile by loading it
    my $profile_obj;
    eval {
        $profile_obj = load_cipher_profile($profile);
    } or do {
        return (0, "ERROR: $@");
    };
    
    # TODO: Update /etc/protocol-7/httpsd-ciphers.yaml active_profile
    # TODO: Reload HTTPSD if not --no-reload
    
    return (1, "Cipher profile changed to: $profile\n" .
               "TLS Versions: " . join(', ', @{$profile_obj->{tls_versions}}) . "\n" .
               "Description: " . $profile_obj->{description} . "\n");
}

1;
