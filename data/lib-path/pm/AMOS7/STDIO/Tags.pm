
package AMOS7::STDIO::Tags;  #################################################

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

#,,,.,.,,,.,,,..,,.,.,,..,,,,,.,,,,.,,...,.,.,.,.,...,...,,.,,..,,,.,,,,.,..,,
#24476OX4D4CBMVO6TU2TUJXAPA44DORIL5DYRZ6JKKC5YQ76APNROBSLMIVJL77REG2HWI4HEG4KI
#\\\|PJ7P4FXKJ74DM22WM3HXFYDG3YD2I3ZUABCGTRASN76XOYNT4DQ \ / AMOS7 \ YOURUM ::
#\[7]RWNBFH7NCI5MJJD77DTJGVAXPKFN3U5RKZIHHHA2NVXKCRC6BWCA 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
