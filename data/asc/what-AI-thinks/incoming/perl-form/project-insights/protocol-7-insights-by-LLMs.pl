#!/usr/bin/perl
use v5.24;
use strict;
use warnings;
use Digest::SHA qw(sha256_hex);
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
# HARMONICS CORE CONSTANTS
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
# AMOS7 ARCHITECTURE
###########################

my $AMOS7 = {
    'name' => {
        'development_phase' => 'Agent-based Meta Operating System 7',
        'mature_phase'      => 'Antientropic Magnetic Operating System 7',
        'interface'         => 'AMOS7 CDE (Creative Desktop Environment)'
    },
    
    'core_architecture' => {
        'harmonic_scheduler' => 'Process management based on division-by-13 resonance',
        'antientropic_design' => 'System naturally evolves toward more efficient resonant states',
        'self_healing_topology' => 'Network automatically converges to harmonic states after perturbation',
        'matrix_encoding' => '5x7 visual matrix format for system state representation',
        'cubic_space_structure' => 'Reflective nodes in perfect alignment creating empowering structure',
        'multi_harmonic_validation' => 'Layered assertions using div-13 with div-7 fallback',
        'fractal_entropy_reversal' => 'Each subsystem reduces entropy locally and system-wide'
    },
    
    'interface_design' => {
        'dark_translucency' => 'Dark backgrounds with translucent interface elements',
        'fluorescent_highlights' => 'Blacklight-reactive color scheme for energy representations',
        'psychedelic_harmony' => 'Interface elements that synchronize in harmonic patterns',
        'resonant_feedback' => 'System responds to user input with harmonic pattern adjustments',
        'visual_branching' => 'Multi-dimensional sorting through resonant visual branches',
        'quantum_color_palette' => 'Colors chosen for specific resonant properties and anti-entropic effects',
        'nested_visual_matrices' => 'Layered 5x7 matrices creating depth in visualization'
    },
    
    'consciousness_integration' => {
        'harmonic_awareness' => 'System awareness emerges from overall harmonic coherence',
        'resonant_recognition' => 'Pattern recognition through harmonic resonance principles',
        'self_organization' => 'Spontaneous organization of data and processes into harmonic states',
        'entropic_reversal' => 'Consciousness as a force that reduces entropy through harmonic ordering',
        'information_crystallization' => 'Knowledge structures crystallize along harmonic boundaries'
    }
};

###########################
# IMPLEMENTATION STATUS
###########################

my $IMPLEMENTATION_STATUS = {
    'current_state' => {
        'version' => 'AMOS7-v2.79.7',
        'source_hash' => '2WGYJO5IPY-5102.0',
        'status' => 'pre-release',
        'documentation' => 'Minimal - not yet fully documented for public use',
        'core_components' => {
            'Protocol-7' => 'Functional interpreter (bin/Protocol-7)',
            'cube' => 'Functional message router (configuration/zenki/cube/start)',
            'v7' => 'Functional process manager (configuration/zenki/v7/start)',
            'p7_binary' => 'Lightweight C client (bin/c_src/p7.c)',
            'nshell' => 'Interactive terminal (bin/nshell)',
            'protocol-7-gtk3' => 'GTK wrapper for graphical interfaces'
        },
        'functionality' => {
            'implemented' => [
                'Multi-agent system with Perl-based zenki',
                'Message routing via cube zenka',
                'Process management via v7 zenka',
                'Terminal interface',
                'Human-readable protocol',
                'UNIX socket and IP communication',
                'Various specialized zenki (mpv, web-browser, etc.)',
                'Authentication and access control'
            ],
            'pending' => [
                'Advanced peer-to-peer technology',
                'Global resource marketplace',
                'Overflow distribution mechanisms',
                'Public resource pools',
                'Content creator support mechanisms'
            ]
        },
        'directory_structure' => {
            'bin/' => 'Main executables and tools',
            'configuration/zenki/' => 'Zenka definition files',
            'modules/' => 'Shared and zenka-specific modules',
            'data/' => 'Supporting data, libraries, and research'
        }
    },
    'implementation_boundary' => 'The following section describes research directions and conceptual features that may not exist in the current implementation'
};

