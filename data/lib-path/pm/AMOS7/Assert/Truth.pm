##  [:<  ##

package AMOS7::Assert::Truth; ################################################
our $VERSION = qw| AMOS7::Assert::Truth-VERSION.C3BUQXY |;

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
use List::MoreUtils qw| uniq |;
use Math::BigInt;
use POSIX qw| frexp |;

##[ AMOS MODULE ]#############################################################

use AMOS7;
use AMOS7::Assert;
use AMOS7::INLINE;
use AMOS7::TEMPLATE;

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

    ## reject non-integer mode args early — otherwise downstream numeric == ##
    ## checks warn-spam and callers see silent fallback                     ##
    ## [ any non-negative integer accepted — P7 TRUE = 5 is used ]          ##
    return warn_err(
        sprintf "invalid check_as_num mode [ '%s' ] : expected integer",
        $check_as_num )
        if $check_as_num !~ m{^\d+$};
    return warn_err(
        sprintf "invalid check_as_elf mode [ '%s' ] : expected integer",
        $check_as_elf )
        if $check_as_elf !~ m{^\d+$};

    return warn_err('no checks enabled')
        if not $check_as_num and not $check_as_elf;

    $data_ref = join( ' ', $data_ref->@* ) if ref $data_ref eq qw| ARRAY |;
    $data_ref = \"$data_ref"               if ref $data_ref ne qw| SCALAR |;

    return warn_err('undefined input <{C2}>') if not defined $$data_ref;

    my @assertion_modes = uniq @ARG ? @ARG : @assertion_modes;

    return FALSE    ## check as num when numerical ##
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

##  asserts truth of arbitrary len. numerical value [ division by 13 ]  ##
##
## residue table of compiled true_int [ verified on 22001 values ] n mod 13 ##
## in this set resolves to FALSE [ 0 ], otherwise TRUE [ 5 ]                ##
my %false_residue = map { $_ => 1 } qw| 1 3 4 9 10 12 |;

sub calc_true {

    my $check_num = shift;

    ##                                 ##
    ## returns 5 for true, 0 for false ##
    ##                                 ##

    ## negatives are numerical for the compiled oracle [ its unsigned long ##
    ## parameter wraps, its double parameter keeps the sign ] : accept the ##
    ## is_number shapes plus sign, leading-dot and e[+-] exponents         ##
    error_exit( "input '%s' not numerical", $check_num )
        if $check_num !~ m{^-?(?:\d+(?:\.\d+)?|\.\d+)(?:e[+-]?\d+)?$}i;

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

    ## pure-perl fallback paths below are bit-identical to the compiled  ##
    ## oracle [ true_int \ true_float ] -- verified on large vector sets ##

    ## the compiled functions' own range : emulate them bit-exactly ##
    return pure_true_int($check_num)
        if index( $check_num, qw| . |, 0 ) == -1
        and $check_num <= 18446744073709551615;    ## 64 bit ##

    return pure_true_float($check_num)
        if $input_len < 17
        or $check_num =~ m{e}i;

    ## beyond it [ the long numbers the compiled path never sees ] : exact  ##
    ## -- the residue of the digits without the point [ a decimal shift is  ##
    ## neutral mod 13 ; the sign too : -1 is a square mod 13 ]. same as the ##
    ## former arbitrary precision division [ 3040 long values, 0 off ]      ##
    ( my $digits = $check_num ) =~ s{[^0-9]}{}g;
    my $remainder = 0;
    $remainder = ( $remainder * 10 + $ARG ) % 13 for split m||, $digits;
    return $false_residue{$remainder} ? FALSE : TRUE;
}

##[ PURE-PERL ORACLE-IDENTICAL FALLBACK ]#####################################

## fcvt false-pattern search windows of the constant ecvt( 3/13, 13 ) digit ##
## string '2307692307692' : six rotating windows of the 230769 cycle        ##
my @false_patterns = qw| 230769 307692 076923 769230 692307 923076 |;

