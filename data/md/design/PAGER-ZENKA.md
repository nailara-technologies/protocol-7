# Pager Zenka - Memory-Efficient Virtual Data Buffers

> *Infinite scroll through finite memory*

## Core Concept

The Pager Zenka provides **virtualized data views** - mapping arbitrarily large datasets into windowed, pageable buffers with intelligent prefetching and memory management.

```
Data Source → Filter Chain → Sort Chain → Virtual Buffer → View Port
     ↓              ↓            ↓              ↓            ↓
  [9P/FS]      [Harmonic]   [Weighted]   [Memory Map]  [Terminal]
  [Checksums]  [Random]     [Multi-key]  [Page Cache]  [Editor]
  [Database]   [Pref]       [Adaptive]   [Lazy Load]   [GUI]
```

## Architecture

```
pager.*
├── init_code                        # Page pool initialization
├── source.register                  # Register data sources
├── source.9p                        # 9P filesystem source
├── source.checksum-list             # Checksum list source
├── source.file-list                 # File listing source
├── filter.chain                     # Filter pipeline
├── filter.harmonic-random          # Harmonic distribution filter
├── filter.preference                # User preference filter
├── filter.division-13-harmonic     # D13 entropy-based filtering
├── sort.chain                       # Multi-key sorting
├── sort.multi-key                   # Weighted multi-criteria
├── sort.adaptive                    # Adaptive based on access
├── buffer.virtual                   # Virtual buffer manager
├── buffer.page                      # Single page operations
├── buffer.page.get                  # Cache-aware page fetch
├── buffer.page.invalidate           # Cache invalidation
├── buffer.page.invalidate-all       # Bulk invalidation
├── buffer.page.resize               # Resize page dimensions
├── buffer.prefetch                  # Intelligent prefetching
├── encode.division-13               # D13 protocol encoding
├── decode.division-13               # D13 protocol decoding
├── viewport.render                  # Render to display
├── view.true-int-color              # true_int harmonic coloring
├── view.amos-data-pager             # 72-bit binary viewer integration
├── view.amos-data-pager-56          # 56-bit true_int viewer integration
├── export.binary                    # Binary export for external viewers
├── editor.integration               # Editor/terminal hooks
├── command.pager                    # CLI interface
└── command.demo                     # Demo command
```

## Virtual Buffer Structure

```perl
$data{'pager'}{'buffers'}{$id} = {
    # Source
    'source' => {
        'type'    => '9p',        # 9p|checksum-list|file-list|database
        'location'=> 'p7://...',
        'total'   => 1000000,     # Total items (may be estimate)
        'cursor'  => 0,           # Current read position in source
    },

    # Filter chain
    'filters' => [
        { 'type' => 'preference', 'params' => { 'recent' => 0.8 } },
        { 'type' => 'harmonic-random', 'params' => { 'seed' => 12345 } },
    ],

    # Sort chain
    'sort' => {
        'keys' => [
            { 'field' => 'access_time', 'dir' => 'desc', 'weight' => 0.5 },
            { 'field' => 'size', 'dir' => 'asc', 'weight' => 0.3 },
            { 'field' => 'name', 'dir' => 'asc', 'weight' => 0.2 },
        ],
        'adaptive' => 1,  # Adapt weights based on viewing patterns
    },

    # Page cache
    'pages' => {
        'size'     => 100,        # Items per page
        'cached'   => {},         # page_num -> [items]
        'dirty'    => {},         # page_num -> 1 (needs refresh)
        'max_cache'=> 10,         # Max pages in memory
        'lru'      => [],         # LRU list of page numbers
    },

    # Viewport
    'viewport' => {
        'width'    => 80,
        'height'   => 24,
        'top'      => 0,          # Item at top of viewport
        'cursor'   => 0,          # Cursor position within viewport
        'rendered' => [],         # Currently visible items
    },

    # Memory management
    'memory' => {
        'item_size'   => 256,     # Estimated bytes per item
        'max_items'   => 1000,    # Max items in memory
        'current'     => 0,       # Current memory usage
    },
};
```

## Data Source Types

