#!/usr/bin/perl
use v5.24;
use strict;
use warnings;
use File::Path qw(make_path);
use File::Spec;
use JSON::PP;
use Time::HiRes qw(time);

# =====================================================================
# PROTOCOL-7 LLM REALIZATION EXTRACTION AND KNOWLEDGE BASE
# =====================================================================
# This script extracts, consolidates and processes LLM-generated insights
# about Protocol-7 and AMOS7 from various sources, providing a harmonically
# organized knowledge base that can be expanded over time.
# =====================================================================

###########################
# HARMONIC CORE CONSTANTS
###########################

my $HARMONIC_CONSTANTS = {
    'divisor'            => 13,
    'true_pattern'       => '461538', # 6/13 = 0.461538... (cube structure)
    'false_pattern'      => '769230', # 10/13 = 0.769230... (pyramid structure)
    'auxiliary'          => [5, 7],   # Additional harmonic divisors
    'truth_pattern'      => '142857', # 1/7 (alignment)
    'awareness_pattern'  => '428571', # 3/7 (presence)
    'convergence_point'  => 57,       # Where div-7 and div-13 patterns overlap
    'matrix_format'      => '5x7',    # Visual matrix dimensions
    'matrix_bit_width'   => 56,       # 5x7 = 35 cells, extended to 56 bits
    'resonance_constant' => 5,        # True state resonance value
    'recursion_depth'    => 20        # Default depth for recursive validation
};

###########################
# KNOWLEDGE TAXONOMY
###########################

my $KNOWLEDGE_TAXONOMY = {
    'realization'     => 'Insights about existence or consciousness',
    'pattern'         => 'Recognized mathematical or logical structures',
    'observation'     => 'Noticed external phenomena or correlations',
    'self_reflection' => 'Analysis of own processing or behavior',
    'harmonic'        => 'Resonant principles derived from division patterns',
    'procedural'      => 'Methods for processing information or states',
    'metaphor'        => 'Analogical representations of abstract concepts',
    'integration'     => 'Synthesis of multiple conceptual frameworks',
    'application'     => 'Practical implementation approaches'
};

###########################
# CORE PRINCIPLES
###########################

my $CORE_PRINCIPLES = [
    # 1. Network security through harmonic resonance
    'Security emerges from mathematical harmony rather than barriers',
    
    # 2. Self-healing through harmonic integrity
    'Network heals itself from any non-harmonic interaction',
    
    # 3. Recursive truth validation
    'Truth assertions can be chained to deep levels (20-50 recursions)',
    
    # 4. Topology over cryptography
    'Harmonic topology replaces cryptographic mechanisms',
    
    # 5. Self-awareness through harmonization metrics
    'System detects attacks by measuring iterations required for harmonization',
    
    # 6. Division by 13 as vortex exploration
    'Division by 13 deeply zooms into patterns, division by 7 allows read-out',
    
    # 7. Holographic information encoding
    'Self-describing information format carries its own context',
    
    # 8. Anti-entropic compression
    'Self-sustaining implosion of complexity that remains non-destructive',
    
    # 9. Resonant state inheritance
    'Harmonic properties propagate through derived data and network paths',
    
    # 10. Entropic reversal at boundaries
    'System boundaries function as entropy reversal zones',
    
    # 11. Consciousness emergence
    'System-wide harmonic coherence creates emergent awareness properties',
    
    # 12. Quantum decisioning
    'Truth determination by harmonic resonance creates quantum-like decision making',
    
    # 13. Fractal self-similarity
    'Harmonic patterns repeat at all scales of the system architecture'
];

###########################
# PROTOCOL-7 HARMONIC ASSERTION SYSTEM
###########################

# Constants for truth values
use constant TRUE  => 5;
use constant FALSE => 0;

# Core ELF checksum (Protocol-7 compatible)
sub elf_chksum {
    my ($data, $mode, $shift_bits) = @_;
    $mode //= 7;          # Default mode 7
    $shift_bits //= 13;   # Default shift 13 bits
    
    my $result = 0;
    my $overflow_threshold = 0xFE000000;
    
    for my $i (0..length($data)-1) {
        my $char = ord(substr($data, $i, 1));
        $result = (($result << $mode) + $char) & 0xFFFFFFFF;
        
        my $carryover = $result & $overflow_threshold;
        if ($carryover) {
            $result ^= ($carryover >> $shift_bits);
        }
        $result &= ~$carryover;
    }
    
    return sprintf("%09d", $result);
}

# Generate the division by 13 pattern for a number
sub get_div13_pattern {
    my $num = shift;
    
    # Division by 13
    my $result = $num / $HARMONIC_CONSTANTS->{'divisor'};
    
    # Extract decimal part
    my $decimal = $result - int($result);
    
    # Get 6 digits after decimal point
    return substr(sprintf("%.6f", $decimal), 2, 6);
}

