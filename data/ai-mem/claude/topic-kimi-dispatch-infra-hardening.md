---
name: topic-kimi-dispatch-infra-hardening
description: "kimi_dispatch/kimi_continue hardening — --afk mode, per-dispatch model routing, wrapper-process lingering pattern"
metadata: 
  node_type: memory
  type: project
  originSessionId: 3c264315-73af-4677-a8b4-23ce085cb5a8
  modified: 2026-07-19T07:47:06.151Z
---

**LANDED 2026-07-17**, three related fixes to `bin/mcp-server-p7`'s kimi
tools, all same session as the agent-detection fix
([[feedback-mcp-memory-update-agent-detection]]).

- **`--afk` flag** (commit `ee656088c`) added to both `kimi_dispatch`/
  `kimi_continue` alongside `-y`. Directly prevents the failure mode that
  burned ~30 min of tokens earlier this session: a dispatched kimi
  session hit an `AskUserQuestion` mid-task with no one able to answer
  it in a non-interactive background dispatch. `-y` only auto-approves
  tool permissions, not interactive content questions — `--afk` is the
  flag that actually covers this. Confirmed live against `kimi-legacy
  --help` before adding, not guessed.
- **Model routing** (commit `940be9206`): `model=k3|k2.7|k2.7-fast` on
  both tools, mirroring `claude_dispatch`'s existing `haiku|sonnet|opus`
  pattern in `tool_external_command`. Real pricing: K3 $15/1M output,
  1,048,576 token context, best reasoning; K2.7-code $4/1M output,
  262,144 context, cheapest; K2.7-code-highspeed $8/1M, faster. K3 is
  pricier than *both* K2.7 variants on output/cache-miss-input, not
  "between" them as first assumed — its premium is concentrated exactly
  where reasoning-heavy tool-calling work generates the most tokens
  (output), so route broad search/verification work to K2.7 and save
  K3 for design/tricky-bug work that needs the bigger context. Internal
  aliases (`kimi-code/k3` etc.) confirmed against `~/.kimi/config.toml`.
  `kimi_continue` had to migrate from the legacy `param_name`/
  `param2_name` format to the `params` array format to fit the third
  param — justified, not scope creep: it also gave `kimi_continue`
  `auto_summarize`/`keep` support it never had (its sibling
  `kimi_dispatch` already had both).
- **Wrapper-process lingering pattern** (observed, not yet fixed): a
  dispatched kimi-legacy session's outer `sh -c kimi-legacy ...` wrapper
  process sometimes doesn't exit even after the underlying work finishes
  and its result is delivered/reported. Seen at least twice — once
  needed a manual `kill`, once ran idle (sleeping, zero CPU) for 4h40m
  after its task (`state-play`/waypoints, commit `f3ff56181`) had long
  since landed. Not investigated further; if it recurs, check
  `ps --ppid <wrapper_pid>` for a still-sleeping child before assuming
  something's actually stuck — idle-but-alive is harmless, just needs
  occasional manual cleanup (`pkill -f kimi`).
- **MCP bridge timeout ≠ dispatch failure**: `kimi_dispatch`/
  `kimi_continue` calls have hit the MCP tool's own ~1800s idle timeout
  multiple times this session while the underlying kimi work kept
  running and completed successfully regardless — check
  `pgrep -af kimi-legacy` and/or `session_catchup(client=kimi)` +
  reading the session's own `wire.jsonl` directly for the real final
  output before assuming a timed-out call means lost work. Session
  files live at `~/.kimi/sessions/<hash>/<session_id>/wire.jsonl`; the
  last `ContentPart` with `type: text` before `TurnEnd` is the actual
  final report — `session_catchup`'s own summarization is itself lossy
  for large results (confirmed: undercounted a 22-vs-20 file list once).

**Recurrence 2026-07-19**: same false-failure pattern hit again on the
`strm-generic-subscribe-wrapper.md` K3 dispatch — `task-notification`
reported `status=failed` after the MCP idle timeout, but
`~/.kimi/logs/kimi.log` showed the work (6 modules, live-verified
against cred-mesh/proxy, self-recorded gotcha note) had already
completed; only the final `write_new_file` for its own memory note got
cut off mid-reply. Disk state (`git status`, `ls modules/`) confirmed
everything landed. Same lesson: check disk/logs before treating a
`failed` task-notification as lost work.

**Recurrence 2026-07-29 (3 for 3 in one session)**: `kcqwm9ylr`
(security-intel dispatch) actually finished clean and committed
(`27b5421ab`); `kfm4ggfbf`/`k41h2bfrf`/`k2u50wvde` (forensics-agent, the
original dispatch + a resume) both hit the same MCP idle-timeout
`status=failed` while `ps aux` + `~/.kimi/logs/kimi.log` timestamps
confirmed the underlying `kimi-legacy` process was still alive and
actively editing files each time, live-verified against real console
output from the running `forensics` zenka as it iterated (auth.zenki
fix, init_code fix, the `File::stat` shadowing bug, an ntime comp-int
decode gap). Same fix each time: check `ps aux | grep kimi` +
`grep <session_id> ~/.kimi/logs/kimi.log | tail` before assuming
`status=failed` means the work stopped — resume via `kimi_continue`
with the same session id only if the process actually isn't running
anymore; otherwise just wait, it's still going.

**Task file written 2026-07-29**: `data/tasks/mcp-kimi-status-check-reattach.md`
proposes a `kimi_check_status(session_id)` MCP tool to formalize today's
manual recovery workaround (ps aux + log-tail + kimi_continue/kimi -r)
into a real tool, since the 1800s cutoff is confirmed to be the outer
Claude Code harness's own idle-silence watchdog
(`CLAUDE_CODE_MCP_TOOL_IDLE_TIMEOUT`), not anything in `bin/mcp-server-p7`
(which already declares `timeout => 4620`, 77 min, for both
kimi_dispatch and kimi_continue). Not yet dispatched.

