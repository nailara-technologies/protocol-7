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

#,,..,,,,,.,.,,.,,,,.,,,,,...,...,,.,,.,,,..,,..,,...,...,..,,..,,...,..,,...,
#6KAUCWY46ZMSXTGYUL34EFEPM7LMXFREUP3EHIG4IN2RN3KY7SLEBH3ZU3ZWWNJ6RSEKBBT6IEVSE
#\\\|QNHRUYXMFWPADMDXBCM4JRC76XK3A37BUOCYBYKUTZCDZMUFLSF \ / AMOS7 \ YOURUM ::
#\[7]7UGIJXUTJ4KJLXSJGBIIEJDYJXJ5KTUAR2LEILXGQPZR24BNN2BI 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
