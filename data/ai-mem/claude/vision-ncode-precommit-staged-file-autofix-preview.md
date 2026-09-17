---
name: vision-ncode-precommit-staged-file-autofix-preview
description: the actual ncode design/implementation history lives in [[topic-ncode-pattern-learning-loop]] (self-learning regex-vs-LLM pattern pipeline, phases 1-2 landed 2026-07-24/30, live-verified) -- this file only captures the one genuinely new, unbuilt piece stated by the user 2026-09-17: wire an ncode scan into the pre-commit hook, scoped to staged files, offering a fix-with-preview to accept in one action
metadata:
  type: vision
---

**Correction 2026-09-17**: an earlier version of this memory
mis-described ncode as an unbuilt "nshell zenka" idea and re-derived a
shallow architecture sketch from a single design doc
(`data/md/coding-tasks/ncode-zenka-self-refining-regex.md`) without
first checking existing memory. The real, authoritative record is
[[topic-ncode-pattern-learning-loop]] -- read that file, not this one,
for how ncode actually works and what's already landed: a two-tier
mechanical-vs-LLM pattern model, a self-learning streak/graduation gate
(phase 1, `ncode.cmd.pattern-review`/`.graduate`/`.expand`, landed +
live-verified 2026-07-24), and namespace scope-stack widening (phase 2,
landed + live-verified 2026-07-30). `ncode.init: 17 patterns loaded`
at every coding-zenka boot confirms this is genuinely live, not
theoretical.

**The one thing actually new here, stated directly by the user**: not
ncode itself, not the review/graduation loop (both exist) -- wiring an
ncode scan into the **pre-commit hook**, scoped to **staged files**
specifically (not a whole-tree sweep), that offers a concrete fix with
a preview to accept in one action rather than just flagging a match.
Not scoped as a task file yet.

**A real blocker this integration would likely hit immediately**, per
[[topic-ncode-pattern-learning-loop]]'s own still-open finding: as of
2026-07-24, `access.zenki` has **no grant for any caller to reach
`ncode.*` at all** except the `<admin-user>`/`<unix-admin>` wildcard --
that's why phase 1's own smoke tests worked (run as `unix-taeki` via
`p7c`, which resolves through that wildcard). A pre-commit git hook
almost certainly runs as a different principal than that wildcard
covers; check whether this gap was closed before assuming the hook can
just call `ncode.cmd.pattern-review`/`.apply` directly. If not, that's
the real prerequisite, not new ncode functionality.

**A live candidate pattern for whenever this gets built**: the
`qw| multi word |` list-flattening gotcha
([[feedback-qw-multiword-list-flattening-in-list-context]]), found the
same session -- syntactically valid, semantically wrong, tied to this
codebase's own `qw|word|` idiom, mechanical fix once detected. Exactly
tier-A shape per [[topic-ncode-pattern-learning-loop]]'s own model.

## related

[[topic-ncode-pattern-learning-loop]] (the real design/status record),
[[feedback-qw-multiword-list-flattening-in-list-context]]

#,,,.,,.,,,,.,,,.,..,,,,.,,,.,.,.,,.,,..,,...,.,.,...,...,...,.,.,...,,.,,,..,
#7SAGB2U7E5XMTJERSGYE326UBMP3XAJP44C6BUBHOAQW4HOG4QPGXN766PJIKSKKRLDRV7DAPJTFI
#\\\|PV5XMUKH224ICAXKUDUIPZBBJEOL4P7IFPCJVDE3CTMZHSHPWKT \ / AMOS7 \ YOURUM ::
#\[7]5ZN3AJF44QOHAZ2GXAAYLQWRMVKQM4T5HTAEDICWJ35DW6H3TUDI 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
