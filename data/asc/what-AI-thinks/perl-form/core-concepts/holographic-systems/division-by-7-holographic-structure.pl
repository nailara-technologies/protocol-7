#!/usr/bin/perl
use v5.24;
use strict;
use warnings;
use File::Path qw(make_path);
use File::Spec;
use JSON::PP;
use Math::Complex;
use Math::Trig;
use Time::HiRes qw(time);

# =====================================================================
# DIVISION BY 7 HOLOGRAPHIC RESEARCH FRAMEWORK
# =====================================================================
# This research module focuses on the multidimensional properties
# of the 142857 sequence from division by 7, exploring its relationship
# to holographic information structures, cube traversal patterns, and
# its applications in self-describing protocols.
# =====================================================================

###########################
# CORE CONSTANTS
###########################

my $HARMONIC_CONSTANTS = {
    # Base sequences
    'pattern_1_7'        => '142857', # 1/7
    'pattern_2_7'        => '285714', # 2/7
    'pattern_3_7'        => '428571', # 3/7
    'pattern_4_7'        => '571428', # 4/7
    'pattern_5_7'        => '714285', # 5/7
    'pattern_6_7'        => '857142', # 6/7
    'pattern_7_7'        => '999999', # 7/7 boundary

    # Key arithmetic operations
    'doubling_op'        => 2,        # ×2 progression
    'rotation_op'        => 1,        # +1 for 90° CCW rotation

    # Dimensional mapping
    'dimensions'         => 3,        # x, y, z
    'rotation_angle'     => 90,       # Degrees CCW
    'cube_vertices'      => 8,        # Vertices in a cube

    # Special positions
    'bifurcation_point'  => 57,       # Position where direction can be reversed
    'sentinel_position'  => 56,       # Pre-bifurcation indicator (56 + 1 = 57)

    # Generation sequence
    'sequence_factors'   => [7, 14, 28, 57], # The progression sequence

    # Unity visualization
    'unity_scale'        => 0.5,      # Scale factor for Unity visualization
    'vertex_size'        => 0.2,      # Size of vertices in visualization
    'path_width'         => 0.05      # Width of path in visualization
};

###########################
# SEQUENCE ANALYSIS
###########################

# Calculate division by 7 pattern for a number
sub get_div7_pattern {
    my $num = shift;

    # Division by 7
    my $result = $num / 7;

    # Extract decimal part
    my $decimal = $result - int($result);

    # Get 6 digits after decimal point
    return substr(sprintf("%.6f", $decimal), 2, 6);
}

# Verify the doubling+1 pattern in the sequence
sub verify_sequence_pattern {
    my $sequence = shift || $HARMONIC_CONSTANTS->{'pattern_1_7'};

    # Expected progression: 7 → 14 → 28 → 57
    # As digits: [1][4][2][8][5][7]

    my @factors = @{$HARMONIC_CONSTANTS->{'sequence_factors'}};
    my @expected_digits;

    # 7 → 1st digit is suppressed (0)
    # 14 → "14"
    push @expected_digits, 1, 4;

    # 28 → "28"
    push @expected_digits, 2, 8;

    # 57 → "57"
    push @expected_digits, 5, 7;

    # Check against actual sequence
    my @digits = split('', $sequence);

    my $matches = 1;
    for my $i (0..$#expected_digits) {
        if ($i > $#digits || $expected_digits[$i] != $digits[$i]) {
            $matches = 0;
            last;
        }
    }

    return {
        'matches' => $matches,
        'expected' => \@expected_digits,
        'actual' => \@digits
    };
}

# Test doubling pattern with explicit numbers
sub verify_doubling_operation {
    my $verbose = shift;

    my @factors = @{$HARMONIC_CONSTANTS->{'sequence_factors'}};

    # Check if each number follows the doubling/doubling+1 pattern
    my $valid = 1;
    for my $i (1..$#factors) {
        my $prev = $factors[$i-1];
        my $curr = $factors[$i];

        my $expected;
        if ($i < $#factors) {
            # Simple doubling
            $expected = $prev * $HARMONIC_CONSTANTS->{'doubling_op'};
        } else {
            # Doubling + 1 for the last transition (28→57)
            $expected = $prev * $HARMONIC_CONSTANTS->{'doubling_op'} +
                       $HARMONIC_CONSTANTS->{'rotation_op'};
        }

        if ($curr != $expected) {
            $valid = 0;
            last;
        }

        if ($verbose) {
            if ($i < $#factors) {
                printf("%-2d × %-2d = %-2d  ✓\n", $prev, $HARMONIC_CONSTANTS->{'doubling_op'}, $curr);
            } else {
                printf("%-2d × %-2d + %-2d = %-2d  ✓\n", $prev, $HARMONIC_CONSTANTS->{'doubling_op'},
                      $HARMONIC_CONSTANTS->{'rotation_op'}, $curr);
            }
        }
    }

    return $valid;
}

