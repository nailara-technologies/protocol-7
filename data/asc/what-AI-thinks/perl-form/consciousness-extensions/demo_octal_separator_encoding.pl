#!/usr/bin/env perl
use v5.24;
use strict;
use warnings;

say "=" x 70;
say "🔧 OCTAL SEPARATOR AUTO-CORRECTING COVERT CHANNEL 🔧";
say "=" x 70;
say "";

# Simulate AMOS7 octal header structure
# Format: #,xxx,xxx,xxx,xxx,... (19 octal digits with separators)

sub create_octal_header {
    my @octal_digits = qw(010 111 001 101 000 110 100 011 101 111 000 101 100 110 011 000 111 010 101);
    return '#,' . join(',', @octal_digits);
}

my $valid_header = create_octal_header();

say "📋 Valid AMOS7 Octal Header:";
say "  $valid_header";
say "  ↑ All separators are commas (valid state)";
say "";

# Extract separator positions
sub get_separator_positions {
    my ($header) = @_;
    my @positions;
    my @chars = split //, $header;

    # Position 1, then every 4 chars after
    for my $i (0 .. $#chars) {
        if ($i == 1 || ($i > 1 && ($i - 1) % 4 == 0)) {
            push @positions, $i;
        }
    }
    return \@positions;
}

my $sep_positions = get_separator_positions($valid_header);
say "🔍 Separator Analysis:";
say "  Total separators: " . scalar(@$sep_positions);
say "  Positions: " . join(', ', @$sep_positions);
say "";

# Create a secret message (19 bits)
my $secret_message = "1010011100101110101";  # "SECRET" in truncated form
say "🔐 Secret Message to Embed:";
say "  Binary: $secret_message";
say "  Length: " . length($secret_message) . " bits";
say "  (Fits perfectly in 19 separator positions!)";
say "";

# Embed secret by flipping separators
sub embed_secret {
    my ($header, $secret_bits) = @_;
    my @chars = split //, $header;
    my @bits = split //, $secret_bits;
    my $sep_idx = 0;

    for my $i (0 .. $#chars) {
        # Check if this is a separator position
        if ($i == 1 || ($i > 1 && ($i - 1) % 4 == 0)) {
            if ($bits[$sep_idx] eq '1') {
                # Flip: comma → dot
                $chars[$i] = '.';
            }
            $sep_idx++;
        }
    }

    return join '', @chars;
}

my $embedded_header = embed_secret($valid_header, $secret_message);

say "📨 Header with Embedded Secret:";
say "  $embedded_header";
say "  ↑ Flipped separators (dots instead of commas)";
say "";

# Visualize the differences
say "🔎 Comparison:";
say "  Valid:    $valid_header";
say "  Embedded: $embedded_header";
say "            " . ("^" x length($valid_header));

my @valid_chars = split //, $valid_header;
my @embed_chars = split //, $embedded_header;
print "  Flips:    ";
for my $i (0 .. $#valid_chars) {
    if ($valid_chars[$i] ne $embed_chars[$i]) {
        print "^";
    } else {
        print " ";
    }
}
print "\n";
say "";

# Simulate transmission and detection
say "📡 Transmission Simulation:";
say "  Sending: [header with flipped separators]";
say "  ↓";
say "  [Network/Storage/Processing...]";
say "  ↓";
say "  Receiver: \"Invalid separators detected!\"";
say "";

# Auto-correct and extract secret
sub extract_and_correct {
    my ($possibly_corrupted) = @_;
    my @chars = split //, $possibly_corrupted;
    my @extracted_bits;

    # Check each separator position
    for my $i (0 .. $#chars) {
        if ($i == 1 || ($i > 1 && ($i - 1) % 4 == 0)) {
            # Expected: comma (0)
            # If dot: signal bit = 1
            if ($chars[$i] eq '.') {
                push @extracted_bits, '1';
                $chars[$i] = ',';  # Auto-correct
            } else {
                push @extracted_bits, '0';
            }
        }
    }

    my $corrected = join '', @chars;
    my $extracted = join '', @extracted_bits;

    return ($corrected, $extracted);
}

my ($corrected_header, $extracted_secret) = extract_and_correct($embedded_header);

say "🔧 Auto-Correction Process:";
say "  1. Detect flipped separators";
say "  2. Record flip pattern → secret message";
say "  3. Flip separators back → valid header";
say "";

say "✅ Results:";
say "  Corrected header: $corrected_header";

