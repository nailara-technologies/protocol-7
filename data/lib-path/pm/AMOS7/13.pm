
package AMOS7::13; ###########################################################

use v5.24;
use strict;
use English;
use warnings;

use AMOS7;
use AMOS7::Assert;
use AMOS7::Assert::Truth;

use Time::HiRes qw| time |;

use vars qw| $VERSION @EXPORT |;

use Exporter;
use base qw| Exporter |;

@EXPORT = qw[

    divide_13
    harmonize_13

    gen_seed_val

    bin_032
    bin_056
    num_to_str
    asc_to_bin_056
    reverse_bin_032
    reverse_bin_056
    bin_to_comp_int

];

##[ INITIALIZATIONS ]#########################################################

my $verbose = 1;

my $min_seed_data_len = 13;
my $iterations_1001   = 4200;
my $iterations_0000   = 4200;

my $result_tmpl = {
    qw| TRUE | => " $C{b}$C{T}:$C{0}"
        . " %04d$C{b}$C{0} $C{T}:$C{R}"
        . " $C{b}$C{B}$C{T}%s$C{R}"
        . " $C{b}%s$C{R}"
        . " $C{b}%s$C{R}\n",
    qw| FALSE | => " $C{b}$C{0}  "
        . "%04d$C{R}$C{b}$C{0}  $C{R}"
        . " $C{b}$C{0}%s$C{R}"
        . " $C{b}%s$C{R}"
        . " $C{b}%s$C{R}\n"
};

##[ DIVISION BY 13 ]##########################################################

sub divide_13 {    ## for short numbers only ## use Math::Bigint later too ##
    my $num = shift;
    return error_exit('parameter is not numerical') if not is_number($num);

    return 0 if $num == 0;

    my $num_len = zulum_prefix_length($num);
    return sprintf( qw| %09d |, $num / 13 ) if $num_len == 0;

    my $factor = join( '', qw| 10 |, qw| 0 | x $num_len );

    return sprintf( qw| %09d |, $factor * $num / 13 );
}

##[ DATA HARMONIZATION ]######################################################

sub harmonize_13 {
    my $value_num  = shift;
    my $show_TRUE  = shift // 0;
    my $show_FALSE = shift // 0;
    return error_exit('expected numerical input value')
        if not is_number($value_num);

    my $bin_str = bin_032($value_num);
    my $rev_bin = reverse_bin_032($value_num);

    my $iterations = 0;
    my $all_true   = 0;

    ## recalculate until all values are true ##
    while ( not $all_true and ++$iterations ) {

        $value_num = divide_13($value_num);
        $bin_str   = bin_032($value_num);
        $rev_bin   = reverse_bin_032($value_num);

        my @truth_states = (
            scalar is_true( $value_num, 1, 0 ),
            scalar is_true( $bin_str,   0, 1 ),
            scalar is_true( $rev_bin,   0, 1 )
        );

        $all_true = 1;
        map { $all_true = 0 if $ARG == 0 } @truth_states;
        $iterations++;

        visualize_bin_032( $iterations, $value_num, @truth_states )
            if $show_TRUE and $all_true
            or not $all_true and $show_FALSE;
    }

    return ( $value_num, $iterations ) if wantarray;
    return $value_num;
}

##[ INIT ENTROPY ]############################################################