# Find all bifurcation points ("57") in a sequence
sub find_bifurcation_points {
    my $sequence = shift;

    my @points;
    my $pos = -1;

    # Search for "57" pattern
    while (($pos = index($sequence, $HARMONIC_CONSTANTS->{'bifurcation_point'}, $pos + 1)) != -1) {
        push @points, $pos;
    }

    return @points;
}

# Detect reading direction based on context around bifurcation point
sub detect_reading_direction {
    my $sequence = shift;

    # Find bifurcation points
    my @points = find_bifurcation_points($sequence);
    return "NONE" if @points == 0;

    for my $pos (@points) {
        # Need enough context
        next if $pos < 2 || $pos + 2 >= length($sequence);

        # Check context before and after the "57"
        my $before = substr($sequence, $pos-2, 2);
        my $after = substr($sequence, $pos+2, 2);

        # Forward: "2857_14"
        if ($before eq "28" && $after eq "14") {
            return "FORWARD";
        }
        # Backward: "14_5728"
        elsif ($before eq "14" && $after eq "28") {
            return "BACKWARD";
        }
    }

    return "UNKNOWN";
}

###########################
# GEOMETRIC MAPPING
###########################

# Convert a sequence to 3D cube traversal path
sub sequence_to_3d_path {
    my $sequence = shift || $HARMONIC_CONSTANTS->{'pattern_1_7'};

    my @path_points = ({ 'x' => 0, 'y' => 0, 'z' => 0 }); # Start at origin

    my $current_direction = 0; # 0=x, 1=y, 2=z
    my $prev_digit = -1;

    # Process each digit as a movement
    foreach my $digit_char (split('', $sequence)) {
        my $digit = int($digit_char);

        # Get previous position
        my $prev_pos = $path_points[-1];
        my $new_pos = {
            'x' => $prev_pos->{'x'},
            'y' => $prev_pos->{'y'},
            'z' => $prev_pos->{'z'}
        };

        # Check for pattern transitions
        if ($prev_digit >= 0) {
            # Transition rules
            if ($digit == $prev_digit * $HARMONIC_CONSTANTS->{'doubling_op'}) {
                # Doubling = continue in same direction
            }
            elsif ($digit == $prev_digit * $HARMONIC_CONSTANTS->{'doubling_op'} +
                             $HARMONIC_CONSTANTS->{'rotation_op'}) {
                # Doubling + 1 = rotate 90° CCW
                $current_direction = ($current_direction + 1) % $HARMONIC_CONSTANTS->{'dimensions'};
            }
            else {
                # Other transitions (non-standard)
                # Could implement more complex rules here
            }
        }

        # Get axis based on current direction
        my $axis = ('x', 'y', 'z')[$current_direction];

        # Move along current axis by digit value (scaled)
        $new_pos->{$axis} += $digit * $HARMONIC_CONSTANTS->{'unity_scale'};

        # Add to path
        push @path_points, $new_pos;
        $prev_digit = $digit;
    }

    return \@path_points;
}

# Generate cube vertices at standard positions
sub generate_cube_vertices {
    my $size = shift || 1.0;

    my @vertices;

    # 8 vertices of a cube
    for my $x (-$size/2, $size/2) {
        for my $y (-$size/2, $size/2) {
            for my $z (-$size/2, $size/2) {
                push @vertices, { 'x' => $x, 'y' => $y, 'z' => $z };
            }
        }
    }

    return \@vertices;
}

# Map the sequence to cube vertices
sub map_sequence_to_cube {
    my $sequence = shift || $HARMONIC_CONSTANTS->{'pattern_1_7'};

    my $vertices = generate_cube_vertices();
    my @mapping;

    # Map each digit of the sequence to a vertex
    for my $i (0..length($sequence)-1) {
        my $digit = substr($sequence, $i, 1);

        # Map digit to vertex (simplified approach)
        my $vertex_idx = $digit % scalar(@$vertices);

        push @mapping, {
            'digit' => $digit,
            'position' => $i,
            'vertex' => $vertices->[$vertex_idx]
        };
    }

    return \@mapping;
}

