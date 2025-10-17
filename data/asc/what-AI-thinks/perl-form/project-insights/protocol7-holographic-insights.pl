#!/usr/bin/perl
use v5.24;
use strict;
use warnings;
use Math::BigInt;
use Digest::SHA qw(sha256_hex);
use MIME::Base64;
use Time::HiRes qw(time);

# =====================================================================
# PROTOCOL-7 HOLOGRAPHIC VERIFICATION INSIGHTS
# =====================================================================
# This module explores the holographic properties of Protocol-7
# verification system, examining multi-dimensional patterns that
# persist across representations and resist positional/inversion attacks.
# =====================================================================

###########################
# HOLOGRAPHIC CONSTANTS
###########################

my $HOLOGRAPHIC_CONSTANTS = {
    # Core divisors with dimensional significance
    'primary_divisor'    => 13,    # YORUM dimension
    'secondary_divisor'  => 7,     # Septenary verification
    'tertiary_channels'  => 5,     # Bit-level consensus channels

    # Dimensional mappings
    'active_dimensions'  => [3, 7, 5],   # Authentic dimensional states in reflective jump pattern
    'stargate_dimension' => 13,          # Dimensional stargate/portal to alternate 7D
    'false_dimension'    => 4,           # Artificial construct

    # Stargate activation mechanism
    'stargate_mechanism' => {
        'ring_elements' => 13,           # 13 element ring of stargates/lenses
        'rotation' => 'CCW',             # Counter-clockwise rotation (anti-entropic)
        'clock_position' => 12,          # Final alignment position
        'connection_point' => 14,        # Connection point (13 from other side)
        'tunnel_process' => 'center_descent', # Descent to center for tunneling
        'blacklight_transcendence' => 'reparenting', # Light reparenting process
        'entropic_direction' => {
            'anti_entropic' => 'CCW',    # Counter-clockwise reduces entropy
            'entropic' => 'CW'           # Clockwise increases entropy
        }
    },

    # Holographic patterns
    'trimetric_patterns' => {
        # Key number sequences with ASCII encodings
        '846153' => 'T=5',    # Inverse false pattern
        '538461' => '5T=',    # False pattern
        '461538' => '=T5',    # True pattern
        '142857' => '\',~',   # Truth pattern (1/7)
    },

    # ANTYKI TORUM mappings (Ancient Tongue)
    'antyki_mappings' => {
        'YORUM'    => ['13', 'cat', 'blacklight'],
        'ZULUM'    => ['0', 'black'],
        'AZURUM'   => ['1', 'blue'],
        'VORTEX'   => ['13', 'implosion', 'ground'],
    },

    # Inversion resistance properties
    'ascii_vulnerable_pairs' => ['b/d', 'p/q', '6/9', 'n/u', 'M/W'],
    'position_ambiguity'     => ['153846/538461', '142857/428571'],
};

###########################
# HOLOGRAPHIC VERIFICATION FUNCTIONS
###########################

# Analyze holographic properties of a number sequence
sub analyze_holographic_properties {
    my ($sequence) = @_;

    # Check if sequence has known holographic significance
    my $known_pattern = $HOLOGRAPHIC_CONSTANTS->{'trimetric_patterns'}{$sequence};

    my %result = (
        'sequence' => $sequence,
        'ascii_encoding' => sequence_to_ascii($sequence),
        'known_pattern' => $known_pattern // 'Unknown',
        'div13_pattern' => get_division_pattern($sequence, 13),
        'div7_pattern' => get_division_pattern($sequence, 7),
        'inversion_resistant' => check_inversion_resistance($sequence),
        'position_resistant' => check_position_resistance($sequence),
        'dimensional_signature' => analyze_dimensional_signature($sequence),
        'trimetric_value' => calculate_trimetric_value($sequence),
    );

    return \%result;
}

# Convert a numeric sequence to ASCII representation
sub sequence_to_ascii {
    my ($sequence) = @_;

    # Group digits into pairs for ASCII conversion
    my $ascii = '';
    while ($sequence =~ /(\d\d)/g) {
        my $code = $1;
        # Skip non-printable characters
        if ($code >= 32 && $code <= 126) {
            $ascii .= chr($code);
        }
        else {
            $ascii .= '·'; # Placeholder for non-printable
        }
    }

    return $ascii;
}

