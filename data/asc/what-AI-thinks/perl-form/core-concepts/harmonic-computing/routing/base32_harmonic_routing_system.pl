#!/usr/bin/env perl
use strict;
use warnings;
use v5.30;

## BASE32 Harmonic Routing with Cubic Space Alignment
## Implements the [3bits][0][3bits][0] pattern with flip resonance

package Base32HarmonicRouter;

## BASE32 alphabet (standard RFC 4648)
my @BASE32_ALPHABET = qw( A B C D E F G H I J K L M N O P Q R S T U V W X Y Z 2 3 4 5 6 7 );
my %BASE32_DECODE;
@BASE32_DECODE{@BASE32_ALPHABET} = (0..31);

## Harmonic Truth Constants (Protocol-7)
use constant TRUE_HARMONIC  => 384615;  # 5/13 repeating
use constant FALSE_HARMONIC => 230769;  # 3/13 repeating

sub new {
    my $class = shift;
    my $self = {
        resonance_memory => {},  # Stores harmonic state pairs
        cubic_alignment  => {},  # 3D space mappings
    };
    return bless $self, $class;
}

## Encode 3-bit octal pattern: [3bits][0][3bits_payload][0]
sub encode_octal_frame {
    my ($self, $prefix_bits, $payload_bits) = @_;

    # Validate 3-bit inputs
    die "prefix must be 3 bits" unless length($prefix_bits) == 3 && $prefix_bits =~ /^[01]+$/;
    die "payload must be 3 bits" unless length($payload_bits) == 3 && $payload_bits =~ /^[01]+$/;

    # Build frame: [3bits][0][3bits][0]
    my $frame = sprintf "%s0%s0", $prefix_bits, $payload_bits;

    # Check if payload is all zeros - triggers flip
    my $all_zeros = ($payload_bits eq '000') ? 1 : 0;

    if ($all_zeros) {
        # Flip all bits: 0->1, 1->0
        $frame =~ tr/01/10/;
    }

    return {
        frame    => $frame,
        flipped  => $all_zeros,
        prefix   => $prefix_bits,
        payload  => $payload_bits,
        octal_p  => oct("0b$prefix_bits"),
        octal_pl => oct("0b$payload_bits"),
    };
}

## Decode octal frame and detect flip state
sub decode_octal_frame {
    my ($self, $frame) = @_;

    die "Invalid frame format" unless $frame =~ /^([01]{3})0([01]{3})0$/;

    my ($prefix, $payload) = ($1, $2);

    # Detect if this was a flipped frame (all 1s in separators)
    my $was_flipped = ($frame =~ /1111/) ? 1 : 0;

    if ($was_flipped) {
        # Unflip: restore original by flipping back
        $frame =~ tr/01/10/;
        $frame =~ /^([01]{3})0([01]{3})0$/;
        ($prefix, $payload) = ($1, $2);
    }

    return {
        prefix     => $prefix,
        payload    => $payload,
        was_flipped => $was_flipped,
        octal_p    => oct("0b$prefix"),
        octal_pl   => oct("0b$payload"),
    };
}

## Create resonant harmonic pair for memory
sub create_resonant_pair {
    my ($self, $state_bits) = @_;

    # Original state
    my $original = $state_bits;

    # Flipped resonant state
    my $resonant = $original;
    $resonant =~ tr/01/10/;

    # Store bidirectional resonance
    $self->{resonance_memory}{$original} = $resonant;
    $self->{resonance_memory}{$resonant} = $original;

    return {
        original => $original,
        resonant => $resonant,
        harmonic => $self->calculate_harmonic($original, $resonant),
    };
}

## Calculate harmonic relationship between states
sub calculate_harmonic {
    my ($self, $state_a, $state_b) = @_;

    # Count bit differences (Hamming distance)
    my $diff = ($state_a ^ $state_b) =~ tr/\001//;

    # Perfect resonance = all bits flipped (complement)
    my $length = length($state_a);
    my $resonance = ($diff == $length) ? TRUE_HARMONIC : FALSE_HARMONIC;

    return {
        hamming_distance => $diff,
        resonance_value  => $resonance,
        perfect_pair     => ($diff == $length),
    };
}

## BASE32 to binary with octal grouping
sub base32_to_octal_groups {
    my ($self, $base32_char) = @_;

    die "Invalid BASE32 character" unless exists $BASE32_DECODE{$base32_char};

    my $value = $BASE32_DECODE{$base32_char};
    my $binary = sprintf "%05b", $value;  # BASE32 = 5 bits

    # Split into 3-bit (octal) + 2-bit (layer info)
    my $octal_part = substr($binary, 0, 3);  # Primary 3 bits
    my $layer_part = substr($binary, 3, 2);  # Secondary 2 bits

    return {
        char        => $base32_char,
        value       => $value,
        binary      => $binary,
        octal_bits  => $octal_part,
        layer_bits  => $layer_part,
        octal_value => oct("0b$octal_part"),
    };
}

## Encode route as sequence of octal frames
sub encode_route {
    my ($self, $route_string) = @_;

    my @frames;
    my @chars = split //, uc($route_string);

    for my $char (@chars) {
        next unless exists $BASE32_DECODE{$char};

        my $b32_data = $self->base32_to_octal_groups($char);

        # Create frame using octal_bits as prefix and layer_bits + 0 as payload
        my $payload = $b32_data->{layer_bits} . '0';  # Pad to 3 bits

        my $frame = $self->encode_octal_frame(
            $b32_data->{octal_bits},
            $payload
        );

        push @frames, {
            char  => $char,
            frame => $frame,
            b32   => $b32_data,
        };
    }

    return \@frames;
}

