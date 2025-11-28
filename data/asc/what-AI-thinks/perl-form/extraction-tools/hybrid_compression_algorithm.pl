#!/usr/bin/perl

use v5.24;
use strict;
use warnings;
use Getopt::Long;
use File::Slurp;
use MIME::Base32 qw(encode_base32 decode_base32);
use Encode qw(encode decode);
use Storable qw(store retrieve);

# Perform frequency analysis on the given text
sub frequency_analysis {
    my ($text, $level) = @_;
    my %frequency;

    my @elements;
    if ($level eq 'character') {
        @elements = split(//, $text);
    } elsif ($level eq 'syllable') {
        @elements = split(/(?<=\w\w)/, $text);  # Simplified syllable split
    } elsif ($level eq 'word') {
        @elements = split(/\s+/, $text);
    } elsif ($level eq 'sentence') {
        @elements = split(/(?<=[.!?])\s*/, $text);
    } elsif ($level eq 'paragraph') {
        @elements = split(/\n\n+/, $text);
    }

    for my $element (@elements) {
        $frequency{$element}++;
    }

    return \%frequency;
}

# Assign numerical IDs based on frequency
sub assign_ids {
    my ($frequency, $use_base32, $use_utf7) = @_;
    my %id_map;
    my $id = 1;

    for my $element (sort { $frequency->{$b} <=> $frequency->{$a} } keys %$frequency) {
        my $encoded_id;
        if ($use_utf7) {
            $encoded_id = encode('UTF-7', chr(10000 + $id));
        } elsif ($use_base32) {
            $encoded_id = encode_base32($id);
        } else {
            $encoded_id = $id;
        }
        $id_map{$element} = $encoded_id;
        $id++;
    }

    return \%id_map;
}

# Compress the text using the assigned numerical IDs
sub compress_text {
    my ($text, $id_map, $use_base32, $use_utf7) = @_;
    my @words = split(/\s+/, $text);
    my @compressed;

    for my $word (@words) {
        my $encoded_word = $id_map->{$word} // $word;
        if ($use_base32 && $encoded_word =~ /^\d+$/) {
            $encoded_word = encode_base32($encoded_word);
        } elsif ($use_utf7 && $encoded_word =~ /^\d+$/) {
            $encoded_word = encode('UTF-7', chr(10000 + $encoded_word));
        }
        push @compressed, $encoded_word;
    }

    return join(' ', @compressed);
}

# Expand the compressed text back to its original form
sub expand_text {
    my ($compressed_text, $id_map, $use_base32, $use_utf7) = @_;
    my %reverse_id_map = reverse %$id_map;
    my @words = split(/\s+/, $compressed_text);
    my @expanded;

    for my $word (@words) {
        my $decoded_word;
        if ($use_base32) {
            $decoded_word = decode_base32($word);
        } elsif ($use_utf7) {
            $decoded_word = ord(decode('UTF-7', $word)) - 10000;
        } else {
            $decoded_word = $word;
        }
        push @expanded, $reverse_id_map{$decoded_word} // $word;
    }

    return join(' ', @expanded);
}

# Main script
my $file_name;
my $use_base32 = 0;
my $use_utf7 = 0;
my $level = 'word';

GetOptions(
    'file=s' => \$file_name,
    'base32' => \$use_base32,
    'utf7' => \$use_utf7,
    'level=s' => \$level,
) or die "Usage: $0 --file <file_name> [--base32] [--utf7] [--level <character|syllable|word|sentence|paragraph>]\n";

if (!$file_name) {
    die "Usage: $0 --file <file_name> [--base32] [--utf7] [--level <character|syllable|word|sentence|paragraph>]\n";
}

my $text = read_file($file_name);

# Frequency analysis
my $frequency = frequency_analysis($text, $level);

# Assign numerical IDs
my $id_map = assign_ids($frequency, $use_base32, $use_utf7);

# Compress the text
my $compressed_text = compress_text($text, $id_map, $use_base32, $use_utf7);
say "Compressed Text: $compressed_text";

# Expand the text back to original
my $expanded_text = expand_text($compressed_text, $id_map, $use_base32, $use_utf7);
say "Expanded Text: $expanded_text";
