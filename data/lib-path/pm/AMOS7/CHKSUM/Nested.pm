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

use AMOS7::CHKSUM qw| amos_template_chksum |;

$VERSION = qw| AMOS7::CHKSUM::Nested-VERSION.CZPHQTY |;

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
        or ( length $parent_chksum
        and $parent_chksum !~ m|^[A-Z0-9]{7}$| )
        or not defined $child_name
        or not length $child_name
        or index( $child_name, qw| . | ) >= 0;

    ## bracketed and bare notation shapes as comma-joined truth templates [ ##
    ## split_truth_templates splits on unescaped commas and                 ##
    ## template_is_true requires all clauses to pass, so the result is true ##
    ## combined and separate : both [child:parent] and the bare             ##
    ## child:parent form [ e.g. terminal double-click copy-paste, where     ##
    ## word-boundary selection stops at the brackets ] validate ]           ##
    my $nest_template = join( ',',
        sprintf( qw| [%s:%s] |, qw| %s |, $parent_chksum ),
        sprintf( qw| %s:%s |,   qw| %s |, $parent_chksum ) );

    ## convergence loop searches until [child:parent] and child:parent are  ##
    ## both true [ multiple simultaneous representations, same mechanism as ##
    ## crypt.C25519.key_bin_checksums ]                                     ##
    return amos_template_chksum( $nest_template,
        $parent_chksum . '.' . $child_name );
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
        unless $notation =~ m|^\[([A-Z0-9]+):([A-Z0-9]+)\]$|;

    return { child => $1, parent => $2 };
}

##[ NESTING VERIFICATION ]####################################################

sub verify_nesting {

    my ( $notation, $parent_chksum, $child_name ) = @_;

    my $parsed = parse_nested($notation);
    return FALSE if not defined $parsed;
    return FALSE
        if not defined $parent_chksum
        or $parsed->{'parent'} ne $parent_chksum;

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

#,,,,,.,,,,,.,.,,,..,,,,,,.,,,,.,,,.,,,,.,.,,,..,,...,...,..,,,.,,,..,...,,,,,
#5KYR7JJT4GKLR33OTUUBQAVWA4HLDG3IHOLBCSD3A2JN6P7TPHNYCTULTMAM6B7GS7XYBYN6XPDD6
#\\\|U54F4TCLZUL76I7J5QDGXH5MLAUV2LD6MKZ4GRHKIFWVOW4TMKD \ / AMOS7 \ YOURUM ::
#\[7]5V64CDYSYG5E5LHKPKPEK42EJZQJGPBR2BUFKO2XCLUO5PC6FMBY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
