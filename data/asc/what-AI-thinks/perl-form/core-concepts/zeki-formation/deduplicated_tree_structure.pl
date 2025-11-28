#!/usr/bin/perl

use v5.24;
use strict;
use warnings;
use Getopt::Long;
use File::Slurp;
use MIME::Base32 qw(encode_base32 decode_base32);
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
    my ($frequency, $use_base32) = @_;
    my %id_map;
    my $id = 1;

    for my $element (sort { $frequency->{$b} <=> $frequency->{$a} } keys %$frequency) {
        my $encoded_id = $use_base32 ? encode_base32($id) : $id;
        $id_map{$element} = $encoded_id;
        $id++;
    }

    return \%id_map;
}

# Build the deduplicated tree structure
sub build_tree {
    my ($text, $id_map, $level) = @_;
    my @elements;
    if ($level eq 'character') {
        @elements = split(//, $text);
    } elsif ($level eq 'syllable') {
        @elements = split(/(?<=\w\w)/, $text);
    } elsif ($level eq 'word') {
        @elements = split(/\s+/, $text);
    } elsif ($level eq 'sentence') {
        @elements = split(/(?<=[.!?])\s*/, $text);
    } elsif ($level eq 'paragraph') {
        @elements = split(/\n\n+/, $text);
    }

    my @tree;
    for my $element (@elements) {
        push @tree, $id_map->{$element};
    }

    return \@tree;
}

# Main script
my $file_name;
my $use_base32 = 0;
my $level = 'word';

GetOptions(
    'file=s' => \$file_name,
    'base32' => \$use_base32,
    'level=s' => \$level,
) or die "Usage: $0 --file <file_name> [--base32] [--level <character|syllable|word|sentence|paragraph>]\n";

if (!$file_name) {
    die "Usage: $0 --file <file_name> [--base32] [--level <character|syllable|word|sentence|paragraph>]\n";
}

my $text = read_file($file_name);

# Frequency analysis
my $frequency = frequency_analysis($text, $level);

# Assign numerical IDs
my $id_map = assign_ids($frequency, $use_base32);

# Build the deduplicated tree
my $tree = build_tree($text, $id_map, $level);

# Save the tree and ID map
store($tree, 'tree.dat');
store($id_map, 'id_map.dat');

say "Deduplicated tree and ID map saved to tree.dat and id_map.dat";
