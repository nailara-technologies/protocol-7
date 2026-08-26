## archive: DONE ✓ -- 2026-08-22
## commit: 7ed1ba794 -- spdx cleanup batches 3-4: last src/ files, plus retire phantom base32 duplicate
## notes: all 4 batches landed (365b1e26c, fa3e379c9, and batch 3-4 in 7ed1ba794); every
##        SPDX-License-Identifier marker confirmed gone from src/; also retired the
##        phantom base.decode.bmw/bmw-L13 duplicate of base32.decode found along the way;
##        closes todo item G5X

## [:< ##

# name  = task: remove false SPDX-License-Identifier strings from suspect-session files
# descr = review ~30 modules carrying a fabricated "SPDX-License-Identifier: ISC"
#         line, then strip the line once each file is cleaned/reviewed

## context

repository base branch is public domain (see README.md). a prior low-quality
authoring session inserted `# SPDX-License-Identifier: ISC` at the tail of
~30 module files — an AI model unilaterally asserting a license on
public-domain code, which is not acceptable regardless of intent.

the line is being kept IN PLACE for now, deliberately, as a marker of which
files came from that suspect session and need review. it is not a real
license declaration and must not be treated as one. see
data/ai-mem/claude/reference-spdx-marker-flags-suspect-session.md.

## scope (as of 2026-08-09)

```
grep -rl "SPDX-License-Identifier" src/
```

mostly `pager.*` (pager.buffer.virtual, pager.source.*, pager.filter.*,
pager.sort.*, pager.view.*, pager.init-code, pager.editor.*, pager.export.*,
pager.command.demo), plus:
  - base.editor.init_buffer / set_line_callback / set_total_lines
  - storage.9p.mount / storage.9p.umount
  - context.tree.index.position / context.tree.summary.compact.check
  - context.template.resolve
  - base.decode.bmw-L13

## task

for each file above:
  1. review the actual code for correctness/quality (this is the session
     that prompted the marker — assume nothing, verify behavior)
  2. fix or rewrite as needed
  3. once clean, remove the `# SPDX-License-Identifier: ISC` line entirely
     — do not replace it with any other license string, the repo doesn't
     use per-file license tags

do not remove the marker line from a file before it has actually been
reviewed — it is the only record of which files still need attention.

## batching plan (added 2026-08-21, after a prior no-batch dispatch attempt
## hit the weekly kimi budget instantly with zero landed result)

dispatch in small per-namespace-family batches, one at a time, k2.7 by
default — hold back anything actually live-called for extra scrutiny:

- **batch 1** (dispatched 2026-08-21, k2.7) — DONE, verified: `pager.buffer.virtual`,
  `pager.buffer.page`, `pager.buffer.page.invalidate`,
  `pager.buffer.page.invalidate-all`, `pager.init-code` — 5 files, none
  currently called from anywhere in `coding.*` (verified via grep), but
  all compiled at `coding` zenka startup (`pager` is in its
  `modules.load`) — a syntax error breaks that zenka's reload, so static
  syntax verification per file is required even though nothing invokes
  these yet. all 5 syntax-checked clean (`bin/dev/ptd -c`) and diff
  reviewed directly: SPDX line(s) removed cleanly (including the
  duplicated pair in `pager.init-code`), plus one real bug fixed in
  `pager.buffer.page.invalidate` — single-page invalidation left the
  page's entry in `$buf->{'pages'}{'dirty'}` behind (invalidate-all
  clears the whole dirty hash, single-page invalidate didn't), fixed
  with a matching `delete`. staged, not yet committed.
- **batch 2** (dispatched 2026-08-21, k2.7) — DONE, verified: 9 files
  (`pager.source.{checksum-list,9p,register,file-list}`,
  `pager.filter.{harmonic-random,preference,chain}`,
  `pager.sort.{chain,multi-key}`). 7 were clean SPDX-only removals
  (diffed each by hand, nothing else touched). 2 had real fixes: (a)
  `pager.source.file-list` — dead `@cmd`/`$depth` `find`-command
  scaffolding removed, `files_only`/`dirs_only` args (previously silently
  ignored) actually implemented in the live `next_batch` loop; contract
  preserved, re-verified live myself via `p7c coding.call-tool list_files`
  after `p7c coding.reload`. (b) `pager.source.9p` — 3 real API-mismatch
  fixes against `plugin.storage.p7ref.parse` (arg shape `{p7ref=>...}`,
  `{mode,data}` reply) and `storage.9p.scan` (`name`/`path` args not
  `mount_point`, `{mode,data}` reply not `{entries}`), plus `qid.type &
  QTDIR` for dir-type detection matching `storage.9p.scan`'s own internal
  convention — checked all three referenced modules' real contracts
  directly, fix matches exactly. still returns undef at runtime pending
  `storage.9p.mount`'s stub (batch 4), by design. all 9 syntax-checked
  clean (`bin/dev/ptd -c`, re-run independently). no scope creep this
  time (contrast with the earlier unrelated `base.log` incident on a
  different task) — kimi even flagged pre-existing unrelated
  `data/ai-mem/` diffs in its own report rather than touching them.