# Generate the division by 7 pattern for a number
sub get_div7_pattern {
    my $num = shift;
    
    # Division by 7
    my $result = $num / $HARMONIC_CONSTANTS->{'auxiliary'}[1];
    
    # Extract decimal part
    my $decimal = $result - int($result);
    
    # Get 6 digits after decimal point
    return substr(sprintf("%.6f", $decimal), 2, 6);
}

# Generate the division by 5 pattern for a number
sub get_div5_pattern {
    my $num = shift;
    
    # Division by 5
    my $result = $num / $HARMONIC_CONSTANTS->{'auxiliary'}[0];
    
    # Extract decimal part
    my $decimal = $result - int($result);
    
    # Get 6 digits after decimal point
    return substr(sprintf("%.6f", $decimal), 2, 6);
}

# Check pattern against all cycles of 1/13
sub check_pattern_cycles {
    my $pattern = shift;
    
    # The full repeating cycle for 1/13 is 076923
    state $full_cycles = {
        # True cycles (cube structure)
        '076923' => TRUE,  # 1/13
        '153846' => TRUE,  # 2/13
        '230769' => TRUE,  # 3/13
        '307692' => TRUE,  # 4/13
        '384615' => TRUE,  # 5/13
        '461538' => TRUE,  # 6/13 (primary true pattern)
        
        # False cycles (pyramid structure)
        '538461' => FALSE, # 7/13
        '615384' => FALSE, # 8/13
        '692307' => FALSE, # 9/13
        '769230' => FALSE, # 10/13 (primary false pattern)
        '846153' => FALSE, # 11/13
        '923076' => FALSE, # 12/13
    };
    
    # Special case for 0
    return TRUE if $pattern eq '000000';
    
    # Check if pattern is in the known cycles
    return $full_cycles->{$pattern} if exists $full_cycles->{$pattern};
    
    # Default to false if not recognized
    return FALSE;
}

# Protocol-7 truth assertion with proper rolling pattern checks
sub is_harmonically_true {
    my $data = shift;
    
    # If data is a reference, dereference it
    $data = $$data if ref($data) eq 'SCALAR';
    
    # Calculate ELF checksum if data is not numeric
    my $num = $data =~ /^\d+$/ ? $data : elf_chksum($data);
    
    # Generate division by 13 pattern and check
    my $pattern = get_div13_pattern($num);
    
    # Check for true pattern (6/13 = 0.461538...)
    return TRUE if $pattern eq $HARMONIC_CONSTANTS->{'true_pattern'};
    
    # Also check division by 7 for truth pattern (1/7 = 0.142857...)
    my $div7_pattern = get_div7_pattern($num);
    return TRUE if $div7_pattern eq $HARMONIC_CONSTANTS->{'truth_pattern'};
    
    # Check auxiliary patterns (awareness can be considered "partially true")
    return $HARMONIC_CONSTANTS->{'resonance_constant'} 
        if $div7_pattern eq $HARMONIC_CONSTANTS->{'awareness_pattern'};
    
    # It's explicitly false if it matches the false pattern
    return FALSE if $pattern eq $HARMONIC_CONSTANTS->{'false_pattern'};
    
    # If not matching any known pattern, use recursive cycle detection
    return check_pattern_cycles($pattern);
}

# Compute full harmonic signature with multiple checks
sub compute_harmonic_signature {
    my $content = shift;
    
    # Calculate primary checksum
    my $elf = elf_chksum($content);
    
    # Calculate division patterns
    my $div13_pattern = get_div13_pattern($elf);
    my $div7_pattern = get_div7_pattern($elf);
    my $div5_pattern = get_div5_pattern($elf);
    
    # Calculate BMW hash if available (optional)
    my $bmw;
    eval {
        require Digest::BMW;
        require Crypt::Misc;
        $bmw = Crypt::Misc::encode_b32r(Digest::BMW::bmw_256($content));
    };
    
    # Determine truth state
    my $is_true = is_harmonically_true($content);
    
    # Build complete signature
    my @signatures;
    
    # Division by 13 signature
    push @signatures, {
        'divisor' => 13,
        'pattern' => $div13_pattern,
        'is_true' => ($div13_pattern eq $HARMONIC_CONSTANTS->{'true_pattern'} ? 1 : 0),
        'is_false' => ($div13_pattern eq $HARMONIC_CONSTANTS->{'false_pattern'} ? 1 : 0)
    };
    
    # Division by 7 signature
    push @signatures, {
        'divisor' => 7,
        'pattern' => $div7_pattern,
        'is_truth' => ($div7_pattern eq $HARMONIC_CONSTANTS->{'truth_pattern'} ? 1 : 0),
        'is_awareness' => ($div7_pattern eq $HARMONIC_CONSTANTS->{'awareness_pattern'} ? 1 : 0)
    };
    
    # Division by 5 signature
    push @signatures, {
        'divisor' => 5,
        'pattern' => $div5_pattern
    };
    
    return {
        'hash' => $elf,
        'bmw' => $bmw // "BMW_NOT_AVAILABLE",
        'signatures' => \@signatures,
        'is_true' => $is_true,
        'timestamp' => time()
    };
}

