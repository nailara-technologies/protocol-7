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

#,,,.,.,,,,.,,,,,,,,.,.,.,,,,,...,.,,,,,.,.,,,..,,...,...,.,,,...,.,.,.,.,...,
#5U5HREREPGNWTX6D6RA6LNWVKZUCYVIB4WBE5M2AZ2J2B7TS7KPJXTEBI7FIITTCADDYC46WS43GS
#\\\|7ECOWGVVWXBTWVBCGX2FLFZDGAOC4SGNAUMAJVBDIPPPFM5JTAI \ / AMOS7 \ YOURUM ::
#\[7]CVHF4H5ZCUFZK6HRNLHHJBLKG7R2RVUCCVI4THSXU4S3QGEVMGCY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
