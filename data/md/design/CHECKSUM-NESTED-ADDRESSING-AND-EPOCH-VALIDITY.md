# checksum-nested addressing, epoch validity windows, and model self-test cycle

captured 2026-06-10 — raw design ideation from taeki, interrupted mid-dispatch
by the v7 boot crash (bmw-harmonize-l13). intended as input for the next
"opus task file generation" dispatch — these are NOT yet task files, just the
ideas that should become task files (likely 2-3 separate tasks).

## 1. collision-free nested checksum addressing `[CHECKSUM:NAME]`

`amos-chksum` already produces a checksum for an arbitrary name, and a
checksum-of-a-checksum-plus-name for nesting:

```
$ amos-chksum litter-7
JC762WY

$ amos-chksum JC762WY.litter-7
GGL6ANA
```

written as `[GGL6ANA:JC762WY]` — the outer checksum (of `<parent>.<name>`)
paired with the parent's own checksum.

properties:
- the network name itself becomes part of the entropy for collision
  exclusion of its children — no separate exclusion-list needed
- the checksum of the *whole element* (`[GGL6ANA:JC762WY]`) gives implicit
  parenting: knowing the algorithm + nesting convention, a node's ancestry
  chain can be reconstructed without a lookup table
- recursive: arbitrary depth nesting, with "infrastructure module" layers
  interleavable at any level — types, encoded epoch-string groups, trunking/
  multiplexing/contextualization layers — all auto-collapsing/-folding back
  to a single checksum pair when not expanded
- works for namespaces *without* arbitrary human-readable names too (pure
  checksum chains)

relates to: [[topic-checksum-addressing]], [[topic-addressing-trinity]],
[[topic-checksum-tree-wire]], `data/md/design/CHECKSUM-CLUSTER-MAP.md`

## 2. v7 epoch as temporal network root + rollover validity windows

the v7 epoch timestamp (e.g. `V7L36SA`) is the implicit pre-grouping /
always-available parent — a "temporal network root":

- `<epoch>:<key>` or `<epoch>:<key>:<name>` gives users/user-keys a
  **temporal, auto-closing collision exclusion**: once an epoch is over,
  nothing using that format can generate the same key/name again, and
  network-wide accidental collisions within one epoch's window are
  vanishingly unlikely
- ergonomic win over raw timestamps: a user can memoize their *own creation
  epoch* easily, whereas near-current entropy variations are easier to
  brute-force
- **epoch rollover as index-checksum salt** (already partially documented
  somewhere in `data/` — needs locating): treat the epoch timestamp as a
  salt for index checksumming; only a window of {previous, current, next}
  epoch is considered valid. all networked indices must roll over seamlessly
  or fall out of validity
- **checksum-based search protocol**, built on the above:
  1. `amos-chksum 'search.type : <pattern>'` → e.g. `KU5GOWY` sent into the
     network
  2. network replies with a longer BMW-L13 (or similar) checksum proving the
     search performed is the one tied to an even-longer BMW384 *content*
     checksum of the result
  3. that BMW384 checksum doubles as the **route to the data itself** —
     anonymized and perfectly cacheable
  4. any cache registered on that route can reply with the data early,
     potentially before the uplink responds — transparently, even from a
     `%data`/`%files`/in-zenka cache
- **epoch directories as a general storage pattern**: rolling resource-
  prefix directories (webserver paths, settings dirs) — defends against
  scanners, separates cache from archive, gives natural timeline/rollback
  grouping for forensics, empty epoch dirs auto-collapse between populated
  ones, and older epochs can be "squashed" into difference-based layers
  instead of keeping every intermediate change

relates to: [[topic-checksum-addressing]], `amos7-template-epoch-exclusion`
(just landed, commit 8cf4fda11 — `AMOS7::TEMPLATE` epoch window callback),
`data/tasks/epoch-bmw-l13-truth-templates.md`,
`data/tasks/epoch-chksum-path-helper.md`, [[topic-stream-framing-protocol]]

## 3. coding zenka model self-test cycle

a model self-test cycle that runs after each model load in the coding zenka:

- acquires initial timeout multipliers per model (feeds the existing
  `coding.cfg.timeout_stats` / statistical adaptive timeout idea from
  `topic-next-steps`)
- expandable into an intelligent model-cycling benchmark / deeper model
  assertion taskflow
- usable for **model fallback on hard tasks**: try model A, if it fails try
  model B, etc. until one succeeds
- secondary feature: instant rollback + network-timestamped, xz-based
  archival of each model's result per attempt
- final **consensus-group round** for quality ranking across attempts —
  may overlap with `llm.service.consensus_vote` and/or the task zenka
  itself; could share a common var-watcher-based state-machine iterator
  module for batch processing regardless of which zenka owns it

relates to: [[topic-coding-state-machine]], [[topic-task-coordination]],
[[topic-distributed-consensus]], `topic-next-steps` (statistical adaptive
timeout future task)

## next step

fold these three into separate task files via the next opus
"task file generation" dispatch (same flow as
`console-stdio-slot-addressing.md` / `console-foldable-render-baseline.md`).

#,,..,,.,,..,,,,,,,,.,,.,,.,,,...,,,.,,,.,.,.,..,,...,...,...,,,.,..,,...,,..,
#BPUQS5LUMXGJM3APSXKFJ7PCEGA2EKZKWI2FCC56T43ZVNSFF6C545DMTT7DH7GRRLUYANH74FZ6W
#\\\|2TF4E6RUAVHVTQQWNQFLRO63D4O54HJNMCVK6R5SV43744ETCVF \ / AMOS7 \ YOURUM ::
#\[7]X52WJLXPJO3Q5XJOVBQ4G2HCGB2L4UBDSETYFQNFZUK2ESAQKWDY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
