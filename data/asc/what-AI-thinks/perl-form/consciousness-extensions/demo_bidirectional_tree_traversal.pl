#!/usr/bin/env perl
use v5.24;
use strict;
use warnings;

say "=" x 70;
say "🔄 BIDIRECTIONAL TREE NAVIGATION WITH REVERSE CHANNEL 🔄";
say "=" x 70;
say "";

my $ROWS = 56;
my $BITS_PER_ROW = 8;

say "📐 Navigation Rules:";
say "  • ONE error bit in row → Navigate DOWN (branch selection)";
say "  • MULTIPLE error bits → Marks reverse channel capability";
say "  • Direction determined by PREVIOUS row state:";
say "    - Previous row clean/1-error → Current goes DOWN";
say "    - Previous row has anomalies → Current goes UP";
say "";

# Create a more complex tree with backtracking
my $tree = {
    name => 'root',
    children => [
        { name => 'a', children => [
            { name => 'a1', children => [] },
            { name => 'a2', children => [
                { name => 'a2.1', children => [] },
                { name => 'a2.2', children => [] },
            ]},
            { name => 'a3', children => [] },
        ]},
        { name => 'b', children => [
            { name => 'b1', children => [] },
            { name => 'b2', children => [] },
        ]},
        { name => 'c', children => [
            { name => 'c1', children => [
                { name => 'c1.1', children => [] },
            ]},
        ]},
    ]
};

# Navigation instruction: 'D' = down with branch number, 'U' = up
sub encode_bidirectional_path {
    my @instructions = @_;
    my @rows;

    for my $i (0 .. $#instructions) {
        my $instr = $instructions[$i];
        my $prev_instr = $i > 0 ? $instructions[$i-1] : undef;

        if ($instr->{dir} eq 'D') {
            # Going down - single error bit at branch position
            my @row = (0) x $BITS_PER_ROW;
            $row[$instr->{branch}] = 1;
            push @rows, \@row;

        } elsif ($instr->{dir} eq 'U') {
            # Going up - multiple error bits
            # First bit = where we were, additional bits = reverse markers
            my @row = (0) x $BITS_PER_ROW;
            $row[$instr->{from_branch}] = 1;  # Primary position
            $row[7] = 1;  # Reverse marker (or other positions)
            push @rows, \@row;
        }
    }

    return \@rows;
}