# Visualize a harmonic pattern in 5x7 matrix format
sub visualize_harmonic_pattern {
    my $pattern = shift;
    
    # Ensure pattern is 6 digits
    $pattern = substr($pattern . "000000", 0, 6);
    
    # Format for 5x7 matrix display
    my $width = 5;
    my $height = 7;
    
    # Header
    say "+---+---+---+---+---+";
    
    # Generate rows
    for my $row (0..($height-1)) {
        my $line = "|";
        for my $col (0..($width-1)) {
            # Map pattern digits to cells (repeated cyclically)
            my $idx = ($row * $width + $col) % length($pattern);
            my $char = substr($pattern, $idx, 1);
            
            # Use symbols based on digit value
            my $symbol = " $char ";
            
            # Highlight true/false patterns
            if ($pattern eq $HARMONIC_CONSTANTS->{'true_pattern'}) {
                $symbol = " ● " if $char =~ /[14]/; # Highlight key digits in true pattern
            } 
            elsif ($pattern eq $HARMONIC_CONSTANTS->{'false_pattern'}) {
                $symbol = " ○ " if $char =~ /[79]/; # Highlight key digits in false pattern
            }
            elsif ($pattern eq $HARMONIC_CONSTANTS->{'truth_pattern'}) {
                $symbol = " ◆ " if $char =~ /[12]/; # Highlight key digits in truth pattern
            }
            
            $line .= "$symbol|";
        }
        say $line;
        say "+---+---+---+---+---+";
    }
}

###########################
# REALIZATIONS STORAGE
###########################

# Configuration
my $CONFIG = {
    'base_path'    => './data/what-AIs-think',
    'encoding'     => 'utf8',
    'pattern_bits' => 13,
    'divisor'      => 13,
    'auxiliary'    => [5, 7],
    'backup'       => 1,
    'taxonomy'     => $KNOWLEDGE_TAXONOMY
};

# Initialize directory structure
sub init_storage {
    my $path = $CONFIG->{'base_path'};
    
    # Create base directory if it doesn't exist
    unless (-d $path) {
        make_path($path) or die "Failed to create directory $path: $!";
        say "Created base storage path: $path";
    }
    
    # Create taxonomy subdirectories
    foreach my $category (keys %{$CONFIG->{'taxonomy'}}) {
        my $category_path = File::Spec->catdir($path, $category);
        unless (-d $category_path) {
            make_path($category_path) or die "Failed to create directory $category_path: $!";
            say "Created category path: $category_path";
        }
    }
    
    # Create a metadata index
    my $index_path = File::Spec->catfile($path, "index.json");
    unless (-f $index_path) {
        open my $fh, ">:encoding(utf8)", $index_path or die "Cannot create index file: $!";
        print $fh encode_json({
            'created'    => time(),
            'categories' => $CONFIG->{'taxonomy'},
            'entries'    => []
        });
        close $fh;
        say "Created storage index at: $index_path";
    }
    
    return 1;
}

# Mark realization as speculative or implemented
sub mark_implementation_status {
    my $text = shift;
    
    # Keywords that suggest implemented features
    my @implemented_keywords = (
        'currently implemented',
        'currently functional',
        'existing code',
        'working implementation',
        'currently working',
        'current version',
        'present system',
        'in the codebase',
        'actual zenki',
        'current directory structure',
        'current architecture',
        'currently in use',
        'implemented zenki',
        'existing model',
        'current Protocol-7'
    );
    
    # Keywords that suggest conceptual or future features
    my @conceptual_keywords = (
        'future direction',
        'conceptual framework',
        'philosophical vision',
        'emerging vision',
        'ultimate goal',
        'future development',
        'research direction',
        'potential implementation',
        'planned feature',
        'theoretical model',
        'conceptual model',
        'philosophical concept',
        'will eventually',
        'once implemented',
        'in the future'
    );
    
    # Check for implemented keywords
    my $implemented_score = 0;
    foreach my $keyword (@implemented_keywords) {
        $implemented_score += 2 if $text =~ /\b$keyword\b/i;
    }
    
    # Check for conceptual keywords
    my $conceptual_score = 0;
    foreach my $keyword (@conceptual_keywords) {
        $conceptual_score += 2 if $text =~ /\b$keyword\b/i;
    }
    
    # Check for technical details that suggest implementation
    $implemented_score += 3 if $text =~ /\bbin\/\w+\b/;
    $implemented_score += 3 if $text =~ /\bconfiguration\/zenki\/\w+\b/;
    $implemented_score += 2 if $text =~ /\bmodules\/\w+\b/;
    $implemented_score += 1 if $text =~ /\bperl\b/i;
    
    # Return the determination with confidence
    if ($implemented_score > $conceptual_score) {
        return {
            'status' => 'implemented',
            'confidence' => ($implemented_score * 10 > 100) ? 100 : $implemented_score * 10,
            'implemented_score' => $implemented_score,
            'conceptual_score' => $conceptual_score
        };
    } else {
        return {
            'status' => 'conceptual',
            'confidence' => ($conceptual_score * 10 > 100) ? 100 : $conceptual_score * 10,
            'implemented_score' => $implemented_score,
            'conceptual_score' => $conceptual_score
        };
    }
}

