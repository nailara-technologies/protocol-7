## [:< ##

# name  = task: make kimi_dispatch/kimi_continue non-blocking in mcp-server-p7
# descr = the single-threaded MCP server blocks its whole request loop for
#         the full duration of a kimi run, so check_status (and every
#         other tool call) queues behind it instead of running

## context

found 2026-09-08 debugging why `kimi_check_status` -- documented as "returns
within seconds" -- hung for the full ~1800s outer-harness idle timeout,
twice, on a real, genuinely-running kimi session. root-caused by reading
`bin/mcp-server-p7` directly, not assumed:

- the whole server is a single `while ( my $line = <STDIN> )` loop
  (confirmed: `grep -n 'while.*STDIN' bin/mcp-server-p7` -> one hit, the
  main loop). there is already a comment in this exact file, at a
  different call site, documenting this as a known, deliberate tradeoff:
  "this whole server is single-threaded [ one blocking STDIN read loop, no
  fork/threads for request handling ], a stuck summarize here blocked
  every other MCP tool call indefinitely, not just this one."
- `kimi_dispatch` and `kimi_continue` both route through the generic
  `tool_external_command` (shared with `claude_dispatch`, `claude_continue`,
  `coding_summarize` -- see the `@external_tools` array and its
  `'name' => 'kimi_dispatch'` / etc entries near the top of the file for
  each tool's configured `timeout`).
- `tool_external_command`'s actual execution, unconditionally, for every
  tool sharing this path: `$output = qx($cmd 2>/dev/null);` wrapped in
  `alarm($ext->{'timeout'} // 120)`. for `kimi_dispatch`/`kimi_continue`
  this alarm is 4620s (77 minutes). that `qx()` call blocks the ENTIRE
  server process -- the same one `kimi_check_status` and every other tool
  call also needs -- for as long as the kimi CLI subprocess runs.
- `kimi_check_status`'s own handler (`tool_kimi_check_status`) is NOT part
  of this blocking path -- it has its own dedicated, fast, non-blocking
  implementation (a few `ps`/`tail`/`grep` shellouts). it was never the
  slow part. it just could never get a turn to run while the server was
  still stuck inside an earlier dispatch's `qx()` call.
- practical timeline that exposed this, same day: dispatched a long kimi
  task -> outer harness reported it "failed" after ~1800s idle (expected,
  documented behavior, the underlying kimi process was still genuinely
  running) -> called `kimi_check_status` to check -> it ALSO hung the
  full ~1800s and was aborted, even though `ps`/`tail` done by hand at
  that exact moment confirmed the session was alive and actively working.
  had to fall back to polling `ps -p <pid>` and `tail ~/.kimi/logs/
  kimi.log` directly for the rest of that session, defeating the entire
  purpose of `kimi_check_status` existing.

## why kimi specifically (scope decision)

`claude_dispatch`/`claude_continue` share the exact same blocking `qx()`
architecture and have the exact same theoretical problem -- but unlike
kimi, there is no `claude_check_status` equivalent tool in this file
(confirmed: `grep -n \"'name'\" bin/mcp-server-p7` lists no such entry).
if `claude_dispatch` were changed to return early with "still running,"
there would be NO way for a caller to ever retrieve that dispatch's real
result afterward -- a genuine regression, not a fix. **this task is
scoped to `kimi_dispatch` and `kimi_continue` only**, because `kimi_check_
status` already exists and can recover a completed session's final result
from `~/.kimi/sessions/*/<uuid>/wire.jsonl` regardless of how the dispatch
call itself returned. extending the same pattern to claude would need a
`claude_check_status` built first -- flag it, don't build it, in this task.

## existing precedent to follow, not invent something new

`_dispatch_followup` (same file, search for that sub name) already forks
and detaches a background kimi-legacy process for a different purpose
(an internal auto-followup dispatch), and is the established idiom for
"run kimi-legacy without blocking this server":
- `local $SIG{'CHLD'} = 'IGNORE';` before fork, so the child auto-reaps
  without the parent needing to waitpid it.
- child redirects `STDIN` from `/dev/null`, `STDOUT`/`STDERR` to a log
  file, then `exec(...)`s straight into `kimi-legacy` -- never returns to
  perl code in the child, no shared state to worry about between parent
  and child after the fork point.
- parent logs the pid and returns immediately.

follow this same shape for the real fix, adapted to preserve
`kimi_dispatch`/`kimi_continue`'s existing request/response contract as
much as possible (see design below) rather than copying `_dispatch_
followup` verbatim, since that helper's caller never needed the actual
kimi output back at all -- `kimi_dispatch`/`kimi_continue`'s callers do.

## design

replace the unconditional blocking `qx($cmd)` in `tool_external_command`,
for `$ext->{'name'} =~ m{^kimi_(dispatch|continue)$}` only (every other
`@external_tools` entry keeps today's exact blocking behavior --
`claude_dispatch`, `claude_continue`, `coding_summarize` are explicitly
out of scope per the section above), with:

1. fork immediately (`local $SIG{'CHLD'} = 'IGNORE'` first, matching the
   precedent).
2. in the child: redirect `STDIN` from `/dev/null`; redirect `STDOUT`
   and `STDERR` to a per-dispatch temp file (not the shared log file
   `_dispatch_followup` uses -- this one needs its OWN captured output
   read back, not just a log trail) under something like `$ROOT_PATH/
   data/state/kimi-dispatch-<pid>.out`; then `exec` the actual built
   `$cmd` (the same command string already constructed earlier in this
   function -- do not rebuild it, reuse it exactly as today's code
   builds it, only change how it gets RUN).
3. in the parent, immediately after fork (no `alarm`, no blocking `qx`):
   a short bounded wait loop -- non-blocking `waitpid($pid, WNOHANG)` in
   a loop with brief `select(undef,undef,undef,0.2)` sleeps, capped at
   roughly 5-8 seconds total. this exists ONLY to let a near-instant
   failure (bad model alias already logged elsewhere, missing required
   param already checked earlier in this same function before this
   point, kimi-legacy failing to even start) return synchronously with
   its real error instead of always claiming "dispatched" even for an
   immediate, obvious failure. it is NOT meant to catch normal dispatch
   completion -- every real kimi run in this session took minutes, this
   cap should almost always be exceeded.
4. if the child exits within that short cap: read back the temp output
   file, feed it through the EXACT same post-processing this function
   already does today for a synchronous result (claude session-id
   extraction -- not applicable here since this branch is kimi-only,
   auto_summarize handling, etc.) and `send_tool_result` it, same as
   today. clean up the temp file.
5. if the child has NOT exited within the cap: do NOT wait further.
   return immediately via `send_tool_result` with a message making the
   new session's resumability discoverable right away -- specifically,
   this needs the session uuid. that uuid is generated by `kimi-legacy`
   itself at runtime for a fresh `kimi_dispatch` (not known before
   exec), so it cannot be embedded in the immediate reply the same way
   the synchronous path could. options, pick based on what's actually
   findable without guessing:
   - simplest, matches how this session itself recovered the uuid by
     hand: have the immediate reply say the child pid and point at the
     per-dispatch temp output file path, and separately point out that
     `kimi_check_status` needs a session uuid, which can be recovered
     from `~/.kimi/logs/kimi.log` by grepping for the fresh log lines
     that appear once `kimi-legacy` actually starts (this session did
     exactly this: `ps aux | grep kimi-legacy` for the pid, matched
     against fresh `kimi.log` entries for the uuid). document this
     recovery path in the tool's own reply text so a caller doesn't have
     to rediscover it by hand again.
   - better if achievable without much extra work: check whether
     `kimi-legacy -y --afk -p ... --model ...` (or a variant flag) can be
     told to print its own session uuid to a known location BEFORE
     starting real work, or whether `~/.kimi/sessions/<hash>/` gets a new
     directory the instant the session is created (even before the CLI's
     own first real log line) that a short post-fork `find -newer` scan
     in the parent (still within the same short bounded-wait window from
     step 3) could pick up reliably. try this first; fall back to the
     simpler pid+log-grep approach above if it's not reliably available
     that early.
   - for `kimi_continue` specifically, the session uuid is already known
     (it's a required input param to the tool call) -- the "how does the
     caller find the uuid" problem above only applies to a fresh `kimi_
     dispatch`, not `kimi_continue`. make sure the immediate-return
     message for `kimi_continue` just echoes the already-known uuid back,
     simpler than the dispatch case.
6. `auto_summarize` handling (the block that runs a completed dispatch's
   raw output through a local summarizer) only makes sense for the
   synchronous/fast-completion branch (step 4) -- it needs the real
   output in hand. for the async branch (step 5) there is nothing to
   summarize yet; do not attempt it there, and do not silently drop the
   caller's `auto_summarize`/`keep`/`template` params either -- if this
   turns out to matter for a later `kimi_check_status`-driven recovery
   flow, note it as a follow-up rather than half-implementing it now.

## what NOT to do

- do not touch `claude_dispatch`, `claude_continue`, or `coding_summarize`
  -- explicitly out of scope, see the scope-decision section above.
- do not remove or weaken `kimi_check_status`'s own existing logic -- it
  was never the broken part, confirmed by reading it directly. it should
  keep working exactly as it does today; this task's fix is what actually
  lets it get a chance to run promptly.
- do not attempt to make the whole server generically concurrent (a real
  event loop, threads, etc.) -- that is a much larger change with its own
  risks across every other tool in this file, not needed to fix the
  specific, scoped problem here.
- do not add any placeholder AMOS7 signature footer to new or edited
  files -- a human signs files separately via `bin/Protocol-7 sourcecode
  update-signatures` before commit.

## validation

- a normal, fast `kimi_dispatch` call (something trivially quick, or a
  deliberately-invalid one to test the short-cap synchronous-failure
  path) still returns its real result/error directly, same as today --
  confirm the short-cap path isn't accidentally always taken or never
  taken.
- a genuinely long-running `kimi_dispatch` (minutes, not seconds) returns
  an immediate "dispatched" reply well under the cap, WITHOUT waiting for
  the actual kimi run to finish.
- **the actual bug this task exists to fix, demonstrated concretely**:
  while that long-running dispatch is still genuinely in progress
  (confirm via direct `ps`/log inspection, not by trusting the tool's own
  claims), issue a SEPARATE, unrelated MCP tool call (eg `kimi_check_
  status` on the new session, or any other quick tool entirely) and
  confirm it returns promptly -- proving the server is no longer blocked
  by the in-flight dispatch. this is the one check that actually proves
  the fix; everything else above is regression-checking the existing
  contract.
- `kimi_continue` tested the same way, using a session id from a prior
  dispatch.
- confirm the short bounded-wait cap value chosen is stated explicitly
  in a comment (matching this file's existing commenting style right
  next to the `alarm(...)` calls elsewhere in the same function), so a
  future reader doesn't have to re-derive why that specific number was
  picked.

## results [ 2026-09-08, implemented by kimi, reviewed by claude ]

**scope respected exactly**: only `bin/mcp-server-p7` touched (267+/35-),
`claude_dispatch`/`claude_continue`/`coding_summarize` byte-identical in
the unchanged `else` branch, `kimi_check_status` untouched.

**one real improvement over this file's own suggested design**: used a
double-fork (intermediate child reaped immediately, worker orphaned to
init) instead of the `_dispatch_followup` precedent's `local $SIG{'CHLD'}
= 'IGNORE'`. correctly identified that a `local`'d IGNORE only auto-reaps
while still in effect -- since this function returns almost immediately
after forking, the local would already be restored by the time the real
worker exits minutes later, leaking a zombie per dispatch; a *permanent*
IGNORE would instead break `qx()`/`system()` exit-status handling
elsewhere in this same server. double-fork avoids both failure modes with
no SIGCHLD disposition changes at all.

**step 5 (session uuid recovery) -- the better option worked, no fallback
needed**: measured live that `~/.kimi/sessions/<hash>/<uuid>/` appears
~1.1s after a fresh dispatch starts, well inside the 6s bounded window and
long before the first real stdout line (~16.6s observed). the parent
snapshots existing session dirs pre-fork and diffs during the wait window
-- the uuid is recovered directly, no log-grepping needed in the normal
case. the pid+log-grep fallback this file described is preserved only as
reply text for the rare ambiguous case (a concurrent unrelated dispatch
creating a session in the same window).

**validated three ways, all before touching the live server**:
1. `perl -C31 -c` clean, zero new warnings vs pre-edit baseline.
2. a standalone mechanism test (13/13 passing) exercising fork/exec/
   readback/uuid-recovery/zombie-count in isolation.
3. **the actual bug demonstrated fixed**, on a separate throwaway
   `mcp-server-p7` instance (not either of the two live ones) driven over
   real stdio JSON-RPC: a genuinely long-running `kimi_dispatch` returned
   `status=dispatched_async` at ~6s with the correct uuid; mid-run,
   `kimi_check_status` replied in 0.02s and `tools/list` in 0.00s --
   previously both would have queued behind the dispatch for its entire
   duration. fast-completion and fast-failure paths both confirmed to
   still return synchronously with real output (the sync branch is
   neither always- nor never-taken). `kimi_continue`'s simpler
   known-uuid path also confirmed.

**left for a human, correctly not done automatically**:
- two live `mcp-server-p7` processes found (pids 1170555, 1268138) still
  running the old blocking code -- neither touched or restarted. restart
  needed to pick up the fix, at whatever moment is convenient (a restart
  drops the active MCP connection briefly).
- file needs re-signing (`bin/Protocol-7 sourcecode update-signatures`)
  before commit -- the edit invalidated the existing signature.
- minor, deliberately out of scope: async dispatches leave their
  `.out`/`.pid` capture files in `data/state/` with no rotation/cleanup
  added, to keep the fix itself minimal.

**not done, per explicit scope**: `claude_dispatch`/`claude_continue`
still block the same way they always did -- no `claude_check_status`
equivalent exists to recover a result if they returned early, so
extending this same fix to them would need that built first. tracked
here as a known follow-up, not attempted.

#,,,,,.,,,..,,,.,,...,...,,,.,..,,,.,,.,.,,..,..,,...,...,,,,,...,,,.,,,,,.,.,
#HMBO7AZURRX3JKBLBOD6FYCXG7YBSQIRY4IEMYAADIBNUTZVGDA6ULAVBQOSMFPLUW7Q7SYH36SB4
#\\\|D7Y3TK5LI5TRY4DYSVNKEUABUJMNJPRNDRX4WWISB2VBPO5UNFO \ / AMOS7 \ YOURUM ::
#\[7]WANQRSN2F2DFR2YKUCE3UJOIGW6GESVUQI4XGXUQGWRNOHW6MKDI 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
