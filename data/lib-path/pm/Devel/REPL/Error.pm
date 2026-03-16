package Devel::REPL::Error;

our $VERSION = '1.003028';

use Moose;
use namespace::autoclean;

# FIXME get nothingmuch to refactor and release his useful error object

has type => (
    isa      => "Str",
    is       => "ro",
    required => 1,
);

has message => (
    isa      => "Str|Object",
    is       => "ro",
    required => 1,
);

sub stringify {
    my $self = shift;

    sprintf "%s: %s", $self->type, $self->message;
}
__PACKAGE__

#,,.,,...,,,,,.,.,,,.,,,,,...,.,,,.,,,..,,.,.,..,,...,...,,,.,,.,,,.,,.,,,.,.,
#3JCGP5JWGXI4COQEKFL3NUI2I2MOGWA5SE76RSIZNOQJ6YXRNIDH6ZCXC75Y6UM4TCF55KXNX5PD4
#\\\|FJWXIYG3E5MGOBNNZPTHIA4VVEUWUUDPGEBNQWBO4EUEOQ3BYBO \ / AMOS7 \ YOURUM ::
#\[7]X6KDY56AAA3JW7CQEQXAZJUIDVR3K65KVZK5WCTPUUIU5B4742AY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
