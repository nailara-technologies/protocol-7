---
name: mcp-server-p7-kimi-dispatch-nonblocking
description: bin/mcp-server-p7 is a single-threaded, one-blocking-STDIN-loop server -- kimi_dispatch/kimi_continue used to hold the whole server hostage via a blocking qx() for the entire kimi run, so kimi_check_status (and every other tool call) queued behind it instead of running. fixed 2026-09-08 via fork+detach, kimi-only.
metadata:
  type: feedback
---

found 2026-09-08 while debugging why `kimi_check_status` -- documented as
"returns within seconds" -- hung for the full ~1800s outer-harness idle
timeout, twice, on a genuinely-running kimi session (confirmed alive via
direct `ps`/log-tail the whole time it was supposedly hung).

**root cause, confirmed by reading `bin/mcp-server-p7` directly, not
assumed**: the whole server is one `while ( my $line = <STDIN> )` loop --
no fork/threads for request handling (there was already a comment in the
file documenting this exact tradeoff at an unrelated call site --
see [[feedback-claude-dispatch-summarize-hang]] for that sibling case,
a *different* mechanism in the same file, do not conflate the two).
`kimi_dispatch`/`kimi_continue` ran their `kimi-legacy` subprocess via an
unconditional blocking `qx($cmd)` -- so the entire server was stuck
inside that call, unable to read or service ANY other incoming request
(including `kimi_check_status`, which has its own fast, correct,
never-broken implementation -- it just could never get a turn to run),
for as long as the kimi run took (up to the 4620s alarm).

**the fix**: `kimi_dispatch`/`kimi_continue` now fork+detach (double-fork
-- intermediate child reaped at once, worker orphaned to init, avoiding
both a zombie-per-dispatch leak and breaking `qx()`/`system()` elsewhere
in the server) with a short ~6s bounded window: a near-instant failure
still returns synchronously with its real output, but a real run (always
minutes in practice) returns `status=dispatched_async` immediately with
the session uuid + a capture-file path, freeing the server for other
requests while kimi keeps running. **deliberately scoped to kimi only**
-- `claude_dispatch`/`claude_continue` share the identical blocking
architecture and the identical theoretical problem, but have no
`claude_check_status` to ever recover a result if they returned early, so
extending this same fix to them would be a regression, not an
improvement, until that's built. they still block exactly as before.

**diagnostic technique worth reusing generally, not just for kimi**: when
a custom local MCP server's "fast poll" tool inexplicably hangs for a
suspiciously round timeout value, check whether the server is single-
threaded/blocking before assuming the poll tool's own logic is broken --
`ps`/log-tail the underlying process directly to get ground truth while
investigating, rather than trusting the MCP tool's own non-response.

**does NOT resolve [[feedback-kimi-dispatch-never-parallel]]** -- read
that memory's 2026-09-08 update before assuming concurrent kimi_dispatch
calls are now safe. If anything this fix makes that older, still-open
bug newly TESTABLE rather than fixed: before this fix, two "concurrent"
dispatches could never actually run their kimi-legacy processes at the
same time at all (strict serialization via the same blocking loop) --
after this fix, they genuinely can, for the first time, which could
finally surface whatever kimi-legacy-internal session/lock issue that
older memory suspected but never confirmed.

full technical detail (design, code, three-tier validation) is in
`data/tasks/completed/mcp-server-p7-kimi-dispatch-nonblocking.md` --
this memory captures the reusable lessons, not the implementation.

## related

[[feedback-kimi-dispatch-never-parallel]]
[[feedback-claude-dispatch-summarize-hang]]
[[feedback-coding-context-size-cmd-returned-stale-floor]]

#,,,.,.,,,.,.,...,.,,,,,,,,..,,.,,..,,.,,,..,,..,,...,...,...,,.,,..,,..,,,,,,
#BAAGNMJNZ4VSRF3BAITDP5IBXWBTLXUPLJSDS4YI2KWVGVYPLMJDRXW2X4VWREMDHRPN5WWXHD42W
#\\\|I32O2274LP6V7K4FGFZ5DRBGYV6OCOEZXM7SDB4QYDHNOHOXB6D \ / AMOS7 \ YOURUM ::
#\[7]IMZYNELI4IUBNZ3T57I4QB4VXJPHLOLDRYNNGLPOAKKHOKROU2AQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
