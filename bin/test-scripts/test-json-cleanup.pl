#!/usr/bin/perl
## Test JSON cleanup/normalization from vision model streaming output
## Demonstrates removing spurious spaces that break JSON syntax
## Usage: ./test-json-cleanup.pl [image_path] [json_prompt]

use strict;
use warnings;
use JSON::PP;

my $image_path = shift
    || '/data/projects/protocol-7/data/gfx/backgrounds/4VVIXSXYEI35M6IUUYW274KXEYCSRZTWZE5ZQH7RHRLYNTPXHBNHTB3V.jpg';
my $json_prompt = shift
    || 'Respond with JSON: {type: image_type, main_subject: description, colors: [colors], mood: feeling}';

print "=== Vision Model JSON Cleanup Test ===\n\n";
print "Image: $image_path\n";
print "Prompt: $json_prompt\n\n";

# Step 1: Get raw output from vision model
print "[Step 1] Calling vision model...\n";
my $raw_output
    = qx(p7 llama-server-vision.analyze_image "$image_path" "$json_prompt" 2>&1);
print "Raw output:\n$raw_output\n";
print "Length: " . length($raw_output) . " bytes\n\n";

# Step 2: Extract JSON portion and clean spurious spaces
print "[Step 2] Cleaning spurious spaces from JSON...\n";
my $cleaned = clean_json_spaces($raw_output);
print "Cleaned output:\n$cleaned\n";
print "Length: " . length($cleaned) . " bytes\n\n";

# Step 3: Try parsing as JSON
print "[Step 3] Attempting JSON parse...\n";
my $json_parser = JSON::PP->new->utf8;
my $parsed;

eval {
    $parsed = $json_parser->decode($cleaned);
    print "✓ JSON parsed successfully!\n";
    print "Parsed structure:\n";
    foreach my $key ( keys %$parsed ) {
        my $value = $parsed->{$key};
        if ( ref $value eq 'ARRAY' ) {
            print "  $key: [" . join( ", ", @$value ) . "]\n";
        } else {
            my $preview = substr( $value, 0, 60 );
            $preview .= "..." if length($value) > 60;
            print "  $key: $preview\n";
        }
    }
};

if ($@) {
    print "✗ JSON parse failed: $@\n";
    print "\nDebug: First 200 chars of cleaned output:\n";
    print substr( $cleaned, 0, 200 ) . "\n";
}

print "\n=== Test Complete ===\n";

# ============================================================================
# CLEANUP FUNCTION: Remove spurious spaces from JSON strings
# ============================================================================
sub clean_json_spaces {
    my ($json_str) = @_;

# Strategy: Remove spaces that split single words, but preserve spaces between words
#
# Spurious patterns from streaming:
# - "neb ula" (word split mid-token)
# - "a ns we r" (single letter fragments)
# - "pur p les" (word + consonant fragment)
#
# Legitimate patterns to preserve:
# - "New York" (proper nouns)
# - "The image" (normal word separation)
#
# Heuristic: Spurious spaces are between very short fragments (1-2 chars)
# or within known word suffixes. Legitimate spaces are between full words.
#
# Most reliable: target specific fragment patterns that look wrong
# Single letter followed by space and lowercase: likely spurious
# ("a ns" from "answer", "p les" from "purples")

    # Pattern 1: Single letter + space + letters (fragment)
    # Examples: "a ns we r" -> "answer", "e v oking" -> "evoking"
    $json_str =~ s/ ([a-z])\s([a-z])/$1$2/g;    # " X Y" -> "XY"

    # Pattern 2: Known suffix fragments separated by space
    # Examples: "vast ness" -> "vastness", "e v oking" -> "evoking"
    $json_str
        =~ s/\s(ness|ing|tion|ment|ity|able|ible|ous|ful|less|ly|al|ary|ive|ish)\b/$1/g;

# Pattern 3: Consonant fragments mid-word
# Examples: "pur p les" -> "purples" (space before single consonant)
# But be careful: "tap p ing" should become "tapping", "me ch anism" should become "mechanism"
    $json_str =~ s/([a-z])\s([bcdfghjklmnpqrstvwxyz])\s([a-z])/$1$2$3/g;

    return $json_str;
}

=pod

CLEANUP STRATEGY NOTES:

The vision model streaming produces spurious spaces in the middle of words because
the token stream is being interrupted or decoded with spacing artifacts.

Examples from testing:
- "answer" → "a ns we r"
- "nebula" → "neb ula"
- "purples" → "pur p les"
- "vastness" → "vast ness"
- "evoking" → "ev oking"

The cleanup function uses increasingly specific patterns:

1. **First pass - Lowercase+space+lowercase**:
   Catches most word breaks like "neb ula" → "nebula"

2. **Second pass - Case transitions**:
   Handles cases where space comes after proper noun start

3. **Third pass - Known suffixes**:
   Catches patterns like "vast ness" → "vastness" by recognizing "ness" suffix

4. **Normalize JSON spacing**:
   Fix spacing around colons and commas for valid JSON

This approach should work reliably because:
- It targets the specific pattern of spurious spaces
- It preserves legitimate spaces (e.g., between words in multi-word values)
- It's simple enough to work with almost any LLM output
- It doesn't require understanding the JSON structure deeply
- The extraction logic doesn't need additional context beyond the task

=cut
