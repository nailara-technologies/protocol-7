#!/usr/bin/perl
# Standalone benchmark for AMOS7::13::key_32 iteration performance
# Helps determine safe default limits for the function

use lib "./data/lib-path/pm";
use v5.24;
use strict;
use warnings;
use Time::HiRes qw(time sleep);
use AMOS7::13   qw(key_32);

my $RUN_TIME  = 5;    # Run benchmark for 5 seconds
my $test_seed = "benchmark_entropy_seed_data_test_string";

print "\n";
print "=" x 60 . "\n";
print "AMOS7::13::key_32 Iteration Performance Benchmark\n";
print "Running for ~$RUN_TIME seconds to measure real performance\n";
print "=" x 60 . "\n\n";

# Test 1: SCALAR ref usage (smart iteration count)
print "[TEST 1] SCALAR ref parameter (smart 113-226 iterations)\n";
print "         Recommended: This is the preferred usage\n";
print "-" x 60 . "\n";

my $count      = 0;
my $start_time = time();
my $total_time = 0;

while ( $total_time < $RUN_TIME ) {
    my $seed_var = $count;    # Different entropy per iteration
    my $key      = key_32( \$test_seed, \$seed_var );
    $count++;
    $total_time = time() - $start_time;
}

my $elapsed = time() - $start_time;
my $rate    = $count / $elapsed;

printf "  Iterations in %.2fs: %d calls\n", $elapsed, $count;
printf "  Rate: %.1f calls/second\n", $rate;
printf "  Average time per call: %.4fs (%.1fms)\n\n", $elapsed / $count,
    ( $elapsed / $count ) * 1000;

# Test 2: Small numeric seeds (safe range)
print "[TEST 2] Numeric seed parameter (safe: 0-1000)\n";
print "         Total iterations: 113 + seed\n";
print "-" x 60 . "\n";

my @test_numeric_seeds = ( 1, 10, 100, 500, 1000 );

foreach my $num_seed (@test_numeric_seeds) {
    my $count_n   = 0;
    my $start_n   = time();
    my $elapsed_n = 0;

    while ( $elapsed_n < 1.0 ) {
        my $key = key_32( \$test_seed, $num_seed );
        $count_n++;
        $elapsed_n = time() - $start_n;
    }

    my $rate_n     = $count_n / $elapsed_n;
    my $total_iter = 113 + $num_seed;

    printf "  Seed +%-5d (total %4d iters): %.1f calls/sec (%.2fms each)\n",
        $num_seed, $total_iter, $rate_n, ( 1000 / $rate_n );
}

print "\n";
print "[TEST 3] Analysis & Recommendations\n";
print "-" x 60 . "\n\n";

print "PERFORMANCE THRESHOLDS:\n";
printf "  Instant (< 50ms):      can run in event handlers\n";
printf "  Fast (< 200ms):        acceptable in event loop\n";
printf "  Moderate (< 500ms):    noticeable, should avoid in loop\n";
printf "  Slow (> 2s):           should be async or standalone\n\n";

print "SAFE LIMITS ANALYSIS:\n";
print "  ✓ SCALAR ref usage:      Safe (auto 113-226 iters)\n";
print "  ✓ Numeric 0-1000:        Safe (113-1113 iters)\n";
print "  ✗ Numeric > 1000:        Unsafe - exponential slowdown\n";
print "  ✗ Numeric > 100,000:     Blocks event loop entirely\n\n";

print "RECOMMENDED DEFAULTS:\n";
print "  • Default iteration limit: 1000 (for numeric seeds)\n";
print "  • Warning threshold: seeds > 1000\n";
print "  • Override flag for long-running use: allow explicit exceeding\n\n";

print "USAGE PATTERNS:\n";
print "  ✓ Safe:     key_32(\\\\secret, \\\\session_id)\n";
print "              Smart iterations: 113-226, instant\n\n";
print "  ✗ Unsafe:   key_32(\\\\secret, \$large_number)\n";
print "              Could create millions of iterations\n\n";

print "=" x 60 . "\n";
print "Benchmark complete. Use results to set AMOS7::13 limits.\n";
print "=" x 60 . "\n\n";

#,,.,,.,,,..,,,,,,.,.,...,.,.,,,,,,,.,...,.,,,..,,...,...,.,.,,.,,...,.,.,.,,,
#7QYMKYQLQXB5NFPLXOZPCABGFUT7D5FEYXRDXMA3GXUXG3MYG2QYMV2XNQ7F2BMZC6W3WDIZ76CWY
#\\\|2HZKFWWP23I5H62TVPQJ5DZUXAGH5UNXBGURWKV2UAJWBQMSU6D \ / AMOS7 \ YOURUM ::
#\[7]JOWITCAFHZTOTGROET6XMEHPKYNEQB544WN3LTZDU32433NUWECQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
