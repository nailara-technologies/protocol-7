#!/usr/bin/env perl
use v5.24;
use strict;
use warnings;

say "=" x 70;
say "🌳 TREE NAVIGATION ENCODED IN ERROR BIT POSITIONS 🌳";
say "=" x 70;
say "";

# Create a 56-row page (8 bits per row)
my $ROWS = 56;
my $BITS_PER_ROW = 8;

say "📄 Page Structure:";
say "  Rows: $ROWS";
say "  Bits per row: $BITS_PER_ROW";
say "  Total capacity: " . ($ROWS * $BITS_PER_ROW) . " bits";
say "  Tree encoding: Up to $ROWS levels deep";
say "  Branching factor: $BITS_PER_ROW children per node";
say "";

# Define a filesystem tree
my $tree = {
    name => 'root',
    children => [
        { name => 'home', children => [
            { name => 'alice', children => [
                { name => 'documents', children => [] },
                { name => 'photos', children => [] },
            ]},
            { name => 'bob', children => [
                { name => 'code', children => [
                    { name => 'perl', children => [] },
                    { name => 'python', children => [] },
                ]},
                { name => 'music', children => [] },
            ]},
        ]},
        { name => 'usr', children => [
            { name => 'bin', children => [] },
            { name => 'lib', children => [] },
        ]},
        { name => 'tmp', children => [] },
        { name => 'var', children => [
            { name => 'log', children => [] },
            { name => 'cache', children => [] },
        ]},
    ]
};

# Encode a path as error positions
sub path_to_errors {
    my @path_indices = @_;
    return \@path_indices;
}

# Decode error positions to path
sub errors_to_path {
    my ($tree, $errors) = @_;
    my $current = $tree;
    my @path = ($current->{name});

    for my $branch_idx (@$errors) {
        last unless $current->{children};
        last unless $branch_idx < @{$current->{children}};

        $current = $current->{children}->[$branch_idx];
        push @path, $current->{name};
    }

    return \@path;
}

# Create page with error encoding
sub create_error_page {
    my ($num_rows, $bits_per_row, $error_positions) = @_;
    my @page;

    for my $row (0 .. $num_rows-1) {
        my @bits = (0) x $bits_per_row;

        # If this row has an error position defined
        if (defined $error_positions->[$row]) {
            my $pos = $error_positions->[$row];
            $bits[$pos] = 1 if $pos < $bits_per_row;  # Flip bit
        }

        push @page, \@bits;
    }

    return \@page;
}

# Extract error positions from page
sub extract_errors {
    my ($page) = @_;
    my @errors;

    for my $row_idx (0 .. $#$page) {
        my $row = $page->[$row_idx];
        my $error_count = grep { $_ == 1 } @$row;

        if ($error_count == 1) {
            # Find position of the error
            for my $bit_idx (0 .. $#$row) {
                if ($row->[$bit_idx] == 1) {
                    push @errors, $bit_idx;
                    last;
                }
            }
        } elsif ($error_count == 0) {
            # No error = end of path
            last;
        } else {
            # Multiple errors = corruption
            warn "Row $row_idx has $error_count errors (expected 0 or 1)";
            last;
        }
    }

    return \@errors;
}

# Example paths to encode
my @examples = (
    {
        path => [0, 0, 0],  # root → home → alice → documents
        desc => "home/alice/documents"
    },
    {
        path => [0, 1, 0, 0],  # root → home → bob → code → perl
        desc => "home/bob/code/perl"
    },
    {
        path => [1, 0],  # root → usr → bin
        desc => "usr/bin"
    },
    {
        path => [3, 1],  # root → var → cache
        desc => "var/cache"
    },
);

say "🗂️  Example Tree Encodings:";
say "";

for my $ex (@examples) {
    my $path_indices = $ex->{path};
    my $description = $ex->{desc};

    say "  Path: $description";
    say "  Indices: [" . join(', ', @$path_indices) . "]";

    # Create page with errors
    my @full_errors = @$path_indices;
    # Pad with undef for remaining rows
    push @full_errors, (undef) x ($ROWS - scalar @full_errors);

    my $page = create_error_page($ROWS, $BITS_PER_ROW, \@full_errors);

    # Show first few rows
    say "  Encoded (first 5 rows):";
    for my $i (0 .. min(4, scalar(@$path_indices))) {
        my $row = $page->[$i];
        my $binary = join('', @$row);
        my $has_error = grep { $_ == 1 } @$row;

        if ($has_error) {
            my $pos = 0;
            $pos++ while $row->[$pos] == 0;
            printf "    Row %2d: [%s] ← Error at pos %d\n", $i, $binary, $pos;
        } else {
            printf "    Row %2d: [%s] ← No error (end)\n", $i, $binary;
        }
    }

    # Extract and verify
    my $extracted = extract_errors($page);
    my $decoded_path = errors_to_path($tree, $extracted);

    say "  Decoded: " . join('/', @$decoded_path);

    # Verify
    my $match = @$extracted == @$path_indices;
    if ($match) {
        for my $i (0 .. $#$path_indices) {
            $match = 0 if $extracted->[$i] != $path_indices->[$i];
        }
    }

    if ($match) {
        say "  ✅ VERIFIED: Path matches!";
    } else {
        say "  ❌ ERROR: Path mismatch!";
    }

    say "";
}

