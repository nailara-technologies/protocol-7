---
name: kimi zenka state machine upgrade
description: COMPLETE — watcher-based state machine implemented, reconnect fix applied
type: project
originSessionId: 327ba945-ac12-456a-985f-690320d1550f
---
## completed (2026-05-14, session 23)

kimi zenka upgraded to `<[event.add_var]>` variable watcher state machine. task
multiplexing foundation laid. full round-trip verified: `p7c kimi.ask-reply` → "Four".

**what was built:**
- `kimi.watcher.ws_status` — Event.pm variable watcher (`repeat=>TRUE, poll=>'w'`) on
  `<kimi.ws.status>`, drives all lifecycle transitions (disconnected/connecting/ready/busy)
- `kimi.handler.dispatch_next_task` — dispatches next pending task when ws is ready
- `kimi.cmd.status` — shows ws status, task queue, active task, pending approvals
- task queue: pending/active/completed/failed arrays with `kimi.task.active_id`

**reconnect stuck bug fixed:**
- root cause: watcher doesn't fire when value written is same as current value
- symptom: `ws.status` already `disconnected`, written again → watcher silent → no retry
- fix: in `kimi.handler.ws_message` and `kimi.handler.session_liveness_timeout`,
  call `<[kimi.connect.schedule_retry]>` directly after writing `disconnected`,
  not relying solely on the watcher

## open items (session 24 — all prior items closed)

- `flush_on_acquisition` extracted to `kimi.flush_on_acquisition` (session 24);
  fixed hashref vs arrayref bug in original; redefined warning eliminated
- sudo auto-decline added to `kimi.handler.approval_request` — rejects with message,
  checks `$description` and `$action` fields; `kimi.wire.approval_respond` accepts
  optional decline reason message parameter
- task multiplexing: currently max_concurrent=1; design ready for N when needed

## correction, 2026-08-04 — the arrayref/hashref fix above did not survive

Live-read `modules/kimi.flush_on_acquisition` this session: line 17 is
`<kimi.approval.pending> = [];` — an **arrayref** reset, while every other
use of `<kimi.approval.pending>` (`kimi.handler.approval_request:34`, and
this same file's own `keys %{$href_pending}` at line 7) treats it as a
**hashref**. Whatever fixed this in session 24 either regressed later or
the "fixed" note above described a different pass than what's live now —
not re-investigated here, just flagged as contradicted by current code,
not silently trusted. Also found, separately: `kimi.flush_on_acquisition`
is never actually *called* anywhere in `modules/` outside its own
self-listing in `base.list.subroutines` — the reconnect branch of
`kimi.handler.ws_message` (~line 279-281) should call it and doesn't,
which is the likely root cause of
[[project-auto-summarize-cost-investigation]]'s "approval-request
disassociates on reconnect" bug. K3 dispatch in flight to verify+fix:
task id `k8usgy2y0`, task file `data/tasks/kimi-zenka-approval-reconnect-
disassociation-fix.md`.

**User's follow-on idea, same thread**: `kimi-web` (the backend process
`kimi` zenka connects to) is currently started manually; the *separate*
`kimi-web.*` zenka-management modules (`kimi-web.cmd.spawn_agent`,
`kimi-web.bridge.ensure_local_agent`) are new and not yet confirmed
production-ready. If/when that management layer works cleanly, the `kimi`
zenka could trigger it to start the backend on-demand instead of relying
on a manual pre-start — a further-out roadmap item, not part of the
current dispatch's scope (that dispatch was explicitly told not to touch
`kimi-web.*`).

## second bug found live-testing the first fix, 2026-08-04 — approval-respond TOCTOU race

