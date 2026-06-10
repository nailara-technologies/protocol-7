#!/usr/bin/perl
use v5.24;
use strict;
use warnings;
use English;
use File::Spec;
use Cwd     qw| abs_path |;
use FindBin qw| $RealBin |;

## test base.chk-sum.bmw.harmonize_L13
## verifies bit-identical output after rewrap of calculate_L13_sum
## and template_L13

BEGIN {
    my $up_dir       = File::Spec->updir;
    my $data_pm_path = qw| data/lib-path/pm |;
    my $root_path    = abs_path(
        File::Spec->catdir( $RealBin, $up_dir, $up_dir, $up_dir, $up_dir ) );
    my $local_lib_path
        = abs_path( File::Spec->catdir( $root_path, $data_pm_path ) );
    $local_lib_path //= $data_pm_path;
    die "\n:\n:: not found : $local_lib_path\n:\n" if !-d $local_lib_path;
    unshift( @INC, $local_lib_path )               if -d $local_lib_path;
}

use AMOS7::Assert::Truth qw| is_true |;
use AMOS7::Assert::Truth qw| is_true_with_template is_template_syntax_valid |;
use AMOS7::TEMPLATE;
use Crypt::Misc qw| encode_b32r |;
use Digest::BMW;
use Time::HiRes;

use constant TRUE => 5;

##[ old calculate_L13_sum reference implementation ]##########################

sub old_calculate_L13_sum {
    my $bmw_512_bin = shift // '';

    if ( length $bmw_512_bin != 64 ) {
        warn 'expecting 64 byte [binary] 512 bit BMW digest <{C1}>';
        return undef;
    }

    ## start entropy ##
    state $start_seed_num;
    $start_seed_num //= unpack qw| Q |, pack qw| B64 |, '10000000' x 8;
    my $bits_num = $start_seed_num;

    foreach my $segment_num ( unpack qw| Q8 |, $bmw_512_bin ) {

        while ( not AMOS7::Assert::Truth::true_int($segment_num) ) {
            $segment_num = sprintf qw| %u |, $segment_num / 13;
        }

        $bits_num ^= $segment_num;    ## stringwise XOR ##

        while ( not AMOS7::Assert::Truth::true_int($bits_num) ) {
            $bits_num <<= 1;          ## make true ##
        }

    }

    my $result_str_B32 = encode_b32r( pack qw| Q |, $bits_num );

    while (not is_true( $result_str_B32, 0, 1 )
        or not AMOS7::Assert::Truth::true_int($bits_num) ) {
        $bits_num = sprintf qw| %u |, $bits_num / 13;
        $bits_num <<= 5;
        $bits_num = 13 if $bits_num == 0;  ##  make sure to exit true if 0  ##
        ##  again until true  ##
        $result_str_B32 = encode_b32r( pack qw| Q |, $bits_num );
    }

    return $result_str_B32;    ##  13 characters  ##  [ a true value ]  ##
}

##[ old template_L13 reference implementation ]###############################

sub old_template_L13 {
    my $template = shift;

    if ( not @ARG or grep { not defined } @ARG ) {
        warn 'expected defined input param[s] <{C1}>';
        return undef;
    }

    ## start entropy ##
    state $start_seed_num;
    $start_seed_num //= unpack qw| Q |, pack qw| B64 |, '10000000' x 8;
    my $bits_num = $start_seed_num;

    foreach my $segment_num ( unpack qw| Q8 |, Digest::BMW::bmw_512(@ARG) ) {

        while ( not AMOS7::Assert::Truth::true_int($segment_num) ) {
            $segment_num = sprintf qw| %u |, $segment_num / 13;
        }

        $bits_num ^= $segment_num;    ## stringwise XOR ##

        while ( not AMOS7::Assert::Truth::true_int($bits_num) ) {
            $bits_num <<= 1;          ## make true ##
        }

    }

    my $result_str_B32 = encode_b32r( pack qw| Q |, $bits_num );

    while (not is_true_with_template( $template, $result_str_B32, 0, 1 )
        or not AMOS7::Assert::Truth::true_int($bits_num) ) {
        $bits_num = sprintf qw| %u |, $bits_num / 13;
        $bits_num <<= 5;
        $bits_num = 13 if $bits_num == 0;  ##  make sure to exit true if 0  ##
        ##  again until true  ##
        $result_str_B32 = encode_b32r( pack qw| Q |, $bits_num );
    }

    return $result_str_B32;    ##  13 characters  ##  [ a true value ]  ##
}

