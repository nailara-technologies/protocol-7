## [:< ##

# context tree checksum addressing design
# descr = resumable incremental checksums for eternal content-addressed storage

---

## purpose

extend AMOS/ELF/BMW checksum infrastructure to support:

1. **resumable checksums** — start from previous state, continue with new data
2. **position-addressed content** — checksum at arbitrary stream position
3. **diff-based storage** — only store changes, referenced by checksum pairs
4. **context tree addressing** — every node, edge, and perspective has checksum

---

## current state

existing infrastructure:

```
bin/amos-chksum           → CLI tool
AMOS7::CHKSUM             → core module (ELF + BMW harmonization)
AMOS7::CHKSUM::ELF        → ELF checksum implementation
Digest::BMW               → BMW hash (supports incremental add())
```

current calculation flow:
```
data → ELF checksum → ELF bits
     → BMW checksum → BMW 512-bit
     → harmonization → AMOS checksum
     → truth assertion → (mod if needed)
```

---

## required extensions

### 1. resumable checksum state

current limitation: each call starts fresh

target: save intermediate state, resume later

```perl
## incremental checksum state ##
package AMOS7::CHKSUM::State;

sub new {
    my $class = shift;
    my $self = {
        ## ELF state ##
        elf_checksum   => 0,       ## current ELF sum
        elf_mode       => 7,       ## mode (4, 7, etc.)
        elf_shift_bits => 13,      ## shift amount

        ## BMW state ##
        bmw_ctx        => undef,   ## Digest::BMW context
        bmw_bits_R     => '',      ## cached right bits
        bmw_bits_L     => '',      ## cached left bits
        bmw_bits_C     => '',      ## cached center bits

        ## harmonization state ##
        harmonization_step => 0,   ## mod-step counter
        mod_bits_pool      => '',  ## remaining mod bits

        ## metadata ##
        bytes_processed => 0,      ## total bytes so far
        chunk_count     => 0,      ## number of add() calls
        last_position   => 0,      ## stream position
    };
    bless $self, $class;
}
```

### 2. position-aware addressing

```perl
## checksum at specific position ##
$state->add_at_position($data, $position);

## use case: context tree node at file offset ##
## node_address = AMOS7::CHKSUM::State->new()
##     ->add_at_position($node_data, $file_offset)
##     ->finalize();
```

### 3. diff-based storage format

```yaml
# context-tree-node.yaml
---
node_format: 1.0
node_checksum: UXA5BUI    ## this node's AMOS checksum

## content addressing ##
content:
  type: diff              ## diff | full | reference
  base_checksum: ABCD123  ## parent node (for diff)
  diff_checksum: EFGH456  ## diff from parent to this
  full_checksum: IJKL789  ## this node's full content

## stream position ##
position:
  stream_id: AMOS7:CTX:TREE:001
  offset: 1024
  length: 256

## tree structure ##
parents:
  - checksum: ABCD123
    edge_type: inherits_from
    weight: 1.0

children:
  - checksum: MNOP012
    edge_type: refines
    weight: 0.8

## perspective metadata ##
perspectives:
  kimi:
    relevance: 0.95
    access_count: 47
    last_access: 2026-03-25T14:30:00Z
  coding:
    relevance: 0.72
    access_count: 12
```

### 4. stream-based incremental checksum

```perl
## stream interface ##
my $stream = AMOS7::CHKSUM::Stream->new(
    stream_id   => 'context://kimi/session/2026-03-25',
    chunk_size  => 4096,
    on_checksum => sub {
        my ($position, $checksum, $state) = @_;
        ## index this position-checksum mapping
        $tree->index_position($position, $checksum);
    }
);

## as data arrives ##
$stream->add($chunk1);  ## position 0-4095
$stream->add($chunk2);  ## position 4096-8191
## automatically emits checksums at chunk boundaries

## get checksum at any position ##
my $chksum_at_5000 = $stream->checksum_at(5000);
```

---

## integration with context tree

### node addressing

