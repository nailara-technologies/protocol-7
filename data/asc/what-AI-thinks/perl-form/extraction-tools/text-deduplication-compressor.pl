#!/usr/bin/perl

use v5.24;
use strict;
use warnings;
use List::Util qw(sum);
use File::Slurp;
use MIME::Base32 qw(encode_base32 decode_base32);
use Getopt::Long;

# Perform frequency analysis on the given text
sub frequency_analysis {
    my ($text) = @_;
    my %frequency;

    # Split text into words
    my @words = split(/\s+/, $text);

    # Count frequency of each word
    for my $word (@words) {
        $frequency{$word}++;
    }

    return \%frequency;
}

# Assign numerical IDs based on word frequency
sub assign_ids {
    my ($frequency, $use_base32) = @_;
    my %id_map;
    my $id = 1;

    # Sort words by frequency (most used first)
    for my $word (sort { $frequency->{$b} <=> $frequency->{$a} } keys %$frequency) {
        my $encoded_id = $use_base32 ? encode_base32($id) : $id;
        $id_map{$word} = $encoded_id;
        $id++;
    }

    return \%id_map;
}

# Compress the text using the assigned numerical IDs
sub compress_text {
    my ($text, $id_map) = @_;
    my @words = split(/\s+/, $text);
    my @compressed;

    for my $word (@words) {
        push @compressed, $id_map->{$word} // $word;
    }

    return join(' ', @compressed);
}

# Expand the compressed text back to its original form
sub expand_text {
    my ($compressed_text, $id_map, $use_base32) = @_;
    my %reverse_id_map = reverse %$id_map;
    my @words = split(/\s+/, $compressed_text);
    my @expanded;

    for my $word (@words) {
        my $decoded_word = $use_base32 ? decode_base32($word) : $word;
        push @expanded, $reverse_id_map{$decoded_word} // $word;
    }

    return join(' ', @expanded);
}

# Main script
my $file_name;
my $use_base32 = 0;

GetOptions(
    'file=s' => \$file_name,
    'base32' => \$use_base32,
) or die "Usage: $0 --file <file_name> [--base32]\n";

if (!$file_name) {
    die "Usage: $0 --file <file_name> [--base32]\n";
}

my $text = read_file($file_name);

# Frequency analysis
my $frequency = frequency_analysis($text);

# Assign numerical IDs
my $id_map = assign_ids($frequency, $use_base32);

# Compress the text
my $compressed_text = compress_text($text, $id_map);
say "Compressed Text: $compressed_text";

# Expand the text back to original
my $expanded_text = expand_text($compressed_text, $id_map, $use_base32);
say "Expanded Text: $expanded_text";