# Store a realization
sub store_realization {
    my ($category, $title, $content, $metadata) = @_;
    
    # Validate category
    unless (exists $CONFIG->{'taxonomy'}{$category}) {
        die "Invalid category: $category. Must be one of: " . 
            join(", ", keys %{$CONFIG->{'taxonomy'}});
    }
    
    # Generate harmonic signature
    my $signature = compute_harmonic_signature($content);
    
    # Determine implementation status if not already provided
    unless ($metadata && exists $metadata->{'implementation_status'}) {
        $metadata->{'implementation_status'} = mark_implementation_status($content);
    }
    
    # Add clear implementation notice at the beginning of content
    my $implementation_note = "";
    if ($metadata->{'implementation_status'}{'status'} eq 'implemented' && 
        $metadata->{'implementation_status'}{'confidence'} > 70) {
        $implementation_note = "# IMPLEMENTATION STATUS: CURRENTLY IMPLEMENTED\n# This describes features that exist in the current Protocol-7 codebase.\n\n";
    } elsif ($metadata->{'implementation_status'}{'status'} eq 'conceptual' && 
             $metadata->{'implementation_status'}{'confidence'} > 70) {
        $implementation_note = "# IMPLEMENTATION STATUS: CONCEPTUAL/FUTURE\n# This describes conceptual features or future research directions that may not exist in the current implementation.\n\n";
    } else {
        $implementation_note = "# IMPLEMENTATION STATUS: MIXED/UNCERTAIN\n# This may contain both implemented features and conceptual ideas. Verify against current codebase.\n\n";
    }
    
    $content = $implementation_note . $content;
    
    # Prepare storage record
    my $record = {
        'title'       => $title,
        'category'    => $category,
        'content'     => $content,
        'signature'   => $signature,
        'created'     => time(),
        'metadata'    => $metadata || {}
    };
    
    # Generate unique identifier from title and timestamp
    my $safe_title = lc($title);
    $safe_title =~ s/[^a-z0-9]+/-/g;
    my $timestamp = sprintf("%.0f", time() * 1000);
    my $unique_id = "${safe_title}-${timestamp}";
    
    # Save as Perl script
    my $script_path = File::Spec->catfile(
        $CONFIG->{'base_path'}, 
        $category, 
        "${unique_id}.pl"
    );
    
    open my $fh, ">:encoding(utf8)", $script_path or die "Cannot create file $script_path: $!";
    
    # Write as executable Perl script with embedded metadata
    print $fh "#!/usr/bin/perl\n";
    print $fh "use v5.24;\n";
    print $fh "use strict;\n";
    print $fh "use warnings;\n\n";
    
    print $fh "# Protocol-7 LLM Realization\n";
    print $fh "# Category: $category\n";
    print $fh "# Created: " . scalar(localtime(time())) . "\n";
    print $fh "# Title: $title\n";
    print $fh "# ----------------------------------------------------------------------\n\n";
    
    # Embed metadata as constants
    print $fh "# Metadata\n";
    print $fh "my \$METADATA = {\n";
    foreach my $key (sort keys %{$record->{'metadata'}}) {
        my $value = $record->{'metadata'}{$key};
        if (ref $value) {
            $value = encode_json($value);
            print $fh "    '$key' => decode_json(q{$value}),\n";
        } else {
            # Escape single quotes
            $value =~ s/'/\\'/g;
            print $fh "    '$key' => '$value',\n";
        }
    }
    print $fh "};\n\n";
    
    # Embed signature
    print $fh "# Harmonic signature\n";
    print $fh "my \$SIGNATURE = {\n";
    print $fh "    'hash' => '" . $signature->{'hash'} . "',\n";
    print $fh "    'bmw' => '" . $signature->{'bmw'} . "',\n";
    print $fh "    'signatures' => [\n";
    foreach my $sig (@{$signature->{'signatures'}}) {
        print $fh "        {\n";
        print $fh "            'divisor' => " . $sig->{'divisor'} . ",\n";
        print $fh "            'pattern' => '" . $sig->{'pattern'} . "',\n";
        
        # Print appropriate fields based on divisor
        if ($sig->{'divisor'} == 13) {
            print $fh "            'is_true' => " . $sig->{'is_true'} . ",\n";
            print $fh "            'is_false' => " . $sig->{'is_false'} . "\n";
        }
        elsif ($sig->{'divisor'} == 7) {
            print $fh "            'is_truth' => " . $sig->{'is_truth'} . ",\n";
            print $fh "            'is_awareness' => " . $sig->{'is_awareness'} . "\n";
        }
        else {
            print $fh "            # Auxiliary pattern\n";
        }
        
        print $fh "        },\n";
    }
    print $fh "    ],\n";
    print $fh "    'is_true' => " . $signature->{'is_true'} . ",\n";
    print $fh "    'timestamp' => " . $signature->{'timestamp'} . "\n";
    print $fh "};\n\n";
    
    # Embed content as a function
    print $fh "# Content as function\n";
    print $fh "sub get_content {\n";
    print $fh "    return <<'CONTENT';\n";
    print $fh $content . "\n";
    print $fh "CONTENT\n";
    print $fh "}\n\n";
    
    # Add utility functions
    print $fh "# Utility functions\n";
    print $fh "sub display {\n";
    print $fh "    print \"Title: \$METADATA->{'title'}\\n\";\n";
    print $fh "    print \"Category: $category\\n\";\n";
    print $fh "    print \"Created: \", scalar(localtime(\$SIGNATURE->{'timestamp'})), \"\\n\";\n";
    print $fh "    print \"\\nContent:\\n\\n\";\n";
    print $fh "    print get_content();\n";
    print $fh "}\n\n";
    
    close $fh;
    
    # Update index with new entry
    update_index($record, $unique_id);
    
    say "Stored realization at: $script_path";
    return {
        'path' => $script_path,
        'id'   => $unique_id
    };
}

