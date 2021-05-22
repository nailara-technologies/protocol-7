
package AMOS::Assert::Truth;  ################################################

use vars qw| $VERSION @EXPORT |;
use Exporter;
use base qw| Exporter |;

###                                                                 ###
##  ASSERT HARMONIC TRUTH BASED ON DIVISION BY 13 CALCULATION RESULT ##
###                                                                 ###

#######################
@EXPORT = qw| is_true |;      ##  <--  main function  ##
#######################

use v5.24;
use strict;
use English;
use warnings;
use Math::BigFloat;
use List::MoreUtils qw| uniq |;

##[ AMOS MODULE ]#############################################################

use AMOS;
use AMOS::Assert;
use AMOS::INLINE;

our %true  = init_table(qw| true |);
our %false = init_table(qw| false |);

our $elf_shift_bits = 13;    ##  elf shift bits  ##

our @assertion_modes = qw| 4 7 |;    ##  elf truth modes : main set-up  ##

use AMOS::CHKSUM::ELF qw| elf_chksum |;

## skip compilation when included from AMOS::INLINE::src::TruthAssertion
if ( defined &compile_inline_source ) {

    compile_inline_source( { qw| subroutine-name | => qw| true_int | } )
        if not defined &true_int;

    compile_inline_source( { qw| subroutine-name | => qw| true_float | } )
        if not defined &true_float;

}
###

##[ MAIN FUNCTION ]###########################################################

sub is_true {
    my $data_ref = shift;

    return warn_err('undefined input') if not defined $data_ref;

    my $calc_result;
    my $check_as_num = shift // 2;         ## also check as numerical ##
    my $check_as_elf = shift // 1;         ## check elf checksum ##
    my $shift_bits   = $elf_shift_bits;    ## right shift on overflow ##

    return warn_err('no checks enabled')
        if not $check_as_num and not $check_as_elf;

    $data_ref = join( ' ', @{$data_ref} ) if ref($data_ref) eq qw| ARRAY |;
    $data_ref = \"$data_ref"              if ref($data_ref) ne qw| SCALAR |;

    my @assertion_modes = uniq @ARG ? @ARG : @assertion_modes;

    return 0    ## check as mumber when numerical ##
        if $check_as_num == 1
        and AMOS::Assert::is_number($$data_ref)
        and calc_true( scalar($$data_ref) ) <= 0;

    return 0    ## when numerical with no 0 prefix ##
        if $check_as_num == 2
        and AMOS::Assert::numerical_no_0_prefix($$data_ref)
        and calc_true( scalar($$data_ref) ) <= 0;

    return 1 if not $check_as_elf;    ## numerical only, skip elf check ##

    ## assert selected elf checksum modes ##
    ##
    foreach my $elf_mode (@assertion_modes) {
        if ( calc_true( elf_chksum( $data_ref, 0, $elf_mode, $shift_bits ) )
            <= 0 ) {
            return 0 if not wantarray;
            return ( 0, $elf_mode );    ## report mode level of objection ##
        }
    }
    ## success : TRUE .: ##
    return 1 if not wantarray;
    return ( 1, @assertion_modes );

}

##[ HELPER ROUTINES ]#########################################################

sub init_table {
    my $mode = shift // '';

    die 'expected mode parameter [false|true]' if !length($mode);
    my $init_sequence = $mode eq 'true' ? qw| 461538 | : qw| 230769 |;
    my @pairs;
    foreach my $offset ( reverse 0 .. length($init_sequence) ) {
        my $num_t = join(
            '',
            substr( $init_sequence, $offset,
                length($init_sequence) - $offset )
                . substr( $init_sequence, 0, $offset )
        );
        push( @pairs, sprintf( '%06d', $num_t - 1 ) => $offset );  ## round ##
        push( @pairs, sprintf( '%06d', $num_t + 1 ) => $offset );  ## round ##
        push( @pairs, sprintf( '%06d', $num_t + 0 ) => $offset );  ## trunc ##
    }
    return @pairs;
}

sub calc_true {
    my $check_num = shift;

    error_exit( "input '%s' not numerical", $check_num )
        if not AMOS::Assert::is_number($check_num);

    my $calc_result;
    my $input_len = length($check_num);

    ## from AMOS::INLINE ##
    #
    return AMOS::Assert::Truth::int::true_int($check_num)
        if index( $check_num, '.', 0 ) == -1
        and $check_num <= 18446744073709551615    ## 64 bit ##
        and defined &AMOS::Assert::Truth::int::true_int
        and \&AMOS::Assert::Truth::int::true_int ne \&calc_true;

    return AMOS::Assert::Truth::float::true_float($check_num)
        if $input_len < 17
        and defined &AMOS::Assert::Truth::int::true_float
        and \&AMOS::Assert::Truth::int::true_float ne \&calc_true;
    #
    ###

    ##  LLL : adopt quotient based reduction method from inline version  ##

    my $factor = join( '', qw| 1 |, qw| 0 | x $input_len );

    if ( $input_len < 10 ) {  ## skipping Math::BigFloat for shorter values ##

        $calc_result = sprintf( qw| %.7f |, $check_num / 13 * $factor );

    } else { ##  gemeric division by 13 calculation [ arbitary precision ]  ##

        my $accuracy = 7 + length($check_num);
        Math::BigFloat->accuracy($accuracy);
        Math::BigFloat->round_mode(qw| trunc |);

        (   $calc_result    ## cleaned for 00000 inaccuracies at the end ##
                = Math::BigFloat->new($check_num)->bmul($factor)
                ->bdiv( 13, $accuracy )->bdstr()
        ) =~ s|(*nlb:(*nlb:5)3)0+$||;
    }

    ## truncate to match ##
    substr( $calc_result, 0, length($calc_result) - 6, '' );

    ## FALSE ### 230769 ####
    return 0 if exists $false{$calc_result};

    ### TRUE ### 384615 ####         ## implement visualization mode ##  [LLL]
    return 1 if exists $true{$calc_result};

    ### TRUE ### 0000000 | 1 ####
    return 1;
}

return 1;  ###################################################################

#.............................................................................
#75T7QD7PAHUPAVIHEAOY5CMLU5CGUUWCWTITVUJYSIUB4YVP5YKVULHCEQ724RIJLGSIZTI7ACF2S
#::: RL4JAXEFIGYGLS2NGJ5LBDJ3C4O3IYSRRQWNY3OXZORN6USLSUA :::: NAILARA AMOS :::
# :: I7YHK3G6JTTVEK7XXLYIDWMXZ4L3JA23RRBZX6ZM4YBECKITNUBY :: CODE SIGNATURE ::
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
