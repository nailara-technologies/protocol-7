package Crypt::Misc;    ##  minimal test shim : pure-perl b32r only  ##

use v5.24;
use strict;
use warnings;
use Exporter;
use base qw| Exporter |;

our @EXPORT_OK = qw| encode_b32r decode_b32r |;

my $B32_ALPHABET = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ234567';

sub encode_b32r {
    my $data = shift // '';
    return '' if not length $data;
    my $bits = unpack 'B*', $data;
    $bits .= '0' x ( 5 - length($bits) % 5 ) if length($bits) % 5;
    my $out = '';
    while ( length $bits ) {
        $out .= substr( $B32_ALPHABET, oct( '0b' . substr( $bits, 0, 5, '' ) ),
            1 );
    }
    return $out;
}

sub decode_b32r {
    my $str = shift // '';
    return '' if not length $str;
    $str = uc $str;
    return undef if $str =~ m{[^A-Z2-7]};
    my $bits = '';
    foreach my $ch ( split '', $str ) {
        $bits .= sprintf '%05b', index( $B32_ALPHABET, $ch );
    }
    ##  truncate to full bytes [ b32r has no padding ]  ##
    $bits = substr( $bits, 0, int( length($bits) / 8 ) * 8 );
    return pack 'B*', $bits;
}

1;

#,,,.,..,,,,.,,.,,,.,,,,,,..,,,,.,,,,,,,,,,..,..,,...,..,,,..,,,,,.,,,.,,,,,,,
#NFZISQJDBXUMUUIUIVLAG3XCDN57QBJZ3WFONWKPWOC4S75PIXK4NXIT7FBK7MNS7Y3LDQYU4SWG6
#\\\|2P2JSOVNGI7CBTOK2NRQYS4L5IVXQWXYOR62XGHOSCGMQEZWF7C \ / AMOS7 \ YOURUM ::
#\[7]UEENLNHWAQLBL6LSTT3JZ5UQYTBHWBFPRH5RCACUTMCFISVEEUBQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
