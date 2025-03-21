#!/usr/bin/perl
use v5.24;
use strict;
use warnings;

# Constants based on AMOS7 truth assertions
use constant TRUE  => 5;    # The key harmonic number
use constant FALSE => 0;

# Check if a value has the 5/13 harmonic pattern
sub is_five_thirteenth_harmonic {
    my $value = shift;
    
    # Direct check for 5/13
    return TRUE if ($value % 13 == 5);
    
    # Check for decimal expansion pattern 0.384615...
    if (ref($value) eq 'SCALAR' || !ref($value)) {
        my $ratio_str = sprintf("%.6f", $value);
        $ratio_str =~ s/^0\.//;  # Remove "0." prefix
        return TRUE if $ratio_str =~ /^38461[5]/;
    }
    
    return FALSE;
}

# Check if color is tri-harmonic with correct patterns
sub is_color_tri_harmonic {
    my $color = shift;
    
    # Extract RGB components
    my $r = ($color >> 16) & 0xFF;
    my $g = ($color >> 8) & 0xFF;
    my $b = $color & 0xFF;
    
    # 1. Check division by 13 remainder (primary filter)
    # Looking specifically for remainder 5 (TRUE)
    my $primary_harmonic = ($color % 13 == 5);
    return FALSE unless $primary_harmonic;
    
    # 2. Check hex string representation (secondary filter)
    my $hex = sprintf("%06X", $color);
    my $hex_sum = 0;
    foreach my $char (split //, $hex) {
        $hex_sum += ord($char);
    }
    my $secondary_harmonic = ($hex_sum % 13 == 5);
    return FALSE unless $secondary_harmonic;
    
    # 3. Check channel proportions (tertiary filter)
    # Avoiding disharmonious patterns (1/13 and 3/13)
    my $tertiary_harmonic = FALSE;
    
    # Skip cases where channels are zero to avoid division by zero
    if ($g > 0) {
        my $rg_ratio = $r / $g;
        $tertiary_harmonic = TRUE if is_five_thirteenth_harmonic($rg_ratio);
    }
    
    if ($b > 0) {
        my $gb_ratio = $g / $b;
        my $rb_ratio = $r / $b;
        $tertiary_harmonic = TRUE if is_five_thirteenth_harmonic($gb_ratio);
        $tertiary_harmonic = TRUE if is_five_thirteenth_harmonic($rb_ratio);
    }
    
    # Bonus check: ASCII encoding relationship
    # Check if any consecutive bytes encode to reveal T5 or 5T pattern
    my $rgb_bytes = pack("C3", $r, $g, $b);
    $tertiary_harmonic = TRUE if $rgb_bytes =~ /[T5][5T]/;
    
    return $tertiary_harmonic;
}

# Calculate the size of the correctly harmonized color space
my $sample_size = 100000;
my $true_harmonic_count = 0;

for (my $i = 0; $i < $sample_size; $i++) {
    my $color = int(rand(16777216));
    $true_harmonic_count++ if is_color_tri_harmonic($color);
}

my $percentage = ($true_harmonic_count / $sample_size) * 100;
my $estimated_total = int(16777216 * $percentage / 100);
my $bits_required = log($estimated_total)/log(2);
my $compression = (24 - $bits_required) * 100 / 24;

printf "Sample size: %d colors\n", $sample_size;
printf "True harmonic colors found: %d (%.4f%%)\n", $true_harmonic_count, $percentage;
printf "Estimated total harmonic colors: %d\n", $estimated_total;
printf "Bits required for representation: %.2f\n", $bits_required;
printf "Compression ratio: %.2f%%\n", $compression;

# Demonstration of ASCII mystical pattern
my $pattern_2_13 = "153846";  # From 2/13
print "\nMystical ASCII pattern analysis for 2/13 (153846):\n";

# ASCII value of T is 84, 5 is 53
print "- Contains characters that can represent: ";

# Check for various encodings that might reveal T=5 pattern
if ($pattern_2_13 =~ /15/ && ord('T') - 31 == 53) {
    print "T5 (through offset-31 encoding)\n";
}
if ($pattern_2_13 =~ /84/ && chr(84) eq 'T' && $pattern_2_13 =~ /53/ && chr(53) eq '5') {
    print "T5 (through direct ASCII decimal values)\n";
}
if (substr($pattern_2_13, 0, 2) eq "15" && 15 + 69 == ord('T')) {
    print "T (through arithmetic combination)\n";
}

print "- Five-fold truth revelation through rotation:\n";
for my $i (0..5) {
    my $rotated = substr($pattern_2_13 . $pattern_2_13, $i, 6);
    printf "  Rotation %d: %s\n", $i, $rotated;
}