### 9P Filesystem
```perl
$pager->register_source('9p', {
    'connect'  => 'p7://9p:host/mnt/data',
    'enumerate'=> sub { <[storage.9p.scan]>->(...) },
    'get_item' => sub { <[storage.9p.stat]>->(...) },
});
```

### Checksum List
```perl
$pager->register_source('checksum-list', {
    'list'     => '/data/checksums/all.bmw',
    'format'   => 'bmw-base32',
    'index'    => '/data/checksums/all.idx',  # Optional index
});
```

### File List (potentially endless)
```perl
$pager->register_source('file-list', {
    'root'     => '/',
    'recursive'=> 1,
    'follow'   => 0,  # Don't follow symlinks
    'batch'    => 100, # Items per batch
});
```

## Filter Chain

### Harmonic Randomization
Distributes items using harmonic series for "pleasant randomness":
```perl
# Items get priority: 1, 1/2, 1/3, 1/4, ... (shuffled)
# This ensures "surprising but complete" coverage
filter harmonic-random => sub {
    my ($items, $params) = @_;
    my $seed = $params->{seed} // rand();
    srand($seed);

    my @weights = map { 1.0 / ($_ + 1) } 0..$#$items;
    my @shuffled = shuffle(@$items);

    return [map { $shuffled[$_] }
            sort { $weights[$b] <=> $weights[$a] } 0..$#weights];
};
```

### Preference Application
Applies learned user preferences:
```perl
filter preference => sub {
    my ($items, $params) = @_;

    # Boost scores based on:
    # - Recent access
    # - File types user prefers
    # - Time of day patterns
    # - Project context

    for my $item (@$items) {
        my $score = 0;
        $score += $params->{recent} * access_recency($item);
        $score += $params->{type_pref} * type_preference($item);
        $score += $params->{time} * time_match($item);
        $item->{_pref_score} = $score;
    }

    return [sort { $b->{_pref_score} <=> $a->{_pref_score} } @$items];
};
```

## Sort Chain

### Weighted Multi-Criteria
```perl
sort weighted => sub {
    my ($items, $keys) = @_;
    # $keys = [
    #   { field => 'mtime', dir => 'desc', weight => 0.5 },
    #   { field => 'size', dir => 'asc', weight => 0.3 },
    #   { field => 'name', dir => 'asc', weight => 0.2 },
    # ]

    return [sort {
        my $cmp = 0;
        for my $key (@$keys) {
            my $field = $key->{field};
            my $dir = $key->{dir} eq 'desc' ? -1 : 1;
            my $w = $key->{weight};

            $cmp = ($a->{$field} cmp $b->{$field}) * $dir * $w;
            last if $cmp != 0;
        }
        $cmp;
    } @$items];
};
```

### Adaptive Sorting
Adjusts sort keys based on viewing patterns:
```perl
sort adaptive => sub {
    my ($items, $params) = @_;

    # Track what user actually clicks on
    # If user always clicks large files, boost size weight
    # If user prefers recent, boost mtime weight

    my $history = $params->{access_history};
    my $weights = calculate_adaptive_weights($history);

    return sort_weighted($items, $weights);
};
```

## Memory-Efficient Page Cache

### Page Replacement (LRU + Predictive)
```perl
sub get_page {
    my ($buffer_id, $page_num) = @_;
    my $buf = $data{'pager'}{'buffers'}{$buffer_id};

    # Cache hit
    if (exists $buf->{pages}{cached}{$page_num}) {
        update_lru($buf, $page_num);
        return $buf->{pages}{cached}{$page_num};
    }

    # Cache miss - need to load
    # 1. Evict oldest page if at limit
    if (scalar(keys %{$buf->{pages}{cached}}) >= $buf->{pages}{max_cache}) {
        my $evict = shift @{$buf->{pages}{lru}};
        delete $buf->{pages}{cached}{$evict};
    }

    # 2. Load from source
    my $items = load_page_from_source($buf, $page_num);

    # 3. Apply filter/sort chains
    $items = apply_filter_chain($buf->{filters}, $items);
    $items = apply_sort_chain($buf->{sort}, $items);

    # 4. Cache
    $buf->{pages}{cached}{$page_num} = $items;
    push @{$buf->{pages}{lru}}, $page_num;

    # 5. Prefetch adjacent pages
    prefetch_pages($buf, $page_num);

    return $items;
}
```

