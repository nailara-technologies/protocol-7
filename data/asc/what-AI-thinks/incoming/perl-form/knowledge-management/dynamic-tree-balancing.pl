#!/usr/bin/perl
use v5.24;
use strict;
use warnings;
use List::Util qw(max min sum);

# Dynamic Tree Balancing
# Algorithms for maintaining optimal knowledge tree structure over time
# ---------------------------------------------------------------------

# Tree balancing constants
my $TREE_CONSTANTS = {
    'optimal_branching_factor' => {
        'root_level' => 7,       # Optimal children at root level
        'mid_level' => 13,       # Optimal children at middle levels
        'leaf_level' => 5        # Optimal children at leaf level
    },
    'depth_limits' => {
        'min_depth' => 3,        # Minimum tree depth for effective organization
        'max_depth' => 13,       # Maximum tree depth before compression needed
        'optimal_depth' => 7     # Target depth for balanced trees
    },
    'entropy_thresholds' => {
        'high_entropy' => 0.8,   # Threshold for excessively distributed knowledge
        'low_entropy' => 0.3,    # Threshold for overly concentrated knowledge
        'optimal_entropy' => 0.5 # Target entropy for balanced knowledge distribution
    },
    'balancing_weights' => {
        'depth' => 0.3,           # Weight of depth balance in overall score
        'breadth' => 0.3,         # Weight of breadth balance in overall score
        'distribution' => 0.2,    # Weight of even knowledge distribution
        'connectivity' => 0.2     # Weight of cross-branch connectivity
    },
    'pruning_thresholds' => {
        'usage_threshold' => 0.1, # Minimum usage frequency to avoid pruning
        'age_threshold' => 90,    # Days since last access before pruning consideration
        'redundancy_threshold' => 0.8 # Similarity threshold for redundancy pruning
    }
};

# Tree operations modes
my $TREE_OPERATIONS = {
    'analysis' => {
        'description' => 'Analyze tree structure without modification',
        'metrics' => ['depth', 'breadth', 'entropy', 'connectivity']
    },
    'balancing' => {
        'description' => 'Adjust tree structure to optimize knowledge organization',
        'operations' => ['redistribute', 'split', 'merge', 'elevate', 'demote']
    },
    'pruning' => {
        'description' => 'Remove redundant or low-value branches while preserving knowledge integrity',
        'strategies' => ['usage_based', 'redundancy_based', 'age_based', 'integrity_preserving']
    },
    'growth' => {
        'description' => 'Strategically expand tree to accommodate new knowledge domains',
        'patterns' => ['organic', 'planned', 'fractal', 'adaptive']
    }
};

# Tree balancing metrics
my $BALANCE_METRICS = {
    'depth_ratio' => {
        'description' => 'Ratio of actual depth to optimal depth',
        'optimal_value' => 1.0,
        'weight' => 1.5
    },
    'branching_uniformity' => {
        'description' => 'Consistency of branching factors across similar levels',
        'optimal_value' => 0.9,
        'weight' => 1.2
    },
    'knowledge_distribution' => {
        'description' => 'How evenly knowledge is distributed across branches',
        'optimal_value' => 0.7,
        'weight' => 1.0
    },
    'access_pattern_alignment' => {
        'description' => 'Alignment between tree structure and knowledge access patterns',
        'optimal_value' => 0.8,
        'weight' => 1.3
    },
    'cross_reference_density' => {
        'description' => 'Density of connections between different branches',
        'optimal_value' => 0.6,
        'weight' => 0.8
    }
};

# Tree node object encapsulation
package TreeNode;

sub new {
    my ($class, $name, $content, $metadata) = @_;
    
    my $self = {
        'name' => $name,
        'content' => $content || '',
        'children' => [],
        'parent' => undef,
        'metadata' => $metadata || {},
        'stats' => {
            'created' => time(),
            'accessed' => time(),
            'modified' => time(),
            'access_count' => 0,
            'modification_count' => 0
        }
    };
    
    return bless $self, $class;
}

# Add a child node
sub add_child {
    my ($self, $child) = @_;
    
    # Set parent reference
    $child->{'parent'} = $self;
    
    # Add to children array
    push @{$self->{'children'}}, $child;
    
    # Update stats
    $self->{'stats'}->{'modified'} = time();
    $self->{'stats'}->{'modification_count'}++;
    
    return $child;
}

# Remove a child node
sub remove_child {
    my ($self, $child) = @_;
    
    # Find and remove the child
    my @remaining = grep { $_ != $child } @{$self->{'children'}};
    
    # Update children array if we found and removed the child
    if (scalar @remaining != scalar @{$self->{'children'}}) {
        $self->{'children'} = \@remaining;
        
        # Update stats
        $self->{'stats'}->{'modified'} = time();
        $self->{'stats'}->{'modification_count'}++;
        
        return 1; # Success
    }
    
    return 0; # Child not found
}

# Access the node (update access stats)
sub access {
    my ($self) = @_;
    
    $self->{'stats'}->{'accessed'} = time();
    $self->{'stats'}->{'access_count'}++;
    
    return $self;
}

# Update node content
sub update_content {
    my ($self, $new_content) = @_;
    
    $self->{'content'} = $new_content;
    $self->{'stats'}->{'modified'} = time();
    $self->{'stats'}->{'modification_count'}++;
    
    return $self;
}

# Get node depth (distance from root)
sub depth {
    my ($self) = @_;
    
    return 0 if !defined $self->{'parent'};
    return 1 + $self->{'parent'}->depth();
}