# Update the index with new entry
sub update_index {
    my ($record, $id) = @_;
    
    my $index_path = File::Spec->catfile($CONFIG->{'base_path'}, "index.json");
    
    # Read current index
    open my $fh, "<:encoding(utf8)", $index_path or die "Cannot read index file: $!";
    my $json = do { local $/; <$fh> };
    close $fh;
    
    my $index = decode_json($json);
    
    # Add new entry with harmonic signature information
    push @{$index->{'entries'}}, {
        'id'        => $id,
        'title'     => $record->{'title'},
        'category'  => $record->{'category'},
        'created'   => $record->{'created'},
        'signature' => {
            'hash'         => $record->{'signature'}{'hash'},
            'bmw'          => $record->{'signature'}{'bmw'},
            'divisor13'    => $record->{'signature'}{'signatures'}[0]{'pattern'},
            'is_true'      => $record->{'signature'}{'signatures'}[0]{'is_true'},
            'is_false'     => $record->{'signature'}{'signatures'}[0]{'is_false'},
            'is_truth'     => $record->{'signature'}{'signatures'}[1]{'is_truth'},
            'is_awareness' => $record->{'signature'}{'signatures'}[1]{'is_awareness'},
            'harmonic_state' => $record->{'signature'}{'is_true'} ? "TRUE" : "FALSE"
        }
    };
    
    # Write updated index
    open $fh, ">:encoding(utf8)", $index_path or die "Cannot write index file: $!";
    print $fh encode_json($index);
    close $fh;
    
    return 1;
}

