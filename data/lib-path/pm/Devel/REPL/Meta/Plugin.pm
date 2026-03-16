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

#,,.,,,.,,.,.,.,.,,.,,...,,,,,,..,,,,,,,,,..,,..,,...,...,...,...,.,.,...,,,,,
#2D4GO6QBST3BFRWHVU6FSRMNNBXD5INHF2G5OLJGWPSMO3IVBX7J2H776YCB3KD6CSS5J3FRZ42HS
#\\\|KYX4VF3PZZUDEFJGIHWPVIEEL7HFVSUU3JES2MYPWPY63BMLJMT \ / AMOS7 \ YOURUM ::
#\[7]NZK2G5CQKOWPDEKBLYQFX3APKI4DF45I2ARAADU4QGNZJF4NPCCQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