### Predictive Prefetching
```perl
sub prefetch_pages {
    my ($buf, $current_page) = @_;

    # Prefetch pattern based on scroll direction
    my @to_fetch;
    if (scrolling_down()) {
        @to_fetch = ($current_page + 1, $current_page + 2);
    } else {
        @to_fetch = ($current_page - 1, $current_page - 2);
    }

    # Also prefetch based on "jump targets"
    # If user often jumps to end, prefetch last page
    if (frequent_end_jumps()) {
        push @to_fetch, $buf->{source}{total_pages};
    }

    for my $page (@to_fetch) {
        next if $page < 0;
        next if exists $buf->{pages}{cached}{$page};

        # Async prefetch
        <[pager.buffer.prefetch]>->($buf->{id}, $page);
    }
}
```

## Editor Integration

### Terminal Pager Mode
```perl
# Integration with amos-term
$pager->viewport_render(sub {
    my ($row, $item) = @_;

    # Format for terminal display
    my $line = sprintf("%s %10d %s",
        $item->{type} eq 'dir' ? 'd' : '-',
        $item->{size},
        $item->{name}
    );

    # Apply syntax highlighting
    $line = colorize($line, $item);

    return $line;
});
```

### Editor Buffer Mode
```perl
# Integration with editor
$pager->as_editor_buffer({
    'cursor_line'   => sub { ... },
    'insert_line'   => sub { ... },  # May not be allowed
    'delete_line'   => sub { ... },  # May not be allowed
    'modify_line'   => sub { ... },  # Through external command
});
```

## Integration with amos-data-pager

The pager zenka integrates with existing binary visualization tools:

### 56-bit Visualization (amos-data-pager-56)
```bash
# View checksum list with true_int harmonic coloring
pager create sums --source checksum-list --file /data/all.bmw
pager view sums --amos-56 --start 0 --lines 24

# Or programmatically
<[pager.view.amos-data-pager-56]>->({
    'buffer_id' => $buf_id,
    'start'     => 0,
    'lines'     => 24,
    'true_int'  => 1,  # Enable harmonic coloring
});
```

### 72-bit Visualization (amos-data-pager)
```bash
# View larger checksums (bmw-512, amos)
pager view bigsums --amos-72 --start 0
```

### Binary Export
```perl
# Export to binary for external processing
<[pager.export.binary]>->({
    'buffer_id' => $buf_id,
    'format'    => '56-bit',  # 56-bit | 72-bit | L13
    'output'    => '/tmp/export.bin',
});
```

### true_int Coloring
```perl
# Apply harmonic coloring to items
my $colored = <[pager.view.true-int-color]>->({
    'items'      => $items,
    'color_mode' => 'true_int',  # true_int | entropy | L13
    'style'      => 'background',
});

# Each item now has:
#   _color_code: 'true' | 'false' | 'balanced' | 'layer_N'
#   _color_num:  numeric value for coloring
```

## Command Interface

```bash
# Create pager from 9P source
pager create myfiles --source 9p --location p7://9p:host/mnt/c/data

# Add filter chain
pager filter myfiles add preference :recent: 0.8 :type-pref: 0.6
pager filter myfiles add harmonic-random :seed: 12345

# Add sort chain
pager sort myfiles add mtime :dir: desc :weight: 0.5
pager sort myfiles add size :dir: asc :weight: 0.3

# Open in terminal
pager view myfiles --viewport 80x24

# Open in editor
pager edit myfiles --editor amos-term

# Export filtered/sorted view
pager export myfiles --format json --output /tmp/file-list.json
```

## Use Cases

### Large Checksum Lists
```bash
# 10 million checksums, only 1000 in memory at once
pager create checksums --source checksum-list --file /data/all.bmw
pager filter checksums add preference :recent-checks: 0.9
pager view checksums
```