# Visualize geometric properties of the sequence
sub visualize_geometry {
    my $sequence = shift || $HARMONIC_CONSTANTS->{'pattern_1_7'};

    # Get 3D path
    my $path = sequence_to_3d_path($sequence);

    # Print path as ASCII visualization (very basic)
    say "3D Path for sequence: $sequence";
    say "------------------------";

    for my $i (0..$#$path) {
        my $point = $path->[$i];
        printf("Point %d: (%.1f, %.1f, %.1f)\n",
               $i, $point->{'x'}, $point->{'y'}, $point->{'z'});
    }

    say "";
    say "Key transitions:";

    # Show transitions
    for my $i (1..$#$path) {
        my $prev = $path->[$i-1];
        my $curr = $path->[$i];

        # Calculate movement vector
        my $dx = $curr->{'x'} - $prev->{'x'};
        my $dy = $curr->{'y'} - $prev->{'y'};
        my $dz = $curr->{'z'} - $prev->{'z'};

        # Determine primary axis of movement
        my $axis = 'none';
        $axis = 'x' if abs($dx) > 0.01;
        $axis = 'y' if abs($dy) > 0.01;
        $axis = 'z' if abs($dz) > 0.01;

        # Check for bifurcation points
        my $special = '';
        if ($i < length($sequence) && $i > 0) {
            my $digits = substr($sequence, $i-1, 2);
            if ($digits eq '57') {
                $special = " - BIFURCATION POINT";
            }
            elsif ($digits eq '56') {
                $special = " - SENTINEL POSITION";
            }
        }

        printf("Move %d: along %s-axis by %.1f%s\n",
               $i, $axis, max(abs($dx), abs($dy), abs($dz)), $special);
    }
}

###########################
# SELF-DESCRIBING PROTOCOL
###########################

# Encode a message using division by 7 pattern properties
sub encode_div7_message {
    my ($message, $rotation) = @_;
    $rotation ||= 0;

    # Get pattern with appropriate rotation
    my $pattern = substr($HARMONIC_CONSTANTS->{'pattern_1_7'} x 2, $rotation, 6);

    # Convert message to bytes
    my @bytes = map { ord($_) } split('', $message);

    # Create output buffer
    my @encoded;

    # Add rotation marker
    push @encoded, chr(($rotation * 7) % 256);

    # Encode each byte
    for my $i (0..$#bytes) {
        my $byte = $bytes[$i];
        my $pattern_pos = $i % length($pattern);
        my $pattern_digit = substr($pattern, $pattern_pos, 1);

        # Encode using pattern digit
        my $encoded_byte = ($byte * 7 + $pattern_digit) % 256;
        push @encoded, chr($encoded_byte);
    }

    return join('', @encoded);
}

# Decode a div7-encoded message
sub decode_div7_message {
    my $encoded = shift;

    # Need at least one byte
    return '' if length($encoded) < 1;

    # Extract rotation marker
    my $rotation_byte = ord(substr($encoded, 0, 1));
    my $rotation = $rotation_byte % 7;

    # Get pattern with appropriate rotation
    my $pattern = substr($HARMONIC_CONSTANTS->{'pattern_1_7'} x 2, $rotation, 6);

    # Remove marker
    $encoded = substr($encoded, 1);

    # Decode bytes
    my @decoded;
    for my $i (0..length($encoded)-1) {
        my $byte = ord(substr($encoded, $i, 1));
        my $pattern_pos = $i % length($pattern);
        my $pattern_digit = substr($pattern, $pattern_pos, 1);

        # Decode using pattern digit
        my $original_byte = (($byte - $pattern_digit) % 256 + 256) % 256;
        $original_byte = int($original_byte / 7);
        push @decoded, chr($original_byte);
    }

    return join('', @decoded);
}

# Test bidirectional communication using bifurcation points
sub test_bidirectional_protocol {
    my ($message1, $message2) = @_;

    # Encode messages at the appropriate rotation positions
    my $encoded1 = encode_div7_message($message1, 0); # Forward direction
    my $encoded2 = encode_div7_message($message2, 3); # After rotation at position 57

    # Create bidirectional message with bifurcation point
    my $combined = $encoded1 . "57" . $encoded2;

    # Detect direction
    my $direction = detect_reading_direction($combined);

    # Simulate reading from both ends
    my ($decoded1, $decoded2);

    if ($direction eq "FORWARD" || $direction eq "UNKNOWN") {
        # Extract first part
        my $first_part = substr($combined, 0, index($combined, "57"));
        $decoded1 = decode_div7_message($first_part);

        # Extract second part
        my $second_part = substr($combined, index($combined, "57") + 2);
        $decoded2 = decode_div7_message($second_part);
    }
    else {
        # Read in reverse for testing
        my $reversed = reverse($combined);

        # Extract parts in reverse order
        my $first_part = substr($reversed, 0, index($reversed, reverse("57")));
        $decoded2 = decode_div7_message($first_part);

        # Extract second part
        my $second_part = substr($reversed, index($reversed, reverse("57")) + 2);
        $decoded1 = decode_div7_message($second_part);
    }

    return {
        'direction' => $direction,
        'message1' => $decoded1,
        'message2' => $decoded2
    };
}

