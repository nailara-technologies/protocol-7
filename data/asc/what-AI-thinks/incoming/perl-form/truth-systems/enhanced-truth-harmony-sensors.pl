#!/usr/bin/perl
use v5.24;
use strict;
use warnings;
use List::Util qw(sum min max);

# Addition to the existing analyze_coherence method to implement the two requested features:
# 1. Contextual Analysis: Incorporating surrounding information to improve contradiction detection
# 2. Dynamic Weighting: Adjusting weights or significance based on statement importance or source reliability

# This code should be integrated into the DatasetSensor package in the original truth-harmony-sensors.pl file

package DatasetSensor;

# Enhanced analyze_coherence with contextual analysis
sub analyze_coherence_enhanced {
    my ($self, $knowledge_context) = @_;
    
    # Core analysis from original implementation
    my $reading = $self->analyze_coherence($knowledge_context);
    
    # 1. Contextual Analysis Enhancement
    $reading = $self->apply_contextual_analysis($reading, $knowledge_context);
    
    # 2. Dynamic Weighting Enhancement
    $reading = $self->apply_dynamic_weighting($reading, $knowledge_context);
    
    return $reading;
}

# 1. Contextual Analysis implementation
sub apply_contextual_analysis {
    my ($self, $reading, $knowledge_context) = @_;
    
    # Extract statements from knowledge context
    my @statements = extract_statements($knowledge_context);
    
    # Context window size - how many surrounding statements to consider
    my $context_window = 3;
    
    # Enhanced contradiction detection with contextual awareness
    my $contradiction_count = 0;
    my $statement_count = scalar @statements;
    
    # Track contradictions with their contextual confidence
    my @contextual_contradictions;
    
    # For each pair of statements that might contradict
    for my $i (0..$#statements-1) {
        for my $j ($i+1..$#statements) {
            # Basic contradiction check (from original implementation)
            my $basic_contradiction = statements_contradict($statements[$i], $statements[$j]);
            
            if ($basic_contradiction) {
                # Collect context around both statements
                my @context_i = get_statement_context(\@statements, $i, $context_window);
                my @context_j = get_statement_context(\@statements, $j, $context_window);
                
                # Evaluate contradiction in context
                my $contextual_confidence = evaluate_contradiction_in_context(
                    $statements[$i], 
                    $statements[$j], 
                    \@context_i, 
                    \@context_j
                );
                
                # Only count as contradiction if contextual confidence is high enough
                if ($contextual_confidence > 0.6) { # Threshold for contextual contradiction
                    $contradiction_count++;
                    push @contextual_contradictions, {
                        'statement1' => $statements[$i],
                        'statement2' => $statements[$j],
                        'confidence' => $contextual_confidence,
                        'context1' => \@context_i,
                        'context2' => \@context_j
                    };
                }
            }
        }
    }
    
    # Calculate coherence score with contextual analysis (0-1, higher is more coherent)
    my $max_possible_contradictions = ($statement_count * ($statement_count - 1)) / 2;
    my $coherence_score = $max_possible_contradictions > 0 
        ? 1 - ($contradiction_count / $max_possible_contradictions)
        : 1;
    
    # Update reading with contextual analysis results
    $reading->{'coherence_score'} = $coherence_score;
    $reading->{'contextual_contradictions'} = \@contextual_contradictions;
    $reading->{'contextual_analysis_applied'} = 1;
    
    # Update frequency analysis based on new coherence score
    foreach my $freq (keys %{$reading->{'resonance_frequencies'}}) {
        $reading->{'resonance_frequencies'}->{$freq} = 
            $coherence_score * (1 - abs(sin($freq * $coherence_score)));
    }
    
    foreach my $freq (keys %{$reading->{'dissonance_frequencies'}}) {
        $reading->{'dissonance_frequencies'}->{$freq} = 
            (1 - $coherence_score) * abs(sin($freq * (1 - $coherence_score)));
    }
    
    return $reading;
}

# Get surrounding context for a statement
sub get_statement_context {
    my ($statements, $index, $window_size) = @_;
    
    my @context;
    
    # Get statements before the target
    my $start = max(0, $index - $window_size);
    for my $i ($start..($index-1)) {
        push @context, $statements->[$i];
    }
    
    # Get statements after the target
    my $end = min(scalar(@$statements) - 1, $index + $window_size);
    for my $i (($index+1)..$end) {
        push @context, $statements->[$i];
    }
    
    return @context;
}