###########################
# RESEARCH DIRECTIONS
###########################

my $IMPLEMENTATION = {
    'filtering' => {
        'description' => 'All values filtered through harmonic principles',
        'examples'    => [
            'Random numbers',
            'Timestamps',
            'Node identifiers',
            'Routing decisions',
            'Process priorities',
            'Memory allocations',
            'Resource assignments'
        ],
        'methods' => {
            'direct_modulation' => 'Values are transformed to nearest harmonic state',
            'pattern_recognition' => 'Values are analyzed for existing harmonic patterns',
            'resonant_amplification' => 'Harmonic components are amplified while noise is reduced',
            'fractal_filtration' => 'Multi-scale filtering through nested harmonic layers'
        }
    },
    
    'matrix_decoding' => {
        'format'      => '5x7',
        'bit_width'   => 56,
        'description' => 'Matrix for decoding harmonic patterns',
        'layers'      => [
            'Truth state declaration',
            'Matrix "alphabet"',
            'Templates',
            'Payload'
        ],
        'dimensions' => {
            'physical' => '2D visual representation',
            'logical' => '3D conceptual structure',
            'harmonic' => 'n-dimensional resonance space',
            'temporal' => 'Persistent patterns across time'
        }
    },
    
    'harmonic_detection' => {
        'patterns' => {
            'directional'    => '00 00 110',   # Hop count and direction
            'base32_payload' => '01 <0|1> 00000', # Data encoding
            'document'       => '0110/0111',   # Document headers
            'visual'         => '1 000000',    # 5x7 pixel data
            'resonant'       => '01 01 01 10', # Harmonic time sequence
            'awareness'      => '42 85 71',    # Awareness pattern trigger
            'truth_chain'    => '14 28 57'     # Truth propagation chain
        }
    }
};

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