The `flush_on_acquisition` fix (`k8usgy2y0`, deployed + zenka restarted,
confirmed live via `data/tasks/kimi-zenka-approval-reconnect-
disassociation-fix.md`) covers *pending* (never-yet-decided) approvals
surviving reconnect. Live testing (real natural reconnects observed —
`kimi.handler.ws_message: websocket disconnected` on the order of
seconds during normal operation, not hypothetical) surfaced a **second,
deeper bug** the user correctly predicted might exist ("none of the many
fixes so far truly solved the problem, only made it slightly less often
occurring"): `modules/kimi.wire.approval_respond` marks
`<kimi.approval.responded>->{$request_id} = 1` and persists it to disk
*before* confirming the actual `websocket.send` succeeded (lines 42-49).
If the connection drops between the line-13 connectivity check and the
line-49 send, the zenka believes the approval was delivered when it
wasn't — and `kimi.handler.approval_request`'s dedup check then silently
swallows kimi-web's legitimate re-send of that same request forever, no
error logged above level 2. **This reproduces with `auto_approve` at its
normal default (on)** — not just in a manual-approval-pending scenario —
which is why the symptom kept recurring despite prior fixes: the
auto-approve *decision* was always fine, it's the *delivery* of that
decision that could silently fail while being marked as succeeded.
**Fixed, live-verified, staged 2026-08-04** (task id `k0sawgih1`, task
file `data/tasks/kimi-zenka-approval-respond-toctou-race-fix.md`).
`modules/kimi.wire.approval_respond` now sends first, marks+persists
`responded` only after a confirmed send (`defined $sent and $sent > 0`,
where `$sent` is `websocket.send`'s return — byte count on success,
undef on syswrite error). **K3 also found and fixed a second instance of
the identical bug**, not in the original task scope: `modules/
kimi.connect`'s reconnect-flush loop pre-marked `responded` before
calling `approval_respond` (redundant even before the fix, since
`approval_respond` already marks it) — now only deletes from `pending`
when the respond call actually succeeds, so a failed flush retries on
the next reconnect instead of being silently lost.

Live-verified via `devmod.cmd.eval-code` after `kimi.reload source`,
with `auto_approve` left ON (the user was explicit this reproduces even
in the normal/default state, unlike the manual-pending scenario) — three
paths, all against the real running zenka:
- success: real send (121 bytes) → marked + persisted to disk
- failure: **discovered the kimi zenka runs with `$SIG{PIPE}` at
  DEFAULT** — a genuine in-process dead-socket write test would kill
  the zenka, so it used a safer injection instead (temporarily swap
  `<kimi.ws.socket>` for a read-only filehandle; `syswrite` → EBADF →
  undef, no signal) → confirmed not marked, not persisted
- dedup: re-injected a genuinely-responded id, confirmed still suppressed

Logged the `$SIG{PIPE}`-DEFAULT danger + the safe read-only-filehandle
injection technique to `data/ai-mem/kimi/coding-style.md` ("live-
verifying send failure paths" section) — reusable for testing any other
send-path failure mode in this zenka without risking a crash.

**Cross-referenced 2026-08-04**: this bug/fix pair is a live, unprompted
instance of [[categorical-compartmentalization]]'s "prior cannot be
destabilized until next is verified" anti-crash rule
(`data/yaml/reasoning-templates/categorical-compartmentalization.yaml`)
— `prior` (the approval marked `responded`) was committed before `next`
(the confirmed send) actually verified, exactly the failure mode that
template describes in the abstract. Nobody was referencing that doc
while fixing this; the convergence is worth keeping on record as a real
design-to-implementation correspondence, not a numerological one.

Staged, not committed, syntax-checked (`bin/dev/ptd -c`), signature
footers left stale for user re-signing per house convention.

## model-awareness gap — closed, 2026-08-04

**Was**: `modules/kimi.*` had zero model concept at all. **Now fixed and
committed** (`f332c2e41`, K3 dispatch `kcbdrrlm1`): verified live against
`kimi-web`'s own `GET/PATCH /api/config/` REST API (real model keys —
`kimi-code/kimi-for-coding` = k2.7, `-highspeed` = k2.7-fast, `kimi-code/
k3`, `kimi-code/k3-256k`; global to the process, not per-session) before
writing anything. Added `kimi.cmd.list-models` / `kimi.cmd.set-model
<name> [-restart [-force]]`, both live-verified end to end including a
direct curl cross-check. See
[[project-kimi-k2.7-vs-k3-tier-economics]] for the real API-key mapping
and [[reference-kimi-k3-256k-model]] for the model variants themselves.

## third gap found live-testing the first two fixes — QuestionRequest silently dropped

**Not a regression** of either fix above — both were confirmed working
correctly in this same real dispatch (two genuine `ApprovalRequest`s
round-tripped cleanly, including across a natural reconnect). This is a
third, separate, never-implemented code path producing the same
user-visible symptom (silent hang, forced manual kimi-web-UI
intervention). `modules/kimi.handler.ws_message`'s `QuestionRequest`
branch (lines 237-243) logs a bare message-id and returns — no response
sent to kimi-web at all, unlike the adjacent `ToolCallRequest` branch
(lines 222-235, same file) which is *also* unimplemented but explicitly
sends a `reject` so kimi-web doesn't hang.

**Live-reproduced**: dispatching a real task
(`data/yaml/coding-tasks/amos-term-interaction-plugin.yaml`) triggered a
`QuestionRequest` for an MCP tool-call confirmation (one of the `p7_*`
tools from `bin/mcp-server-p7`) — logged as `question request [ ... ] :
not handled` twice (once before a reconnect, again identically after),
stuck until the user manually answered via kimi-web's UI directly.

K3 dispatch in flight: task id `ktbi8za15`, task file
`data/tasks/kimi-zenka-question-request-silent-hang-fix.md`. Scope is
deliberately minimal — stop the silent hang (send an explicit
decline/reject, matching `ToolCallRequest`'s pattern, after dumping the
real payload live to confirm the reply shape), not full interactive
question-answering (that's the much larger, already-designed
[[topic-next-steps]]-adjacent fallback-chain/interaction-surfaces thread,
`db8e3cbba`, `data/md/design/CODING-ZENKA-USER-INTERACTION-SURFACES.md`).

#,,,,,,,,,,.,,..,,,.,,..,,.,,,,,,,,,,,...,,,,,..,,...,...,,,.,..,,.,,,,.,,..,,
#4LOWBIWZXIMCZGHZEL37XFRJOSQ3CALF2GRAQ3HX2YJUQ4R6P27VEU2WEK4GQ62JJDU3I3V5DIELG
#\\\|G6M5EL465VITIHTAGQTONIGEPLZ6VYVPBIKKNBK3XTG2XP5ZA7R \ / AMOS7 \ YOURUM ::
#\[7]Q3SZLYN6MYSVOVK5UHKACUIPRH5T6ZKHJYMICI4GNT62K76TEWAI 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
