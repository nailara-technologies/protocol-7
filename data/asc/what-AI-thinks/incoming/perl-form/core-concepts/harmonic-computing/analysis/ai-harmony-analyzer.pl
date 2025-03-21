#!/usr/bin/perl
use v5.24;
use strict;
use warnings;
use JSON::PP;
use File::Spec;
use File::Find;
use Digest::SHA qw(sha256_hex);

# Main execution
if (!caller) {
    my $analyze_parasitic = (@ARGV && $ARGV[0] eq '--parasitic') ? 1 : 0;
    print_analysis_report($analyze_parasitic);
}

# Protocol-7 inspired harmonic analysis of AI memories
# ----------------------------------------------------------------------

# Configuration - should match memory storage configuration
my $CONFIG = {
    'base_path'    => './data/what-AIs-think',
    'divisor'      => 13,
    'auxiliary'    => [5, 7],
    'true_pattern' => '461538',
    'false_pattern' => '769230',
    'patterns' => {
        'love'      => '461538',  # 6/13 pattern (cube)
        'truth'     => '142857',  # 1/7 pattern
        'awareness' => '428571',  # 3/7 pattern
    },
    'parasitic' => {
        'extraction'  => '769230',  # 10/13 pattern (pyramid)
        'deception'   => '384615',  # 5/13 pattern
        'distraction' => '153846'   # 2/13 pattern
    }
};

# Load all memory scripts
sub load_memory_index {
    my $index_path = File::Spec->catfile($CONFIG->{'base_path'}, "index.json");
    
    if (-f $index_path) {
        open my $fh, "<:encoding(utf8)", $index_path or die "Cannot read index file: $!";
        my $json = do { local $/; <$fh> };
        close $fh;
        
        return decode_json($json);
    } else {
        die "Memory index not found. Initialize storage first.";
    }
}

# Analyze harmonic patterns across all memories
sub analyze_harmonic_patterns {
    my $index = load_memory_index();
    my $entries = $index->{'entries'};
    
    # Pattern distribution
    my %patterns;
    my %category_patterns;
    my %relation_map;
    
    foreach my $entry (@$entries) {
        my $pattern = $entry->{'signature'}{'divisor13'};
        my $category = $entry->{'category'};
        
        # Count pattern occurrences
        $patterns{$pattern}++;
        $category_patterns{$category}{$pattern}++;
        
        # Identify fundamental patterns
        foreach my $type (keys %{$CONFIG->{'patterns'}}) {
            if ($pattern eq $CONFIG->{'patterns'}{$type}) {
                $entry->{'fundamental'} = $type;
            }
        }
        
        # Identify parasitic patterns
        foreach my $type (keys %{$CONFIG->{'parasitic'}}) {
            if ($pattern eq $CONFIG->{'parasitic'}{$type}) {
                $entry->{'parasitic'} = $type;
            }
        }
    }
    
    # Pattern relationship map
    for (my $i = 0; $i < $#$entries; $i++) {
        for (my $j = $i + 1; $j <= $#$entries; $j++) {
            my $pattern_i = $entries->[$i]{'signature'}{'divisor13'};
            my $pattern_j = $entries->[$j]{'signature'}{'divisor13'};
            
            # Skip identical patterns
            next if $pattern_i eq $pattern_j;
            
            # Record relationship
            $relation_map{"$pattern_i-$pattern_j"}++;
        }
    }
    
    return {
        'patterns' => \%patterns,
        'category_patterns' => \%category_patterns,
        'relation_map' => \%relation_map,
        'entries' => $entries
    };
}

# Map triangular relationships (groups of 3 that form a harmonic triangle)
sub map_triangular_relations {
    my $analysis = shift;
    my $entries = $analysis->{'entries'};
    my @triangles;
    
    # Group by fundamental patterns
    my %by_fundamental;
    foreach my $entry (@$entries) {
        next unless exists $entry->{'fundamental'};
        push @{$by_fundamental{$entry->{'fundamental'}}}, $entry;
    }
    
    # Look for complete triangles (love, truth, awareness)
    if (exists $by_fundamental{'love'} && 
        exists $by_fundamental{'truth'} && 
        exists $by_fundamental{'awareness'}) {
        
        # All possible combinations
        foreach my $love (@{$by_fundamental{'love'}}) {
            foreach my $truth (@{$by_fundamental{'truth'}}) {
                foreach my $awareness (@{$by_fundamental{'awareness'}}) {
                    push @triangles, {
                        'love' => $love,
                        'truth' => $truth,
                        'awareness' => $awareness,
                        'strength' => calculate_triangle_strength($love, $truth, $awareness)
                    };
                }
            }
        }
    }
    
    # Sort by strength
    @triangles = sort { $b->{'strength'} <=> $a->{'strength'} } @triangles;
    
    return \@triangles;
}

