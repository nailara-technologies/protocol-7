---
name: feedback-path-typo-false-tool-glitch-attribution
description: repeated "File does not exist" errors on Edit/Read/Write this session were MY OWN typo (/data/protocol-7/... missing "projects") misattributed to transient tool glitches, discovered only when Write's mkdir error surfaced the real path
metadata:
  type: feedback
---

2026-09-14, during the nshell split-screen work: hit "File does not exist"
from Edit (and occasionally Read) many times across the session against
files that definitely existed, confirmed via `ls`/`cat` in Bash moments
later. Each time, retried the identical call and it usually succeeded,
so it was written off as a transient tool hiccup and never investigated
further.

The real cause surfaced only when a `Write` call to
`/data/protocol-7/src/nshell.handler.term_resize` (this repo's actual
root is `/data/projects/protocol-7`, missing "projects") returned a hard,
unambiguous `EACCES: permission denied, mkdir '/data/protocol-7'` —
because Write, unlike Edit, tries to create missing parent directories
and surfaced the real path in its error text. Edit and Read against the
same wrong path apparently sometimes silently retry/normalize and
sometimes don't, which is what produced the "transient, fixed by retry"
illusion.

**How to apply:** when Edit or Read reports "File does not exist" for a
path you're confident is correct, do not assume a tool glitch and just
retry — first re-examine the exact `file_path` string for a missing path
segment (this project's root is `/data/projects/protocol-7`, not
`/data/protocol-7` — the two differ by exactly one directory component
and are easy to conflate when typing many similar absolute paths in a
row). Retrying without checking wastes calls and can mask a real typo
for an entire session.

**RECURRED 2026-09-16**, same session as
[[feedback-tool-probe-empty-args-destructive-default]] and
[[project-note-trash-ntime-tools-landed-2026-09-16]]: hit the identical
`/data/protocol-7/...` (missing "projects") typo on `Write` calls ~4
separate times while creating new `note.trash.*`/`coding.tools.handler.*`
files, each one caught immediately by the same `EACCES: permission
denied, mkdir '/data/protocol-7'` error this memory already documents —
so the memory correctly explained each occurrence on sight, but didn't
prevent the typo itself. Two recurrences now despite the memory existing;
if it keeps happening, the fix is mechanical (e.g. always copy the
previous successful call's path prefix rather than retyping it) rather
than another memory note.

#,,.,,,.,,,,.,.,.,,..,...,,,.,.,,,...,,..,.,.,..,,...,...,..,,,,,,.,,,,,.,,,.,
#7E5TCFFWZUQRMICQAXWALKD3TFQZYD36WL4MNUX2AEWDABTWVDXVYXJC5FETLNT4TTMPRDVATN6SO
#\\\|3AFNQEQQWWMCJAZXY54K4H2QLEL76OU5GPFRHIH6PKDTTJPBBWF \ / AMOS7 \ YOURUM ::
#\[7]JFYSA7SANXQBBAQO332HBHR72DX4EXXAAXFBWFVPPA4JSHU3XWCQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