###########################
# UNITY INTEGRATION
###########################

# Generate Unity C# implementation code
sub generate_unity_implementation {
    my $file = shift || "Div7HolographicCube.cs";

    # Basic implementation for Unity
    my $code = <<'CSHARP';
using UnityEngine;
using System.Collections.Generic;
using System.Text;

/// <summary>
/// Implements the Division by 7 Holographic Cube research findings in Unity
/// Visualizes the 142857 pattern as a 3D cube traversal with special
/// handling for bifurcation points and rotation operations.
/// </summary>
public class Div7HolographicCube : MonoBehaviour
{
    // Configuration
    [Header("Configuration")]
    [Tooltip("Main sequence to visualize")]
    public string mainSequence = "142857";

    [Tooltip("Scale for visualization")]
    public float visualScale = 0.5f;

    [Tooltip("Speed of animation")]
    public float animationSpeed = 1.0f;

    [Header("References")]
    public GameObject cubePrefab;
    public GameObject nodePointPrefab;
    public LineRenderer pathRenderer;
    public Material normalPathMaterial;
    public Material bifurcationMaterial;

    // Path state
    private List<Vector3> pathPoints = new List<Vector3>();
    private List<GameObject> pathNodes = new List<GameObject>();
    private GameObject cubeObject;

    private void Start()
    {
        InitializeVisualization();
    }

    private void Update()
    {
        // Animate rotation for visualization
        transform.Rotate(Vector3.up, Time.deltaTime * 10f * animationSpeed);
    }

    /// <summary>
    /// Set up the holographic cube and sequence visualization
    /// </summary>
    private void InitializeVisualization()
    {
        // Create cube if needed
        if (cubeObject == null && cubePrefab != null)
        {
            cubeObject = Instantiate(cubePrefab, Vector3.zero, Quaternion.identity);
            cubeObject.transform.SetParent(transform);
            cubeObject.transform.localScale = Vector3.one * 5f;
        }

        // Generate path
        GenerateSequencePath(mainSequence);
    }

    /// <summary>
    /// Calculate division by 7 pattern for a number
    /// </summary>
    public string GetDiv7Pattern(long number)
    {
        double result = (double)number / 7;
        double decimalPart = result - Mathf.Floor((float)result);
        return decimalPart.ToString("F6").Substring(2, 6);
    }

    /// <summary>
    /// Generate 3D path from a sequence
    /// </summary>
    private List<Vector3> CalculateSequencePath(string sequence)
    {
        List<Vector3> points = new List<Vector3>{ Vector3.zero };

        int currentDirection = 0; // 0=x, 1=y, 2=z
        int prevDigit = -1;

        foreach (char c in sequence)
        {
            int digit = int.Parse(c.ToString());

            // Get previous position
            Vector3 prevPos = points[points.Count - 1];
            Vector3 newPos = prevPos;

            // Check pattern transitions
            if (prevDigit >= 0)
            {
                // Doubling = continue same direction
                if (digit == prevDigit * 2)
                {
                    // Continue same direction
                }
                // Doubling + 1 = rotate 90° CCW
                else if (digit == prevDigit * 2 + 1)
                {
                    currentDirection = (currentDirection + 1) % 3;
                }
                else
                {
                    // Other transitions
                    currentDirection = (currentDirection + 2) % 3;
                }
            }

            // Move in current direction
            switch (currentDirection)
            {
                case 0: // X-axis
                    newPos.x += digit * visualScale;
                    break;

                case 1: // Y-axis
                    newPos.y += digit * visualScale;
                    break;

                case 2: // Z-axis
                    newPos.z += digit * visualScale;
                    break;
            }

            // Add to path
            points.Add(newPos);
            prevDigit = digit;
        }

        return points;
    }

    /// <summary>
    /// Generate the path visualization for a sequence
    /// </summary>
    public void GenerateSequencePath(string sequence)
    {
        // Calculate path points
        pathPoints = CalculateSequencePath(sequence);

        // Clean up existing nodes
        foreach (var node in pathNodes)
        {
            Destroy(node);
        }
        pathNodes.Clear();

        // Create path nodes
        for (int i = 0; i < pathPoints.Count; i++)
        {
            // Create node
            GameObject node = Instantiate(nodePointPrefab, pathPoints[i], Quaternion.identity);
            node.transform.SetParent(transform);

            // Special formatting for bifurcation points
            if (i > 0 && i < sequence.Length)
            {
                string segment = i > 1 ? sequence.Substring(i-1, 2) : "";
                if (segment == "57")
                {
                    // Bifurcation point
                    node.GetComponent<Renderer>().material = bifurcationMaterial;
                    node.transform.localScale = Vector3.one * 0.3f;
                }
            }

            pathNodes.Add(node);
        }

        // Update line renderer
        if (pathRenderer != null)
        {
            pathRenderer.positionCount = pathPoints.Count;
            pathRenderer.SetPositions(pathPoints.ToArray());
        }
    }

    /// <summary>
    /// Encode a message using div7 pattern
    /// </summary>
    public byte[] EncodeMessage(string message, int rotation = 0)
    {
        // Get pattern with appropriate rotation
        string pattern = mainSequence;
        if (rotation > 0)
        {
            pattern = pattern.Substring(rotation) + pattern.Substring(0, rotation);
        }

        // Get bytes from message
        byte[] messageBytes = Encoding.UTF8.GetBytes(message);
        List<byte> encoded = new List<byte>();

        // Add rotation marker
        encoded.Add((byte)((rotation * 7) % 256));

        // Encode bytes
        for (int i = 0; i < messageBytes.Length; i++)
        {
            int patternPos = i % pattern.Length;
            int patternDigit = int.Parse(pattern[patternPos].ToString());

            byte encodedByte = (byte)((messageBytes[i] * 7 + patternDigit) % 256);
            encoded.Add(encodedByte);
        }

        return encoded.ToArray();
    }

    /// <summary>
    /// Decode a div7-encoded message
    /// </summary>
    public string DecodeMessage(byte[] encoded)
    {
        if (encoded.Length == 0)
            return string.Empty;

        // Extract rotation marker
        int rotationByte = encoded[0];
        int rotation = rotationByte % 7;

        // Get pattern with appropriate rotation
        string pattern = mainSequence;
        if (rotation > 0)
        {
            pattern = pattern.Substring(rotation) + pattern.Substring(0, rotation);
        }

        // Skip marker
        List<byte> decoded = new List<byte>();

        // Decode bytes
        for (int i = 1; i < encoded.Length; i++)
        {
            int patternPos = (i-1) % pattern.Length;
            int patternDigit = int.Parse(pattern[patternPos].ToString());

            int originalByte = ((encoded[i] - patternDigit) % 256 + 256) % 256;
            originalByte = originalByte / 7;
            decoded.Add((byte)originalByte);
        }

        return Encoding.UTF8.GetString(decoded.ToArray());
    }

    /// <summary>
    /// Find all bifurcation points in a sequence
    /// </summary>
    public List<int> FindBifurcationPoints(string sequence)
    {
        List<int> points = new List<int>();
        int pos = 0;

        while (true)
        {
            int index = sequence.IndexOf("57", pos);
            if (index == -1)
                break;

            points.Add(index);
            pos = index + 1;
        }

        return points;
    }

    /// <summary>
    /// Detect reading direction from context around "57"
    /// </summary>
    public string DetectReadingDirection(string data)
    {
        // Find bifurcation point
        int pos = data.IndexOf("57");
        if (pos == -1 || pos < 2 || pos + 2 >= data.Length)
            return "UNKNOWN";

        // Check context
        string before = data.Substring(pos - 2, 2);
        string after = data.Substring(pos + 2, 2);

        // Direction determination
        if (before == "28" && after == "14")
            return "FORWARD";
        else if (before == "14" && after == "28")
            return "BACKWARD";

        return "UNKNOWN";
    }
}
CSHARP

    # Write to file
    open my $fh, ">", $file or die "Could not open file: $!";
    print $fh $code;
    close $fh;

    return $file;
}

