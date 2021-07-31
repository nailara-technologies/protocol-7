use strict;
use warnings;

package Devel::REPL::Meta::Plugin;

our $VERSION = '1.003028';

use Moose;
use namespace::autoclean;

extends 'Moose::Meta::Role';

before 'apply' => sub {
    my ( $self, $other ) = @_;
    return unless $other->isa('Devel::REPL');
    if ( my $pre = $self->get_method('BEFORE_PLUGIN') ) {
        $pre->body->( $other, $self );
    }
};

after 'apply' => sub {
    my ( $self, $other ) = @_;
    return unless $other->isa('Devel::REPL');
    if ( my $pre = $self->get_method('AFTER_PLUGIN') ) {
        $pre->body->( $other, $self );
    }
};

1;

#,,.,,,.,,.,.,.,.,,.,,...,,,,,,..,,,,,,,,,..,,..,,...,..,,,,.,,.,,,,,,,,,,.,,,
#HED2CKCH3DXVFCXDCPICUCGAIKXUDHSGB7CHKRZOUVXGGL5SU42P2P4SLU7EZXHD3D4PVYCUPDTV4
#\\\|MWG4HM3K66ZI6SXJQDRDT2EWNQM2XQVRTGXA7X5ZE2PBM7NCPLA \ / AMOS7 \ YOURUM ::
#\[7]VJWQZQSDNZ27QTLSUIUVNJRQFHSEBAVELQHN6IXTXXQRKECTRKCA 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
