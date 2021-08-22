## [:< ##

package AMOS7::13; ###########################################################

use v5.28;
use strict;
use English;
use warnings;

##[ global constants ]##
use constant TRUE  => 5;    ##  TRUE.  ##
use constant FALSE => 0;    ##  false  ##

use AMOS7;
use AMOS7::Assert;
use AMOS7::Assert::Truth qw| is_true |;

use AMOS7::INLINE;

## AMOS7::BitConv ##
compile_inline_source( { qw| subroutine-name | => qw| bit_string_to_num | } );

use Digest::BMW;
use Fcntl qw| :seek |;
use Crypt::Misc qw| encode_b32r |;
use Crypt::PRNG::Fortuna qw| irand |;

use Time::HiRes qw| time sleep |;

use vars qw| $VERSION @EXPORT |;

use Exporter;
use base qw| Exporter |;

##  subroutines need clean-up [ remove or extract obsolete ] ##  [ LLL ]
##
@EXPORT = qw[

    key_32
    key_56
    divide_13
    gen_entropy_string
    gen_entropy_values

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

my $min_seed_data_len = 13;

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

sub gen_key_from_file_entropy {

    my $file_path          = shift;   ## path to entropy file ##
    my $seed_phrase        = shift;   ## additional user entropy [optional] ##
    my $wants_true_B32_enc = shift // TRUE; ## binary key true as BASE 32 ? ##

    my $file_read_length = 32768;
    my $fh;
    my $result_keybin;    ##  32 bytes key from file entropy  ##
    my @result_values;    ##  63 numerical values  ##
    if ( not defined $file_path or not length $file_path ) {
        warn_err 'path param expected <{C1}>';
        return undef;
    } elsif ( -d $file_path ) {
        warn_err( "is a directory [ '%s' ]", 1, $file_path );
        return undef;
    } elsif ( not -f $file_path ) {
        warn_err( "path not found [ '%s' ]", 1, $file_path );
        return undef;
    } elsif ( not -r $file_path ) {
        warn_err( "path not readable [ '%s' ]", 1, $file_path );
        return undef;
    } elsif ( not open $fh, qw| <:raw |, $file_path ) {
        warn_err( "error on opening file path [ '%s' ]",
            1, lcfirst $OS_ERROR );
        return undef;
    } elsif ( defined $seed_phrase and not length $seed_phrase ) {
        $seed_phrase = undef;
    }
    my $fstat = File::stat::stat($file_path);
    if ( not defined $fstat ) {
        warn_err( "cannot get stat from file path [ '%s' ]",
            1, lcfirst $OS_ERROR );
        return undef;
    }
    my $fsize_total = $fstat->size;
    my $beginning_255;
    if (   not read( $fh, $beginning_255, 255 )
        or not defined $beginning_255
        or not length $beginning_255 ) {
        warn_err( "cannot read bytes from file path [ '%s' ]",
            1, lcfirst( $OS_ERROR // 'read error' ) );
        return undef;
    } elsif ( not seek $fh, 0, SEEK_SET ) {
        warn_err( "file not seekable [ '%s' ]",
            1, lcfirst( $OS_ERROR // 'seek failed' ) );
        return undef;
    }

    ##  reverse string [ file headers ] ##
    $beginning_255 = join '', reverse split '', $beginning_255;

    if ( length $beginning_255 < 255 ) {
        ##  asc 127 padding for small files  ##
        $beginning_255 .= chr(127) x ( 255 - length $beginning_255 );
    }

    my $seed_iteration_count
        = AMOS7::13::seed_iteration_val( \$beginning_255, 63, 77 );

    my @num_63;

    my $ELF7_sum = { 4 => 0, 3 => 0 };

    my $nand_elf_c_int;
    my $substring_length = 8192;
    while ( tell($fh) < $fsize_total
        and read( $fh, my $buffer, $file_read_length ) ) {

        ##  increased in iterations for smaller files  ##
        ##
        my $buffer_offset = 0;
    OFFSET_READ:

        my $substr_offset = 0;
        while ( $substr_offset < length $buffer ) {  ##[ 4 x 8K per buffer ]##
            $substr_offset += $buffer_offset;
            my $seed_str = substr $buffer, $substr_offset, $substring_length;

            $ELF7_sum->{4}
                = AMOS7::CHKSUM::ELF::elf_chksum( \$seed_str, $ELF7_sum->{4},
                4 );
            $ELF7_sum->{3}
                = AMOS7::CHKSUM::ELF::elf_chksum( \$seed_str, $ELF7_sum->{3},
                3 );

            my $revsum_elf_mode_3 = join '', reverse split '', $ELF7_sum->{3};

            my $XOR_elf_sums = unpack qw| N |,
                $ELF7_sum->{4} |. $revsum_elf_mode_3;

            $nand_elf_c_int .= pack qw| w |, $XOR_elf_sums;
            $substr_offset += $substring_length;
        }

        ##  compensating for smaller files  ##
        ##
        if ( length $nand_elf_c_int < 13 and tell($fh) == $fsize_total ) {
            $buffer_offset++;
            goto OFFSET_READ;
        }

    }

    ##[ 32 bit numbers from file entropy ]##
    ##
    my $status
        = AMOS7::13::gen_entropy_values( \$nand_elf_c_int,
        $seed_iteration_count, \@num_63 );

    if ( not defined $status or not $status or @num_63 == 0 ) {
        warn_err('cannot generate encryption key');
        return undef;
    }

    @num_63 = sort @num_63;
    ##  keep highest 63  ##
    splice( @num_63, 63 - @num_63, 63 ) if @num_63 > 63;

    my @quad_int;

RESEED_KEY_32:

    ##  harmonize numbers [ division by 13 ]  ##
    ##
    foreach my $result (@num_63) {
        $result = divide_13($result);
        while ( not AMOS7::Assert::Truth::is_true( \$result, 2, 1 ) ) {
            $result = divide_13($result);
        }
    }

    my @seed_values_63 = @num_63;

RECALCULATE_KEY_32:

    for ( 0 .. 3 ) {    ##  4 64 bit values required  ##
        my $qint = 0;
        while ( @seed_values_63 > 2 and length $qint < 20 ) {
            $qint .= join '', reverse split '',
                ##  sum of lowest and highest  ##
                shift(@seed_values_63) + pop(@seed_values_63);
        }
        $qint =~ s|^0||;    ##  removing 0 prefix  ##

        ##  entropy underrun [ ending iteration ]  ##
        last if length($qint) < 19;

        push @quad_int, substr $qint, 0, 19;    ##  19 digits for Q int  ##
    }

    ##  entropy  underrun  ##
    ##
    if ( @quad_int != 4 ) {
        @quad_int = ();    ##  resetting  ##
        ##[  increasing iterations  ]##
        $seed_iteration_count *= 2;
        goto RESEED_KEY_32;    ## reseed ., ##
    }

    $result_keybin = pack qw| Q* |, @quad_int;   ##  encode as 32 B binary  ##

    if (not AMOS7::Assert::Truth::is_true( $result_keybin, FALSE, TRUE )
        or $wants_true_B32_enc and not AMOS7::Assert::Truth::is_true(
            Crypt::Misc::encode_b32r($result_keybin),
            FALSE, TRUE
        )
    ) {
        @quad_int = ();    ##  resetting  ##
        goto RECALCULATE_KEY_32;
    }

    if ( not close $fh ) {
        warn_err( "error on closing file path [ '%s' ]",
            1, lcfirst $OS_ERROR );
        return undef;
    } else {
        return ( $result_keybin, \@num_63 ) if wantarray;
        return $result_keybin;    ##  success, return extracted key  ##
    }
}

sub gen_entropy_string {

    ##  use gen_entropy_values to create harmonic [bin] entropy string  ##
    ##
    my $entropy_block      = '';
    my $entropy_block_size = shift // '';   ##  size parameter is required  ##
    my $seed_data_sref = shift;       ##  optional scalar ref to seed data  ##
    my $add_iterations = shift // 0;  ##  optional round increase ##

    if ( $entropy_block_size !~ m|^\d+$| or $entropy_block_size == 0 ) {
        warn_err('expected entropy length parameter <{C1}>');
        return undef;
    } elsif ( defined $seed_data_sref
        and ref $seed_data_sref ne qw| SCALAR | ) {
        warn_err('seed param not a scalar reference <{C1}>');
        return undef;
    } elsif ( $add_iterations !~ m|^\d+$| ) {
        warn_err( 'additional iterations parameter '
                . 'needs to be positive integer <{C1}>' );
        return undef;
    }
    ##  calc ammount of required numbers  ##
    my $requested_value_count = sprintf qw| %u |, $entropy_block_size / 2.6;

    $requested_value_count += $add_iterations if $add_iterations > 0;

    ##  using filter subroutine to convert numbers to binary string  ##
    AMOS7::13::gen_entropy_values( $seed_data_sref,
        $requested_value_count, \$entropy_block, \&entropy_string_filter,
        TRUE, TRUE );

    ## truncate overflow ##
    my $block_overflow_size = length($entropy_block) - $entropy_block_size;
    if ( $block_overflow_size > 0 ) {
        if ( $add_iterations == 0 ) {
            ## regular mode [ truncates block end ] ##
            substr $entropy_block, $entropy_block_size, $block_overflow_size,
                '';
        } else {    ##  additional iterations mode [ truncate from start ]  ##
            substr $entropy_block, 0, $block_overflow_size, '';
        }
    }

    return \$entropy_block;    ##  return entropy of requested size  ##
}

##  create a randomized numerical sequence from input seed string entropy  ##
##
sub random_sequence {

    my $input_seed   = shift;  ##  [ arbitary length ] seed entropy string  ##
    my @num_sequence = @ARG;   ##  single element count or number sequence  ##

    my @result_sequence;       ##  returning randomized sequence  ##

    if ( not defined $input_seed ) {
        warn_err('expected input seed string parameter <{C1}>');
        return undef;
    } elsif ( @num_sequence == 0 ) {
        warn_err('expected [ at least one ] numerical sequence param <{C1}>');
        return undef;
    }
    my $element_index = 0;
    foreach my $test_val (@num_sequence) {
        if (    @num_sequence == 1
            and defined $test_val
            and ( $test_val !~ m|^\d{1,5}$| or $test_val == 0 ) ) {
            warn_err( 'element count not numerical or'
                    . ' out of range [ <= 5 digits ] <{C1}>' );
            return undef;
        } elsif ( not defined $test_val or $test_val !~ m|^\d+$| ) {
            warn_err( 'sequence element [ %03d ] is not numerical :. %s .:',
                1, $element_index, $test_val // qw| [UNDEF] | );
            return undef;
        }
        $element_index++;
    }

    ## single value = element count | otherwise num sequence list ##
    ##
    my $element_count
        = @num_sequence == 1 ? shift @num_sequence : scalar @num_sequence;

    if ( not @num_sequence ) {  ## number sequence from given element count ##
        @num_sequence = ( 0 .. $element_count - 1 );
    }

    ##  input seed padding to length 13  ##
    $input_seed .= 'Z' x ( 13 - length $input_seed )
        if length $input_seed < 13;

    my @entropy_data; ## same ammount of numerical values to select indices ##
    if (not AMOS7::13::gen_entropy_values(
            \$input_seed, $element_count, \@entropy_data
        )
    ) {
        warn_err('cannot generate entropy values <{C1}>');
        return undef;
    }

    while (@num_sequence) {   ##  choose the next element for the sequence  ##
        my $next_val = shift @entropy_data;
        $next_val %= scalar @num_sequence;
        push @result_sequence, splice @num_sequence, $next_val, 1;
    }

    ##  returning randomized sequence  ##
    ##
    if (wantarray) {
        return @result_sequence;    ##  return as array in list context  ##
    } else {
        return \@result_sequence;   ##  return array ref in scalar context  ##
    }
}

##  return ranged numerical float or integer value from input seed data  ##
##
sub seed_iteration_val {

    my $seed_data_sref = shift;    ##  scalar ref to seed data  ##
    my $range_start    = shift;    ## numerical value range start ##
    my $range_limit    = shift;    ## numerical upper value range limit ##

    if ( ref $seed_data_sref ne qw| SCALAR | ) {
        warn_err('expected scalar ref to seed data <{C1}>');
        return undef;
    } elsif ( not defined $seed_data_sref->$* ) {
        warn_err('seed data is undef <{C1}>');
        return undef;
    } elsif ( not defined $range_start or $range_start !~ m|^\d+$| ) {
        warn_err('expected numerical range start param <{C1}>');
        return undef;
    } elsif ( not defined $range_limit
        or $range_limit !~ m|^\d+$|
        or $range_limit == 0 ) {
        warn_err('expected numerical range limit param <{C1}>');
        return undef;
    } elsif ( $range_start >= $range_limit ) {
        warn_err('range start must be lower than range limit param <{C1}>');
        return undef;
    } elsif ( length $seed_data_sref->$* < $min_seed_data_len ) {
        ## seed asc 127 padding ##
        $seed_data_sref = \sprintf qw| %s%s |, $seed_data_sref->$*,
            chr(127) x ( $min_seed_data_len - length $seed_data_sref->$* );
    }

    my $result_aref = [];   ##  numerical seed for actual iterations value  ##
    if (not AMOS7::13::gen_entropy_values(
            $seed_data_sref, 13, $result_aref, undef, TRUE, TRUE
        )
    ) {
        warn_err('error while calculating seed iterations value <{C1}>');
        return undef;
    }
    my $iteration_count = 0;
    while ( my $result_number = shift $result_aref->@* ) {
        $iteration_count += $result_number;
        $iteration_count = divide_13($iteration_count);
    }
    while ( $iteration_count > 63 or $iteration_count < 13 ) {
        $iteration_count += 13;
        $iteration_count /= 13 if $iteration_count > 63;
    }
    $iteration_count = sprintf qw| %u |, $iteration_count;

    ##  generate seed data for final result value  ##
    ##
    if (not AMOS7::13::gen_entropy_values(
            $seed_data_sref, $iteration_count,
            $result_aref,    undef,
            TRUE,            TRUE
        )
    ) {
        warn_err('error while calculating requested result value <{C1}>');
        return undef;
    } else {
        undef $iteration_count;    ## done. ##
    }

    my $delta_count_threshold  = 13;    ##  range limit crossings  ##
    my $ranged_int_result      = 0;     ##  initializing result value  ##
    my $int_range_delta        = $range_limit - $range_start;
    my $range_delta_count      = 0;
    my $range_center_threshold = $range_start + $int_range_delta / 2;

    while ($range_delta_count < $delta_count_threshold
        or $ranged_int_result > $range_limit
        or $ranged_int_result < $range_start ) {
        foreach my $result_number ( $result_aref->@* ) {

            $ranged_int_result += $result_number;    ##[  add entropy val  ]##
            $ranged_int_result *= 1.42;    ##[  accelerate value increase  ]##

            if ( $ranged_int_result < $range_start ) {
                $ranged_int_result
                    += $int_range_delta / ( $ranged_int_result / 13 );
            }

            ## bring value back in range ##
            if ( $ranged_int_result > $range_limit ) {
                ( my $value_remainder = $ranged_int_result ) =~ s|\d+.|0.|;
                $ranged_int_result %= $range_limit;
                $ranged_int_result += $value_remainder;
                $range_delta_count++;
            }

            ## truth assertion as harmonization \ additional entropy ##
            ##
            my $last_result_val = 0;
            while (
                    $ranged_int_result <= $range_limit
                and $ranged_int_result >= $range_start
                and $range_delta_count >= $delta_count_threshold
                and (
                    not AMOS7::Assert::Truth::true_int(
                        sprintf( qw| %u |, $ranged_int_result )
                    )
                    or not AMOS7::Assert::Truth::calc_true($ranged_int_result)
                )
            ) {
                if ( $ranged_int_result < $range_start ) {  ##[  addition  ]##
                    $ranged_int_result += divide_13($ranged_int_result);
                    ## bring value back in range ##
                    ( my $value_remainder = $ranged_int_result )
                        =~ s|\d+.|0.|;
                    $ranged_int_result %= $range_limit;
                    $ranged_int_result += $value_remainder;
                    $range_delta_count++;

                } elsif ( $ranged_int_result > $range_start ) {
                    $ranged_int_result /= 13;    ##[  division by 13  ]##
                }
                last if $ranged_int_result == $last_result_val;
                $last_result_val = $ranged_int_result;
            }
            last    ##  exit loop when value in range and min iterations  ##
                if $range_delta_count > $delta_count_threshold
                and $ranged_int_result <= $range_limit
                and $ranged_int_result >= $range_start;
        }
    }

    ##  return floating point result in list context  ##
    return sprintf qw| %.13f |, $ranged_int_result if wantarray;

    ##  return result value as integer  ##
    return sprintf qw| %u |, $ranged_int_result;
}

sub entropy_string_filter {  ##  numerical input string of arbitary length  ##

    my $packed_str = '';

    while ( length $ARG[0] ) {
        my $next_chr = 0;
        if ( length( $ARG[0] ) < 3 ) {
            $next_chr = $ARG[0];
            $ARG[0] = '';
        } else {
            $next_chr = substr( $ARG[0], 0, 2, '' );
            $next_chr .= substr( $ARG[0], 0, 1, '' )    ## take another ##
                if join( '', $next_chr, substr( $ARG[0], 0, 1 ) ) <= 255;
        }
        $packed_str .= chr($next_chr);
    }
    return $packed_str;
}

sub gen_entropy_values {

    my $seed_data_sref = shift;

    my $requested_value_count;
    if ( defined $ARG[0] and $ARG[0] =~ m|^\d+$| ) {    ## optional ##
        $requested_value_count = shift;
        if ( $requested_value_count == 0 ) {
            warn_err('value count of 0 is not valid <{C1}>');
            return undef;
        }
    }

    my $output_reference = shift;
    my $filter_coderef   = shift;
    my $not_encode       = shift // FALSE;
    my $not_127_pad      = shift // FALSE;

    my @seed_blocks;
    my @entropy_data;
    my $file_output     = FALSE;
    my $req_b32_encoded = FALSE;
    my $fortuna_mode    = FALSE;

    if ( not defined $seed_data_sref ) {    ##  random value data mode  ##

        $fortuna_mode = TRUE;               ## true ##

    } elsif ( ref $seed_data_sref ne qw| SCALAR | ) {
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
    } elsif ( defined $filter_coderef and ref $filter_coderef ne qw| CODE | )
    {
        warn 'filter code ref param is not a CODE reference <{C1}>';
        return undef;
    }
    my $output_reftype = ref $output_reference;
    if ( not length $output_reftype ) {
        warn 'require output reference param <{C1}>';
        return undef;
    } elsif ( $output_reftype =~ m,(IO::(File|Handle)|GLOB), ) {
        if ( not length fileno($output_reference) ) {
            warn_err('second parameter not [open] filehandle <{C1}>');
            return undef;
        } elsif ( ref $filter_coderef ne qw| CODE | ) {
            warn_err('filehandle also requires a CODE ref parameter <{C1}>');
            return undef;
        } else {    ##  true  if not otherwise requested  ##
            $file_output = $req_b32_encoded = $not_encode ? FALSE : TRUE;
        }
    } elsif ( $output_reftype eq qw| ARRAY | and defined $filter_coderef ) {
        warn_err( 'filter parameter not expected '
                . 'with output reference type ARRAY <{C1}>' );
        return undef;
    } elsif ( defined $output_reference
        and ref $output_reference eq qw| SCALAR | ) {

        $req_b32_encoded = $not_encode ? FALSE : TRUE;    ## true ##

    } elsif ( $output_reftype ne qw| ARRAY |
        and $output_reftype ne qw| SCALAR | ) {
        warn_err( "output ref type '%s' not valid <{C1}>",
            1, ref $output_reference );
        return undef;
    }

    my $result;
    my $t_start = sprintf( qw| %.5f |, Time::HiRes::time ) if $verbose;

    if ($fortuna_mode) {

        for ( 1 .. $requested_value_count || $genseed_iterations_0 ) {

            my $rnd_val;
            while (not defined $rnd_val
                or not AMOS7::Assert::Truth::is_true( $rnd_val, 2, 1 ) ) {
                $rnd_val = sprintf qw| %.10u |, irand();
            }

            if ($verbose) {
                say $C{'0'}, '< prng.fortuna > ', $C{'T'}, $rnd_val, $C{'R'};
            }

            push @seed_blocks, $rnd_val;
        }

    } else {    ##  maximize password \ passphrase entropy  ##

        my $bit_size  = 49;
        my $seed_bits = get_seed_bits($seed_data_sref);
        my $bits_len  = length $seed_bits;

        $result = offset_comp_int( \$seed_bits, -$bit_size );

        my $seed_bit_offs = 0;

        for ( 1 .. $requested_value_count || $genseed_iterations_0 ) {

            ( my $cur_block_val, my $block_bits )
                = offset_comp_int( \$seed_bits,
                $bit_size - ++$seed_bit_offs );

            $seed_bit_offs %= -$bits_len;

            my $apply_at = 1 + abs(
                AMOS7::BitConv::bit_string_to_num(
                    substr( $block_bits->$*, 0, 4 )
                ) - 1
            );

            my $recalc = FALSE;

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

            while ( not AMOS7::Assert::Truth::is_true( \$result, 2, 1 ) ) {
                $result = divide_13($result);
            }

            push @seed_blocks, $result;
        }
    }

    if ($verbose) {
        foreach my $numval ( reverse @seed_blocks ) {
            say $C{'0'}, '< SEED > ', $C{'T'}, $numval, $C{'R'};
        }
        say '';
    }

    for ( 1 .. $requested_value_count || $genseed_iterations_1 ) {

        ##  apply collected seed numbers  ##
        ##
        $result += shift @seed_blocks;

    RECALC_0110:

        $result = divide_13($result);

        goto RECALC_0110
            if not AMOS7::Assert::Truth::is_true( $result, 2, 1 );

        my $encoded_result;

        if ($req_b32_encoded) {

            my $vax_bin = pack qw| V |, $result;
            goto RECALC_0110
                if not AMOS7::Assert::Truth::is_true( $vax_bin, 0, 1 );

            $encoded_result = encode_b32r($vax_bin);
            goto RECALC_0110
                if not AMOS7::Assert::Truth::is_true( $encoded_result, 0, 1 );

            say $C{'0'}, '< RSB32 > ', $C{'T'}, $encoded_result if $verbose;
        }
        ## result data output ##
        ##
        if ($req_b32_encoded) {
            push @entropy_data, $encoded_result;
        } else {
            push @entropy_data, $result;
        }
    }

    while ( defined $output_reference and @entropy_data > 0 ) {

        ##  output values in reverse order  ##

        if ($file_output    ##  output encryption expected  ##
            or ref $output_reference eq qw| SCALAR |
            and defined $filter_coderef
        ) {
            my $output_value = '';

            for ( 0 .. 15 ) {
                last if @entropy_data == 0;   ##  uneven ammount requested  ##
                $output_value .= pop @entropy_data;    ## multiple of 16 B ##
            }

            my $value_length = length $output_value;
            if ( $value_length % 16 != 0 ) {
                if ( @entropy_data > 0 ) {
                    warn_err( 'value length of %03d is not valid',
                        0, $value_length );
                    truncate( $output_reference, 0 );    ## erasing content ##
                    return error_exit('aborting write.');

                } else {    ##  output data padded with asc 127 characters  ##

                    ## if not ommission requested ##
                    ##
                    if ( $not_127_pad == FALSE ) {
                        my $remainder_len = 16 - $value_length % 16;
                        $output_value .= chr(127) x $remainder_len;
                    }
                }
            }

            ##  file encryption done in code reference  ##

            my $cipher_string = $filter_coderef->($output_value);

            $cipher_string = $cipher_string->$*   ##  expected ref to data  ##
                if ref $cipher_string eq qw| SCALAR |;

            return error_exit('filter code returned undefined value')
                if not defined $cipher_string;

            ##  WRITE TO ENCRYPTED FILE [ DATA ASC 127 PADDED ]  ##
            ##
            if ($file_output) {

                if ( not length( $cipher_string // '' ) ) {
                    truncate( $output_reference, 0 );    ## erasing content ##
                    close($output_reference);
                    return error_exit('encryption error [ writing aborted ]');
                }
                print {$output_reference}
                    $cipher_string;    ##  write to handle  ##

            } else {
                $output_reference->$* .= $cipher_string;  ## to scalar ref. ##
            }

        } elsif ( ref $output_reference eq qw| ARRAY | ) {   ## num. values ##

            ##  all values at once  ##
            push $output_reference->@*, @entropy_data;
            undef @entropy_data;    ##  reset array  ##

        } elsif ( ref $output_reference eq qw| SCALAR | ) {

            ## one per iteration ##
            $output_reference->$* .= pop @entropy_data;  ##[  unencrypted  ]##
        }
    }

    ## time ellapsed ##
    printf "$C{0} $C{b}::::::::$C{R}$C{0} $C{b}%s s$C{R}\n\n",
        sprintf( qw| %.5f |, Time::HiRes::time - $t_start )
        if $verbose;

    if ($file_output) { return FALSE if not close($output_reference) }

    if ( not defined $output_reference ) {

        ##  values in list context [ last value first ]  ##
        ##
        return reverse @entropy_data if wantarray;

        return $result;    ## only last value in scalar context ##

    } else {    ##  otherwise report success only  ##
        return TRUE;    ## true ##
    }
}

##[ KEY DERRIVATION ]#########################################################

sub key_32 { ##  create 32 bytes binary encryption key from arbitary input  ##

    my $enc_key;
    my $pass_sref    = shift;    ##  scalar ref to password or phrase  ##
    my $keyname_seed = shift;    ##  optional name to influence iterations  ##
    my $wants_true         = shift // TRUE;  ##  request harmonized values  ##
    my $wants_true_B32_enc = shift // FALSE; ##  true BASE32 enc. values  ##

    ##  when keyname seed is numerical, it will be used for increase ..,    ##
    ##  when it is a scalar reference it will be calculated from its value  ##

    my $seed_iteration_count;
    if ( not defined $keyname_seed ) {
        $seed_iteration_count = 113;   ## <-- increased by key_name entropy ##
    } elsif ( ref $keyname_seed eq qw| SCALAR |
        and defined $keyname_seed->$* ) {

        $seed_iteration_count          ##  initializing with name entropy  ##
            = AMOS7::13::seed_iteration_val( $keyname_seed, 113, 226 );

    } elsif ( $keyname_seed =~ m|^\d+$| ) {    ##  adding to min value  ##
        $seed_iteration_count = 113 + $keyname_seed;
    } elsif ( ref $keyname_seed eq qw| SCALAR | ) {
        warn_err('keyname seed reference pointing to undef value <{C1}>');
        return undef;
    } else {
        warn_err( 'keyname seed must be numerical '
                . '[iterations] or scalar ref <{C1}>' );
        return undef;
    }

    if ( ref $pass_sref ne qw| SCALAR | ) {
        warn_err('expected scalar ref param to passphrase <{C1}>');
        return undef;
    } elsif ( not defined $pass_sref->$*
        or length( $pass_sref->$* ) < $min_seed_data_len ) {
        warn_err( 'expected password length is at least %d characters',
            1, $min_seed_data_len );
        return undef;
    }

    my @quad_int;
    my @pwd_entropy_val;

RESEED_KEY_32:

    my $key_status    ##  [>=]113 [ 32 bit ] numbers from password entropy  ##
        = AMOS7::13::gen_entropy_values( $pass_sref, $seed_iteration_count,
        \@pwd_entropy_val );

    if (   not defined $key_status
        or not $key_status
        or @pwd_entropy_val == 0 ) {
        warn_err('cannot generate encryption key');
        return undef;
    }

    @pwd_entropy_val = sort @pwd_entropy_val;    ##  numerical sort  ##

RECALCULATE_KEY_32:

    for ( 0 .. 3 ) {    ##  4 64 bit values required  ##
        my $qint = 0;
        while ( @pwd_entropy_val > 2 and length $qint < 20 ) {
            $qint .= join '', reverse split '',
                ##  sum of lowest and highest  ##
                shift(@pwd_entropy_val) + pop(@pwd_entropy_val);
        }
        $qint =~ s|^0||;    ##  removing 0 prefix  ##

        ##  entropy underrun [ ending iteration ]  ##
        last if length($qint) < 19;

        push @quad_int, substr $qint, 0, 19;    ##  19 digits for Q int  ##
    }

    ##  entropy  underrun  ##
    ##
    if ( @quad_int != 4 ) {
        @quad_int = ();    ##  resetting  ##
        ##[  increasing iterations  ]##
        $seed_iteration_count *= 2;
        goto RESEED_KEY_32;    ## reseed ., ##
    }

    my $enc_bin = pack qw| Q* |, @quad_int;    ##  encode as 32 B binary  ##

    if ($wants_true
        and not AMOS7::Assert::Truth::is_true( $enc_bin, FALSE, TRUE )
        or $wants_true_B32_enc and not AMOS7::Assert::Truth::is_true(
            Crypt::Misc::encode_b32r($enc_bin),
            FALSE, TRUE
        )
    ) {
        @quad_int = ();    ##  resetting  ##
        goto RECALCULATE_KEY_32;
    }

    return $enc_bin;       ##  binary encryption key  ##
}

sub key_56 {    ##  BMW 384 based key [chksum] derivation function  ##

    my $pass_sref    = shift;    ##  scalar ref to password or phrase  ##
    my $keyname_seed = shift;    ##  optional name to influence entropy  ##

    if ( ref $pass_sref ne qw| SCALAR | ) {
        warn_err('expected scalar ref param to passphrase <{C1}>');
        return undef;
    } elsif ( not defined $pass_sref->$* ) {
        warn_err('input data reference points to undefined value');
        return undef;
    }

    my $pass_chksum = encode_b32r Digest::BMW::bmw_384(    ##[ length  77 ]##
        ( defined $keyname_seed and length $keyname_seed )
        ? sprintf( qw| %s:%s |, $keyname_seed, $pass_sref->$* )
        : $pass_sref->$*    ##  name prefix if defined  ##
    );

    ##  removing 21b  ##
    my $second_entropy_str = substr $pass_chksum, 56, 21, ''; ##[keeping it]##
    my $next_round_str     = '';
    my $xor_char_pos = 56 - 1;  ##[ harmonization using XOR and reencoding ]##
    while ( $xor_char_pos >= 0
        and not AMOS7::Assert::Truth::is_true( $pass_chksum, FALSE, TRUE ) ) {
        my $pos_byte = substr $pass_chksum, $xor_char_pos, 1;
        my $xor_byte = substr $second_entropy_str, 0, 1, '';
        $pos_byte ^.= $xor_byte;
        substr $pass_chksum, $xor_char_pos, 1, $pos_byte;    ## replace ##
        $pass_chksum = encode_b32r $pass_chksum;    ## reencode the encoded ##
        $second_entropy_str .= substr $pass_chksum, 56, 34, '';    ## of 90 ##
        $next_round_str .= $xor_byte;    ##  store it for next round  ##

        if ( not length $second_entropy_str ) {    ## char pos completed ##
            $second_entropy_str = $next_round_str;    ## reset to stored ##
            $xor_char_pos--;         ## advance character pos left ##
            $next_round_str = '';    ##  resetting  for next round  ##
        }
    }

    return $pass_chksum;    ##  returning harmonized 56 byte bmw checksum  ##
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

    say sprintf '< bits [ %06d ]> %s', $first_pos, $offset_bits if $verbose;

    my $comp_int = bits_to_comp_int($offset_bits) / 13 / 13 / 13 / 13 / 13;

    return ( $comp_int, \$offset_bits ) if wantarray;
    return $comp_int;

}

sub get_seed_bits {

    my $seed_data_sref = shift;

    my $min_bit_len = 49;
    my $bits;

    if ( ref $seed_data_sref ne qw| SCALAR | ) {
        warn_err('expected scalar ref to seed data <{C1}>');
        return undef;
    }

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

    my $index     = shift @ARG;
    my $value_num = shift @ARG;

    my @truth_states = @ARG;

    return warn 'expected numerical index argument' if not is_number($index);
    return warn 'expected numerical <value>'    if not is_number($value_num);
    return warn 'expected 3 truth state values' if not @truth_states == 3;

    my $T_state  = $truth_states[0] ? qw| TRUE | : qw| FALSE |;
    my $bin_0000 = reverse_bin_032($value_num);    ## reverse left ##
    my $bin_0110 = bin_032($value_num);            ## actual right ##
    my $c0       = $truth_states[1] ? join( '', $C{T}, $C{B} ) : $C{0};
    my $c1       = $truth_states[2] ? join( '', $C{T}, $C{B} ) : $C{0};

    printf $result_tmpl->{$T_state},
        $index, $value_num,
        join( '', $c0, $bin_0000 ),
        join( '', $c1, $bin_0110 );
}

return TRUE ##################################################################

#,,.,,.,.,.,.,,.,,,,,,.,,,.,,,,.,,,,,,,,.,.,,,..,,...,...,...,,,,,..,,,.,,,..,
#G4P4VFNOHFSPSIF52IX7EDOYJVIUPRFZFOC42FM2ZTDJLBEFURVYQF6PI5CA52ZSSQH33ISKEQVAA
#\\\|HMZHAXYNYNX2QCAXPAUPL2CNHJ3UOYF4RQKHXTXM7D5RIZO4FFG \ / AMOS7 \ YOURUM ::
#\[7]6NY4SN7SC7MG5LLFZ4MD22ECET3N55BHFJRMCXKXZYU7JXBUQGCY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
