# session design tree — overview + dispatch planner

[ origin: 2026-06-10 — parent/overview structure for the 5 design
  docs and 17 task files produced in this session's design sequence.
  written reflexively under the philosophy doc's own principle:
  *a branch node is already a complete tree* — so the session's own
  output gets the same fold/render treatment any other sub-tree gets. ]

## the three lineages [ at a glance ]

```
session design tree
├── UI / fold lineage
│   CONSOLE-FOLD-TREE-PHILOSOPHY.md
│   └── STDIO-RELAY-FOLD-APPLICATION.md
│
├── checksum / epoch lineage
│   EPOCH-CHECKSUM-EXCLUSION-ADDRESSING.md
│   └── BMW-CHECKSUM-TEMPLATE-EXPANSION.md
│
└── stdio-multiplex lineage
    STDIO-MULTIPLEX-PROTOCOL.md
    [ rooted under STDIO-RELAY-FOLD-APPLICATION.md as its wire layer ]
```

each lineage is independently dispatchable in early stages but
converges at the relay surface — the multiplex demux task is the
explicit convergence point; the persistent-storage seam is the
implicit one [ noted but not yet acted on ].

## navigable tree [ docs + tasks ]

### UI / fold lineage

```
CONSOLE-FOLD-TREE-PHILOSOPHY.md           [ first principles ]
├── console-fold-primitive.md             [ generic verbs ]
├── console-foldable-render-baseline.md   [ generic policy ]
├── console-stdio-slot-addressing.md      [ generic addresses ]
└── STDIO-RELAY-FOLD-APPLICATION.md       [ first surfaces ]
    ├── v7-stdout-foldable-relay.md       [ generalise v7 relay ]
    ├── v7-console-log-filter-overlay.md  [ usage example A ]
    ├── v7-console-per-zenka-tree-view.md [ usage example B ]
    ├── configure-zenka-fallback-ui.md    [ first generic consumer ]
    └── installer-zenka-template-flow.md  [ second generic consumer ]
```

### checksum / epoch lineage

```
EPOCH-CHECKSUM-EXCLUSION-ADDRESSING.md    [ outer doc — epoch/chksum
│                                           addressing + cross-epoch
│                                           exclusion as load-balancer ]
├── amos7-template-epoch-exclusion.md     [ AMOS7::TEMPLATE substrate ]
├── epoch-chksum-path-helper.md           [ base.path.epoch-chksum ]
│
└── BMW-CHECKSUM-TEMPLATE-EXPANSION.md    [ inner doc — BMW family-
    │                                       wide template + AMOS7
    │                                       consolidation ]
    ├── bmw-harmonize-l13-helper.md       [ L13 chokepoint, prereq ]
    ├── epoch-bmw-l13-truth-templates.md  [ templated L13 wrapper ]
    ├── amos7-chksum-consolidation.md     [ lift BMW+JHA into AMOS7 ]
    └── bmw-truth-template-family.md      [ family tranche + JHA ]
```

### stdio-multiplex lineage

```
STDIO-MULTIPLEX-PROTOCOL.md               [ wire grammar — 3-bit
│                                           type-tag layered on the
│                                           existing 3+1 framing ]
├── stdio-multiplex-type-tag-codec.md         [ encoder/decoder ]
├── stdio-multiplex-unix-socket-transport.md  [ socket carrier ]
└── v7-console-stdio-multiplex-demux.md       [ v7-side demux ]
```

## cross-lineage connections [ explicit seams ]

### UI/fold ↔ stdio-multiplex

three concrete seams, all already cross-referenced in both directions:

- **slot addresses** [ `console-stdio-slot-addressing.md` ] are the
  semantic content of the multiplex protocol's `slot_addr` META field
- **fold/unfold verbs** [ `console-fold-primitive.md` ] operate on the
  META scope tree the demux reconstructs — no separate state
- **v7-console-stdio-multiplex-demux.md** explicitly depends on both
  the slot-addressing task and the fold primitive task; this is the
  hard convergence point of the two lineages

### UI/fold ↔ checksum/epoch

one explicit seam [ added in this round ]: the persistent on-disk
counterpart of `v7.stdout_log` rotation [ named as future work in
`STDIO-RELAY-FOLD-APPLICATION.md` ] adopts the `epoch/chksum` native
tree from `EPOCH-CHECKSUM-EXCLUSION-ADDRESSING.md` *if/when* it lands.
the in-memory ring stays flat; this is a future-direction note, not
a current dependency.

### checksum/epoch ↔ stdio-multiplex

one explicit seam [ added in this round ]: the multiplex protocol's
META `slot_addr` and `hop_id` fields are length-prefixed precisely so
they can later carry the fixed-width epoch/chksum path segments
`epoch-chksum-path-helper.md` produces, without recoding the wire.
again a future-direction note — multiplex demux does not block on
the epoch path helper.

## recommended dispatch ordering

### tranche 1 — unblocked, can land in parallel

independent primitives. none depend on anything outside this set.