**2026-08-05, mechanism confirmed (corrected twice, this is the settled
version)**: `p7c coding.show-buffer T-<task_id>-F` returning text matching
`session_catchup`'s kimi-session output is real and IS a valid recovery
technique — but not because the `coding` zenka natively tracks/manages kimi
tasks (it doesn't; a separate `models` zenka is the one that knows about
kimi, unused this session). The actual mechanism: **`bin/mcp-server-p7`
itself — the bridge process implementing `kimi_dispatch`/`kimi_continue`/
`session_catchup` — writes/mirrors each dispatch's final summary into the
`coding` zenka's buffer system as a side effect of running the dispatch**,
independent of whether `coding` itself has any involvement in the actual
kimi work. So `p7c coding.list buffers` → `p7c coding.show-buffer T-<id>-F`
is a legitimate, fast alternative to `session_catchup(client=kimi)` (list) →
`session_catchup(session_id=...)` (summarize) for recovering a dispatch's
result — same underlying data, different retrieval path, both real.

Also confirmed real: `kimi_dispatch` hits genuine `kimi.com` hosted-API
billing (a live HTTP 403 "Usage limit reached for this billing cycle ...
purchase extra usage or upgrade plan" was seen) — it is not free local
compute, regardless of which path recovers its output.

**Better recovery technique than session_catchup alone**: `p7c coding.list
buffers` shows per-task buffers named `T-<task_id>` (raw)/`T-<task_id>-T`
(thinking)/`T-<task_id>-F` (final) — `p7c coding.show-buffer T-<id>-F` pulls
a task's final report directly, often faster to correlate than matching
`session_catchup`'s kimi-session list by title/timestamp guesswork. Still
subject to the same narrative-compression issue as `session_catchup`
(neither reliably returns an exhaustive itemized list when a session's own
final answer was already prose-with-examples — asking either tool to "not
summarize" doesn't recover detail that was never written out in the first
place; a fresh dispatch told to write its result directly to a file on disk,
one row per item, forces completeness far better than asking for a chat-style
report after the fact).

**LANDED 2026-08-09** (commit `6686041a9`): `kimi_check_status(session_id,
lines?)` shipped in `bin/mcp-server-p7`, closing out the 2026-07-29 task file
above. Dispatched to kimi (model `k3-256k`) for implementation, then two real
bugs were caught in human+Claude review before commit — worth the extra pass:

1. **Lingering-wrapper false positive** (the exact pattern documented above,
   observed 2026-07-17): the first draft's liveness check trusted bare
   process existence (`ps` argv match on the session_id) with no
   corroboration, so a lingering idle wrapper would report `status=running`
   forever even though the session had actually finished hours earlier.
   Fixed by adding a unified freshness gate both liveness branches funnel
   through: `wire.jsonl` mtime freshness (<180s) OR a trailing `TurnEnd`
   event demotes a process match to `status=completed` (with a
   `note=stale_wrapper_process_ignored` marker), rather than trusting the
   process alone.
2. **Silent decode failure on non-ASCII completed-session results**: `$json`
   in this file is `JSON->new->utf8->canonical` (line ~303) — `->utf8` mode
   means `decode()` expects **raw UTF-8 bytes**, not an already-decoded Perl
   string. Every other `$json->decode()` call in the file reads its source
   via a `<:raw` filehandle first to get bytes; the new code instead read its
   JSON line via `qx($grep_cmd)`, and because the whole script runs under
   `perl -C31` (UTF-8 on all I/O layers, including new pipes from `qx`), that
   string comes back already decoded. Feeding it to `$json->decode()` threw
   `"Wide character in subroutine entry"`, caught silently by the wrapping
   `eval`, so `status=completed` recovery silently returned "no final
   assistant text found" for any real (near-universally non-ASCII, e.g. em
   dashes) response — i.e. it was broken for almost every actual use.
   Fix: `encode('UTF-8', $last_text_line)` before `decode()`. **Lesson for
   this file specifically**: any new code that pipes `qx()` output into
   `$json->decode()` needs that same re-encode step first — the `<:raw`-read
   convention isn't just style, `->utf8` mode requires it.

Both bugs were found by testing the actual tool end-to-end after dispatch
(live stdio JSON-RPC smoke tests, plus a synthetic `exec -a 'kimi-legacy...'`
process to simulate the lingering-wrapper case) rather than trusting the
dispatch's own "tested, verified" self-report at face value — the second bug
in particular only showed up once a completed session with real prose
(non-ASCII punctuation) was checked; the initial verification pass had only
exercised sessions/synthetic text that happened to be pure ASCII.

## related

[[feedback-mcp-memory-update-agent-detection]] ·
[[feedback-kimi-dispatch-pattern]] ·
[[feedback-tasks-completed-scan-verdict-trust]]

#,,.,,,.,,,,,,..,,..,,.,.,..,,,,.,,.,,,.,,,..,..,,...,...,,,.,..,,.,,,,.,,,,,,
#5KQD54ZUBAYBUO5WG42DCG6G63EBKMUIMR4MRPSNVL7URY2I2RPJO3KC53TJFRBLSB5K4CGI6MZFG
#\\\|3QLBPC2DFLX3PQWV2L3KPLAPE7O6LYMPZNEHRKX25Q3KFQDCAJM \ / AMOS7 \ YOURUM ::
#\[7]SLBIZSUKWBU6JRFP6EKTFNJ7FP4QGVD7LX64SVZ3KDCIMFQBHGAY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