# Get subtree height (distance to deepest leaf)
sub height {
    my ($self) = @_;
    
    # If no children, height is 0
    return 0 if !@{$self->{'children'}};
    
    # Otherwise, height is 1 + maximum height of children
    my $max_child_height = 0;
    foreach my $child (@{$self->{'children'}}) {
        my $child_height = $child->height();
        $max_child_height = $child_height if $child_height > $max_child_height;
    }
    
    return 1 + $max_child_height;
}

# Count total nodes in subtree
sub size {
    my ($self) = @_;
    
    my $size = 1; # Count this node
    
    # Add size of all child subtrees
    foreach my $child (@{$self->{'children'}}) {
        $size += $child->size();
    }
    
    return $size;
}

# Get all leaf nodes in subtree
sub get_leaves {
    my ($self) = @_;
    
    # If no children, this is a leaf
    return ($self) if !@{$self->{'children'}};
    
    # Otherwise, collect leaves from all children
    my @leaves;
    foreach my $child (@{$self->{'children'}}) {
        push @leaves, $child->get_leaves();
    }
    
    return @leaves;
}

# Find node by name (breadth-first search)
sub find_node {
    my ($self, $name) = @_;
    
    # Check if this is the node we're looking for
    return $self if $self->{'name'} eq $name;
    
    # Create a queue for breadth-first search
    my @queue = @{$self->{'children'}};
    
    while (@queue) {
        my $node = shift @queue;
        return $node if $node->{'name'} eq $name;
        push @queue, @{$node->{'children'}};
    }
    
    return undef; # Node not found
}

# Get sibling nodes (other children of same parent)
sub get_siblings {
    my ($self) = @_;
    
    # Return empty list if no parent
    return () if !defined $self->{'parent'};
    
    # Get all siblings (including self)
    my @siblings = @{$self->{'parent'}->{'children'}};
    
    # Remove self from list
    @siblings = grep { $_ != $self } @siblings;
    
    return @siblings;
}

# Convert to string representation
sub to_string {
    my ($self, $indent) = @_;
    $indent ||= 0;
    
    my $result = ' ' x $indent . $self->{'name'};
    if (length($self->{'content'}) > 0) {
        $result .= ': ' . substr($self->{'content'}, 0, 30);
        $result .= '...' if length($self->{'content'}) > 30;
    }
    $result .= "\n";
    
    foreach my $child (@{$self->{'children'}}) {
        $result .= $child->to_string($indent + 2);
    }
    
    return $result;
}

package KnowledgeTree;

sub new {
    my ($class, $root_name) = @_;
    $root_name ||= 'root';
    
    my $self = {
        'root' => TreeNode->new($root_name, 'Knowledge tree root node'),
        'metadata' => {
            'created' => time(),
            'last_balanced' => time(),
            'balance_count' => 0
        },
        'stats' => {
            'total_nodes' => 1,
            'max_depth' => 0,
            'avg_branching_factor' => 0,
            'balance_score' => 1.0  # Start perfectly balanced
        }
    };
    
    return bless $self, $class;
}

