---
name: feedback-kimi-dispatch-never-parallel
description: "never run two kimi_dispatch/kimi_continue calls concurrently -- reproducible session-collision/early-termination pattern. NOT settled as an accepted external limitation -- user (2026-09-02) frames this as a likely regression in bin/mcp-server-p7 itself, not a best-practice API constraint to comply with indefinitely"
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

**2026-09-02 correction, per the user directly**: do not treat this as a
settled "best practice"/permanent API constraint to just comply with
indefinitely — it is a **regression**, and the fix belongs in
`bin/mcp-server-p7` itself, not in accepting a workaround forever. The
2026-09-01 investigation above only ruled out one specific mechanism
(the tool-level `timeout`/`alarm` handling) — it did not rule out the
rest of the script (session-id generation, lock/state-file handling
around concurrent `qx()` subprocess launches, etc.), and concluding
"most likely `kimi-legacy` itself" was premature. Consistent with
[[feedback-upgrade-substrate-not-revert-on-tool-limits]]: when this
becomes active work, look for the actual bug in `bin/mcp-server-p7`'s
own session-management code before accepting external-cause as the
final answer, so the sequential-only rule can eventually be retired
rather than permanently documented as required behavior.

**2026-09-08 update -- a real bug WAS found and fixed in `bin/mcp-server-
p7`, but it is probably not this one, and may make this one newly
testable rather than resolved.** Root-caused and fixed (see
[[mcp-server-p7-kimi-dispatch-nonblocking]]): the whole server is a
single blocking `while (<STDIN>)` loop, and `kimi_dispatch`/`kimi_
continue` ran their subprocess via an unconditional blocking `qx($cmd)`
that held the entire server hostage for the full run. Fixed via a
double-fork detach so dispatch/continue return within ~6s instead of
blocking for the run's full duration.

**why this doesn't obviously explain the 2026-09-01 collision, and may
even make it newly reproducible**: under the OLD blocking architecture,
two "concurrent" `kimi_dispatch` calls could never actually run their
`kimi-legacy` processes at the same time at all -- the second request's
own `qx()` line couldn't even be read off STDIN until the first one's
`qx()` call returned, since the server only reads its next line once the
current handler returns. That's pure serialization (slow, but not
collision-shaped) -- not an obvious match for "only one session existed
afterward" / garbled results. **After the fix, two dispatches sent close
together can genuinely run their kimi-legacy worker processes
concurrently for the first time ever** -- which means the open question
this memory already flagged (something in kimi-legacy's own session-id
generation / lock-file handling when invoked concurrently) is now
actually testable, where before it structurally couldn't manifest this
way. **Do not treat the sequential-only rule as retired based on today's
fix** -- it addresses a different, real problem (one dispatch blocking
unrelated tool calls like `kimi_check_status`), not this one. Test two
genuinely concurrent `kimi_dispatch` calls post-fix, watching for the
exact 2026-09-01 symptoms (session count via `kimi -r` picker, output
size sanity), before updating this guidance again.

## related

[[project-kimi-k2.7-vs-k3-tier-economics]]
[[mcp-server-p7-kimi-dispatch-nonblocking]]

#,,..,,.,,...,.,,,,,.,,,.,...,,,,,,..,.,,,,,.,..,,...,..,,...,...,,.,,.,,,,,,,
#ZUQTDWS6QJCU7NRFYP2IAK7CE2I6SCOUBLIQCIIQS7GD7QTNSSRE2U7WXF4ZNIYL7XWLRDTNDMYAY
#\\\|IBFYP4MCHKLTJTUUZXZ5JB65WZMQZZ7US7KIBZ6GPLBTT5RJYFL \ / AMOS7 \ YOURUM ::
#\[7]OKVTPOUYD44AFHZJ3S34FHWZIUHZAD76ATIBHDTK7UOY3QGWSQCY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
