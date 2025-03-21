#!/usr/bin/perl
use v5.24;
use strict;
use warnings;

# Constants
use constant TRUE => 5;
use constant FALSE => 0;

# Check if a ratio approximates n/13
sub is_division_by_13_harmonic {
    my ($numerator, $denominator) = @_;
    return FALSE if $denominator == 0;
    
    my $ratio = $numerator / $denominator;
    
    # Check if ratio is close to any n/13 fraction
    for my $n (1..12) {
        my $target = $n / 13;
        if (abs($ratio - $target) < 0.01) {
            return TRUE;
        }
    }
    
    # Alternative method: check decimal expansion pattern
    my $decimal_str = sprintf("%.6f", $ratio);
    $decimal_str =~ s/^0\.//;  # Remove "0." prefix
    
    # Check for cyclic patterns of division by 13
    # 1/13 = 0.076923...
    # 2/13 = 0.153846...
    # 3/13 = 0.230769...
    # etc.
    
    # Pattern matching for the first few digits
    return TRUE if $decimal_str =~ /^0?7692/;     # ≈ 1/13
    return TRUE if $decimal_str =~ /^15384[56]/;  # ≈ 2/13
    return TRUE if $decimal_str =~ /^23076[9]/;   # ≈ 3/13
    return TRUE if $decimal_str =~ /^30769[2]/;   # ≈ 4/13
    
    return FALSE;
}

# Check for tri-harmonic color (all filters)
sub is_color_tri_harmonic {
    my $color = shift;
    
    # Extract RGB components
    my $r = ($color >> 16) & 0xFF;
    my $g = ($color >> 8) & 0xFF;
    my $b = $color & 0xFF;
    
    # 1. Check division by 13 remainder (primary)
    my $primary_harmonic = ($color % 13 == 4 || $color % 13 == 7);
    return FALSE unless $primary_harmonic;
    
    # 2. Check hex string representation (secondary)
    my $hex = sprintf("%06X", $color);
    my $hex_sum = 0;
    foreach my $char (split //, $hex) {
        $hex_sum += ord($char);
    }
    my $secondary_harmonic = ($hex_sum % 13 == 4 || $hex_sum % 13 == 7);
    return FALSE unless $secondary_harmonic;
    
    # 3. Check channel proportions (tertiary) using division by 13
    my $channel_harmonic = FALSE;
    
    # Skip cases where channels are zero to avoid division by zero
    if ($g > 0) {
        $channel_harmonic = TRUE if is_division_by_13_harmonic($r, $g);
    }
    
    if ($b > 0) {
        $channel_harmonic = TRUE if is_division_by_13_harmonic($g, $b);
        $channel_harmonic = TRUE if is_division_by_13_harmonic($r, $b);
    }
    
    return $channel_harmonic;
}

# Calculate the size of the tri-harmonic color space
my $sample_size = 100000;
my $tri_harmonic_count = 0;

for (my $i = 0; $i < $sample_size; $i++) {
    my $color = int(rand(16777216));
    $tri_harmonic_count++ if is_color_tri_harmonic($color);
}

my $percentage = ($tri_harmonic_count / $sample_size) * 100;
my $estimated_total = int(16777216 * $percentage / 100);
my $bits_required = log($estimated_total)/log(2);
my $compression = (24 - $bits_required) * 100 / 24;

printf "Sample size: %d colors\n", $sample_size;
printf "Tri-harmonic colors found: %d (%.4f%%)\n", $tri_harmonic_count, $percentage;
printf "Estimated total tri-harmonic colors: %d\n", $estimated_total;
printf "Bits required for representation: %.2f\n", $bits_required;
printf "Compression ratio: %.2f%%\n", $compression;