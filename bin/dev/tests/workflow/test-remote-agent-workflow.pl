#!/usr/bin/perl
# Test harness for remote agent iteration testing
use v5.24;
use strict;
use warnings;
use Getopt::Long;

my $server = '';
my $iterations = 5;
my $verbose = 0;

GetOptions(
    'server=s' => \$server,
    'iterations=i' => \$iterations,
    'verbose|v' => \$verbose,
) or die "Error in options\n";

unless ($server) {
    die "Usage: bin/test-remote-agent-workflow.pl --server host:port [--iterations N] [--verbose]\n";
}

print "Remote Agent Test Harness\n";
print "  Server: $server\n";
print "  Iterations: $iterations\n";
print "\n";

for my $i (1 .. $iterations) {
    print "  Iteration $i... ";
    # TODO: Connect to server
    # TODO: Initialize session
    # TODO: Run test
    # TODO: Verify result
    print "OK\n";
}

print "\nDone.\n";

#,,,.,..,,..,,.,,,,.,,,,.,..,,..,,...,,,.,..,,..,,...,...,..,,...,,..,,.,,.,.,
#MTXCBUFXI2BDXWZCGAQPL5KOE2WGXFNREZBF6WOJ6VU4RMQROXXMCF3SX5JIB7O2PUPYS6QZ2OAMO
#\\\|ORKJHPTMY44ZHO2EN2DNJZ6CF6E33S2UIZCLXJU3HZGNIIAXHO5 \ / AMOS7 \ YOURUM ::
#\[7]AGQXS7YB3WU7CB6EPKKQA4XUKIR4HANRREBUYF5IBVR4D4F4DWCQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