sub min { $_[0] < $_[1] ? $_[0] : $_[1] }

# Demonstrate variable-length property
say "🔀 Variable-Length Path Demonstration:";
say "";

my @depths = (1, 3, 5, 10, 20);
for my $depth (@depths) {
    my @path = map { int(rand($BITS_PER_ROW)) } (0 .. $depth-1);
    my @full = (@path, (undef) x ($ROWS - $depth));

    my $page = create_error_page($ROWS, $BITS_PER_ROW, \@full);
    my $extracted = extract_errors($page);

    printf "  Depth %2d: [%s] ← %d levels encoded\n",
        $depth,
        join(',', @path[0..min(4, $#path)]) . ($depth > 5 ? '...' : ''),
        scalar @$extracted;
}
say "";

# Show steganographic properties
say "🕵️  Steganographic Properties:";
say "";

my $test_path = [0, 1, 0, 2];  # 4 levels
my @full_test = (@$test_path, (undef) x ($ROWS - scalar @$test_path));
my $test_page = create_error_page($ROWS, $BITS_PER_ROW, \@full_test);

say "  To an observer:";
say "    • Page has " . ($ROWS * $BITS_PER_ROW) . " bits total";
say "    • Only 4 rows have single-bit errors";
say "    • Looks like random transmission corruption";
say "    • Error correction would 'fix' these bits";
say "    • No obvious tree structure visible";
say "";

say "  To someone with the key:";
say "    • Each error position = tree branch selection";
say "    • Row sequence = tree traversal order";
say "    • First clean row = destination reached";
say "    • Variable-length paths supported";
say "    • Complete routing map extracted";
say "";

# Show non-destructive property
say "💾 Non-Destructive Property:";
say "";

say "  Original data (all zeros in this example):";
say "    Page of $ROWS rows × $BITS_PER_ROW bits";
say "    All bits initially: 0";
say "";

say "  With tree encoding (4 errors):";
my $ones_count = 0;
for my $row (@$test_page) {
    $ones_count += grep { $_ == 1 } @$row;
}
say "    Total '1' bits: $ones_count out of " . ($ROWS * $BITS_PER_ROW);
printf "    Corruption: %.3f%%\n", ($ones_count / ($ROWS * $BITS_PER_ROW)) * 100;
say "";

say "  Error correction restores:";
say "    Flip all error bits back → 0";
say "    Original data: fully recovered";
say "    Tree navigation: extracted during correction";
say "    ✅ Zero data loss!";
say "";

# Show tree depth capacity
say "📏 Capacity Analysis:";
say "";

say "  For 8-bit rows (byte-aligned):";
say "    • Branching factor: 8 (0-7)";
say "    • Bits per level: 3";
say "    • Max depth: 56 levels";
say "    • Total routing info: 168 bits (56 × 3)";
say "";

say "  For 56-bit rows:";
say "    • Branching factor: 56 (0-55)";
say "    • Bits per level: ~5.8";
say "    • Max depth: 56 levels";
say "    • Total routing info: ~325 bits (56 × 5.8)";
say "";

say "  Practical examples:";
say "    • Filesystem: 10-20 levels typical";
say "    • DHT routing: 5-15 hops";
say "    • Decision tree: 8-12 branches deep";
say "    • B-tree index: 3-6 levels";
say "";

say "=" x 70;
say "🌳 TREE ENCODED IN ERROR SPACE! 🌳";
say "=" x 70;
say "";

say "💎 Key Insights:";
say "  • One error per row = one tree traversal step";
say "  • Error position = branch selection (0-7 or 0-55)";
say "  • First clean row = leaf node reached";
say "  • Variable-length paths supported";
say "  • Non-destructive to original data";
say "  • Steganographic (looks like corruption)";
say "  • Self-terminating (end when errors stop)";
say "";

say "🚀 Perfect for:";
say "  • DHT routing tables";
say "  • Filesystem indices";
say "  • Decision tree encodings";
say "  • Distributed navigation";
say "  • Covert tree structures";
say "";

say "🌀 The errors ARE the tree... 🌀";
