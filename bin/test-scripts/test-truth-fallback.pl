#!/usr/bin/env perl
use v5.24;
use strict;
use English;
use warnings;

##     Test AMOS7::Assert::Truth fallback bit-identity with the             ##
##     compiled oracle                                                      ##
##                                                                          ##
##     two layers of verification :                                         ##
##                                                                          ##
##     1. in-process : compiled true_int \ true_float [ Inline::C ]         ##
##     compared directly against the pure-perl pure_true_int \              ##
##     pure_true_float on thousands of vectors [ ints incl. > 2**53 and     ##
##     64 bit edges, floats of many magnitudes and decimal shapes ]         ##
##                                                                          ##
##     2. cross-process : this script re-executes itself with Inline::C     ##
##     hidden                                                               ##
##     [ PERL5OPT=-MBlockInlineC via fixtures/truth/BlockInlineC ] so       ##
##     AMOS7::INLINE installs the pure-perl fallbacks -- calc_true,         ##
##     is_true, elf_chksum, amos_chksum, bit_string_to_num and              ##
##     num_to_bit_string results on identical vectors must agree with       ##
##     the compiled parent process                                          ##
##                                                                          ##
##     run with any perl [ local or floor ] : results must be identical     ##

##[ LOCAL PM LIB PATH ]#######################################################

BEGIN {
    use English;
    use File::Spec;
    use Cwd     qw| abs_path |;
    use FindBin qw| $RealBin |;
    my $up_dir       = File::Spec->updir;
    my $data_pm_path = qw| data/lib-path/pm |;
    my $root_path    = abs_path(
        File::Spec->rel2abs(
            File::Spec->catdir( $RealBin, $up_dir, $up_dir )
        )
    );
    my $local_lib_path
        = abs_path( File::Spec->catdir( $root_path, $data_pm_path ) );
    $local_lib_path //= $data_pm_path;
    die "\n:\n:: not found : $local_lib_path\n:\n" if !-d $local_lib_path;
    unshift( @INC, $local_lib_path )               if -d $local_lib_path;
}

use English;
use File::Spec;
use Cwd     qw| abs_path |;
use FindBin qw| $RealBin |;
use Math::BigInt;

use AMOS7;
use AMOS7::CHKSUM;    ## amos_chksum + inline compilation ##
use AMOS7::Assert::Truth;
use AMOS7::CHKSUM::ELF qw| elf_chksum |;

## num_to_bit_string is registered in AMOS7::INLINE but no module pulls it ##
## in [ its own note : example only, sprintf '%0*b' is faster ] -- compile ##
## it here so the BitConv fallback check covers both directions            ##
AMOS7::INLINE::compile_inline_source(
    { qw| subroutine-name | => qw| num_to_bit_string | } );

my $fixture_dir
    = abs_path( File::Spec->catdir( $RealBin, qw| fixtures truth | ) );

my $tests_run    = 0;
my $tests_passed = 0;
my @failures;

sub check {
    my ( $label, $condition ) = @ARG;
    $tests_run++;
    if ($condition) {
        $tests_passed++;
    } else {
        push @failures, $label;
        say sprintf( '[ FAIL ] %s', $label );
    }
    return $condition;
}

##[ DETERMINISTIC VECTOR SETS ]###############################################

