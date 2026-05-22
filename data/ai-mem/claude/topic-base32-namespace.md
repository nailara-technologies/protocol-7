---
name: topic-base32-namespace
description: "base32.* namespace — 5-bit space, encode/decode wrappers, dep-graph swap parser fix, self-healing whitelist concept"
metadata: 
  node_type: memory
  type: project
  originSessionId: 666d4dc1-21c4-4bf4-b502-caa56dad8014
---

## base32.* namespace (session 45)

`base.base32.encode` / `base.base32.decode` / `base.base32.pre_init` — live, signed, committed.

- wraps `Crypt::Misc::encode_b32r` / `decode_b32r` (reverse byte order variant)
- handles both scalar ref and plain string input
- `<{C1}>` caller level in warn messages
- pre_init uses `base.swap_subs` to alias `base.base32.*` → `base32.*`
- `base.encode.b32` retired — old single-arg no-ref-handling wrapper replaced

namespace is NOT just a codec — base32 is a 5-bit arithmetic space:
- AMOS checksum is base32-native (7 chars × 5 bits = 35 bits)
- `bin/amos-matrix` renders as 5×7 dot grids
- `0`/`1` outside alphabet → sentinel/separator uses
- will grow: `base32.matrix`, `base32.bits`, `base32.chunk`, checksum ops
- worth loading in all zenki — becomes a network-layer primitive like SIZE replies

**Why:** [[topic-data-protocol]] needed `encode_b32r` calls; models kept inventing
non-existent bare function names. Clean namespace fixes this permanently.

## dep-graph swap parser fix (session 45)

`extract_swap_pairs` in `bin/dev/dep-graph` now handles three forms:
1. `swap_subs( 'base.X', 'X' )` — single-quote
2. `swap_subs(qw| base.X X |)` — single qw block, two tokens
3. `swap_subs( qw| base.X |, qw| Y | )` — two separate qw blocks (new)

pre_init files should use form 2 — cleanest, already handled before fix.
form 3 was the bug: `base.base32.pre_init` used it, swap map never populated,
`base32.encode` not resolved, pre_init never triggered.

## self-healing whitelist concept (session 45)

blocked on signing infrastructure — automated whitelist writes need valid
signatures before the policy can trust them. sequence:
1. loading policy + control method checks fully implemented first
2. then: dep-graph stdout mode for on-demand zenka scans
   - scoped to zenka's own namespace only (no noise from other zenki)
   - validates AMOS7 signatures on every included module
   - flags: clean / signature missing / signature mismatch / moved_to mismatch
   - streams to stdout — no file write, no signing requirement
3. zenka's configured policy decides: accept / warn / refuse / fallback to full load
4. `<base.modules.moved_to>` registry consulted on NOT FOUND before failing
   — gives "module X moved to Y, whitelist stale" rather than just dying

**Why:** self-healing runs after init, no latency constraints — can afford full
scan that cold start cannot. same pattern as async inference spawning.
forensics zenka receives audit trail; operator sees patterns, not noise.

#,,,.,..,,..,,.,.,,,,,...,...,..,,.,.,,.,,.,.,..,,...,...,.,,,,..,.,,,,..,.,.,
#CDBCSMCGHIDT5R2N4A2ZAV437POZVPFHWQN6OCLQERERZFH25NL6OTF4ZI5E57MTJ2NN5P5QFJOJK
#\\\|CEZZDBAW3LZ4HYODFS22X7UZPMUQFL5FK5ITQEKF6JMTCTXMCNC \ / AMOS7 \ YOURUM ::
#\[7]BRR2GVSEV6ZBLTDC3AJ3EI2W7WVCIJCSYJQU6OJQI6CT25OFLODI 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
