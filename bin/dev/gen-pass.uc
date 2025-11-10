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

#,,,.,,,,,,.,,,,.,,..,.,,,.,.,,..,..,,.,.,.,,,..,,...,...,.,.,,,.,,..,...,,,,,
#ODEW2A6BGIRAXLHU2AQBLAF4U5MET652L5P2KCKY7KZUOIP3SVZORM5IFXHMPGMSZAZNC5QETB2PG
#\\\|HSFWW3QWFQOFYK7PEMWS6UZ7L36HOFLHWSRDOSNDEX4I7CQEB25 \ / AMOS7 \ YOURUM ::
#\[7]R3T56MM7NJ6ZJIU5UZ73OQNDMUNXAB6JH2CQXY46PFSKDKKNGABI 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
