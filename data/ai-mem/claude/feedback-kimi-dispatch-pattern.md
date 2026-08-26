---
name: kimi-dispatch-pattern
description: dispatching implementation tasks to kimi via bin/kimi-task is highly token-efficient and productive
metadata:
  node_type: memory
  type: feedback
  originSessionId: 3e611ce5-11ac-409b-bf6d-272aa2ab6339
---

**Current method (2026-07-14): the MCP tools `kimi_dispatch` + `kimi_continue`**,
not `bin/kimi-task`. Point `kimi_dispatch`'s prompt at the task file path
directly (kimi reads it autonomously, same as the network-dispatch pattern
below). `auto_summarize` (default true) runs the raw output through a local
9B model before returning — this can silently drop the "To resume this
session: kimi -r <uuid>" resume line from the summary. If a dispatched task
needs `kimi_continue` later and the resume line didn't come through, check
the kimi TUI/session transcript for the `session id : <uuid>` line near the
bottom rather than guessing — don't start a fresh dispatch, it loses all
prior debugging context.

Dispatching coding tasks to kimi via `bin/kimi-task -next -file task.md` is the
most token-efficient way to get implementation work done. Opus input tokens for
task prompts are cheap; kimi's output tokens do the heavy lifting.

**Why:** opus output tokens are 5x more expensive than input. A well-crafted
task prompt (3-5KB) can produce 10+ modules of implementation from kimi.

**How to apply:**
- Write detailed task files with: files to read, what to build, P7 pitfalls
  to avoid (base.logs not base.log, no `my $call`, no fake signatures, TRUE=5)
- Use `-next` flag for fresh session per task
- `-template` flag is coding zenka only — kimi does NOT support it; write
  the full task context directly in the task file instead
- Kimi v2 is faster at orientation and has more consistent result quality
- Network dispatch: `kimi.ask-reply :next: :file: data/tasks/foo.md`
  kimi sees the path string, pattern-matches it as a file reference, and calls
  ReadFile() on it autonomously — the file content drives the task
- `:next:` token starts a fresh session; without it, kimi appends to the current
  session context and the ask-reply return value may be the previous task's cached result
- Real results for network-dispatched tasks arrive via the approval queue in the
  web frontend, not as the MCP return value from ask-reply — fire and watch the frontend
- Review kimi output for known issues: fake signature stubs, `base.log` vs
  `base.logs`, `my $call` redeclaration, `sprintf qw|...|` misuse
- **`sprintf qw|...|` misuse, precise mechanism** (confirmed live 2026-07-22,
  a real bug that took v7's own boot down): `sprintf`'s prototype is `($@)`
  — its *first* syntactic argument is forced into scalar context. A
  multi-word `qw()` list in scalar context evaluates via comma-operator
  semantics and collapses to its **last element only** — so
  `sprintf( qw| foo.bar %s %s |, $a, $b )` does NOT become
  `sprintf('foo.bar', '%s', '%s', $a, $b)` as flattening intuition
  suggests; the `qw()` collapses to just `'%s'` (its last word) *before*
  becoming the format string, `$a` fills that lone placeholder, `$b` is
  silently dropped. Verified with `perl -e` (`sprintf(qw|a b|,"X")` → `b`,
  not `a` or `X`).

  **Not a reason to flag every `sprintf(qw|...|)` call** — a single-word
  `qw| [cmd:%s] |`-style format (no internal whitespace, so nothing for
  scalar context to collapse) is a genuinely safe, established idiom in
  this codebase (taeki uses it routinely) and is almost certainly *why*
  kimi reached for the pattern at all — it's pattern-matching on real,
  correct, pervasive surrounding style. The trap is specifically the
  generalization step: extending a safe single-word idiom to a multi-word
  phrase, where the single-word constraint that made the original safe
  isn't visible from the pattern itself. Even taeki has hit this
  expanding-a-known-safe-idiom trap before, hence now deliberately
  restricting `sprintf qw|...|` to single-word formats only.

  **How to review**: grep `sprintf( *qw\|` across every changed file, then
  check *only* whether each hit's `qw()` content contains internal
  whitespace (multi-word = broken, single-word = fine) — don't flag single-
  word hits, and don't skip checking just because the surrounding file
  uses the idiom safely elsewhere.
- User signs and stages; Claude commits — keeps the flow fast
- Kimi can work autonomously on tasks while waiting for token reset
- **Parallel tasks (pre-queue-module)**: open multiple kimi-cli browser tabs as
  independent workers, coordinate via `bin/chat` script — each tab is its own
  session, chat provides the P7-native coordination channel for task assignment,
  status updates, and result handoff. zero new code needed until kimi.queue exists.
- When parallel tasks hang on update-signatures: check if modules were written
  before the hang (`ls src/the.new.module`) — usually yes, just resume and
  tell kimi signatures are handled by the human
- **kimi-cli mid-stream inject**: ctrl+s sends immediately without waiting for
  newline — use to course-correct before kimi commits to a wrong direction.
  works while kimi is still "thinking". paste the redirect message, hit ctrl+s.
- **always point kimi at its own reference material** — kimi does NOT read
  `data/ai-mem/kimi/coding-style.md` or `data/ai-mem/kimi/MEMORY.md` by
  default. Every task prompt/file should explicitly say to read both before
  starting. Input tokens are cheap; the payoff is immediate — fewer P7
  convention mistakes (see the `base.swap_subs` namespace mixup this style
  guide now documents, from [[feedback-base-prefix-stripped]]) without
  re-deriving them per task.
- **ask kimi to maintain its own memory when a task teaches it something
  non-obvious** — after a task that surfaces a codebase gotcha (a subtle
  runtime behavior, a naming convention, a pitfall), explicitly ask kimi to
  add a note to `data/ai-mem/kimi/coding-style.md` and/or
  `data/ai-mem/kimi/MEMORY.md` in its own established format, same as any
  other task instruction — it does this well when asked (see the
  `base.swap_subs` write-up added 2026-07-11) but won't do it unprompted.

- **default to `k3-256k`, not plain `k3`, even for design-level dispatches**
  (per user, 2026-08-15, after dispatching a genuinely new-design task —
  frame-geometry work for `user-edit`'s corner-checksum display — on plain
  `k3`): `k3-256k` gives the SAME reasoning quality at roughly half the
  quota, with a 256k context ceiling and no video input. That ceiling
  covers essentially every task file + referenced-file context this
  project's dispatches have needed so far. Reserve plain `k3` for the
  narrow case where a task genuinely needs more than 256k context or video
  input — not "this task involves design reasoning," since k3-256k clears
  that bar too. Re-check this default periodically; it's about relative
  quota cost, not a claim that k3-256k is literally the same model.

#,,,,,,..,...,.,,,,,.,,..,.,,,,,.,,.,,.,.,.,,,..,,...,...,,.,,,,,,.,,,,.,,,,,,
#2HW3NOILGTT6FZVMD6PET42NYQMTTKKAWBKOOLII7TJC6NIS5KDW2OIGFYQQBOAS6CJL2CORPYJBI
#\\\|RZKNS4MWMYLEEJJVSBH6ZYEXITRZBIOMESMA4GD243SK5BSEBQY \ / AMOS7 \ YOURUM ::
#\[7]WBUPCJKW4TBAG2EADDVMM6JDL36AXQYBZ3SVX3UYEJADRPCRI6AQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