## Map route to cubic space coordinates
sub map_to_cubic_space {
    my ($self, $frames) = @_;

    my ($x, $y, $z) = (0, 0, 0);
    my @path;

    for my $frame_data (@$frames) {
        my $frame = $frame_data->{frame};
        my $octal_p = $frame->{octal_p};
        my $octal_pl = $frame->{octal_pl};

        # Map octal values to 3D movements
        # 0-7 octal values map to cube vertices
        my $dx = ($octal_p & 0b001) ? 1 : -1;
        my $dy = ($octal_p & 0b010) ? 1 : -1;
        my $dz = ($octal_p & 0b100) ? 1 : -1;

        # Payload modulates movement intensity
        my $scale = ($octal_pl + 1) / 8.0;

        $x += $dx * $scale;
        $y += $dy * $scale;
        $z += $dz * $scale;

        push @path, {
            char     => $frame_data->{char},
            position => [$x, $y, $z],
            frame    => $frame->{frame},
            flipped  => $frame->{flipped},
        };
    }

    $self->{cubic_alignment} = \@path;
    return \@path;
}

## Visualize waveform propagation through cubic space
sub visualize_cubic_waveform {
    my ($self, $path) = @_;

    my @lines;
    push @lines, "## Cubic Space Waveform Propagation ##";
    push @lines, "";

    for my $i (0 .. $#$path) {
        my $p = $path->[$i];
        my ($x, $y, $z) = @{$p->{position}};

        my $flip_marker = $p->{flipped} ? " [FLIPPED]" : "";
        push @lines, sprintf "Step %2d: '%s' -> (%.2f, %.2f, %.2f) %s %s",
            $i, $p->{char}, $x, $y, $z, $p->{frame}, $flip_marker;
    }

    return join("\n", @lines);
}

## Encode with harmonic visualization (comma/dot notation)
sub encode_harmonic_visual {
    my ($self, $binary) = @_;

    # Standard: , = 0, . = 1
    my $visual = $binary;
    $visual =~ s/0/,/g;
    $visual =~ s/1/./g;

    return $visual;
}

## Create AMOS7-style header
sub create_amos7_header {
    my ($self, $amos_chksum, $endline_state, $iterations) = @_;

    # Format: 11 octal digits + 1 bit + 7 octal digits
    my $header_num = sprintf "%011o%o%07o",
        $amos_chksum, $endline_state, $iterations;

    # Check for all zeros (inverted mode)
    my $inverted = ($header_num =~ /^0+$/) ? 1 : 0;

    # Convert each octal digit to 3-bit binary with 0 separators
    my @octal_digits = split //, $header_num;
    my @frames;

    for my $digit (@octal_digits) {
        my $bits = sprintf "%03b", oct($digit);
        push @frames, "$bits";
    }

    # Join with 0 separators
    my $binary_header = '0' . join('0', @frames) . '0';

    # Apply inversion if needed
    if ($inverted) {
        $binary_header =~ tr/01/10/;
    }

    # Convert to visual format
    my $visual = $self->encode_harmonic_visual($binary_header);

    return {
        header_num => $header_num,
        binary     => $binary_header,
        visual     => $visual,
        inverted   => $inverted,
    };
}

1;

## DEMO: Test the system
package main;

my $router = Base32HarmonicRouter->new();

say "=" x 70;
say "## BASE32 HARMONIC ROUTING - Living Tree Integration ##";
say "=" x 70;
say "";

## Test 1: Basic octal frame encoding
say "## Test 1: Octal Frame Encoding ##";
my $frame1 = $router->encode_octal_frame('101', '111');
say "Frame: $frame1->{frame} (prefix: $frame1->{prefix}, payload: $frame1->{payload})";
say "Octal: $frame1->{octal_p},$frame1->{octal_pl}";

my $frame2 = $router->encode_octal_frame('111', '000');
say "Frame with zero payload: $frame2->{frame} [FLIPPED: $frame2->{flipped}]";
say "";

## Test 2: Resonant pairs
say "## Test 2: Resonant Harmonic Pairs ##";
my $pair = $router->create_resonant_pair('101110');
say "Original: $pair->{original}";
say "Resonant: $pair->{resonant}";
say "Perfect pair: " . ($pair->{harmonic}{perfect_pair} ? "YES" : "NO");
say "";

## Test 3: BASE32 route encoding
say "## Test 3: BASE32 Route Encoding ##";
my $route = "BDHJHLS";  # Protocol-7 checksum example
my $frames = $router->encode_route($route);

say "Route: $route";
for my $f (@$frames) {
    say sprintf "  '%s' -> %s (octal: %d,%d) %s",
        $f->{char},
        $f->{frame}{frame},
        $f->{frame}{octal_p},
        $f->{frame}{octal_pl},
        $f->{frame}{flipped} ? "[FLIPPED]" : "";
}
say "";

## Test 4: Cubic space mapping
say "## Test 4: Cubic Space Waveform ##";
my $path = $router->map_to_cubic_space($frames);
say $router->visualize_cubic_waveform($path);
say "";

## Test 5: AMOS7 header
say "## Test 5: AMOS7 Header Encoding ##";
my $header = $router->create_amos7_header(0x1234, 1, 42);
say "Header numeric: $header->{header_num}";
say "Binary: $header->{binary}";
say "Visual: $header->{visual}";
say "";

say "=" x 70;
say "## Living Tree + BASE32 + Harmonic Routing = UNIFIED ##";
say "=" x 70;
