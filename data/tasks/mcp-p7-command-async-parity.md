# p7_command: give the most-used MCP tool the same async parity kimi_dispatch has

not started, investigation write-up only. written 2026-09-20 after two
independent same-day incidents (below). sibling to
[[mcp-claude-dispatch-async-parity]] -- same disease, different organ.

## why this exists

observed live today, twice: a `p7_command` call running
`models.discover :re-scan:` hung well past 120s, and separately a
coding-zenka self-test that legitimately takes several minutes blocked its
tool call for the whole duration. both are expected-to-be-slow cube commands
sent through the single most-used tool in this server.

the mechanism is documented in code already, just for a different call site:
this server is single-threaded [ one blocking `<STDIN>` read loop at
`bin/mcp-server-p7:1172`, no fork/threads for request handling ], so any slow
tool blocks EVERY tool for its duration -- root-caused 2026-09-08 for the
unconditional `qx()` in the external-command handler, whose fix comment
[~4131-4145] explains the kimi fork/detach build. `tool_p7_command`
[~1514] → `cube_command` [~2048] → blocking byte-by-byte `sysread` on the
shared cached `$cube_sock` is the same class of bug one transport down:
not "waiting on a child process" but "waiting on a socket reply".

## what exists to build on

**the kimi async triad** [all in `bin/mcp-server-p7`]: `_kimi_fork_run`
[~4337] forks a per-dispatch capture-file worker, with a 6s bounded
fast-fail window so near-instant completion still returns synchronously;
`_kimi_dispatch_async_reply` [~4465] builds the `status=dispatched_async`
reply [pid, capture path, `bin/dev/notify-pid-gone` nudge]; and
`tool_kimi_check_status` [~4532] recovers the result later with zero
blocking. that shape is the reference, but see the next paragraph -- the
kimi trick does not transplant directly.

**the genuinely different part**: kimi/claude dispatch forks a BRAND-NEW OS
process per call and captures its stdout. `p7_command` sends one line over
an ALREADY-OPEN, LONG-LIVED cube socket and blocks on that same socket for
the reply. you cannot fork-and-detach a send on the shared connection the
same way: a forked child would either inherit the live fd [note the existing
comment at `cube_connect` ~1785-1789 -- subprocesses must NOT inherit the
cube socket, "inherited fds closed by child processes desync the protocol";
FD_CLOEXEC is set exactly for this] or need its own connection.

**request/reply correlation ALREADY EXISTS in the cube protocol** [the key
finding of this investigation, and it halves the design space]:

- `src/base.handler.command:429` strips a leading `(cmd_id)` prefix off the
  incoming command line [id format `\d{2,15}`, `src/base.regex:28`] and
  stores it in the call args.
- `src/base.callback.cmd_reply:37-38` echoes that id back as a `(%d)` prefix
  on EVERY reply line -- TRUE/FALSE/SIZE/CHRSIZE/DATA/TREE, and the mcp
  server's own `drain_strm_stream` already strips `^\( \d+ \)` prefixes off
  STRM frames [~1911, ~1949], so the reader side is prefix-tolerant today.
- an in-network client precedent already does demux on a shared cube session
  socket: `src/base.X-11.get_bg_color` sends `($cmd_id)X-11.bg_color`, then
  loops reading lines, buffering non-matching replies back into the session
  input buffer until its own `^\($cmd_id\)(TRUE|FALSE)` arrives.
- deferred replies are normal server-side [cmd_reply handles TRUE|FALSE|WAIT
  modes], i.e. cube does not serialize reply order per connection.

