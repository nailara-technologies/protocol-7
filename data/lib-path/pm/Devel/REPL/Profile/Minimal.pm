package Devel::REPL::Profile::Minimal;

our $VERSION = '1.003028';

use Moose;
use namespace::autoclean;

with 'Devel::REPL::Profile';

sub plugins {
    qw(History LexEnv DDS Packages Commands MultiLine::PPI);
}

sub apply_profile {
    my ( $self, $repl ) = @_;
    $repl->load_plugin($_) for $self->plugins;
}

1;

#,,..,,,,,.,.,,.,,,,.,,,,,...,...,,.,,.,,,..,,..,,...,...,,.,,,..,.,.,,..,.,.,
#R5IRAP4AJ6NGU2PKYD2CZ3QGJJLLRUHEOLJFJ3CNPZWLAV545HNEWAORBCEFUJDCYXCDYR44437TM
#\\\|VAQGN63E62RWXBILCMRVGBNJAY5OUJAONDSEPCBD3MN5PDNSOUU \ / AMOS7 \ YOURUM ::
#\[7]PL7XVI4GCRYGMRBFFK36AWBXFKFZJFDYJYQPPAIM7VSYPGZWVADA 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
