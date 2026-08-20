---
name: project-auto-summarize-cost-investigation
description: user hypothesis (2026-07-30) that dispatch auto_summarize isn't actually hanging/failing, just slow on small-context sessions — needs its own investigation into what coding_summarize does and a lighter/faster alternative
metadata:
  node_type: memory
  type: project
  originSessionId: 8a65c64f-bcd4-43e6-9d47-e37ee5dc8750
  modified: 2026-07-30
---

Distinct from [[feedback-claude-dispatch-summarize-hang]] (confirmed
failure/stuck-poll-loop cases). User's read on 2026-07-30: `auto_summarize`
likely *does* work correctly most of the time — the actual problem is that
`coding_summarize`'s local-9B call takes a long time specifically when the
session's context is small, which is backwards from what you'd expect and
worth its own investigation rather than assuming every slow return is the
known hang.

**Investigation still needed:**
- what `coding_summarize` is actually doing internally, and why small
  context would be slow (as opposed to just cheap) — profile it rather than
  guessing
- if the model itself is just heavy: look for a lighter model with
  configurable context size as a swap-in

**Proposed alternative approach**, if the above doesn't pan out cleanly:
detect the last round in the session log with plain Perl (no LLM call) and
either return that directly with no summary, or hand only that last round
to the summarizer instead of full context — much cheaper input either way.

**Prior art, not currently wired in**: the currently-unused kimi zenka
already implements "return final message only" (no summarization step).
It's not in use because of a known separate bug: approval-request state
disassociates from the session during a backend reconnect, and the caller
hangs until a human manually approves in the UI. Both problems (this one
and the summarize-cost question) are believed fixable, but treat them as
two separate fixes — don't conflate "make the kimi zenka's last-message
path work" with "make auto_summarize faster."

**Update 2026-08-04 — the two threads are actually coupled, per the
user**: fixing the reconnect/approval-disassociation bug re-enables the
kimi zenka's own last-message-only return path — once that's live, `kimi`
dispatches go back to returning only the final round (kimi-generated),
never the full session context, which sidesteps the `coding_summarize`
local-9B cost/slowness question for kimi-routed dispatches specifically
(it stops being invoked at all on that path). Root cause found and a K3
fix dispatched this session: `src/kimi.flush_on_acquisition` is
defined but never called from the reconnect branch of
`src/kimi.handler.ws_message`, plus two more bugs inside
`flush_on_acquisition` itself (arrayref/hashref type mismatch on reset;
re-flushes a fabricated blank payload instead of the original stored
approval data). Task file: `data/tasks/kimi-zenka-approval-reconnect-
disassociation-fix.md`, dispatch task id `k8usgy2y0` (K3, in flight as of
this update). If this lands, revisit whether the `coding_summarize`
profiling investigation below is still needed at all, or only for
non-kimi dispatch paths (e.g. `claude_dispatch`).

**Update 2026-08-04 — likely root cause found, thinking-mode never
disabled**: motivated by watching K3's own local coding-zenka batch
scoring step during an unrelated dispatch — it visibly burned its whole
reasoning budget on the local model before assertion sped up, once
thinking got disabled. Traced the actual `coding_summarize` call chain
directly: `coding.cmd.summarize-context` →
`coding.tools.handler.summarize_enqueue` → the inference payload build.
**No `enable_thinking`/`no_think`/reasoning-mode control exists anywhere
in that path** — grepped the whole codebase for it, one unrelated hit
only (`jobsite.util.build_prompt`). So every summarization call goes to
the local model with whatever reasoning-mode it defaults to, completely
unaddressed by this code. If the local model defaults to thinking-on,
that's a roughly *constant* per-call overhead regardless of input size —
which would make it dominate small-context calls (almost all time is
reasoning, little is summarization) while being proportionally smaller
and less noticeable on large-context calls. That directly resolves the
original "backwards" mystery: it stops being backwards once thinking-mode
overhead, not content volume, is the actual cost driver.

**Not yet fixed, only diagnosed** — next step, per the user: pass the
inference parameter through rather than hardcode a single choice. Add a
`thinking`/`enable_thinking` option all the way up the call chain
(`coding.cmd.summarize-context` → `coding.tools.handler.summarize_enqueue`
→ the inference payload) so callers can control it explicitly per call,
defaulting to whatever's fastest for summarization specifically (likely
off) rather than leaving it silently at the model/server's own default.
If the model/server doesn't expose a thinking toggle at all, fall back to
the original "lighter model" swap-in idea above. Measure small-context
summarization time before/after to confirm the fix actually worked —
don't treat this as closed until that's tested, diagnosis isn't the same
as verification.

**How to apply:** before assuming a slow `kimi_dispatch`/`claude_dispatch`
return is the known hang from [[feedback-claude-dispatch-summarize-hang]],
consider it may just be legitimately working but slow on a small-context
session — check elapsed time against the ~13min self-resolve window noted
there before intervening.

#,,.,,.,.,,,.,,.,,...,,.,,,..,..,,.,,,,..,..,,.,.,...,...,..,,...,...,,,,,,.,,
#EBKR34SS3JNMSAC7J25FBNJ3MGKI5XJ3QYJMVN4EIAHCYCK2PPZI67FR73EEIHAXTAZAAGWQS2MP4
#\\\|L7QLMMNY7RVSWKUMVTCHHRNEKJL4FPLC2WVQVJ4W5IUVHIQ7GON \ / AMOS7 \ YOURUM ::
#\[7]TPO3HXB7XW3H6JF6ITQJRPY3N7EZ6GL4NQHKLNOM66CQKPFXWOBQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
