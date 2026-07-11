---
name: kimi-dispatch-pattern
description: dispatching implementation tasks to kimi via bin/kimi-task is highly token-efficient and productive
metadata:
  node_type: memory
  type: feedback
  originSessionId: 3e611ce5-11ac-409b-bf6d-272aa2ab6339
---

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
- User signs and stages; Claude commits — keeps the flow fast
- Kimi can work autonomously on tasks while waiting for token reset
- **Parallel tasks (pre-queue-module)**: open multiple kimi-cli browser tabs as
  independent workers, coordinate via `bin/chat` script — each tab is its own
  session, chat provides the P7-native coordination channel for task assignment,
  status updates, and result handoff. zero new code needed until kimi.queue exists.
- When parallel tasks hang on update-signatures: check if modules were written
  before the hang (`ls modules/the.new.module`) — usually yes, just resume and
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

#,,,,,,,,,..,,,,,,,,,,..,,,..,,,,,,,,,,..,,.,,..,,...,...,,,,,,,.,,,.,,,,,,,.,
#I5DKFS75NRHC2NQCJOTHLPASOBA7YY65REGO63EGDTZ7244PWJ4IA6GDXQRPNDMIVOKMDZLZOJ3UO
#\\\|XRLCKUACHAXTZFHMZJEPL5KHITM32ND4YMS3OLDQE6FLX3AKXUD \ / AMOS7 \ YOURUM ::
#\[7]QZ33I2BPPBBWXZTJB2EXHBDRGLTINHEX27PR2SCP5RFDKWQD4EAI 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
