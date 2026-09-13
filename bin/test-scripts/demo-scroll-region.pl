#!/usr/bin/env perl

## visual demo for AMOS7::TERM's scroll_region_set/pinned_row_print -- run  ##
## this directly in a REAL terminal to confirm the split-screen primitive   ##
## actually looks right before wiring it into nshell. prints simulated      ##
## "streaming" content into a scrolling top region while a fake,            ##
## periodically-updated "input line" sits pinned at the bottom, proving the ##
## two don't corrupt each other.                                            ##
##                                                                          ##
## run: perl bin/test-scripts/demo-scroll-region.pl                         ##
## quit: ctrl-c [ restores full-screen scrolling on the way out ]           ##

use v5.24;
use strict;
use warnings;
use FindBin     qw| $RealBin |;
use Time::HiRes qw| sleep time |;

BEGIN { unshift( @INC, "$RealBin/../../data/lib-path/pm" ) }
use AMOS7::TERM qw| scroll_region_set scroll_region_clear pinned_row_print |;

die "run this in a real terminal, not a pipe\n" unless -t STDOUT;

my $input_row = scroll_region_set(1);    ## reserve the bottom 1 row ##
die "terminal too small\n" unless defined $input_row;
$input_row++;                            ## the reserved row itself ##

$SIG{'INT'} = sub {
    scroll_region_clear();
    print "\n";
    exit 0;
};

my $counter = 0;
print "-- scroll-region demo : streaming content "
    . "above, pinned input line below --\n";

while (1) {
    $counter++;
    print "[ simulated stream chunk $counter, " . scalar(localtime) . " ]\n";

    pinned_row_print( $input_row,
        sprintf( '> fake input line, still here [ tick %d ] _', $counter ) );

    sleep(0.4);
}

#,,,,,..,,,,,,,,,,.,.,,.,,.,,,...,,,.,,.,,.,,,..,,...,...,.,.,.,.,,..,,..,,,.,
#5L2I6MJMLHJ53DJYF7XKC2UPOM7PNJBJXA3WTMI7BIWOIUUQKYYGDG4CGJIWUTMWREGSYT6XFIMYS
#\\\|WNHQYATUUOREFD6XI5ZPVQPQSSMGOPUXRVBW4SE44RNXIT5Z56X \ / AMOS7 \ YOURUM ::
#\[7]LA6SWJXGDBE5FCVSK2E5AHENCUHUYBCSKRZZRSU2F52QIRMSWAAQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
