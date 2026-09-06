---
name: feedback-audit-shared-state-when-multi-instance-bolted-on
description: "when a commit adds multi-instance/auxiliary support to code written for a single always-exit instance, git-show that exact commit to see what it actually touched vs. left alone — surrounding globals, log wording, and exit-only assumptions are easy to miss and only manifest once the new instances are actually concurrent"
metadata:
  type: feedback
---

Found live during the 2026-09-06 X-11 xvfb session
([[project-x11-xvfb-crash-loop-and-cleanup-2026-09-06]]): `X-11.handler.
server_output` still used `<X-11.output_buffer>`/`<X-11.first_error>` —
single global scalars, not keyed by pid/display — and unconditionally
logged `"done."` (a zenka-shutdown idiom used elsewhere, e.g.
`X-11.connect_X11`'s `base.exit(3,'done.',1)`) even on the auxiliary-
server code path that does NOT exit the zenka.

**How this was found, and why it's a reusable technique**: user pushed
back on my dismissal of the "done." line as merely misleading-but-
harmless. Ran `git log --follow -p -- src/X-11.handler.server_output`
and grepped for `is_primary`/`exit(2)` across the diff hunks to find
exactly which commit introduced the primary/auxiliary split, then
`git show <that commit> -- <old-path>` to see the FULL diff of that one
commit against this one file. It proved the mechanism precisely: the
commit (`55787d320`, "X-11: multi-server jobqueue architecture") changed
ONLY the literal `exit(2);` to `exit(2) if $is_primary; return;` and
touched nothing else in the function. Every other line - the shared
globals, the "done." log - was written years earlier (this file dates to
2015) under a single-instance, always-exit assumption, and was never
re-audited when multi-instance support was bolted on.

**Why it wasn't caught sooner**: not exploitable in practice until two
other same-session bugs were fixed - a crash-loop bug meant two
auxiliary Xvfb displays could never stay alive concurrently long enough
to hit the shared-buffer interleaving, so the latent bug was invisible
until the crash-loop fix made concurrent auxiliary instances real.

**How to apply**: whenever you find an `if ($is_something) { special-case
} else { general-case }` split next to state that predates it (globals,
alarming log wording, anything written as if only one code path could
ever run), don't just trust that the split covers everything - `git log
--follow -p` the file, find the commit that introduced the split, and
`git show <hash> -- <path-at-that-commit>` to see its FULL diff against
that one file. If the diff only touches the control-flow line and
nothing else, treat every other line in the function as suspect for the
same "written for the old single-path assumption" class of bug - check
whether any of it is genuinely single-instance-only state (globals,
messages implying exclusivity) that should have moved to per-instance
state when the split was added.

#,,,.,.,,,,.,,,.,,,,.,,..,..,,.,.,.,.,..,,,..,..,,...,...,..,,..,,,..,,,,,,.,,
#EXLLWGUDOWHCQ7C54OF5K4L2IBZPZJWWSSHMYBRHB3LOQX7Q5S5PCCVRNN24FEYCTQZSHTRZF6B5O
#\\\|2OUULE7MLPQENEMTUZWXITVTB6Q5M4QMQNZ5L3ITTV3K5GDQNK7 \ / AMOS7 \ YOURUM ::
#\[7]BEAU2F25UXFGOQ2UNZANBQSAMCSAL3X2CEEJATSDMBVPLX42XKCY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
