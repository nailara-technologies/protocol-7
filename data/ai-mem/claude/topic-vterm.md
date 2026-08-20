# vterm Module System

## Overview
22 modules in `src/vterm.*` namespace — generic visual consensus buffer
system for any zenka. Committed `b5dbe8db1` (2026-03-02).

## Cell Format
- Pack template: `'c4 N C3C3C C c C C N'` = **23 bytes** (not 16 as originally spec'd)
- `<vterm.cell.size_bytes> //= 23` in `vterm.init_code`
- Confidence stored as signed char (`c`), unpacked with `/ 127` to normalize to 0..1
- Fields: subbit_r/g/b/attr (4), codepoint (4), fg_r/g/b (3), bg_r/g/b (3),
  attrs (1), state (1), confidence (1), alternation (1), vote_count (1), last_update (4)

## Consensus Algorithm
- 11-member body: -5..0..+5; ±5 = declaration (SET/CLEAR); 0 = routing state
- 5-of-7 threshold: `declared_count >= <vterm.consensus.threshold>` → sharp pixel
- Below threshold: interference pattern via `vterm.consensus.interference_pattern`
- Blur/ghosts make Byzantine dissent visually perceivable

## Review Findings (bugs caught pre-commit)
Four critical bugs fixed before first commit:
1. `vterm.consensus.check_layer_agreement`: `sort {...} %fingerprints` (hash flattened)
   → fixed to `sort {...} values %fingerprints`
2. `vterm.subbit` vote action: `shift @ARG` after list-copy grabbed wrong element
   → fixed to `my ($cell_ref, $vote, $direction, $channel) = @ARG`
3. `vterm.init_code`: `size_bytes //= 16` (then 22) → actual pack size is **23**
4. `vterm.instance`: `<vterm.instances> {$key}` missing `->` → `<vterm.instances>->{$key}`

Known design issues (deferred to forensic mode implementation):
- DESIGN-1: `vterm.subbit.determine_route` counts total history entries not actual
  sign changes — "secret" reduces to vote-count parity
- DESIGN-2: `vterm.consensus.ghosts` returns cells without layer identity — forensic
  layouts will need `{layer_id, cell}` pairs

## Pending Stubs (⏳ in spec)
- `vterm.compositor.layout.grid` — forensic grid layout
- `vterm.compositor.layout.stack` — forensic stack layout
- `vterm.compositor.layout.diff` — forensic diff view
- data zenka SHM read/write (path exists, actual I/O commented out)

## Key Config (all idempotent //= in vterm.init_code)
- `<vterm.shm.fallback_local> //= TRUE` — always works without data zenka
- `<vterm.compositor.blend_mode> //= 'consensus_5of7'`
- `<vterm.compositor.temporal_window> //= 13`

## Docs
- Spec: `data/md/design/VTERM-BUFFER-SPECIFICATION.md`
- Review: `data/yaml/code-reviews/src/vterm-post-refactor-review.yaml`
- Pre-refactor review: `data/yaml/code-reviews/src/vterm-inline-subs-extraction.yaml`

#,,..,.,,,.,.,..,,.,,,..,,.,,,,.,,,,,,,,.,,,,,..,,...,...,,,.,..,,,,.,.,.,,..,
#II4CWLE2B7Q4DNU3EC4UL4DUYDAU65ZELLOADRWBRJDNZHL3SZZFW4GZGIBPZO3CVBTHZLJ6UUECA
#\\\|7CD4VR3ISTLHKEB7IYW2GVJZDKYBVDMGSH7MLIYXHO2CDGA27EO \ / AMOS7 \ YOURUM ::
#\[7]QWSS2M67D446PAYH7K24OX643WF6NB66ZCJJLKRXMLJ2YUEN7UDQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