sub gen_seed_val {

    my $seed_data_sref = shift;
    return error_exit('expected scalar reference to seed data')
        if not defined $seed_data_sref
        or ref $seed_data_sref ne qw| SCALAR |;
    return error_exit(
        sprintf( 'seed data must be at least %d characters long',
            $min_seed_data_len )
    ) if length($$seed_data_sref) < $min_seed_data_len;

    my @seed_blocks;

    my $first_part = join( '',
        map { sprintf '%03d', ord($ARG) }
            split( '', substr( $$seed_data_sref, 0, 3 ) ) );

    ## say $C{0} . ':.';

    while ( length $$seed_data_sref ) {
        my $pkey_block = substr( $$seed_data_sref, 0, 3, '' );
        my $p_num      = join( '',
            map { sprintf '%03d', ord($ARG) } split( '', $pkey_block ) );

        my $blklen = length($p_num);
        $p_num .= substr( $first_part, 0, 9 - $blklen ) if $blklen < 9;

        ## make passphrase seed harmonic  ##
        push( @seed_blocks, scalar harmonize_13($p_num) );
    }

    ## say $C{0} . '.:';

    ## say $C{'T'} . $C{'B'}, map {"$ARG\n"} @seed_blocks;
    say map {"$ARG\n"} @seed_blocks;

    exit;

    my $result;
    my $first_val = divide_13( $seed_blocks[0] );

    $result = $first_val;

    my $index = 0;

    my $t_start = sprintf( '%.5f', time ) if $verbose;

    my $iteration = 1;

    for ( 1 .. $iterations_1001 ) {    ## seeding with passphrase xor merge ##

        my $result_str = num_to_str($first_val);

        my $cur_block_val = $seed_blocks[$index];

        say $C{0}
            . '< BLOCK > '
            . join( ' ', bin_032($cur_block_val), $cur_block_val )
            . $C{R}
            if 1;

        my $xord_str = sprintf( '%09d', $result ^ $cur_block_val );
        my $xord_num = $xord_str;

        ## my $xord_num = join( '', map {ord} split '', $xord_str );

        ## my $xord_num = divide_13( join( '', map {ord} split '', $xord_str ) );

        ## LLL
        #        my $cut_iterations = 0;
        #        my $over_len       = length($xord_num) - 9;
        #        if ($over_len) {
        #            my $left_over = substr( $xord_num, 0, $over_len, '' );
        #        }

        say $C{0}
            . '< x-ord > '
            . join( ' ', bin_032($xord_num), sprintf '%9s', $xord_num )
            . $C{R}
            if 1;

    RECALC_0000:

        $result = divide_13($result);

        goto RECALC_0000 if not is_true($result);

        ## visualize_bin_032( $iteration, $result ) if $verbose;

        ++$iteration;

        $index = 0 if not defined $seed_blocks[ ++$index ];
    }

    for ( 1 .. $iterations_0000 ) {    ## seeding without passphrase xor ##

    RECALC_0110:

        $result = divide_13($result);

        goto RECALC_0110 if not is_true($result);

        ++$iteration;

        ## visualize_bin_032( $iteration, $result ) if $verbose;

    }

    ## visualize_bin_032( $iteration, $result ) if not $verbose;

    ## time ellapsed ##
    printf "$C{0} $C{b}::::::::$C{R}$C{0} $C{b}%s s$C{R}\n\n",
        sprintf( '%.5f', time - $t_start )
        if $verbose;

    return $result;
}

##[ BINARY OPERATIONS ]#######################################################

sub bin_032 {
    my $digits_032 = shift // 0;

    return warn sprintf( 'expected 32 bit number, got %d digits %s',
        length($digits_032), caller_str(1) )
        if not is_number($digits_032)
        or $digits_032 > 4294967295;

    sprintf qw| %032B |, $digits_032;
}

sub reverse_bin_032 {
    my $digits_032 = shift // 0;

    return warn sprintf( 'expected 32 bit number, got %d digits %s',
        length($digits_032), caller_str(1) )
        if not is_number($digits_032)
        or $digits_032 > 4294967295;

    join( '', reverse( split '', sprintf( qw| %032B |, $digits_032 ) ) );
}

sub bin_056 {
    my $digits_056 = shift // 0;

    return warn sprintf( 'expected 56 bit number, got %d digits %s',
        length($digits_056), caller_str(1) )
        if not is_number($digits_056)
        or $digits_056 > 72057594037927936;

    sprintf qw| %056B |, $digits_056;
}

sub asc_to_bin_056 {
    my $bytes_7 = shift // 0;

    return warn sprintf( 'expected 7 bytes string, got %d %s',
        length($bytes_7), caller_str(1) )
        if length($bytes_7) != 7;

    unpack qw| B56 |, $bytes_7;
}

