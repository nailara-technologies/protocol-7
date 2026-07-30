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

**How to apply:** before assuming a slow `kimi_dispatch`/`claude_dispatch`
return is the known hang from [[feedback-claude-dispatch-summarize-hang]],
consider it may just be legitimately working but slow on a small-context
session — check elapsed time against the ~13min self-resolve window noted
there before intervening.

#,,..,,.,,,,.,.,.,...,...,,.,,,..,,,.,,.,,.,,,.,.,...,...,..,,,,,,.,,,.,.,.,.,
#FZI2U5XSBYMKHQJQMXFAOWK2OIJ5SJUP242SENJKAGSFJS3CVXVKND5IRPFNB2NA4YADJDDGE755C
#\\\|G4QT4PDKOVCXNMQZPSS4BXEWTI3ZMS7KBPIU66F2DLDWTMPW5UC \ / AMOS7 \ YOURUM ::
#\[7]UOWF76VE24FDWC5SZVDR4ZXRLNQY2JZCTNJNIFRY7HNZ2FXMYUAA 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
