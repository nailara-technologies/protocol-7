#!/usr/bin/perl
## Simple, conservative JSON cleanup - only fix obviously broken patterns
## Test strategy: iteratively refine based on actual observed issues

use strict;
use warnings;
use JSON::PP;

my $image_path = shift
    || '/data/projects/protocol-7/data/gfx/backgrounds/4VVIXSXYEI35M6IUUYW274KXEYCSRZTWZE5ZQH7RHRLYNTPXHBNHTB3V.jpg';
my $prompt = shift || 'Respond with JSON: {type: image_type}';

print "=== Simple JSON Cleanup Test ===\n\n";

# Get raw output
print "[1] Getting raw vision output...\n";
my $raw
    = qx(p7 llama-server-vision.analyze_image "$image_path" "$prompt" 2>&1);
print "Raw length: " . length($raw) . " bytes\n";
print "First 150 chars: " . substr( $raw, 0, 150 ) . "\n\n";

# Conservative cleanup: only remove single-letter + space patterns in JSON keys
# Pattern: space between single letters (likely spurious)
print "[2] Applying conservative cleanup...\n";
my $cleaned = $raw;

# Only target the most obvious: single letters separated by spaces
# "a ns we r" -> "answer" (letter + space + letter pattern repeated)
$cleaned =~ s/([a-z])\s([a-z])([a-z]\s[a-z])*/$1$2$3/g;

# More specific: "a ns we r" pattern
# Match: letter space letter space letter space letter
$cleaned =~ s/([a-z])\s([a-z])\s([a-z])\s([a-z])/$1$2$3$4/g;

# And again for longer sequences
$cleaned =~ s/([a-z])\s([a-z])/$1$2/g if $raw =~ / [a-z] [a-z] [a-z]/;

print "Cleaned length: " . length($cleaned) . " bytes\n";
print "First 150 chars: " . substr( $cleaned, 0, 150 ) . "\n\n";

# Try parsing
print "[3] Attempting JSON parse...\n";
my $parser = JSON::PP->new->utf8->relaxed;
my $result;

eval {
    $result = $parser->decode($cleaned);
    print "✓ Success! Parsed as:\n";
    foreach ( keys %$result ) {
        print "  $_: " . substr( $result->{$_}, 0, 80 ) . "\n";
    }
};

if ($@) {
    print "✗ Parse failed: $@\n";
}

print "\n=== Test Complete ===\n";

#,,,.,.,,,...,,,,,.,,,.,,,..,,...,.,,,,.,,,,,,..,,...,...,.,,,.,.,.,,,,.,,.,.,
#I4ICFSQGXTV2CSOYFRTEIAHQ473ULL7QUZ44YHZT22ZFRMD5UKP63NVXFF466Q6GTI4XHL2JZDYCA
#\\\|OPOIQCT7F4GXM6G6V4E3PYOFVSOH3RZZJ3GC6D6L2GL4WJG4WEN \ / AMOS7 \ YOURUM ::
#\[7]7NXRYA47ABUZN4P7WJCGUND4ODF4RSHLXITZFGGWIZC5XZG3CQBQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