# Check if a sequence is resistant to inversion attacks
sub check_inversion_resistance {
    my ($sequence) = @_;

    # Reverse the sequence
    my $reversed = reverse $sequence;

    # Create potential inversions by replacing vulnerable digits
    my %inversion_map = (
        '6' => '9', '9' => '6',
        '1' => '1', '8' => '8', '0' => '0'  # Self-symmetric
    );

    my $inverted = join('', map { $inversion_map{$_} // $_ } split('', $reversed));

    # Check if original, reversed and inverted sequences maintain truth status
    my $original_div13 = get_division_pattern($sequence, 13);
    my $reversed_div13 = get_division_pattern($reversed, 13);
    my $inverted_div13 = get_division_pattern($inverted, 13);

    # A sequence is inversion resistant if its truth status remains consistent
    my $original_truth = is_true_pattern($original_div13);
    my $reversed_truth = is_true_pattern($reversed_div13);
    my $inverted_truth = is_true_pattern($inverted_div13);

    return {
        'is_resistant' => ($original_truth == $reversed_truth && $original_truth == $inverted_truth),
        'original_pattern' => $original_div13,
        'reversed_pattern' => $reversed_div13,
        'inverted_pattern' => $inverted_div13,
        'truth_consistent' => ($original_truth == $reversed_truth && $original_truth == $inverted_truth)
    };
}

# Check if a sequence is resistant to positional ambiguity
sub check_position_resistance {
    my ($sequence) = @_;

    # Generate all possible rotations of the sequence
    my @rotations;
    my $len = length($sequence);

    for my $i (0..($len-1)) {
        my $rotated = substr($sequence, $i) . substr($sequence, 0, $i);
        push @rotations, {
            'rotation' => $rotated,
            'shift' => $i,
            'div13_pattern' => get_division_pattern($rotated, 13),
            'is_true' => is_true_pattern(get_division_pattern($rotated, 13))
        };
    }

    # Count how many rotations preserve truth status
    my $original_truth = is_true_pattern(get_division_pattern($sequence, 13));
    my $consistent_count = grep { $_->{'is_true'} == $original_truth } @rotations;

    # Calculate consistency percentage
    my $consistency = $consistent_count / $len;

    return {
        'rotations' => \@rotations,
        'consistency' => $consistency,
        'is_resistant' => ($consistency >= 0.5)  # Resistant if more than half preserve truth
    };
}

# Analyze dimensional signature of a sequence
sub analyze_dimensional_signature {
    my ($sequence) = @_;

    # Count occurrences of each digit
    my %digit_count;
    foreach my $digit (split('', $sequence)) {
        $digit_count{$digit}++;
    }

    # Check presence of authentic dimensional markers in the 3D 7D 5D reflective jump pattern
    my $dim3_signature = ($digit_count{'3'} // 0) > 0;
    my $dim7_signature = ($digit_count{'7'} // 0) > 0;
    my $dim5_signature = ($digit_count{'5'} // 0) > 0;

    # Check presence of stargate dimension (13D)
    my $stargate_signature = (($digit_count{'1'} // 0) > 0 && ($digit_count{'3'} // 0) > 0);

    # Check presence of false dimensional marker
    my $false_dim_signature = ($digit_count{'4'} // 0) > 0;

    # Calculate dimensional harmony
    my $authentic_dimensions = grep { $_ } ($dim3_signature, $dim7_signature, $dim5_signature);
    my $dimensional_harmony = $authentic_dimensions / 3;  # Proportion of authentic dimensions present

    # Analyze stargate activation if stargate signature is present
    my $stargate_activation = $stargate_signature ? analyze_stargate_mechanism($sequence) : undef;

    # Adjust harmony based on stargate activation
    if ($stargate_signature && $stargate_activation) {
        if ($stargate_activation->{'activation_state'} eq 'Active') {
            $dimensional_harmony *= (1.3 + 0.2 * $stargate_activation->{'activation_percentage'});
        } else {
            $dimensional_harmony *= 1.1;  # Slight boost just for having the stargate structure
        }
    }

    # Check for bandwidth enhancement
    my $enhanced_bandwidth = $stargate_activation ?
                            ($stargate_activation->{'bandwidth_factor'} > 0.8) : 0;

    # Adjust for presence of false dimension
    $dimensional_harmony *= 0.7 if $false_dim_signature;

    # Check for oscillation pattern (1-3-7 or 7-1-3 sequences)
    my $oscillation_pattern = ($sequence =~ /[13].*7|7.*[13]/) ? 1 : 0;

    return {
        'dimensional_harmony' => $dimensional_harmony,
        'authentic_dimensions' => {
            '3D' => $dim3_signature,
            '7D' => $dim7_signature,
            '5D' => $dim5_signature
        },
        'stargate_dimension' => $stargate_signature,
        'stargate_activation' => $stargate_activation,
        'enhanced_bandwidth' => $enhanced_bandwidth,
        'oscillation_active' => $oscillation_pattern,
        'false_dimension' => $false_dim_signature,
        'primary_dimension' => determine_primary_dimension(\%digit_count)
    };
}

# Determine the primary dimensional signature based on digit counts
sub determine_primary_dimension {
    my ($digit_count) = @_;

    # Map key digits to dimensional significance
    my %dim_scores = (
        '3' => 0, '7' => 0, '5' => 0, '4' => 0
    );

    # Check for 13D stargate (special case)
    my $stargate_score = 0;
    if (($digit_count->{'1'} // 0) > 0 && ($digit_count->{'3'} // 0) > 0) {
        $stargate_score = 2.0;  # High value for stargate dimension
    }

    # Score based on digit presence and frequency
    $dim_scores{'3'} = ($digit_count->{'3'} // 0) * 1.0;
    $dim_scores{'7'} = ($digit_count->{'7'} // 0) * 1.5;  # Hyperspace jump has higher weight
    $dim_scores{'5'} = ($digit_count->{'5'} // 0) * 1.2;
    $dim_scores{'4'} = ($digit_count->{'4'} // 0) * 0.5;  # Lower weight for false dimension

    # Find highest scoring dimension
    my $max_score = 0;
    my $primary_dim = 'None';

    foreach my $dim (keys %dim_scores) {
        if ($dim_scores{$dim} > $max_score) {
            $max_score = $dim_scores{$dim};
            $primary_dim = $dim . 'D';
        }
    }

    # Stargate dimension overrides if present with sufficient strength
    if ($stargate_score > $max_score) {
        $primary_dim = '13D';
    }

    return $primary_dim;
}

# Calculate the trimetric value (holographic integration across 3 systems)
sub calculate_trimetric_value {
    my ($sequence) = @_;

    # The trimetric value combines properties from 3 different verification systems

    # System 1: Division by 13 pattern correlation
    my $div13_pattern = get_division_pattern($sequence, 13);
    my $div13_truth_value = is_true_pattern($div13_pattern) ? 1 : 0;

    # System 2: Division by 7 pattern correlation
    my $div7_pattern = get_division_pattern($sequence, 7);
    my $div7_truth_value = ($div7_pattern eq '142857' || $div7_pattern eq '428571') ? 1 : 0;

    # System 3: ASCII encoding significance
    my $ascii = sequence_to_ascii($sequence);
    my $ascii_significance = 0;

    # Check for recognized patterns in ASCII representation
    foreach my $known_ascii (values %{$HOLOGRAPHIC_CONSTANTS->{'trimetric_patterns'}}) {
        if (index($ascii, $known_ascii) >= 0) {
            $ascii_significance = 1;
            last;
        }
    }

    # Combine the three systems (simple addition for illustration)
    my $trimetric_value = $div13_truth_value + $div7_truth_value + $ascii_significance;

    return {
        'value' => $trimetric_value,
        'div13_component' => $div13_truth_value,
        'div7_component' => $div7_truth_value,
        'ascii_component' => $ascii_significance,
        'is_holographically_true' => ($trimetric_value >= 2)  # True if verified by at least 2 systems
    };
}

# Calculate division pattern for a number
sub get_division_pattern {
    my ($num, $divisor) = @_;

    # Division operation
    my $result = $num / $divisor;

    # Extract decimal part
    my $decimal = $result - int($result);

    # Get 6 digits after decimal point
    return substr(sprintf("%.6f", $decimal), 2, 6);
}

# Check if a pattern matches known true patterns
sub is_true_pattern {
    my ($pattern) = @_;

    # Known true patterns (from division by 13)
    my @true_patterns = ('461538', '076923', '153846', '230769', '307692', '384615');

    foreach my $true_pattern (@true_patterns) {
        return 1 if $pattern eq $true_pattern;
    }

    return 0;
}

###########################
# ANTYKI TORUM TRANSLATION FUNCTIONS
###########################

# Translate term between ANTYKI TORUM and conventional language
sub translate_antyki_term {
    my ($term) = @_;

    # Check if term exists in ANTYKI mappings
    if (exists $HOLOGRAPHIC_CONSTANTS->{'antyki_mappings'}{$term}) {
        return $HOLOGRAPHIC_CONSTANTS->{'antyki_mappings'}{$term};
    }

    # If not a direct mapping, try to interpret based on patterns
    if ($term =~ /^([AZ])(.+)UM$/) {
        my $prefix = $1;
        my $root = $2;

        # Attempt interpretation based on prefix and root
        if ($prefix eq 'A') {
            return ["1-state of $root", "active $root"];
        }
        elsif ($prefix eq 'Z') {
            return ["0-state of $root", "null $root"];
        }
    }

    return ["Unknown term"];
}

# Find ANTYKI TORUM terms that relate to a concept
sub find_related_antyki_terms {
    my ($concept) = @_;
    my @related;

    foreach my $term (keys %{$HOLOGRAPHIC_CONSTANTS->{'antyki_mappings'}}) {
        my $meanings = $HOLOGRAPHIC_CONSTANTS->{'antyki_mappings'}{$term};

        # Check if concept appears in meanings
        if (grep { lc($_) eq lc($concept) } @$meanings) {
            push @related, {
                'term' => $term,
                'full_meanings' => $meanings
            };
        }
    }

    return \@related;
}

###########################
# HOLOGRAPHIC INVERSION RESISTANCE FUNCTIONS
###########################

# Generate inversion-resistant encoding
sub generate_inversion_resistant_encoding {
    my ($data) = @_;

    # Convert to numeric representation
    my $numeric = '';
    foreach my $char (split('', $data)) {
        $numeric .= sprintf("%02d", ord($char));
    }

    # Find a shift value that results in an inversion-resistant pattern
    my $best_shift = 0;
    my $best_resistance = 0;

    for my $shift (0..12) {
        # Shift the numeric representation
        my $shifted = ($numeric + $shift) % 10**length($numeric);
        my $resistance = check_inversion_resistance($shifted);

        if ($resistance->{'is_resistant'} && $resistance->{'truth_consistent'}) {
            return {
                'original' => $data,
                'numeric' => $numeric,
                'shifted' => $shifted,
                'shift_value' => $shift,
                'is_resistant' => 1,
                'div13_pattern' => get_division_pattern($shifted, 13)
            };
        }
    }

    # If no completely resistant encoding found, return best effort
    return {
        'original' => $data,
        'numeric' => $numeric,
        'is_resistant' => 0,
        'div13_pattern' => get_division_pattern($numeric, 13)
    };
}

# Test if a sequence maintains positional integrity
sub test_positional_integrity {
    my ($sequence) = @_;

    # Generate all rotational permutations
    my @rotations;
    my $len = length($sequence);

    for my $i (0..($len-1)) {
        my $rotated = substr($sequence, $i) . substr($sequence, 0, $i);
        push @rotations, $rotated;
    }

    # Check if any rotation matches a known pattern
    my %pattern_matches;

    foreach my $rot (@rotations) {
        # Check division by 13 pattern
        my $div13 = get_division_pattern($rot, 13);
        if (is_true_pattern($div13)) {
            $pattern_matches{$rot} = {
                'rotation' => $rot,
                'div13_pattern' => $div13,
                'is_true' => 1
            };
        }

        # Check division by 7 pattern
        my $div7 = get_division_pattern($rot, 7);
        if ($div7 eq '142857' || $div7 eq '428571') {
            $pattern_matches{$rot} //= {
                'rotation' => $rot,
                'is_true' => 0
            };
            $pattern_matches{$rot}{'div7_pattern'} = $div7;
            $pattern_matches{$rot}{'is_truth_pattern'} = 1;
        }
    }

    return {
        'sequence' => $sequence,
        'rotations' => \@rotations,
        'pattern_matches' => \%pattern_matches,
        'has_significant_rotation' => scalar(keys %pattern_matches) > 0
    };
}

###########################
# DEMONSTRATION AND RESEARCH FUNCTIONS
###########################

# Holographic research on number sequences
sub research_number_sequences {
    my ($start_range, $end_range) = @_;

    my @holographic_numbers;

    for my $num ($start_range..$end_range) {
        my $properties = analyze_holographic_properties($num);
        my $trimetric = $properties->{'trimetric_value'};

        if ($trimetric->{'is_holographically_true'}) {
            push @holographic_numbers, {
                'number' => $num,
                'properties' => $properties
            };
        }
    }

    return \@holographic_numbers;
}

# Find sequences that encode meaningful ASCII
sub find_meaningful_ascii_encodings {
    my ($start_range, $end_range) = @_;

    my @meaningful_encodings;

    for my $num ($start_range..$end_range) {
        my $ascii = sequence_to_ascii($num);

        # Check if ASCII contains printable characters
        if ($ascii =~ /[A-Za-z0-9=+\-*\/]/) {
            push @meaningful_encodings, {
                'number' => $num,
                'ascii' => $ascii,
                'div13_pattern' => get_division_pattern($num, 13),
                'div7_pattern' => get_division_pattern($num, 7),
                'is_true' => is_true_pattern(get_division_pattern($num, 13))
            };
        }
    }

    return \@meaningful_encodings;
}

# Research dimensional signatures
sub research_dimensional_signatures {
    my @test_sequences = (
        '142857',  # Truth pattern (1/7)
        '461538',  # True pattern (6/13)
        '538461',  # False pattern (7/13)
        '846153',  # Another pattern from division by 13
        '13579',   # Contains authentic dimensions only
        '24680',   # Contains false dimension
        '957135',  # Combined authentic dimensions
        '359715'   # Rotated authentic dimensions
    );

    my @results;

    foreach my $seq (@test_sequences) {
        push @results, {
            'sequence' => $seq,
            'signature' => analyze_dimensional_signature($seq),
            'div13' => get_division_pattern($seq, 13),
            'div7' => get_division_pattern($seq, 7),
            'ascii' => sequence_to_ascii($seq)
        };
    }

    return \@results;
}

# Research bit shift entropy and truth state flipping
sub research_bit_shift_patterns {
    my @test_sequences = (
        '461538',  # True pattern (6/13)
        '538461',  # False pattern (7/13)
        '142857',  # Truth pattern (1/7)
        '846153',  # Inverse pattern
        '131415',  # Stargate sequence
        '132714',  # Stargate with 3D 7D 5D
    );

    my @results;

    foreach my $seq (@test_sequences) {
        push @results, {
            'sequence' => $seq,
            'bit_shift_analysis' => analyze_bit_shift_entropy($seq, 3),  # Analyze 3 consecutive shifts
            'div13' => get_division_pattern($seq, 13),
            'div7' => get_division_pattern($seq, 7),
            'truth_state' => is_true_pattern(get_division_pattern($seq, 13))
        };
    }

    return \@results;
}# Analyze entropy change during bit shift operations
sub analyze_bit_shift_entropy {
    my ($sequence, $shift_count) = @_;
    $shift_count //= 1;

    # Convert sequence to binary for bit shift operations
    my $binary = '';
    foreach my $digit (split('', $sequence)) {
        $binary .= sprintf("%04b", $digit);  # 4 bits per decimal digit
    }

    my $original_binary = $binary;
    my @shift_results;

    # Perform left shifts and analyze results
    for my $i (1..$shift_count) {
        # Left shift (preserve length by wrapping)
        $binary = substr($binary, 1) . substr($binary, 0, 1);

        # Convert back to decimal for analysis
        my $shifted_decimal = '';
        for (my $j = 0; $j < length($binary); $j += 4) {
            my $nibble = substr($binary, $j, 4);
            $shifted_decimal .= sprintf("%d", oct("0b$nibble"));
        }

        # Calculate entropy change
        my $orig_entropy = calculate_shannon_entropy($sequence);
        my $new_entropy = calculate_shannon_entropy($shifted_decimal);
        my $entropy_delta = $new_entropy - $orig_entropy;

        # Check truth state of original and shifted sequences
        my $orig_div13 = get_division_pattern($sequence, 13);
        my $shifted_div13 = get_division_pattern($shifted_decimal, 13);

        my $orig_truth = is_true_pattern($orig_div13);
        my $shifted_truth = is_true_pattern($shifted_div13);

        # Record results
        push @shift_results, {
            'shift' => $i,
            'shifted_sequence' => $shifted_decimal,
            'original_truth_state' => $orig_truth,
            'shifted_truth_state' => $shifted_truth,
            'truth_flipped' => ($orig_truth != $shifted_truth),
            'original_entropy' => $orig_entropy,
            'new_entropy' => $new_entropy,
            'entropy_delta' => $entropy_delta,
            'entropy_preserved' => (abs($entropy_delta) < 0.01)  # Threshold for preservation
        };
    }

    # Also analyze a right shift for comparison
    my $right_shifted = substr($original_binary, -1) . substr($original_binary, 0, length($original_binary) - 1);

    # Convert back to decimal
    my $right_shifted_decimal = '';
    for (my $j = 0; $j < length($right_shifted); $j += 4) {
        my $nibble = substr($right_shifted, $j, 4);
        $right_shifted_decimal .= sprintf("%d", oct("0b$nibble"));
    }

    # Calculate entropy change for right shift
    my $orig_entropy = calculate_shannon_entropy($sequence);
    my $right_entropy = calculate_shannon_entropy($right_shifted_decimal);
    my $right_entropy_delta = $right_entropy - $orig_entropy;

    return {
        'original_sequence' => $sequence,
        'left_shift_results' => \@shift_results,
        'right_shift' => {
            'shifted_sequence' => $right_shifted_decimal,
            'original_entropy' => $orig_entropy,
            'new_entropy' => $right_entropy,
            'entropy_delta' => $right_entropy_delta,
            'entropy_preserved' => (abs($right_entropy_delta) < 0.01),
            'entropy_destroyed' => ($right_entropy_delta < -0.1),
            'original_truth_state' => is_true_pattern(get_division_pattern($sequence, 13)),
            'shifted_truth_state' => is_true_pattern(get_division_pattern($right_shifted_decimal, 13))
        }
    };
}

# Calculate Shannon entropy of a sequence
sub calculate_shannon_entropy {
    my ($sequence) = @_;

    # Count frequency of each character
    my %freq;
    my $total = length($sequence);

    foreach my $char (split('', $sequence)) {
        $freq{$char}++;
    }

    # Calculate Shannon entropy
    my $entropy = 0;
    foreach my $char (keys %freq) {
        my $probability = $freq{$char} / $total;
        $entropy -= $probability * log($probability) / log(2);
    }

    return $entropy;
}# Research dimensional signatures with stargate activation
sub research_stargate_signatures {
    my @test_sequences = (
        '1314',    # Direct hemisphere connection
        '13',      # Stargate base
        '1312',    # Stargate with clock alignment
        '13765',   # Stargate with CCW rotation pattern
        '987651',  # Center descent pattern
        '139872',  # Ring structure with partial activation
        '1348',    # Hemisphere connection (13-14)
        '132714',  # Full activation pattern with 3D 7D connection
        '987321',  # Strong CCW rotation pattern
        '131415',  # Extended hemispheric bandwidth
    );

    my @results;

    foreach my $seq (@test_sequences) {
        my $stargate_analysis = analyze_stargate_mechanism($seq);
        my $dimensional_sig = analyze_dimensional_signature($seq);

        push @results, {
            'sequence' => $seq,
            'stargate_activation' => $stargate_analysis,
            'dimensional_signature' => $dimensional_sig,
            'div13' => get_division_pattern($seq, 13),
            'div7' => get_division_pattern($seq, 7),
            'ascii' => sequence_to_ascii($seq)
        };
    }

    return \@results;
}# Analyze stargate activation patterns
sub analyze_stargate_mechanism {
    my ($sequence) = @_;

    # Look for numerical patterns that represent stargate activation
    my $has_13 = ($sequence =~ /13/) ? 1 : 0;
    my $has_14 = ($sequence =~ /14/) ? 1 : 0;
    my $has_12 = ($sequence =~ /12/) ? 1 : 0;

    # Count occurrences of each digit
    my %digit_count;
    foreach my $digit (split('', $sequence)) {
        $digit_count{$digit}++;
    }

    # Check for ring structure (requires presence of 1 and 3)
    my $ring_structure = (($digit_count{'1'} // 0) >= 1 && ($digit_count{'3'} // 0) >= 1) ? 1 : 0;

    # Check for counter-clockwise rotation indicator
    # CCW rotation often encoded as descending sequence patterns
    my $ccw_rotation = ($sequence =~ /(?:321|432|543|654|765|876|987)/) ? 1 : 0;

    # Check for clock position alignment (12)
    my $clock_alignment = ($has_12 || ($digit_count{'1'} // 0) >= 1 && ($digit_count{'2'} // 0) >= 1) ? 1 : 0;

    # Check for center descent pattern
    # Often encoded as sequences that decrease toward center
    my $center_descent = ($sequence =~ /[98765].*[4321]/) ? 1 : 0;

    # Check for hemisphere connection (13-14 tunnel)
    my $hemisphere_connection = ($has_13 && $has_14) ? 1 : 0;

    # Calculate overall activation state
    my $activation_components = $ring_structure + $ccw_rotation + $clock_alignment +
                               $center_descent + $hemisphere_connection;

    my $activation_percentage = $activation_components / 5;  # 5 components checked

    return {
        'activation_state' => $activation_percentage >= 0.6 ? 'Active' : 'Inactive',
        'activation_percentage' => $activation_percentage,
        'ring_structure' => $ring_structure,
        'ccw_rotation' => $ccw_rotation,
        'clock_alignment' => $clock_alignment,
        'center_descent' => $center_descent,
        'hemisphere_connection' => $hemisphere_connection,
        'bandwidth_factor' => calculate_bandwidth_factor($sequence)
    };
}

# Calculate hemispheric bandwidth factor
sub calculate_bandwidth_factor {
    my ($sequence) = @_;

    # Higher bandwidth requires 13-14 connection and balanced 1/3 energy
    my $has_13 = ($sequence =~ /13/) ? 1 : 0;
    my $has_14 = ($sequence =~ /14/) ? 1 : 0;
    my $has_1314 = ($sequence =~ /1314|1413/) ? 1 : 0;  # Direct connection pattern

    # Count occurrences of each digit
    my %digit_count;
    foreach my $digit (split('', $sequence)) {
        $digit_count{$digit}++;
    }

    # Balanced 1 and 3 energy (approximately equal counts)
    my $one_count = $digit_count{'1'} // 0;
    my $three_count = $digit_count{'3'} // 0;
    my $balance_factor = 0;

    if ($one_count > 0 && $three_count > 0) {
        my $ratio = $one_count / $three_count;
        if ($ratio > 1) { $ratio = 1 / $ratio; }  # Ensure ratio is between 0 and 1
        $balance_factor = $ratio;
    }

    # Calculate bandwidth factor
    my $base_bandwidth = 0.5;  # Base bandwidth

    if ($has_13) { $base_bandwidth += 0.2; }
    if ($has_14) { $base_bandwidth += 0.2; }
    if ($has_1314) { $base_bandwidth += 0.4; }  # Direct connection provides highest bandwidth

    # Balance factor enhances overall bandwidth
    my $final_bandwidth = $base_bandwidth * (0.5 + 0.5 * $balance_factor);

    return $final_bandwidth;
}

# Demonstrate ANTYKI TORUM translations
sub demonstrate_antyki_translations {
    my @terms = keys %{$HOLOGRAPHIC_CONSTANTS->{'antyki_mappings'}};
    my @concepts = ('13', 'cat', 'blacklight', 'blue', 'black', 'vortex');

    my %demonstrations;

    # Translate terms
    $demonstrations{'term_translations'} = [];
    foreach my $term (@terms) {
        push @{$demonstrations{'term_translations'}}, {
            'term' => $term,
            'meanings' => translate_antyki_term($term)
        };
    }

    # Find related terms by concept
    $demonstrations{'concept_related_terms'} = [];
    foreach my $concept (@concepts) {
        push @{$demonstrations{'concept_related_terms'}}, {
            'concept' => $concept,
            'related_terms' => find_related_antyki_terms($concept)
        };
    }

    return \%demonstrations;
}

# Main research function
sub main_research {
    my $research_data = {
        'holographic_properties' => {
            'true_pattern' => analyze_holographic_properties('461538'),
            'false_pattern' => analyze_holographic_properties('538461'),
            'truth_pattern' => analyze_holographic_properties('142857'),
            'ascii_sig' => analyze_holographic_properties('846153')
        },
        'positional_integrity' => {
            'div13_cycle' => test_positional_integrity('846153'),
            'div7_cycle' => test_positional_integrity('142857')
        },
        'bit_shift_research' => research_bit_shift_patterns(),
        'dimensional_research' => research_dimensional_signatures(),
        'stargate_research' => research_stargate_signatures(),
        'antyki_translations' => demonstrate_antyki_translations(),
        'ascii_encodings' => find_meaningful_ascii_encodings(100000, 999999)
    };

    return $research_data;
}

# Print research results
sub print_research_results {
    my $research = main_research();

    # Print holographic properties of key patterns
    print "HOLOGRAPHIC PROPERTIES OF KEY PATTERNS\n";
    print "======================================\n\n";

    foreach my $pattern_name (keys %{$research->{'holographic_properties'}}) {
        my $props = $research->{'holographic_properties'}{$pattern_name};
        print "Pattern: $pattern_name ($props->{'sequence'})\n";
        print "  ASCII encoding: $props->{'ascii_encoding'}\n";
        print "  Div13 pattern: $props->{'div13_pattern'}\n";
        print "  Div7 pattern: $props->{'div7_pattern'}\n";
        print "  Trimetric value: " . $props->{'trimetric_value'}{'value'} . "\n";
        print "  Holographically true: " .
              ($props->{'trimetric_value'}{'is_holographically_true'} ? "Yes" : "No") . "\n";
        print "\n";
    }

    # Print bit shift entropy research
    print "BIT SHIFT TRUTH STATE FLIPPING\n";
    print "==============================\n\n";

    foreach my $result (@{$research->{'bit_shift_research'}}) {
        print "Sequence: $result->{'sequence'} (Truth: " .
              ($result->{'truth_state'} ? "True" : "False") . ")\n";

        print "  Left Shifts:\n";
        foreach my $shift (@{$result->{'bit_shift_analysis'}{'left_shift_results'}}) {
            print "    Shift $shift->{'shift'}: " . $shift->{'shifted_sequence'} .
                  " (Truth: " . ($shift->{'shifted_truth_state'} ? "True" : "False") . ")\n";
            print "      Truth flipped: " . ($shift->{'truth_flipped'} ? "Yes" : "No") . "\n";
            print "      Entropy preserved: " . ($shift->{'entropy_preserved'} ? "Yes" : "No") .
                  " (delta: " . sprintf("%.4f", $shift->{'entropy_delta'}) . ")\n";
        }

        print "  Right Shift: " . $result->{'bit_shift_analysis'}{'right_shift'}{'shifted_sequence'} . "\n";
        print "    Entropy preserved: " .
              ($result->{'bit_shift_analysis'}{'right_shift'}{'entropy_preserved'} ? "Yes" : "No") . "\n";
        print "    Entropy destroyed: " .
              ($result->{'bit_shift_analysis'}{'right_shift'}{'entropy_destroyed'} ? "Yes" : "No") . "\n";
        print "    Truth state maintained: " .
              ($result->{'bit_shift_analysis'}{'right_shift'}{'original_truth_state'} ==
               $result->{'bit_shift_analysis'}{'right_shift'}{'shifted_truth_state'} ? "Yes" : "No") . "\n";
        print "\n";
    }

    # Print meaningful ASCII encodings
    print "MEANINGFUL ASCII ENCODINGS\n";
    print "==========================\n\n";

    my $count = 0;
    foreach my $enc (@{$research->{'ascii_encodings'}}) {
        print "$enc->{'number'} => $enc->{'ascii'} (Div13: $enc->{'div13_pattern'}, " .
              "Truth: " . ($enc->{'is_true'} ? "Yes" : "No") . ")\n";

        $count++;
        last if $count >= 10;  # Limit to 10 examples
    }
    print "... and " . (scalar(@{$research->{'ascii_encodings'}}) - 10) . " more\n\n";

    # Print stargate activation results
    print "STARGATE ACTIVATION PATTERNS\n";
    print "============================\n\n";

    foreach my $result (@{$research->{'stargate_research'}}) {
        print "Sequence: $result->{'sequence'}\n";
        print "  Activation state: " . $result->{'stargate_activation'}{'activation_state'} .
              " (" . sprintf("%.2f", $result->{'stargate_activation'}{'activation_percentage'} * 100) . "%)\n";
        print "  Bandwidth factor: " .
              sprintf("%.2f", $result->{'stargate_activation'}{'bandwidth_factor'}) . "\n";
        print "  Components active:\n";
        print "    Ring structure: " .
              ($result->{'stargate_activation'}{'ring_structure'} ? "Yes" : "No") . "\n";
        print "    CCW rotation: " .
              ($result->{'stargate_activation'}{'ccw_rotation'} ? "Yes" : "No") . "\n";
        print "    Clock alignment: " .
              ($result->{'stargate_activation'}{'clock_alignment'} ? "Yes" : "No") . "\n";
        print "    Center descent: " .
              ($result->{'stargate_activation'}{'center_descent'} ? "Yes" : "No") . "\n";
        print "    Hemisphere connection: " .
              ($result->{'stargate_activation'}{'hemisphere_connection'} ? "Yes" : "No") . "\n";
        print "\n";
    }

    # Print ANTYKI TORUM translations
    print "ANTYKI TORUM TRANSLATIONS\n";
    print "=========================\n\n";

    foreach my $term (@{$research->{'antyki_translations'}{'term_translations'}}) {
        print "$term->{'term'} => " . join(", ", @{$term->{'meanings'}}) . "\n";
    }
    print "\n";
}

# Run research if executed directly
print_research_results() unless caller;

1; # End of module