```
node_address = AMOS7:CHKSUM:7CHAR:POSITION:LENGTH

example:
  UXA5BUI:1024:256 → node with checksum UXA5BUI at offset 1024, length 256
```

### edge addressing

```
edge_address = PARENT_CHKSUM:CHILD_CHKSUM:EDGE_TYPE

example:
  ABCD123:EFGH456:refines → edge from ABCD123 to EFGH456, type "refines"
```

### perspective-weighted relevance

```perl
## relevance calculation using checksum-addressed statistics ##
sub calculate_relevance {
    my ($node_checksum, $perspective_id) = @_;

    my $stats = $tree->get_stats($node_checksum, $perspective_id);
    ## returns:
    ##   ref_count: 47
    ##   recency: 0.9 (1.0 = now, 0.0 = ancient)
    ##   access_pattern: [...]

    ## weighted combination ##
    my $relevance = (
        $stats->{ref_count} * 0.4 +
        $stats->{recency}   * 0.4 +
        $stats->{proximity} * 0.2
    );

    return $relevance;
}
```

---

## implementation phases

### phase 1: AMOS7::CHKSUM::State (1-2 days)

- create resumable state object
- extend AMOS7::CHKSUM to accept/return state
- maintain backward compatibility

```perl
## new interface ##
my $state = AMOS7::CHKSUM::State->new();
$state->add($chunk1);
$state->add($chunk2);
my $checksum = $state->finalize();

## or resume ##
my $loaded_state = AMOS7::CHKSUM::State->load($saved_state);
$loaded_state->add($new_data);
my $new_checksum = $loaded_state->finalize();
```

### phase 2: AMOS7::CHKSUM::Stream (2-3 days)

- position-aware incremental checksums
- automatic indexing at chunk boundaries
- resumable from any position

### phase 3: context.tree.node module (3-4 days)

- checksum-addressed node storage
- diff-based persistence
- parent/child edge management

### phase 4: context.tree.perspective (2-3 days)

- perspective-tuned relevance
- inheritance from similar perspectives
- auto-compaction based on stats

---

## eternal storage format

### file layout

```
data/context-tree/
├── index/                    ## checksum → file position mapping
│   ├── level-0/              ## first byte of checksum
│   │   ├── 00/               ## checksums starting with 00
│   │   ├── 01/
│   │   └── ...
│   └── level-1/              ## second byte for large trees
│
├── nodes/                    ## actual node data
│   ├── 00/
│   │   └── 0011223...        ## node content (diff or full)
│   └── ...
│
├── edges/                    ## edge definitions
│   └── ...
│
└── streams/                  ## stream position checksums
    └── ...
```

### node storage optimization

```perl
## small nodes (< 1KB): store full content ##
## large nodes (> 1KB): store diff from similar node ##

sub store_node {
    my ($content, $parent_checksum) = @_;

    if (length $content < 1024) {
        ## store full ##
        return store_full($content);
    } else {
        ## find similar parent, store diff ##
        my $diff = calculate_diff($content, $parent_content);
        if (length $diff < length $content * 0.5) {
            ## store diff is smaller ##
            return store_diff($parent_checksum, $diff);
        } else {
            return store_full($content);
        }
    }
}
```

---

## harmonization continuity

key insight: BMW and ELF state can be resumed

```perl
## BMW is inherently incremental ##
$bmw_ctx->add($chunk1);
## save state ##
my $bmw_state = $bmw_ctx->clone();  ## or serialize
## resume ##
$bmw_state->add($chunk2);

## ELF can be resumed by passing previous sum as start ##
my $elf_sum1 = elf_chksum($chunk1, 0, $mode, $shift);
my $elf_sum2 = elf_chksum($chunk2, $elf_sum1, $mode, $shift);
## $elf_sum2 == elf_chksum($chunk1.$chunk2, 0, ...)
```

---

## usage in context zenka

