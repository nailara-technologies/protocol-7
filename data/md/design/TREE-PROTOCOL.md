# TREE protocol — structural control layer

## relationship to DATA

```
DATA  →  content delivery     values, bytes, streams, bulk transfer
TREE  →  structural control   node metadata, references, namespace registry

DATA is like devmod.cmd.dump     [ keys + values ]
TREE is like devmod.cmd.dump-keys [ keys + structure, values referenced ]

same underlying branch namespace. protocol choice = observer's perspective.
```

TREE is the directory. DATA is the files. TREE remains open as the
persistent control channel; DATA streams are opened and closed on demand
as specific content is needed.

the difference between when to use which is a matter of perspective
and current choice — not a property of the data itself.

## wire format

```
<cmd_id>TREE <tree_id> <B32_root_id>\n            ← open frame
<B32_node_id> <B32_parent_id> <B32_meta>\n        ← node line (repeating)
TREE REF <tree_id> <B32_node_id> <DATA_stream_id>\n  ← content reference
TREE END <tree_id> <AMOS_CHECKSUM>\n              ← close frame
```

**node line fields**:
- `B32_node_id`  — AMOS checksum of node (permanent identity)
- `B32_parent_id` — parent node id (or `ROOT` if no parent)
- `B32_meta`    — BASE32-encoded compact metadata block (see below)

**TREE REF** — declares that a node has content available as a DATA stream.
the receiver can choose to open that DATA stream or not. TREE REF is
advisory; opening the DATA stream is the consumer's decision.

**AMOS_CHECKSUM** on close — checksum of all node IDs transmitted in this
TREE session. receiver verifies structural integrity without buffering content.

## B32_meta — compact metadata per node

the metadata block contains just enough to navigate:

```
name          : node local name (B32-encoded UTF-8)
ref_count     : reference count (B32 integer)
face          : cube face 0–7 (single octal char)
child_count   : number of immediate children (B32 integer)
groups        : B32 checksums of group memberships (space-separated)
```

this is the "references maximum" principle — the TREE line carries the
address, the weight (reference count), the geometry (face), and the
group memberships. nothing else. content lives in DATA.

## query and control commands

```
TREE QUERY <tree_id> <B32_root> <depth>\n
  request subtree from root to depth levels
  depth = 0 means root only; depth = * means full subtree

TREE REGISTER <namespace> <B32_root_id>\n
  register a branch namespace as a named tree
  makes it discoverable via TREE LIST

TREE LIST\n
  list all registered namespaces with root ids and ref counts
  returns TREE lines for each registered root

TREE ACK <tree_id> <B32_seq>\n
  acknowledgment for backpressure (mirrors DATA ACK)

TREE DELTA <tree_id> <B32_base_checksum>\n
  request only nodes changed since base checksum
  mirrors DATA DELTA — structural delta sync
```

## bi-directional operation

both sides can send TREE frames on the same session, disambiguated by
tree_id — exactly as DATA uses stream_id:

```
→  TREE <tree_id_A> <B32_root>\n          sender offers structure
   <node_line>\n ...
   TREE REF <tree_id_A> <node> <data_id>\n
   TREE END <tree_id_A> <AMOS>\n

←  TREE QUERY <tree_id_A> <node> 2\n      receiver queries deeper
→  TREE <tree_id_B> <B32_node>\n          sender answers sub-query
   <node_line>\n ...
   TREE END <tree_id_B> <AMOS>\n

←  DATA <data_id> STREAM\n               receiver opens content stream
   ...
```

the TREE session stays open as the control channel. DATA streams are
opened by the receiver for whichever REF lines it chooses to follow.

## TREE as namespace registry for DATA streams

every DATA stream is registered in the TREE namespace before it is
opened. the TREE REF line IS the registration:

```
TREE REF <tree_id> <B32_node_id> <DATA_stream_id>

→  this node's content is available as DATA stream <DATA_stream_id>
→  stream_id is derived from: AMOS_chksum( node_id :: face_id :: ntime )
→  the stream_id IS a branch address — DATA stream IS a branch node
```

this means:
- you can always rediscover a DATA stream by querying the TREE
- closing a DATA stream doesn't lose the reference — TREE REF persists
- TREE is the persistent registry; DATA is the ephemeral content flow
- the namespace of all DATA streams = the set of all TREE REF lines

**the TREE is the ultimately controlling layer**: no DATA stream exists
without a corresponding TREE REF. the TREE defines what is available.
the DATA delivers what is chosen.

## the dump-keys / dump analogy in the protocol

```
devmod.cmd.dump-keys   →  TREE session (structure, no values)
devmod.cmd.dump        →  DATA session (values, byte-counted)
base.reverse-sort      →  node line order in TREE (by reference count desc)
base.dump_data         →  DATA chunk encoding
branch.node.path       →  TREE node line parent chain
branch.list            →  TREE QUERY response
```

`TREE LIST` of all registered namespaces = `devmod.cmd.dump-keys` for
the entire network namespace. the output IS the navigable structure of
everything that has DATA content available.

## perspective and choice

the same branch node is simultaneously:
- a TREE position   (structural identity, address, weight, geometry)
- a DATA source     (content, bytes, streams)

