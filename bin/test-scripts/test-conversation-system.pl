#!/usr/bin/perl
use v5.24;
use strict;
use warnings;

## Test conversation management system
## Tests: create, add_turn, get_context, compact operations

my $p7_path = '/data/projects/protocol-7';
chdir $p7_path or die "Cannot chdir to $p7_path: $!";

print "\n=== Testing Conversation System ===\n\n";

## Test 1: Create conversation
print "[TEST 1] Creating conversation...\n";
my $create_cmd = qq[p7 models.conversation_create ];
$create_cmd .= qq['{"job_id":"test_conv_1","token_budget":4096}'];

my $create_output = `$create_cmd 2>&1`;
print "Output:\n$create_output\n";

if ($create_output =~ /success/) {
    print "✓ Conversation created successfully\n\n";
} else {
    print "✗ Failed to create conversation\n\n";
    exit 1;
}

## Test 2: Add turn to conversation
print "[TEST 2] Adding turn to conversation...\n";
my $add_turn_cmd = qq[p7 models.conversation_add_turn ];
$add_turn_cmd .= qq['{"job_id":"test_conv_1","role":"user","content":"Hello"}'];

my $add_output = `$add_turn_cmd 2>&1`;
print "Output:\n$add_output\n";

if ($add_output =~ /success|turn/) {
    print "✓ Turn added successfully\n\n";
} else {
    print "✗ Failed to add turn\n\n";
}

## Test 3: Get conversation context
print "[TEST 3] Retrieving conversation context...\n";
my $get_cmd = qq[p7 models.conversation_get_context ];
$get_cmd .= qq['{"job_id":"test_conv_1"}'];

my $get_output = `$get_cmd 2>&1`;
print "Output:\n$get_output\n";

if ($get_output =~ /success|turns/) {
    print "✓ Context retrieved successfully\n\n";
} else {
    print "✗ Failed to get context\n\n";
}

## Test 4: List conversations
print "[TEST 4] Listing conversations...\n";
my $list_cmd = 'p7 models.conversation_list';

my $list_output = `$list_cmd 2>&1`;
print "Output:\n$list_output\n";

if ($list_output =~ /test_conv/) {
    print "✓ Conversation listed successfully\n\n";
} else {
    print "✗ Failed to list conversations\n\n";
}

## Test 5: Status check
print "[TEST 5] Checking conversation metrics...\n";
my $status_cmd = 'p7 models.conversation_status';

my $status_output = `$status_cmd 2>&1`;
print "Output:\n$status_output\n";

if ($status_output =~ /active|completed/) {
    print "✓ Status retrieved successfully\n\n";
} else {
    print "✗ Failed to get status\n\n";
}

## Test 6: Clear conversation
print "[TEST 6] Clearing conversation...\n";
my $clear_cmd = 'p7 models.conversation_clear test_conv_1';

my $clear_output = `$clear_cmd 2>&1`;
print "Output:\n$clear_output\n";

if ($clear_output =~ /success|cleared/) {
    print "✓ Conversation cleared successfully\n\n";
} else {
    print "✗ Failed to clear conversation\n\n";
}

print "=== Conversation System Tests Complete ===\n\n";

#,,.,,,,.,.,.,,.,,.,,,..,,,,,,,,,,,.,,,,.,,,,,..,,...,...,..,,,,.,,,.,,..,..,,
#MKZMCQQHFV5WW3MII7VHNYKQBWYAOCOFDGMJCBAD4YNQRPFIPLRTJ63WK4R6HIZPGUFDUKXY6NFPO
#\\\|5PPGB3CA6N4TSJDJNWMXZEJOWYDVATDOS4GYLGSFSYS4FIMQQL5 \ / AMOS7 \ YOURUM ::
#\[7]EBZDYBJOGKFS2YANQGXCPWTC3JJS3FJJOB32ESHKLHXLGDCNYMCY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