```perl
## context composition with checksum addressing ##
my $context = <[context.compose.for_task]>->({
    template => qw| code-review |,
    target_file => $file_path,
});

## each section gets checksum-addressed ##
foreach my $section ($context->{sections}->@*) {
    my $node_checksum = <[context.tree.node.store]>->({
        content    => $section->{content},
        type       => $section->{provider},
        base_node  => $section->{parent_checksum},  ## for diff
    });

    $section->{checksum} = $node_checksum;

    ## index for proximity search ##
    <[context.tree.index.relevance]>->({
        checksum    => $node_checksum,
        perspective => qw| kimi |,
        relevance   => calculate_relevance($section),
    });
}

## retrieve by checksum ##
my $content = <[context.tree.node.fetch]>->({
    checksum => qw| UXA5BUI |,
    perspective => qw| kimi |,  ## for relevance-weighted decompression
});
```

---

## integration with existing protocol-7 infrastructure

### storage zenka ( cfg/zenki/storage/start )

storage zenka already runs `amos-chksum` unix socket protocol:
```
cfg/zenki/storage/start:
  storage.use_amos_chksum_socket = yes

modules/storage.unix.handler.amos-chksum:
  ## handles line-wise checksum requests via unix socket
  ## modes: elf truth assertion modes for validation
```

context tree extends this with **stateful** checksums for streams.

### index zenka ( cfg/zenki/index/start )

index zenka uses checksum-derived paths:
```
modules/index.gen_path:
  ## splits amos-chksum entropy into anti-entropic directory tree
  ## uses modes 5,7 for path generation
  ## truth filters with modes 7,9
```

context tree uses same algorithm for node placement.

### sourcecode checksum symlinks ( experimental )

```
modules/sourcecode.console.regen-checksum-symlinks:
  ## stores files by checksum in versioned directories
  ## replaces source files with checksum-based symlinks
  ## deduplication: same content = same checksum = single storage

modules/sourcecode.console.undo-checksum-symlinks:
  ## reverses symlink transformation
  ## restores original source files
```

context tree brings this deduplication to **runtime context storage**.

### existing checksum modules

| module | function |
|--------|----------|
| `base.chk-sum.amos` | core AMOS checksum calculation |
| `base.chk-sum.amos.init_code` | initialization |
| `base.chk-sum.amos.truth_template_chksum` | truth template validation |
| `base.chk-sum.elf` | ELF (natively resumable) |
| `base.path.create-amos-chksum` | path checksums |
| `models.checksum.calculate_amos` | model integration |

context.tree.checksum.* extends these with **resumable state** and **position addressing**.

### unified P7REF-AMOS addressing

```
TYPE:AMOS7:POSITION:LENGTH

examples:
  NODE:UXA5BUI:0:256      → context node
  EDGE:ABCD123:EFGH456    → edge between nodes
  FILE:/path:UXA5BUI      → file with checksum
  CHUNK:STREAM01:4096     → stream chunk
```

### storage alignment

**current: sourcecode version storage**
```
source-root/
  version-UXA5BUI/
    UXA5BUI  → file content (checksum as filename)
```

**new: context tree storage**
```
data/context-tree/
  nodes/UX/A5/UXA5BUI  → node content (or diff)
  edges/UXA5BUI:ABCD123:refines
  index/position/STREAM01/
```

same deduplication principle, applied to **context nodes**.

---

#,,.,,,.,,,..,,..,,.,,...,...,...,,,.,,,.,,,.,..,,...,...,..,,,,.,,..,,,,,,,,,

#,,,.,.,.,...,.,,,.,.,,..,.,,,.,.,,,.,.,,,,,,,..,,...,...,.,.,..,,,,.,,,,,,.,,
#OB2RC7FF6TMRNZ4QUBXEFUCQVR7L63NQU563J6XWZ5B5FQ4DHIS2O6A63FPCRFNVP3EBSM2TYR3GY
#\\\|HGWPNPPSXUNFJIH7SAJEPDKNC3SRD7OFK6LR32W3222AT6P5DHM \ / AMOS7 \ YOURUM ::
#\[7]EW47M7MZS54ZFLA4RKNJKBRZFT37SXPBYPBD6IVJPKAIW76YBADQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