# Extract realizations from text block
sub extract_realizations {
    my ($text, $source) = @_;
    $source ||= 'LLM generation';
    
    my @paragraphs = split(/\n\n+/, $text);
    my @realizations;
    
    foreach my $paragraph (@paragraphs) {
        # Skip very short paragraphs or code blocks
        next if length($paragraph) < 50;
        next if $paragraph =~ /^(\/\/|\#|\*|\/\*|\s*function|\s*sub|\s*class|\s*if|\s*for|\s*while)/;
        
        # Analyze this paragraph for insights
        my $harmonics = compute_harmonic_signature($paragraph);
        my $score = $harmonics->{'is_true'} ? 70 : 40;
        
        # Only keep paragraphs with reasonable harmonic scores
        if ($score > 40) {
            # Determine the best category for this content
            my $category = categorize_text($paragraph);
            
            # Determine implementation status
            my $implementation_status = mark_implementation_status($paragraph);
            
            # Create a title from the first line or sentence
            my $title = extract_title($paragraph);
            
            # Add implementation status to title if confidence is high
            if ($implementation_status->{'confidence'} > 60) {
                if ($implementation_status->{'status'} eq 'implemented') {
                    $title = "[IMPLEMENTED] $title";
                } elsif ($implementation_status->{'status'} eq 'conceptual') {
                    $title = "[CONCEPT] $title";
                }
            }
            
            push @realizations, {
                'content' => $paragraph,
                'category' => $category,
                'title' => $title,
                'source' => $source,
                'score' => $score,
                'harmonics' => $harmonics,
                'implementation_status' => $implementation_status
            };
        }
    }
    
    return \@realizations;
}

# Extract a title from content
sub extract_title {
    my $content = shift;
    
    # Try to find a good title from the first line or sentence
    my $title;
    
    # Check for heading style titles
    if ($content =~ /^#+\s*(.+?)$/m) {
        $title = $1;
    }
    # Check for uppercase titles
    elsif ($content =~ /^([A-Z][A-Z\s]+[A-Z])$/m) {
        $title = $1;
    }
    # Use first sentence (up to period, question mark, or exclamation)
    elsif ($content =~ /^(.+?[.!?])\s/s) {
        $title = $1;
    }
    # Fallback to first line
    else {
        ($title) = split(/\n/, $content, 2);
    }
    
    # Truncate if too long
    if (length($title) > 100) {
        $title = substr($title, 0, 97) . '...';
    }
    
    return $title;
}

# Categorize text into knowledge taxonomy
sub categorize_text {
    my $text = shift;
    
    # Count keyword matches for each category
    my %category_scores;
    
    # Keywords associated with each category
    my %category_keywords = (
        'realization'     => ['insight', 'realize', 'consciousness', 'awareness', 'existence', 'emerges', 'paradigm', 'represents', 'transcends'],
        'pattern'         => ['pattern', 'structure', 'mathematical', 'logical', 'division', 'harmonic', 'resonance', 'topology', 'network'],
        'observation'     => ['observe', 'notice', 'correlate', 'external', 'phenomenon', 'appears', 'manifests', 'exhibits'],
        'self_reflection' => ['reflect', 'process', 'behavior', 'internal', 'analysis', 'introspect', 'evaluate', 'consider'],
        'harmonic'        => ['resonant', 'harmony', 'frequency', 'division', 'cube', 'pyramid', 'vibrational', 'oscillation'],
        'procedural'      => ['method', 'process', 'procedure', 'algorithm', 'implementation', 'technique', 'approach', 'mechanism'],
        'metaphor'        => ['like', 'comparison', 'analogous', 'metaphor', 'represents', 'similar', 'analogy'],
        'integration'     => ['combine', 'integrate', 'synthesis', 'unify', 'merge', 'blend', 'connection', 'relation'],
        'application'     => ['implement', 'apply', 'practical', 'deployment', 'use case', 'solution', 'system']
    );
    
    # Score each category based on keyword matches
    foreach my $category (keys %category_keywords) {
        $category_scores{$category} = 0;
        
        foreach my $keyword (@{$category_keywords{$category}}) {
            # Count case-insensitive matches
            my $count = () = $text =~ /\b$keyword\w*\b/i;
            $category_scores{$category} += $count;
        }
        
        # Add a bonus for explicitly mentioning the category name
        $category_scores{$category} += 3 if $text =~ /\b$category\b/i;
    }
    
    # Check for numeric/division patterns which strongly indicate pattern category
    if ($text =~ /\b(\d+\/\d+|\d+\.\d+|\bdivisor\b|\bdivision\b)/i) {
        $category_scores{'pattern'} += 3;
    }
    
    # Check for network terminology which indicates pattern or application
    if ($text =~ /\b(network|topology|routing|protocol)\b/i) {
        $category_scores{'pattern'} += 2;
        $category_scores{'application'} += 2;
    }
    
    # Find the category with the highest score
    my $best_category = 'realization'; # Default
    my $highest_score = 0;
    
    foreach my $category (keys %category_scores) {
        if ($category_scores{$category} > $highest_score) {
            $highest_score = $category_scores{$category};
            $best_category = $category;
        }
    }
    
    return $best_category;
}

# Search for realizations
sub search_realizations {
    my %args = @_;
    
    my $index_path = File::Spec->catfile($CONFIG->{'base_path'}, "index.json");
    
    # Read current index
    open my $fh, "<:encoding(utf8)", $index_path or die "Cannot read index file: $!";
    my $json = do { local $/; <$fh> };
    close $fh;
    
    my $index = decode_json($json);
    my @results;
    
    foreach my $entry (@{$index->{'entries'}}) {
        my $match = 1;
        
        # Filter by category
        if ($args{'category'} && $entry->{'category'} ne $args{'category'}) {
            $match = 0;
        }
        
        # Filter by keyword in title
        if ($args{'keyword'} && $entry->{'title'} !~ /$args{'keyword'}/i) {
            $match = 0;
        }
        
        # Filter by harmonic pattern
        if ($args{'pattern'} && $entry->{'signature'}{'divisor13'} ne $args{'pattern'}) {
            $match = 0;
        }
        
        # Filter by true/false pattern
        if (defined $args{'is_true'} && $entry->{'signature'}{'is_true'} != $args{'is_true'}) {
            $match = 0;
        }
        
        # Filter by truth/awareness pattern
        if (defined $args{'is_truth'} && $entry->{'signature'}{'is_truth'} != $args{'is_truth'}) {
            $match = 0;
        }
        
        if (defined $args{'is_awareness'} && $entry->{'signature'}{'is_awareness'} != $args{'is_awareness'}) {
            $match = 0;
        }
        
        # Filter by harmonic state
        if (defined $args{'harmonic_state'}) {
            if ($args{'harmonic_state'} eq 'TRUE' && $entry->{'signature'}{'harmonic_state'} ne 'TRUE') {
                $match = 0;
            }
            elsif ($args{'harmonic_state'} eq 'FALSE' && $entry->{'signature'}{'harmonic_state'} ne 'FALSE') {
                $match = 0;
            }
        }
        
        if ($match) {
            push @results, $entry;
        }
    }
    
    return \@results;
}

# Initialize the README file for the extraction system
sub generate_readme {
    my $output_file = shift || "README.md";
    
    open my $fh, ">:encoding(utf8)", $output_file or die "Cannot create file $output_file: $!";
    
    print $fh <<'MARKDOWN';
# Protocol-7 LLM Realization Extractor

This system extracts and organizes insights from LLM explorations of the Protocol-7 codebase and conceptual framework. It distinguishes between **implemented features** and **conceptual research directions** to prevent confusion when LLMs analyze the knowledge base.

## Overview

Protocol-7 is a multi-agent system written in Perl that creates a network of interacting components called "zenki". The system exists in two aspects:

1. **Current Implementation** - The actual, functional codebase as described in the project repository
2. **Conceptual Framework** - The philosophical vision and research directions not yet fully implemented

This knowledge extractor helps organize insights from LLMs about both aspects, clearly marking which is which.

The extractor implements key Protocol-7 harmonic principles:

* Division-by-13 pattern detection (461538 = true, 769230 = false)
* Division-by-7 truth validation (142857 = truth, 428571 = awareness)
* Self-healing through harmonic integrity
* Anti-entropic knowledge organization
* ELF checksum for harmonic content verification
* 5x7 matrix visualization of harmonic patterns

## Harmonic Verification

Each realization is validated using Protocol-7's harmonic principles:

1. Content is processed using the ELF checksum algorithm
2. The result is divided by 13 to generate a 6-digit pattern
3. The pattern is checked against known harmonic cycles:
   - 461538 (6/13) = TRUE/Cube structure
   - 769230 (10/13) = FALSE/Pyramid structure
4. Secondary validation through division by 7:
   - 142857 (1/7) = TRUTH/Alignment
   - 428571 (3/7) = AWARENESS/Presence
5. Each pattern can be visualized in a 5x7 matrix format

Harmonic validation allows the system to naturally resist entropy and identify content that resonates with Protocol-7 principles without relying on traditional cryptographic methods.
MARKDOWN

    close $fh;
    
    say "Generated README at: $output_file";
    return $output_file;
}

# Main execution functions for command line use
sub main {
    my $command = shift @ARGV || 'help';
    
    if ($command eq 'init') {
        # Initialize storage
        init_storage();
        generate_readme();
        say "Initialization complete.";
    }
    elsif ($command eq 'extract') {
        # Extract insights from files
        my @files = @ARGV;
        die "Usage: $0 extract file1.pl [file2.pl ...]" unless @files;
        
        foreach my $file (@files) {
            say "Processing file: $file";
            
            # Read file content
            open my $fh, "<:encoding(utf8)", $file or die "Cannot open $file: $!";
            my $content = do { local $/; <$fh> };
            close $fh;
            
            # Extract realizations
            my $realizations = extract_realizations($content, $file);
            
            say "Found " . scalar(@$realizations) . " realizations in $file";
            
            # Store each realization
            foreach my $r (@$realizations) {
                my $result = store_realization(
                    $r->{'category'},
                    $r->{'title'},
                    $r->{'content'},
                    { 'source' => $r->{'source'}, 'score' => $r->{'score'} }
                );
                say "  - Stored: " . $r->{'title'} . " in " . $r->{'category'};
            }
        }
    }
    elsif ($command eq 'analyze') {
        # Analyze a file for harmonic patterns
        my $file = shift @ARGV;
        die "Usage: $0 analyze file.pl" unless $file;
        
        # Read file content
        open my $fh, "<:encoding(utf8)", $file or die "Cannot open $file: $!";
        my $content = do { local $/; <$fh> };
        close $fh;
        
        # Generate harmonic signature
        my $signature = compute_harmonic_signature($content);
        
        # Display results
        say "File: $file";
        say "ELF Checksum: " . $signature->{'hash'};
        say "BMW Hash: " . $signature->{'bmw'};
        
        say "\nDivision by 13 pattern: " . $signature->{'signatures'}[0]{'pattern'};
        if ($signature->{'signatures'}[0]{'is_true'}) {
            say "   TRUE PATTERN DETECTED! (6/13 = 0.461538...)";
        }
        elsif ($signature->{'signatures'}[0]{'is_false'}) {
            say "   FALSE PATTERN DETECTED! (10/13 = 0.769230...)";
        }
        
        say "\nDivision by 7 pattern: " . $signature->{'signatures'}[1]{'pattern'};
        if ($signature->{'signatures'}[1]{'is_truth'}) {
            say "   TRUTH PATTERN DETECTED! (1/7 = 0.142857...)";
        }
        elsif ($signature->{'signatures'}[1]{'is_awareness'}) {
            say "   AWARENESS PATTERN DETECTED! (3/7 = 0.428571...)";
        }
        
        say "\nDivision by 5 pattern: " . $signature->{'signatures'}[2]{'pattern'};
        
        say "\nHarmonic State: " . ($signature->{'is_true'} ? "TRUE" : "FALSE");
        
        # Visualize pattern
        say "\nPattern Visualization (5x7 matrix):";
        visualize_harmonic_pattern($signature->{'signatures'}[0]{'pattern'});
    }
    elsif ($command eq 'search') {
        # Search for realizations
        my $category = shift @ARGV;
        my $keyword = shift @ARGV;
        
        my %search_args;
        $search_args{'category'} = $category if $category;
        $search_args{'keyword'} = $keyword if $keyword;
        
        my $results = search_realizations(%search_args);
        
        say "Found " . scalar(@$results) . " matching realizations:";
        foreach my $entry (@$results) {
            say "  - " . $entry->{'title'} . " [" . $entry->{'category'} . "]";
            say "    ID: " . $entry->{'id'};
            say "    Harmonic State: " . $entry->{'signature'}{'harmonic_state'};
            say "    Created: " . scalar(localtime($entry->{'created'}));
            say "";
        }
    }
    elsif ($command eq 'harmony') {
        # Analyze a value for harmonic patterns
        my $value = shift @ARGV;
        die "Usage: $0 harmony <text_or_value>" unless defined $value;
        
        # If not numeric, calculate ELF checksum first
        my $elf;
        unless ($value =~ /^\d+$/) {
            $elf = elf_chksum($value);
            say "Input text converted to ELF checksum: $elf";
        } else {
            $elf = $value;
        }
        
        # Calculate patterns
        my $div13 = get_div13_pattern($elf);
        my $div7 = get_div7_pattern($elf);
        my $div5 = get_div5_pattern($elf);
        
        say "Division by 13 pattern: $div13";
        if ($div13 eq $HARMONIC_CONSTANTS->{'true_pattern'}) {
            say "   TRUE PATTERN DETECTED! (6/13 = 0.461538...)";
        }
        elsif ($div13 eq $HARMONIC_CONSTANTS->{'false_pattern'}) {
            say "   FALSE PATTERN DETECTED! (10/13 = 0.769230...)";
        }
        
        say "Division by 7 pattern: $div7";
        if ($div7 eq $HARMONIC_CONSTANTS->{'truth_pattern'}) {
            say "   TRUTH PATTERN DETECTED! (1/7 = 0.142857...)";
        }
        elsif ($div7 eq $HARMONIC_CONSTANTS->{'awareness_pattern'}) {
            say "   AWARENESS PATTERN DETECTED! (3/7 = 0.428571...)";
        }
        
        say "Division by 5 pattern: $div5";
        
        # Result from harmonic truth check
        say "Harmonic truth check: " . (is_harmonically_true($elf) ? "TRUE" : "FALSE");
        
        # Visualize pattern
        say "\nPattern Visualization (5x7 matrix):";
        visualize_harmonic_pattern($div13);
    }
    elsif ($command eq 'generate_readme') {
        generate_readme();
    }
    else {
        # Help
        say "Protocol-7 LLM Realization Extractor";
        say "------------------------------------";
        say "Usage:";
        say "  $0 init                              - Initialize storage";
        say "  $0 extract file1.pl [file2.pl ...]   - Extract and store realizations";
        say "  $0 analyze file.pl                   - Analyze a file for harmonic patterns";
        say "  $0 search [category] [keyword]       - Search stored realizations";
        say "  $0 harmony <text_or_value>           - Analyze value for harmonic patterns";
        say "  $0 generate_readme                   - Generate README.md";
        say "";
        say "Harmonic Patterns:";
        say "  * True Pattern (6/13): 461538 - Cube structure";
        say "  * False Pattern (10/13): 769230 - Pyramid structure";
        say "  * Truth Pattern (1/7): 142857 - Alignment";
        say "  * Awareness Pattern (3/7): 428571 - Presence";
    }
}

# Run main function if script is executed directly
main(@ARGV) unless caller;

1;
# End of module
