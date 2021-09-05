##  [:<  ##

package AMOS7::Assert::Truth; ################################################

###                                                           ###
##  ASSERT HARMONIC TRUTH BASED ON DIVISION BY 13 CALCULATION  ##
#                                                               #

##[ global constants ]##
use constant TRUE  => 5;      ##  TRUE.  ##
use constant FALSE => 0;      ##  false  ##

use Exporter;
use base qw| Exporter |;
use vars qw| $VERSION @EXPORT |;

@EXPORT = qw| is_true |;      ##  <--  main function  ##

##  is_true with sprintf template  ##
###
@EXPORT_OK = qw| is_true_with_template is_template_syntax_valid |;

use v5.24;
use strict;
use English;
use warnings;
use Math::BigFloat;
use List::MoreUtils qw| uniq |;

##[ AMOS MODULE ]#############################################################

use AMOS7;
use AMOS7::Assert;
use AMOS7::INLINE;
use AMOS7::TEMPLATE;

our %true  = init_table(qw| true |);
our %false = init_table(qw| false |);

our $elf_shift_bits = 13;    ##  elf shift bits  ##

our @assertion_modes = qw| 4 7 |;    ##  elf truth modes : main set-up  ##

use AMOS7::CHKSUM::ELF;

## skips compilation when included from AMOS7::INLINE::src::TruthAssertion
if ( defined &compile_inline_source ) {
    ## loads when not defined ##
    map { compile_inline_source( { qw| subroutine-name | => $ARG } ) }
        qw| true_int true_float |;
}
###

##[ MAIN FUNCTION ]###########################################################

sub is_true {

    my $data_ref = shift;

    ##                                 ##
    ## returns 5 for true, 0 for false ##
    ##                                 ##

    return warn_err('undefined input <{C2}>') if not defined $data_ref;

    my $calc_result;
    my $check_as_num = shift // 2;         ## also check as numerical ##
    my $check_as_elf = shift // 1;         ## check elf checksum ##
    my $shift_bits   = $elf_shift_bits;    ## right shift on overflow ##

    return warn_err('no checks enabled')
        if not $check_as_num and not $check_as_elf;

    $data_ref = join( ' ', $data_ref->@* ) if ref $data_ref eq qw| ARRAY |;
    $data_ref = \"$data_ref"               if ref $data_ref ne qw| SCALAR |;

    return warn_err('undefined input <{C2}>') if not defined $$data_ref;

    my @assertion_modes = uniq @ARG ? @ARG : @assertion_modes;

    return FALSE    ## check as mumber when numerical ##
        if $check_as_num == 1
        and AMOS7::Assert::is_number( $data_ref->$* )
        and calc_true( scalar( $data_ref->$* ) ) <= 0;

    return FALSE    ## when numerical with no 0 prefix ##
        if $check_as_num == 2
        and AMOS7::Assert::numerical_no_0_prefix( $data_ref->$* )
        and calc_true( scalar $data_ref->$* ) <= 0;

    return TRUE if not $check_as_elf;    ## numerical only, skip elf check ##

    ## assert selected elf checksum modes ##
    ##
    foreach my $elf_mode (@assertion_modes) {
        if ( calc_true( elf_chksum( $data_ref, 0, $elf_mode, $shift_bits ) )
            <= 0 ) {
            return FALSE if not wantarray;
            return ( FALSE, $elf_mode );  ## report mode level of objection ##
        }
    }

    ## success : TRUE .: ##
    return TRUE if not wantarray;
    return ( TRUE, @assertion_modes );

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

##  asserts truth of arbitary len. numerical value [ division by 13 ]  ##
##
sub calc_true {

    my $check_num = shift;

    ##                                 ##
    ## returns 5 for true, 0 for false ##
    ##                                 ##

    error_exit( "input '%s' not numerical", $check_num )
        if not AMOS7::Assert::is_number($check_num);

    my $calc_result;
    my $input_len = length($check_num);

    ## from AMOS7::INLINE ##
    #
    return AMOS7::Assert::Truth::true_int($check_num)
        if index( $check_num, qw| . |, 0 ) == -1
        and $check_num <= 18446744073709551615    ## 64 bit ##
        and defined &AMOS7::Assert::Truth::true_int
        and \&AMOS7::Assert::Truth::true_int ne \&calc_true;

    return AMOS7::Assert::Truth::true_float($check_num)
        if $input_len < 17
        and defined &AMOS7::Assert::Truth::true_float
        and \&AMOS7::Assert::Truth::true_float ne \&calc_true;
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
    return FALSE if exists $false{$calc_result};

    ### TRUE ### 384615 ####         ## implement visualization mode ##  [LLL]
    return TRUE if exists $true{$calc_result};

    ### TRUE ### 0000000 | 1 ####
    return TRUE;
}

sub is_true_with_template {
    if ( @ARG < 1 ) {
        warn_err('expected at least template string and input params');
        return undef;
    }
    my $template = shift;

    if ( not defined $template ) {
        warn_err('template parameter not defined');
        return undef;
    } elsif ( not is_template_syntax_valid($template) ) {
        warn_err('template syntax is not valid');
        return undef;
    }

    my @templates_and_params;
    foreach
        my $tmpl ( AMOS7::TEMPLATE::split_truth_templates($template)->@* ) {
        push @templates_and_params, [ $tmpl, @ARG ];
    }

    foreach my $check_ref ( [ undef, @ARG ], @templates_and_params ) {
        ( my $template, my @check_args ) = $check_ref->@*;
        if ( not defined $template ) {

            my $is_true = is_true(@check_args);

            return FALSE if not defined $is_true or not $is_true;

        } else {
            my $data_ref = shift @check_args;

            $data_ref = join( ' ', $data_ref->@* )
                if ref $data_ref eq qw| ARRAY |;

            $data_ref = \"$data_ref" if ref $data_ref ne qw| SCALAR |;

            unshift @check_args, \sprintf $template, $data_ref->$*;

            return FALSE if not is_true(@check_args);
        }
    }

    return TRUE;    ## true ##
}

sub is_template_syntax_valid {
    my $template = shift // '';
    my $silence  = shift // FALSE;    ## no syntax warning ##

    ( my $template_valid, my $template_errstr )
        = AMOS7::TEMPLATE::is_valid_template($template);

    if ( not $template_valid ) {
        warn_err( sprintf( '%s <{C2}>', $template_errstr ) )
            if not $silence;
        return FALSE;    ##  false  ##
    }

    return TRUE;         ## true ##
}

return TRUE ##################################################################

#,,.,,.,.,...,..,,.,,,.,.,..,,..,,.,,,,,.,...,..,,...,...,.,.,.,,,,,,,..,,,..,
#IIMUEJP6HARSRRF7O7FVGIHK4RQPZ4NAMTAR4KPEF7O5B3S4TZNFADLSXM4YZ6ILCQV3BIJDT7M5C
#\\\|GUOUDDPY5VGRRNRBWQWAH7QW2AVU7AQRTZEV7IDVDJ7HH7EPF6M \ / AMOS7 \ YOURUM ::
#\[7]TIXTXGFTWV6DVHMVWCJQ4BUFBEHBO2VJCGVVREGPWPKV57EIDIAI 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
