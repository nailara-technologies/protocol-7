#!/usr/bin/env perl
## [:< ##
## verify fix for amos-term.plugin-decoder.elf_match  confirms
## is_true(\$checksum, 0, 1, $mode) gives spread distribution not a committed
## test -- run directly to sanity-check the fix

use strict;
use warnings;
use FindBin;
use lib "$FindBin::Bin/../../data/lib-path/pm";

use AMOS7;
use AMOS7::Assert::Truth;

my @samples = qw|
    ABCDEFG7HIJKLMNOP
    QRS2TUVWXYZ234567
    AAAA2222BBBB3333CC
    HELLO7WORLD2AMOS77
    PROTOCOL7CHECKSUM4
    ZZZZZZZZAAAAAAAA22
    XXXXXXX7YYYYYYYY4
    TESTINGTESTINGTEST
    RESONANCE7MODE1337
    ELFMATCH7FIX2PROBE
    KQMNJR4VXPAB7CDLZ2
    LOVESTOKEN7AMOS13X
    VERIFYDISTRIBUTION7
    DIVISONBY13TRUTH44
    HARMONICELFMODE777
    CHECKSUM13SCORES22
    MODEPASSFAIL4AMOS7
    BRACKETCHECK13XYZ7
    NINECHARACTERSONLY7
    FIVEXXXXXXXXXX7ABCD
    |;

my %score_counts;

printf "%-30s  %5s  %5s  %6s  %s\n", 'checksum', 'p4', 'p7', 'p13', 'score';
printf "%s\n", '-' x 65;

for my $cs (@samples) {
    my $pass4  = AMOS7::Assert::Truth::is_true( \$cs, 0, 1, 4 )  ? 1 : 0;
    my $pass7  = AMOS7::Assert::Truth::is_true( \$cs, 0, 1, 7 )  ? 1 : 0;
    my $pass13 = AMOS7::Assert::Truth::is_true( \$cs, 0, 1, 13 ) ? 1 : 0;
    my $score = ( $pass4 ? 4 : 0 ) + ( $pass7 ? 7 : 0 ) + ( $pass13 ? 2 : 0 );

    $score_counts{$score}++;
    printf "%-30s  %5d  %5d  %6d  %d\n", $cs, $pass4, $pass7, $pass13, $score;
}

printf "\n%s\n",                                  '=' x 65;
printf "score distribution across %d samples:\n", scalar @samples;
for my $s ( sort { $a <=> $b } keys %score_counts ) {
    printf "  score %2d : %d\n", $s, $score_counts{$s};
}

my $distinct = scalar keys %score_counts;
printf "\ndistinct scores seen: %d (need "
    . "> 1 to confirm non-degeneracy)\n", $distinct;
die "FAIL: all samples produced same score -- distribution is degenerate\n"
    if $distinct <= 1;

print "PASS: spread distribution confirmed\n";

#,,,,,..,,.,,,..,,,,,,.,.,...,,,,,.,.,,.,,,..,..,,...,...,,..,,,.,.,.,.,.,.,,,
#WJF7UT7CLWKEHMEFYTHP5U5LXALS3SNSK5E7GBNWZHXWX2VIIR756GZ7NVSSDW2ONK7T7XV62D37S
#\\\|QCAOQYUYOWK6HSZX57XRZSZSRP6QX2FHQROM373TA5P74WXXZXR \ / AMOS7 \ YOURUM ::
#\[7]5YNWHGQ7UTNYY5EWVX66LBQ7SSS44SSSHAG7442SGCGSVSBKCQAQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
