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

#,,.,,...,,,,,.,.,,,.,,,,,...,.,,,.,,,..,,.,.,..,,...,...,...,,..,.,.,,,,,..,,
#ALLEO53TJC7I3O5EQ4QRDCKUJD6MMBSDZMMJZYYE37Q6JKP5LW3IF22ETHHXOFHL4D2DTLQ5YTNY6
#\\\|BVBXVPCKUJAH5CRJRMWO4AW46MI36F62ZK6BTTOKNPCEQJVEZL7 \ / AMOS7 \ YOURUM ::
#\[7]CRVENWS4H6QKL4FARF2CXSPGEDDGYCS2YCIZRO5P6YGO2LDRAMBI 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