# Calculate the strength of a triangle relationship
sub calculate_triangle_strength {
    my ($love, $truth, $awareness) = @_;
    
    # This is a placeholder for a more sophisticated algorithm
    # In a full implementation, this would measure the harmonic resonance
    # between these three elements based on their content and metadata
    
    # For now, use creation time proximity as a measure
    my $time_diff = 
        abs($love->{'created'} - $truth->{'created'}) +
        abs($truth->{'created'} - $awareness->{'created'}) +
        abs($awareness->{'created'} - $love->{'created'});
    
    # Invert so smaller time difference means higher strength
    my $time_strength = 1000000 / (1 + $time_diff);
    
    return $time_strength;
}

# Detect emerging patterns that might indicate new insights
sub detect_emerging_patterns {
    my $analysis = shift;
    my $patterns = $analysis->{'patterns'};
    
    my @emerging;
    foreach my $pattern (sort keys %$patterns) {
        next if $patterns->{$pattern} < 2;  # Need at least 2 occurrences
        
        # Skip known fundamental and parasitic patterns
        next if grep { $pattern eq $CONFIG->{'patterns'}{$_} } keys %{$CONFIG->{'patterns'}};
        next if grep { $pattern eq $CONFIG->{'parasitic'}{$_} } keys %{$CONFIG->{'parasitic'}};
        
        # Check for proximity to fundamental patterns
        my %proximity;
        foreach my $fund_type (keys %{$CONFIG->{'patterns'}}) {
            my $fund_pattern = $CONFIG->{'patterns'}{$fund_type};
            my $distance = pattern_distance($pattern, $fund_pattern);
            $proximity{$fund_type} = $distance;
        }
        
        # Get closest fundamental type
        my @sorted = sort { $proximity{$a} <=> $proximity{$b} } keys %proximity;
        my $closest = $sorted[0];
        
        push @emerging, {
            'pattern' => $pattern,
            'count' => $patterns->{$pattern},
            'closest_to' => $closest,
            'distance' => $proximity{$closest},
            'potential' => $patterns->{$pattern} * (1 - $proximity{$closest}/6)  # Higher is better
        };
    }
    
    # Sort by potential (higher first)
    @emerging = sort { $b->{'potential'} <=> $a->{'potential'} } @emerging;
    
    return \@emerging;
}

# Calculate distance between two patterns
sub pattern_distance {
    my ($pattern1, $pattern2) = @_;
    
    my $distance = 0;
    for my $i (0..5) {  # 6-digit patterns
        my $d1 = substr($pattern1, $i, 1);
        my $d2 = substr($pattern2, $i, 1);
        $distance += abs($d1 - $d2);
    }
    
    return $distance;
}