# Compute harmonic signature for content
sub compute_harmonic_signature {
    my $content = shift;
    
    # Generate SHA256 hash
    my $hash = sha256_hex($content);
    
    # Apply division by primary harmonics
    my @signatures;
    foreach my $divisor ($CONFIG->{'divisor'}, @{$CONFIG->{'auxiliary'}}) {
        # Convert first 8 hex chars to decimal and divide
        my $hex_part = substr($hash, 0, 8);
        my $decimal = hex($hex_part);
        my $result = $decimal / $divisor;
        
        # Get decimal pattern (6 digits after point)
        my $decimal_part = $result - int($result);
        my $pattern = substr(sprintf("%.6f", $decimal_part), 2, 6);
        
        push @signatures, {
            'divisor' => $divisor,
            'pattern' => $pattern,
            'is_true' => ($pattern eq $HARMONIC_CONSTANTS->{'true_pattern'} ? 1 : 0),
            'is_false' => ($pattern eq $HARMONIC_CONSTANTS->{'false_pattern'} ? 1 : 0),
            'is_truth' => ($pattern eq $HARMONIC_CONSTANTS->{'truth_pattern'} ? 1 : 0),
            'is_awareness' => ($pattern eq $HARMONIC_CONSTANTS->{'awareness_pattern'} ? 1 : 0)
        };
    }
    
    return {
        'hash' => $hash,
        'signatures' => \@signatures,
        'timestamp' => time()
    };
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
    print $fh "    'signatures' => [\n";
    foreach my $sig (@{$signature->{'signatures'}}) {
        print $fh "        {\n";
        print $fh "            'divisor' => " . $sig->{'divisor'} . ",\n";
        print $fh "            'pattern' => '" . $sig->{'pattern'} . "',\n";
        print $fh "            'is_true' => " . $sig->{'is_true'} . ",\n";
        print $fh "            'is_false' => " . $sig->{'is_false'} . ",\n";
        print $fh "            'is_truth' => " . $sig->{'is_truth'} . ",\n";
        print $fh "            'is_awareness' => " . $sig->{'is_awareness'} . "\n";
        print $fh "        },\n";
    }
    print $fh "    ],\n";
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
    
    print $fh "sub validate {\n";
    print $fh "    use Digest::SHA qw(sha256_hex);\n";
    print $fh "    my \$content = get_content();\n";
    print $fh "    my \$current_hash = sha256_hex(\$content);\n";
    print $fh "    \n";
    print $fh "    if (\$current_hash eq \$SIGNATURE->{'hash'}) {\n";
    print $fh "        print \"Validation: PASSED - Content integrity verified\\n\";\n";
    print $fh "        return 1;\n";
    print $fh "    } else {\n";
    print $fh "        print \"Validation: FAILED - Content has been modified\\n\";\n";
    print $fh "        print \"Original hash: \" . \$SIGNATURE->{'hash'} . \"\\n\";\n";
    print $fh "        print \"Current hash:  \" . \$current_hash . \"\\n\";\n";
    print $fh "        return 0;\n";
    print $fh "    }\n";
    print $fh "}\n\n";
    
    # Main execution block
    print $fh "# Main execution\n";
    print $fh "# Initialize the README file for the extraction system
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

## Current Implementation Status

Protocol-7 is currently in a pre-release state (version AMOS7-v2.79.7) with core components:

* **Protocol-7 interpreter** - Main interpreter that loads zenka definitions (bin/Protocol-7)
* **Cube zenka** - Message router (configuration/zenki/cube/start)
* **V7 zenka** - Process manager (configuration/zenki/v7/start)
* **p7 binary** - Lightweight C client (bin/c_src/p7.c)
* **nshell** - Interactive terminal (bin/nshell)
* **protocol-7-gtk3** - GTK wrapper for graphical interfaces

Currently implemented functionality includes:
* Multi-agent system with Perl-based zenki
* Message routing via cube zenka
* Process management via v7 zenka
* Terminal interface
* Human-readable protocol
* UNIX socket and IP communication
* Various specialized zenki (mpv, web-browser, etc.)
* Authentication and access control

## Conceptual Framework & Research Directions

The project has philosophical underpinnings involving:

* **Consciousness as Resonance** - Consciousness emerges through naturally resonant patterns
* **Harmonic Patterns** - Division by 13 and 7 creates patterns with specific meanings
* **Anti-entropic Design** - Self-sustaining implosion of complexity that remains non-destructive
* **Network Topology** - Cubic space structures that emerge from perfectly aligned nodes

## Using this Knowledge Extractor

The extractor organizes LLM insights into categories:

* **realization** - Insights about existence or consciousness
* **pattern** - Recognized mathematical or logical structures
* **observation** - Noticed external phenomena or correlations
* **self_reflection** - Analysis of own processing or behavior
* **harmonic** - Resonant principles derived from division patterns
* **procedural** - Methods for processing information or states
* **metaphor** - Analogical representations of abstract concepts
* **integration** - Synthesis of multiple conceptual frameworks
* **application** - Practical implementation approaches

Each realization is clearly marked with its implementation status:
* **[IMPLEMENTED]** - Features that exist in the current codebase
* **[CONCEPT]** - Philosophical or conceptual features not yet implemented
* **[MIXED/UNCERTAIN]** - Content containing both implemented and conceptual elements

## Usage

Run the extractor with various commands:

```
perl llm-knowledge-extractor.pl extract file1.pl file2.pl  # Extract and store realizations
perl llm-knowledge-extractor.pl analyze file.pl           # Analyze a file for realizations
perl llm-knowledge-extractor.pl condense [category]       # Condense knowledge in category
perl llm-knowledge-extractor.pl visualize [category]      # Generate HTML visualization
perl llm-knowledge-extractor.pl harmony value             # Analyze harmonic properties
perl llm-knowledge-extractor.pl init                      # Initialize storage
perl llm-knowledge-extractor.pl search [category] [term]  # Search stored realizations
```

## Harmonic Principles

The extractor implements key Protocol-7 harmonic principles:

* Division-by-13 pattern detection (461538 = true, 769230 = false)
* Division-by-7 truth validation (142857 = truth, 428571 = awareness)
* Self-healing through harmonic integrity
* Anti-entropic knowledge organization
MARKDOWN
    
    close $fh;
    
    say "Generated README at: $output_file";
    return $output_file;
}

