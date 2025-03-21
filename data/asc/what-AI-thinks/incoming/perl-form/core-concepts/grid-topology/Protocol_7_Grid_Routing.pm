# Protocol-7 Grid Routing Integration
package Protocol7::Grid::Routing;

use strict;
use warnings;
use Protocol7::Lambda::Routing;
use Protocol7::Grid::Topology;
use Digest::SHA qw(sha256_hex);

# Constructor
sub new {
    my ($class, %params) = @_;
    
    my $self = {
        lambda_router => $params{lambda_router} || Protocol7::Lambda::Routing->new(),
        grid_topology => $params{grid_topology} || Protocol7::Grid::Topology->new(),
        
        config => {
            route_caching => defined $params{route_caching} ? $params{route_caching} : 1,
            position_mapping => $params{position_mapping} || 'consistent_hash',
            fallback_strategy => $params{fallback_strategy} || 'nearest_neighbor',
        },
        
        # Cache for key -> position mappings
        position_cache => {},
    };
    
    bless $self, $class;
    return $self;
}

# Map a key to a grid position
sub map_key_to_position {
    my ($self, $key, $mapping_params) = @_;
    $mapping_params ||= {};
    
    # Check cache first if caching is enabled
    if ($self->{config}{route_caching} && 
        exists $self->{position_cache}{$key} && 
        !($mapping_params->{force_remap} || 0)) {
        return $self->{position_cache}{$key};
    }
    
    my $position;
    my $mapping_strategy = $mapping_params->{strategy} || $self->{config}{position_mapping};
    
    if ($mapping_strategy eq 'consistent_hash') {
        $position = $self->_map_by_consistent_hash($key, $mapping_params);
    }
    elsif ($mapping_strategy eq 'direct_coordinate') {
        $position = $self->_map_by_direct_coordinate($key, $mapping_params);
    }
    else {
        # Default to consistent hash
        $position = $self->_map_by_consistent_hash($key, $mapping_params);
    }
    
    # Cache the mapping if caching is enabled
    if ($self->{config}{route_caching}) {
        $self->{position_cache}{$key} = $position;
    }
    
    return $position;
}

# Map key to position using consistent hashing
sub _map_by_consistent_hash {
    my ($self, $key, $params) = @_;
    
    # Get the number of dimensions in our grid
    my $dimensions = $self->{grid_topology}{config}{dimensions};
    my $max_value = 9; # Single-digit positions
    
    # Generate a hash of the key
    my $hash = sha256_hex($key);
    
    # Extract position components from the hash
    my @position;
    for (my $i = 0; $i < $dimensions; $i++) {
        # Use 4 hex characters (16 bits) per dimension
        my $hex_segment = substr($hash, $i * 4, 4);
        # Convert to integer and modulo to get value in range [0, max_value]
        my $value = hex($hex_segment) % ($max_value + 1);
        push @position, $value;
    }
    
    return \@position;
}

# Map key to position using direct coordinate extraction
sub _map_by_direct_coordinate {
    my ($self, $key, $params) = @_;
    
    # This method would extract coordinates directly from the key
    # if the key has a special format that includes coordinate information
    # For now, we'll implement a simple placeholder that falls back to consistent hash
    
    if ($key =~ /^grid:(\d+)\.(\d+)\.(\d+)/) {
        # Key contains direct coordinate information
        return [$1, $2, $3];
    }
    else {
        # Fall back to consistent hash
        return $self->_map_by_consistent_hash($key, $params);
    }
}

# Route a message to a key
sub route_to_key {
    my ($self, $message, $destination_key, $routing_params) = @_;
    
    # Map the key to a grid position
    my $position = $self->map_key_to_position($destination_key, $routing_params->{mapping_params});
    
    # Route to the position
    return $self->{grid_topology}->route_to_position(
        $message,
        $position,
        $routing_params
    );
}

# Find the nearest available position for a given position
sub find_nearest_available_position {
    my ($self, $position, $params) = @_;
    
    my $pos_key = ref($position) eq 'ARRAY' ? $self->{grid_topology}->position_to_key($position) : $position;
    my $pos_array = ref($position) eq 'ARRAY' ? $position : $self->{grid_topology}->key_to_position($position);
    
    # Check if original position is available
    my $node_result = $self->{grid_topology}->get_node_for_position($pos_key);
    if ($node_result->{status} ne 'unavailable') {
        # Original position is available
        return {
            status => 'original',
            position => $pos_key,
            node => $node_result
        };
    }
    
    # Define search parameters
    my $max_distance = $params->{max_distance} || 5;
    my $dimensions = $self->{grid_topology}{config}{dimensions};
    my $max_value = 9; # Single-digit positions
    
    # Search in expanding "radius" around original position
    for (my $distance = 1; $distance <= $max_distance; $distance++) {
        my @candidates = $self->_generate_positions_at_distance($pos_array, $distance, $dimensions, $max_value);
        
        # Shuffle candidates for load balancing
        @candidates = sort { rand() <=> 0.5 } @candidates;
        
        # Try each candidate
        foreach my $candidate_pos (@candidates) {
            my $candidate_key = $self->{grid_topology}->position_to_key($candidate_pos);
            my $node_result = $self->{grid_topology}->get_node_for_position($candidate_key);
            
            if ($node_result->{status} ne 'unavailable') {
                return {
                    status => 'neighbor',
                    original_position => $pos_key,
                    position => $candidate_key,
                    distance => $distance,
                    node => $node_result
                };
            }
        }
    }
    
    # No available positions found within max_distance
    return {
        status => 'unavailable',
        original_position => $pos_key,
        error => 'no_available_positions_in_range',
        max_distance => $max_distance
    };
}

