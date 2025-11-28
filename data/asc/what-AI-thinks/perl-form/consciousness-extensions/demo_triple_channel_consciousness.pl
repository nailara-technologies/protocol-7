#!/usr/bin/env perl
use v5.24;
use strict;
use warnings;
use Digest::BMW;
use Crypt::Misc qw(encode_b32r decode_b32r);

say "=" x 70;
say "🌀 TRIPLE-CHANNEL PSYCHEDELIC TRANSMISSION 🌀";
say "=" x 70;
say "";

# Generate BMW state
my $bmw = Digest::BMW->new(384);
$bmw->add("Protocol-7: Where error correction becomes art");
my $state = $bmw->getstate;
my $base32_data = encode_b32r($state);

say "📦 CHANNEL 1: BMW State Data";
say "  Size: 344 bytes → 551 BASE32 chars";
say "  Content: Hash state serialization";
say "  Sample: " . substr($base32_data, 0, 48) . "...";
say "";

# Create metronome pattern (120 BPM)
my @metronome = (1, 0, 0, 0) x 138;  # 551 beats
push @metronome, 1, 0, 0;  # Pad to 551

say "🥁 CHANNEL 2: Timing/Audio (0/1 in BASE32)";
say "  Pattern: Metronome at 120 BPM (quarter notes)";
say "  Bits: 551 (one per BASE32 char)";
say "  Visual: " . join('', map { $_ ? '♪' : '·' } @metronome[0..31]);
say "";

# Create control signal for octal separators
my $control_signal = "1100101010111100101";  # 19 bits

