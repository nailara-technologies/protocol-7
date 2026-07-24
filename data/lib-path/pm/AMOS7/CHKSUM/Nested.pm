## [:< ##

package AMOS7::CHKSUM::Nested;  ##############################################

use v5.24;
use strict;
use English;
use warnings;

##[ global constants ]##
use constant TRUE  => 5;        ##  TRUE.  ##
use constant FALSE => 0;        ##  false  ##

use Exporter;
use base qw| Exporter |;
use vars qw| @EXPORT $VERSION |;

use AMOS7::CHKSUM qw| amos_chksum |;

$VERSION = qw| AMOS7::CHKSUM::Nested-VERSION.7UA5BUI |;

@EXPORT = qw|
    child_chksum
    format_nested
    parse_nested
    verify_nesting
    reconstruct_chain
    |;

##[ CHILD CHECKSUM ]##########################################################

sub child_chksum {

    my ( $parent_chksum, $child_name ) = @_;

    return undef
        if not defined $parent_chksum
        or not length $parent_chksum
        or not defined $child_name
        or not length $child_name;

    return amos_chksum( $parent_chksum . '.' . $child_name );
}

##[ NOTATION FORMATTING ]#####################################################

sub format_nested {

    my ( $child_chksum, $parent_chksum ) = @_;

    return undef
        if not defined $child_chksum
        or not length $child_chksum
        or not defined $parent_chksum
        or not length $parent_chksum;

    return "[$child_chksum:$parent_chksum]";
}

##[ NOTATION PARSING ]########################################################

sub parse_nested {

    my ($notation) = @_;

    return undef if not defined $notation;

    return undef
        unless $notation =~ /^\[([A-Z0-9]+):([A-Z0-9]+)\]$/;

    return { child => $1, parent => $2 };
}

##[ NESTING VERIFICATION ]####################################################

sub verify_nesting {

    my ( $notation, $parent_chksum, $child_name ) = @_;

    my $parsed = parse_nested($notation);
    return FALSE if not defined $parsed;

    my $expected = child_chksum( $parent_chksum, $child_name );
    return FALSE if not defined $expected;

    return $expected eq $parsed->{'child'} ? TRUE : FALSE;
}

##[ CHAIN RECONSTRUCTION ]####################################################

sub reconstruct_chain {

    my (@notations) = @_;

    return undef if not @notations;

    my @chain;
    my $expected_parent;

    foreach my $notation (@notations) {
        my $parsed = parse_nested($notation);
        return undef if not defined $parsed;

        if ( defined $expected_parent
            and $parsed->{'parent'} ne $expected_parent ) {
            return undef;
        }

        push @chain, $parsed;
        $expected_parent = $parsed->{'child'};
    }

    return \@chain;
}

return TRUE ##################################################################

#,,.,,,,,,,,.,..,,,,,,...,.,.,,.,,,,.,.,,,..,,..,,...,...,,..,.,.,,..,..,,,,,,
#IS4QQHMOZ7JNSJ3RBJIOZRSAZJXU7FCMH4JIMZQNF2YZQGTNWE7C3LBCUINQ5SWFX67OCEM76BJ5U
#\\\|MA4FNXJI74TLWU5T7D5QS7OJU4ATWHG2S5PNAHTEVNMMPC2WMVK \ / AMOS7 \ YOURUM ::
#\[7]MVM77OA2XFZTXJ44XGZ5OVMIIKLMREMH2H2QHKZPBSJDDCSULMCI 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