##[ new harmonize_L13 loaded from module file ]###############################

my $module_root
    = abs_path( File::Spec->catdir( $RealBin, ( File::Spec->updir ) x 4 ) );

my $helper_path = File::Spec->catfile( $module_root,
    qw| modules base.chk-sum.bmw.harmonize_L13 | );

open( my $HFH, qw| < |, $helper_path )
    or die "cannot read $helper_path : $!";
my $helper_src = do { local $/; <$HFH> };
close($HFH);

## strip header comments and signature footer ##
$helper_src =~ s|^\s*##\s*\[:<\s*##\s*\n||;
$helper_src =~ s|\n#,,.*\z||s;

## wrap in sub ##
my $harmonize_L13 = eval "sub {\n$helper_src\n}";
die "helper compile error: $@" if $@;

##[ new calculate_L13_sum loaded from module file ]###########################

my $calc_path = File::Spec->catfile( $module_root,
    qw| modules base.chk-sum.bmw.calculate_L13_sum | );

open( my $CFH, qw| < |, $calc_path )
    or die "cannot read $calc_path : $!";
my $calc_src = do { local $/; <$CFH> };
close($CFH);

$calc_src =~ s|^\s*##\s*\[:<\s*##\s*\n||;
$calc_src =~ s|\n#,,.*\z||s;