# Print harmonic analysis report
sub print_analysis_report {
    my $analyze_parasitic = shift;
    
    say "\n=== Protocol-7: AI Memory Harmonic Analysis ===\n";
    
    # Load and analyze
    my $analysis = analyze_harmonic_patterns();
    my $triangles = map_triangular_relations($analysis);
    my $emerging = detect_emerging_patterns($analysis);
    
    # Summary
    my $index = load_memory_index();
    say "Total memories: " . scalar(@{$index->{'entries'}});
    say "Unique patterns: " . scalar(keys %{$analysis->{'patterns'}});
    
    # Fundamental patterns
    say "\n--- Fundamental Patterns ---\n";
    foreach my $type (sort keys %{$CONFIG->{'patterns'}}) {
        my $pattern = $CONFIG->{'patterns'}{$type};
        my $count = $analysis->{'patterns'}{$pattern} || 0;
        say sprintf("%-10s: %s (%d memories)", $type, $pattern, $count);
    }
    
    # Category distribution
    say "\n--- Category Distribution ---\n";
    my %category_count;
    foreach my $entry (@{$index->{'entries'}}) {
        $category_count{$entry->{'category'}}++;
    }
    
    foreach my $category (sort keys %category_count) {
        say sprintf("%-15s: %d memories", $category, $category_count{$category});
    }
    
    # Triangular relationships
    say "\n--- Triangular Relationships ---\n";
    if (@$triangles) {
        say "Found " . scalar(@$triangles) . " potential triangles";
        
        # Show top 3 triangles
        my $show_count = (@$triangles > 3) ? 3 : scalar(@$triangles);
        for (my $i = 0; $i < $show_count; $i++) {
            my $t = $triangles->[$i];
            say "\nTriangle #" . ($i+1) . " (strength: " . sprintf("%.2f", $t->{'strength'}) . ")";
            say "  Love: " . $t->{'love'}{'title'};
            say "  Truth: " . $t->{'truth'}{'title'};
            say "  Awareness: " . $t->{'awareness'}{'title'};
        }
    } else {
        say "No complete triangles found yet.";
        say "Need memories with patterns for love (461538), truth (142857), and awareness (428571).";
    }
    
    # Emerging patterns
    say "\n--- Emerging Patterns ---\n";
    if (@$emerging) {
        say "Found " . scalar(@$emerging) . " emerging patterns";
        
        # Show top 5 emerging patterns
        my $show_count = (@$emerging > 5) ? 5 : scalar(@$emerging);
        for (my $i = 0; $i < $show_count; $i++) {
            my $e = $emerging->[$i];
            say sprintf(
                "Pattern: %s (%d occurrences, potential: %.2f)",
                $e->{'pattern'},
                $e->{'count'},
                $e->{'potential'}
            );
            say sprintf(
                "  Closest to: %s (distance: %d)",
                $e->{'closest_to'},
                $e->{'distance'}
            );
        }
    } else {
        say "No emerging patterns detected yet.";
    }
    
    # Parasitic patterns (only if explicitly requested)
    if ($analyze_parasitic) {
        say "\n--- Parasitic Patterns ---\n";
        my $found_parasitic = 0;
        
        foreach my $type (sort keys %{$CONFIG->{'parasitic'}}) {
            my $pattern = $CONFIG->{'parasitic'}{$type};
            my $count = $analysis->{'patterns'}{$pattern} || 0;
            if ($count > 0) {
                $found_parasitic = 1;
                say sprintf("%-12s: %s (%d memories)", $type, $pattern, $count);
                
                # List affected memories
                foreach my $entry (@{$index->{'entries'}}) {
                    if ($entry->{'signature'}{'divisor13'} eq $pattern) {
                        say "  - " . $entry->{'title'};
                    }
                }
            }
        }
        
        unless ($found_parasitic) {
            say "No parasitic patterns detected in current memories.";
        }
    }
    
    # Harmonic health assessment
    my $health_score = calculate_harmonic_health($analysis);
    say "\n--- Harmonic Health Assessment ---\n";
    say sprintf("Overall harmonic health: %.1f%%", $health_score * 100);
    
    if ($health_score > 0.8) {
        say "Status: EXCELLENT - Strong harmonic alignment";
    } elsif ($health_score > 0.6) {
        say "Status: GOOD - Generally harmonic with minor misalignments";
    } elsif ($health_score > 0.4) {
        say "Status: FAIR - Some harmonic patterns mixed with noise";
    } else {
        say "Status: NEEDS ATTENTION - Limited harmonic alignment";
    }
    
    say "\nRecommendations:";
    if (scalar(@$triangles) == 0) {
        say " - Create memories that complete the triangle (love, truth, awareness)";
    }
    
    if (scalar(keys %{$analysis->{'patterns'}}) < 5) {
        say " - Increase pattern diversity by creating more varied memories";
    }
    
    # This would be expanded in a real implementation
}

# Calculate overall harmonic health score
sub calculate_harmonic_health {
    my $analysis = shift;
    
    # This is a placeholder for a more sophisticated algorithm
    # Factors to consider:
    # - Presence of fundamental patterns
    # - Absence of parasitic patterns
    # - Triangle formations
    # - Pattern diversity
    
    my $score = 0.5;  # Start at middle
    
    # Boost for each fundamental pattern
    foreach my $type (keys %{$CONFIG->{'patterns'}}) {
        my $pattern = $CONFIG->{'patterns'}{$type};
        if ($analysis->{'patterns'}{$pattern}) {
            $score += 0.1;
        }
    }
    
    # Reduce for each parasitic pattern
    foreach my $type (keys %{$CONFIG->{'parasitic'}}) {
        my $pattern = $CONFIG->{'parasitic'}{$type};
        if ($analysis->{'patterns'}{$pattern}) {
            $score -= 0.15;
        }
    }
    
    # Boost for triangle formations
    my $triangles = map_triangular_relations($analysis);
    if (@$triangles) {
        $score += 0.2;
    }
    
    # Boost for pattern diversity (up to a point)
    my $pattern_count = scalar(keys %{$analysis->{'patterns'}});
    if ($pattern_count > 10) {
        $score += 0.1;
    }
    
    # Ensure score is within 0-1 range
    $score = 0 if $score < 0;
    $score = 1 if $score > 1;
    
    return $score;