# Evaluate if two statements still contradict when viewed in their respective contexts
sub evaluate_contradiction_in_context {
    my ($statement1, $statement2, $context1, $context2) = @_;
    
    # In a real implementation, this would perform sophisticated NLP analysis
    # to determine if the apparent contradiction is resolved by context
    
    # For example:
    # - Statement 1: "The temperature is rising"
    # - Context 1: "In the northern hemisphere..."
    # - Statement 2: "The temperature is falling"
    # - Context 2: "In the southern hemisphere..."
    # These statements don't contradict when context is considered
    
    # Simulated context-aware contradiction analysis
    my $contextual_confidence = 0.8; # Default high confidence in the contradiction
    
    # Check if contexts provide disambiguation
    my $context_resolves_contradiction = context_provides_disambiguation(
        $statement1, $statement2, $context1, $context2);
    
    if ($context_resolves_contradiction) {
        $contextual_confidence *= 0.3; # Significantly reduce contradiction confidence
    }
    
    # Check if contexts indicate different temporal frames
    my $temporal_difference = contexts_have_temporal_difference($context1, $context2);
    if ($temporal_difference) {
        $contextual_confidence *= 0.5; # Reduce contradiction confidence
    }
    
    # Check if contexts indicate different spatial frames
    my $spatial_difference = contexts_have_spatial_difference($context1, $context2);
    if ($spatial_difference) {
        $contextual_confidence *= 0.5; # Reduce contradiction confidence
    }
    
    return $contextual_confidence;
}

# 2. Dynamic Weighting implementation
sub apply_dynamic_weighting {
    my ($self, $reading, $knowledge_context) = @_;
    
    # Extract statements and sources
    my @statements = extract_statements($knowledge_context);
    my @sources = extract_sources($knowledge_context);
    
    # Calculate weights for statements based on:
    # 1. Source reliability
    # 2. Statement specificity
    # 3. Statement recency
    # 4. Statement corroboration level
    
    my %statement_weights;
    
    foreach my $i (0..$#statements) {
        my $statement = $statements[$i];
        
        # Get source reliability (0-1, higher is more reliable)
        my $source_reliability = get_source_reliability($statement, \@sources);
        
        # Get statement specificity (0-1, higher is more specific)
        my $specificity = calculate_statement_specificity($statement);
        
        # Get statement recency (0-1, higher is more recent)
        my $recency = calculate_statement_recency($statement);
        
        # Get corroboration level (0-1, higher is more corroborated)
        my $corroboration = calculate_corroboration_level($statement, \@statements);
        
        # Calculate overall weight as weighted sum of factors
        my $weight = ($source_reliability * 0.4) + 
                     ($specificity * 0.2) + 
                     ($recency * 0.1) + 
                     ($corroboration * 0.3);
        
        $statement_weights{$i} = $weight;
    }
    
    # Now apply weights to contradiction detection
    my $weighted_contradiction_sum = 0;
    my $weight_sum = 0;
    
    # Re-analyze contradictions using weights
    if (exists $reading->{'contextual_contradictions'}) {
        foreach my $contradiction (@{$reading->{'contextual_contradictions'}}) {
            # Find indices of the contradicting statements
            my $idx1 = find_statement_index($contradiction->{'statement1'}, \@statements);
            my $idx2 = find_statement_index($contradiction->{'statement2'}, \@statements);
            
            # Skip if couldn't find indices
            next if ($idx1 < 0 || $idx2 < 0);
            
            # Calculate combined weight for this contradiction
            my $combined_weight = ($statement_weights{$idx1} + $statement_weights{$idx2}) / 2;
            
            # Add weighted contradiction
            $weighted_contradiction_sum += $contradiction->{'confidence'} * $combined_weight;
            $weight_sum += $combined_weight;
        }
    }
    
    # Calculate weighted coherence score
    my $weighted_coherence_score;
    if ($weight_sum > 0) {
        my $weighted_contradiction_avg = $weighted_contradiction_sum / $weight_sum;
        $weighted_coherence_score = 1 - $weighted_contradiction_avg;
    } else {
        $weighted_coherence_score = $reading->{'coherence_score'};
    }
    
    # Update reading with weighted scores
    $reading->{'weighted_coherence_score'} = $weighted_coherence_score;
    $reading->{'statement_weights'} = \%statement_weights;
    $reading->{'dynamic_weighting_applied'} = 1;
    
    # Optional: Update coherence score to use weighted version
    $reading->{'original_coherence_score'} = $reading->{'coherence_score'};
    $reading->{'coherence_score'} = $weighted_coherence_score;
    
    return $reading;
}

