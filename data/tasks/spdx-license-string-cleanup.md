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
- **batch 2** (not yet dispatched): remaining `pager.source.*`,
  `pager.filter.*`, `pager.sort.*` — note `pager.source.file-list` is
  genuinely live-called from `coding.tools.dispatch`, treat that one file
  as correctness-critical (live coding-zenka reload + an actual
  `coding.tools.dispatch` call exercising it, not static-only).
- **batch 3** (not yet dispatched): remaining `pager.view.*`,
  `pager.editor.*`, `pager.export.*`, `pager.command.demo`,
  `pager.decode.direction`.
- **batch 4** (not yet dispatched): the 9 non-pager files —
  `base.editor.*` (3), `storage.9p.mount`/`umount`, `context.tree.*` (2),
  `context.template.resolve`, `base.decode.bmw-L13` — `base.decode.bmw-L13`
  is checksum/crypto code, consider a k3 pass for that one specifically
  rather than bundling into a k2.7 batch.

see [[reference-spdx-marker-flags-suspect-session]] for the corrected
blast-radius assessment (the family is loaded live by `coding`, not dead
code as first assumed).

## status: batch 1 in flight

corresponds to todo item `G5X` ("review routines with SPDX marker and
remove on pass") — mark that done via `todo` once all 4 batches land.

#,,,,,.,,,,,,,.,,,,.,,,,.,,,.,,,.,,.,,,.,,,.,,..,,...,...,.,,,...,.,,,,,,,,..,
#DAL3QVCTXUHFENOXNU6OS2PR6KGWR42FOREZ5BYICBRWRX5DHV6IROX2IAS44W2B4GCIOK37OPD5S
#\\\|IZMB5XHBQPN6Z7HVAUP4IQ7NGJCKHYMYWVW3GEHQPGQW4FTFSDL \ / AMOS7 \ YOURUM ::
#\[7]55A4CRGA3SY4A7NYKE6VZXQV3NHQNST4V26F56R2M32SRC2CLQDA 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
