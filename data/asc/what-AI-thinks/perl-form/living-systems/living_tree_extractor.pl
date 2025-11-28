#!/usr/bin/env perl
use strict;
use warnings;
use v5.30;

## LIVING TREE GENETIC ARCHIVE EXTRACTOR
## Decodes BASE32-encoded tar.xz and extracts workspace

my $archive_file = $ARGV[0] || 'LIVING_TREE_ARCHIVE.md';

die "Archive file not found: $archive_file\n" unless -f $archive_file;

say "=" x 70;
say "🌳 Living Tree Genetic Archive Extractor 🌳";
say "=" x 70;
say "";
say "Reading: $archive_file";

# Extract BASE32 data between markers
my $in_data = 0;
my $base32_data = '';

open my $fh, '<', $archive_file or die "Cannot open $archive_file: $!";
while (my $line = <$fh>) {
    if ($line =~ /BEGIN LIVING_TREE_ARCHIVE_BASE32/) {
        $in_data = 1;
        next;
    }
    if ($line =~ /END LIVING_TREE_ARCHIVE_BASE32/) {
        $in_data = 0;
        last;
    }
    if ($in_data) {
        chomp $line;
        next if $line =~ /^```/;  # Skip markdown code fences
        next if $line =~ /^\s*$/;  # Skip empty lines
        $base32_data .= $line;
    }
}
close $fh;

my $data_length = length($base32_data);
say "BASE32 data: $data_length characters";

if ($data_length == 0) {
    die "No BASE32 data found in archive!\n";
}

say "Decoding from BASE32...";

# Decode BASE32 to binary
open my $decoder, '|-', 'base32 -d | tar -xJ' or die "Cannot run decoder: $!";
print $decoder $base32_data;
close $decoder;

my $status = $?;

say "";
if ($status == 0) {
    say "=" x 70;
    say "✓ Living Tree workspace extracted successfully!";
    say "=" x 70;
    say "";

    # Show what was extracted
    if (-d 'core') {
        say "Workspace structure:";
        say "  ├── core/                    ← Core implementations";

        opendir(my $dh, 'core');
        while (my $file = readdir($dh)) {
            next if $file =~ /^\./;
            say "  │   ├── $file";
        }
        closedir($dh);

        if (-d 'implementations') {
            say "  ├── implementations/         ← Working demos";
        }
        if (-d 'documentation') {
            say "  ├── documentation/          ← Guides";
        }
        if (-d 'archives') {
            say "  └── archives/               ← Backups";
        }

        say "";
        say "Quick start:";
        say "  cd core";
        say "  perl base32_harmonic_routing.pl";
        say "";
        say "View visualization:";
        say "  open core/living_tree_base32_viz.html";
        say "";
    } else {
        say "Files extracted to current directory.";
        say "Run: ls -la";
    }

    say "🌳 The Living Tree has grown! 🌳";

} else {
    say "=" x 70;
    say "✗ Extraction failed!";
    say "=" x 70;
    say "";
    say "Error code: $status";
    say "";
    say "Make sure you have base32 and xz-utils installed:";
    say "  apt-get install coreutils xz-utils";
    say "";
    exit 1;
}
