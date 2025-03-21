#!/usr/bin/perl
# grid_lambda_test.pl - Demonstrate Protocol-7 Grid and Lambda integration

use strict;
use warnings;
use Protocol7::Lambda::Routing;
use Protocol7::Grid::Topology;
use Protocol7::Grid::Routing;
use Data::Dumper;

print "Protocol-7 Grid & Lambda Integration Test\n";
print "----------------------------------------\n\n";

# Initialize components
print "Initializing Lambda Router...\n";
my $lambda_router = Protocol7::Lambda::Routing->new();

print "Initializing Grid Topology...\n";
my $grid = Protocol7::Grid::Topology->new(
    dimensions => 3,
    redundancy_factor => 2,
    lambda_router => $lambda_router
);

print "Initializing Grid Router...\n";
my $router = Protocol7::Grid::Routing->new(
    lambda_router => $lambda_router,
    grid_topology => $grid
);

# Generate test nodes
print "\nGenerating test nodes...\n";
my @nodes;
for my $i (1..20) {
    push @nodes, {
        id => "node_$i",
        key => $lambda_router->{keys}->load_or_create_key("node_$i"),
        capacity => 100,
        ip => "192.168.0.$i",
        port => 9000 + $i
    };
    print "  Created node_$i\n";
}

# Initialize the grid
print "\nInitializing grid with test nodes...\n";
my $init_result = $grid->initialize_grid({
    nodes => \@nodes,
    assignment_strategy => 'balanced'
});

print "Grid initialized with " . $init_result->{positions} . " positions\n";

# Test key to position mapping
print "\nTesting key to position mapping...\n";
my @test_keys = (
    "user_alice",
    "user_bob", 
    "document_123",
    "config_main",
    "media_video_001"
);

foreach my $key (@test_keys) {
    my $position = $router->map_key_to_position($key);
    my $pos_key = $grid->position_to_key($position);
    
    print "  $key -> position $pos_key\n";
    
    # Get node for position
    my $node_result = $grid->get_node_for_position($pos_key);
    
    if ($node_result->{status} ne 'unavailable') {
        print "    Served by: $node_result->{node_id} ($node_result->{status})\n";
        
        # Get alternates
        my $alternates = $grid->{grid}{alternates}{$pos_key} || [];
        if (@$alternates) {
            print "    Alternates: " . join(", ", @$alternates) . "\n";
        }
    }
    else {
        print "    Position unavailable\n";
    }
}

# Test Lambda route creation
print "\nTesting Lambda route creation between nodes...\n";
my $source_node = $nodes[0];
my $dest_node = $nodes[5];

print "Creating route from $source_node->{id} to $dest_node->{id}...\n";
my $route_result = $lambda_router->create_route(
    $source_node->{key},
    $dest_node->{key}
);

if ($route_result->{status} eq 'success') {
    my $route = $route_result->{route};
    print "  Route created successfully:\n";
    print "  ID: $route->{id}\n";
    print "  Forward path: $route->{forward_path}\n";
    print "  Meeting point: $route->{meeting_point}\n";
}
else {
    print "  Route creation failed: $route_result->{error}\n";
}

# Test node failure handling
print "\nTesting node failure handling...\n";
my $failed_node = $nodes[3];
print "Simulating failure of $failed_node->{id}...\n";

my $failure_result = $grid->handle_node_unavailable($failed_node->{id});
print "  Handled node failure: $failure_result->{primary_positions_affected} positions affected\n";

# Test finding nearest neighbor
print "\nTesting nearest neighbor routing...\n";
my $test_key = "document_456";
my $test_position = $router->map_key_to_position($test_key);
my $test_pos_key = $grid->position_to_key($test_position);

print "  $test_key maps to position $test_pos_key\n";

# Simulate this position being unavailable by temporarily removing its nodes
my $original_primary = $grid->{grid}{positions}{$test_pos_key};
my $original_alternates = $grid->{grid}{alternates}{$test_pos_key};

$grid->{grid}{positions}{$test_pos_key} = 'unavailable_node';
$grid->{grid}{alternates}{$test_pos_key} = [];

print "  Simulating position $test_pos_key being unavailable\n";

my $nearest_result = $router->find_nearest_available_position($test_position);

if ($nearest_result->{status} ne 'unavailable') {
    print "  Found nearest available position: $nearest_result->{position}\n";
    print "  Distance from original: $nearest_result->{distance}\n";
    print "  Served by: $nearest_result->{node}{node_id} ($nearest_result->{node}{status})\n";
}
else {
    print "  No available positions found within range\n";
}

# Restore original node assignments
$grid->{grid}{positions}{$test_pos_key} = $original_primary;
$grid->{grid}{alternates}{$test_pos_key} = $original_alternates;

# Show routing statistics
print "\nRouting Statistics:\n";
my $stats = $router->get_routing_stats();
print "  Grid Positions: $stats->{grid_positions}\n";
print "  Active Nodes: $stats->{active_nodes}\n";
print "  Dimensions: $stats->{dimensions}\n";
print "  Redundancy Factor: $stats->{redundancy_factor}\n";
print "  Position Mapping: $stats->{position_mapping}\n";
print "  Fallback Strategy: $stats->{fallback_strategy}\n";

print "\nTest complete.\n";