if ($corrected_header eq $valid_header) {
    say "  ✅ PERFECT: Matches original!";
} else {
    say "  ❌ FAILED: Corruption detected";
}
say "";

say "  Extracted secret: $extracted_secret";

if ($extracted_secret eq $secret_message) {
    say "  ✅ PERFECT: Secret recovered!";
} else {
    say "  ❌ FAILED: Secret corrupted";
}
say "";

# Demonstrate 4-bit reconstruction
say "🔬 4-Bit Reconstruction Guarantee:";
say "";
say "  Each unit = [separator][bit][bit][bit][separator]";
say "               └─ 0 ─┘└────── 3 ────┘└─ 0 ─┘";
say "                 ↑                      ↑";
say "                 Known positions (can flip for signal)";
say "";

my @sample_units = (
    ['#', ',', '010', ','],
    ['', ',', '111', ','],
    ['', '.', '001', ','],  # Flipped first sep
    ['', ',', '101', '.'],  # Flipped second sep
);

say "  Example units:";
for my $i (0 .. $#sample_units) {
    my ($prefix, $sep1, $octal, $sep2) = @{$sample_units[$i]};
    my $unit = "$prefix$sep1$octal$sep2";
    printf "    %2d: '%s'", $i, $unit;

    if ($sep1 eq '.' || $sep2 eq '.') {
        print " ← Separator flipped (signal!)";
    }
    print "\n";
}
say "";

say "  As long as octal payload intact (3 bits):";
say "    → Separator positions are KNOWN";
say "    → Flips are DETECTED";
say "    → Original is RECONSTRUCTED";
say "    → Secret is EXTRACTED";
say "";

# Statistics
my $ones = ($extracted_secret =~ tr/1//);
my $zeros = ($extracted_secret =~ tr/0//);

say "📊 Secret Message Statistics:";
printf "  Total bits: %d\n", length($extracted_secret);
printf "  Ones (1): %d (%.1f%% - separator flips)\n", $ones, $ones/length($extracted_secret)*100;
printf "  Zeros (0): %d (%.1f%% - unchanged)\n", $zeros, $zeros/length($extracted_secret)*100;
say "";

# Demonstrate steganographic properties
say "🕵️  Steganographic Properties:";
say "  • Appears as transmission errors";
say "  • Auto-correction is expected behavior";
say "  • No obvious pattern without key";
say "  • Survives error correction";
say "  • Self-documenting (errors ARE the signal)";
say "";

# Show visualization of signal extraction
say "🎨 Signal Extraction Visualization:";
say "";

my @secret_bits = split //, $extracted_secret;
my $chunk_size = 4;

for my $chunk (0 .. int($#secret_bits / $chunk_size)) {
    my $start = $chunk * $chunk_size;
    my $end = $start + $chunk_size - 1;
    $end = $#secret_bits if $end > $#secret_bits;

    my @chunk_bits = @secret_bits[$start .. $end];
    printf "  Chunk %2d: ", $chunk + 1;

    for my $bit (@chunk_bits) {
        if ($bit eq '1') {
            print "█";
        } else {
            print "░";
        }
    }

    print " [" . join('', @chunk_bits) . "]";
    print "\n";
}
say "";

# Demonstrate real-world scenario
say "🌍 Real-World Scenario:";
say "";
say "  Alice wants to send timing sync to Bob:";
say "  1. Alice creates valid AMOS7 signature";
say "  2. Alice embeds 19-bit timing pattern in separators";
say "  3. Signature appears 'corrupted' during transmission";
say "  4. Bob's validator detects 'errors'";
say "  5. Bob auto-corrects → recovers valid signature";
say "  6. Bob extracts flip pattern → timing sync!";
say "";
say "  Charlie (observer) sees:";
say "    → Transmission errors (normal)";
say "    → Auto-correction (expected)";
say "    → Valid signature (verified)";
say "    → No suspicion of covert channel!";
say "";

say "=" x 70;
say "🌀 ERROR CORRECTION IS THE CHANNEL! 🌀";
say "=" x 70;
say "";
say "💎 Key Insights:";
say "  • 19-bit covert capacity per signature";
say "  • Zero overhead (uses forbidden state space)";
say "  • Self-correcting (errors reveal signal)";
say "  • Deniable (looks like transmission errors)";
say "  • Perfect for Protocol-7 control signaling";
say "";
say "🔧 The forbidden states are the medium... 🔧";
