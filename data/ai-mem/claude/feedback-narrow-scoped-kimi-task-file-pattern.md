---
name: feedback-narrow-scoped-kimi-task-file-pattern
description: writing a self-contained data/tasks/*.md file per dispatch -- pointing at one design-doc section, one existing precedent module to mirror, an explicit out-of-scope list, and static-only verification (no live execution needed) -- got four kimi K2.7 dispatches right in a row on the user-edit console zenka work; still requires reviewing the actual diff before signing, caught two real bugs the syntax check didn't
metadata:
  type: feedback
---

Building `user-edit` (see [[topic-user-edit-console-zenka-status]]), four
separate `kimi_dispatch(model=k2.7)` calls in a row landed clean or
near-clean implementations, each against a task file with this shape:

- **one design-doc section named explicitly** (e.g. "read
  `phase_1b_path_discovery` specifically ... the rest of the doc ... is
  NOT in scope"), not "read the whole design doc and figure out what's
  relevant" — narrows what kimi has to reason about before writing code.
- **one or more existing precedent files named and pointed at directly**
  — `keys/start` to clone the shape of, `workspace-transfer.pre_init` for
  the one real `register_keywords` call site, and — most effective of
  all — later tasks pointed at the PREVIOUS task's own output as the
  precedent ("mirror `user-edit.outbox.write/list/clear`'s structure
  exactly, you are applying an already-approved pattern to a second use
  case"). Once phase 1-3 existed, later dispatches had zero net-new
  design decisions to make, only pattern application — this is likely
  why the fourth dispatch (draft storage) came back clean with no fixes
  needed, while the first two each needed a correction.
- **explicit "explicitly out of scope" list**, always including "no live
  network/filesystem execution" and "don't touch already-committed
  files X/Y/Z" — kept every dispatch's blast radius to new files only,
  made diff review fast (only ever 1-4 new files to check per dispatch).
- **verification section that doesn't require a live zenka** — `bin/dev/
  ptd -c` syntax checks plus "trace this by hand and state what path it
  resolves to" instead of "run it and confirm." user-edit isn't network-
  reachable yet (no cube access granted on purpose), so any verification
  requiring execution would have been impossible anyway — designing the
  task around that constraint up front avoided a dead end.
- **named, specific P7 pitfalls pasted directly into the task file**
  rather than just "read coding-style.md" — the swapped-module-family
  rule (`base.file.*`→`file.*` at runtime, `base.path.*` does NOT swap)
  was spelled out inline in three of the four task files, and kimi got
  it right both times it was load-bearing (calling `file.zenka_dir.
  data_path`/`file.make_path`/`file.all_files` correctly unprefixed
  while keeping `base.path.*`/`base.perlmod.*` fully prefixed) — this is
  a documented common kimi mistake area elsewhere in memory
  ([[kimi-dispatch-pattern]]), and pointing at the specific rule inline,
  not just "go read the style guide," seems to have mattered.

**Still caught real bugs after "syntax ok" + a clean kimi summary,
twice**: task 1 (skeleton) — kimi noticed and fixed a real contradiction
I'd introduced in the task prompt itself (a generic networked-zenka boot
sequence pasted alongside a pointer to `keys/start`'s actual standalone
pattern), documenting its reasoning unprompted. Task 3 (outbox) —
`outbox.list` called `base.file.all_files` (runtime: `file.all_files`)
against a directory that doesn't exist yet on a fresh zenka; that sub
`base.s_warn`s on a missing path, so every call before the outbox had
ever been written to would log a warning for a completely normal state.
Kimi's own `// []` coercion made the RETURN VALUE correct, so the task's
"return empty arrayref if directory doesn't exist" verification step
passed — the bug was a side effect (log noise) invisible to a
return-value-only check. Fixed with a `-d` guard before the call.

**How to apply**: this shape is worth defaulting to for kimi dispatches
generally, not just this project — narrow scope + named precedent +
explicit non-goals + execution-free verification. But "syntax check
passed" and "summary looks clean" are not sufficient signals to sign
without reading the actual diff — the outbox bug specifically would not
have been caught by trusting the task's own stated verification
criteria, only by independently reasoning about what the called sub
actually does in the missing-directory case.

**Efficiency data point, 2026-08-22**: a k2.7 dispatch built with this
exact shape (Tcreate/Tremove for the 9P subsystem — 8 new/changed
files, 4 named precedent files pointed at directly, explicit Twstat
out-of-scope note, static-only verification) used only ~4% of kimi's
session token budget and came back with correct, working logic on the
first pass — the only real defect found in review was a malformed
signature-footer shape (see [[fake-signature-marks-ai-scratch-content]]'s
addendum), not a logic bug. Confirms the pattern scales down to genuinely
small budget cost for well-bounded feature work, making it a good default
for weekly k2.7/k3 budget balancing, not just a quality-of-output win.

#,,,.,.,,,,,,,,,.,,..,..,,..,,,,,,.,.,.,,,.,.,..,,...,...,.,,,..,,..,,.,,,.,.,
#RHTZILBZHNXHU3RV4LBWGESTDNUYEOWVWKX37C7CPPVH2YAMVKZYMQHUKEWJC2SYCVVQAH7LYI6LM
#\\\|TDXZS4B4YJAJRPDAXVELI6KG3VOWTBBXNZLGLBO246PGVH6FMPN \ / AMOS7 \ YOURUM ::
#\[7]27ZBGB7WVPTYCCERP77ZAT42D3V5PM6NJDXDRMTTBHRN2LAXSYCA 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