corollary worth stating plainly: `cube_command` never uses this. it sends
bare commands and reads strictly positionally, which is only safe BECAUSE
the server blocks -- one in flight at a time. any concurrency added without
cmd_id demux [a background drain, a second reader] would corrupt the cached
socket's byte stream; `drain_strm_stream`'s hard invariant ["never a
partial-return with frames left in the cached socket"] exists precisely
because the codebase already got burned by byte-stream desync.

**other load-bearing facts**: `bin/c_src/p7c.c` is NOT a demux precedent --
one command per process, fresh connect/auth per invocation, exits after the
reply -- but it does prove cube tolerates a fresh short-lived connection per
command cheaply [~5-line handshake: banner, `select unix`, `auth`, optional
`select-strm-mode`]. idle-bounded socket helpers already exist in the server
[`sock_readline_timed` / `sock_read_bytes_timed`, ~1689-1722]. chat
notifications do NOT arrive over the cube socket [`check_chat_pending` polls
`data/development/chat` mtimes, ~1434], so a reader loop would see only
genuine command replies, no unsolicited pushes. line numbers here are as of
2026-09-20 and drift versus the sibling doc's.

## sketch of the mirrored shape [three candidates, tradeoffs real]

**A. shared socket + cmd_id demux + persistent reader.** give every
`cube_command` a synthetic `($id)` prefix and add a single owner of
`$cube_sock` that continuously drains it and files replies into a
`%pending` table keyed by id; a new `p7_check_status`-style tool polls the
table. because the main loop is a blocking `<STDIN>` read, the reader is
either a forked child passing demuxed replies to the parent over a pipe
[parent selects on STDIN + pipe], or the main loop gets restructured around
`IO::Select`. most elegant -- one connection, true pipelining, uses the
protocol feature cube already has -- but touches the core dispatch path of
the most critical file, must handle SIZE/STRM payload framing inside the
reader, and needs a defined fallback for any unprefixed/unknowable reply
line [today's answer to stream confusion is `cube_disconnect`; that becomes
more expensive once other calls are in flight].

**B. separate cube connection per async dispatch [closest mirror of
`_kimi_fork_run`].** for a command routed async: fork; the child CLOSES the
inherited `$cube_sock`, does its OWN `cube_connect()` [auth handshake is
cheap, p7c proves it], sends the command, writes the full reply to a
capture file under `data/state`, exits. parent replies `dispatched_async`
with pid + capture path immediately [or keeps kimi's bounded fast-fail
window to return instant errors synchronously]. recovery tool reads the
capture file when the pid is gone, tails it while alive. zero demux needed,
zero changes to the shared-socket protocol handling, and the fork+detach+pid
machinery is already proven in this same file. costs: N concurrent slow
commands = N cube sessions; loses connection reuse; and it leans on cube
being happy with many concurrent sessions for one unix user -- very likely
fine [every p7c invocation does exactly this], but unverified at MCP-server
concurrency levels.

**C. hybrid / opt-in with synchronous grace period.** leave `cube_command`
synchronous for the 99% of calls that answer in well under a second; add an
`async` [and/or `timeout`] param to the `p7_command` schema [~514] routing
through B, plus optionally an automatic short synchronous grace window
[kimi's 6s fast-fail shape at ~4407-4452 applies almost verbatim: "finishes
fast vs runs long" is decided AFTER dispatch there, not before] so a
borderline command still returns inline when it can. smallest behavioral
delta, no risk to fast-path callers; the failure mode shifts to "caller
forgot async and blocked anyway" unless the auto-detach grace period exists.

lean: B or C first -- they mirror the proven kimi shape, keep the shared
socket byte-for-byte untouched, and need no protocol assumptions. A is the
better end state if slow cube commands become routine rather than
exceptional, but it is cube-transport-only work: it does nothing for
claude_dispatch's blocking qx() [a child process, not a socket -- that one
stays with the sibling doc].

## open questions, not yet investigated

- does cube interleave replies to pipelined commands on ONE session freely,
  or is there hidden per-session serialization that would neuter design A?
  [X-11's demux loop assumes interleaving; WAIT-mode deferred replies imply
  it. confirm before building A.]
- do ALL reply paths honor the cmd_id echo when id > 0, including error
  paths that bypass `base.callback.cmd_reply`? drain_strm's prefix-tolerant
  parsing hints at variance somewhere. design A needs a teardown policy for
  an unmatchable line mid-stream.
- is there a per-session or per-user cap on in-flight commands / concurrent
  sessions in cube? relevant to both A [pipelining depth] and B [connection
  count].
- session semantics under B: do any cube commands behave per-SESSION rather
  than per-USER [the chat tools' "current active channel" phrasing suggests
  session state exists; `user.cube.session` is keyed somehow] -- if so, a
  fresh connection per async dispatch may see different defaults than the
  long-lived one. check before B.
- does the MCP server's `auth_user` map to a distinct cube user such that
  its concurrent sessions are clearly attributable in logs?
- completion nudge for A: there is no pid to hand `notify-pid-gone` -- what
  is the A-equivalent cue [reader-written flag file? mtime poll in the check
  tool?] or is polling-only acceptable there.
- interaction with the outer harness's ~1800s idle-silence watchdog [see
  `tool_kimi_check_status` header comment]: what timeout/grace values keep
  an async p7_command reply useful rather than watchdog-failed.

## related

[[mcp-claude-dispatch-async-parity]] -- the sibling doc: claude_dispatch /
claude_continue still block in `tool_external_command`'s qx() branch; same
server-wide blocking disease, child-process transport instead of socket.

the original incident this whole async family was built to fix: the comment
block at `bin/mcp-server-p7` ~4131-4145 [root-caused 2026-09-08], mirrored
by `[[reference-mcp-server-p7-kimi-dispatch-nonblocking]]` in memory under
that or a similar name.

#,,..,.,,,,,.,,..,,,.,..,,,,,,.,.,,,,,.,.,.,.,..,,...,..,,.,,,,,.,,,,,...,.,.,
#FIT2J57H5IXGJIJ3ZAYB24PPB6WMDIFR5HL3A2RE6QBWJQXUKTSIEDFVAGR7SHCFAV66OGGFNC3VE
#\\\|HJGVENXIV2OQY3IXRRRJN2EIBI7LBZ2DKE5NFK7GJTTZLW7TNBM \ / AMOS7 \ YOURUM ::
#\[7]7WCGBYCEEIMQ37EDDY2ERZCAETEF3FTSMKSXETCGTUNSQIKV7UAQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
