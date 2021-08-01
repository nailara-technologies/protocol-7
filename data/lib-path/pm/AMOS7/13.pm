
package AMOS7::13; ###########################################################

use v5.32;
use strict;
use English;
use warnings;

use AMOS7;
use AMOS7::Assert;
use AMOS7::Assert::Truth qw| is_true |;

use AMOS7::INLINE;

## AMOS7::BitConv ##
compile_inline_source( { qw| subroutine-name | => qw| bit_string_to_num | } );

use Crypt::Misc qw| encode_b32r |;

use Time::HiRes qw| time sleep |;

use vars qw| $VERSION @EXPORT |;

use Exporter;
use base qw| Exporter |;

@EXPORT = qw[

    gen_entropy_values

    divide_13
    harmonize_13

    bin_032
    bin_056
    num_to_str
    asc_to_bin_056
    reverse_bin_032
    reverse_bin_056
    bin_to_comp_int

];

##[ INITIALIZATIONS ]#########################################################

my $verbose = 0;

## my $min_seed_data_len = 13;
my $min_seed_data_len = 4;

my $genseed_iterations_0 = 9216;
my $genseed_iterations_1 = 9216;

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

    return sprintf( qw| %09d |, $num / 13 ) if $num_len < 2;
    return sprintf( qw| %09d |, ( $num << 5 ) / 13 );
}

##[ INIT ENTROPY ]############################################################