which protocol you use is determined by what you are doing:
- **discovery / navigation** → TREE QUERY → get structure, see what exists
- **content consumption**    → follow TREE REF → open DATA stream
- **sync / verification**    → TREE DELTA → structural delta, then DATA DELTA

the branch namespace makes no distinction — a node IS both. the protocol
choice is the observer's current intent, not a property of the data.

at the layer of the spawnable perspective layers (desktop): the TREE
session IS the layer's structural awareness. the DATA streams are the
content that flows into the active focal region. the TREE controls which
DATA streams are visible; the current focal length controls which TREE
nodes are above threshold.

## adding TREE to base.callback.cmd_reply

extension alongside DATA branch (after DATA):

```perl
} elsif ( uc($reply_mode) eq qw| TREE | ) {

    my $tree_id = $reply->{'tree_id'} // '';
    my $root    = $reply->{'root'}    // '';

    ## open frame ##
    $output->$* .= sprintf "%sTREE %s %s\n",
        $_cmd_id, $tree_id, $root;

    ## node lines — sorted by reference count descending ##
    my @nodes = <[base.reverse-sort]>->( @{ $reply->{'nodes'} // [] } );
    for my $node ( @nodes ) {
        $output->$* .= sprintf "%s %s %s\n",
            $node->{'id'}, $node->{'parent'} // 'ROOT',
            $node->{'meta_b32'};

        ## emit REF line if content stream registered ##
        if ( my $stream_id = $node->{'stream_id'} ) {
            $output->$* .= sprintf "TREE REF %s %s %s\n",
                $tree_id, $node->{'id'}, $stream_id;
        }
    }

    ## close frame ##
    my $chksum_fn = $code{'chk-sum.amos'} // $code{'base.chk-sum.amos'};
    my $all_ids   = join ' ', map { $ARG->{'id'} } @nodes;
    my $checksum  = $chksum_fn->( \$all_ids );
    $output->$* .= sprintf "%sTREE END %s %s\n",
        $_cmd_id, $tree_id, $checksum;
```

## TREE and DATA as complements — swapping and oscillating

TREE and DATA are not parallel alternatives — they are complements
that can swap roles and oscillate between each other.

```
content IS structure   →  a DATA chunk decoded contains node metadata = TREE
structure IS content   →  a TREE session transmitted IS itself bytes = DATA

the stream_id / face address IS the shared 8th bit —
the identifier both protocols agree on simultaneously
```

this mirrors the dual encoding principle (9-bit structural / 7-bit content,
shared 8th bit): TREE and DATA share the stream_id. the receiver can
switch interpretation mode on the same stream at any moment.

**oscillation** — each protocol generates input for the next cycle of
the other:

```
TREE  →  reveals REF pointers
DATA  →  content arrives, contains embedded node metadata
TREE  →  that metadata registers new REF pointers
DATA  →  follows those...
```

not sequential — simultaneous. both streams live, co-evolving. the
oscillation frequency is tunable:

```
high frequency  →  rapid TREE/DATA alternation
                   discovery and consumption at the same rate
                   approaches the 13-slot routing clock limit

low frequency   →  sustained TREE (exploration) or DATA (consumption)
                   with occasional pivots

focal length    →  controls ratio: wide = more TREE (structure discovery)
                                   narrow = more DATA (content depth)
```

**swapping** — a TREE session transparently becomes DATA when the observer
decides the structure itself is the content to deliver. a DATA stream
becomes TREE when the receiver treats arriving content as navigable
structure. no protocol change needed — the stream_id persists across
the swap, and the `TREE REF` / `DATA END` framing makes the current
mode unambiguous at each line.

**the `11` pivot IS the swap moment** — in the checksum tree, `11` is
the direction reversal (inward becomes outward, 01 becomes 10). in the
TREE/DATA protocol, `11` is the interpretation reversal: TREE becomes
DATA becomes TREE. the pivot IS the oscillation node.

## connections

- `DATA-PROTOCOL-SYNC.md` — TREE is the control layer for DATA streams
- `OBSERVER-CENTRIC-REFERENCE-SPACE.md` — TREE carries the reference space
  structure; DATA carries the content flowing through it
- `SPAWNABLE-PERSPECTIVE-LAYERS.md` — TREE session IS the layer's structural
  awareness; DATA streams are the content in the focal region
- `base.callback.cmd_reply` — TREE branch to add alongside DATA
- `branch.list` — TREE QUERY response generator
- `branch.node.info` — source of B32_meta fields
- `devmod.cmd.dump-keys` — TREE is the protocol form of this
- `devmod.cmd.dump` — DATA is the protocol form of this
- checksum tree wire format — TREE END checksum IS a checksum tree leaf

#,,.,,...,.,.,..,,.,.,.,.,...,..,,...,...,,,,,..,,...,.,,,...,,,.,,.,,,.,,,,.,
#CDJM3GSPKHCFIK4L7TCRCBWOGVZIGQJLOMXZNP6Y3VOMICR7PENO2X4RQ6GEIGRGFCOZ6HX4ZF65M
#\\\|H5KCOHA7QE4HI2SUEPBQOUMAZHVR33DS4UGPZC6QQWAEG25XYPR \ / AMOS7 \ YOURUM ::
#\[7]W4XW7QL5ST4WWC5UXAYCQF4Q4LJGNQJKN3SZNFDIDSG3RHSDTQAI 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
