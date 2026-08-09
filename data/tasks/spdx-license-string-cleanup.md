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
grep -rl "SPDX-License-Identifier" modules/
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

## status: not started

#,,,.,,,.,,,.,...,.,.,..,,..,,,,,,.,.,...,...,..,,...,...,,..,,.,,,,.,,..,,,.,
#AZ4ALZRTRD7CPTGOCEMOD2BW6HUR4GKUAILTFKX4QPOGTQ5UF6KQDQH4DQ3PSP4PCXCBUXEBTKLDC
#\\\|DOFEZ6ZP6GHVXTF6SM63UXD3UX56XKTE52RYHJ5JOD576C2GZ5T \ / AMOS7 \ YOURUM ::
#\[7]5HXUPUG566NI23GXZOHRZPUW46EQNZ7R36BKON6MJGDYHYJY26BQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