# Add a path of nodes to the tree
sub add_path {
    my ($self, $path, $content) = @_;
    
    # Start at root
    my $current = $self->{'root'};
    
    # Split path into components
    my @components = split('/', $path);
    
    # Traverse/create path
    for my $i (0..$#components) {
        my $name = $components[$i];
        
        # Check if this node already exists
        my $found = 0;
        foreach my $child (@{$current->{'children'}}) {
            if ($child->{'name'} eq $name) {
                $current = $child;
                $found = 1;
                last;
            }
        }
        
        # If not found, create new node
        if (!$found) {
            # Only add content to the last node in path
            my $node_content = ($i == $#components) ? $content : '';
            my $new_node = TreeNode->new($name, $node_content);
            $current->add_child($new_node);
            $current = $new_node;
            
            # Update tree stats
            $self->{'stats'}->{'total_nodes'}++;
        }
    }
    
    # Return the final node
    return $current;
}

# Find a node by path
sub find_path {
    my ($self, $path) = @_;
    
    # Start at root
    my $current = $self->{'root'};
    
    # Special case for root path
    return $current if $path eq '' || $path eq '/';
    
    # Split path into components
    my @components = split('/', $path);
    
    # Remove empty first component if path started with /
    shift @components if @components && $components[0] eq '';
    
    # Traverse path
    for my $name (@components) {
        my $found = 0;
        foreach my $child (@{$current->{'children'}}) {
            if ($child->{'name'} eq $name) {
                $current = $child;
                $found = 1;
                last;
            }
        }
        
        # Return undef if any component not found
        return undef if !$found;
    }
    
    # Return the final node
    return $current;
}

# Calculate balance metrics for the tree
sub calculate_balance_metrics {
    my ($self) = @_;
    
    my $metrics = {};
    
    # Calculate depth ratio
    my $max_depth = $self->max_depth();
    $self->{'stats'}->{'max_depth'} = $max_depth;
    $metrics->{'depth_ratio'} = $max_depth / $TREE_CONSTANTS->{'depth_limits'}->{'optimal_depth'};
    
    # Calculate branching uniformity
    my $branching_stats = $self->branching_statistics();
    $metrics->{'branching_uniformity'} = 1.0 - $branching_stats->{'std_dev'} / $branching_stats->{'mean'};
    $self->{'stats'}->{'avg_branching_factor'} = $branching_stats->{'mean'};
    
    # Calculate knowledge distribution
    my $distribution = $self->knowledge_distribution();
    $metrics->{'knowledge_distribution'} = 1.0 - $distribution->{'entropy'};
    
    # Calculate access pattern alignment
    my $access_alignment = $self->access_pattern_alignment();
    $metrics->{'access_pattern_alignment'} = $access_alignment;
    
    # Calculate cross-reference density
    my $cross_ref_density = $self->cross_reference_density();
    $metrics->{'cross_reference_density'} = $cross_ref_density;
    
    # Calculate overall balance score
    my $balance_score = 0;
    my $total_weight = 0;
    
    foreach my $metric (keys %$BALANCE_METRICS) {
        my $weight = $BALANCE_METRICS->{$metric}->{'weight'};
        my $optimal = $BALANCE_METRICS->{$metric}->{'optimal_value'};
        my $actual = $metrics->{$metric};
        my $score = 1.0 - abs($optimal - $actual) / $optimal;
        $balance_score += $score * $weight;
        $total_weight += $weight;
    }
    
    # Normalize score
    $metrics->{'overall_score'} = $balance_score / $total_weight;
    $self->{'stats'}->{'balance_score'} = $metrics->{'overall_score'};
    
    return $metrics;
}

# Get maximum depth of the tree
sub max_depth {
    my ($self) = @_;
    return $self->{'root'}->height();
}

# Calculate branching statistics
sub branching_statistics {
    my ($self) = @_;
    
    # Breadth-first traversal to collect branching factors by level
    my @levels;
    my @current_level = ($self->{'root'});
    
    while (@current_level) {
        # Count children for each node at this level
        my @branching_factors;
        my @next_level;
        
        foreach my $node (@current_level) {
            push @branching_factors, scalar @{$node->{'children'}};
            push @next_level, @{$node->{'children'}};
        }
        
        # Store this level's branching factors
        push @levels, \@branching_factors;
        
        # Move to next level
        @current_level = @next_level;
    }
    
    # Calculate statistics
    my $total_nodes = 0;
    my $sum_branches = 0;
    my @all_factors;
    
    foreach my $level (@levels) {
        $total_nodes += scalar @$level;
        $sum_branches += sum(@$level);
        push @all_factors, @$level;
    }
    
    # Calculate mean
    my $mean = @all_factors ? sum(@all_factors) / scalar(@all_factors) : 0;
    
    # Calculate standard deviation
    my $variance = 0;
    if (@all_factors) {
        $variance = sum(map { ($_ - $mean) ** 2 } @all_factors) / scalar(@all_factors);
    }
    my $std_dev = sqrt($variance);
    
    return {
        'levels' => \@levels,
        'mean' => $mean,
        'std_dev' => $std_dev,
        'total_nodes' => $total_nodes,
        'total_branches' => $sum_branches
    };
}

# Calculate knowledge distribution entropy
sub knowledge_distribution {
    my ($self) = @_;
    
    # Get all leaf nodes
    my @leaves = $self->{'root'}->get_leaves();
    
    # Calculate content size for each leaf
    my @content_sizes;
    my $total_content = 0;
    
    foreach my $leaf (@leaves) {
        my $size = length($leaf->{'content'});
        push @content_sizes, $size;
        $total_content += $size;
    }
    
    # Calculate Shannon entropy of distribution
    my $entropy = 0;
    foreach my $size (@content_sizes) {
        if ($size > 0 && $total_content > 0) {
            my $p = $size / $total_content;
            $entropy -= $p * log($p) / log(2);
        }
    }
    
    # Normalize entropy (0-1 scale)
    my $max_entropy = log(scalar @leaves) / log(2);
    my $normalized_entropy = $max_entropy > 0 ? $entropy / $max_entropy : 0;
    
    return {
        'entropy' => $normalized_entropy,
        'total_content' => $total_content,
        'leaf_count' => scalar @leaves
    };
}

# Calculate alignment between tree structure and access patterns
sub access_pattern_alignment {
    my ($self) = @_;
    
    # Breadth-first traversal to collect all nodes
    my @nodes;
    my @queue = ($self->{'root'});
    
    while (@queue) {
        my $node = shift @queue;
        push @nodes, $node;
        push @queue, @{$node->{'children'}};
    }
    
    # Skip if no nodes with access stats
    return 0 if !@nodes;
    
    # Calculate expected access frequency based on depth
    # Nodes at shallower depths should be accessed more frequently
    my $alignment_score = 0;
    
    foreach my $node (@nodes) {
        my $depth = $node->depth();
        my $access_count = $node->{'stats'}->{'access_count'};
        
        # Skip nodes with no accesses
        next if $access_count == 0;
        
        # Calculate expected access frequency (higher for shallower nodes)
        my $expected_frequency = 1.0 / (1.0 + $depth);
        
        # Normalize actual frequency relative to all nodes
        my $total_accesses = sum(map { $_->{'stats'}->{'access_count'} } @nodes);
        my $actual_frequency = $access_count / $total_accesses;
        
        # Calculate alignment for this node
        my $node_alignment = 1.0 - abs($expected_frequency - $actual_frequency) / $expected_frequency;
        
        # Weight by access count
        $alignment_score += $node_alignment * ($access_count / $total_accesses);
    }
    
    return $alignment_score;
}

# Calculate cross-reference density
sub cross_reference_density {
    my ($self) = @_;
    
    # For a real implementation, this would analyze content for cross-references
    # For this demonstration, we'll use a simplified approach
    
    # Count potential cross-references in content
    my $cross_ref_count = 0;
    my $total_nodes = 0;
    
    # Breadth-first traversal
    my @queue = ($self->{'root'});
    
    while (@queue) {
        my $node = shift @queue;
        $total_nodes++;
        
        # Simple regex to identify potential cross-references
        my $content = $node->{'content'};
        $cross_ref_count += () = $content =~ /see also|related|reference|link|connection/ig;
        
        push @queue, @{$node->{'children'}};
    }
    
    # Calculate density
    my $max_possible = $total_nodes * ($total_nodes - 1) / 2; # Maximum possible references
    my $density = $max_possible > 0 ? $cross_ref_count / $max_possible : 0;
    
    return $density;
}

# Balance the tree
sub balance_tree {
    my ($self, $mode) = @_;
    $mode ||= 'balancing';
    
    # Record balancing operation
    $self->{'metadata'}->{'last_balanced'} = time();
    $self->{'metadata'}->{'balance_count'}++;
    
    # Different operations based on mode
    if ($mode eq 'analysis') {
        # Just calculate and return metrics
        return $self->calculate_balance_metrics();
        
    } elsif ($mode eq 'balancing') {
        # Perform tree balancing operations
        my $original_metrics = $self->calculate_balance_metrics();
        my $operations = $self->identify_balancing_operations($original_metrics);
        
        my $changes = $self->apply_balancing_operations($operations);
        my $new_metrics = $self->calculate_balance_metrics();
        
        return {
            'before' => $original_metrics,
            'after' => $new_metrics,
            'operations' => $operations,
            'changes' => $changes
        };
        
    } elsif ($mode eq 'pruning') {
        # Identify and prune redundant or low-value branches
        my $candidates = $self->identify_pruning_candidates();
        my $pruned = $self->prune_branches($candidates);
        my $new_metrics = $self->calculate_balance_metrics();
        
        return {
            'pruned' => $pruned,
            'metrics' => $new_metrics
        };
        
    } elsif ($mode eq 'growth') {
        # Strategic growth is typically driven by new content addition
        # This is mostly a placeholder for demonstration
        return {
            'status' => 'growth requires new content',
            'metrics' => $self->calculate_balance_metrics()
        };
    }
    
    return undef; # Invalid mode
}

# Identify needed balancing operations
sub identify_balancing_operations {
    my ($self, $metrics) = @_;
    
    my @operations;
    
    # Check depth ratio (tree too deep or too shallow)
    if ($metrics->{'depth_ratio'} > 1.2) {
        # Tree too deep, need to flatten
        push @operations, { 'type' => 'flatten', 'reason' => 'depth_ratio', 'value' => $metrics->{'depth_ratio'} };
    } elsif ($metrics->{'depth_ratio'} < 0.8) {
        # Tree too shallow, need to deepen
        push @operations, { 'type' => 'deepen', 'reason' => 'depth_ratio', 'value' => $metrics->{'depth_ratio'} };
    }
    
    # Check branching uniformity
    if ($metrics->{'branching_uniformity'} < 0.7) {
        # Inconsistent branching, need to redistribute
        push @operations, { 'type' => 'redistribute', 'reason' => 'branching_uniformity', 'value' => $metrics->{'branching_uniformity'} };
    }
    
    # Check knowledge distribution
    if ($metrics->{'knowledge_distribution'} < 0.6) {
        # Poor knowledge distribution, need to rebalance content
        push @operations, { 'type' => 'rebalance_content', 'reason' => 'knowledge_distribution', 'value' => $metrics->{'knowledge_distribution'} };
    }
    
    # Check access pattern alignment
    if ($metrics->{'access_pattern_alignment'} < 0.6) {
        # Structure doesn't match access patterns, need to reorganize
        push @operations, { 'type' => 'reorganize', 'reason' => 'access_pattern_alignment', 'value' => $metrics->{'access_pattern_alignment'} };
    }
    
    return \@operations;
}

# Apply balancing operations
sub apply_balancing_operations {
    my ($self, $operations) = @_;
    
    my $changes = 0;
    
    foreach my $op (@$operations) {
        if ($op->{'type'} eq 'flatten') {
            $changes += $self->flatten_deep_branches();
        } elsif ($op->{'type'} eq 'deepen') {
            $changes += $self->deepen_shallow_branches();
        } elsif ($op->{'type'} eq 'redistribute') {
            $changes += $self->redistribute_branches();
        } elsif ($op->{'type'} eq 'rebalance_content') {
            $changes += $self->rebalance_content();
        } elsif ($op->{'type'} eq 'reorganize') {
            $changes += $self->reorganize_by_access_patterns();
        }
    }
    
    return $changes;
}

# Flatten overly deep branches by promoting grandchildren
sub flatten_deep_branches {
    my ($self) = @_;
    
    my $changes = 0;
    
    # Identify deep branches (BFS to process level by level)
    my @queue = ($self->{'root'});
    my $max_depth = $TREE_CONSTANTS->{'depth_limits'}->{'optimal_depth'};
    
    while (@queue) {
        my $node = shift @queue;
        my $node_depth = $node->depth();
        
        # Skip shallow nodes
        if ($node_depth < $max_depth - 1) {
            push @queue, @{$node->{'children'}};
            next;
        }
        
        # Check if this node has children with many grandchildren
        foreach my $child (@{$node->{'children'}}) {
            # Skip children with few grandchildren
            next if scalar @{$child->{'children'}} < 3;
            
            # Promote grandchildren to children
            my @grandchildren = @{$child->{'children'}};
            
            # Skip nodes with very large content (these should remain leaves)
            @grandchildren = grep { length($_->{'content'}) < 1000 } @grandchildren;
            
            # Only proceed if we have grandchildren to promote
            next if !@grandchildren;
            
            # Clear child's children array
            $child->{'children'} = [];
            
            # Add grandchildren as children of current node
            foreach my $grandchild (@grandchildren) {
                $node->add_child($grandchild);
                $changes++;
            }
            
            # If child now has no children and no significant content, remove it
            if (!@{$child->{'children'}} && length($child->{'content'}) < 100) {
                $node->remove_child($child);
                $changes++;
            }
        }
        
        # Add remaining children to queue
        push @queue, @{$node->{'children'}};
    }
    
    return $changes;
}

# Deepen shallow branches by grouping children
sub deepen_shallow_branches {
    my ($self) = @_;
    
    my $changes = 0;
    
    # Identify shallow branches with many children
    my @queue = ($self->{'root'});
    
    while (@queue) {
        my $node = shift @queue;
        
        # Skip nodes with few children
        if (scalar @{$node->{'children'}} < $TREE_CONSTANTS->{'optimal_branching_factor'}->{'mid_level'} * 1.5) {
            push @queue, @{$node->{'children'}};
            next;
        }
        
        # Group children by common prefixes or similarities
        my %groups;
        
        foreach my $child (@{$node->{'children'}}) {
            # Extract first part of name for grouping
            my $prefix = '';
            if ($child->{'name'} =~ /^(\w+)/) {
                $prefix = $1;
            } else {
                $prefix = substr($child->{'name'}, 0, 1);
            }
            
            push @{$groups{$prefix}}, $child;
        }
        
        # Create new intermediate nodes for groups with multiple children
        foreach my $prefix (keys %groups) {
            my $group = $groups{$prefix};
            
            # Skip small groups
            next if scalar @$group < 3;
            
            # Create new intermediate node
            my $group_node = TreeNode->new($prefix . '_group', "Group for items starting with '$prefix'");
            $node->add_child($group_node);
            
            # Move children to new group node
            foreach my $child (@$group) {
                $node->remove_child($child);
                $group_node->add_child($child);
                $changes++;
            }
        }
        
        # Add remaining children to queue
        push @queue, @{$node->{'children'}};
    }
    
    return $changes;
}

# Redistribute branches to balance branching factor
sub redistribute_branches {
    my ($self) = @_;
    
    my $changes = 0;
    
    # Breadth-first traversal to identify imbalanced nodes
    my @queue = ($self->{'root'});
    
    while (@queue) {
        my $node = shift @queue;
        my $child_count = scalar @{$node->{'children'}};
        
        # Get optimal branching factor for this level
        my $node_depth = $node->depth();
        my $optimal_factor;
        
        if ($node_depth == 0) {
            $optimal_factor = $TREE_CONSTANTS->{'optimal_branching_factor'}->{'root_level'};
        } elsif ($node->height() <= 1) {
            $optimal_factor = $TREE_CONSTANTS->{'optimal_branching_factor'}->{'leaf_level'};
        } else {
            $optimal_factor = $TREE_CONSTANTS->{'optimal_branching_factor'}->{'mid_level'};
        }
        
        # Check if this node needs rebalancing
        if ($child_count > $optimal_factor * 1.5) {
            # Too many children, need to redistribute
            $changes += $self->split_node($node, $optimal_factor);
        } elsif ($child_count > 0 && $child_count < $optimal_factor * 0.5) {
            # Too few children, check if we can merge with siblings
            my @siblings = $node->get_siblings();
            
            if (@siblings) {
                # Find sibling with smallest number of children
                my $best_sibling = $siblings[0];
                foreach my $sibling (@siblings) {
                    if (scalar @{$sibling->{'children'}} < scalar @{$best_sibling->{'children'}}) {
                        $best_sibling = $sibling;
                    }
                }
                
                # If merging would create a better balance, do it
                my $combined_children = $child_count + scalar @{$best_sibling->{'children'}};
                if ($combined_children <= $optimal_factor * 1.2) {
                    $changes += $self->merge_nodes($node, $best_sibling);
                }
            }
        }
        
        # Add children to queue for next iteration
        push @queue, @{$node->{'children'}};
    }
    
    return $changes;
}

# Split a node with too many children
sub split_node {
    my ($self, $node, $optimal_factor) = @_;
    
    # If too few children, don't split
    my $child_count = scalar @{$node->{'children'}};
    return 0 if $child_count < $optimal_factor;
    
    my $changes = 0;
    
    # Calculate how many groups we need
    my $group_count = int($child_count / $optimal_factor) + ($child_count % $optimal_factor > 0 ? 1 : 0);
    
    # Get children sorted by name to group similar items
    my @sorted_children = sort { $a->{'name'} cmp $b->{'name'} } @{$node->{'children'}};
    
    # Calculate children per group
    my $children_per_group = int($child_count / $group_count);
    my $extras = $child_count % $group_count;
    
    # Create new group nodes and distribute children
    my @groups;
    
    for my $i (0..$group_count-1) {
        # Calculate range for this group
        my $start_idx = $i * $children_per_group + min($i, $extras);
        my $group_size = $children_per_group + ($i < $extras ? 1 : 0);
        
        # Get children for this group
        my @group_children = @sorted_children[$start_idx..($start_idx+$group_size-1)];
        
        # Skip if no children (shouldn't happen if math is right)
        next if !@group_children;
        
        # Find common prefix or theme
        my $prefix = $self->find_common_prefix(\@group_children);
        
        # Create new group node
        my $group_node = TreeNode->new(
            $prefix . "_group_" . ($i+1),
            "Group " . ($i+1) . " of " . $group_count . " for " . $node->{'name'}
        );
        
        # Add group node to parent
        $node->add_child($group_node);
        
        # Move children to group node
        foreach my $child (@group_children) {
            $node->remove_child($child);
            $group_node->add_child($child);
            $changes++;
        }
    }
    
    return $changes;
}

# Find common prefix for a group of nodes
sub find_common_prefix {
    my ($self, $nodes) = @_;
    
    return "group" if !@$nodes;
    
    # Start with first node's name
    my $prefix = $nodes->[0]->{'name'};
    
    # Compare with other node names to find common prefix
    foreach my $node (@$nodes[1..$#$nodes]) {
        my $name = $node->{'name'};
        my $len = min(length($prefix), length($name));
        my $common_len = 0;
        
        # Find common prefix length
        for my $i (0..$len-1) {
            if (substr($prefix, $i, 1) eq substr($name, $i, 1)) {
                $common_len++;
            } else {
                last;
            }
        }
        
        # Update prefix
        $prefix = substr($prefix, 0, $common_len);
        
        # If no common prefix, use first character
        if ($common_len == 0) {
            $prefix = substr($nodes->[0]->{'name'}, 0, 1);
            last;
        }
    }
    
    # Return at least 2 characters, or "group" if too short
    return length($prefix) >= 2 ? $prefix : "group";
}

# Merge two nodes
sub merge_nodes {
    my ($self, $node1, $node2) = @_;
    
    my $changes = 0;
    
    # Create merged name
    my $merged_name = $node1->{'name'} . "_" . $node2->{'name'};
    
    # Create merged content
    my $merged_content = "";
    $merged_content .= "Content from " . $node1->{'name'} . ":\n" . $node1->{'content'} if length($node1->{'content'}) > 0;
    $merged_content .= "\n\nContent from " . $node2->{'name'} . ":\n" . $node2->{'content'} if length($node2->{'content'}) > 0;
    
    # Get parent
    my $parent = $node1->{'parent'};
    return 0 if !defined $parent; # Can't merge without parent
    
    # Create new merged node
    my $merged_node = TreeNode->new($merged_name, $merged_content);
    $parent->add_child($merged_node);
    
    # Move all children from both nodes to merged node
    foreach my $child (@{$node1->{'children'}}) {
        $node1->remove_child($child);
        $merged_node->add_child($child);
        $changes++;
    }
    
    foreach my $child (@{$node2->{'children'}}) {
        $node2->remove_child($child);
        $merged_node->add_child($child);
        $changes++;
    }
    
    # Remove original nodes
    $parent->remove_child($node1);
    $parent->remove_child($node2);
    $changes += 2;
    
    return $changes;
}

# Rebalance content across nodes
sub rebalance_content {
    my ($self) = @_;
    
    my $changes = 0;
    
    # Get all leaf nodes
    my @leaves = $self->{'root'}->get_leaves();
    
    # Calculate average content size
    my $total_size = sum(map { length($_->{'content'}) } @leaves);
    my $avg_size = $total_size / scalar(@leaves);
    
    # Identify oversized and undersized leaves
    my @oversized = grep { length($_->{'content'}) > $avg_size * 1.5 } @leaves;
    my @undersized = grep { length($_->{'content'}) < $avg_size * 0.5 && $_->depth() > 1 } @leaves;
    
    # Sort by size (largest first for oversized, smallest first for undersized)
    @oversized = sort { length($b->{'content'}) <=> length($a->{'content'}) } @oversized;
    @undersized = sort { length($a->{'content'}) <=> length($b->{'content'}) } @undersized;
    
    # Process oversized nodes
    foreach my $node (@oversized) {
        # Skip if no undersized nodes to balance with
        last if !@undersized;
        
        # Split content if possible
        my $content = $node->{'content'};
        
        # Simple split by paragraphs for demonstration
        my @paragraphs = split(/\n\n/, $content);
        
        # Only split if we have multiple paragraphs
        if (@paragraphs > 2) {
            # Keep some paragraphs in original node
            my $keep_count = int(@paragraphs / 2);
            my $new_content = join("\n\n", @paragraphs[0..($keep_count-1)]);
            
            # Move remaining paragraphs to undersized node
            my $move_content = join("\n\n", @paragraphs[$keep_count..$#paragraphs]);
            
            # Find suitable undersized node
            my $target_node = shift @undersized;
            
            # Update contents
            $node->update_content($new_content);
            $target_node->update_content($target_node->{'content'} . "\n\n" . $move_content);
            
            $changes++;
            
            # Re-evaluate if target node is still undersized
            if (length($target_node->{'content'}) < $avg_size * 0.5) {
                # Still undersized, put back in list
                push @undersized, $target_node;
                @undersized = sort { length($a->{'content'}) <=> length($b->{'content'}) } @undersized;
            }
        }
    }
    
    return $changes;
}

# Reorganize tree based on access patterns
sub reorganize_by_access_patterns {
    my ($self) = @_;
    
    my $changes = 0;
    
    # Get all nodes
    my @nodes;
    my @queue = ($self->{'root'});
    
    while (@queue) {
        my $node = shift @queue;
        push @nodes, $node;
        push @queue, @{$node->{'children'}};
    }
    
    # Sort by access count (most accessed first)
    @nodes = sort { $b->{'stats'}->{'access_count'} <=> $a->{'stats'}->{'access_count'} } @nodes;
    
    # Skip root node
    @nodes = grep { $_ != $self->{'root'} } @nodes;
    
    # Process most accessed nodes
    foreach my $node (@nodes) {
        # Skip nodes with few accesses
        last if $node->{'stats'}->{'access_count'} < 5;
        
        my $current_depth = $node->depth();
        my $target_depth = 1; # Direct child of root
        
        # Skip if already at optimal depth
        next if $current_depth <= $target_depth;
        
        # Elevate the node to higher level
        my $parent = $node->{'parent'};
        if (defined $parent && $parent != $self->{'root'}) {
            $parent->remove_child($node);
            $self->{'root'}->add_child($node);
            $changes++;
        }
    }
    
    return $changes;
}

# Identify candidates for pruning
sub identify_pruning_candidates {
    my ($self) = @_;
    
    my @candidates;
    
    # Get all nodes
    my @nodes;
    my @queue = ($self->{'root'});
    
    while (@queue) {
        my $node = shift @queue;
        push @nodes, $node;
        push @queue, @{$node->{'children'}};
    }
    
    # Skip root
    @nodes = grep { $_ != $self->{'root'} } @nodes;
    
    # Current time for age calculation
    my $now = time();
    
    # Check each node against pruning criteria
    foreach my $node (@nodes) {
        my $score = 0;
        my @reasons;
        
        # Check access frequency
        my $access_count = $node->{'stats'}->{'access_count'};
        my $total_accesses = sum(map { $_->{'stats'}->{'access_count'} } @nodes);
        my $access_frequency = $total_accesses > 0 ? $access_count / $total_accesses : 0;
        
        if ($access_frequency < $TREE_CONSTANTS->{'pruning_thresholds'}->{'usage_threshold'}) {
            $score += 0.3;
            push @reasons, "low_usage";
        }
        
        # Check age
        my $last_access = $node->{'stats'}->{'accessed'};
        my $days_since_access = ($now - $last_access) / (24 * 60 * 60);
        
        if ($days_since_access > $TREE_CONSTANTS->{'pruning_thresholds'}->{'age_threshold'}) {
            $score += 0.4;
            push @reasons, "age";
        }
        
        # Check redundancy (simplified)
        # In a real implementation, this would use more sophisticated content comparison
        my $content = $node->{'content'};
        my $is_redundant = 0;
        
        foreach my $other (@nodes) {
            next if $other == $node;
            
            my $other_content = $other->{'content'};
            
            # Skip if either node has no content
            next if length($content) == 0 || length($other_content) == 0;
            
            # Simple similarity check based on content length and common words
            my %words_node;
            my @words = split /\s+/, lc($content);
            $words_node{$_}++ for @words;
            
            my %words_other;
            my @words_other = split /\s+/, lc($other_content);
            $words_other{$_}++ for @words_other;
            
            # Count common words
            my $common_words = 0;
            foreach my $word (keys %words_node) {
                $common_words += min($words_node{$word}, $words_other{$word} || 0);
            }
            
            # Calculate similarity
            my $total_words = scalar(@words) + scalar(@words_other) - $common_words;
            my $similarity = $total_words > 0 ? $common_words / $total_words : 0;
            
            if ($similarity > $TREE_CONSTANTS->{'pruning_thresholds'}->{'redundancy_threshold'}) {
                $score += 0.5;
                push @reasons, "redundancy";
                $is_redundant = 1;
                last;
            }
        }
        
        # Check overall pruning score
        if ($score >= 0.7) {
            push @candidates, {
                'node' => $node,
                'score' => $score,
                'reasons' => \@reasons
            };
        }
    }
    
    return \@candidates;
}

# Prune branches based on candidates list
sub prune_branches {
    my ($self, $candidates) = @_;
    
    my @pruned;
    
    # Sort candidates by score (highest first)
    my @sorted = sort { $b->{'score'} <=> $a->{'score'} } @$candidates;
    
    # Process candidates
    foreach my $candidate (@sorted) {
        my $node = $candidate->{'node'};
        
        # Skip nodes with children unless they're redundant
        if (@{$node->{'children'}} > 0) {
            next unless grep { $_ eq "redundancy" } @{$candidate->{'reasons'}};
        }
        
        # Get parent
        my $parent = $node->{'parent'};
        next if !defined $parent; # Skip if no parent
        
        # Record node details before pruning
        push @pruned, {
            'name' => $node->{'name'},
            'content_length' => length($node->{'content'}),
            'child_count' => scalar @{$node->{'children'}},
            'reasons' => $candidate->{'reasons'}
        };
        
        # Remove node
        $parent->remove_child($node);
        
        # Update tree stats
        $self->{'stats'}->{'total_nodes'}--;
    }
    
    return \@pruned;
}

# Convert to string representation
sub to_string {
    my ($self) = @_;
    
    my $result = "Knowledge Tree Structure:\n";
    $result .= $self->{'root'}->to_string();
    
    # Add tree statistics
    $result .= "\nTree Statistics:\n";
    $result .= "  Total nodes: " . $self->{'stats'}->{'total_nodes'} . "\n";
    $result .= "  Maximum depth: " . $self->{'stats'}->{'max_depth'} . "\n";
    $result .= "  Average branching factor: " . sprintf("%.2f", $self->{'stats'}->{'avg_branching_factor'}) . "\n";
    $result .= "  Balance score: " . sprintf("%.2f", $self->{'stats'}->{'balance_score'}) . "\n";
    
    return $result;
}

package main;

# Function to demonstrate knowledge tree balancing
sub demonstrate_tree_balancing {
    say "\n=== Demonstrating Knowledge Tree Balancing ===\n";
    
    # Create a sample knowledge tree
    my $tree = KnowledgeTree->new("Knowledge Framework");
    
    # Add sample paths and content
    $tree->add_path("concepts/consciousness_resonance", 
                  "Framework for understanding consciousness as emergent property of resonant systems");
    $tree->add_path("concepts/network_topology", 
                  "Study of organizational structures in resilient networks");
    $tree->add_path("concepts/harmonic_verification", 
                  "Method for validating knowledge integrity through harmonic principles");
    
    $tree->add_path("implementation/matrix_verification", 
                  "2D matrix with AMOS7 checksums for error detection and correction");
    $tree->add_path("implementation/bayesian_reconstruction", 
                  "Probabilistic inference for restoring corrupted knowledge");
    $tree->add_path("implementation/cross_branch_interpolation", 
                  "Recovery of missing information through related branches");
    
    $tree->add_path("validation/confidence_metrics", 
                  "Measurements of reconstruction reliability and accuracy");
    $tree->add_path("validation/pattern_templates", 
                  "Templates for validating structural, semantic, and conceptual patterns");
    
    # Display initial tree structure
    say "Initial Tree Structure:";
    say $tree->to_string();
    
    # Calculate balance metrics
    my $metrics = $tree->calculate_balance_metrics();
    
    say "\nInitial Balance Metrics:";
    foreach my $metric (sort keys %$metrics) {
        say "  $metric: " . sprintf("%.4f", $metrics->{$metric});
    }
    
    # Create an imbalance by adding many items to one branch
    for my $i (1..15) {
        $tree->add_path("concepts/subconcepts/item_$i", "Content for item $i");
    }
    
    say "\nTree After Creating Imbalance:";
    say $tree->to_string();
    
    # Recalculate metrics
    $metrics = $tree->calculate_balance_metrics();
    
    say "\nImbalanced Metrics:";
    foreach my $metric (sort keys %$metrics) {
        say "  $metric: " . sprintf("%.4f", $metrics->{$metric});
    }
    
    # Balance the tree
    my $balance_result = $tree->balance_tree('balancing');
    
    say "\nTree After Balancing:";
    say $tree->to_string();
    
    say "\nBalance Operations Applied:";
    foreach my $op (@{$balance_result->{'operations'}}) {
        say "  " . $op->{'type'} . " - reason: " . $op->{'reason'} . 
            ", value: " . sprintf("%.4f", $op->{'value'});
    }
    
    say "\nFinal Balance Metrics:";
    foreach my $metric (sort keys %{$balance_result->{'after'}}) {
        say "  $metric: " . sprintf("%.4f", $balance_result->{'after'}->{$metric});
    }
    
    # Simulate access patterns
    my $concepts_node = $tree->find_path("concepts");
    $concepts_node->access() if defined $concepts_node;
    $concepts_node->access() if defined $concepts_node;
    $concepts_node->access() if defined $concepts_node;
    
    my $matrix_node = $tree->find_path("implementation/matrix_verification");
    $matrix_node->access() if defined $matrix_node;
    $matrix_node->access() if defined $matrix_node;
    
    # Demonstrate pruning
    say "\n=== Demonstrating Branch Pruning ===\n";
    
    # Add some redundant content
    $tree->add_path("redundant/item_1", "Information about consciousness as emergent property of resonant systems");
    $tree->add_path("old/unused", "This is old and unused content that hasn't been accessed");
    
    # Identify pruning candidates
    my $candidates = $tree->identify_pruning_candidates();
    
    say "Pruning Candidates:";
    foreach my $candidate (@$candidates) {
        say "  " . $candidate->{'node'}->{'name'} . " - score: " . 
            sprintf("%.2f", $candidate->{'score'}) . ", reasons: " . 
            join(", ", @{$candidate->{'reasons'}});
    }
    
    # Perform pruning
    my $pruned = $tree->prune_branches($candidates);
    
    say "\nPruned Branches:";
    foreach my $branch (@$pruned) {
        say "  " . $branch->{'name'} . " - content length: " . 
            $branch->{'content_length'} . ", child count: " . 
            $branch->{'child_count'} . ", reasons: " . 
            join(", ", @{$branch->{'reasons'}});
    }
    
    say "\nFinal Tree Structure:";
    say $tree->to_string();
}

# Function to explain tree balancing concepts
sub explain_tree_balancing {
    say "\n=== Dynamic Tree Balancing ===\n";
    
    say "A framework for maintaining optimal knowledge tree structure over time,";
    say "ensuring efficient organization, access, and evolution of knowledge.";
    
    say "\n--- Tree Balance Constants ---\n";
    
    say "Optimal Branching Factor:";
    say "  Root level: " . $TREE_CONSTANTS->{'optimal_branching_factor'}->{'root_level'};
    say "  Mid level: " . $TREE_CONSTANTS->{'optimal_branching_factor'}->{'mid_level'};
    say "  Leaf level: " . $TREE_CONSTANTS->{'optimal_branching_factor'}->{'leaf_level'};
    
    say "\nDepth Limits:";
    say "  Minimum depth: " . $TREE_CONSTANTS->{'depth_limits'}->{'min_depth'};
    say "  Maximum depth: " . $TREE_CONSTANTS->{'depth_limits'}->{'max_depth'};
    say "  Optimal depth: " . $TREE_CONSTANTS->{'depth_limits'}->{'optimal_depth'};
    
    say "\n--- Tree Operations ---\n";
    
    foreach my $mode (sort keys %$TREE_OPERATIONS) {
        say ucfirst($mode) . ": " . $TREE_OPERATIONS->{$mode}->{'description'};
    }
    
    say "\n--- Balance Metrics ---\n";
    
    foreach my $metric (sort keys %$BALANCE_METRICS) {
        say ucfirst($metric) . " (weight " . $BALANCE_METRICS->{$metric}->{'weight'} . "): " . 
            $BALANCE_METRICS->{$metric}->{'description'};
    }
}

# Main function
if (!caller) {
    explain_tree_balancing();
    demonstrate_tree_balancing();
}

__END__

=head1 Dynamic Tree Balancing

=head2 Key Concepts

=over

=item * Optimal structural parameters for different tree levels (branching factor, depth)

=item * Measurement of tree balance across multiple metrics (depth ratio, branching uniformity, etc.)

=item * Dynamic redistribution of branches to maintain efficient organization

=item * Pruning of redundant or low-value branches while preserving knowledge integrity

=item * Adaptation of tree structure to actual usage patterns

=item * Fractal self-similarity principles applied to knowledge organization

=back

=head2 Practical Applications

=over

=item * Self-optimizing knowledge repositories that adapt to usage patterns

=item * Prevention of knowledge tree degradation over time

=item * Efficient access to frequently used information

=item * Automatic reorganization based on emerging knowledge structures

=item * Strategic growth planning for evolving knowledge domains

=back

=cut