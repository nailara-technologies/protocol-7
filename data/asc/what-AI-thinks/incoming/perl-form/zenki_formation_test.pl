#!/usr/bin/perl
# zenki_formation_test.pl - Test the Zenki Formation capabilities

use strict;
use warnings;
use Protocol7::Lambda::Routing;
use Protocol7::Grid::Topology;
use Protocol7::Zenki::Formation;
use Protocol7::Zenki::Agent;  # Would need to be implemented
use Data::Dumper;

print "Protocol-7 Zenki Formation Test\n";
print "----------------------------------\n\n";

# Initialize components
print "Initializing Lambda Router...\n";
my $lambda_router = Protocol7::Lambda::Routing->new();

print "Initializing Grid Topology...\n";
my $grid = Protocol7::Grid::Topology->new(
    dimensions => 3,
    redundancy_factor => 2,
    lambda_router => $lambda_router
);

print "Initializing Zenki Formation Manager...\n";
my $formation_manager = Protocol7::Zenki::Formation->new(
    lambda_router => $lambda_router,
    grid_topology => $grid,
    formation_type => 'grid',
    optimal_agents => 9
);

# Define a test mission
my $mission = {
    mission_type => 'data_transfer',
    source => $lambda_router->{keys}->load_or_create_key("source_node"),
    destination => $lambda_router->{keys}->load_or_create_key("destination_node"),
    priority => 'high',
    data_size => 1024 * 1024,  # 1MB
    encryption_required => 1,
    integrity_check => 'sha256'
};

# Create a formation
print "\nCreating Zenki formation for mission...\n";
my $create_result = $formation_manager->create_formation($mission);

print "Formation created with ID: $create_result->{formation_id}\n";
print "Agent count: $create_result->{agent_count}\n";
print "Formation type: $create_result->{formation_type}\n";

# Get the formation
my $formation = $formation_manager->{formations}{$create_result->{formation_id}};

# Deploy the formation
print "\nDeploying formation...\n";
my $deploy_result = $formation_manager->deploy_formation(
    $create_result->{formation_id},
    {
        route_params => {
            include_contingency => 1
        },
        geo_params => {
            strategy => 'route_aligned'
        },
        entropy_params => {
            level => 0.8,
            iterations => 100
        }
    }
);

print "Formation deployed:\n";
print "  Route has " . scalar(@{$deploy_result->{route}{waypoints}}) . " waypoints\n";
print "  Geographic distribution applied\n";

# Show agent distribution
print "\nAgent distribution in formation:\n";
foreach my $agent (@{$formation->{agents}}) {
    my $role = $agent->{role} || 'member';
    my $pos = $agent->{formation_position};
    print "  Agent $agent->{id} ($role) at position [" . 
          sprintf("%.1f, %.1f, %.1f", $pos->{x}, $pos->{y}, $pos->{z}) . "]\n";
}

# Test agent disruption
print "\nSimulating agent disruption...\n";
my $disrupted_agent = $formation->{agents}[3]{id};
print "Disrupting agent: $disrupted_agent\n";

my $disruption_result = $formation_manager->handle_agent_disruption(
    $create_result->{formation_id},
    $disrupted_agent,
    {
        type => 'disconnection',
        permanent => 0
    }
);

print "Disruption handled:\n";
if ($disruption_result->{status} eq 'adjusted') {
    print "  Formation adjusted, " . $disruption_result->{adjustment}{adjustments_made} . 
          " agents repositioned\n";
    print "  Formation integrity: " . sprintf("%.1f%%", $disruption_result->{integrity} * 100) . "\n";
}
elsif ($disruption_result->{status} eq 'recreated') {
    print "  Agent recreated as " . $disruption_result->{new_agent_id} . "\n";
    print "  Recreation strategy: " . $disruption_result->{strategy} . "\n";
    print "  Recreation time: " . $disruption_result->{recreation_time} . " seconds\n";
}

# Simulate permanent agent failure
print "\nSimulating permanent agent failure...\n";
my $failed_agent = $formation->{agents}[5]{id};
print "Agent failure: $failed_agent\n";

my $failure_result = $formation_manager->handle_agent_disruption(
    $create_result->{formation_id},
    $failed_agent,
    {
        type => 'failure',
        permanent => 1,
        recreation_params => {
            strategy => 'distributed'
        }
    }
);

print "Agent failure handled:\n";
if ($failure_result->{status} eq 'recreated') {
    print "  Agent recreated as " . $failure_result->{new_agent_id} . "\n";
    print "  Recreation strategy: " . $failure_result->{strategy} . "\n";
    print "  Recreation time: " . $failure_result->{recreation_time} . " seconds\n";
}

print "\nTest complete.\n";
