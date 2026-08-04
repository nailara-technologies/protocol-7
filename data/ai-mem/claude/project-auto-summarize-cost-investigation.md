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
fix dispatched this session: `modules/kimi.flush_on_acquisition` is
defined but never called from the reconnect branch of
`modules/kimi.handler.ws_message`, plus two more bugs inside
`flush_on_acquisition` itself (arrayref/hashref type mismatch on reset;
re-flushes a fabricated blank payload instead of the original stored
approval data). Task file: `data/tasks/kimi-zenka-approval-reconnect-
disassociation-fix.md`, dispatch task id `k8usgy2y0` (K3, in flight as of
this update). If this lands, revisit whether the `coding_summarize`
profiling investigation below is still needed at all, or only for
non-kimi dispatch paths (e.g. `claude_dispatch`).

**How to apply:** before assuming a slow `kimi_dispatch`/`claude_dispatch`
return is the known hang from [[feedback-claude-dispatch-summarize-hang]],
consider it may just be legitimately working but slow on a small-context
session — check elapsed time against the ~13min self-resolve window noted
there before intervening.

#,,,.,,..,,..,,,,,.,,,,,,,...,...,,,,,,.,,,..,.,.,...,...,,.,,..,,,,.,..,,,..,
#B7K7NQTYWIWTFEFK6ZRY6XHDBCSA54BQVM6JXEGI4YIT64IA5MORTMW4GN322BPFFDHS3ZVBBYAKM
#\\\|QOR6J3SLT7OVL7CXO2366MUCL5VGNJC7YZHKI6I2J4IEULI7A45 \ / AMOS7 \ YOURUM ::
#\[7]Y2YC2NDCS6F6IU25Q44ZZ74HDU3YJ4CZEK5RYFDPKAVWKGQJDSDY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