sub build_vectors {

    my (@int_vectors, @float_vectors, @string_vectors,
        @bit_vectors, @neg_vectors
    );

    srand(13);

    ## small integers cover every residue class repeatedly ##
    push @int_vectors, 0 .. 260;

    ## multiples of 13 and neighbouring offsets ##
    foreach my $multiple ( 1 .. 40 ) {
        push @int_vectors, map { 13 * $multiple + $ARG } -2 .. 14;
    }

    ## powers of two with neighbours [ BigInt strings stay exact ] ##
    foreach my $pow ( 0 .. 64 ) {
        my $base = Math::BigInt->new(2)->bpow($pow);
        push @int_vectors,
            map { my $v = $base->copy->badd($ARG); "$v" } -2 .. 2;
    }

    ## 64 bit boundary values ##
    push @int_vectors,
        map { my $v = Math::BigInt->new(2)->bpow(64)->badd($ARG); "$v" }
        -3 .. 0;
    push @int_vectors, "9223372036854775807", "9223372036854775808",
        "18446744073709551614", "18446744073709551615";

    ## random 64 bit and wider integers ##
    foreach my $len ( 16, 19, 20, 30, 44 ) {
        push @int_vectors, join '', map { int rand 10 } ( 1 .. $len )
            for 1 .. 60;
    }

    ## integer strings with leading zeros and e+ notation ##
    push @int_vectors, "00000000000000000007", "0e+0", "25e+3", "12e+1",
        "7e+0", "123456789e+4", "5e+30";

    ## floats : plain decimals with 1..16 fractional digits ##
    foreach my $digits ( 1 .. 16 ) {
        push @float_vectors,
            sprintf( '%d.%s',
            int rand 1e7,
            join '', map { int rand 10 } 1 .. $digits )
            for 1 .. 90;
    }

    ## floats : magnitudes across the double range ##
    foreach my $exp ( -300 .. 300 ) {
        next if $exp == 0;
        push @float_vectors,
            sprintf( '%de%s%d', 1 + int rand 9, $exp > 0 ? '+' : '', $exp );
    }

    ## floats : subnormal and near-subnormal values ##
    push @float_vectors,
        map { sprintf '%.17g', $ARG }
        ( 5e-320, 1e-308, 2.3e-308, 1e-310, 4.9e-324 );

    ## floats : values near multiples of 13 from both sides ##
    foreach ( 1 .. 400 ) {
        my $k   = int rand 10**( 1 + int rand 12 );
        my $eps = ( rand() - 0.5 ) * 10**( -1 - int rand 16 );
        push @float_vectors, sprintf '%.17g', 13 * $k + $eps;
    }

    ## floats : dec_pt boundary shapes [ v near 0.1, 0.01 and 1 ] ##
    foreach ( 1 .. 120 ) {
        my $k = int rand 10**( 1 + int rand 8 );
        push @float_vectors, sprintf '%.17g', 13 * $k + 1.3;
        push @float_vectors, sprintf '%.17g', 13 * $k + 0.13;
        push @float_vectors, sprintf '%.17g',
            13 * ( $k + 1 ) - 10**( -3 - int rand 13 );
    }

    ## floats : exact binary fractions incl. mantissa 2**34 shapes        ##
    ## [ exercise ties-to-even in the 64->53 bit and 17 digit roundings ] ##
    foreach my $mp2 ( 1, 3, 5, 7, 9, 15, 17, 65537, 131071 ) {
        push @float_vectors, sprintf '%.17g',
            13 * ( 1 + int rand 100 ) + $mp2 * 2**-18;
    }
    foreach ( 1 .. 120 ) {
        push @float_vectors,
            sprintf( '%.17g', int( rand 1e6 ) + 2**( -1 - int rand 40 ) );
    }

    ## floats : non-terminating decimals and integer-valued floats ##
    push @float_vectors,
        map { sprintf '%.17g', $ARG } (
        0.1,   0.2, 0.7,  1 / 7,  2 / 3, 10 / 13, 3 / 13, 1 / 13,
        100.0, 0.5, 0.25, 0.0625, 13.0,  0.0
        );

    ## non-finite and e+notation float shapes ##
    push @float_vectors, "9e+999", "1e+309", "25e+3", "5e+30", "12.5e+2";

    ## strings for is_true / amos_chksum / elf_chksum comparison ##
    push @string_vectors, '', 'a', '13', 'true', 'hello world',
        join( '', map { chr( 32 + int rand 95 ) } 1 .. 64 ),
        "\x00\x00\x00", "perl\0bytes\x80\xff",
        join( '', map {chr} ( 0 .. 255 ) ),
        "\xc3\xa9\xe2\x82\xac utf8 \xf0\x9f\x99\x82",
        'x' x 1024;

    foreach ( 1 .. 60 ) {
        my $len = 1 + int rand 512;
        push @string_vectors,
            join '', map { chr( int rand 256 ) } ( 1 .. $len );
    }

    ## negatives : the compiled unsigned long parameter wraps, the float ##
    ## path searches the absolute value [ fmodl keeps the sign ]         ##
    ## [ not in the calc_true lines : is_number refuses a '-' sign ]     ##
    push @neg_vectors, -1 .. -50;
    push @neg_vectors,
        map { my $v = Math::BigInt->new(2)->bpow($ARG)->bneg(); "$v" }
        ( 52, 53, 63, 64 );
    push @neg_vectors, "-18446744073709551615", "-9223372036854775808",
        "-9223372036854775809", "-99999999999999999999",
        "-123456789012345678901234567890";
    push @neg_vectors, "18446744073709551616", "999999999999999999999999";
    push @neg_vectors, "-25e+3", "-5e+30", "-0.05", "-5.5", "-1e+30",
        "-5e-320", "-0.1", "-13.000001", "-0.0", "-1e+309", "-0.005",
        "-0.071444000001065433";

    ## bit strings for BitConv comparison ##
    push @bit_vectors, '', '0', '1', '101', '1111111111111111';
    foreach my $len ( 1 .. 64 ) {
        push @bit_vectors, join '', map { int rand 2 } 1 .. $len for 1 .. 8;
    }

    return (
        \@int_vectors, \@float_vectors, \@string_vectors,
        \@bit_vectors, \@neg_vectors
    );
}

