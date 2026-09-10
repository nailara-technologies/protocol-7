# claude_dispatch / claude_continue: give them the same async parity kimi has

not started, not scoped in detail. written up 2026-09-10 to keep context free
for the catalog-retrieval embedding work in progress
([[coding-catalog-retrieval-phase2]]) rather than building this alongside it.

## why this exists

found while fixing a real awareness gap: a `kimi_dispatch`/`kimi_continue`
call returns almost immediately with `status=dispatched_async`, a pid, and
a session uuid, while the actual kimi-legacy process keeps running detached
in the background. nothing was proactively watching that pid, so completion
was only noticed when the user checked manually. fixed by adding a
`bin/dev/notify-pid-gone <pid> &` reminder directly into the async-dispatch
reply text in `bin/mcp-server-p7` (`_kimi_dispatch_async_reply`,
~line 4159), so the nudge fires every time regardless of whether the
model-side "never trust status=completed without an independent check"
rule gets recalled in the moment.

asked whether the same fix applies to `claude_dispatch`/`claude_continue` --
it does not, but for a reason worth fixing rather than accepting: those two
run through the **blocking** branch of the shared handler
(`tool_external_command`, `bin/mcp-server-p7:3706`), not the detached-fork
path. the code has a comment at ~3808-3822 explaining why returning early
would be unsafe for claude_* today: kimi has `kimi_check_status` to recover
a result later from `~/.kimi/sessions/*/wire.jsonl`; **there is no
`claude_check_status`**, so nothing could ever retrieve the result of an
early-returned claude dispatch. the comment reads as a deliberate permanent
design choice ("would be a regression... deliberately") but per the user:
it's forgotten/unfinished parity work, not an intentional difference --
the async treatment was built for kimi and never carried over.

## what exists to build on

`claude_dispatch`'s actual command (`bin/mcp-server-p7:227-227`):

```
claude -p %s --dangerously-skip-permissions --output-format stream-json \
    --model %s --max-budget-usd %s
```

`--output-format stream-json` is a real, capturable, line-by-line
transcript -- the same shape of problem kimi's `wire.jsonl` already solves,
just a different JSON schema. `claude -r <uuid>` already exists for
resuming (used by `claude_continue`, `bin/mcp-server-p7:262`), mirroring
kimi's `-r <uuid>`. so the primitives needed already exist; this is a
symmetric build, not new design space.

## sketch of the mirrored shape

reference implementation to mirror, all in `bin/mcp-server-p7`:

- `_kimi_fork_run` (line 4015) -- forks the command, redirects stdio to a
  capture file, returns immediately if the process is still running past
  a bounded window (vs. near-instant completion, which is fed through the
  normal synchronous path unchanged).
- `_kimi_dispatch_async_reply` (line 4143) -- builds the
  `status=dispatched_async` reply text (pid, session uuid, capture-file
  path, the `notify-pid-gone` reminder just added, the resume-line
  instructions).
- `tool_kimi_check_status` (line 4210) -- recovers the final result later
  by reading the session's `wire.jsonl` back off disk; must return fast,
  no blocking waits.

for claude: same three-part shape, but the recovery step
(`claude_check_status`, new tool) needs to parse `stream-json`'s event
format instead of kimi's `wire.jsonl` -- an open question is exactly what
"final result" extraction looks like from that stream (which event type
marks completion, how to get the assistant's final text out of it) and
whether a still-running vs. finished check has an equivalent to how kimi's
session-directory presence is checked today.

## open questions, not yet investigated

- does forking+backgrounding a nested `claude -p` process (a Claude Code
  CLI instance dispatched from inside an MCP server that is itself a tool
  a Claude Code session is calling) have any session-locking or resource
  conflict this repo hasn't hit with kimi's simpler CLI wrapper?
- `--max-budget-usd` and the 2400s timeout are currently enforced by the
  *blocking* qx() path's own timeout handling -- confirm how/whether that
  carries over cleanly to a forked-and-detached version.
- should `claude_check_status` be a genuinely new tool, or could
  `kimi_check_status` generalize to take a `kind` param and dispatch to the
  right parser internally? lean toward a separate tool first (kimi's is
  already kimi-specific by name and by parsing logic) and only unify later
  if a third async family shows up -- avoid the premature-abstraction
  pattern this session has been deliberately avoiding elsewhere.

## related

[[reference-mcp-server-p7-kimi-dispatch-nonblocking]] (memory, if it exists
under that or a similar name -- the original kimi-side blocking-server
incident this whole async path was built to fix, 2026-09-08 per the comment
at bin/mcp-server-p7:3808)

#,,.,,,..,,.,,,.,,..,,...,.,,,,.,,..,,.,,,,,,,..,,...,...,...,.,,,...,..,,..,,
#HQFY37HY2K6L26FLDHLIS7LECVFUTVJBM4HT4EWGSRH5QETROEXPCU4FHH753CVP55J55N5AFFG3E
#\\\|6G2C4FXITCEWIBQASNLABPEMP4GT4VMJFSTM4QS6W7TZMEDHEJU \ / AMOS7 \ YOURUM ::
#\[7]W2RWALYLAN6LT2REXMQAG6RJP73PJZOJRFLGFGW4ESXXBF4WXKCI 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