- **batch 3** (dispatched 2026-08-22, k2.7) — DONE, verified: 7 files
  (`pager.view.{amos-data-pager,amos-data-pager-56,true-int-color}`,
  `pager.editor.get_line`, `pager.export.binary`, `pager.command.demo`,
  `pager.decode.direction`). Real bugs found and fixed in 5 of 7: (a) all
  3 `pager.view.*` files were treating a base32-encoded L13 checksum
  string as HEX (`pack('H*', $hash)` / `hex(substr($hash,0,14))`) —
  fixed to decode via `base.decode.bmw-L13` (the same function reviewed
  in batch 4); (b) `pager.view.true-int-color`'s entropy branch had a
  genuine bit-math bug, `pack('Q>', $num) >> 8` numerically shifts a
  *packed binary string*, meaningless in Perl — fixed to `pack('Q>',
  $num << 8)`, shifting the number before packing; traced by hand
  against the paired decode-side unpack, the two are a consistent
  shift-left-before-pack / shift-right-after-unpack pair; (c)
  `pager.view.amos-data-pager` also had `'pid' => $!` (errno, not a
  PID) in its async-launch return, removed rather than faked; (d)
  `pager.export.binary` added bounds-checks around a visible-slice
  array-slice that could silently produce undef entries past the end;
  (e) `pager.command.demo` guards a missing `$render->{'lines'}` key
  and defaults 3 stats fields with `// 0`. `pager.editor.get_line` and
  `pager.decode.direction` reviewed clean, SPDX-only removal. All 7
  syntax-checked clean, re-run independently; diffs reviewed by hand,
  including retracing the bit-shift math myself before trusting it.
- **batch 4** (dispatched 2026-08-22, k2.7) — DONE, verified: 9 files
  (`base.editor.{init_buffer,set_line_callback,set_total_lines}`,
  `storage.9p.{mount,umount}`, `context.tree.{index.position,
  summary.compact.check}`, `context.template.resolve`,
  `base.decode.bmw-L13`). 8 were clean SPDX-only removals; all are
  honestly self-marked `[ stub ]` code except `context.template.resolve`
  (a real ~200-line recursive template resolver, genuinely live-called
  from `coding.prompt.assemble` — reviewed with extra care per the
  dispatch instructions, live-verified via `p7c coding.reload` +
  `coding.show-prompt`, zero bugs found, zero code changes beyond the
  marker removal).

  **follow-up finding, caught by the user, not by the dispatch**:
  `base.decode.bmw-L13` (and its undocumented sibling `base.decode.bmw`,
  which never carried the marker) turned out to be a phantom duplicate
  of the real `base.base32.decode` (swapped to `base32.decode` at
  runtime via `base.base32.pre_init`'s `swap_subs` call — used by 6 real
  call sites elsewhere: jobsite.job.read, transport/proxy.cmd.
  cred-rotated, task.cmd.complete, jobsite.store.prune,
  base.vax-int.decode). Traced both phantom modules to commit
  `13ce23a38` (2026-03-28, "Resolve all undefined routine warnings for
  clean coding zenka startup") — a mechanical pass that manufactured new
  stub modules matching whatever (wrong) names the pager.* suspect-
  session code already called, instead of redirecting those calls to
  the real `base32.decode`. Same commit is also where nearly every other
  file in this whole SPDX cleanup task originated as a stub. Fixed:
  redirected all 5 real callers (the 4 pager.view.*/export.binary files
  fixed in batches 3-4, using the correct swapped call form
  `<[base32.decode]>->(...)`, NOT `<[base.base32.decode]>->(...)` which
  would not resolve post-swap) and deleted `src/base.decode.bmw` +
  `src/base.decode.bmw-L13` outright. Verified: `bin/dev/ptd -c` clean
  on all 4 touched files, `p7c coding.reload` succeeds, grep confirms
  zero remaining references anywhere except the auto-generated
  `base.list.subroutines` index (regenerates on its own next run).
  Also: a `p7c coding.reload` run during this investigation triggered a
  broken partial regeneration of `data/md/documentation/
  module-dependency-graph.asc` (wrong-direction edit + stripped
  signature footer) — reverted, not committed; root cause not
  investigated further, flag if seen again.

see [[reference-spdx-marker-flags-suspect-session]] for the corrected
blast-radius assessment (the family is loaded live by `coding`, not dead
code as first assumed).

## status: DONE — all 4 batches landed, verified `grep -rl
## "SPDX-License-Identifier" src/` returns nothing

corresponds to todo item `G5X` ("review routines with SPDX marker and
remove on pass") — mark that done via `todo` once all 4 batches land.

#,,,.,...,,,.,..,,..,,,.,,...,,.,,.,.,,..,..,,..,,...,...,...,..,,..,,,,,,..,,
#Y4WKT2K5A64YCFKN3KWMMMUAZYH5FDKDRL4MH6XCXLR3RX5K6O36TN5LSGKAQLKHNIVESTHSAK7UW
#\\\|5XLIJB2EDEFFHHSXOKOG7GJBOV3BXLRFN7UIM2QZKIM4AAT6QXA \ / AMOS7 \ YOURUM ::
#\[7]WXC77KEKGA4WLESSJOAEXSQTRNBU4TI6NALENYDJ2LB32TX764DQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