# Find the index of a statement in the statements array
sub find_statement_index {
    my ($statement, $statements) = @_;
    
    for my $i (0..$#$statements) {
        # Simple equality check for example purposes
        # In real implementation, would need more sophisticated matching
        if ($statements->[$i]->{'text'} eq $statement->{'text'}) {
            return $i;
        }
    }
    
    return -1; # Not found
}

# Calculate source reliability based on past accuracy, diversity, etc.
sub get_source_reliability {
    my ($statement, $sources) = @_;
    
    # In a real implementation, this would access historical data on source reliability
    # For demonstration, use simulated reliability
    
    # Find the source for this statement
    my $source = $statement->{'source'} || '';
    
    # Find source in sources list
    foreach my $src (@$sources) {
        if ($src->{'name'} eq $source) {
            # Use stored reliability if available
            return $src->{'reliability'} if exists $src->{'reliability'};
            
            # Otherwise calculate based on available metrics
            my $reliability = 0.5; # Default moderate reliability
            
            # Adjust based on factors like:
            $reliability += 0.1 if $src->{'verified'};          # Verified sources
            $reliability += 0.2 if $src->{'peer_reviewed'};     # Peer-reviewed
            $reliability -= 0.1 if $src->{'conflict_of_interest'}; # Conflicts of interest
            $reliability += 0.1 if $src->{'primary_source'};    # Primary sources
            
            # Ensure in 0-1 range
            $reliability = max(0, min(1, $reliability));
            
            return $reliability;
        }
    }
    
    # Source not found, return default reliability
    return 0.5;
}

# Calculate statement specificity (more specific statements given higher weight)
sub calculate_statement_specificity {
    my ($statement) = @_;
    
    # In a real implementation, this would analyze statement content
    # to determine how specific vs. general it is
    
    # For demonstration, use simulated specificity based on arbitrary metrics
    my $specificity = 0.5; # Default moderate specificity
    
    # Example metrics (in real implementation these would analyze content):
    $specificity += 0.2 if $statement->{'has_quantities'};  # Contains numerical values
    $specificity += 0.1 if $statement->{'has_dates'};       # Contains specific dates
    $specificity += 0.1 if $statement->{'has_locations'};   # Contains specific locations
    $specificity -= 0.2 if $statement->{'has_qualifiers'};  # Contains hedging language
    
    # Ensure in 0-1 range
    return max(0, min(1, $specificity));
}

# Calculate statement recency (more recent statements given higher weight)
sub calculate_statement_recency {
    my ($statement) = @_;
    
    # In a real implementation, this would compare timestamp to current time
    # For demonstration, use simulated recency
    
    my $timestamp = $statement->{'timestamp'} || 0;
    my $current_time = time();
    
    # Calculate recency score (1.0 = very recent, 0.0 = very old)
    my $max_age = 60 * 60 * 24 * 365; # One year in seconds
    my $age = $current_time - $timestamp;
    
    # Linear decay with age, capped at max_age
    my $recency = 1 - min(1, $age / $max_age);
    
    return $recency;
}

# Calculate corroboration level (statements corroborated by multiple sources given higher weight)
sub calculate_corroboration_level {
    my ($statement, $statements) = @_;
    
    # In a real implementation, this would analyze semantic similarity
    # to find corroborating statements from different sources
    
    # For demonstration, use simulated corroboration
    my $corroboration_count = 0;
    
    # Count statements that corroborate this statement
    foreach my $other_statement (@$statements) {
        # Skip if same statement
        next if $statement eq $other_statement;
        
        # Skip if same source
        next if ($statement->{'source'} eq $other_statement->{'source'});
        
        # Check if statements corroborate
        if (statements_corroborate($statement, $other_statement)) {
            $corroboration_count++;
        }
    }
    
    # Calculate corroboration score (0-1)
    my $max_corroboration = 5; # Cap at 5 corroborating statements
    my $corroboration_score = min(1, $corroboration_count / $max_corroboration);
    
    return $corroboration_score;
}

# Placeholder functions for context-based contradiction analysis
sub context_provides_disambiguation { return rand() < 0.3; }
sub contexts_have_temporal_difference { return rand() < 0.2; }
sub contexts_have_spatial_difference { return rand() < 0.2; }
sub statements_corroborate { return rand() < 0.4; } # 40% chance of corroboration

# To integrate this enhanced functionality, modify the DatasetSensor::take_reading
# method to call analyze_coherence_enhanced instead of analyze_coherence when
# analyzing coherence in knowledge context:

