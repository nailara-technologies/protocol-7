#!/usr/bin/perl

use strict;
use warnings;
use File::Slurp;
use Text::GradualUTF7Compressor;

# Main script
my $file_name = shift or die "Usage: $0 <file_name>\n";
my $use_utf7 = 1;
my $level = 'word';

my $text = read_file($file_name);

# Create a GradualUTF7Compressor object
my $compressor = Text::GradualUTF7Compressor->new(use_utf7 => $use_utf7, level => $level);

# Frequency analysis
my $frequency = $compressor->frequency_analysis($text);

# Assign numerical IDs
my $id_map = $compressor->assign_ids($frequency);

# Compress the text
my $compressed_text = $compressor->compress_text($text, $id_map);
print "Compressed Text: $compressed_text\n";

# Expand the text back to original
my $expanded_text = $compressor->expand_text($compressed_text, $id_map);
print "Expanded Text: $expanded_text\n";