- `console-fold-primitive.md`                — UI/fold lineage root verb
- `console-foldable-render-baseline.md`      — UI/fold render policy
- `console-stdio-slot-addressing.md`         — UI/fold address scheme
- `bmw-harmonize-l13-helper.md`              — checksum lineage chokepoint
- `amos7-template-epoch-exclusion.md`        — checksum lineage substrate
- `stdio-multiplex-type-tag-codec.md`        — multiplex codec [ depends
                                                only on the existing
                                                framing protocol, not on
                                                anything in this session ]

### tranche 2 — unblocks after tranche 1

each task here depends on one or two tranche-1 deliverables.

- `v7-stdout-foldable-relay.md`              — needs all 3 UI/fold prims
- `epoch-bmw-l13-truth-templates.md`         — needs bmw-harmonize helper
- `epoch-chksum-path-helper.md`              — needs amos7-template-epoch
- `stdio-multiplex-unix-socket-transport.md` — needs type-tag codec

### tranche 3 — depends on tranche 2

- `v7-console-log-filter-overlay.md`         — needs v7-stdout-foldable
- `v7-console-per-zenka-tree-view.md`        — needs v7-stdout-foldable
- `configure-zenka-fallback-ui.md`           — needs UI/fold prims; can
                                                land in parallel with the
                                                two v7-console tasks
- `amos7-chksum-consolidation.md`            — needs bmw-harmonize +
                                                epoch-bmw-l13 to have
                                                settled contracts
- `v7-console-stdio-multiplex-demux.md`      — needs unix-socket
                                                transport + slot
                                                addressing + fold prims
                                                [ the convergence point ]

### tranche 4 — depends on tranche 3

- `installer-zenka-template-flow.md`         — depends on
                                                configure-zenka-fallback
- `bmw-truth-template-family.md`             — depends on AMOS7
                                                consolidation having
                                                landed

## what was missing before this round [ gap-scan result ]

three gaps were found in the round-1-through-4 output:

1. **back-link from `STDIO-RELAY-FOLD-APPLICATION.md` to
   `EPOCH-CHECKSUM-EXCLUSION-ADDRESSING.md`** for the persistent-log
   storage seam. epoch doc named it; relay doc did not back-reference.
   FIXED: relay doc's non-goals section now names epoch/chksum as the
   intended target shape for future rotated-to-disk slices.

2. **no cross-reference between stdio-multiplex and checksum/epoch
   lineages** despite META `slot_addr` and `hop_id` being natural
   carriers of the epoch/chksum addressing. FIXED: STDIO-MULTIPLEX-
   PROTOCOL.md now names the alignment in its cross-link section.

3. **no parent/overview structure** for the 5 docs + 17 tasks as one
   navigable tree with dispatch ordering. FIXED: this doc.

no other gaps were found. specifically:
- every task file already carries an explicit `## relation` or
  `## relation to <DOC>` header
- every design doc references its parent and lists the tasks it roots
- the strict-ordering chains within each lineage are stated in the
  lineage's outer doc
- the only ambiguous boundary [ configure vs installer ] is
  explicitly named as such in `STDIO-RELAY-FOLD-APPLICATION.md` and
  the task files

## final assertion [ honest checkpoint ]

the tree is **coherent and ready to start dispatching from tranche 1.**
no further design or task-file authoring is required as a precondition
for implementation.

three caveats:

- the **epoch/chksum ↔ multiplex META** alignment is a *future-
  direction note*, not a present dependency. when whoever takes
  `v7-console-stdio-multiplex-demux.md` decides whether to encode
  `slot_addr` and `hop_id` as epoch/chksum paths or as raw P7REFs,
  that choice can be made at implementation time without further
  design-doc work — the wire is length-prefixed precisely so this is
  a local decision.
- the **persistent on-disk log rotation** seam is named but
  *deliberately deferred*. no task in this session ships it. the
  next session-level decision worth making is whether to root that
  work [ a new task `v7-stdout-log-epoch-rotation.md`, say ] now or
  wait until a concrete consumer demands it. recommend wait — no
  current zenka needs persisted stdout slices addressable across
  weeks, and writing the task speculatively risks designing for an
  empty acceptance criterion.
- the **configure / installer** boundary may collapse during
  implementation. the design docs already say this; no pre-emptive
  task merge is warranted.

implementation dispatch should begin from tranche 1; gaps found
during implementation will surface their own specific design
questions, which are better answered with code in hand than with
more docs in advance.

#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::

#,,,.,..,,,..,,.,,,..,,,,,..,,,.,,,,.,...,...,..,,...,...,..,,,.,,,.,,,,.,,,.,
#GKOK3EPQXUWYX2SZZ6NTXOMZUR32NVE6DUMZ6C7KDUYHTWOVQRTCVETLZ3YIATFRWOPZ53X6JP5K2
#\\\|4NGW7N4G6EPYYB5NDEFO3J5UJXEYUJAYYZL6INHBUXREPLGWIPY \ / AMOS7 \ YOURUM ::
#\[7]5P5WBBGOIOUCTRJVEEPMP3C7GSUHKCVFT75RF5ZFBRJPZ4DP7YDI 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
