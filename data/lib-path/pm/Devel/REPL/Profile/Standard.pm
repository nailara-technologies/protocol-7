package Devel::REPL::Profile::Standard;

our $VERSION = '1.003028';

use Moose;
use namespace::autoclean;

with 'Devel::REPL::Profile';

sub plugins {
    qw(
        Colors
        Completion
        CompletionDriver::INC
        CompletionDriver::LexEnv
        CompletionDriver::Keywords
        CompletionDriver::Methods
        History
        LexEnv
        DDS
        Packages
        Commands
        MultiLine::PPI
        ReadLineHistory
    );
}

sub apply_profile {
    my ( $self, $repl ) = @_;
    $repl->load_plugin($_) for $self->plugins;
}

1;

#,,,.,.,,,,.,,,,,,,,.,.,.,,,,,...,.,,,,,.,.,,,..,,...,...,.,.,,,,,.,.,,,,,,,,,
#6B2KZJRRPZUULRBANHTCS4F6FMARRTXROAGQ2LI352AYLLBHIDQGMG7OZP2R7V5EP5EMEVINFINNQ
#\\\|F5ZMVCS3LDGHY4METK2DXOUH4HWS46WHW63BSGHRBBS2B3RA6RS \ / AMOS7 \ YOURUM ::
#\[7]3AXP75EVNKFNILZGEIP7TBKN5OH6CATUZC7HF4P7ZBFH2QAD2CAQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