sub gen_entropy_values {
    my $requested_value_count;
    my $seed_data_sref = shift;
    if ( defined $ARG[0] and $ARG[0] =~ m|^\d+$| ) {    ## optional ##
        $requested_value_count = shift;
        if ( $requested_value_count == 0 ) {
            warn_err('value count of 0 is not valid <{C1}>');
            return undef;
        }
    }
    my $output_reference = shift;
    my $filter_coderef   = shift;

    my @seed_blocks;
    my @entropy_data;
    my $file_output     = 0;
    my $req_b32_encoded = 0;

    if ( ref $seed_data_sref ne qw| SCALAR | ) {
        warn_err('expected scalar ref to seed data <{C1}>');
        return undef;
    } elsif ( ref $seed_data_sref eq qw| SCALAR |
        and length( $seed_data_sref->$* ) < $min_seed_data_len ) {
        warn_err( 'seed data must be at least %d characters long <{NC}>',
            1, $min_seed_data_len );
        return -1;
    } elsif ( defined $seed_data_sref ) {
        ( my $test_characters = $seed_data_sref->$* ) =~ s|\s+||g;
        if ( length($test_characters) < 5 ) {
            warn_err('seed data needs 5 non-whitespace characters <{NC}>');
            return -2;
        }
    }
    if (   ref $output_reference eq qw| IO::File |
        or ref $output_reference eq qw| IO::Handle | ) {
        if ( not length fileno($output_reference) ) {
            warn_err('second parameter not [open] filehandle <{C1}>');
            return undef;
        } elsif ( ref $filter_coderef ne qw| CODE | ) {
            warn_err('filehandle also requires a CODE ref parameter <{C1}>');
            return undef;
        } else {

            $file_output = $req_b32_encoded = 5;    ## true ##

        }
    } elsif ( defined $output_reference
        and ref $output_reference eq qw| ARRAY |
        and defined $filter_coderef ) {
        warn_err( 'filter parameter not expected '
                . 'with output reference type ARRAY <{C1}>' );
        return undef;
    } elsif ( defined $output_reference
        and ref $output_reference eq qw| SCALAR | ) {

        $req_b32_encoded = 5;    ## true ##

    } elsif ( defined $output_reference
        and ref $output_reference ne qw| ARRAY |
        and ref $output_reference ne qw| SCALAR | ) {
        warn_err( "output ref type '%s' not valid <{C1}>",
            1, ref $output_reference );
        return undef;
    }

    my $bit_size = 49;

    my $seed_bits = get_seed_bits($seed_data_sref);
    my $bits_len  = length $seed_bits;

    my $result = offset_comp_int( \$seed_bits, -$bit_size );

    my $seed_bit_offs = 0;

    my $t_start = sprintf( qw| %.5f |, Time::HiRes::time ) if $verbose;

    my $iteration = 1;

    for ( 1 .. $requested_value_count || $genseed_iterations_0 ) {

        ( my $cur_block_val, my $block_bits )
            = offset_comp_int( \$seed_bits, $bit_size - ++$seed_bit_offs );

        $seed_bit_offs %= -$bits_len;

        my $apply_at = 1 + abs(
            AMOS7::BitConv::bit_string_to_num(
                substr( $block_bits->$*, 0, 4 )
            ) - 1
        );

        my $recalc = 0;

        if ( $recalc or $ARG % $apply_at == 0 ) {
            my $bits_0 = sprintf qw| %032B |, $result;
            my $bits_1 = substr( $block_bits->$*, 0, 32 );
            my $nand_bits;
            foreach my $pos ( 0 .. 31 ) {
                $nand_bits .= nor(
                    substr( $bits_0, $pos, 1 ),
                    substr( $bits_1, $pos, 1 )
                );
            }
            $result += AMOS7::BitConv::bit_string_to_num($nand_bits);
        }

        $result = divide_13($result);

        while ( not is_true( \$result, 2, 1 ) ) {
            $result = divide_13($result);
        }

        push @seed_blocks, $result;

        say $C{'0'}, '< SEED > ', $C{'T'}, $result, $C{'R'} if $verbose;

        ++$iteration;
    }

    for ( 1 .. $requested_value_count || $genseed_iterations_1 ) {

        ##  apply collected seed numbers  ##
        ##
        $result += shift @seed_blocks;

    RECALC_0110:

        $result = divide_13($result);

        goto RECALC_0110 if not is_true( $result, 2, 1 );

        my $encoded_result;

        if ($req_b32_encoded) {

            my $vax_bin = pack qw| V |, $result;
            goto RECALC_0110 if not is_true( $vax_bin, 0, 1 );

            $encoded_result = encode_b32r($vax_bin);
            goto RECALC_0110 if not is_true( $encoded_result, 0, 1 );

            say $C{'0'}, '< RSB32 > ', $C{'T'}, $encoded_result if $verbose;
        }
        ## result data output ##
        ##
        if ($req_b32_encoded) {
            push @entropy_data, $encoded_result;
        } else {
            push @entropy_data, $result;
        }

        ++$iteration;
    }

    while ( defined $output_reference
        and my $output_value = pop @entropy_data ) {  ##  in reverse order  ##

        if ($file_output) {    ##  file encryption done in code reference  ##
            print {$output_reference} $filter_coderef->($output_value);

        } elsif ( ref $output_reference eq qw| ARRAY | ) {
            push $output_reference->@*, $output_value;
        } elsif ( ref $output_reference eq qw| SCALAR | ) {
            if ( defined $filter_coderef ) {
                $output_reference->$* .= $filter_coderef->($output_value);
            } else {
                $output_reference->$* .= $output_value;
            }
        }
    }

    ## time ellapsed ##
    printf "$C{0} $C{b}::::::::$C{R}$C{0} $C{b}%s s$C{R}\n\n",
        sprintf( qw| %.5f |, Time::HiRes::time - $t_start )
        if $verbose;

    if ($file_output) { return 0 if not close($output_reference) }

    if ( not defined $output_reference ) {

        ##  values in list context [ last value first ]  ##
        ##
        return reverse @entropy_data if wantarray;

        return $result;    ## only last value in scalar context ##

    } else {    ##  otherwise report success only  ##
        return 5;    ## true ##
    }
}

##[ BINARY OPERATIONS ]#######################################################

sub offset_comp_int {

    my $bits_ref  = shift;
    my $first_pos = shift // 0;
    my $bit_size  = 49;

    if ( ref $bits_ref ne qw| SCALAR | ) {
        warn_err('expected scalar ref param to bitstring <{C1}>');
        return undef;
    } elsif ( not defined $bits_ref->$* or $bits_ref->$* !~ m|^[01]{49,}$| ) {
        warn_err('expected [ >= 49 bit ] bitstring <{C1}>');
        return undef;
    } elsif ( not defined $first_pos or $first_pos !~ m|^-?\d+$| ) {
        warn_err('second param expected to be a bit offset <{C1}>');
        return undef;
    }

    my $bits_len = length $bits_ref->$*;

    if ( $bits_len < $bit_size ) {
        $bits_ref = \scalar( $bits_ref->$* x 3 );
    }

    ##  correct offset overflow  ##
    if ( $first_pos < 0 ) {
        $first_pos %= -$bits_len;
        $first_pos += $bits_len;
    } else {
        $first_pos %= $bits_len;
    }

    my $offset_bits = substr $bits_ref->$*, $first_pos, $bit_size;

    $offset_bits .= substr $bits_ref->$*, 0, $bit_size - length($offset_bits)
        if length($offset_bits) < $bit_size;

    say sprintf '< bits [ %03d ]> %s', $first_pos, $offset_bits if $verbose;

    my $comp_int = bits_to_comp_int($offset_bits) / 13 / 13 / 13 / 13 / 13;

    return ( $comp_int, \$offset_bits ) if wantarray;
    return $comp_int;

}