##[ CANONICAL RESULT LINES ]##################################################

sub result_lines {

    my @lines;

    my ( $int_vectors, $float_vectors, $string_vectors, $bit_vectors )
        = build_vectors();

    foreach my $vector ( @{$int_vectors}, @{$float_vectors} ) {
        push @lines, sprintf "calc_true\t%s\t%s",
            $vector, AMOS7::Assert::Truth::calc_true($vector);
    }

    foreach my $vector ( @{$string_vectors} ) {
        ## hex-encode the key : raw binary vectors may hold \t \n bytes ##
        my $vhex = unpack( qw| H* |, $vector );
        push @lines, sprintf "is_true\t%s\t%s", $vhex,
            scalar is_true( \$vector );
        push @lines, sprintf "amos_chksum\t%s\t%s",
            scalar( unpack( qw| H* |, $vector ) ),
            scalar amos_chksum($vector);
        foreach my $elf_mode ( 4, 7 ) {
            push @lines, sprintf "elf_chksum\t%d\t%s\t%s", $elf_mode,
                scalar( unpack( qw| H* |, $vector ) ),
                scalar elf_chksum( $vector, 0, $elf_mode, 13 );
        }
    }

    foreach my $vector ( @{$bit_vectors} ) {
        push @lines, sprintf "bit_string_to_num\t%s\t%s", $vector,
            AMOS7::BitConv::bit_string_to_num($vector);
    }

    foreach ( 1 .. 120 ) {
        my $num     = int rand 2**64;
        my $min_len = ( 0, 8, 16, 32, 64 )[ int rand 5 ];
        push @lines, sprintf "num_to_bit_string\t%s\t%s\t%s", $num, $min_len,
            scalar AMOS7::BitConv::num_to_bit_string( $num, $min_len );
    }

    return @lines;
}

##[ CHILD MODE : Inline::C hidden, fallbacks installed ]######################

## @ARGV -- under 'use English' @ARG is @_ [ empty here : the child never ##
## saw its flag and spawned its own child -> a fork chain, 2026-10-18 ]   ##
if ( @ARGV and $ARGV[0] eq qw| -child | ) {
    my $fallback_active
        = \&AMOS7::Assert::Truth::true_int eq
        \&AMOS7::Assert::Truth::calc_true
        ? 1
        : 0;
    printf "child-mode\tperl=%s\tfallback=%d\n", $^V, $fallback_active;
    say $_ for result_lines();
    exit 0;
}

