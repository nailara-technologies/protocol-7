#!/usr/bin/perl
use v5.24;
use strict;
use warnings;

# Constants
use constant TRUE => 5;
use constant FALSE => 0;

# Identify tri-harmonic colors
sub is_color_tri_harmonic {
    my $color = shift;
    
    # Extract RGB components
    my $r = ($color >> 16) & 0xFF;
    my $g = ($color >> 8) & 0xFF;
    my $b = $color & 0xFF;
    
    # Prevent division by zero
    return FALSE if $r == 0 || $g == 0;
    
    # 1. Check division by 13 remainder (primary)
    my $primary_harmonic = ($color % 13 == 4 || $color % 13 == 7);
    return FALSE unless $primary_harmonic;
    
    # 2. Check hex string representation (secondary)
    my $hex = sprintf("%06X", $color);
    my $secondary_harmonic = is_hex_string_harmonic($hex);
    return FALSE unless $secondary_harmonic;
    
    # 3. Check channel proportions (tertiary)
    # Method A: Division by 13 channel ratio harmonics
    my $rg_ratio = int(($r * 100) / $g) % 13;
    my $gb_ratio = int(($g * 100) / $b) % 13;
    my $rb_ratio = int(($r * 100) / $b) % 13;
    
    my $ratio_harmonic = ($rg_ratio == 4 || $rg_ratio == 7 || 
                         $gb_ratio == 4 || $gb_ratio == 7 || 
                         $rb_ratio == 4 || $rb_ratio == 7);
    
    # Method B: Golden ratio approximation (φ ≈ 1.618)
    my $phi = 1.618;
    my $phi_tolerance = 0.05;
    
    my $golden_harmonic = 
        (abs(($r/$g) - $phi) < $phi_tolerance) ||
        (abs(($g/$b) - $phi) < $phi_tolerance) ||
        (abs(($r/$b) - $phi) < $phi_tolerance);
    
    # Return true if any tertiary harmony method is satisfied
    return ($ratio_harmonic || $golden_harmonic);
}

# Check if hex string is harmonic
sub is_hex_string_harmonic {
    my $hex = shift;
    
    # Calculate character sum and check remainder
    my $char_sum = 0;
    foreach my $char (split //, $hex) {
        $char_sum += ord($char);
    }
    
    return ($char_sum % 13 == 4 || $char_sum % 13 == 7);
}

# Count harmonics in a sample
my $sample_size = 100000;
my $tri_harmonic_count = 0;

for (my $i = 0; $i < $sample_size; $i++) {
    my $color = int(rand(16777216));
    $tri_harmonic_count++ if is_color_tri_harmonic($color);
}

my $percentage = ($tri_harmonic_count / $sample_size) * 100;
printf "Tri-harmonic colors: %d (%.2f%%)\n", $tri_harmonic_count, $percentage;
printf "Estimated bits required: %.1f (%.1f%% compression)\n", 
       log($tri_harmonic_count * (16777216/$sample_size))/log(2),
       (24 - log($tri_harmonic_count * (16777216/$sample_size))/log(2)) * 100 / 24;