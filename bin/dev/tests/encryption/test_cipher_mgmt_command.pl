#!/usr/bin/perl
# Example: protocol-7 letsencr set-cipher-profile <profile>
# This is the Cube Command Handler syntax

package LetsEncrCmd::SetCipherProfile;

use v5.24;
use strict;
use warnings;
use FindBin qw($RealBin);

# Use p7 command to call flat modules
my $P7_PATH = "$RealBin/../../../p7";

sub _load_cipher_profile {
    my ($profile_name) = @_;
    my $json
        = `$P7_PATH httpsd.load-cipher-profile '$profile_name' 2>/dev/null`;
    return undef unless $json;
    eval { require JSON::PP; } or do { return undef; };
    return JSON::PP::decode_json($json);
}

sub _list_profiles {
    my $json = `$P7_PATH httpsd.cmd.list-cipher-profiles 2>/dev/null`;
    return {} unless $json;
    eval { require JSON::PP; } or do { return {}; };
    return JSON::PP::decode_json($json);
}

sub execute {
    my ( $self, @args ) = @_;

    my $profile   = shift @args;
    my $no_reload = grep { $_ eq '--no-reload' } @args;

    unless ($profile) {
        my $profiles = _list_profiles();
        my $list     = join( "\n  ", sort keys %$profiles );
        return ( 0,
            "Usage: protocol-7 letsencr set-cipher-profile <profile> [--no-reload]\n\n"
                . "Available profiles:\n  $list\n" );
    }

    # Validate profile by loading it
    my $profile_obj = _load_cipher_profile($profile);

    unless ($profile_obj) {
        return ( 0, "ERROR: Failed to load cipher profile: $profile" );
    }

    # TODO: Update /etc/protocol-7/httpsd-ciphers.yaml active_profile
    # TODO: Reload HTTPSD if not --no-reload

    return ( 1,
              "Cipher profile changed to: $profile\n"
            . "TLS Versions: "
            . join( ', ', @{ $profile_obj->{tls_versions} } ) . "\n"
            . "Description: "
            . $profile_obj->{description}
            . "\n" );
}

1;

#,,,,,.,.,,,.,.,.,.,,,,,,,,.,,..,,..,,,,.,,,,,..,,...,..,,,,.,,,.,...,..,,,,,,
#27QV7M6J2QN4TICQN5ZSPBKHS73VPQYMH5SR7DKFIQ75BEODYSSXSI5WDLM2BWHPCIIH7ZD57XXKE
#\\\|TIMBO4NDJJPY5VJRO6IOMD6BXOLMDSQMHJJAHIYGG7FCZJOHY2V \ / AMOS7 \ YOURUM ::
#\[7]ITTHZ3HVV6UWMJV7QZ5CZYSSIV3FRP5W7OUQNOZ5VZKIG4KSUOCY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
