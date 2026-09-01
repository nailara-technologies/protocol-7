---
name: feedback-kimi-dispatch-never-parallel
description: "never run two kimi_dispatch/kimi_continue calls concurrently -- reproducible session-collision/early-termination pattern, root cause outside this repo's own source (kimi-legacy binary itself, not bin/mcp-server-p7)"
metadata:
  type: feedback
---

2026-09-01. Dispatched two format-code tasks (`-p` postfix-deref,
`-r` regex-delimiter) via `kimi_dispatch` in the same message, expecting
independent parallel sessions. Real consequences, traced across several
turns:

1. **Only one kimi session actually existed afterward** (confirmed via
   the user checking `kimi -r`'s resume picker directly) — not two. The
   second dispatch's session either never registered or got clobbered.
2. **One dispatch's result was a 9.7MB/114k-line garbage dump** instead
   of the actual small result — inconsistent with the coding zenka's own
   completion log showing `result_len=1115` for the same task. Traced
   this partway to a real, separate `cube` protocol bug (see
   [[feedback-cube-trm-wrong-reply-type-for-size]] if that gets written)
   but the size mismatch itself is consistent with session confusion.
3. **The re-dispatched `-r` session (once the first attempt's session
   turned out to not exist at all) ended abruptly mid-investigation** —
   stopped while still chasing "some errors" in its own 100-file batch
   test, well before its 4620s server-side timeout and with plenty of
   token budget left (verified: weekly 87%, session 21% used at the
   time). `kimi_continue` on the exact session UUID was used to resume
   it from where it left off.

**Ruled out**: `bin/mcp-server-p7`'s own timeout handling. Checked
directly — `kimi_dispatch`/`kimi_continue` have `'timeout' => 4620` in
the `@external_tools` config (`bin/mcp-server-p7:140,188`), and the
actual subprocess call is one blocking `qx($cmd)` (line 3809) with no
other kill logic in this file. An `alarm(590)` elsewhere in the same file
belongs to an unrelated summarization helper (`_do_summarize`/
`_do_summarize_file`), not the kimi dispatch path — easy to
misidentify as the culprit at first, it isn't.

**Most likely remaining explanation**: something inside `kimi-legacy`
itself (the external CLI binary this server execs, not part of this
repo's own source) when two invocations run concurrently against
overlapping session/lock state. Not confirmed, not further traceable
from `bin/mcp-server-p7`'s side alone.

**How to apply**: always dispatch `kimi_dispatch`/`kimi_continue` calls
strictly sequentially, one at a time, even though the MCP tool interface
technically allows firing them in parallel in one message. If a
dispatch's result looks wrong-sized, garbled, or a resumed session
reports "still investigating X" from a genuinely stopped (not paused)
prior run, suspect this pattern before assuming the model itself failed
or ran out of budget — check `ps aux | grep kimi` and the `kimi -r`
resume picker to see actual session state directly rather than trusting
the MCP tool's own result/notification.

## related

[[project-kimi-k2.7-vs-k3-tier-economics]]

#,,,,,.,,,..,,.,,,...,.,,,.,.,.,.,,,.,,,.,.,.,..,,...,...,,..,..,,,.,,..,,.,.,
#4YKGRV23K72YNLSLZH26AHVBHANEYFNTMNHJGDVUGIPJOEI6S7GQNPABJWF4JNTKPUFAVJDNQK3HY
#\\\|NE7BV5Z6PWSDSW3APJSXBDG7JFNYY3GTCCLAYUTCVWJ32T2TLMH \ / AMOS7 \ YOURUM ::
#\[7]XTM4GOGLKLTYLJQYAJD5FTLEHDXZOX6KM5XESZSZP7GVSBVKGUDY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
