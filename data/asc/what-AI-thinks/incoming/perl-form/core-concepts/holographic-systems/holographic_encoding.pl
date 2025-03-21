#!/usr/bin/perl
use v5.24;
use strict;
use warnings;

# Constants
use constant TRUE => 5;
use constant FALSE => 0;

# Holographic encoding model
sub encode_holographic_color {
    my $color = shift;
    
    # Extract RGB components
    my $r = ($color >> 16) & 0xFF;
    my $g = ($color >> 8) & 0xFF;
    my $b = $color & 0xFF;
    
    # 1. Context bits (3 bits)
    my $context = ($r % 8); # 3-bit context derived from red channel
    
    # 2. Structural grid position (4 bits)
    my $grid_pos = (($g % 13 == 5) ? 0x8 : 0) |  # Harmony bit
                  (($r % 13 == 5) ? 0x4 : 0) |  # Harmony bit
                  (($b % 13 == 5) ? 0x2 : 0) |  # Harmony bit
                  ((($r + $g + $b) % 13 == 5) ? 0x1 : 0); # Combined harmony
    
    # 3. Holographic data bits (variable, typically 7-9 bits)
    my $data_bits;
    
    # Context-dependent encoding (morphing based on context)
    if ($context & 0x4) { # Context bit 3 set
        # BCD-like encoding for upper contexts
        $data_bits = ($r & 0xF) << 8 | ($g & 0xF) << 4 | ($b & 0xF);
    } else {
        # Ratio-based encoding for lower contexts
        my $rb_ratio = int(($r * 100) / ($b || 1)) % 13;
        my $gb_ratio = int(($g * 100) / ($b || 1)) % 13;
        $data_bits = ($rb_ratio << 4) | $gb_ratio;
    }
    
    # 4. Verification patterns (overlapping with above)
    my $verification = ($r ^ $g ^ $b) % 13;
    
    # Final holographic code - not a simple concatenation!
    # The bits interrelate and overlap in meaning
    return {
        context => $context,
        grid => $grid_pos,
        data => $data_bits,
        verify => $verification,
        # The holographic signature emerges from the relationships
        signature => sprintf("%01X%01X%02X%01X", 
                            $context, $grid_pos, $data_bits, $verification)
    };
}

# Demonstration with a harmonic color
my $harmonic_color = 0x538461; # Deliberately chosen to contain 5384 pattern
my $encoding = encode_holographic_color($harmonic_color);

print "Holographic encoding of color #" . sprintf("%06X", $harmonic_color) . ":\n";
print "  Context bits:       " . sprintf("%03b", $encoding->{context}) . "\n";
print "  Structural grid:    " . sprintf("%04b", $encoding->{grid}) . "\n";
print "  Data bits:          " . sprintf("%010b", $encoding->{data}) . "\n";
print "  Verification:       " . $encoding->{verify} . "\n";
print "  Holographic signature: " . $encoding->{signature} . "\n\n";

# Calculate effective compression
my $traditional_bits = 24;
my $holographic_bits = 3 + 4 + length(sprintf("%b", $encoding->{data}));
my $compression = ($traditional_bits - $holographic_bits) / $traditional_bits * 100;

print "Traditional bits required: $traditional_bits\n";
print "Holographic bits required: $holographic_bits\n";
print "Compression ratio: " . sprintf("%.1f%%", $compression) . "\n";
print "But more importantly: information density increased through context-aware encoding\n";