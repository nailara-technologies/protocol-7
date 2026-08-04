## [:< ##

# name  = task: kimi zenka — approval-request disassociates from backend reconnect
# descr = pending tool-approval requests are lost/orphaned across a kimi-web
#         websocket reconnect; caller hangs until a human manually approves
#         via the kimi-web UI. root cause found, needs verification + fix.

## context — read first

`kimi` is a P7 zenka (`modules/kimi.*`) that connects as a client to a
**manually-started, external `kimi-web` process** over websocket — NOT the
separate `modules/kimi-web.*` zenka-management modules (`kimi-web.cmd.
spawn_agent`, `kimi-web.bridge.ensure_local_agent`, etc.), which are new,
unrelated, and not yet confirmed to replace the manual-start workflow.
**Do not touch or assume anything about `kimi-web.*` in this task** — scope
is strictly the `kimi.*` zenka's own reconnect/approval handling as a
client of an already-running kimi-web backend.

**User-reported symptom**: when kimi-web's interval-based backend
reconnect happens at the same time as (or shortly before) a tool-approval
request, the approval state disassociates from the session — the
dispatched task just hangs, and the user has to manually open the kimi-web
UI to nudge/approve it before the zenka-side caller unblocks. Distinct
from [[feedback-kimi-dispatch-idle-timeout-recovery]] (that's the separate
MCP-bridge `kimi_dispatch`/`kimi-legacy` CLI path spawned by
`bin/mcp-server-p7` — this bug is in the `kimi` P7 zenka itself, a
different code path entirely). Also distinct from the unrelated `--afk`
flag on `kimi_dispatch`/`kimi_continue` (that flag auto-dismisses
`AskUserQuestion` in the spawned `kimi-legacy` CLI process — it has no
relationship to this zenka's websocket approval-request flow at all;
confirmed by grep, `afk` does not appear anywhere under `modules/kimi*`).

## root cause found this pass, needs live verification

**`modules/kimi.flush_on_acquisition` is defined but never called.**
Grepped every file under `modules/` — its only other appearance is its own
self-listing in the generated `modules/base.list.subroutines` index. The
one place that should call it doesn't:

`modules/kimi.handler.ws_message:274-281` — on a successful `initialize`
response, distinguishes first-handshake (`not <kimi.session.acquired>`,
sets it TRUE, logs "kimi-web ready to serve requests") from **reconnect**
(`else` branch, just logs "kimi: reconnected : status ready") — neither
branch calls `<[kimi.flush_on_acquisition]>`. So any approval request that
arrived (and got stored into `<kimi.approval.pending>` by
`modules/kimi.handler.approval_request:34`) while the session was
mid-reconnect is never re-processed after the reconnect completes — it
just sits in `<kimi.approval.pending>` forever, orphaned, matching the
user's symptom exactly.

**Two more real bugs found inside `flush_on_acquisition` itself while
reading it** (matter once the call-site gap above is fixed — fixing only
the call site would surface these next):

1. `modules/kimi.flush_on_acquisition:17` — `<kimi.approval.pending> = [];`
   resets the pending store to an **arrayref**, but it's used as a
   **hashref** everywhere else (`->{$request_id} = {...}` in
   `kimi.handler.approval_request:34`; `keys %{$href_pending}` in this
   same file at line 7). Should be `{}`, not `[]`. Confirm live whether
   this throws (`Not a HASH reference` under strict refs) or silently
   misbehaves — either way it corrupts the pending store for every
   session after the first flush.
2. `modules/kimi.flush_on_acquisition:8-15` — re-invokes
   `<kimi.handler.approval_request>` with a **fabricated blank payload**
   (`tool_call_id`/`sender`/`action`/`description` all empty strings),
   not the original request data already sitting in
   `<kimi.approval.pending>->{$request_id}` from when it first arrived.
   `kimi.handler.approval_request:34` then **overwrites** the stored
   record with this blank one, destroying the real `action`/`description`
   needed to auto-approve (sudo check, `auto_allow` policy match) or to
   show the user anything meaningful via `kimi.cmd.approvals`. Fix: pass
   the real stored payload, not a synthesized empty one — i.e. call
   `<[kimi.handler.approval_request]>->( $request_id, $existing_record )`
   using the fields already in `$href_pending->{$request_id}`, not a
   fresh blank hash.

## what to do

1. **Verify live** before fixing: reproduce or closely approximate the
   disconnect/reconnect window (e.g. instrument a log line in
   `kimi.handler.ws_message`'s reconnect branch, or manually kill/restart
   the kimi-web backend process while a task with a pending approval is
   in flight) and confirm the pending approval is genuinely orphaned as
   described, not just theorized from reading.
2. Fix the call-site gap: call `<[kimi.flush_on_acquisition]>` from the
   reconnect branch of `kimi.handler.ws_message` (~line 279-281). Decide
   live whether the first-handshake branch also needs it (probably a
   no-op there since nothing can be pending before first acquisition, but
   confirm rather than assume).
3. Fix `kimi.flush_on_acquisition`'s two bugs above: `{}` not `[]` for the
   reset, and pass the real stored record instead of a blank payload.
4. Check for other callers/assumptions about `<kimi.approval.pending>`'s
   type (hashref vs arrayref) before changing the reset line, in case
   something downstream already silently depends on the current (buggy)
   behavior.
5. Add a regression test if this codebase's existing test patterns for
   `modules/kimi.*` support one (check for existing `.t` files or a test
   harness pattern first — match house convention, don't invent a new
   test style).
6. Read `data/ai-mem/kimi/coding-style.md` and `data/ai-mem/kimi/
   MEMORY.md` first if they exist, for P7 module conventions (lowercase
   comments, `[ word ]` bracket style, `TRUE`/`FALSE`/`UNKNOWN` constants,
   `<[module.name]>` invocation syntax) before editing.

## style / house conventions

- comments lowercase, `[ word ]` not `( word )` for annotations — this
  task file already follows that, match it in code changes too.
- this repo's commit-message convention for a fix like this: state the
  concrete mechanism found broken, the fix, and what was verified live —
  see recent commits like `84930c1f5`, `a5b64e4c5` for the house style
  (`git log --oneline -5` for more examples).
- **do not commit** — write the fix, verify it live, leave it staged for
  the user to review and commit themselves (`user signs and stages,
  Claude commits` convention noted in memory — for this dispatch, just
  leave it ready, don't commit).

## if you learn something non-obvious

Add a note to `data/ai-mem/kimi/coding-style.md` and/or `data/ai-mem/kimi/
MEMORY.md` in your own established format, same as any other task
instruction, if this surfaces a codebase gotcha worth remembering (e.g.
anything about `<kimi.approval.pending>`'s type history, or the
reconnect/flush lifecycle in general).

#,,.,,,..,.,,,.,.,.,,,,..,,,.,.,,,..,,...,,..,.,.,...,..,,,..,,..,.,,,,,.,.,.,
#T5EJXQAZFKXNVY3AXE7UPPX7YEZPBWJPCWF6QWL3OTB2VAGZRCZIOKWGQHFKANGQBGBKY3ED7IFWM
#\\\|7FNLW7ZUS52WBNC3ZRO5ODN7DOB7WOIQ6Y66PVJQXTOQ5X6UX32 \ / AMOS7 \ YOURUM ::
#\[7]ZFEICV4DXVGGCRI2CNA6SLNPLJBO2IEKDHXZZNNFASQ2VFOSN6AA 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
