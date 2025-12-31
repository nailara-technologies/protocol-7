#!/usr/bin/perl
## Test wrapper for vision-parser.analyze_and_extract
## Provides synchronous interface to async vision-parser by polling job registry
## Usage: ./test-vision-parser.pl <image_path> [vision_prompt] [extraction_prompt]
##
## The vision-parser uses deferred callbacks, so this wrapper:
## 1. Initiates the async analysis
## 2. Polls the coding zenka's job registry for completion
## 3. Returns results synchronously

use strict;
use warnings;
use Time::HiRes qw(sleep time);
use JSON::PP;

# Get arguments
my $image_path = shift
    or die "Usage: $0 <image_path> [vision_prompt] [extraction_prompt]\n";
my $vision_prompt
    = shift || 'Analyze this image and provide structured analysis';
my $extraction_prompt = shift || 'Extract key information';

die "Image file not found: $image_path\n" unless -f $image_path;

print "=== Vision Parser Test Wrapper ===\n";
print "Image: $image_path\n";
print "Vision Prompt: $vision_prompt\n";
print "Extraction Prompt: $extraction_prompt\n\n";

# Step 1: Trigger the async vision analysis
print "[Step 1] Triggering async vision analysis...\n";
my $trigger_cmd
    = sprintf(
    'p7 "coding.vision-parser.analyze_and_extract" -m param image_path="%s" vision_prompt="%s" extraction_prompt="%s" 2>&1',
    $image_path, $vision_prompt, $extraction_prompt );

my $trigger_response = qx($trigger_cmd);
print "Trigger response: $trigger_response\n";

# Step 2: Poll the coding zenka job registry for completion
print "\n[Step 2] Polling job registry for completion...\n";
my $max_wait      = 120;      # Wait up to 2 minutes
my $poll_interval = 0.5;
my $start_time    = time();
my $result        = undef;

while ( time() - $start_time < $max_wait ) {

    # Check job registry via eval-code
    my $poll_cmd
        = 'p7 coding.eval-code \'$jobs = <coding.vision-parser.jobs>; foreach my $jid (keys %$jobs) { $job = $jobs->{$jid}; if ($job->{extraction_result}) { print "$jid: " . substr($job->{extraction_result}, 0, 100) } }\'';

    my $poll_response = qx($poll_cmd 2>&1);

    if ( $poll_response && length($poll_response) > 0 ) {
        print "Found completed job(s):\n$poll_response\n";
        $result = $poll_response;
        last;
    }

    my $elapsed = time() - $start_time;
    printf "\r[%3d/%3d sec] Waiting for completion...", int($elapsed),
        $max_wait;
    sleep($poll_interval);
}

if ($result) {
    print "\n\n[Step 3] Vision analysis complete!\n";
    print "Result preview:\n$result\n";
} else {
    print "\n\n[ERROR] Job did not complete within timeout\n";
    print "Note: Vision analysis is async and may still be processing\n";
    print
        "Check job registry manually with: p7 coding.eval-code '<coding.vision-parser.jobs>'\n";
}

print "\n=== Test Complete ===\n";