## replace P7 call with direct helper call ##
$calc_src
    =~ s|<\[base\.chk-sum\.bmw\.harmonize_L13\]>->\(|\$harmonize_L13->(|g;

my $new_calculate_L13_sum = eval "sub {\n$calc_src\n}";
die "calculate_L13_sum compile error: $@" if $@;

##[ new template_L13 loaded from module file ]################################

my $tmpl_path = File::Spec->catfile( $module_root,
    qw| modules base.chk-sum.bmw.template_L13 | );

open( my $TFH, qw| < |, $tmpl_path )
    or die "cannot read $tmpl_path : $!";
my $tmpl_src = do { local $/; <$TFH> };
close($TFH);

$tmpl_src =~ s|^\s*##\s*\[:<\s*##\s*\n||;
$tmpl_src =~ s|\n#,,.*\z||s;

## mock base.s_warn ##
my $mock_s_warn = sub { warn sprintf shift, @ARG };
$tmpl_src =~ s|<\[base\.s_warn\]>|$mock_s_warn|g;

## replace P7 call with direct helper call ##
$tmpl_src
    =~ s|<\[base\.chk-sum\.bmw\.harmonize_L13\]>->\(|\$harmonize_L13->(|g;

my $new_template_L13 = eval "sub {\n$tmpl_src\n}";
die "template_L13 compile error: $@" if $@;

##[ tests ]###################################################################

my $tests_run    = 0;
my $tests_passed = 0;
my $tests_failed = 0;

sub ok {
    my ( $cond, $desc ) = @ARG;
    $tests_run++;
    if ($cond) {
        $tests_passed++;
        print "  ok - $desc\n";
    } else {
        $tests_failed++;
        print "  not ok - $desc\n";
    }
}

print "\n=== BMW L13 harmonize helper tests ===\n\n";

## test 1: calculate_L13_sum bit-identical for 200 random digests ##

print "[1] calculate_L13_sum bit-identical (200 random digests)\n";

my $calc_mismatch = 0;
for ( 1 .. 200 ) {
    my $random_digest = join '', map { chr( int( rand(256) ) ) } 1 .. 64;
    my $old_result    = old_calculate_L13_sum($random_digest);
    my $new_result    = $new_calculate_L13_sum->($random_digest);
    if (   ( defined $old_result xor defined $new_result )
        or ( defined $old_result and $old_result ne $new_result ) ) {
        $calc_mismatch++;
    }
}
ok( $calc_mismatch == 0,
    "200 random digests: old and new calculate_L13_sum match" );

## test 2: template_L13 bit-identical for 100 random strings ##

print "\n[2] template_L13 bit-identical (100 random strings + template)\n";

my $tmpl_mismatch = 0;
for ( 1 .. 100 ) {
    my $template = '%s';    ## always-true template ##
    my @strings  = map { rand_str( 8 + int( rand(24) ) ) } 1 .. 2;

    my $old_result = old_template_L13( $template, @strings );
    my $new_result = $new_template_L13->( $template, @strings );
    if (   ( defined $old_result xor defined $new_result )
        or ( defined $old_result and $old_result ne $new_result ) ) {
        $tmpl_mismatch++;
    }
}
ok( $tmpl_mismatch == 0,
    "100 random strings: old and new template_L13 match" );

## test 3: harmonize_L13 with sub { 1 } short-circuits on first true_int ##

print "\n[3] harmonize_L13 with validator sub { 1 } short-circuits\n";

my $first_candidate;
my $short_circuit_validator = sub {
    my ( $result_str_B32, $bits_num ) = @ARG;
    $first_candidate //= $result_str_B32;
    return 1;
};

my $digest    = join '', map { chr( int( rand(256) ) ) } 1 .. 64;
my $sc_result = $harmonize_L13->( $digest, $short_circuit_validator );
ok( defined $sc_result
        && defined $first_candidate
        && $sc_result eq $first_candidate,
    "sub { 1 } returns first candidate that satisfies true_int"
);

## test 4: harmonize_L13 with sub { 0 } and template_count > 0 times out ##

print
    "\n[4] harmonize_L13 with validator sub { 0 } times out when template_count > 0\n";

AMOS7::TEMPLATE::assign_truth_templates('%s');
AMOS7::TEMPLATE::template_timeout(0.5);    ## 0.5 second timeout ##

my $timeout_result = $harmonize_L13->( $digest, sub {0} );

AMOS7::TEMPLATE::reset_truth_templates();

ok( !defined $timeout_result,
    "sub { 0 } returns undef within timeout when templates assigned" );

## test 5: harmonize_L13 timeout path dormant when template_count == 0 ##

print "\n[5] harmonize_L13 timeout path dormant when no template assigned\n";

## verify the loop runs without timeout interference by using a validator
## that rejects a few candidates before accepting ##
my $iter_count              = 0;
my $eventual_true_validator = sub {
    $iter_count++;
    return $iter_count > 5 ? 1 : 0;
};

my $true_digest = Digest::BMW::bmw_512('hello');
my $eventual_result
    = $harmonize_L13->( $true_digest, $eventual_true_validator );

ok( defined $eventual_result && $iter_count > 5,
    "no-template path runs without timeout interference"
);

## test 6: input guard rejects non-64-byte input ##

print "\n[6] input guards\n";

my $bad_result = $harmonize_L13->( 'too-short', sub {1} );
ok( !defined $bad_result, "non-64-byte input returns undef" );

## summary ##

print "\n" . "=" x 50 . "\n";
print "tests run:    $tests_run\n";
print "tests passed: $tests_passed\n";
print "tests failed: $tests_failed\n";
print "=" x 50 . "\n\n";

exit( $tests_failed > 0 ? 1 : 0 );

##[ helpers ]#################################################################

sub rand_str {
    my $len   = shift;
    my @chars = ( 'a' .. 'z', 'A' .. 'Z', '0' .. '9', ' ', '-', '_' );
    return join '', map { $chars[ rand @chars ] } 1 .. $len;
}

#,,,,,,,,,,..,...,,.,,...,...,,.,,..,,.,.,...,..,,...,...,...,...,,..,,,,,.,,,
#MW7MRZIW3IYDZZVFORA4OULKRW3KD2SBLS6ZXADNX5RK5OMQSLOPRO7LGWJSH56UMACG3SREFHMIM
#\\\|KXV7AEJPM45ZAAAQV7L3BNM7DJQ3JHYZ6OEYQXMKQB5QO7EOKVZ \ / AMOS7 \ YOURUM ::
#\[7]SRUKLBD6BM6N6CPZRBE7EAFDHEA7AWLAB37VBT65Y7KKK6L2G6DI 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