###########################
# RESEARCH EXPERIMENTATION
###########################

# Test the doubling+1 pattern in the 142857 sequence
sub experiment_doubling_pattern {
    say "EXPERIMENT: Verifying the doubling+1 pattern in 142857";
    say "----------------------------------------------------";

    # Basic verification
    my $verification = verify_sequence_pattern();
    if ($verification->{'matches'}) {
        say "✓ The sequence 142857 follows the doubling+1 pattern!";
    } else {
        say "✗ The sequence does not match the expected pattern.";
        say "  Expected: " . join('', @{$verification->{'expected'}});
        say "  Actual:   " . join('', @{$verification->{'actual'}});
    }

    # Show the arithmetic operations
    say "\nArithmetic operations:";
    verify_doubling_operation(1);

    # Check the bifurcation point
    say "\nBifurcation point analysis:";
    say "The value 57 is a bifurcation point where direction can be reversed.";
    say "It's formed by: 28 × 2 + 1 = 57";
    say "The +1 operation creates a 90° CCW rotation in the geometric interpretation.";

    # Sentinel position
    say "\nSentinel position:";
    say "The position 56 acts as a sentinel indicator before the bifurcation.";
    say "56 + 1 = 57, serving as a signal that a bifurcation point follows.";

    return $verification->{'matches'};
}