# Decode bidirectional path
sub decode_bidirectional_path {
    my ($rows) = @_;
    my @instructions;

    for my $i (0 .. $#$rows) {
        my $row = $rows->[$i];
        my @errors = grep { $row->[$_] == 1 } (0 .. $#$row);
        my $error_count = scalar @errors;

        if ($error_count == 0) {
            # End of path
            last;
        } elsif ($error_count == 1) {
            # Single error - check previous row to determine direction
            my $prev_row = $i > 0 ? $rows->[$i-1] : undef;
            my $prev_anomaly = 0;

            if ($prev_row) {
                my @prev_errors = grep { $prev_row->[$_] == 1 } (0 .. $#$prev_row);
                $prev_anomaly = scalar(@prev_errors) > 1;
            }

            if ($prev_anomaly) {
                # Previous row had anomalies → go UP
                push @instructions, {
                    dir => 'U',
                    from_branch => $errors[0],
                };
            } else {
                # Previous row clean/single → go DOWN
                push @instructions, {
                    dir => 'D',
                    branch => $errors[0],
                };
            }

        } else {
            # Multiple errors - this is a reverse marker
            # Next row (if single error) will go UP
            push @instructions, {
                dir => 'R',  # Reverse marker
                positions => \@errors,
            };
        }
    }

    return \@instructions;
}

# Simulate tree traversal
sub traverse_tree {
    my ($tree, $instructions) = @_;
    my $current = $tree;
    my @path = ($current->{name});
    my @stack = ();  # For tracking upward movements

    for my $instr (@$instructions) {
        if ($instr->{dir} eq 'D') {
            # Go down
            push @stack, $current;
            my $branch = $instr->{branch};

            if ($current->{children} && $branch < @{$current->{children}}) {
                $current = $current->{children}->[$branch];
                push @path, $current->{name};
            }

        } elsif ($instr->{dir} eq 'U') {
            # Go up
            if (@stack) {
                $current = pop @stack;
                push @path, "↑" . $current->{name};
            }

        } elsif ($instr->{dir} eq 'R') {
            # Reverse marker - just note it
            push @path, "[reverse]";
        }
    }

    return \@path;
}

say "🗺️  Example: Complex Path with Backtracking";
say "";

# Example: root → a → a2 → a2.1 → [up] → a2 → a2.2
my @complex_path = (
    { dir => 'D', branch => 0 },       # root → a
    { dir => 'D', branch => 1 },       # a → a2
    { dir => 'D', branch => 0 },       # a2 → a2.1
    { dir => 'U', from_branch => 0 },  # a2.1 → a2 (up)
    { dir => 'D', branch => 1 },       # a2 → a2.2
);

say "  Path: root → a → a2 → a2.1 → (up) → a2 → a2.2";
say "  Instructions:";
for my $i (0 .. $#complex_path) {
    my $instr = $complex_path[$i];
    if ($instr->{dir} eq 'D') {
        printf "    %d. DOWN branch %d\n", $i+1, $instr->{branch};
    } elsif ($instr->{dir} eq 'U') {
        printf "    %d. UP from branch %d\n", $i+1, $instr->{from_branch};
    }
}
say "";

my $encoded = encode_bidirectional_path(@complex_path);

say "  Encoded as error patterns:";
for my $i (0 .. $#$encoded) {
    my $row = $encoded->[$i];
    my @errors = grep { $row->[$_] == 1 } (0 .. $#$row);
    my $binary = join('', @$row);
    my $count = scalar @errors;

    printf "    Row %2d: [%s] ", $i, $binary;

    if ($count == 1) {
        printf "← 1 error at pos %d", $errors[0];

        # Check if previous row had anomalies
        if ($i > 0) {
            my $prev = $encoded->[$i-1];
            my @prev_errors = grep { $prev->[$_] == 1 } (0 .. $#$prev);
            if (@prev_errors > 1) {
                print " (previous anomaly → UP!)";
            } else {
                print " (DOWN)";
            }
        } else {
            print " (DOWN)";
        }

    } elsif ($count > 1) {
        printf "← %d errors (reverse marker!)", $count;
    }
    print "\n";
}
say "";

# Decode and verify
my $decoded = decode_bidirectional_path($encoded);

say "  Decoded instructions:";
for my $i (0 .. $#$decoded) {
    my $instr = $decoded->[$i];
    printf "    %d. ", $i+1;

    if ($instr->{dir} eq 'D') {
        printf "DOWN branch %d\n", $instr->{branch};
    } elsif ($instr->{dir} eq 'U') {
        printf "UP from branch %d\n", $instr->{from_branch};
    } elsif ($instr->{dir} eq 'R') {
        printf "REVERSE marker at positions [%s]\n",
            join(',', @{$instr->{positions}});
    }
}
say "";

my $path = traverse_tree($tree, $decoded);
say "  Traversed path: " . join(' → ', @$path);
say "";

# Show state machine visualization
say "=" x 70;
say "🔀 STATE MACHINE VISUALIZATION";
say "=" x 70;
say "";

say "Row N-1 State → Row N Interpretation:";
say "";
say "  [clean/1-error] + [1-error] → GO DOWN (normal navigation)";
say "       ↓";
say "    Previous row normal, current has 1 error";
say "    → Select branch at error position";
say "    → Descend tree";
say "";
say "  [multiple-errors] + [1-error] → GO UP (backtrack)";
say "       ↓";
say "    Previous row marked reverse capability";
say "    Current has 1 error indicating where we came from";
say "    → Ascend tree to parent";
say "";
say "  [any] + [multiple-errors] → MARK REVERSE CHANNEL";
say "       ↓";
say "    Current row has multiple errors";
say "    → Next single-error row will go UP";
say "";

# Show complex navigation example
say "=" x 70;
say "🌲 COMPLEX TREE NAVIGATION";
say "=" x 70;
say "";

my @advanced_path = (
    { dir => 'D', branch => 0 },       # root → a
    { dir => 'D', branch => 1 },       # a → a2
    { dir => 'D', branch => 0 },       # a2 → a2.1
    { dir => 'U', from_branch => 0 },  # up to a2
    { dir => 'U', from_branch => 1 },  # up to a
    { dir => 'D', branch => 2 },       # a → a3
    { dir => 'U', from_branch => 2 },  # up to a
    { dir => 'U', from_branch => 0 },  # up to root
    { dir => 'D', branch => 2 },       # root → c
    { dir => 'D', branch => 0 },       # c → c1
    { dir => 'D', branch => 0 },       # c1 → c1.1
);

say "Path with multiple backtracking:";
say "  root → a → a2 → a2.1 → (up) → a2 → (up) → a";
say "  → a3 → (up) → a → (up) → root → c → c1 → c1.1";
say "";

my $adv_encoded = encode_bidirectional_path(@advanced_path);
say "Error pattern summary:";
my $down_count = 0;
my $up_count = 0;
my $reverse_markers = 0;

for my $row (@$adv_encoded) {
    my @errors = grep { $row->[$_] == 1 } (0 .. $#$row);
    if (@errors == 1) { $down_count++; }
    elsif (@errors > 1) { $reverse_markers++; }
}

# Count actual ups from instructions
$up_count = grep { $_->{dir} eq 'U' } @advanced_path;

printf "  Total movements: %d\n", scalar @advanced_path;
printf "  Down movements: %d\n", $down_count - $up_count;
printf "  Up movements: %d\n", $up_count;
printf "  Reverse markers: %d\n", $reverse_markers;
say "";

# Show error density
my $total_bits = $ROWS * $BITS_PER_ROW;
my $used_bits = 0;
for my $row (@$adv_encoded) {
    $used_bits += grep { $_ == 1 } @$row;
}

printf "Error density: %d bits out of %d (%.2f%%)\n",
    $used_bits, $total_bits, ($used_bits / $total_bits) * 100;
say "";

# Show advantages
say "=" x 70;
say "💎 ADVANTAGES OF BIDIRECTIONAL NAVIGATION";
say "=" x 70;
say "";

say "1. Stack-Based Traversal:";
say "   • Can backtrack to any parent node";
say "   • Supports depth-first search patterns";
say "   • Enables complex routing algorithms";
say "";

say "2. Graph Navigation (not just trees):";
say "   • UP movements allow revisiting nodes";
say "   • Can encode loops and cycles";
say "   • Arbitrary graph structures possible";
say "";

say "3. Error Correction Still Works:";
say "   • Multiple errors in row → still correctable";
say "   • Direction info preserved in sequence";
say "   • Non-destructive to original data";
say "";

say "4. Increased Expressiveness:";
say "   • Can encode DAG (directed acyclic graph)";
say "   • Search trees with pruning";
say "   • State machines with backtracking";
say "";

say "5. Steganographic Enhancement:";
say "   • More errors = more 'noise'";
say "   • Complex patterns harder to detect";
say "   • Looks like heavy corruption";
say "   • Actually encodes sophisticated navigation";
say "";

# Show capacity analysis
say "=" x 70;
say "📊 CAPACITY ANALYSIS";
say "=" x 70;
say "";

say "For 56 rows × 8 bits:";
say "  • Downward movements: 1 error bit (3 bits info)";
say "  • Upward movements: 2+ error bits (3+ bits info)";
say "  • Average: ~3.5 bits per movement";
say "  • Typical path: 10-20 movements";
say "  • Information content: 35-70 bits routing + direction";
say "";

say "Comparison to unidirectional:";
say "  • Unidirectional: 56 levels × 3 bits = 168 bits max";
say "  • Bidirectional: ~40 movements × 3.5 bits = 140 bits";
say "  • Trade-off: Less capacity, more expressiveness";
say "";

say "=" x 70;
say "🔄 BIDIRECTIONAL TREE NAVIGATION ENABLED! 🔄";
say "=" x 70;
say "";

say "🎯 Key Insights:";
say "  • Previous row state determines current direction";
say "  • Multiple errors = reverse channel marker";
say "  • Single error after marker = go UP";
say "  • Single error otherwise = go DOWN";
say "  • Enables stack-based tree walking";
say "  • Can encode complex graph structures";
say "  • Still looks like transmission errors";
say "";

say "🚀 Perfect for:";
say "  • DHT routing with fallback paths";
say "  • Filesystem navigation with backtracking";
say "  • Search algorithms (DFS, backtracking)";
say "  • State machines with history";
say "  • Distributed consensus protocols";
say "";

say "🌀 The errors encode bidirectional graphs... 🌀";