=begin INTEGRATION_CODE
# In DatasetSensor::take_reading method, replace:
if ($self->{'type'} eq 'coherence_sensor') {
    $reading = $self->analyze_coherence($knowledge_context);
}

# With:
if ($self->{'type'} eq 'coherence_sensor') {
    $reading = $self->analyze_coherence_enhanced($knowledge_context);
}
=end INTEGRATION_CODE

package main;

# Example usage of enhanced coherence analysis
sub demonstrate_enhanced_analysis {
    say "\n=== Demonstrating Enhanced Truth Harmony Analysis ===\n";
    
    # Create a sample knowledge context with statements
    my $knowledge_context = create_sample_knowledge_context();
    
    # Create coherence sensor
    my $sensor = DatasetSensor->new('coherence_sensor');
    
    # Analyze with original method
    my $basic_reading = $sensor->analyze_coherence($knowledge_context);
    say "Basic coherence score: " . sprintf("%.2f", $basic_reading->{'coherence_score'});
    
    # Analyze with enhanced method
    my $enhanced_reading = $sensor->analyze_coherence_enhanced($knowledge_context);
    say "Enhanced coherence score: " . sprintf("%.2f", $enhanced_reading->{'coherence_score'});
    say "Weighted coherence score: " . sprintf("%.2f", $enhanced_reading->{'weighted_coherence_score'});
    
    # Show weighted statements
    say "\nStatement weights:";
    foreach my $idx (sort keys %{$enhanced_reading->{'statement_weights'}}) {
        say "  Statement $idx: " . sprintf("%.2f", $enhanced_reading->{'statement_weights'}->{$idx});
    }
    
    # Show contextual contradictions
    say "\nContextual contradictions:";
    foreach my $contradiction (@{$enhanced_reading->{'contextual_contradictions'}}) {
        say "  Statements: \"" . $contradiction->{'statement1'}->{'text'} . 
            "\" and \"" . $contradiction->{'statement2'}->{'text'} . "\"";
        say "  Confidence: " . sprintf("%.2f", $contradiction->{'confidence'});
        say "";
    }
}

# Create sample knowledge context for demonstration
sub create_sample_knowledge_context {
    my @statements;
    
    # Create some statements with different properties
    push @statements, {
        'text' => "The atmospheric CO2 increased by 2.5ppm in 2023",
        'source' => "NOAA",
        'timestamp' => time() - (60 * 60 * 24 * 30), # 30 days ago
        'coordinates' => {
            'conceptual' => 0.3,
            'temporal' => 0.9
        },
        'has_quantities' => 1,
        'has_dates' => 1,
        'has_locations' => 0,
        'has_qualifiers' => 0
    };
    
    push @statements, {
        'text' => "Global temperatures might potentially show an increasing trend",
        'source' => "Climate Blog",
        'timestamp' => time() - (60 * 60 * 24 * 180), # 180 days ago
        'coordinates' => {
            'conceptual' => 0.4,
            'temporal' => 0.7
        },
        'has_quantities' => 0,
        'has_dates' => 0,
        'has_locations' => 0,
        'has_qualifiers' => 1
    };
    
    push @statements, {
        'text' => "The Paris Agreement set a target of 1.5°C maximum warming",
        'source' => "UN",
        'timestamp' => time() - (60 * 60 * 24 * 365 * 2), # 2 years ago
        'coordinates' => {
            'conceptual' => 0.5,
            'temporal' => 0.5
        },
        'has_quantities' => 1,
        'has_dates' => 0,
        'has_locations' => 1,
        'has_qualifiers' => 0
    };
    
    # Create sources
    my @sources = (
        {
            'name' => "NOAA",
            'reliability' => 0.9,
            'verified' => 1,
            'peer_reviewed' => 1,
            'conflict_of_interest' => 0,
            'primary_source' => 1
        },
        {
            'name' => "Climate Blog",
            'reliability' => 0.6,
            'verified' => 0,
            'peer_reviewed' => 0,
            'conflict_of_interest' => 0,
            'primary_source' => 0
        },
        {
            'name' => "UN",
            'reliability' => 0.85,
            'verified' => 1,
            'peer_reviewed' => 0,
            'conflict_of_interest' => 0,
            'primary_source' => 0
        }
    );
    
    return {
        'statements' => \@statements,
        'sources' => \@sources
    };
}

# For standalone testing
if (!caller) {
    demonstrate_enhanced_analysis();
}

1; # Return true