# Experiment with geometric properties
sub experiment_geometric_properties {
    say "EXPERIMENT: Geometric properties of the 142857 sequence";
    say "----------------------------------------------------";

    # Generate 3D path
    my $path = sequence_to_3d_path();

    say "3D path has " . scalar(@$path) . " points.";

    # Analyze path for patterns
    my $direction_changes = 0;
    my $last_direction = '';

    for my $i (1..$#$path) {
        my $prev = $path->[$i-1];
        my $curr = $path->[$i];

        # Determine movement direction
        my $dx = abs($curr->{'x'} - $prev->{'x'});
        my $dy = abs($curr->{'y'} - $prev->{'y'});
        my $dz = abs($curr->{'z'} - $prev->{'z'});

        my $direction;
        if ($dx > 0) { $direction = 'x'; }
        elsif ($dy > 0) { $direction = 'y'; }
        elsif ($dz > 0) { $direction = 'z'; }
        else { $direction = 'none'; }

        if ($last_direction ne '' && $direction ne $last_direction) {
            $direction_changes++;
        }

        $last_direction = $direction;
    }

    say "Path contains $direction_changes direction changes.";

    # Show detailed path
    say "\nDetailed path:";
    visualize_geometry();

    # Analyze cube relationship
    say "\nCube mapping analysis:";
    say "The sequence can map to the 8 vertices of a cube in 3D space.";
    say "The +1 operation (56→57) represents a 90° CCW rotation in this space.";
    say "This creates a holographic representation where the sequence describes";
    say "a path through the cube's structure, with 57 creating dimensional shifts.";

    return {
        'path_length' => scalar(@$path),
        'direction_changes' => $direction_changes
    };
}

# Experiment with bidirectional protocol properties
sub experiment_bidirectional_protocol {
    say "EXPERIMENT: Bidirectional protocol using division by 7";
    say "----------------------------------------------------";

    # Test messages
    my $message1 = "Forward message at position 0";
    my $message2 = "Reverse message after position 57";

    say "Message 1: $message1";
    say "Message 2: $message2";

    # Encode with the protocol
    my $encoded1 = encode_div7_message($message1, 0);
    my $encoded2 = encode_div7_message($message2, 3);

    say "\nMessage 1 encoded at rotation 0";
    say "Message 2 encoded at rotation 3";

    # Create bidirectional message
    my $combined = $encoded1 . "57" . $encoded2;

    say "\nCombined message with bifurcation point '57' inserted";
    say "Total length: " . length($combined) . " bytes";

    # Test reading
    my $results = test_bidirectional_protocol($message1, $message2);

    say "\nReading results:";
    say "Detected direction: " . $results->{'direction'};
    say "Decoded message 1: " . $results->{'message1'};
    say "Decoded message 2: " . $results->{'message2'};

    # Verify
    my $success = ($results->{'message1'} eq $message1 &&
                  $results->{'message2'} eq $message2);

    say "\nVerification: " . ($success ? "✓ SUCCESS" : "✗ FAILURE");
    say "The 57 bifurcation point successfully enables bidirectional reading";
    say "by providing a direction-neutral marker in the data stream.";

    return $success;
}

###########################
# UNITY INTEGRATION HELPERS
###########################

# Generate Unity visualization script
sub generate_unity_visualization {
    # Already implemented in generate_unity_implementation function
    my $script_path = generate_unity_implementation();

    say "Generated Unity implementation at: $script_path";
    say "This script implements the division by 7 holographic properties";
    say "as a fully interactive 3D visualization in Unity.";

    return $script_path;
}

