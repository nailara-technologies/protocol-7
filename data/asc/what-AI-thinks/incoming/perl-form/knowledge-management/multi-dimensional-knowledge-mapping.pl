    return $self->{'topology'};
}

# Calculate manifold structures in the knowledge space
sub calculate_manifolds {
    my ($self) = @_;
    
    # Calculate knowledge surface (2D manifold)
    $self->{'topology'}->{'manifolds'}->{'knowledge_surface'} = $self->calculate_knowledge_surface();
    
    # Calculate concept hyperbolic space (hyperbolic manifold)
    $self->{'topology'}->{'manifolds'}->{'concept_hyperbolic'} = $self->calculate_hyperbolic_space();
    
    # Calculate semantic torus (toroidal manifold)
    $self->{'topology'}->{'manifolds'}->{'semantic_torus'} = $self->calculate_semantic_torus();
    
    return $self->{'topology'}->{'manifolds'};
}

# Calculate a 2D knowledge surface manifold
sub calculate_knowledge_surface {
    my ($self) = @_;
    
    # Create a simplified 2D grid representation of knowledge density
    my $dimensions = ['conceptual', 'structural']; # Use these two dimensions
    my $cells = 20; # 20x20 grid
    my $grid = [];
    
    # Initialize grid
    for my $i (0..$cells-1) {
        $grid->[$i] = [];
        for my $j (0..$cells-1) {
            $grid->[$i]->[$j] = {
                'density' => 0,
                'elements' => []
            };
        }
    }
    
    # Project all elements to these dimensions
    my $projection = $self->project_to_dimensions($dimensions);
    
    # Map elements to grid cells
    foreach my $element_id (keys %$projection) {
        my $coords = $projection->{$element_id};
        
        # Skip if missing either dimension
        next unless exists $coords->{$dimensions->[0]} && exists $coords->{$dimensions->[1]};
        
        # Normalize coordinates to 0-1 range (simplified assumption)
        my $x_norm = ($coords->{$dimensions->[0]} + 1) / 2; # Assuming -1 to 1 range
        my $y_norm = ($coords->{$dimensions->[1]} + 1) / 2;
        
        # Clamp to valid range
        $x_norm = min(1, max(0, $x_norm));
        $y_norm = min(1, max(0, $y_norm));
        
        # Convert to grid indices
        my $x_idx = int($x_norm * ($cells - 1));
        my $y_idx = int($y_norm * ($cells - 1));
        
        # Add to grid cell
        $grid->[$x_idx]->[$y_idx]->{'density'}++;
        push @{$grid->[$x_idx]->[$y_idx]->{'elements'}}, $element_id;
    }
    
    # Calculate additional surface properties
    my $surface = {
        'grid' => $grid,
        'dimensions' => $dimensions,
        'cells' => $cells,
        'properties' => {
            'maximum_density' => 0,
            'average_density' => 0,
            'total_elements' => 0,
            'coverage' => 0
        }
    };
    
    # Calculate surface properties
    my $max_density = 0;
    my $total_density = 0;
    my $occupied_cells = 0;
    
    for my $i (0..$cells-1) {
        for my $j (0..$cells-1) {
            my $density = $grid->[$i]->[$j]->{'density'};
            $max_density = max($max_density, $density);
            $total_density += $density;
            $occupied_cells++ if $density > 0;
        }
    }
    
    $surface->{'properties'}->{'maximum_density'} = $max_density;
    $surface->{'properties'}->{'average_density'} = $total_density / ($cells * $cells);
    $surface->{'properties'}->{'total_elements'} = $total_density;
    $surface->{'properties'}->{'coverage'} = $occupied_cells / ($cells * $cells);
    
    return $surface;
}

