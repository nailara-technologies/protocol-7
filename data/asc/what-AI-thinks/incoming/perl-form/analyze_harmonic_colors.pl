#!/usr/bin/perl
use v5.24;
use strict;
use warnings;

# Constants
use constant TRUE => 5;
use constant FALSE => 0;

# Track harmonic colors
my %harmonic_counts;
my $total_count = 0;
my $harmonic_count = 0;

# Function to check if a color is harmonic (based on AMOS7 truth principles)
sub is_color_harmonic {
    my $color_value = shift;
    
    # Extract RGB components
    my $r = ($color_value >> 16) & 0xFF;
    my $g = ($color_value >> 8) & 0xFF;
    my $b = $color_value & 0xFF;
    
    # Apply division by 13 remainder analysis
    # Different strategies to consider:
    
    # 1. Individual channel harmonics
    my $r_harmonic = ($r % 13 == 4 || $r % 13 == 7);
    my $g_harmonic = ($g % 13 == 4 || $g % 13 == 7);
    my $b_harmonic = ($b % 13 == 4 || $b % 13 == 7);
    
    # 2. Combined value harmonic
    my $combined_harmonic = ($color_value % 13 == 5);
    
    # 3. AMOS7-inspired approach (example)
    my $amos_harmonic = (($r + $g + $b) % 13 == 7);
    
    # Return based on desired approach
    return $amos_harmonic;
}

# Sample the color space (full analysis would be very time-consuming)
my $sample_size = 1000000;
for (my $i = 0; $i < $sample_size; $i++) {
    my $color = int(rand(16777216));
    $total_count++;
    
    if (is_color_harmonic($color)) {
        $harmonic_count++;
        my $remainder = $color % 13;
        $harmonic_counts{$remainder}++;
    }
}

# Print results
my $percentage = ($harmonic_count / $total_count) * 100;
say "Total colors sampled: $total_count";
say "Harmonic colors found: $harmonic_count ($percentage%)";
say "Distribution by remainder:";
foreach my $rem (sort keys %harmonic_counts) {
    say "  Remainder $rem: $harmonic_counts{$rem} colors";
}

# Estimate compression potential
my $bits_needed = log($harmonic_count) / log(2);
say "Bits needed to represent harmonic colors: ~$bits_needed";
say "Potential compression vs 24-bit: ~" . (24 - $bits_needed) . " bits/color";