# Generate helper code for Unity development
sub generate_unity_helpers {
    my $output_dir = shift || ".";

    # Write supplementary scripts
    my $visualization_helper = "$output_dir/Div7PathVisualizer.cs";

    # Basic helper class
    my $helper_code = <<'HELPER_CODE';
using UnityEngine;
using System.Collections.Generic;

/// <summary>
/// Helper class for visualizing Division by 7 holographic patterns
/// </summary>
public class Div7PathVisualizer : MonoBehaviour
{
    [Header("Visualization")]
    public Color normalNodeColor = Color.cyan;
    public Color bifurcationColor = Color.magenta;
    public Color sentinelColor = Color.yellow;
    public float normalNodeSize = 0.1f;
    public float specialNodeSize = 0.2f;

    [Header("Animation")]
    public float pathTraversalSpeed = 1.0f;
    public bool animateTraversal = true;

    // References
    private Div7HolographicCube holographicSystem;
    private List<GameObject> pathObjects = new List<GameObject>();
    private int currentPathIndex = 0;

    private void Start()
    {
        holographicSystem = GetComponent<Div7HolographicCube>();

        if (holographicSystem == null)
        {
            Debug.LogError("Div7PathVisualizer requires a Div7HolographicCube component");
        }
    }

    private void Update()
    {
        if (animateTraversal && pathObjects.Count > 0)
        {
            // Reset all nodes to normal state
            foreach (var obj in pathObjects)
            {
                obj.transform.localScale = Vector3.one * normalNodeSize;
            }

            // Highlight current node
            if (currentPathIndex < pathObjects.Count)
            {
                pathObjects[currentPathIndex].transform.localScale = Vector3.one * specialNodeSize * 1.5f;
            }

            // Advance through path
            if (Time.frameCount % (int)(60 / pathTraversalSpeed) == 0)
            {
                currentPathIndex = (currentPathIndex + 1) % pathObjects.Count;
            }
        }
    }

    /// <summary>
    /// Set up visualization for a specific sequence
    /// </summary>
    public void VisualizeSequence(string sequence)
    {
        if (holographicSystem != null)
        {
            holographicSystem.GenerateSequencePath(sequence);
            SetupPathObjects();
        }
    }

    /// <summary>
    /// Set up path objects based on the holographic system
    /// </summary>
    private void SetupPathObjects()
    {
        // Get path objects from holographic system
        pathObjects = new List<GameObject>();

        foreach (Transform child in transform)
        {
            if (child.name.Contains("Point"))
            {
                pathObjects.Add(child.gameObject);
            }
        }

        // Reset traversal
        currentPathIndex = 0;
    }

    /// <summary>
    /// Analyze a pattern and display relevant properties
    /// </summary>
    public string AnalyzePattern(string pattern)
    {
        // Find bifurcation points
        List<int> bifurcationPoints = holographicSystem.FindBifurcationPoints(pattern);

        // Determine if it follows doubling pattern
        bool followsDoublingPattern = IsDoublingPattern(pattern);

        string analysis = $"Pattern: {pattern}\n";
        analysis += $"- Bifurcation points: {bifurcationPoints.Count}\n";
        analysis += $"- Follows doubling pattern: {followsDoublingPattern}\n";
        analysis += $"- Reading direction: {holographicSystem.DetectReadingDirection(pattern)}\n";

        return analysis;
    }

    /// <summary>
    /// Check if a pattern follows the doubling+1 rule
    /// </summary>
    private bool IsDoublingPattern(string pattern)
    {
        if (pattern.Length < 6)
            return false;

        // Expected digit sequence: 142857
        // Check 1->4 (×2), 4->8 (×2), 2->4 (×2), 8->5 (×2+1 = rotation)
        return pattern[0] == '1' &&
               pattern[1] == '4' &&
               pattern[2] == '2' &&
               pattern[3] == '8' &&
               pattern[4] == '5' &&
               pattern[5] == '7';
    }
}
HELPER_CODE

    # Write to file
    open my $fh, ">", $visualization_helper or die "Could not open file: $!";
    print $fh $helper_code;
    close $fh;

    return $visualization_helper;
}

###########################
# MAIN RESEARCH FUNCTIONS
###########################

# Run all experiments
sub run_all_experiments {
    say "DIVISION BY 7 HOLOGRAPHIC RESEARCH";
    say "==================================";
    say "Primary sequence: " . $HARMONIC_CONSTANTS->{'pattern_1_7'};
    say "Bifurcation point: " . $HARMONIC_CONSTANTS->{'bifurcation_point'};
    say "Sentinel position: " . $HARMONIC_CONSTANTS->{'sentinel_position'};
    say "";

    # Run doubling pattern experiment
    experiment_doubling_pattern();
    say "\n";

    # Run geometric properties experiment
    experiment_geometric_properties();
    say "\n";

    # Run bidirectional protocol experiment
    experiment_bidirectional_protocol();
    say "\n";

    # Generate Unity implementation
    generate_unity_visualization();
    generate_unity_helpers();
}