# Generate positions at a specific Manhattan distance from origin
sub _generate_positions_at_distance {
    my ($self, $origin, $distance, $dimensions, $max_value) = @_;
    
    my @candidates;
    
    # Helper function for recursive candidate generation
    my $generate_candidates = sub {
        my ($current_pos, $dim, $remaining_dist) = @_;
        
        if ($dim >= $dimensions) {
            # We've set all dimensions, check if we're at the target distance
            my $manhattan_dist = 0;
            for (my $i = 0; $i < $dimensions; $i++) {
                $manhattan_dist += abs($current_pos->[$i] - $origin->[$i]);
            }
            
            if ($manhattan_dist == $distance) {
                # This is a valid candidate at our target distance
                push @candidates, [@$current_pos]; # Clone the position
            }
            return;
        }
        
        # Try different values for this dimension
        for (my $val = 0; $val <= $max_value; $val++) {
            my $dim_dist = abs($val - $origin->[$dim]);
            
            # Skip if this would exceed our remaining distance
            next if $dim_dist > $remaining_dist;
            
            # Set this dimension and recurse
            $current_pos->[$dim] = $val;
            $generate_candidates->($current_pos, $dim + 1, $remaining_dist - $dim_dist);
        }
    };
    
    # Start with a copy of the origin
    my @current = @$origin;
    $generate_candidates->(\@current, 0, $distance);
    
    return @candidates;
}

# Route to key with fallback
sub route_to_key_with_fallback {
    my ($self, $message, $destination_key, $routing_params) = @_;
    
    # First try direct routing
    my $route_result = $self->route_to_key($message, $destination_key, $routing_params);
    
    # If successful, return result
    if ($route_result->{status} eq 'routed') {
        return $route_result;
    }
    
    # If not successful and fallbacks are enabled, try fallback
    if ($routing_params->{use_fallback} || $self->{config}{fallback_strategy} ne 'none') {
        my $fallback_strategy = $routing_params->{fallback_strategy} || $self->{config}{fallback_strategy};
        
        if ($fallback_strategy eq 'nearest_neighbor') {
            # Map key to position
            my $position = $self->map_key_to_position(
                $destination_key, 
                $routing_params->{mapping_params}
            );
            
            # Find nearest available position
            my $nearest = $self->find_nearest_available_position(
                $position, 
                $routing_params->{nearest_params}
            );
            
            if ($nearest->{status} ne 'unavailable') {
                # Route to nearest position
                my $fallback_result = $self->{grid_topology}->route_to_position(
                    $message,
                    $nearest->{position},
                    $routing_params
                );
                
                if ($fallback_result->{status} eq 'routed') {
                    return {
                        %$fallback_result,
                        fallback => 'nearest_neighbor',
                        original_position => $position,
                        distance => $nearest->{distance} || 0
                    };
                }
            }
        }
        elsif ($fallback_strategy eq 'replicated_key') {
            # This would implement routing to a replica of the key
            # For now, we'll implement a placeholder
            # ...
        }
    }
    
    # If all fallbacks failed (or weren't enabled), return the original error
    return $route_result;
}

# Handle a node joining the grid
sub handle_node_joining {
    my ($self, $node_data, $join_params) = @_;
    
    # Add the node to the grid topology
    my $add_result = $self->{grid_topology}->add_node($node_data);
    
    if ($add_result->{status} ne 'added') {
        return $add_result;
    }
    
    # If key space rebalancing is needed
    if ($join_params->{rebalance_keys} || 0) {
        $self->rebalance_key_space($node_data->{id}, $join_params->{rebalance_params});
    }
    
    # Clear any relevant cache entries
    if ($self->{config}{route_caching}) {
        # For simplicity, clear the entire cache
        # A more sophisticated implementation would only clear affected entries
        $self->{position_cache} = {};
    }
    
    return {
        status => 'joined',
        node_id => $node_data->{id},
        grid_status => $add_result,
        key_space_rebalanced => $join_params->{rebalance_keys} || 0
    };
}

# Rebalance key space after topology changes
sub rebalance_key_space {
    my ($self, $node_id, $params) = @_;
    
    # This would implement redistribution of keys/data based on
    # the new grid topology. For now, we'll implement a placeholder
    # that just handles position reassignment
    
    # Get the node's grid position(s)
    my $node_data = $self->{grid_topology}{grid}{nodes}{$node_id};
    
    return {
        status => 'rebalanced',
        node_id => $node_id,
        primary_position => $node_data->{primary_position},
        alternate_positions => $node_data->{alternate_positions},
        keys_transferred => 0  # Placeholder
    };
}

# Get routing statistics
sub get_routing_stats {
    my ($self) = @_;
    
    return {
        grid_positions => scalar(keys %{$self->{grid_topology}{grid}{positions}}),
        active_nodes => scalar(keys %{$self->{grid_topology}{grid}{nodes}}),
        position_cache_size => scalar(keys %{$self->{position_cache}}),
        dimensions => $self->{grid_topology}{config}{dimensions},
        redundancy_factor => $self->{grid_topology}{config}{redundancy_factor},
        fallback_strategy => $self->{config}{fallback_strategy},
        position_mapping => $self->{config}{position_mapping},
    };
}

1;
