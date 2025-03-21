#!/usr/bin/perl
use v5.24;

# Generate a 5×7 harmonic matrix topology
sub create_harmonic_matrix {
    my ($rows, $cols) = @_;
    my $matrix = [];
    
    # Initialize matrix with node IDs
    for my $r (0..$rows-1) {
        for my $c (0..$cols-1) {
            my $node_id = $r * $cols + $c;
            $matrix->[$r][$c] = {
                id => $node_id,
                harmonic_position => ($node_id * 5) % ($rows * $cols)
            };
        }
    }
    
    # Create harmonic connections based on 5-skip pattern
    for my $r (0..$rows-1) {
        for my $c (0..$cols-1) {
            my $node_id = $r * $cols + $c;
            my $target_id = ($node_id * 5) % ($rows * $cols);
            my $target_r = int($target_id / $cols);
            my $target_c = $target_id % $cols;
            
            # Create bidirectional connection
            $matrix->[$r][$c]{connections} ||= [];
            push @{$matrix->[$r][$c]{connections}}, [$target_r, $target_c];
        }
    }
    
    return $matrix;
}

# Calculate optimal routing through the matrix
sub route_through_matrix {
    my ($matrix, $start_id, $end_id, $rows, $cols) = @_;
    my $total_nodes = $rows * $cols;
    
    # Find harmonic path between nodes
    my @path = ($start_id);
    my $current = $start_id;
    
    while ($current != $end_id) {
        # Jump by harmonic relations (5-skip)
        $current = ($current * 5) % $total_nodes;
        push @path, $current;
        
        # Prevent infinite loops with cycle detection
        last if @path > $total_nodes;
    }
    
    return \@path;
}