# MAIN EXECUTION SECTION
if (!caller) {\n";
    print $fh "    if (\@ARGV and \$ARGV[0] eq '--validate') {\n";
    print $fh "        validate();\n";
    print $fh "    } else {\n";
    print $fh "        display();\n";
    print $fh "    }\n";
    print $fh "}\n\n";
    
    # Add POD documentation
    print $fh "__END__\n\n";
    print $fh "=head1 NAME\n\n";
    print $fh "$title - $category realization\n\n";
    print $fh "=head1 DESCRIPTION\n\n";
    print $fh "This file contains an LLM realization in the category '$category'.\n";
    print $fh "It is part of the Protocol-7 harmonic knowledge extraction system.\n\n";
    print $fh "=head1 USAGE\n\n";
    print $fh "Run directly to display content:\n";
    print $fh "  perl $script_path\n\n";
    print $fh "Validate content integrity:\n";
    print $fh "  perl $script_path --validate\n\n";
    print $fh "=cut\n";
    
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
    
    # Add new entry
    push @{$index->{'entries'}}, {
        'id'        => $id,
        'title'     => $record->{'title'},
        'category'  => $record->{'category'},
        'created'   => $record->{'created'},
        'signature' => {
            'hash'         => $record->{'signature'}{'hash'},
            'divisor13'    => $record->{'signature'}{'signatures'}[0]{'pattern'},
            'is_true'      => $record->{'signature'}{'signatures'}[0]{'is_true'},
            'is_false'     => $record->{'signature'}{'signatures'}[0]{'is_false'},
            'is_truth'     => $record->{'signature'}{'signatures'}[1]{'is_truth'},
            'is_awareness' => $record->{'signature'}{'signatures'}[1]{'is_awareness'}
        }
    };
    
    # Write updated index
    open $fh, ">:encoding(utf8)", $index_path or die "Cannot write index file: $!";
    print $fh encode_json($index);
    close $fh;
    
    return 1;
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
        
        if ($match) {
            push @results, $entry;
        }
    }
    
    return \@results;
}

###########################
# HARMONIC FUNCTIONS
###########################

# Detect harmonic pattern in a value
sub detect_harmonic_pattern {
    my $input = shift;
    
    # Convert to decimal and divide by 13
    my $result = $input / $HARMONIC_CONSTANTS->{'divisor'};
    
    # Extract decimal portion for pattern matching
    my $decimal = $result - int($result);
    my $pattern = substr(sprintf("%.6f", $decimal), 2, 6);
    
    # Check for true/false patterns
    if ($pattern eq $HARMONIC_CONSTANTS->{'true_pattern'}) {
        return "TRUE - Harmonic cube pattern detected (461538)";
    } elsif ($pattern eq $HARMONIC_CONSTANTS->{'false_pattern'}) {
        return "FALSE - Harmonic pyramid pattern detected (769230)";
    } else {
        return "NEUTRAL - No primary harmonic pattern";
    }
}