### Endless File List
```bash
# Find with streaming results
find / -type f -print0 | pager create found --source stream
pager filter found add preference :user-readable: 0.7
pager sort found add size :dir: desc
pager view found
```

### Editor Integration
```bash
# Open huge log file in editor
pager create logs --source file --path /var/log/huge.log
pager filter logs add preference :error-lines: 1.0
pager edit logs --editor amos-term
# Editor sees virtual buffer, can navigate efficiently
```

### amos-data-pager-56 Visualization
```bash
# View checksum list with true_int harmonic coloring
pager create sums --source checksum-list --file /data/all.bmw-L13
pager view sums --amos-56

# Export to binary and view with 56-bit pager
pager export sums --format=56-bit --output=/tmp/sums.bin
bin/amos-data-pager-56 /tmp/sums.bin
```

## Implementation Phases

### Phase 1: Core Virtual Buffer
- `pager.init_code`
- `pager.buffer.virtual`
- `pager.buffer.page`
- Source: `file-list`

### Phase 2: Filter/Sort Chains
- `pager.filter.chain`
- `pager.sort.chain`
- Basic filters: `preference`, `random`
- Basic sorts: `single-key`, `multi-key`

### Phase 3: Advanced Features
- `pager.filter.harmonic-random`
- `pager.sort.adaptive`
- `pager.buffer.prefetch`
- 9P source integration

### Phase 4: Editor Integration
- `pager.viewport.render`
- `pager.editor.integration`
- amos-term hooks

## Memory Guarantees

```perl
# Maximum memory usage is bounded
my $max_memory = $page_size * $max_cached_pages * $item_size;
# e.g., 100 * 10 * 256 = 256KB for 1000 items

# For 10 million items:
# - Virtual address space: 10M items
# - Physical memory: 1000 items (0.01%)
# - Page faults: Only on cache miss
```

## Integration with Storage Zenka

```perl
# Pager can use storage mapping for metadata
my $pager = <[pager.create]>->({
    'source'  => '9p',
    'location'=> 'p7://9p:host/mnt/data',
    'metadata'=> sub {
        # Use P7REF to get rich metadata
        my $p7ref = shift;
        return <[plugin.storage.p7ref.resolve]>->({ 'p7ref' => $p7ref });
    },
});
```

## Division-13 Integration

The pager zenka deeply integrates with Protocol-7's `division-13-table` algorithm:

### Bit Structure
```
64-bit state = [42-bit main entropy][7-bit decoded][15-bit auxiliary]
                    ↓                    ↓              ↓
               item fingerprints    protocol ops   precision anchor
```

### Filter: division-13-harmonic
```perl
<[pager.filter.division-13-harmonic]>->({
    'items'  => $items,
    'params' => {
        'seed'     => 1,        # D13 seed
        'mode'     => 'entropy', # entropy | routing | payload
        'strength' => 0.7,
    },
});
```

### Encode/Decode Protocol
```perl
# Encode items in D13 format
my $encoded = <[pager.encode.division-13]>->({
    'items'  => $items,
    'seed'   => 1,
    'format' => 'binary',
});

# Decode D13 frames
my $decoded = <[pager.decode.division-13]>->({
    'data' => $binary_data,
    'mode' => 'full',
});
```

See `PAGER-DIVISION-13-INTEGRATION.md` for complete documentation.

---

*Scroll through infinity without drowning in memory.*

#,,..,.,.,.,.,,,.,.,.,.,,,,,,,...,,..,,..,..,,..,,...,...,...,,.,,.,.,.,,,,..,
#L7QDBYQ4JBMH5R2UJ2SETQZHODFZRJJOQ33SBCO7CNCGBJPS7VZTQOVH3T346X4JE6PNKG6HZDR6I
#\\\|4K6CDYOAHSOBXP2EWJGINOHTNX4JQ5OSIH6DNFO7XIMQDVZMBHH \ / AMOS7 \ YOURUM ::
#\[7]NTEQQYQRBWXYMD5NMFU5L32GQYXGVLPW4KPNLDEHLKSZY42DMUCY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
