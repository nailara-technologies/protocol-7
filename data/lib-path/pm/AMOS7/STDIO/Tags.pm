
package AMOS7::STDIO::Tags;  #################################################
our $VERSION = qw| AMOS7::STDIO::Tags-VERSION.TBFJQWI |;

use v5.24;
use strict;
use warnings;
use English;

use Exporter;
use base qw| Exporter |;

our @EXPORT = qw|
    META SIN RIN EOUT TOUT NUM STR ERR
    |;

use constant {
    META => 0b000,
    SIN  => 0b001,
    RIN  => 0b010,
    EOUT => 0b011,
    TOUT => 0b100,
    NUM  => 0b101,
    STR  => 0b110,
    ERR  => 0b111,
};

return 5;  ###################################################################

#,,.,,...,,,,,.,,,.,,,..,,.,,,.,,,.,.,,..,..,,.,.,...,...,...,,.,,,,,,..,,..,,
#3GFI3XCDXWXJ75G5UK3XMP3UCJBPN2P4FM7IMPGYU2OS5B32QVP7PIE46POMBY4SGAKJBJLTDNXFE
#\\\|FGCCRBNJ53ZUF7YGROU7TTT7MQVIB2AAM3C5NIYLQUUSPDTCVMA \ / AMOS7 \ YOURUM ::
#\[7]LFVCTTBA4BRPZKZVJUO2O6MEX2AFHLH23OHNJQBCR4OZGUNIOIBQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
