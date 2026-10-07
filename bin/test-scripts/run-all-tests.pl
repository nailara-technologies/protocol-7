#!/usr/bin/perl
use v5.24;
use strict;
use warnings;
use File::Spec;

## Comprehensive test runner for template + conversation system
## Runs all test scripts and reports results

my $script_dir = File::Spec->rel2abs($0);
$script_dir =~ s|/[^/]+$||;

my @test_files = (
    'test-conversation-system.pl',
    'test-template-substitution.pl',
    'test-vision-conversation.pl'
);

print "\n";
print "=" x 70 . "\n";
print "  PROTOCOL-7 TEMPLATE & CONVERSATION SYSTEM TEST SUITE\n";
print "=" x 70 . "\n";

my $total_tests = scalar(@test_files);
my $passed = 0;
my $failed = 0;

foreach my $test_file (@test_files) {
    my $test_path = File::Spec->catfile($script_dir, $test_file);

    unless (-f $test_path) {
        print "✗ Test file not found: $test_path\n";
        $failed++;
        next;
    }

    print "\nRunning: $test_file\n";
    print "-" x 70 . "\n";

    my $result = system("perl $test_path");

    if ($result == 0) {
        $passed++;
    } else {
        $failed++;
    }
}

print "\n" . "=" x 70 . "\n";
print "TEST RESULTS\n";
print "=" x 70 . "\n";
print "Total Tests: $total_tests\n";
print "Passed:      $passed\n";
print "Failed:      $failed\n";
print "=" x 70 . "\n\n";

if ($failed == 0) {
    print "✓ All tests passed!\n\n";
} else {
    print "✗ Some tests failed. Review output above.\n\n";
}

print "Next Steps:\n";
print "1. Review any failed tests\n";
print "2. Check protocol-7 logs: tail -f /var/log/protocol-7/*\n";
print "3. Verify v7-zenki zenka health: p7c v7-zenki.status\n";
print "4. Test end-to-end vision pipeline when ready\n\n";

exit($failed > 0 ? 1 : 0);

#,,,.,,.,,..,,..,,...,...,...,.,,,..,,,..,.,,,..,,...,...,,..,,.,,..,,,.,,,..,
#3RGHMO3POJXHF2XR5VLWNU5TAFTXQL4FHNVTWA5BEHURF3FN7U73A5JGBMQ2T3TWYP6M2L2BAFKOA
#\\\|X4IY2PAIEL2EH4LMITPAGMQUU3P3WEPA6YVQUM23MSAJJYUNXR7 \ / AMOS7 \ YOURUM ::
#\[7]IHSKUEOMJOJW2AMO4IHHQFUHOM4ZI5NNXNKGQPT2JDLNMKHHOAAQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
