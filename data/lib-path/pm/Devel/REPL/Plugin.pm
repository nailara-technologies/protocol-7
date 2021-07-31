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

#,,.,,...,.,.,...,,,.,,,.,..,,,.,,,,,,,,,,,.,,..,,...,...,,.,,,..,,.,,.,,,...,
#257WA7LY4ZZ65J7WYDJQQMA5M2CYJYKZVKSVJMNBC523LH2SSW24ACDGAHEBIEUV6BF7Y4ENKVPUI
#\\\|3X4RFFLSSCPMU7PR344AQE7MDXMTQYXTYSV467FHDIRE2FB5T3S \ / AMOS7 \ YOURUM ::
#\[7]VAWC5C6KKSRFKLQ6KSKFLLDZ3NGUI5JNQOHS7BT4MHQ4EO7UQCAA 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