## exact digit-wise mod 13 residue table [ any length ] ##
sub pure_true_int {

    my $check_num = shift;

    my $negative = 0;
    my $digits;

    if ( $check_num =~ m{^(\d+)$} ) {    ## plain digit string ##
        $digits = $1;
        ## sv_2uv clamps positive overflow to the 64 bit maximum ##
        $digits = '18446744073709551615'
            if length($digits) > 20
            or
            ( length($digits) == 20 and $digits gt '18446744073709551615' );
    } elsif ( $check_num =~ m{^-(\d+)$} ) {
        if ( length($1) < 19
            or ( length($1) == 19 and $1 le '9223372036854775808' ) ) {
            $negative = 1;    ## compiled unsigned long parameter wraps ##
            $digits   = $1;
        } else {
            ## sv_2uv clamps negative overflow to 2**63 ##
            $digits = '9223372036854775808';
        }
    } else {
        ## conversion identical to the compiled parameter [ SvUV ] :   ##
        ## negative values wrap into the unsigned 64 bit range already ##
        my $assert_num = int( 0 + $check_num );
        ## SvUV clamps non-finite input : positive -> UV_MAX, negative -> ##
        ## 2**63 [ like every negative overflow ]                         ##
        if ( $assert_num == 9**9**9 ) { $assert_num = 18446744073709551615 }
        elsif ( $assert_num == -( 9**9**9 ) ) {
            $assert_num = 9223372036854775808;
        }

        return TRUE if $assert_num == 0;    ## matches C early return ##
        $digits = sprintf qw| %u |, $assert_num;
    }

    ## digit-wise mod 13 over the decimal representation ##
    my $remainder = 0;
    $remainder = ( $remainder * 10 + $ARG ) % 13 for split m||, $digits;

    ## 2**64 mod 13 == 3 : wrap the residue for negative input ##
    $remainder = ( 16 - $remainder ) % 13 if $negative;

    return FALSE if $false_residue{$remainder};    ## residue table ##
    return TRUE;
}

sub pure_true_float {    ## bit-exact emulation of compiled true_float ##

    my $check_num = shift;

    ## fmodl( -x, 13 ) == -fmodl( x, 13 ) : the sign only reaches the fcvt ##
    ## sign output, the digit search runs over the absolute value          ##
    my $value = abs( 0 + $check_num );    ## C double parameter ##

    ## non-finite input : fmodl gives nan, fcvt yields no digit patterns ##
    return TRUE if $value != $value or $value == 9**9**9;    ## nan | inf ##

    ## exact decomposition of the double [ value == mantissa * 2**shift ] ##
    my ( $fraction, $exp2 ) = POSIX::frexp($value);
    my $mantissa = int( $fraction * 9007199254740992 );      ## 2**53 scale ##
    my $shift    = $exp2 - 53;

    return TRUE if $mantissa == 0;    ## zero : no false pattern matches ##

    ## emulate fmodl( value, 13 ) : remainder as exact rational r_num/2**j ##
    my $r_num;
    my $j;                            ## denominator of remainder is 2**j ##

    if ( $shift >= 0 ) {              ## integer valued double ##

        ## ( mantissa * 2**shift ) mod 13 : 2**k mod 13 cycles period 12 ##
        my $pow2_mod
            = ( 1, 2, 4, 8, 3, 6, 12, 11, 9, 5, 10, 7 )[ $shift % 12 ];
        $r_num = ( ( $mantissa % 13 ) * $pow2_mod ) % 13;
        $j     = 0;

    } else {    ## fractional double : r == mantissa mod ( 13 * 2**j ) ##

        $j = -$shift;
        if ( $j > 52 or $mantissa < ( 13 << $j ) ) {
            $r_num = $mantissa;    ## value < 13 : remainder is the value ##
        } else {
            my $thirteen_j = 13 << $j;
            my $multiple   = int( $mantissa / $thirteen_j );
            $r_num = $mantissa - $multiple * $thirteen_j;
        }
    }

    return TRUE if $r_num == 0;    ## all-zero digits : no pattern match ##

    ## binary exponent t of r/13 : 13 * 2**t <= r_num < 13 * 2**( t + 1 ) ##
    my $bit_len = length sprintf qw| %b |, $r_num;
    my $t
        = $bit_len < 5                        ? $bit_len - 5
        : $r_num < ( 13 << ( $bit_len - 4 ) ) ? $bit_len - 5
        :                                       $bit_len - 4;

    ## 64 bit mantissa of r/13 [ correctly rounded, exact ties impossible : ##
    ## division remainder compared against odd denominator 13 ]             ##
    my $num = Math::BigInt->new($r_num)->blsft( 63 - $t );
    my ( $mant64, $rem64 ) = $num->copy->bdiv(13);
    $mant64->binc if $rem64->blsft(1)->bcmp(13) > 0;

    ## compiled pipeline converts the long double quotient to the double ##
    ## fcvt parameter [ round to 53 bit, ties to even, subnormal aware ] ##
    my ( $mant, $k ) = round_to_double( $mant64, $t - $j );

    return TRUE if $mant == 0;    ## underflow : all-zero digit string ##

    ## fcvt( v, 17 ) semantics [ glibc %.*f based conversion ] : round the  ##
    ## exact decimal expansion of the double to 17 digits after the decimal ##
    ## point, ties to even, then strip leading zeros with dec_pt adjustment ##
    ##                                                                      ##
    ## exact finite expansion : v == N / 10**k                              ##
    my $dec = Math::BigInt->new(5)->bpow($k)->bmul($mant);
    my $N   = "$dec";
    my $F   = ( '0' x ( $k - length $N ) ) . $N;             ## v == 0.F ##

    my $frac17;
    if ( length $F <= 17 ) {    ## terminates within 17 places ##
        $frac17 = $F . ( '0' x ( 17 - length $F ) );
    } else {                    ## round at the 17th fractional digit ##
        $frac17 = substr( $F, 0, 17 );
        my $rest = substr( $F, 17 );
        my $half = '5' . ( '0' x ( length($rest) - 1 ) );
        my $cmp  = $rest cmp $half;
        if ( $cmp > 0 or $cmp == 0 and substr( $frac17, -1 ) % 2 ) {
            $frac17++;    ## string increment : 999..9 rolls to 1000..0 ##
        }
    }

    ## value < 1 : integer part is '0', or '1' when rounding carries ##
    my $full_digits
        = length $frac17 > 17 ? '1' . ( '0' x 17 ) : '0' . $frac17;

    ## strip leading zeros : dec_pt tracks the decimal point position ##
    ( my $sig_digits = $full_digits ) =~ s{^0+}{};
    my $first_sig = length($full_digits) - length $sig_digits;
    my $dec_pt    = 1 - $first_sig;

    ## false-pattern window search with the compiled decimal point rule :   ##
    ## 'mpos > decimal_pt' compares unsigned int against int                ##
    ## [ C usual arithmetic conversions ] : dec_pt < -1 converts to a huge  ##
    ## unsigned value, so no match position can ever satisfy the comparison ##
    ## -- values resolving to dec_pt < -1 [ v < 0.01 ] are always TRUE      ##
    my $min_pos = $dec_pt >= 0 ? $dec_pt + 1 : $dec_pt == -1 ? 0 : -1;
    return TRUE if $min_pos < 0;    ## dec_pt < -1 : unsigned compare ##
    foreach my $pattern (@false_patterns) {
        my $match_pos = index( $sig_digits, $pattern );
        return FALSE if $match_pos >= $min_pos;
    }
    return TRUE;
}