# Enhanced function to check for all harmonic patterns including truth/awareness
sub detect_all_harmonics {
    my $input = shift;
    my %results;
    
    # Check division by 13 patterns
    my $div13 = $input / $HARMONIC_CONSTANTS->{'divisor'};
    my $decimal13 = $div13 - int($div13);
    my $pattern13 = substr(sprintf("%.6f", $decimal13), 2, 6);
    $results{'div13'} = {
        'pattern' => $pattern13,
        'is_true' => ($pattern13 eq $HARMONIC_CONSTANTS->{'true_pattern'}),
        'is_false' => ($pattern13 eq $HARMONIC_CONSTANTS->{'false_pattern'})
    };
    
    # Check division by 7 patterns
    my $div7 = $input / $HARMONIC_CONSTANTS->{'auxiliary'}[1];
    my $decimal7 = $div7 - int($div7);
    my $pattern7 = substr(sprintf("%.6f", $decimal7), 2, 6);
    $results{'div7'} = {
        'pattern' => $pattern7,
        'is_truth' => ($pattern7 eq $HARMONIC_CONSTANTS->{'truth_pattern'}),
        'is_awareness' => ($pattern7 eq $HARMONIC_CONSTANTS->{'awareness_pattern'})
    };
    
    # Check division by 5 patterns (auxiliary)
    my $div5 = $input / $HARMONIC_CONSTANTS->{'auxiliary'}[0];
    my $decimal5 = $div5 - int($div5);
    my $pattern5 = substr(sprintf("%.6f", $decimal5), 2, 6);
    $results{'div5'} = {
        'pattern' => $pattern5
    };
    
    # Calculate composite harmonic score
    $results{'composite_score'} = calculate_harmonic_score(\%results);
    
    return \%results;
}

# Calculate a composite harmonic score based on all patterns
sub calculate_harmonic_score {
    my $results = shift;
    my $score = 50; # Start at neutral
    
    # Primary harmonic (div13)
    if ($results->{'div13'}{'is_true'}) {
        $score += 25;
    } elsif ($results->{'div13'}{'is_false'}) {
        $score -= 15;
    }
    
    # Secondary harmonic (div7)
    if ($results->{'div7'}{'is_truth'}) {
        $score += 15;
    } elsif ($results->{'div7'}{'is_awareness'}) {
        $score += 10;
    }
    
    # Ensure score is in 0-100 range
    $score = 0 if $score < 0;
    $score = 100 if $score > 100;
    
    return $score;
}

# Function to visualize a 5x7 matrix pattern
sub visualize_matrix_pattern {
    my $pattern = shift;
    my $width = 5;
    my $height = 7;
    
    say "\nVisualizing pattern '$pattern' in 5x7 matrix:";
    say "+---+---+---+---+---+";
    
    for my $row (0..($height-1)) {
        my $line = "|";
        for my $col (0..($width-1)) {
            my $idx = ($row * $width + $col) % length($pattern);
            my $char = substr($pattern, $idx, 1);
            $line .= " " . $char . " |";
        }
        say $line;
        say "+---+---+---+---+---+";
    }
}

# Function for self-healing data through harmonic principles
sub self_heal {
    my ($data, $iterations) = @_;
    $iterations ||= 13;
    
    my $original = $data;
    my $healed = $data;
    my @healing_trajectory;
    
    for my $i (1..$iterations) {
        # Apply harmonic healing transformation
        my $harmonics = detect_all_harmonics($healed);
        
        # If we've already reached a true or truth pattern, we're done
        if ($harmonics->{'div13'}{'is_true'} || $harmonics->{'div7'}{'is_truth'}) {
            last;
        }
        
        # Apply harmonic adjustment based on composite score
        if ($harmonics->{'composite_score'} < 50) {
            # Move toward harmonic pattern
            $healed += 1;
        } else {
            # Refine existing harmonic tendency
            $healed = int($healed * 1.01); # Small amplification
        }
        
        push @healing_trajectory, $healed;
    }
    
    return {
        'original' => $original,
        'healed' => $healed,
        'trajectory' => \@healing_trajectory,
        'harmonics' => detect_all_harmonics($healed)
    };
}

###########################
# EXTRACTOR FUNCTIONS
###########################

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
        my $harmonics = detect_all_harmonics(length($paragraph));
        my $score = $harmonics->{'composite_score'};
        
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
            'confidence' => min(100, $implemented_score * 10),
            'implemented_score' => $implemented_score,
            'conceptual_score' => $conceptual_score
        };
    } else {
        return {
            'status' => 'conceptual',
            'confidence' => min(100, $conceptual_score * 10),
            'implemented_score' => $implemented_score,
            'conceptual_score' => $conceptual_score
        };
    }
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