sub get_seed_bits {
    my $bits;
    my $seed_data_sref = shift;
    if ( ref $seed_data_sref ne qw| SCALAR | ) {
        warn_err('expected scalar ref to seed data <{C1}>');
        return undef;
    }
    my $min_bit_len = 49;

    my $first_part = join '',
        unpack qw| C* |, substr $seed_data_sref->$*, 0, 3;

    for (
        my $bitoffs = 0;
        $bitoffs <= length( $seed_data_sref->$* );
        $bitoffs += 3
    ) {

        my $keyblock = substr $seed_data_sref->$*, $bitoffs, 3;
        my $asc_num  = join '', unpack( qw| C* |, $keyblock );
        my $asc_len  = length $asc_num;

        $asc_num .= substr $first_part, 0, 9 - $asc_len if $asc_len < 9;
        $bits .= sprintf qw| %B |, divide_13($asc_num);
    }

    $bits =~ s|0+$||;
    $bits = join '', map { $ARG == 1 ? qw| 0 | : qw| 1 | } split '', $bits;

    while ( length($bits) < $min_bit_len ) {
        $bits .= substr( $bits, 0, $min_bit_len - length $bits );
    }

    return $bits;
}

sub nand { $ARG[0] & $ARG[1] ? 0 : 1 }

sub nor { $ARG[0] || $ARG[1] ? 0 : 1 }

sub bin_032 {
    my $numerical_32 = shift // 0;

    return warn sprintf( 'expected 32 bit number, got %d digits %s',
        length($numerical_32), caller_str(1) )
        if not is_number($numerical_32)
        or $numerical_32 > 4294967295;

    sprintf qw| %032B |, $numerical_32;
}

sub reverse_bin_032 {
    my $numerical_32 = shift // 0;

    return warn sprintf( 'expected 32 bit number, got %d digits %s',
        length($numerical_32), caller_str(1) )
        if not is_number($numerical_32)
        or $numerical_32 > 4294967295;

    join( '', reverse( split '', sprintf( qw| %032B |, $numerical_32 ) ) );
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

    my $bits_56 = shift // unpack qw| B* |, $buffer_ref->$*;

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

sub bits_to_comp_int {    ##  takes array with 49 bit and returns comp int  ##

    my $bits = shift // '';

    if ( length($bits) < 7 or length($bits) % 7 != 0 ) {
        warn_err 'requires bitstring [ > 7 and % 7 == 0 ] <{C1}>';
        return undef;
    }

    my $result_buffer;
    for ( 1 .. 7 ) {
        if ( $ARG < 7 ) {
            $result_buffer .= pack qw| B8 |, sprintf qw| 1%s |,
                substr( $bits, $ARG * 7, 7 );
        } else {
            $result_buffer .= pack qw| B8 |, sprintf qw| 0%s |,
                substr( $bits, $ARG * 7, 7 );
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
    my $numerical_32 = shift;
    return '' if not length( $numerical_32 // '' );
    return warn_err('expected 9 digit decimal value <{C1}>')
        if not is_number($numerical_32)
        or length($numerical_32) > 9;

    return $numerical_32, '| : ',
        pack qw| c* |,
        substr( $numerical_32, 0, 1 ),
        substr( $numerical_32, 1, 2 ),
        substr( $numerical_32, 3, 2 ),
        substr( $numerical_32, 5, 2 ),
        substr( $numerical_32, 7, 2 );
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

#,,.,,,,,,,..,..,,...,..,,,,,,,,.,...,,.,,...,..,,...,...,,.,,,,,,,,.,,,,,.,,,
#D2PGRPGKV76QRNZ6JZE7BF4YJQUGVWFWHGTMBXCP6KAECINQTDCQHR72NAYJ5K35JLSHJWB62HQKE
#\\\|Y2KD4DBCVZI7SU7LZGU4X322IE7LQYRKZ5XVJZSVYB7PO7K4TVO \ / AMOS7 \ YOURUM ::
#\[7]5M35EWSYDYXQBP5VTF5MGP6UDC6QXUEJ7MKMIFDXNDX7VJKZ7WCY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