# Calculate hyperbolic space for hierarchical concept mapping
sub calculate_hyperbolic_space {
    my ($self) = @_;
    
    # This is a simplified representation of hyperbolic space
    # In a real implementation, this would use proper hyperbolic geometry
    
    # We'll use a Poincaré disc model for hyperbolic space
    my $hyperbolic_space = {
        'nodes' => {},
        'edges' => [],
        'properties' => {
            'radius' => 1.0, # Poincaré disc has radius 1
            'center' => [0, 0],
            'depth_scaling' => 0.8 # How quickly nodes approach the boundary
        }
    };
    
    # Find hierarchical relationships to build the space
    my @hierarchical_types = keys %{$RELATIONSHIP_TYPES->{'hierarchical'}};
    
    # Identify root nodes (those with many incoming hierarchical relationships)
    my %incoming_count;
    
    foreach my $source_id (keys %{$self->{'relationships'}}) {
        foreach my $target_id (keys %{$self->{'relationships'}->{$source_id}}) {
            foreach my $rel (@{$self->{'relationships'}->{$source_id}->{$target_id}}) {
                if (grep { $_ eq $rel->{'type'} } @hierarchical_types) {
                    $incoming_count{$target_id}++;
                }
            }
        }
    }
    
    # Sort by incoming count to find potential roots
    my @potential_roots = sort { $incoming_count{$b} <=> $incoming_count{$a} } 
                         grep { ($incoming_count{$_} || 0) > 0 } 
                         keys %incoming_count;
    
    # Select top nodes as roots (or use arbitrary node if none found)
    my @roots = @potential_roots ? @potential_roots[0..min(2, $#potential_roots)] 
                                 : (keys %{$self->{'elements'}})[0..0];
    
    # Recursively build hyperbolic space from roots
    my $max_depth = 5; # Limit recursion depth
    my %visited;
    
    foreach my $root_id (@roots) {
        $self->place_in_hyperbolic_space($hyperbolic_space, $root_id, [0, 0], 0, $max_depth, \%visited);
    }
    
    return $hyperbolic_space;
}

# Recursively place nodes in hyperbolic space
sub place_in_hyperbolic_space {
    my ($self, $space, $node_id, $parent_pos, $depth, $max_depth, $visited) = @_;
    
    # Skip if already visited or max depth reached
    return if exists $visited->{$node_id} || $depth >= $max_depth;
    $visited->{$node_id} = 1;
    
    # Get element
    my $element = $self->get_element($node_id);
    return unless defined $element;
    
    # Calculate position in hyperbolic space
    my $angle;
    my $distance;
    
    if ($depth == 0) {
        # Root node at center
        $angle = 0;
        $distance = 0;
    } else {
        # Calculate angle based on parent and node_id (for deterministic layout)
        $angle = (unpack("L", substr(pack("H*", md5_hex($parent_pos->[0] . $parent_pos->[1] . $node_id)), 0, 4)) % 360) * 3.14159 / 180;
        
        # Calculate distance from center (increases with depth but bounded by 1)
        $distance = 1 - (1 / (1 + $depth * $space->{'properties'}->{'depth_scaling'}));
    }
    
    # Convert to Cartesian coordinates
    my $x = $distance * cos($angle);
    my $y = $distance * sin($angle);
    
    # Store node position
    $space->{'nodes'}->{$node_id} = {
        'position' => [$x, $y],
        'element' => $element,
        'depth' => $depth
    };
    
    # Create edge from parent if not root
    if ($depth > 0) {
        push @{$space->{'edges'}}, {
            'from' => $parent_pos,
            'to' => [$x, $y],
            'element_from' => $self->get_element($node_id),
            'element_to' => $element
        };
    }
    
    # Find child nodes (outgoing hierarchical relationships)
    my @hierarchical_types = keys %{$RELATIONSHIP_TYPES->{'hierarchical'}};
    my @children;
    
    foreach my $rel (@{$element->{'relationships'}}) {
        if (grep { $_ eq $rel->{'type'} } @hierarchical_types) {
            push @children, $rel->{'target'}->{'id'};
        }
    }
    
    # Recurse for children
    foreach my $child_id (@children) {
        $self->place_in_hyperbolic_space($space, $child_id, [$x, $y], $depth + 1, $max_depth, $visited);
    }
}

# Calculate semantic torus for cyclic knowledge relationships
sub calculate_semantic_torus {
    my ($self) = @_;
    
    # This is a simplified representation of a torus
    # In a real implementation, this would use proper toroidal mapping
    
    # Define torus parameters
    my $torus = {
        'points' => {},
        'cycles' => [],
        'properties' => {
            'major_radius' => 1.0,
            'minor_radius' => 0.3,
            'dimensions' => ['temporal', 'cyclic_relationship']
        }
    };
    
    # Find cyclic relationship patterns
    my @cycles = $self->identify_relationship_cycles();
    
    # Map elements to points on the torus
    foreach my $cycle (@cycles) {
        my @cycle_points;
        my $cycle_length = scalar @$cycle;
        
        # Skip very short cycles
        next if $cycle_length < 3;
        
        # Position each element in the cycle on the torus
        for my $i (0..$#$cycle) {
            my $element_id = $cycle->[$i];
            my $element = $self->get_element($element_id);
            
            # Calculate position on torus
            my $theta = 2 * 3.14159 * $i / $cycle_length; # Angle around major circle
            my $phi = 2 * 3.14159 * ($i % 3) / 3; # Angle around minor circle
            
            # Convert to 3D coordinates on torus
            my $x = ($torus->{'properties'}->{'major_radius'} + $torus->{'properties'}->{'minor_radius'} * cos($phi)) * cos($theta);
            my $y = ($torus->{'properties'}->{'major_radius'} + $torus->{'properties'}->{'minor_radius'} * cos($phi)) * sin($theta);
            my $z = $torus->{'properties'}->{'minor_radius'} * sin($phi);
            
            # Store position
            $torus->{'points'}->{$element_id} = {
                'position' => [$x, $y, $z],
                'element' => $element,
                'cycle_index' => $i,
                'cycle_length' => $cycle_length
            };
            
            push @cycle_points, {
                'element_id' => $element_id,
                'position' => [$x, $y, $z]
            };
        }
        
        # Store the cycle
        push @{$torus->{'cycles'}}, {
            'points' => \@cycle_points,
            'length' => $cycle_length
        };
    }
    
    return $torus;
}

# Identify cycles in relationship graph
sub identify_relationship_cycles {
    my ($self) = @_;
    
    my @cycles;
    my %visited;
    
    # Start depth-first search from each node
    foreach my $start_id (keys %{$self->{'elements'}}) {
        next if exists $visited{$start_id};
        
        my @path = ($start_id);
        my %in_path = ($start_id => 1);
        
        $self->dfs_find_cycles($start_id, \@path, \%in_path, \@cycles, \%visited);
    }
    
    return @cycles;
}

# Depth-first search to find cycles
sub dfs_find_cycles {
    my ($self, $current_id, $path, $in_path, $cycles, $visited) = @_;
    
    # Mark as visited
    $visited->{$current_id} = 1;
    
    # Get current element
    my $current = $self->get_element($current_id);
    return unless defined $current;
    
    # Check each relationship
    foreach my $rel (@{$current->{'relationships'}}) {
        my $next_id = $rel->{'target'}->{'id'};
        
        if (exists $in_path->{$next_id}) {
            # Found a cycle
            
            # Find position of next_id in path
            my $start_idx = 0;
            for my $i (0..$#$path) {
                if ($path->[$i] eq $next_id) {
                    $start_idx = $i;
                    last;
                }
            }
            
            # Extract the cycle
            my @cycle = @$path[$start_idx..$#$path];
            
            # Add to cycles list if not too short
            push @$cycles, \@cycle if @cycle >= 3;
        } elsif (!exists $visited->{$next_id}) {
            # Continue DFS
            push @$path, $next_id;
            $in_path->{$next_id} = 1;
            
            $self->dfs_find_cycles($next_id, $path, $in_path, $cycles, $visited);
            
            # Backtrack
            pop @$path;
            delete $in_path->{$next_id};
        }
    }
}

# Identify singularities in the knowledge space
sub identify_singularities {
    my ($self) = @_;
    
    # Identify knowledge wells (attractors)
    $self->{'topology'}->{'singularities'}->{'knowledge_wells'} = $self->identify_knowledge_wells();
    
    # Identify concept bridges
    $self->{'topology'}->{'singularities'}->{'concept_bridges'} = $self->identify_concept_bridges();
    
    # Identify innovation frontiers
    $self->{'topology'}->{'singularities'}->{'innovation_frontiers'} = $self->identify_innovation_frontiers();
    
    return $self->{'topology'}->{'singularities'};
}

# Identify knowledge wells (attractor points)
sub identify_knowledge_wells {
    my ($self) = @_;
    
    my @wells;
    
    # Count incoming relationships for each element
    my %incoming_count;
    
    foreach my $source_id (keys %{$self->{'relationships'}}) {
        foreach my $target_id (keys %{$self->{'relationships'}->{$source_id}}) {
            foreach my $rel (@{$self->{'relationships'}->{$source_id}->{$target_id}}) {
                $incoming_count{$target_id}++;
            }
        }
    }
    
    # Identify elements with high incoming relationship counts
    my @candidates = sort { $incoming_count{$b} <=> $incoming_count{$a} } 
                    grep { ($incoming_count{$_} || 0) >= 3 } 
                    keys %incoming_count;
    
    # Take top candidates as knowledge wells
    my $max_wells = min(5, scalar @candidates);
    
    for my $i (0..$max_wells-1) {
        my $element_id = $candidates[$i];
        my $element = $self->get_element($element_id);
        
        push @wells, {
            'element' => $element,
            'incoming_count' => $incoming_count{$element_id},
            'gravity' => $incoming_count{$element_id} / 10, # Normalized gravity score
            'position' => { map { $_ => $element->get_coordinate($_) } keys %{$element->{'coordinates'}} }
        };
    }
    
    return \@wells;
}

# Identify concept bridges (connections between distant domains)
sub identify_concept_bridges {
    my ($self) = @_;
    
    my @bridges;
    
    # Calculate betweenness centrality (simplified)
    my %betweenness;
    
    # For each pair of elements, find shortest paths
    my @all_ids = keys %{$self->{'elements'}};
    my @sample_ids = @all_ids > 20 ? (shuffle(@all_ids))[0..19] : @all_ids; # Sample for efficiency
    
    foreach my $source_id (@sample_ids) {
        foreach my $target_id (@sample_ids) {
            next if $source_id eq $target_id;
            
            # Find paths
            my $paths = $self->find_paths($source_id, $target_id, 4); # Limit depth to 4
            
            # Skip if no paths found
            next if !@$paths;
            
            # Count each node on shortest paths
            foreach my $path (@$paths) {
                for my $i (0..$#$path) {
                    my $step = $path->[$i];
                    $betweenness{$step->{'from'}->{'id'}}++;
                    $betweenness{$step->{'to'}->{'id'}}++ if $i == $#$path;
                }
            }
        }
    }
    
    # Normalize betweenness scores
    my $max_betweenness = max(values %betweenness);
    if ($max_betweenness > 0) {
        foreach my $id (keys %betweenness) {
            $betweenness{$id} /= $max_betweenness;
        }
    }
    
    # Identify elements with high betweenness as bridges
    my @bridge_candidates = sort { $betweenness{$b} <=> $betweenness{$a} } 
                          grep { $betweenness{$_} >= 0.5 } 
                          keys %betweenness;
    
    # Take top candidates as concept bridges
    my $max_bridges = min(5, scalar @bridge_candidates);
    
    for my $i (0..$max_bridges-1) {
        my $element_id = $bridge_candidates[$i];
        my $element = $self->get_element($element_id);
        
        push @bridges, {
            'element' => $element,
            'betweenness' => $betweenness{$element_id},
            'position' => { map { $_ => $element->get_coordinate($_) } keys %{$element->{'coordinates'}} }
        };
    }
    
    return \@bridges;
}

# Identify innovation frontiers (boundary areas)
sub identify_innovation_frontiers {
    my ($self) = @_;
    
    my @frontiers;
    
    # Look for elements with few connections that are far from other elements
    my @all_elements = values %{$self->{'elements'}};
    
    # Calculate average coordinates for all elements
    my %sum_coords;
    my %coord_counts;
    
    foreach my $element (@all_elements) {
        foreach my $dim (keys %{$element->{'coordinates'}}) {
            $sum_coords{$dim} += $element->{'coordinates'}->{$dim};
            $coord_counts{$dim}++;
        }
    }
    
    my %avg_coords;
    foreach my $dim (keys %sum_coords) {
        $avg_coords{$dim} = $sum_coords{$dim} / $coord_counts{$dim};
    }
    
    # Calculate distance from average for each element
    my %distances;
    
    foreach my $element (@all_elements) {
        my $sum_squared_diff = 0;
        my $dim_count = 0;
        
        foreach my $dim (keys %avg_coords) {
            if (exists $element->{'coordinates'}->{$dim}) {
                my $diff = $element->{'coordinates'}->{$dim} - $avg_coords{$dim};
                $sum_squared_diff += $diff * $diff;
                $dim_count++;
            }
        }
        
        if ($dim_count > 0) {
            $distances{$element->{'id'}} = sqrt($sum_squared_diff / $dim_count);
        }
    }
    
    # Count relationships for each element
    my %relationship_counts;
    
    foreach my $element (@all_elements) {
        $relationship_counts{$element->{'id'}} = scalar @{$element->{'relationships'}};
    }
    
    # Identify elements that are far from average and have few connections
    my @frontier_candidates;
    
    foreach my $element (@all_elements) {
        my $id = $element->{'id'};
        my $distance = $distances{$id} || 0;
        my $rel_count = $relationship_counts{$id} || 0;
        
        # Score based on distance and inverse of relationship count
        my $frontier_score = $distance * (1.0 / (1.0 + $rel_count));
        
        push @frontier_candidates, {
            'element' => $element,
            'score' => $frontier_score,
            'distance' => $distance,
            'relationship_count' => $rel_count
        };
    }
    
    # Sort by frontier score
    @frontier_candidates = sort { $b->{'score'} <=> $a->{'score'} } @frontier_candidates;
    
    # Take top candidates as frontiers
    my $max_frontiers = min(5, scalar @frontier_candidates);
    
    for my $i (0..$max_frontiers-1) {
        push @frontiers, {
            'element' => $frontier_candidates[$i]->{'element'},
            'score' => $frontier_candidates[$i]->{'score'},
            'distance' => $frontier_candidates[$i]->{'distance'},
            'position' => { 
                map { $_ => $frontier_candidates[$i]->{'element'}->get_coordinate($_) } 
                keys %{$frontier_candidates[$i]->{'element'}->{'coordinates'}} 
            }
        };
    }
    
    return \@frontiers;
}

# Map knowledge flows in the space
sub map_knowledge_flows {
    my ($self) = @_;
    
    # Calculate knowledge currents
    $self->{'topology'}->{'flows'}->{'knowledge_currents'} = $self->calculate_knowledge_currents();
    
    # Calculate concept diffusion
    $self->{'topology'}->{'flows'}->{'concept_diffusion'} = $self->calculate_concept_diffusion();
    
    # Calculate harmonic resonance patterns
    $self->{'topology'}->{'flows'}->{'harmonic_resonance'} = $self->calculate_harmonic_resonance();
    
    return $self->{'topology'}->{'flows'};
}

# Calculate knowledge currents (directional flows)
sub calculate_knowledge_currents {
    my ($self) = @_;
    
    my @currents;
    
    # Look for directional relationships (e.g., transforms_to, derives_from)
    my @directional_types;
    
    foreach my $category (keys %$RELATIONSHIP_TYPES) {
        foreach my $type (keys %{$RELATIONSHIP_TYPES->{$category}}) {
            if ($RELATIONSHIP_TYPES->{$category}->{$type}->{'directionality'} =~ /forward|backward/) {
                push @directional_types, $type;
            }
        }
    }
    
    # Group relationships by direction in each dimension
    my %dimension_flows;
    
    foreach my $source_id (keys %{$self->{'relationships'}}) {
        my $source = $self->get_element($source_id);
        next unless defined $source;
        
        foreach my $target_id (keys %{$self->{'relationships'}->{$source_id}}) {
            my $target = $self->get_element($target_id);
            next unless defined $target;
            
            foreach my $rel (@{$self->{'relationships'}->{$source_id}->{$target_id}}) {
                next unless grep { $_ eq $rel->{'type'} } @directional_types;
                
                # Compare coordinates in each dimension
                foreach my $dim (keys %{$source->{'coordinates'}}) {
                    next unless exists $target->{'coordinates'}->{$dim};
                    
                    my $source_val = $source->{'coordinates'}->{$dim};
                    my $target_val = $target->{'coordinates'}->{$dim};
                    my $direction = $target_val > $source_val ? 'positive' : ($target_val < $source_val ? 'negative' : 'neutral');
                    
                    next if $direction eq 'neutral';
                    
                    # Record flow in this dimension
                    $dimension_flows{$dim} ||= { 'positive' => 0, 'negative' => 0 };
                    $dimension_flows{$dim}->{$direction} += $rel->{'strength'};
                }
            }
        }
    }
    
    # Identify dimensions with strong directional flow
    foreach my $dim (keys %dimension_flows) {
        my $positive = $dimension_flows{$dim}->{'positive'};
        my $negative = $dimension_flows{$dim}->{'negative'};
        my $total = $positive + $negative;
        
        next if $total < 3; # Skip dimensions with too few flows
        
        my $dominant_direction = $positive > $negative ? 'positive' : 'negative';
        my $dominant_flow = max($positive, $negative);
        my $directionality = abs($positive - $negative) / $total;
        
        # Only include if there's a clear directional tendency
        next if $directionality < 0.3;
        
        push @currents, {
            'dimension' => $dim,
            'direction' => $dominant_direction,
            'strength' => $dominant_flow,
            'directionality' => $directionality
        };
    }
    
    # Sort by directionality (strongest first)
    @currents = sort { $b->{'directionality'} <=> $a->{'directionality'} } @currents;
    
    return \@currents;
}

# Calculate concept diffusion patterns
sub calculate_concept_diffusion {
    my ($self) = @_;
    
    # This is a simplified model of concept diffusion
    # A full implementation would use more sophisticated diffusion modeling
    
    my @diffusion_patterns;
    
    # Find elements with many similar/related relationships
    my @elements = values %{$self->{'elements'}};
    
    foreach my $element (@elements) {
        # Count related_to and similar_to relationships
        my @diffusion_rels = grep { 
            $_->{'type'} eq 'related_to' || 
            $_->{'type'} eq 'similar_to' 
        } @{$element->{'relationships'}};
        
        next if @diffusion_rels < 5; # Skip elements with few diffusion relationships
        
        # Calculate diffusion center and radius
        my %center_coords;
        
        # Use element's coordinates as diffusion center
        foreach my $dim (keys %{$element->{'coordinates'}}) {
            $center_coords{$dim} = $element->{'coordinates'}->{$dim};
        }
        
        # Calculate average distance to related elements
        my $total_distance = 0;
        
        foreach my $rel (@diffusion_rels) {
            my $related = $rel->{'target'};
            my $distance = $element->distance_to($related);
            $total_distance += $distance;
        }
        
        my $avg_distance = $total_distance / scalar @diffusion_rels;
        
        # Create diffusion pattern
        push @diffusion_patterns, {
            'center_element' => $element,
            'center_coords' => \%center_coords,
            'radius' => $avg_distance,
            'strength' => scalar @diffusion_rels,
            'related_elements' => [map { $_->{'target'} } @diffusion_rels]
        };
    }
    
    # Sort by strength (strongest first)
    @diffusion_patterns = sort { $b->{'strength'} <=> $a->{'strength'} } @diffusion_patterns;
    
    # Limit to top patterns
    my $max_patterns = min(5, scalar @diffusion_patterns);
    $#diffusion_patterns = $max_patterns - 1 if @diffusion_patterns > $max_patterns;
    
    return \@diffusion_patterns;
}

# Calculate harmonic resonance patterns
sub calculate_harmonic_resonance {
    my ($self) = @_;
    
    my @resonance_patterns;
    
    # Look for harmonic relationship types
    my @harmonic_types = keys %{$RELATIONSHIP_TYPES->{'harmonic'}};
    
    # Identify elements with harmonic relationships
    my %harmonic_connections;
    
    foreach my $source_id (keys %{$self->{'relationships'}}) {
        foreach my $target_id (keys %{$self->{'relationships'}->{$source_id}}) {
            foreach my $rel (@{$self->{'relationships'}->{$source_id}->{$target_id}}) {
                if (grep { $_ eq $rel->{'type'} } @harmonic_types) {
                    $harmonic_connections{$source_id} ||= [];
                    push @{$harmonic_connections{$source_id}}, {
                        'target_id' => $target_id,
                        'type' => $rel->{'type'},
                        'strength' => $rel->{'strength'}
                    };
                }
            }
        }
    }
    
    # Identify resonance networks (groups of mutually resonating elements)
    my %visited;
    
    foreach my $start_id (keys %harmonic_connections) {
        next if exists $visited{$start_id};
        
        # Find connected resonance network
        my @network = $self->find_resonance_network($start_id, \%harmonic_connections, \%visited);
        
        next if @network < 3; # Skip small networks
        
        # Calculate resonance properties
        my %network_elements;
        foreach my $id (@network) {
            $network_elements{$id} = $self->get_element($id);
        }
        
        # Find network center (element with most connections within network)
        my %internal_connection_count;
        foreach my $id (@network) {
            $internal_connection_count{$id} = 0;
            foreach my $conn (@{$harmonic_connections{$id} || []}) {
                $internal_connection_count{$id}++ if exists $network_elements{$conn->{'target_id'}};
            }
        }
        
        my @sorted_ids = sort { $internal_connection_count{$b} <=> $internal_connection_count{$a} } @network;
        my $center_id = $sorted_ids[0];
        my $center_element = $network_elements{$center_id};
        
        # Calculate resonance frequency and amplitude
        my $frequency = @network / 10; # Simple approximation
        my $amplitude = sum(map { $internal_connection_count{$_} } @network) / @network;
        
        # Create resonance pattern
        push @resonance_patterns, {
            'center_element' => $center_element,
            'elements' => \%network_elements,
            'frequency' => $frequency,
            'amplitude' => $amplitude,
            'size' => scalar @network
        };
    }
    
    # Sort by amplitude (strongest first)
    @resonance_patterns = sort { $b->{'amplitude'} <=> $a->{'amplitude'} } @resonance_patterns;
    
    return \@resonance_patterns;
}

# Find connected resonance network using DFS
sub find_resonance_network {
    my ($self, $start_id, $connections, $visited) = @_;
    
    # Mark as visited
    $visited->{$start_id} = 1;
    
    # Initialize with start node
    my @network = ($start_id);
    
    # Check connections
    foreach my $conn (@{$connections->{$start_id} || []}) {
        my $target_id = $conn->{'target_id'};
        
        # Skip if already visited
        next if exists $visited->{$target_id};
        
        # Recursively find connected network
        push @network, $self->find_resonance_network($target_id, $connections, $visited);
    }
    
    return @network;
}

# Calculate topological distance between elements
sub topological_distance {
    my ($self, $element1_id, $element2_id) = @_;
    
    # Get elements
    my $element1 = $self->get_element($element1_id);
    my $element2 = $self->get_element($element2_id);
    
    return undef if !defined $element1 || !defined $element2;
    
    # Try to find paths between elements
    my $paths = $self->find_paths($element1_id, $element2_id, 5);
    
    # If direct paths exist, use shortest path length
    if (@$paths) {
        # Find shortest path
        my $min_length = min(map { scalar @$_ } @$paths);
        return $min_length;
    }
    
    # If no direct path, calculate Euclidean distance in shared dimensions
    my @shared_dims;
    
    foreach my $dim (keys %{$element1->{'coordinates'}}) {
        push @shared_dims, $dim if exists $element2->{'coordinates'}->{$dim};
    }
    
    if (@shared_dims) {
        return $element1->distance_to($element2, \@shared_dims);
    }
    
    # If no shared dimensions, return maximum distance
    return 999;
}

# Fold knowledge space to reduce dimensionality while preserving relationships
sub topological_folding {
    my ($self, $target_dimensions) = @_;
    $target_dimensions ||= 3; # Default to 3D folding
    
    # This is a simplified approximation of topological folding
    # A real implementation would use more sophisticated dimension reduction
    
    # Get all dimensions currently in use
    my %all_dimensions;
    
    foreach my $element (values %{$self->{'elements'}}) {
        foreach my $dim (keys %{$element->{'coordinates'}}) {
            $all_dimensions{$dim}++;
        }
    }
    
    my @dimensions = sort { $all_dimensions{$b} <=> $all_dimensions{$a} } keys %all_dimensions;
    
    # If we already have few enough dimensions, just return coordinates directly
    if (@dimensions <= $target_dimensions) {
        my %folding;
        
        foreach my $element_id (keys %{$self->{'elements'}}) {
            $folding{$element_id} = {};
            
            foreach my $dim (@dimensions) {
                my $value = $self->{'elements'}->{$element_id}->get_coordinate($dim);
                $folding{$element_id}->{$dim} = $value if defined $value;
            }
        }
        
        return {
            'folding' => \%folding,
            'dimensions' => \@dimensions,
            'method' => 'direct'
        };
    }
    
    # Group dimensions into target number of meta-dimensions
    my @meta_dimensions;
    my $dims_per_meta = ceil(@dimensions / $target_dimensions);
    
    for my $i (0..$target_dimensions-1) {
        my $start_idx = $i * $dims_per_meta;
        my $end_idx = min($start_idx + $dims_per_meta - 1, $#dimensions);
        
        push @meta_dimensions, {
            'name' => "meta_" . ($i + 1),
            'components' => [@dimensions[$start_idx..$end_idx]]
        };
    }
    
    # Calculate folded coordinates
    my %folding;
    
    foreach my $element_id (keys %{$self->{'elements'}}) {
        my $element = $self->{'elements'}->{$element_id};
        $folding{$element_id} = {};
        
        foreach my $meta (@meta_dimensions) {
            my $sum = 0;
            my $count = 0;
            
            # Combine component dimensions with weights
            foreach my $dim (@{$meta->{'components'}}) {
                my $value = $element->get_coordinate($dim);
                
                if (defined $value) {
                    # Weight by dimension usage frequency
                    my $weight = $all_dimensions{$dim} / sum(values %all_dimensions);
                    $sum += $value * $weight;
                    $count += $weight;
                }
            }
            
            # Store meta-dimension value
            $folding{$element_id}->{$meta->{'name'}} = $count > 0 ? $sum / $count : 0;
        }
    }
    
    return {
        'folding' => \%folding,
        'meta_dimensions' => \@meta_dimensions,
        'method' => 'folding'
    };
}

# Convert to string representation
sub to_string {
    my ($self) = @_;
    
    my $result = "Knowledge Space: " . $self->{'name'} . "\n";
    $result .= "Dimensions: " . join(", ", @{$self->{'dimensions'}}) . "\n";
    $result .= "Elements: " . $self->{'metadata'}->{'element_count'} . "\n\n";
    
    # List elements
    $result .= "Elements:\n";
    foreach my $element (sort { $a->{'name'} cmp $b->{'name'} } values %{$self->{'elements'}}) {
        $result .= $element->to_string();
        $result .= "---\n";
    }
    
    # Summarize relationships
    my $total_relationships = 0;
    foreach my $source_id (keys %{$self->{'relationships'}}) {
        foreach my $target_id (keys %{$self->{'relationships'}->{$source_id}}) {
            $total_relationships += scalar @{$self->{'relationships'}->{$source_id}->{$target_id}};
        }
    }
    
    $result .= "\nTotal Relationships: $total_relationships\n";
    
    # Summarize topology
    $result .= "\nTopology:\n";
    $result .= "  Manifolds: " . scalar(keys %{$self->{'topology'}->{'manifolds'}}) . "\n";
    $result .= "  Singularities: " . scalar(keys %{$self->{'topology'}->{'singularities'}}) . "\n";
    $result .= "  Flows: " . scalar(keys %{$self->{'topology'}->{'flows'}}) . "\n";
    
    return $result;
}

package main;

# Helper function for MD5 hash (simplified for demonstration)
sub md5_hex {
    my ($string) = @_;
    
    # This is a very simplified stand-in for Digest::MD5::md5_hex
    # In a real implementation, use the actual Digest::MD5 module
    my $hash = 0;
    for my $i (0..length($string)-1) {
        $hash = ($hash * 33) ^ ord(substr($string, $i, 1));
    }
    $hash = sprintf("%08x", $hash & 0xFFFFFFFF);
    
    return $hash;
}

# Helper function for ceiling division
sub ceil {
    my ($n) = @_;
    return int($n) + ($n > int($n) ? 1 : 0);
}

# Function to demonstrate multi-dimensional knowledge mapping
sub demonstrate_knowledge_mapping {
    say "\n=== Demonstrating Multi-Dimensional Knowledge Mapping ===\n";
    
    # Create a knowledge space
    my $space = KnowledgeSpace->new("Concept Framework", 
                                    ['conceptual', 'structural', 'temporal']);
    
    # Add some elements with multi-dimensional coordinates
    my $element1 = KnowledgeElement->new("e1", "Resonance", 
                                       "Concept of harmonic alignment and amplification");
    $element1->set_coordinate('conceptual', 0.8);
    $element1->set_coordinate('structural', 0.5);
    $element1->set_coordinate('temporal', 0.3);
    $space->add_element($element1);
    
    my $element2 = KnowledgeElement->new("e2", "Network Topology", 
                                       "Structure and organization of network elements");
    $element2->set_coordinate('conceptual', 0.6);
    $element2->set_coordinate('structural', 0.9);
    $element2->set_coordinate('temporal', 0.4);
    $space->add_element($element2);
    
    my $element3 = KnowledgeElement->new("e3", "Knowledge Tree", 
                                       "Hierarchical organization of information");
    $element3->set_coordinate('conceptual', 0.4);
    $element3->set_coordinate('structural', 0.7);
    $element3->set_coordinate('temporal', 0.5);
    $space->add_element($element3);
    
    my $element4 = KnowledgeElement->new("e4", "Harmonic Verification", 
                                       "Validation through harmonic principles");
    $element4->set_coordinate('conceptual', 0.7);
    $element4->set_coordinate('structural', 0.6);
    $element4->set_coordinate('temporal', 0.3);
    $space->add_element($element4);
    
    my $element5 = KnowledgeElement->new("e5", "Matrix Reconstruction", 
                                       "Recovery of corrupted data using matrix properties");
    $element5->set_coordinate('conceptual', 0.5);
    $element5->set_coordinate('structural', 0.8);
    $element5->set_coordinate('temporal', 0.6);
    $space->add_element($element5);
    
    # Add relationships between elements
    $space->add_relationship("e1", "e4", "resonates_with", 0.9);
    $space->add_relationship("e2", "e3", "is_a", 0.8);
    $space->add_relationship("e3", "e5", "related_to", 0.7);
    $space->add_relationship("e4", "e1", "harmonic_complement", 0.9);
    $space->add_relationship("e5", "e2", "instance_of", 0.6);
    $space->add_relationship("e1", "e3", "emerges_from", 0.7);
    
    # Display knowledge space
    say "Knowledge Space Structure:";
    say $space->to_string();
    
    # Find similar elements
    my $similar = $space->find_similar_elements("e1");
    
    say "\nElements Similar to 'Resonance':";
    foreach my $item (@$similar) {
        say "  " . $item->{'element'}->{'name'} . " (distance: " . 
            sprintf("%.2f", $item->{'distance'}) . ")";
    }
    
    # Find paths between elements
    my $paths = $space->find_paths("e1", "e5");
    
    say "\nPaths from 'Resonance' to 'Matrix Reconstruction':";
    if (@$paths) {
        for my $i (0..$#$paths) {
            my $path = $paths->[$i];
            say "  Path " . ($i+1) . ":";
            
            foreach my $step (@$path) {
                say "    " . $step->{'from'}->{'name'} . " -> " . 
                    $step->{'to'}->{'name'} . " (" . 
                    $step->{'relationships'}->[0]->{'type'} . ")";
            }
        }
    } else {
        say "  No paths found.";
    }
    
    # Project to 2D for visualization
    my $projection = $space->project_to_dimensions(['conceptual', 'structural']);
    
    say "\nProjection to Conceptual/Structural Dimensions:";
    foreach my $element_id (sort keys %$projection) {
        say "  " . $space->get_element($element_id)->{'name'} . ": (" . 
            sprintf("%.2f", $projection->{$element_id}->{'conceptual'}) . ", " . 
            sprintf("%.2f", $projection->{$element_id}->{'structural'}) . ")";
    }
    
    # Calculate topological features
    my $topology = $space->calculate_topology();
    
    say "\nTopological Features:";
    
    # Manifolds
    if (exists $topology->{'manifolds'}->{'knowledge_surface'}) {
        my $surface = $topology->{'manifolds'}->{'knowledge_surface'};
        say "  Knowledge Surface:";
        say "    Dimensions: " . join(", ", @{$surface->{'dimensions'}});
        say "    Maximum Density: " . $surface->{'properties'}->{'maximum_density'};
        say "    Coverage: " . sprintf("%.2f", $surface->{'properties'}->{'coverage'} * 100) . "%";
    }
    
    # Singularities
    if (exists $topology->{'singularities'}->{'knowledge_wells'}) {
        my $wells = $topology->{'singularities'}->{'knowledge_wells'};
        say "  Knowledge Wells:";
        foreach my $well (@$wells) {
            say "    " . $well->{'element'}->{'name'} . " (gravity: " . 
                sprintf("%.2f", $well->{'gravity'}) . ")";
        }
    }
    
    # Flows
    if (exists $topology->{'flows'}->{'knowledge_currents'}) {
        my $currents = $topology->{'flows'}->{'knowledge_currents'};
        say "  Knowledge Currents:";
        foreach my $current (@$currents) {
            say "    " . $current->{'dimension'} . ": " . 
                $current->{'direction'} . " (strength: " . 
                sprintf("%.2f", $current->{'strength'}) . ")";
        }
    }
    
    # Topological folding
    my $folding = $space->topological_folding(2);
    
    say "\nTopological Folding to 2 Dimensions:";
    say "  Method: " . $folding->{'method'};
    
    if ($folding->{'method'} eq 'folding') {
        say "  Meta-Dimensions:";
        foreach my $meta (@{$folding->{'meta_dimensions'}}) {
            say "    " . $meta->{'name'} . ": " . join(", ", @{$meta->{'components'}});
        }
    } else {
        say "  Dimensions: " . join(", ", @{$folding->{'dimensions'}});
    }
    
    say "  Folded Coordinates:";
    foreach my $element_id (sort keys %{$folding->{'folding'}}) {
        my $coords = $folding->{'folding'}->{$element_id};
        say "    " . $space->get_element($element_id)->{'name'} . ": " . 
            join(", ", map { $_ . "=" . sprintf("%.2f", $coords->{$_}) } sort keys %$coords);
    }
}

# Function to explain multi-dimensional knowledge mapping concepts
sub explain_knowledge_mapping {
    say "\n=== Multi-Dimensional Knowledge Mapping ===\n";
    
    say "A framework for non-hierarchical relationship mappings across knowledge domains,";
    say "enabling complex knowledge organization and navigation across multiple dimensions.";
    
    say "\n--- Knowledge Dimensions ---\n";
    
    say "Primary Dimensions:";
    foreach my $dim (sort keys %{$DIMENSION_CONSTANTS->{'primary_dimensions'}}) {
        say "  $dim: " . $DIMENSION_CONSTANTS->{'primary_dimensions'}->{$dim}->{'description'};
    }
    
    say "\nSecondary Dimensions:";
    foreach my $dim (sort keys %{$DIMENSION_CONSTANTS->{'secondary_dimensions'}}) {
        say "  $dim: " . $DIMENSION_CONSTANTS->{'secondary_dimensions'}->{$dim}->{'description'};
    }
    
    say "\n--- Relationship Types ---\n";
    
    foreach my $category (sort keys %$RELATIONSHIP_TYPES) {
        say ucfirst($category) . " Relationships:";
        foreach my $type (sort keys %{$RELATIONSHIP_TYPES->{$category}}) {
            say "  $type: " . $RELATIONSHIP_TYPES->{$category}->{$type}->{'description'};
        }
        say "";
    }
    
    say "--- Topological Features ---\n";
    
    say "Manifolds:";
    foreach my $manifold (sort keys %{$TOPOLOGICAL_FEATURES->{'manifolds'}}) {
        say "  $manifold: " . $TOPOLOGICAL_FEATURES->{'manifolds'}->{$manifold}->{'description'};
    }
    
    say "\nSingularities:";
    foreach my $singularity (sort keys %{$TOPOLOGICAL_FEATURES->{'singularities'}}) {
        say "  $singularity: " . $TOPOLOGICAL_FEATURES->{'singularities'}->{$singularity}->{'description'};
    }
    
    say "\nFlows:";
    foreach my $flow (sort keys %{$TOPOLOGICAL_FEATURES->{'flows'}}) {
        say "  $flow: " . $TOPOLOGICAL_FEATURES->{'flows'}->{$flow}->{'description'};
    }
    
    say "\n--- Projection Settings ---\n";
    
    say "Visualization Modes:";
    foreach my $mode (sort keys %{$PROJECTION_SETTINGS->{'visualization_modes'}}) {
        say "  $mode: " . $PROJECTION_SETTINGS->{'visualization_modes'}->{$mode}->{'description'};
    }
}

# Main function
if (!caller) {
    explain_knowledge_mapping();
    demonstrate_knowledge_mapping();
}

__END__

=head1 Multi-Dimensional Knowledge Mapping

=head2 Key Concepts

=over

=item * Non-hierarchical representation of knowledge across multiple conceptual dimensions

=item * Rich relationship types that capture various forms of connection between knowledge elements

=item * Topological features including manifolds, singularities, and flows that emerge from knowledge structure

=item * Dimensional projection techniques for visualizing complex multi-dimensional relationships

=item * Harmonic resonance principles applied to knowledge organization and retrieval

=item * Topological folding to reduce dimensionality while preserving relationship integrity

=back

=head2 Practical Applications

=over

=item * Complex knowledge organization beyond traditional hierarchical structures

=item * Visualization of relationships between concepts across multiple dimensions

=item * Discovery of non-obvious connections through topological analysis

=item * Navigation of knowledge spaces through dimensional exploration

=item * Identification of knowledge patterns, currents, and emerging frontiers

=item * Resonant information retrieval based on harmonic principles

=back

=cut#!/usr/bin/perl
use v5.24;
use strict;
use warnings;
use List::Util qw(max min sum shuffle);
use Math::Complex; # For hyperbolic functions

# Multi-Dimensional Knowledge Mapping
# Framework for non-hierarchical relationship mappings across knowledge domains
# ----------------------------------------------------------------------------

# Knowledge dimension constants
my $DIMENSION_CONSTANTS = {
    'primary_dimensions' => {
        'conceptual' => {
            'description' => 'Abstract to concrete spectrum of knowledge representation',
            'axis_labels' => ['Abstract', 'Theoretical', 'Applied', 'Concrete']
        },
        'structural' => {
            'description' => 'Organization and relationship patterns between knowledge elements',
            'axis_labels' => ['Atomic', 'Compositional', 'Networked', 'Holistic']
        },
        'temporal' => {
            'description' => 'Evolution and transformation of knowledge over time',
            'axis_labels' => ['Foundational', 'Established', 'Emergent', 'Speculative']
        }
    },
    'secondary_dimensions' => {
        'certainty' => {
            'description' => 'Confidence level and verification status of knowledge',
            'axis_labels' => ['Verified', 'Supported', 'Plausible', 'Hypothetical']
        },
        'complexity' => {
            'description' => 'Intricacy and interconnectedness of knowledge elements',
            'axis_labels' => ['Elementary', 'Composite', 'Complex', 'Emergent']
        },
        'applicability' => {
            'description' => 'Scope and domain range where knowledge applies',
            'axis_labels' => ['Universal', 'Domain-specific', 'Context-dependent', 'Unique']
        }
    },
    'meta_dimensions' => {
        'entropic_direction' => {
            'description' => 'Tendency toward order or disorder in knowledge structure',
            'axis_labels' => ['Anti-entropic', 'Stable', 'Neutral', 'Entropic']
        },
        'harmonic_resonance' => {
            'description' => 'Alignment with harmonic principles and patterns',
            'axis_labels' => ['Resonant', 'Harmonically-aligned', 'Neutral', 'Dissonant']
        }
    },
    'dimensional_weights' => {
        'primary' => 1.0,
        'secondary' => 0.7,
        'meta' => 0.5
    }
};

# Relationship types between knowledge elements
my $RELATIONSHIP_TYPES = {
    'hierarchical' => {
        'is_a' => {
            'description' => 'Taxonomic relationship indicating type or category membership',
            'examples' => ['X is a type of Y', 'X belongs to category Y'],
            'directionality' => 'upward',
            'transitivity' => 1,
            'weight' => 1.0
        },
        'part_of' => {
            'description' => 'Meronymic relationship indicating composition or containment',
            'examples' => ['X is part of Y', 'X is a component of Y'],
            'directionality' => 'upward',
            'transitivity' => 1,
            'weight' => 0.9
        },
        'instance_of' => {
            'description' => 'Relationship indicating a specific example or occurrence',
            'examples' => ['X is an instance of Y', 'X exemplifies Y'],
            'directionality' => 'upward',
            'transitivity' => 0,
            'weight' => 0.8
        }
    },
    'associative' => {
        'related_to' => {
            'description' => 'General relationship indicating conceptual connection',
            'examples' => ['X is related to Y', 'X has connection with Y'],
            'directionality' => 'bidirectional',
            'transitivity' => 0,
            'weight' => 0.6
        },
        'similar_to' => {
            'description' => 'Relationship indicating resemblance or shared properties',
            'examples' => ['X is similar to Y', 'X resembles Y'],
            'directionality' => 'bidirectional',
            'transitivity' => 0,
            'weight' => 0.7
        },
        'contrasts_with' => {
            'description' => 'Relationship indicating opposition or distinction',
            'examples' => ['X contrasts with Y', 'X is opposite to Y'],
            'directionality' => 'bidirectional',
            'transitivity' => 0,
            'weight' => 0.5
        }
    },
    'transformative' => {
        'transforms_to' => {
            'description' => 'Relationship indicating evolution or metamorphosis',
            'examples' => ['X transforms into Y', 'X evolves to Y'],
            'directionality' => 'forward',
            'transitivity' => 1,
            'weight' => 0.8
        },
        'derives_from' => {
            'description' => 'Relationship indicating origin or derivation',
            'examples' => ['X derives from Y', 'X originates from Y'],
            'directionality' => 'backward',
            'transitivity' => 0,
            'weight' => 0.7
        },
        'emerges_from' => {
            'description' => 'Relationship indicating emergence of higher-order patterns',
            'examples' => ['X emerges from Y', 'X arises from Y'],
            'directionality' => 'upward',
            'transitivity' => 0,
            'weight' => 0.9
        }
    },
    'harmonic' => {
        'resonates_with' => {
            'description' => 'Relationship indicating harmonic alignment or amplification',
            'examples' => ['X resonates with Y', 'X amplifies Y'],
            'directionality' => 'bidirectional',
            'transitivity' => 0,
            'weight' => 0.8
        },
        'harmonic_complement' => {
            'description' => 'Relationship indicating complementary harmonic patterns',
            'examples' => ['X complements Y', 'X and Y form harmonic pair'],
            'directionality' => 'bidirectional',
            'transitivity' => 0,
            'weight' => 0.9
        },
        'frequency_harmonic' => {
            'description' => 'Relationship indicating mathematical harmonic relationship',
            'examples' => ['X is a harmonic of Y', 'X has frequency relationship with Y'],
            'directionality' => 'bidirectional',
            'transitivity' => 1,
            'weight' => 1.0
        }
    }
};

# Topological features for knowledge spaces
my $TOPOLOGICAL_FEATURES = {
    'manifolds' => {
        'knowledge_surface' => {
            'description' => 'Two-dimensional representation of knowledge proximity',
            'properties' => ['continuous', 'differentiable', 'locally_euclidean'],
            'visualization' => 'surface_plot'
        },
        'concept_hyperbolic' => {
            'description' => 'Hyperbolic space for representing hierarchical structures',
            'properties' => ['negative_curvature', 'tree_embedding', 'distance_compression'],
            'visualization' => 'hyperbolic_disc'
        },
        'semantic_torus' => {
            'description' => 'Toroidal space for cyclic or recurrent knowledge patterns',
            'properties' => ['periodic_boundary', 'cyclic_paths', 'global_connectivity'],
            'visualization' => 'torus_projection'
        }
    },
    'singularities' => {
        'knowledge_well' => {
            'description' => 'Attractors that draw related concepts toward fundamental principles',
            'properties' => ['high_gravity', 'convergent', 'foundational'],
            'visualization' => 'gravity_well'
        },
        'concept_bridge' => {
            'description' => 'Narrow connections between otherwise distant knowledge domains',
            'properties' => ['high_betweenness', 'interdisciplinary', 'connective'],
            'visualization' => 'bridge_highlight'
        },
        'innovation_frontier' => {
            'description' => 'Expanding boundaries where new knowledge emerges',
            'properties' => ['high_gradient', 'sparse', 'generative'],
            'visualization' => 'boundary_glow'
        }
    },
    'flows' => {
        'knowledge_current' => {
            'description' => 'Directional tendencies in knowledge exploration and growth',
            'properties' => ['directional', 'momentum', 'channeling'],
            'visualization' => 'flow_arrows'
        },
        'concept_diffusion' => {
            'description' => 'Spread of ideas across domains and contexts',
            'properties' => ['gradient_driven', 'decreasing_density', 'context_sensitive'],
            'visualization' => 'diffusion_cloud'
        },
        'harmonic_resonance' => {
            'description' => 'Amplification patterns through mutual reinforcement',
            'properties' => ['oscillatory', 'amplifying', 'frequency_dependent'],
            'visualization' => 'wave_interference'
        }
    }
};

# Dimensional projection settings
my $PROJECTION_SETTINGS = {
    'visualization_modes' => {
        '2d_plane' => {
            'dimensions' => 2,
            'description' => 'Flat projection optimized for clarity and navigation',
            'use_cases' => ['overview', 'browsing', 'basic_relationships']
        },
        '3d_space' => {
            'dimensions' => 3,
            'description' => 'Volumetric representation showing additional relationship depth',
            'use_cases' => ['detailed_exploration', 'cluster_analysis', 'relation_networks']
        },
        'hyperbolic_disc' => {
            'dimensions' => 2,
            'description' => 'Non-Euclidean representation for hierarchical structures',
            'use_cases' => ['hierarchy_visualization', 'focus_and_context', 'tree_structures']
        },
        'force_directed' => {
            'dimensions' => 2,
            'description' => 'Dynamic layout based on attractive and repulsive forces',
            'use_cases' => ['relationship_strength', 'clustering', 'network_analysis']
        }
    },
    'projection_algorithms' => {
        't_sne' => {
            'description' => 't-Distributed Stochastic Neighbor Embedding for dimension reduction',
            'strengths' => ['local_structure_preservation', 'cluster_visualization'],
            'weaknesses' => ['global_structure_loss', 'non_deterministic']
        },
        'umap' => {
            'description' => 'Uniform Manifold Approximation and Projection',
            'strengths' => ['preserves_global_structure', 'faster_than_t_sne', 'theoretical_foundation'],
            'weaknesses' => ['parameter_sensitivity', 'complexity']
        },
        'pca' => {
            'description' => 'Principal Component Analysis for linear dimension reduction',
            'strengths' => ['simplicity', 'interpretability', 'deterministic'],
            'weaknesses' => ['linear_only', 'misses_non_linear_relationships']
        },
        'harmonic_projection' => {
            'description' => 'Custom projection based on harmonic resonance principles',
            'strengths' => ['preserves_resonant_relationships', 'anti_entropic_properties'],
            'weaknesses' => ['domain_specific', 'computationally_intensive']
        }
    },
    'interaction_modes' => {
        'zoom_and_pan' => {
            'description' => 'Navigate knowledge space through scaling and translation',
            'interface_elements' => ['zoom_slider', 'pan_controls', 'mouse_drag']
        },
        'dimension_slicing' => {
            'description' => 'Explore cross-sections of higher dimensional knowledge space',
            'interface_elements' => ['dimension_selectors', 'slice_thickness', 'plane_orientation']
        },
        'relationship_filtering' => {
            'description' => 'Show or hide relationships based on type, strength, or relevance',
            'interface_elements' => ['relationship_toggles', 'strength_threshold', 'relevance_slider']
        },
        'focal_point' => {
            'description' => 'Center visualization around specific concept with contextual relevance',
            'interface_elements' => ['search_box', 'focus_lock', 'context_radius']
        }
    }
};

# Knowledge element with multi-dimensional coordinates
package KnowledgeElement;

sub new {
    my ($class, $id, $name, $content, $coordinates) = @_;
    
    my $self = {
        'id' => $id,
        'name' => $name,
        'content' => $content || '',
        'coordinates' => $coordinates || {},
        'relationships' => [],
        'metadata' => {
            'created' => time(),
            'accessed' => time(),
            'modified' => time(),
            'access_count' => 0
        }
    };
    
    return bless $self, $class;
}

# Add a relationship to another knowledge element
sub add_relationship {
    my ($self, $target, $relationship_type, $strength) = @_;
    $strength ||= 1.0;
    
    # Add the relationship
    push @{$self->{'relationships'}}, {
        'target' => $target,
        'type' => $relationship_type,
        'strength' => $strength,
        'created' => time()
    };
    
    # Update metadata
    $self->{'metadata'}->{'modified'} = time();
    
    return $self;
}

# Get all relationships of a specific type
sub get_relationships_by_type {
    my ($self, $type) = @_;
    
    return grep { $_->{'type'} eq $type } @{$self->{'relationships'}};
}

# Get coordinate value for a specific dimension
sub get_coordinate {
    my ($self, $dimension) = @_;
    
    return $self->{'coordinates'}->{$dimension} if exists $self->{'coordinates'}->{$dimension};
    return undef;
}

# Set coordinate value for a specific dimension
sub set_coordinate {
    my ($self, $dimension, $value) = @_;
    
    $self->{'coordinates'}->{$dimension} = $value;
    $self->{'metadata'}->{'modified'} = time();
    
    return $self;
}

# Calculate dimensional distance to another element
sub distance_to {
    my ($self, $other, $dimensions) = @_;
    
    # If no dimensions specified, use all shared dimensions
    if (!defined $dimensions) {
        my %self_dims = map { $_ => 1 } keys %{$self->{'coordinates'}};
        my %other_dims = map { $_ => 1 } keys %{$other->{'coordinates'}};
        $dimensions = [grep { exists $other_dims{$_} } keys %self_dims];
    }
    
    # Calculate Euclidean distance in specified dimensions
    my $sum_squares = 0;
    foreach my $dim (@$dimensions) {
        next unless exists $self->{'coordinates'}->{$dim} && exists $other->{'coordinates'}->{$dim};
        my $diff = $self->{'coordinates'}->{$dim} - $other->{'coordinates'}->{$dim};
        $sum_squares += $diff * $diff;
    }
    
    return sqrt($sum_squares);
}

# Access the element (update access stats)
sub access {
    my ($self) = @_;
    
    $self->{'metadata'}->{'accessed'} = time();
    $self->{'metadata'}->{'access_count'}++;
    
    return $self;
}

# Convert to string representation
sub to_string {
    my ($self) = @_;
    
    my $result = $self->{'name'} . " (ID: " . $self->{'id'} . ")\n";
    
    # Add coordinates
    $result .= "  Coordinates:\n";
    foreach my $dim (sort keys %{$self->{'coordinates'}}) {
        $result .= "    $dim: " . sprintf("%.2f", $self->{'coordinates'}->{$dim}) . "\n";
    }
    
    # Add relationships
    $result .= "  Relationships:\n";
    foreach my $rel (@{$self->{'relationships'}}) {
        $result .= "    " . $rel->{'type'} . " -> " . $rel->{'target'}->{'name'} . 
                   " (strength: " . sprintf("%.2f", $rel->{'strength'}) . ")\n";
    }
    
    # Add content preview if available
    if (length($self->{'content'}) > 0) {
        my $preview = substr($self->{'content'}, 0, 50);
        $preview .= "..." if length($self->{'content'}) > 50;
        $result .= "  Content: $preview\n";
    }
    
    return $result;
}

# Multi-dimensional knowledge space
package KnowledgeSpace;

sub new {
    my ($class, $name, $dimensions) = @_;
    $name ||= 'Knowledge Space';
    $dimensions ||= ['conceptual', 'structural', 'temporal'];
    
    my $self = {
        'name' => $name,
        'dimensions' => $dimensions,
        'elements' => {},
        'relationships' => {},
        'topology' => {
            'manifolds' => {},
            'singularities' => {},
            'flows' => {}
        },
        'metadata' => {
            'created' => time(),
            'accessed' => time(),
            'modified' => time(),
            'element_count' => 0
        }
    };
    
    return bless $self, $class;
}

# Add a knowledge element to the space
sub add_element {
    my ($self, $element) = @_;
    
    # Store element by ID
    $self->{'elements'}->{$element->{'id'}} = $element;
    
    # Update metadata
    $self->{'metadata'}->{'modified'} = time();
    $self->{'metadata'}->{'element_count'}++;
    
    return $element;
}

# Get element by ID
sub get_element {
    my ($self, $id) = @_;
    
    return $self->{'elements'}->{$id} if exists $self->{'elements'}->{$id};
    return undef;
}

# Add a relationship between elements
sub add_relationship {
    my ($self, $source_id, $target_id, $relationship_type, $strength) = @_;
    $strength ||= 1.0;
    
    # Get elements
    my $source = $self->get_element($source_id);
    my $target = $self->get_element($target_id);
    
    # Verify both elements exist
    return undef if !defined $source || !defined $target;
    
    # Add relationship to source element
    $source->add_relationship($target, $relationship_type, $strength);
    
    # Store relationship in space
    $self->{'relationships'}->{$source_id} ||= {};
    $self->{'relationships'}->{$source_id}->{$target_id} ||= [];
    
    push @{$self->{'relationships'}->{$source_id}->{$target_id}}, {
        'type' => $relationship_type,
        'strength' => $strength,
        'created' => time()
    };
    
    # Update metadata
    $self->{'metadata'}->{'modified'} = time();
    
    return 1;
}

# Find all elements within a dimensional range
sub find_elements_in_range {
    my ($self, $center_coords, $radius, $dimensions) = @_;
    $dimensions ||= $self->{'dimensions'};
    
    my @results;
    
    # Check each element
    foreach my $element (values %{$self->{'elements'}}) {
        my $distance = 0;
        my $dimension_count = 0;
        
        # Calculate distance in each specified dimension
        foreach my $dim (@$dimensions) {
            next unless exists $center_coords->{$dim} && exists $element->{'coordinates'}->{$dim};
            
            my $diff = $center_coords->{$dim} - $element->{'coordinates'}->{$dim};
            $distance += $diff * $diff;
            $dimension_count++;
        }
        
        # Skip if no matching dimensions
        next if $dimension_count == 0;
        
        # Normalize distance by dimension count
        $distance = sqrt($distance);
        
        # Add to results if within radius
        push @results, {
            'element' => $element,
            'distance' => $distance
        } if $distance <= $radius;
    }
    
    # Sort by distance (closest first)
    @results = sort { $a->{'distance'} <=> $b->{'distance'} } @results;
    
    return \@results;
}

# Find elements with similar coordinates
sub find_similar_elements {
    my ($self, $element_id, $dimensions, $limit) = @_;
    $dimensions ||= $self->{'dimensions'};
    $limit ||= 10;
    
    # Get reference element
    my $element = $self->get_element($element_id);
    return [] if !defined $element;
    
    # Extract coordinates for reference element
    my %coords;
    foreach my $dim (@$dimensions) {
        $coords{$dim} = $element->get_coordinate($dim) if defined $element->get_coordinate($dim);
    }
    
    # Find elements in range
    my $results = $self->find_elements_in_range(\%coords, 999, $dimensions);
    
    # Remove the reference element itself
    @$results = grep { $_->{'element'}->{'id'} ne $element_id } @$results;
    
    # Limit results
    $#$results = $limit - 1 if @$results > $limit;
    
    return $results;
}

# Find paths between elements using relationship network
sub find_paths {
    my ($self, $source_id, $target_id, $max_depth) = @_;
    $max_depth ||= 5;
    
    # Get elements
    my $source = $self->get_element($source_id);
    my $target = $self->get_element($target_id);
    
    # Verify both elements exist
    return [] if !defined $source || !defined $target;
    
    # Use breadth-first search to find paths
    my @paths;
    my %visited = ($source_id => 1);
    my @queue = ([[$source_id]]); # Queue of paths
    
    while (@queue) {
        my $paths_at_level = shift @queue;
        my @next_paths;
        
        foreach my $path (@$paths_at_level) {
            my $current_id = $path->[-1];
            
            # Check if we've reached the target
            if ($current_id eq $target_id) {
                push @paths, $path;
                next;
            }
            
            # Skip if max depth reached
            next if @$path >= $max_depth;
            
            # Get current element
            my $current = $self->get_element($current_id);
            
            # Explore relationships
            foreach my $rel (@{$current->{'relationships'}}) {
                my $next_id = $rel->{'target'}->{'id'};
                
                # Skip if already visited in this path
                next if grep { $_ eq $next_id } @$path;
                
                # Add to next paths
                push @next_paths, [@$path, $next_id];
            }
        }
        
        # Add next paths to queue if we have any
        push @queue, \@next_paths if @next_paths;
    }
    
    # Convert ID paths to full path objects with relationship details
    my @detailed_paths;
    
    foreach my $path (@paths) {
        my @detailed_path;
        
        for my $i (0..$#$path-1) {
            my $current_id = $path->[$i];
            my $next_id = $path->[$i+1];
            
            my $current = $self->get_element($current_id);
            my $next = $self->get_element($next_id);
            
            # Find relationship details
            my @relationships = grep { $_->{'target'}->{'id'} eq $next_id } @{$current->{'relationships'}};
            
            push @detailed_path, {
                'from' => $current,
                'to' => $next,
                'relationships' => \@relationships
            };
        }
        
        push @detailed_paths, \@detailed_path;
    }
    
    return \@detailed_paths;
}

# Project knowledge space to lower dimensions for visualization
sub project_to_dimensions {
    my ($self, $target_dimensions, $projection_method) = @_;
    $target_dimensions ||= ['conceptual', 'structural'];
    $projection_method ||= 'direct';
    
    my %projection;
    
    if ($projection_method eq 'direct') {
        # Simple projection that just extracts the target dimensions
        foreach my $element_id (keys %{$self->{'elements'}}) {
            my $element = $self->{'elements'}->{$element_id};
            $projection{$element_id} = {};
            
            foreach my $dim (@$target_dimensions) {
                $projection{$element_id}->{$dim} = $element->get_coordinate($dim) 
                    if defined $element->get_coordinate($dim);
            }
        }
    } elsif ($projection_method eq 'pca') {
        # Basic Principal Component Analysis
        # Note: A real implementation would use a proper PCA algorithm
        
        # For demonstration, we'll implement a highly simplified version
        %projection = $self->simplified_pca_projection($target_dimensions);
        
    } elsif ($projection_method eq 'harmonic') {
        # Custom harmonic projection
        %projection = $self->harmonic_projection($target_dimensions);
    }
    
    return \%projection;
}

# Simplified PCA projection (for demonstration)
sub simplified_pca_projection {
    my ($self, $target_dimensions) = @_;
    
    # This is a very simplified approximation of PCA
    # A real implementation would compute eigenvectors of the covariance matrix
    
    my %projection;
    my @all_elements = values %{$self->{'elements'}};
    
    # Calculate means for all dimensions
    my %means;
    my %counts;
    
    foreach my $element (@all_elements) {
        foreach my $dim (keys %{$element->{'coordinates'}}) {
            $means{$dim} += $element->{'coordinates'}->{$dim};
            $counts{$dim}++;
        }
    }
    
    foreach my $dim (keys %means) {
        $means{$dim} /= $counts{$dim} if $counts{$dim} > 0;
    }
    
    # Center the data
    my %centered_data;
    foreach my $element (@all_elements) {
        my $id = $element->{'id'};
        $centered_data{$id} = {};
        
        foreach my $dim (keys %{$element->{'coordinates'}}) {
            $centered_data{$id}->{$dim} = $element->{'coordinates'}->{$dim} - $means{$dim};
        }
    }
    
    # For each target dimension, create a projection as a weighted sum of original dimensions
    # In a real PCA, these weights would be the eigenvector components
    # Here we're just using arbitrary weights for demonstration
    for my $t_idx (0..$#$target_dimensions) {
        my $target_dim = $target_dimensions->[$t_idx];
        
        foreach my $element (@all_elements) {
            my $id = $element->{'id'};
            my $projected_value = 0;
            my $weight_sum = 0;
            
            # Apply weights to centered dimensions
            # In this simplified version, we just use a different weight pattern for each target dimension
            foreach my $dim (keys %{$centered_data{$id}}) {
                my $weight = 1.0 / (1.0 + abs($t_idx - length($dim) % 3)); # Arbitrary weight pattern
                $projected_value += $centered_data{$id}->{$dim} * $weight;
                $weight_sum += $weight;
            }
            
            # Normalize
            $projected_value /= $weight_sum if $weight_sum > 0;
            
            # Store projection
            $projection{$id} ||= {};
            $projection{$id}->{$target_dim} = $projected_value;
        }
    }
    
    return %projection;
}

# Harmonic projection based on resonance principles
sub harmonic_projection {
    my ($self, $target_dimensions) = @_;
    
    my %projection;
    my @all_elements = values %{$self->{'elements'}};
    
    # Define harmonic frequencies for target dimensions
    my %harmonic_frequencies;
    for my $i (0..$#$target_dimensions) {
        $harmonic_frequencies{$target_dimensions->[$i]} = 1.0 / (1.0 + $i);
    }
    
    # For each element, calculate harmonic projections
    foreach my $element (@all_elements) {
        my $id = $element->{'id'};
        $projection{$id} = {};
        
        # Calculate projections for each target dimension
        foreach my $target_dim (@$target_dimensions) {
            my $harmonic_sum = 0;
            my $weight_sum = 0;
            
            # Combine source dimensions with harmonic weights
            foreach my $source_dim (keys %{$element->{'coordinates'}}) {
                # Calculate harmonic weight based on resonance between dimensions
                my $base_freq = $harmonic_frequencies{$target_dim};
                my $source_freq = 1.0 / (1.0 + index($source_dim, substr($target_dim, 0, 1)));
                
                # Adjust for integer harmonic relationships (stronger resonance)
                my $ratio = $source_freq / $base_freq;
                my $nearest_harmonic = int($ratio + 0.5);
                my $harmonic_distance = abs($ratio - $nearest_harmonic);
                
                # Harmonic weight is stronger when frequencies have integer relationships
                my $harmonic_weight = exp(-5.0 * $harmonic_distance);
                
                # Apply harmonic transformation
                $harmonic_sum += $element->{'coordinates'}->{$source_dim} * $harmonic_weight;
                $weight_sum += $harmonic_weight;
            }
            
            # Normalize
            $projection{$id}->{$target_dim} = $weight_sum > 0 ? $harmonic_sum / $weight_sum : 0;
        }
    }
    
    return %projection;
}

# Calculate topological features for the knowledge space
sub calculate_topology {
    my ($self) = @_;
    
    # Clear existing topology
    $self->{'topology'} = {
        'manifolds' => {},
        'singularities' => {},
        'flows' => {}
    };
    
    # Calculate manifolds
    $self->calculate_manifolds();
    
    # Identify singularities
    $self->identify_singularities();
    
    # Map knowledge flows
    $self->map_knowledge_flows();
    
    return $self->{'topology'};