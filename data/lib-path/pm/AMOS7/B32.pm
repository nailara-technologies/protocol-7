package AMOS7::B32;
our $VERSION = qw| AMOS7::B32-VERSION.NLMPKR2 |;

use strict;
use warnings;
use English;

use Exporter;
use base qw| Exporter |;

our @EXPORT_OK = qw| encode_b32r decode_b32r |;

##[ RFC 4648 base32, unpadded -- the base32r variant ]########################
##
## pure-perl implementation, byte-identical to Crypt::Misc's encode_b32r \
## decode_b32r [ verified against Crypt::Misc for 0..64 byte inputs ] -- so
## module code can use it unconditionally and produce exactly the names
## Crypt::Misc would, with no optional dependency [ bin/Protocol-7 carries the
## same algorithm as p7_base_util_base32_encode \ _decode ]

my $alphabet_str = join '', 'A' .. 'Z', '2' .. '7';

sub encode_b32r {
    my $input_bytes = shift;
    return '' unless defined $input_bytes and length $input_bytes;

    my $result         = '';
    my $buffer         = 0;
    my $bits_in_buffer = 0;

    for my $byte ( unpack qw| C* |, $input_bytes ) {
        $buffer = ( $buffer << 8 ) | $byte;
        $bits_in_buffer += 8;

        while ( $bits_in_buffer >= 5 ) {
            $bits_in_buffer -= 5;
            my $index = ( $buffer >> $bits_in_buffer ) & 0x1F;
            $result .= substr $alphabet_str, $index, 1;
        }
    }

    if ( $bits_in_buffer > 0 ) {
        my $index = ( $buffer << ( 5 - $bits_in_buffer ) ) & 0x1F;
        $result .= substr $alphabet_str, $index, 1;
    }

    return $result;    ##  unpadded, like Crypt::Misc  ##
}

my %alphabet_index = map { substr( $alphabet_str, $ARG, 1 ) => $ARG } 0 .. 31;

sub decode_b32r {
    my $input_string = shift;
    return '' unless defined $input_string and length $input_string;

    my $result         = '';
    my $buffer         = 0;
    my $bits_in_buffer = 0;

    for my $char ( split '', $input_string ) {
        return undef unless exists $alphabet_index{$char};
        my $value = $alphabet_index{$char};
        $buffer = ( $buffer << 5 ) | $value;
        $bits_in_buffer += 5;

        if ( $bits_in_buffer >= 8 ) {
            $bits_in_buffer -= 8;
            $result .= chr( ( $buffer >> $bits_in_buffer ) & 0xFF );
        }
    }

    return $result;
}

1;    ##  AMOS7::B32  ##

#,,..,...,.,,,,,.,.,,,.,.,.,.,...,.,.,,,,,.,,,.,.,...,...,,.,,,.,,.,,,,.,,,,.,
#Z4GSQAW45OVWNTG2L4JZQHKVFR3FV6KSDIVOJB3A27O5VO7QYBHPIZKLLPFJHIUONCFA6P4HBQZJI
#\\\|ULAWHFPZSIHXZA3N6IQ5XKWYHMUU4XR2HTNXJYEGFLF4KFPL7C6 \ / AMOS7 \ YOURUM ::
#\[7]6FG7EHYNKL4JCKJWRKPCP52HWDKZTVXQ24HYT7EUCBA724Y432BY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
