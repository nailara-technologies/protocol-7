---
name: bug-ncode-assess-replace-not-backreferenced
description: ncode.regex.assess (via context.pattern.extract_from_change) builds a capture-group pattern but a literal, non-backreferenced replace in every branch -- no assess-extracted pattern can generalize across a varying matched token
metadata:
  node_type: memory
  type: project
  originSessionId: 8a65c64f-bcd4-43e6-9d47-e37ee5dc8750
  modified: 2026-07-31
---

Found 2026-07-31 while trying to run the ncode tier-A chain end-to-end
starting from `assess` (not `expand`) against a real, unfixed style
violation in the repo (CLAUDE.md's `[ word ]`-not-`( word )` comment
convention — real occurrences still exist, e.g.
`src/amos-term.render.draw_buffer:41`, `src/transport.init_code:27`).

**Confirmed on two independent inputs**, both hitting the "generic
token" branch:

```
p7c ncode.assess '{"old":"## offset for 3D effect (parallax) ##","new":"## offset for 3D effect [ parallax ] ##", ...}'
-> pattern: ## offset for 3D effect \(([\w\-]+)\) ##
-> replace: ## offset for 3D effect [ parallax ] ##      <- literal, not $1

p7c ncode.assess '{"old":"## default probe interval (seconds) ##","new":"## default probe interval [ seconds ] ##", ...}'
-> pattern: ## default probe interval \(([\w\-]+)\) ##
-> replace: ## default probe interval [ seconds ] ##     <- literal, not $1
```

**Root cause, `src/context.pattern.extract_from_change`**: every
branch (numeric, identifier, quoted-string, value-assignment, and the
generic-token fallback at lines 92-103) does the same thing — build
`$pattern` with a real capture group, then build `$replace` by splicing
in the literal `$new`/`$new_middle`/`$new_val` string instead of `$1`
(or the matching numbered backreference for multi-group branches). Not
specific to the token branch; this is systemic across the whole file.

**Why it matters**: this is the exact case a style sweep needs —
"replace `(anything)` with `[ anything ]`" only works as a *reusable*
pattern if the replace reconstructs the captured value. As built, every
`assess`-extracted pattern is permanently overfit to the one line it was
extracted from — it would apply cleanly (syntax-valid, harmless) but
never match/fix any *other* occurrence, defeating the entire point of
persisting it. This is distinct from (but adjacent to) the already-fixed
`cb45d56d0` gap (missing `steps` synthesis) and the already-known
"capture groups the `replace` doesn't reconstruct from" note from
[[topic-ncode-pattern-learning-loop]]'s 2026-07-24 `ncode.cmd.assess`
live test (0.65-confidence case) — that earlier note observed the same
symptom but didn't root-cause it to this file.

**Not yet fixed.** Fix shape: after building `$pattern`/`replace` in
each branch, `$replace` needs to substitute the captured group's
backreference instead of the literal new value — e.g. for the generic
token branch, track which `\w+`/`\d+` run in `$old_middle` maps to which
capture group index and reference `$1`/`$2`/... in `$replace` at that
position, rather than splicing in `$new` wholesale. The single-group
branches (number/identifier/quoted-string) are simpler: swap the literal
`$new_middle` for `$1`. The multi-var generic branch is the hard case
and needs real design thought (multiple captures, positional mapping).

**Nothing landed from this investigation** — no pattern was expanded or
applied, `<ncode.patterns>` untouched, no files touched. This blocks
using `ncode.cmd.assess` for any real style-sweep goal until fixed;
tier-A can still be used today via hand-authored `pattern`/`replace`
(the existing `single-quote-to-qw-scalar` pattern in
`data/yaml/ncode-patterns/p7-style.yaml` was authored this way, not
assess-extracted).

## related

[[topic-ncode-pattern-learning-loop]] — phase 1/2, the `cb45d56d0` steps-
synthesis fix, and the 2026-07-24 0.65-confidence note that first hinted
at this without root-causing it.
[[project-2026-07-30-gap-audit]] — corrects that memory's "tier-A chain
never run end-to-end" line (it *was* run once, from `expand` onward, via
kimi K3 dispatch `kbx4su758` on 2026-07-24, against a scratch file; what
was untested until now was `assess` as the entry point against a real
repo occurrence).

#,,,,,.,.,,,,,,.,,..,,,,,,,,,,.,.,.,.,,,,,...,.,.,...,...,.,.,,,.,,..,,.,,,,.,
#Y7LPMEW7XMF7YKQB553THYJBPLGT76FWLJPUNZYZPEJ4FC2HSIYBBLSUNMLFH5OJZWD656YJ77YB6
#\\\|3N4FHXBZTYRWVEHKHPLD2FQ6QMFKQTMEPY23TPNOYZ5JRUK2KYH \ / AMOS7 \ YOURUM ::
#\[7]ZNDG24PZTNIHN5C6ERR5G7XQ7Z5WUNFXQAL2KY3RK3S5YSQHDECQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
