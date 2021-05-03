
package AMOS::13;  ###########################################################

use v5.24;
use strict;
use English;
use warnings;

use AMOS;
use AMOS::Assert;
use AMOS::Assert::Truth;

use Time::HiRes qw| time |;

use vars qw| $VERSION @EXPORT |;

use Exporter;
use base qw| Exporter |;

@EXPORT = qw[
    divide_13
    harmonize_13
    gen_seed_val
    num_to_str
    show_bin
    bin_reverse
];

##[ INITIALIZATIONS ]#########################################################

my $verbose = 1;

my $min_seed_data_len = 13;
my $iterations_1001   = 113;
my $iterations_0000   = 113;

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
    return error_exit('parameter is not numerical') if not numerical($num);

    return 0 if $num == 0;

    my $num_len = zulum_prefix_length($num);
    return sprintf( qw| %09d |, $num / 13 ) if $num_len == 0;

    my $factor = join( '', qw| 10 |, qw| 0 | x $num_len );

    return sprintf( qw| %09d |, $factor * $num / 13 );
}

##[ DATA HARMONIZATION ]######################################################

sub harmonize_13 {
    my $value_num = shift;
    return error_exit('expected numerical input value')
        if not numerical($value_num);

    my $bin_str = show_bin($value_num);
    my $rev_bin = bin_reverse($value_num);

    say '' if $verbose;
    my $iterations = 0;
    while (not is_true($value_num)
        or not is_true($bin_str)
        or not is_true($rev_bin) ) {

        $value_num = divide_13($value_num);

        $bin_str = show_bin($value_num);
        $rev_bin = bin_reverse($value_num);

        visualize( $iterations++, $value_num ) if $verbose;
    }
    visualize( $iterations, $value_num ) if $verbose and $iterations == 0;

    say ''                                  if $verbose;
    return ( $value_num, abs($iterations) ) if wantarray;
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

    say $C{0} . ':.';

    while ( length $$seed_data_sref ) {
        my $pkey_block = substr( $$seed_data_sref, 0, 3, '' );
        my $p_num      = join( '',
            map { sprintf '%03d', ord($ARG) } split( '', $pkey_block ) );

        my $blklen = length($p_num);
        $p_num .= substr( $first_part, 0, 9 - $blklen ) if $blklen < 9;

        ## make passphrase seed harmonic  ##
        push( @seed_blocks, harmonize_13($p_num) );
    }

    say $C{0} . '.:';

    my $result;
    my $first_val = divide_13( $seed_blocks[0] );

    $result = $first_val;

    my $index = 0;

    my $t_start = sprintf( '%.5f', time ) if $verbose;

    my $iteration = 0;

    for ( 1 .. $iterations_1001 ) {    ## seeding with passphrase xor merge ##

        my $result_str = num_to_str($first_val);

        my $cur_block_val = $seed_blocks[$index];

        say $C{0}
            . '< BLOCK > '
            . join( ' ', show_bin($cur_block_val), $cur_block_val )
            . $C{R};

        my $xord_str = sprintf( '%09d', $result ^ $cur_block_val );
        my $xord_num = $xord_str;

        #        my $xord_num = join( '', map {ord} split '', $xord_str );

       #my $xord_num = divide_13( join( '', map {ord} split '', $xord_str ) );

## LLL
        #        my $cut_iterations = 0;
        #        my $over_len       = length($xord_num) - 9;
        #        if ($over_len) {
        #            my $left_over = substr( $xord_num, 0, $over_len, '' );
        #        }

        say $C{0}
            . '< x-ord > '
            . join( ' ', show_bin($xord_num), sprintf '%9s', $xord_num )
            . $C{R};

    RECALC_0000:

        $result = divide_13($result);

        goto RECALC_0000 if not is_true($result);

        visualize( $iteration, $result ) if $verbose;

        ++$iteration;

        $index = 0 if not defined $seed_blocks[ ++$index ];
    }

    for ( 1 .. $iterations_0000 ) {    ## seeding without passphrase xor ##

    RECALC_0110:

        $result = divide_13($result);

        goto RECALC_0110 if not is_true($result);

        ++$iteration;

        visualize( $iteration, $result ) if $verbose;

    }

    visualize( $iteration, $result ) if not $verbose;

    ## time ellapsed ##
    printf "$C{0} $C{b}::::::::$C{R}$C{0} $C{b}%s s$C{R}\n\n",
        sprintf( '%.5f', time - $t_start )
        if $verbose;

    return $result;

}

##[ BINARY OPERATIONS ]#######################################################

sub show_bin {
    sprintf( qw| %032b |, shift // 0 );
}

sub bin_reverse {
    join( '', reverse( split( '', sprintf( qw| %032b |, shift // 0 ) ) ) );
}

##[ UTILITY FUCTIONS ]########################################################

sub padded_num {
    my $input_num   = shift;
    my $padding_num = shift;
    return error_exit('expected numerical input parameters')
        if not numerical($input_num)
        or not numerical($padding_num);
    my $input_len = length($input_num);
    my $pad_len   = length($padding_num);

    return $input_num if $input_len >= $pad_len;

    return substr( $input_num, 0, $pad_len - $input_len );
}

##[ STRING CONVERSIONS ]######################################################

sub num_to_str {
    return '' if @ARG or not defined $ARG[0];
    return join( '',
        map {chr} substr( $ARG[0], 0, 1 ),
        substr( $ARG[0], 1, 2 ),
        substr( $ARG[0], 3, 2 ),
        substr( $ARG[0], 5, 2 ),
        substr( $ARG[0], 7, 2 ) );
}

##[ VERBOSE MODE ]############################################################

sub visualize {
    my $index     = shift;
    my $value_num = shift;
    my $T_state   = is_true($value_num) ? qw| TRUE | : qw| FALSE |;
    my $bin_0000  = bin_reverse($value_num);    ## reverse left ##
    my $bin_0110  = show_bin($value_num);       ## actual right ##
    my $c0        = is_true($bin_0000) ? join( '', $C{T}, $C{B} ) : $C{0};
    my $c1        = is_true($bin_0110) ? join( '', $C{T}, $C{B} ) : $C{0};
    printf( $result_tmpl->{$T_state},
        $index, $value_num,
        join( '', $c0, $bin_0000 ),
        join( '', $c1, $bin_0110 )
    );
}

return 1;  ###################################################################

#.............................................................................
#EGJXEX3ACZ6YJBMRSBLXB5VPWREIM7YHZ6EGYKOAVOE7ROZ4JJVUDORZHIB66TVEZTSMM4ZF3JYIW
#::: RKYKPF7TQG3GOCIGG3RKAZHSEHA6JOHM2ILVJVXJAN2V7YZR2PU :::: NAILARA AMOS :::
# :: BSURSWJC4JUS64AWAZK7YFRMMF2MCHKRF6EGDV6PAE4O2RT25CDA :: CODE SIGNATURE ::
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
