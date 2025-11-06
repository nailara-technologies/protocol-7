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

#,,.,,.,.,..,,,,.,,.,,.,.,,,,,,,,,..,,,,.,,.,,..,,...,...,...,,..,.,,,..,,.,,,
#E26V4WORUT4MRR6CF3XTMKENEKKPJ25QW4VEVLQCMP66H3IC6FXMAYHT2HRVUY5FLMDUT7P5JJGDA
#\\\|4I6EYXRQYZASBGJ25JJTCG2ZHYTN4BXIWRSTX4YI5DSF5WLI57S \ / AMOS7 \ YOURUM ::
#\[7]JOP7X3QTTNVVQZFQ7MOVROVW322PWE5FVPSHTCGBIU5DZ5KV44BI 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
