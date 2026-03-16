use strict;
use warnings;

package Devel::REPL::Plugin;

our $VERSION = '1.003028';

use Devel::REPL::Meta::Plugin;
use Moose::Role ();
use namespace::autoclean;

sub import {
    my $target = caller;
    Devel::REPL::Meta::Plugin->initialize($target);
    goto &Moose::Role::import;
}

1;

#,,.,,...,.,.,...,,,.,,,.,..,,,.,,,,,,,,,,,.,,..,,...,...,,..,...,,,,,.,.,,,.,
#5GYVMZGKOKYEN44OD6R6ZR67IFFJR62VHSWCJ2L5CTJLFMCXTDDJU6L37GK4FU2KZJJ4JCY3P4S7C
#\\\|D466WWHRJP6KBCKZP6TIXFDRFVAB46FGFB5R4NLELFIUVXVQI4B \ / AMOS7 \ YOURUM ::
#\[7]5OQEMMZ4DUALHIP6MVWJSPT4R4RL2M4N6CCYNRVNN3S5TCFSTOCI 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