sub round_to_double {    ## exact long double [ m,e ] to double [ M,k ] ##

    ## input  : value == m * 2**( e - 63 )  [ m is a 64 bit BigInt ] output ##
    ## : value53 == M * 2**-k  [ IEEE 754 double, round nearest, ties to    ##
    ## even, subnormal grid 2**-1074 below 2**-1022 ]                       ##

    my $m = shift;
    my $e = shift;

    if ( $e >= -959 ) {    ## normal double range [ v >= 2**-1022 ] ##

        my $mant = $m->copy->brsft(11);       ## 64 -> 53 bit ##
        my $drop = $m->copy->bmod(2048);
        my $cmp  = $drop->bcmp(1024);
        $mant->binc if $cmp > 0 or $cmp == 0 and $mant->is_odd;
        if ( $mant->bcmp( 2**53 ) == 0 ) {    ## carry rollover ##
            $mant = Math::BigInt->new(2)->bpow(52);
            $e++;
        }
        return ( $mant, 52 - $e );

    } else {    ## subnormal double range : integer grid of 2**-1074 ##

        ## value / 2**-1074 == m * 2**( e + 1011 ) ##
        my $scaled = Math::BigInt->new($m);
        if ( $e + 1011 >= 0 ) {
            $scaled->blsft( $e + 1011 );
        } else {
            my $div = Math::BigInt->new(1)->blsft( -$e - 1011 );
            my ( $q, $rem ) = $scaled->bdiv($div);
            my $round_cmp = $rem->blsft(1)->bcmp($div);
            $q->binc if $round_cmp > 0 or $round_cmp == 0 and $q->is_odd;
            $scaled = $q;
        }
        return ( $scaled, 1074 );
    }
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

#,,.,,.,.,,.,,...,,,.,,,.,,.,,...,...,.,,,...,..,,...,...,.,.,,,.,.,,,...,.,,,
#VQACKYL4TRGVVHCY6YQNFEB5LU7DCAENGYHWD32X6CS5WB2MFQ2BZMVYKDDJIFYC72DE65DN7BKVI
#\\\|OM5QFFL64OK7APAIVYJJ4YLQGVFK37GGV5AM5GXFBFCYTMQQ65W \ / AMOS7 \ YOURUM ::
#\[7]2TQNANJGGTZIHEFE5WLMVTFEYJC6ZBW6SCU67Z57MUM7JWUAFSBY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