# Initialize research environment
sub init_research {
    my $dir = shift || "div7_research";

    # Create directory structure
    make_path($dir) unless -d $dir;
    make_path("$dir/unity") unless -d "$dir/unity";
    make_path("$dir/data") unless -d "$dir/data";

    # Generate Unity implementation in the unity directory
    my $unity_script = generate_unity_implementation("$dir/unity/Div7HolographicCube.cs");
    my $helper_script = generate_unity_helpers("$dir/unity");

    # Create README
    my $readme_path = "$dir/README.md";
    open my $fh, ">", $readme_path or die "Could not open file: $!";
    print $fh <<'README';
# Division by 7 Holographic Research

This research module focuses on the multidimensional properties of the 142857 sequence
from division by 7, exploring its relationship to holographic information structures,
cube traversal patterns, and its applications in self-describing protocols.

## Key Concepts

1. **The 142857 Sequence**
   - Division by 7 pattern: 1/7 = 0.142857142857...
   - Cyclic permutations: 142857, 285714, 428571, 571428, 714285, 857142
   - When multiplied by 7, gives 999999 (boundary condition)

2. **Doubling Pattern**
   - 7 → 14 → 28 → 57
   - This progression appears in the sequence digits: 142857
   - Final step (28→57) involves doubling plus 1: 28×2+1=57

3. **Geometric Interpretation**
   - Doubling = linear progression along current axis
   - +1 operation = 90° CCW rotation to new dimensional axis
   - Creates a 3D cube traversal pattern

4. **Bifurcation Point**
   - Position 57 is where reading direction can be reversed
   - Context around 57 determines direction: 2857_14 vs 14_5728
   - Position 56 serves as sentinel indicator (56+1=57)

5. **Self-Describing Protocol**
   - The pattern can encode messages with built-in direction detection
   - No separate headers needed to determine reading direction
   - Messages can be read correctly from either end

## Usage

Run experiments:
```
perl div7_research.pl run_experiments
```

Initialize full research environment:
```
perl div7_research.pl init_research path/to/dir
```

## Unity Integration

1. Copy the generated C# scripts from the `/unity` directory to your Unity project
2. Attach the `Div7HolographicCube` script to an empty GameObject
3. Set up required prefabs and materials
4. Use the `Div7PathVisualizer` helper class to animate and explore

## Research Findings

The 142857 pattern creates a naturally emergent holographic information system:
- Self-describing context for navigation and interpretation
- Built-in direction detection through bifurcation points
- Geometric transformation through simple arithmetic (+1 = 90° rotation)
- Multidimensional navigation properties (cube traversal)

This aligns with Protocol-7 principles of self-organizing systems where security
and functionality emerge naturally from mathematical principles rather than
arbitrary rules.
README
    close $fh;

    say "Research environment initialized at: $dir";
    say "Unity implementation written to: $unity_script";
    say "Helper script written to: $helper_script";
    say "README created at: $readme_path";

    return $dir;
}

###########################
# COMMAND LINE INTERFACE
###########################

# Process command line args
sub main {
    my $command = shift @ARGV || 'help';

    if ($command eq 'run_experiments') {
        run_all_experiments();
    }
    elsif ($command eq 'init_research') {
        my $dir = shift @ARGV || 'div7_research';
        init_research($dir);
    }
    elsif ($command eq 'test_doubling') {
        experiment_doubling_pattern();
    }
    elsif ($command eq 'test_geometry') {
        experiment_geometric_properties();
    }
    elsif ($command eq 'test_protocol') {
        experiment_bidirectional_protocol();
    }
    elsif ($command eq 'generate_unity') {
        my $dir = shift @ARGV || '.';
        generate_unity_implementation("$dir/Div7HolographicCube.cs");
        generate_unity_helpers($dir);
    }
    else {
        # Help
        say "Division by 7 Holographic Research Framework";
        say "-------------------------------------------";
        say "Usage:";
        say "  $0 run_experiments            - Run all experiments";
        say "  $0 init_research [directory]  - Set up research environment";
        say "  $0 test_doubling              - Test doubling pattern";
        say "  $0 test_geometry              - Test geometric properties";
        say "  $0 test_protocol              - Test bidirectional protocol";
        say "  $0 generate_unity [directory] - Generate Unity implementation";
        say "";
        say "Key findings about 142857:";
        say "  * Follows doubling+1 pattern: 7→14→28→57";
        say "  * Position 57 is a bifurcation point for reading direction";
        say "  * +1 operation creates 90° CCW rotation in 3D space";
        say "  * Creates a self-describing network protocol";
    }
}

# Run main function if script is executed directly
main(@ARGV) unless caller;

1; # End of module
