#!/usr/bin/perl

use v5.24;
use strict;
use warnings;
use AMOS7::CHKSUM;

sub generate_checksum {
    my ($input, $reduced_length) = @_;
    my $checksum = AMOS7::CHKSUM::amos_chksum(\$input);
    return $reduced_length ? substr($checksum, 0, 8) : $checksum;
}

sub create_harmonic_frame {
    my ($payload, $rows, $cols, $reduced_length) = @_;
    my @frame;

    for my $i (0 .. $rows - 1) {
        for my $j (0 .. $cols - 1) {
            my $checksum = generate_checksum("$payload-$i-$j", $reduced_length);
            push @{$frame[$i]}, $checksum;
        }
    }

    return \@frame;
}

sub print_frame {
    my ($frame) = @_;
    for my $row (@$frame) {
        say join(' ', @$row);
    }
}

# Example Usage
my $payload = 'HARMONIC_PAYLOAD';
my $rows = 5;
my $cols = 5;
my $reduced_length = 1; # Set to 1 for reduced length, 0 for full length

my $harmonic_frame = create_harmonic_frame($payload, $rows, $cols, $reduced_length);
print_frame($harmonic_frame);
