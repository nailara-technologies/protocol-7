# Copyrights 2011-2020 by [Mark Overmeer].
#  For other contributors see ChangeLog.
# See the manual pages for details on the licensing terms.
# Pod stripped from pm file by OODoc 2.02.
# This code is part of distribution POSIX-1003.  Meta-POD processed with
# OODoc into POD and HTML manual-pages.  See README.md
# Copyright Mark Overmeer.  Licensed under the same terms as Perl itself.

use warnings;
use strict;

no warnings 'redefine', 'prototype';    # during release of distribution

sub POSIX::SigAction::new {
    my $class = shift;
    bless { HANDLER => $_[0], MASK => $_[1], FLAGS => $_[2] || 0, SAFE => 0 },
        $class;
}

#---------------------------

# We cannot use a "package" statement, because it confuses CPAN: the
# namespace is assigned to the perl core distribution.
no warnings 'redefine';

sub POSIX::SigAction::handler($;$) {
    $_[0]->{HANDLER} = $_[1] if @_ > 1;
    $_[0]->{HANDLER};
}

sub POSIX::SigAction::mask($;$) {
    $_[0]->{MASK} = $_[1] if @_ > 1;
    $_[0]->{MASK};
}

sub POSIX::SigAction::flags($;$) {
    $_[0]->{FLAGS} = $_[1] if @_ > 1;
    $_[0]->{FLAGS};
}

sub POSIX::SigAction::safe($;$) {
    $_[0]->{SAFE} = $_[1] if @_ > 1;
    $_[0]->{SAFE};
}

1;

#,,.,,,,.,..,,.,.,...,,,,,...,,.,,.,,,,..,,..,..,,...,...,,..,.,.,.,,,...,.,.,
#ZYNOB3LU7M2SSQNLUTZY7BC7NNE6U4B33OBCG6R7KNRMBUZBXF5IYYBVUCJMZFDY5KEDCN5M544RY
#\\\|2YESUJXGPKLSRPWWPVSINW6GHVRI7KN7GEVTEKBT7LNJ2F5MPRQ \ / AMOS7 \ YOURUM ::
#\[7]2BQQ2IXRI3MEAOVEGQGRE3XE5WTFS7LBNQUYQ6MDHB6PSF2R2IAI 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