##[ PARENT MODE ]#############################################################

my $compiled_available
    = ( defined &AMOS7::Assert::Truth::true_int
        and \&AMOS7::Assert::Truth::true_int ne
        \&AMOS7::Assert::Truth::calc_true );

printf ":: test-truth-fallback [ perl %s ]%s\n", $^V,
    $compiled_available
    ? ' [ compiled oracle present ]'
    : ' [ compiled oracle MISSING ]';

my ($int_vectors, $float_vectors, $string_vectors,
    $bit_vectors, $neg_vectors
) = build_vectors();

##[ 1. in-process oracle comparison ]#########################################

if ($compiled_available) {

    my $int_mismatch   = 0;
    my $float_mismatch = 0;
    my $max_report     = 10;
    my $reported       = 0;

    foreach my $vector ( @{$int_vectors} ) {
        my $compiled = AMOS7::Assert::Truth::true_int($vector);
        my $pure     = AMOS7::Assert::Truth::pure_true_int($vector);
        next if $compiled == $pure;
        $int_mismatch++;
        if ( $reported++ < $max_report ) {
            printf "!! true_int mismatch : input '%s' compiled=%s pure=%s\n",
                $vector, $compiled, $pure;
        }
    }

    foreach my $vector ( @{$float_vectors} ) {
        my $compiled = AMOS7::Assert::Truth::true_float($vector);
        my $pure     = AMOS7::Assert::Truth::pure_true_float($vector);
        next if $compiled == $pure;
        $float_mismatch++;
        if ( $reported++ < $max_report ) {
            printf "!! true_float mismatch : input '%s' "
                . "compiled=%s pure=%s\n", $vector, $compiled, $pure;
        }
    }

    my $neg_mismatch = 0;
    foreach my $vector ( @{$neg_vectors} ) {
        ## independent copies : an Inline conversion sets numeric flags on ##
        ## its argument scalar, which would leak into the next call        ##
        ## [ the float result must come from the string alone ]            ##
        my ( $v_int, $v_float ) = ( "$vector", "$vector" );
        my @results = (
            [   qw| true_int |,
                AMOS7::Assert::Truth::true_int($v_int),
                AMOS7::Assert::Truth::pure_true_int($v_int)
            ],
            [   qw| true_float |,
                AMOS7::Assert::Truth::true_float($v_float),
                AMOS7::Assert::Truth::pure_true_float($v_float)
            ],
        );
        foreach my $result (@results) {
            my ( $name, $compiled, $pure ) = $result->@*;
            next if $compiled == $pure;
            $neg_mismatch++;
            if ( $reported++ < $max_report ) {
                printf "!! %s negative mismatch : input '%s' compiled=%s "
                    . "pure=%s\n", $name, $vector, $compiled,
                    $pure;
            }
        }
    }
    check(
        sprintf( 'negative input oracle parity [ %d vectors ]',
            scalar @{$neg_vectors} ),
        $neg_mismatch == 0
    );

    check(
        sprintf( 'true_int oracle parity [ %d vectors ]',
            scalar @{$int_vectors} ),
        $int_mismatch == 0
    );
    check(
        sprintf( 'true_float oracle parity [ %d vectors ]',
            scalar @{$float_vectors} ),
        $float_mismatch == 0
    );
} else {
    say ':: [ note ] compiled oracle not available '
        . '-- skipping in-process oracle comparison';
}