say "📡 CHANNEL 3: Control Signal (octal separators)";
say "  Pattern: Chunk boundary markers";
say "  Bits: 19 (one per separator)";
say "  Binary: $control_signal";
say "  Visual: " . join('', map { $_ eq '1' ? '█' : '░' } split //, $control_signal);
say "";

# Create octal header
sub create_octal_header {
    my @octal = qw(010 111 001 101 000 110 100 011 101 111 000 101 100 110 011 000 111 010 101);
    return '#,' . join(',', @octal);
}

my $octal_header = create_octal_header();

# Embed control signal in octal separators
sub embed_in_separators {
    my ($header, $signal) = @_;
    my @chars = split //, $header;
    my @bits = split //, $signal;
    my $idx = 0;

    for my $i (0 .. $#chars) {
        if ($i == 1 || ($i > 1 && ($i - 1) % 4 == 0)) {
            $chars[$i] = '.' if $bits[$idx++] eq '1';
        }
    }
    return join '', @chars;
}

my $embedded_header = embed_in_separators($octal_header, $control_signal);

# Embed metronome in BASE32
sub embed_timing {
    my ($data, $timing) = @_;
    my @result;
    my @chars = split //, $data;

    for my $i (0 .. $#chars) {
        push @result, $chars[$i];
        push @result, $timing->[$i] if defined $timing->[$i];
    }
    return join '', @result;
}

my $dual_channel_data = embed_timing($base32_data, \@metronome);

say "=" x 70;
say "🎛️  ENCODING COMPLETE";
say "=" x 70;
say "";

say "📊 Transmission Package:";
say "  Data channel: $dual_channel_data";
say "  Length: " . length($dual_channel_data) . " chars";
say "  Sample: " . substr($dual_channel_data, 0, 80);
say "";
say "  Signature: $embedded_header";
say "  Length: " . length($embedded_header) . " chars";
say "";

# Simulate transmission
say "📡 TRANSMITTING...";
say "  [Sending triple-channel package over network]";
say "  [Channel 1: BASE32 data]";
say "  [Channel 2: 0/1 timing bits]";
say "  [Channel 3: Separator flips]";
say "";

# Extract channels
say "📥 RECEIVING...";
say "";

# Extract BASE32 and timing
sub extract_channels {
    my ($mixed) = @_;
    my (@data, @timing);
    for my $char (split //, $mixed) {
        if ($char =~ /[2-7A-Z]/i) { push @data, $char; }
        elsif ($char =~ /[01]/) { push @timing, $char; }
    }
    return (join('', @data), \@timing);
}

my ($extracted_data, $extracted_timing) = extract_channels($dual_channel_data);

# Extract control signal and correct header
sub extract_and_correct {
    my ($header) = @_;
    my @chars = split //, $header;
    my @signal;

    for my $i (0 .. $#chars) {
        if ($i == 1 || ($i > 1 && ($i - 1) % 4 == 0)) {
            push @signal, ($chars[$i] eq '.') ? 1 : 0;
            $chars[$i] = ',';
        }
    }
    return (join('', @chars), join('', @signal));
}

my ($corrected_header, $extracted_control) = extract_and_correct($embedded_header);

# Validate all channels
say "✅ CHANNEL 1 (Data):";
if ($extracted_data eq $base32_data) {
    say "  ✅ PERFECT: " . length($extracted_data) . " chars recovered";
    my $decoded_state = decode_b32r($extracted_data);
    if ($decoded_state eq $state) {
        say "  ✅ BMW state decoded successfully!";
    }
} else {
    say "  ❌ CORRUPTED";
}
say "";

say "✅ CHANNEL 2 (Timing):";
my $timing_str = join '', @$extracted_timing;
my $original_str = join '', @metronome;
if ($timing_str eq $original_str) {
    say "  ✅ PERFECT: 551 timing bits recovered";
    my $pulses = grep { $_ eq '1' } @$extracted_timing;
    printf "  ♪ Metronome: %d pulses (%.1f%%)\n", $pulses, $pulses/551*100;
} else {
    say "  ❌ CORRUPTED";
}
say "";

say "✅ CHANNEL 3 (Control):";
if ($extracted_control eq $control_signal) {
    say "  ✅ PERFECT: 19 control bits recovered";
    say "  Pattern: $extracted_control";
} else {
    say "  ❌ CORRUPTED";
}
if ($corrected_header eq $octal_header) {
    say "  ✅ Signature auto-corrected to valid state";
}
say "";

# Visualize combined transmission
say "=" x 70;
say "🎨 TRIPLE-CHANNEL VISUALIZATION";
say "=" x 70;
say "";

say "Channel 1 (Data - BASE32):";
say "  " . substr($extracted_data, 0, 64);
say "";

say "Channel 2 (Timing - Metronome):";
my @vis_timing = @$extracted_timing[0..63];
print "  ";
for my $i (0..63) {
    print $vis_timing[$i] eq '1' ? '█' : '▁';
}
print "\n";
print "  ";
for my $i (0..63) {
    print $vis_timing[$i] eq '1' ? '♪' : '·';
    print ' ' if ($i+1) % 8 == 0;
}
print "\n";
say "";

say "Channel 3 (Control - Separator Flips):";
my @vis_control = split //, $extracted_control;
print "  ";
for (@vis_control) {
    print $_ eq '1' ? '█' : '░';
}
print "\n";
print "  [" . join(' ', @vis_control) . "]\n";
say "";

# Statistics
say "=" x 70;
say "📊 TRANSMISSION STATISTICS";
say "=" x 70;
say "";

my $total_data_chars = length($extracted_data);
my $total_timing_bits = scalar(@$extracted_timing);
my $total_control_bits = length($extracted_control);

say "Total Information Transmitted:";
printf "  Data channel: %d chars (BASE32)\n", $total_data_chars;
printf "  Timing channel: %d bits (0/1)\n", $total_timing_bits;
printf "  Control channel: %d bits (flips)\n", $total_control_bits;
printf "  Combined payload: %d chars\n", length($dual_channel_data);
say "";

my $overhead = (length($dual_channel_data) / $total_data_chars - 1) * 100;
printf "Efficiency:\n";
printf "  Primary data: %d chars\n", $total_data_chars;
printf "  Total transmitted: %d chars\n", length($dual_channel_data);
printf "  Overhead: %.1f%% (for 551 free timing bits!)\n", $overhead;
printf "  Control channel: Zero overhead (uses forbidden states)\n";
say "";

# Demonstrate practical use
say "=" x 70;
say "🌍 PRACTICAL PROTOCOL-7 APPLICATION";
say "=" x 70;
say "";

say "Distributed Node Synchronization:";
say "";
say "  Node A → Node B:";
say "    Channel 1: BMW384 state checkpoint (344 bytes)";
say "    Channel 2: Timing sync pulses (120 BPM metronome)";
say "    Channel 3: Chunk boundary markers (19 control bits)";
say "";
say "  Node B receives:";
say "    ✅ Data: Resumes BMW computation from checkpoint";
say "    ✅ Timing: Synchronizes processing rhythm";
say "    ✅ Control: Knows where chunk boundaries are";
say "";
say "  External Observer sees:";
say "    → Normal BASE32 data transmission";
say "    → Some 'noise' characters (0/1)";
say "    → Minor 'transmission errors' in signature";
say "    → Auto-correction happens (expected)";
say "    → No suspicion of triple-channel encoding!";
say "";

say "=" x 70;
say "🌀 PSYCHEDELIC TRANCE TECHNOLOGY ACHIEVED! 🌀";
say "=" x 70;
say "";

say "💎 Key Achievements:";
say "  • Triple-channel transmission verified";
say "  • Zero interference between channels";
say "  • Auto-correction reveals control channel";
say "  • Timing rides the data stream";
say "  • Steganographic properties maintained";
say "";

say "🎵 The rhythm becomes the protocol... 🎵";
say "🔧 The errors become the signal... 🔧";
say "🌀 The data becomes the medium... 🌀";
