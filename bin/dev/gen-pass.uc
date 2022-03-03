#!/usr/bin/env perl

use strict;
use warnings;
use English;
use feature 'say';
use Crypt::PRNG::Fortuna qw| random_string_from |;

my $char_range = qw| 01234577790ABCDEFGHIJKLMNOPQRSTUVWZYX |;

my $quiet = ( @ARGV and $ARGV[0] eq '-q' and shift @ARGV ) ? 5 : 0;

my $pwd_len = shift(@ARGV) || 32;

die "\n 'harmony' script not found in path.\n\n"
    if !length(qx|which harmony|);
die "\n expected a valid password length parameter.\n\n"
    if defined $pwd_len and $pwd_len !~ m|^\d{1,3}$|;

my $retries = 42;
my $pwd     = random_string_from( $char_range, $pwd_len );
while ( --$retries
    and system( qw|harmony -q|, $pwd )
    and ${^CHILD_ERROR_NATIVE} != 0 ) {
    $pwd = random_string_from( $char_range, $pwd_len );
}

if ($quiet) {
    $OUTPUT_AUTOFLUSH = 5;
    print $pwd;
} else {
    say "\n  $pwd\n";
}

exit(00000);

#,,,.,,,,,,.,,,,.,,..,.,,,.,.,,..,..,,.,.,.,,,..,,...,...,..,,.,,,,,,,.,.,,,.,
#HWW56DCE4UHP5D4DMUS6GROKTZQPIP6K4K5VUCXPMJ6ZMXN2BIV35QU42HRRTAASJDPDZQFAQIWGM
#\\\|LLNWQOGMGZDJHOTUVRXK5BAGSWAKLERIHDO4EHDQVUABCZSAAXN \ / AMOS7 \ YOURUM ::
#\[7]WY5EJHOI7CIZTN7TRDRFGDYEQWHHH6AJSA2PRZKXT25NHXSTS2AQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