sub reverse_bin_056 {
    my $digits_056 = shift // 0;

    return warn sprintf( 'expected 56 bit number, got %d digits %s',
        length($digits_056), caller_str(1) )
        if not is_number($digits_056)
        or $digits_056 > 72057594037927936;

    join( '', reverse( split '', sprintf( qw| %056B |, $digits_056 ) ) );
}

sub bin_to_comp_int {
    my $buffer_ref = shift;

    return warn sprintf( "expected scalar reference to 7 bytes string %s\n",
        caller_str(0) )
        if not defined $buffer_ref
        or ref($buffer_ref) ne qw| SCALAR |;
    return
        warn
        sprintf( "scalar reference to expected 7 bytes string, got %d %s\n",
        length($$buffer_ref), caller_str(0) )
        if length($$buffer_ref) != 7;

    my $bits_56 = shift // unpack qw| B* |, $$buffer_ref;

    my $result_buffer;

    for ( 0 .. 7 ) {
        if ( $ARG < 7 ) {
            $result_buffer .= pack qw| B8 |,
                qw| 1 | . substr( $bits_56, $ARG * 7, 7 );
        } else {
            $result_buffer .= pack qw| B8 |,
                qw| 0 | . substr( $bits_56, $ARG * 7, 7 );
        }
    }

    return unpack( qw| w |, $result_buffer );
}

##[ UTILITY FUCTIONS ]########################################################

sub padded_num {
    my $input_num   = shift;
    my $padding_num = shift;

    return warn 'expected numerical input parameters'
        if not is_number($input_num)
        or not is_number($padding_num);

    my $input_len = length($input_num);
    my $pad_len   = length($padding_num);

    return $input_num if $input_len >= $pad_len;

    return substr( $input_num, 0, $pad_len - $input_len );
}

##[ STRING CONVERSIONS ]######################################################

sub num_to_str {
    my $digits_032 = shift;

    return '' if not length( $digits_032 // '' );
    return warn 'expected 9 digit decimal value'
        if not is_number($digits_032)
        or length($digits_032) > 9;

    return join( '',
        map {chr} substr( $ARG[0], 0, 1 ),
        substr( $ARG[0], 1, 2 ),
        substr( $ARG[0], 3, 2 ),
        substr( $ARG[0], 5, 2 ),
        substr( $ARG[0], 7, 2 ) );
}

##[ VERBOSE MODE ]############################################################

sub visualize_bin_032 {
    my $index     = shift(@ARG);
    my $value_num = shift(@ARG);

    my @truth_states = @ARG;

    return warn 'expected numerical index argument' if not is_number($index);
    return warn 'expected numerical <value>'    if not is_number($value_num);
    return warn 'expected 3 truth state values' if not @truth_states == 3;

    my $T_state  = $truth_states[0] ? qw| TRUE | : qw| FALSE |;
    my $bin_0000 = reverse_bin_032($value_num);    ## reverse left ##
    my $bin_0110 = bin_032($value_num);            ## actual right ##
    my $c0       = $truth_states[1] ? join( '', $C{T}, $C{B} ) : $C{0};
    my $c1       = $truth_states[2] ? join( '', $C{T}, $C{B} ) : $C{0};

    printf( $result_tmpl->{$T_state},
        $index, $value_num,
        join( '', $c0, $bin_0000 ),
        join( '', $c1, $bin_0110 )
    );
}

return 1;  ###################################################################

#,,,,,.,.,,..,.,.,,,.,,..,,..,,,,,...,,.,,...,..,,...,..,,.,.,.,,,,.,,..,,..,,
#XY4KMPGWC76UOR3BEYQ7IWXQALR5TPTVOIWB3J6Z3WCUNOWLJE43JDI4ZZCYGXRUQ46YQOJU224RY
#\\\|PX36FOGFTEIJ5OZ5PU2EUYZEVDRBP3WCPPLAVHUAXCIXHAP5ZQD \ / AMOS7 \ YOURUM ::
#\[7]K4TX75TT7C756IH7Y27WDCPBIWGSLR3LO36WYYNCK4DBOITLOABY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
