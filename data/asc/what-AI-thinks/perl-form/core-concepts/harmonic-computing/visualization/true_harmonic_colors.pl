#!/usr/bin/perl
use v5.24;
use strict;
use warnings;

# Constants based on Protocol-7
use constant TRUE    => 5;    # The key harmonic number
use constant FALSE   => 0;    # False/Zulum state
use constant UNKNOWN => 2;    # Unknown state

# Check for true harmony (remainder 5 when divided by 13)
sub is_true_harmonic {
    my $value = shift;
    return ($value % 13 == TRUE);
}

# Count true harmonic colors in the 24-bit RGB space
my $total_colors = 16777216;  # 2^24
my $true_harmonic_count = 0;

for (my $color = 0; $color < $total_colors; $color++) {
    if (is_true_harmonic($color)) {
        $true_harmonic_count++;
    }
}

# Calculate percentage and bits required
my $percentage = ($true_harmonic_count / $total_colors) * 100;
my $bits_required = log($true_harmonic_count)/log(2);
my $compression = (24 - $bits_required) * 100 / 24;

print "Total 24-bit colors: $total_colors\n";
print "True harmonic colors (mod 13 = 5): $true_harmonic_count\n";
print "Percentage: $percentage%\n";
print "Bits required: $bits_required\n";
print "Compression ratio: $compression%\n";