##[ long numbers : an INDEPENDENT rule, not a comparison of two paths ]#######
## beyond the compiled range calc_true is exact on every host : the residue ##
## of the digits without the point [ both paths share this code, so only an ##
## outside rule catches a regression here -- one did, 2026-10-18 ]          ##
{
    my %false = map { $ARG => 1 } 1, 3, 4, 9, 10, 12;
    my $off   = 0;
    my $count = 0;
    srand 41;
    foreach my $len ( 21 .. 60 ) {
        foreach my $dot ( 0, 1 ) {
            foreach ( 1 .. 6 ) {
                my $n = ( 1 + int rand 9 )
                    . join( '', map { int rand 10 } 2 .. $len );
                substr( $n, -4, 0, '.' ) if $dot;
                ( my $digits = $n ) =~ s{[^0-9]}{}g;
                my $r = 0;
                $r = ( $r * 10 + $ARG ) % 13 for split m||, $digits;
                my $want = $false{$r} ? 0 : 5;
                $count++;
                $off++ if AMOS7::Assert::Truth::calc_true($n) != $want;
            }
        }
    }
    check(
        sprintf( 'long numbers follow the residue of their digits [ %d ]',
            $count ),
        $off == 0
    );
}

##[ 2. cross-process comparison with hidden Inline::C ]#######################

die "\n:\n:: fixture dir not found : $fixture_dir\n:\n" if !-d $fixture_dir;

## recursion guard : a child never spawns again, whatever its argv says ##
die "\n:\n:: refusing to spawn from a child process\n:\n"
    if $ENV{'P7_TRUTH_TEST_CHILD'};
local $ENV{'P7_TRUTH_TEST_CHILD'} = 1;

## NOTE : list-form 'open -|' fails on this perl [ 5.42 ] with an empty ##
## $OS_ERROR -- spawn manually : pipe + fork + exec                     ##
pipe( my $child_out, my $child_in )
    or die "cannot create child pipe :\n$OS_ERROR\n";
my $child_pid = fork() // die "cannot fork child process :\n$OS_ERROR\n";
if ( $child_pid == 0 ) {    ## child : the hidden-Inline run ##
    close $child_out;
    open( STDOUT, '>&', $child_in ) or exit 127;
    close $child_in;
    exec(
        $EXECUTABLE_NAME, "-I$fixture_dir", "-MBlockInlineC",
        $PROGRAM_NAME,    qw| -child |
    );
    exit 127;    ## exec failed ##
}
close $child_in;
my @child_lines = <$child_out>;
close($child_out);
waitpid( $child_pid, 0 );
chomp @child_lines;

my $child_header = shift @child_lines // '';
check( 'child process produced output', scalar @child_lines > 0 );

my ($child_fallback_flag) = $child_header =~ m{fallback=(\d+)};
check( 'child runs with pure-perl ' . 'fallbacks installed',
    $child_fallback_flag );

my @parent_lines = result_lines();

check(
    sprintf( 'compiled vs hidden-fallback output identity [ %d lines ]',
        scalar @parent_lines ),
    join( "\n", @parent_lines ) eq join( "\n", @child_lines )
);

if ( join( "\n", @parent_lines ) ne join( "\n", @child_lines ) ) {
    my %child_map = map { $ARG => 1 } @child_lines;
    my $shown     = 0;
    foreach my $line (@parent_lines) {
        next if $child_map{$line};
        printf "!! parent-only line : %s\n", $line;
        last if $shown++ > 10;
    }
}

##[ SUMMARY ]#################################################################

printf ":: tests run : %d -- passed : %d -- failed : %d\n",
    $tests_run, $tests_passed, scalar @failures;

exit( scalar @failures ? 1 : 0 );

#,,,,,.,.,,..,.,.,.,.,..,,,.,,..,,,,,,,.,,,..,..,,...,..,,..,,,,.,,.,,.,,,.,.,
#6UGBXUDLOL2PA5UMQ7JOSHL7AQV2I4OSIK4WPIBAPXXVM56ZLZWNBVWWENPG7CW76GPESZUM7KE6K
#\\\|YIDZ4BD4PKEZJXDR7ZFIQR2ZTQSOPBLJOU5QOFFEX5S2BDRKQSE \ / AMOS7 \ YOURUM ::
#\[7]2PNSCQEV6TZ7H7YYCTNTFMKDRYWHGRX5SINHCTFMS36SZXSHEABQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
