---
name: async-window-startup-transition
description: window placement on multi-monitor WSLg/Weston — root cause (primary/secondary Y-range overlap clamp), generic find_safe_position/build_strip_candidates recovery mechanism, several latent dispatch/race bugs found+fixed 2026-06-24; also the original async-startup-transition history
metadata: 
  node_type: memory
  type: project
  originSessionId: e46832a1-30ee-4a35-b48d-ba1e45979b28
---

**>>> SESSION 2026-06-24 (LATE, long continuation) — UNCOMMITTED, check `git status` first:

**ROOT CAUSE FINALLY NAILED:** Weston/WSLg per-output placement is correct
when monitor Y-ranges DON'T overlap, but on the vertical-offset 3-monitor
layout (beamer on) primary `y:[1860,2940)` and secondary `y:[1080,2520)`
OVERLAP in `y:[1860,2520)`. Any ConfigureWindow targeting a Y inside that
overlap gets mis-attributed to the wrong output and silently clamped/voided
— confirmed via `x:want=1920,got=0` (actual x lands inside PRIMARY's width)
appearing on every failing case. This affects EVERY placement method tested
tonight, including the previously-"always reliable" pre-show_all path — a
brand-new, never-mapped window landed in a genuine void (no monitor
contains the actual position) when its target was in the overlap zone.
NOT FIXABLE client-side: tried resize-nudge, unmap/map, fresh child
process, X11 reconnect — all ineffective. Bottom-strip-on-secondary
(`y=2448` under this layout) is durably unreachable; top-strip-on-secondary
(`y=1080`) is durably safe and is the practical manual-recovery position.

**ONLY proven automated recovery for the DECREASE case:**
`powershell.cmd.display-switch-toggle` (runs `DisplaySwitch.exe /internal`
then `/extend` via the existing `powershell.exec` plumbing) — a host-side
Windows topology re-push, triggered from `X-11.handler.screen_change` on
monitor-count drop, cooldown-guarded (10s). Confirmed live, repeatedly.
INCREASE case (beamer reconnect) has no automated fix; only a full
`v7.restart <zenka>` recovers a stuck-invisible window from that direction,
and even that is non-deterministic for STARTUP placement (see open issues).

**GENERIC RECOVERY MECHANISM BUILT (the real deliverable):**
`window.place.find_safe_position` (`<window_id>, <candidates_aref>` — tries
each candidate via REAL move+verify, X-11.cmd.move-window's own
mismatch-detection logic, returns first that lands) + `window.place.
build_strip_candidates` (`<monitors_aref>, <preferred_profile>,
<preferred_monitor_index>` — builds an ordered top/bottom-strip candidate
list across ALL monitors, preferred one first). Philosophy: empirically
probe real alternates rather than analytically model Weston's exact rule
(which isn't fully/reliably known). Wired into `ticker.move_to_profile`
(runtime swap fallback — WORKS, verified repeatedly) and attempted in
`ticker.open_window`'s map-handler for STARTUP placement (added an `elsif`
branch alongside the existing settle-timer one) — this startup wiring is
UNRELIABLE: a single 0.2s-delayed check is too early, Weston's own
initial-placement handshake for a brand-new window can still be in
progress and clobbers ANY move attempt (manual `X-11.move-window` calls
also failed repeatedly during this window). The pre-existing no-snapshot
settle-timer branch already knows this and polls up to 10×0.2s — my new
branch needs the SAME patience (repeat find_safe_position attempts with
delays, not a single shot) — NOT YET DONE, next session.

**LATENT BUGS FOUND + FIXED (pre-existing, never exercised before
tonight since the screen-change subscriber list was always empty/broken):**
- `X-11.cmd.subscribe-screen-change`: `$params->{'args'}{'data'}` — bogus
  extra `->{'data'}`, `$params->{'args'}` is already the plain string.
  Broke EVERY screen-change subscription ever made (tile's too).
- handler naming: `tile.handler.screen-change` / a `protocol-7-menu.
  handler.screen-change` I wrote were NEVER dispatchable as routed
  commands — `.handler.` doesn't match `base.regex`'s `cmd` pattern
  (single-segment, no dots) and isn't auto-registered into `<base.cmd>`
  (compile-time regex only matches `.cmd.`/`.console.` segments). RENAMED
  both to `tile.cmd.screen-change` / `protocol-7-menu.cmd.screen-change`.
  Exposed command name is cmd-stripped: `tile.screen-change` /
  `protocol-7-menu.screen-change` — update access.zenki + local
  access.cmd.usr.cube lists to the STRIPPED short name, not the file name.
- `X-11.emit.screen-change`: built its payload with `YAML::XS::Dump`
  (multi-line!) sent as a single `call_args.args` string over
  `protocol-7.route-send` — the wire protocol is LINE-ORIENTED, so each
  YAML line got misread as a separate stray command, corrupting cube's
  command stream on EVERY screen-change event (`protocol mismatch`,
  `FALSE-reply to unknown route id [0]` flood). Replaced with a flat
  single-line `event=X width=Y height=Z ntime=W` format; updated both
  `.cmd.screen-change` consumers to parse it with a simple regex instead
  of YAML. Also dropped the now-unneeded `YAML::XS` autoload from
  `X-11.init_code` (was missing entirely — ALSO would have crashed with
  `undefined subroutine &YAML::XS::Dump` on its own, a second latent bug
  stacked on the first).
- `ticker.cmd.swap_profile`: (a) never returned a hash ref at all — `.cmd.`
  commands MUST; (b) used bare `shift` which grabs the raw `$call` hashref
  when dispatched via cube (vs. the plain-string arg when called
  internally) — fixed to `$call->{'args'}`, which the compiled `.cmd.`
  header already normalizes correctly for BOTH call styles.
- `ticker.move_to_profile`: `$did_not_move` compared actual vs the PRIOR
  position with no regard for whether the TARGET equals the prior position
  too — misclassified an already-correct position (e.g. a redundant swap
  landing on the edge it's already on) as a FAILURE, triggering an
  unnecessary fallback cascade on every such call. This very likely caused
  the "ticker frozen, no text/no hover" symptom seen tonight: false
  failure → 0.15s×2 BLOCKING sleeps (`base.sleep` = real `Time::HiRes::
  sleep`, no event-loop pumping) → fallback cascade → repeat on next hover
  poll, starving the event loop of time to service drawing/animation
  callbacks. Fixed: success now depends ONLY on whether actual reached the
  target, not on whether it differs from the prior position.
- `ticker.handler.check_pointer`: the delayed-leave-cancel-on-reentry check
  (`if (not mouse.inside and $inside) { delete leave_pending_until }`)
  cancelled the 300ms grace on the FIRST raw geometric "inside" sample with
  ZERO debounce — unlike every other transition in the file (3-poll/300ms
  debounce). On a thin 72px strip near a screen edge, one incidental/
  imprecise cursor reading could kill the pending fade-in before its grace
  ever completed, then the (properly debounced) enter-detection could ALSO
  fire shortly after — net effect: fade gets stuck, "never realizes
  pointer is gone". Fixed: only cancel the pending leave once re-entry is
  CONFIRMED (3 consecutive polls, same threshold as full entry-detection),
  not on a single sample. ALSO fixed in the SAME root-cause family:
  `ticker.move_to_profile` now resyncs `<x11.coordinates.*>`/`<x11.window.
  width/height>` to GROUND TRUTH (a fresh `get_window_geometry` call) at
  the end of EVERY call regardless of branch, instead of trusting whatever
  set-window-profile/find_safe_position computed — check_pointer's hover-
  box is built from these values, so any drift there breaks leave/enter
  detection independent of the cancel-on-reentry bug above.
- `ticker.move_to_profile`'s fallback-success branch used to unconditionally
  fall through into `keep_below` + force-opacity-1 (written for the
  total-failure case only) even when find_safe_position SUCCEEDED — pushed
  a correctly-placed, fully-opaque window BEHIND other windows, which
  looked EXACTLY like "stuck invisible, needs restart" even though the
  window was technically fine. Fixed: success branch now raises +
  keep_above instead.

**STILL OPEN / UNRESOLVED at session end:**
1. Startup placement into the overlap zone is non-deterministic — same
   fallback code sometimes lands correctly, sometimes lands in a genuine
   void (`x=0,y=...`) that even manual `X-11.move-window` calls couldn't
   immediately escape (had to wait/retry). Needs settle-timer-style
   patience (repeated attempts with delays) added to the new startup
   fallback branch in `ticker.open_window`, not a single 0.2s-delayed shot.
2. NEW, uninvestigated, WORSE on a later recurrence: first seen as "shadow
   only, no text, no hover" (border visible, content not painted); a LATER
   occurrence the SAME session showed "nothing, no draw callback" (not even
   a border) after manual move-window recovery from a void-landing startup.
   No errors in the zenka log either time. A forced 1px-nudge-and-back move
   did NOT fix the first occurrence; a full `v7.restart ticker` was tried
   for the second (landed in ANOTHER void, needed the same manual
   move-window recovery, draw state after that not re-confirmed - session
   ended on context limits). Looks like a pure COMPOSITOR rendering/paint
   glitch distinct from all the placement-logic bugs above, possibly
   correlated with the void-landing startup sequence (both times this
   draw-callback symptom appeared, it followed a void-landing recovery) -
   worth checking next session whether forcing a fresh GTK draw signal
   (`$window->queue_draw` via devmod exec-sub, or a real geometry change
   bigger than 1px) recovers it, and whether it's reproducible WITHOUT a
   preceding void-landing event to confirm/rule out the correlation.
3. Practical manual recovery commands for next session if this recurs:
   `p7c X-11.move-window <id> 1920 1080 3440 72` (secondary-top, confirmed
   durably safe) to fix position; `p7c v7.restart ticker` for a full reset
   (non-deterministic on landing, may need the move-window fix afterward
   too); `p7c X-11.get-windows` / `p7c X-11.get_geometry <id>` to check
   state; `p7c v7.devmod-enable <zenka>` + `p7c <zenka>.get <key>` / `.set`
   to inspect/patch live data state without a restart.

**Files touched this session (uncommitted, verify against `git status`):**
modules/X-11.cmd.move-window (mismatch detection + 0.1s recheck before
logging), modules/X-11.handler.screen_change (decrease-triggered toggle +
settle-check timer; reconnect logic ADDED then REMOVED, see below),
modules/X-11.handler.monitor_settle_check (new), modules/X-11.cmd.
refresh-monitors (new), modules/X-11.handler.global_hotkeys (RandR
sub-event warning suppression), modules/X-11.init_code, modules/X-11.
emit.screen-change, modules/X-11.cmd.subscribe-screen-change, modules/
powershell.cmd.display-switch-toggle (new), modules/window.place.
find_safe_position (new), modules/window.place.build_strip_candidates
(new), modules/ticker.move_to_profile, modules/ticker.cmd.swap_profile,
modules/ticker.handler.check_pointer, modules/ticker.open_window, modules/
tile.cmd.screen-change (renamed from tile.handler.screen-change), modules/
protocol-7-menu.cmd.screen-change (new, renamed from a .handler. version),
modules/protocol-7-menu.subscribe-screen-change (new), modules/
protocol-7-menu.init_code, cfg/zenki/{X-11,ticker,tile,
protocol-7-menu,powershell}/{start,subroutines.load-early}, cfg/
zenki/cube/access.zenki.
**REMOVED entirely (regressed, no confirmed benefit):** an in-handler
X-11 reconnect-on-every-screen-change-notification approach — structurally
incompatible with how `event_handler='queue'`, the RandR subscription, and
the keyboard IO watcher's file descriptor are ALL tied to one connection
object at `X-11.job.finalize_server` startup; none carry over to a fresh
connection or get re-registered automatically. The codebase's OWN existing
reconnect mechanism (`X-11.reconnect`, called only from the connection's
error_handler on a server crash) doesn't solve this either — it
deliberately exits the whole process on exhaustion specifically so v7
restarts it through the full init chain. Don't re-attempt without also
solving the IO-watcher-rebinding problem (no reference to the watcher is
kept anywhere to re-target it).

**WSLg deiconify limitation REFINED:** see
[[feedback-wslg-deiconify-limitation]] — the host Windows taskbar restore
path is NOT blocked by the client-side deiconify limitation; confirmed
live recovering a minimized protocol-7-menu window.
<<<**

**>>> CURRENT TRUTH (2026-06-24, supersedes the stale middle sections below):
TICKER RESILIENCE FULLY IMPLEMENTED + LIVE-VERIFIED with tile fully stuck
(SIGSTOP via v7.pause-instance). Three bounded fallbacks + resolve-once
guards all fire correctly and the ticker comes up online with one window:**
  1. `base.X-11.get_coordinates_async` — fallback timer, config
     `<x11.coordinates_fallback_timeout> // 7`s, named handler
     `base.X-11.handler.coordinates_timeout`; `handler.coordinates_reply` has
     the mirror resolve-once guard (`return if not defined
     <x11.coordinates_async_continuation>`) — fixes the timeout-then-late-reply
     DOUBLE-FIRE (was opening the window twice).
  2. `cube.tile.get-layer` (ticker.startup) — fallback timer, config
     `<ticker.layer_fallback_timeout> // 7`s, named handler
     `ticker.handler.get-layer_timeout` (opens with default layer);
     `ticker.handler.get-layer_reply` has the `<ticker.layer_resolved>` guard.
  3. `base.X-11.get_subconfig` — bounded `select()` read,
     `<x11.subconfig_read_timeout> // 3`s, returns undef→default on timeout;
     MOVED off the startup-critical path to the post-online draw-init block
     (`ticker.callback.draw`) since it only drives runtime auto_speed.
THE PATTERN (bounded-fallback timer + named handler + resolve-once guard) is
the template to multiply to the other 9 window zenki (see Affected set).
The "make tile always-on" theory was WRONG — real tile fix was the openbox
dependency, see [[feedback-tile-openbox-dependency-redundant]] (tile reliable
now). The 3 fallbacks fire SEQUENTIALLY when tile is fully stuck (7+7+3 ≈ 17s
worst case) but well within ticker's 64.7s window; parallelizing get-layer
with coordinates is an open optimization.
COMMITTED 2026-06-24 as `44c83d2b0` (ticker: bounded fallbacks for tile-
dependent startup, 24 files). Earlier this session: `eae0be7da` (gtk monitor
helpers + menu/screen-setup), `eec8a9e8e` (tile openbox dep drop). HELD BACK
uncommitted: modules/X-11.cmd.move-window + base.X-11.move-window (entangled
with the mpv-jobqueue thread, volatile values — do NOT bundle).
STILL OPEN [ ACTIVE NOW ]: the centered-on-WRONG-monitor regression (3rd
monitor on) — geo_ready shapes the correct rect [1920,2448,5360,2520] but
ticker.open_window doesn't apply it as INITIAL placement before show_all
(gravity+default_size+move pre-map like the menu); distinct open_window pass.
<<<**

**>>> PLACEMENT REGRESSION ROOT CAUSE (2026-06-24, diagnosed not yet fixed):
the centered-on-wrong-monitor bug is NOT just "post-map move clamped". The
real cause: `ticker.open_window` line 38 calls `ticker.cmd.set-window-profile`
right after `Gtk3->init`, and set-window-profile RECOMPUTES `<x11.coordinates.*>`
from `ticker.select_monitor` / `window.profile.calculate` (lines 60-65) — at a
point where GDK's monitor list/geometry has NOT settled (esp. non-primary
monitors w/ a vertical offset, 3rd monitor on) → wrong monitor → it CLOBBERS
geo_ready's already-correct rect [1920,2448,5360,2520]. open_window then does
a post-map `startup_settle` poll loop (open_window 296-388) that re-runs
set-window-profile + double `base.X-11.move-window` to "correct" it — but
that's a post-map cross-output move which Weston CLAMPS/centers. So the window
lands wrong and the correction can't fix it cross-output.
FIX DIRECTION (menu is the proven model, protocol-7-menu.graphical-startup-init
200-220): position BEFORE show_all — `set_gravity('north-west')` +
`set_default_size(w,h)` + `$window->move( geo_ready's left, top )` just before
open_window:446 show_all, USING geo_ready's <x11.coordinates> (do NOT let
set-window-profile's GDK-not-settled recompute overwrite them), and stop /
neutralize the post-map startup_settle move loop so it can't clobber the good
initial placement. NOTE dock type_hint (open_window:97, non-swap only) makes
Weston own positioning + ignore client moves — swap mode uses a normal toplevel
[ the tested/regressing case ] so pre-show_all move works there like the menu;
non-swap/dock may need separate handling. set-window-profile also still needed
for runtime profile switches — only the STARTUP path should bypass its
GDK-not-settled recompute.
IMPLEMENTED 2026-06-24 (PENDING SIGN+TEST), 3 edits: (1) ticker.startup.geo_ready
snapshots the correct rect into <ticker.startup_coordinates>; (2) ticker.open_window
positions BEFORE show_all from that snapshot (set_gravity north-west +
set_default_size + move); (3) ticker.open_window gates OFF the post-map
startup_settle/move loop when the snapshot is set (`and not defined
<ticker.startup_coordinates>`) so the clamped post-map move can't clobber it.
DESIGN CONTEXT (taeki): swap-cycle is INTENTIONALLY top/bottom strip of the
SAME screen now (earlier versions cycled between MONITORS — removed on purpose);
this fix only touches STARTUP initial placement, runtime top/bottom swap still
goes through set-window-profile untouched, so the same-screen cycling is
preserved. The bug being fixed = startup landing centered on the WRONG monitor
(3rd on) instead of the configured monitor strip.<<<**

**Started 2026-06-24. TICKER REFERENCE PROVEN ONLINE end-to-end (async
chain works); GDK-ensure-display fix applied, awaiting sign+test confirm.**

**TICKER POSITIONING ROOT (2026-06-24):** with tile up, ticker opens but
mispositioned — log `profile move to bottom-strip failed (actual x=1920
y=1080, target x=1920 y=2448)`. BOTH y values are INSIDE monitor index:1
(XWAYLAND1 y 1080-2520) → this is a WITHIN-monitor post-map move that fails
= the documented Weston "post-map programmatic move unreliable" limit (see
[[feedback-weston-move-unreliable-use-compositor-grab]]), NOT cross-output.
FIX: ticker.open_window must place at geo_ready's strip coords [1920,2448]
via INITIAL placement before show_all (set_gravity+set_default_size+move
pre-map, like screen-setup/menu), not open-at-top-then-move.
**CORRECTION (taeki, 2026-06-24): the hover-SWAP is NOT a hard residual —
it works cleanly when the ticker starts on the 2nd screen (3rd off).** So
post-map within-monitor moves are FINE; the ENTIRE bug is the window
opening on the WRONG monitor when 3 screens are present (maps on the 3rd/
centered instead of index:1) — Weston's per-output state then breaks the
subsequent swaps. Once it maps on the correct monitor (initial placement),
the swap just works. So the ONLY fix needed = force initial placement onto
monitor index:1 before show_all in ticker.open_window. The menu already
lands correctly on the 2nd screen via gravity+default_size+move pre-map —
copy that. ticker.open_window currently calls set-window-profile (line ~38)
which isn't forcing the right output pre-map; investigate why + replace
with the menu-style pre-show_all placement using <x11.coordinates>.

**TILE HANG INVESTIGATION (2026-06-24, INCONCLUSIVE):** taeki wants tile's
unresponsiveness root-caused + made resilient (manual restart fixes it =>
tile HANGS, not just idle-offline, since on-demand would auto-restart).
Searched tile.* modules: NO sync-blocking inter-zenka calls (no readline/
send_to_socket/get_coordinates/get_geometry), no obvious infinite loops/
subprocess/each-traps. So the hang is subtler — candidates to chase next
session: a watcher/timer stuck, or `tile.deferred_replies` accumulating when
window-place can't service a get_geometry-triggered interactive placement
(tile.cmd.get_geometry defers to window-place.place_window; if that never
completes, replies pile up — check tile.handler.receive_placement +
deferred_replies lifecycle). Interim: make tile always-on as stability floor.

**TILE FLAPPING IS THE DOMINANT BLOCKER (2026-06-24):** tile is on-demand
with NO keepalive in its start file (no set_ondemand_timeout, no heartbeat)
→ dies on idle → every window zenka that sync-queries it cascades into
hang/timeout. Hit it 4+ times this session. menu now works (visible on 2nd
screen, snap_to_monitor confirmed). ticker still times out when tile is
offline: it hung at sync `<[base.X-11.get_geometry]>` in geo_ready —
REMOVED that (nothing reads <x11.geometry>; was pure tile-hang weight,
edit made, NEEDS SIGNING). But `<[base.X-11.get_subconfig]>` next in
geo_ready ALSO routes to tile → next hang if tile offline. **DECISIVE FIX
RECOMMENDED: make tile always-on** (add `tile` to v7 start-set-up.base
`zenki.enabled` [currently `cube p7-log system`] + drop start.on-demand;
tile deps = cube X-11 openbox set-up). Offered to taeki; awaiting yes.
Alternative: tile heartbeat+no-timeout (the ondemand-heartbeat-upgrade
intent, never actually wired). Until tile is reliable, all window-zenka
startup testing is noisy.

**RESUMED 2026-06-24 (kimi had been debugging in between):** kimi added a
`_NET_WM_MOVERESIZE_WINDOW` SendEvent to X-11.cmd.move-window to coax
cross-output placement → it reached Weston's minimal xwm, which mishandled
it and the ticker window VANISHED ('no longer opens'). REMOVED that block
(kept kimi's width/height arg parsing, which is a clean format fix; base.
X-11.move-window now sends `id x y w h` space-joined, cmd accepts optional
w/h). Sign X-11.cmd.move-window + reload → window opens again.
**KEY CONCLUSION: move-window does NOT need monitor awareness — runtime
cross-output ConfigureWindow is clamped per-output under this Weston, full
stop. Symptom proof: ticker opens centered on 3rd screen, hover-swap to 2nd-
screen-top works but bottom-swap fails (cross-output clamp), and with the
3rd screen OFF it all works cleanly (no cross-output move to clamp). REAL
FIX = monitor-correct INITIAL placement before show_all (gravity +
set_default_size + move on target-monitor coords) in ticker.open_window,
like screen-setup/protocol-7-menu — NOT a runtime move.** kimi's changes
still unstaged; the _NET_WM_MOVERESIZE attempt is reverted.

**HANDOFF STATE (session ended ~98% tokens 2026-06-24):**
- DONE/PROVEN: ticker comes up `online` via the full async chain
  (requesting→reply→geo_ready→window→session-id→verified). protocol-7-menu
  `online` too (snap_to_monitor verified). screen-setup committed earlier
  (ce80398d5).
- JUST APPLIED, NOT YET CONFIRMED: `base.gtk.ensure_display` (new) + geo_ready
  calls it before ticker.select_monitor [ GDK wasn't inited that early →
  no-monitor-strip → undef coords → move-window errors ]. ticker white-list
  regen'd (589). Sign base.gtk.ensure_display + ticker.startup.geo_ready +
  white-list, then `v7.start ticker`: expect `fallback strip on monitor`
  line, no move-window errors, strip on monitor index:1 (no void).
- UNSIGNED/UNCOMMITTED file inventory (this transition): modules
  base.gtk.{strip_on_monitor,centered_on_monitor,ensure_display},
  base.X-11.{get_coordinates_async,handler.coordinates_reply},
  ticker.startup.geo_ready (new); edits modules/ticker.startup (main_loop
  removed), cfg/zenki/ticker/start, ticker subroutines.load-early.
  ALSO from earlier this session, signed-but-CHECK-IF-COMMITTED: base.gtk.
  {list_monitors,snap_to_monitor}, protocol-7-menu.graphical-startup-init,
  screen.setup.{open_window,enumerate-monitors,handler.*}, cube/auth.zenki —
  run `git status` + `git log --oneline -5` first thing to see what landed.
- GDK FIX CONFIRMED WORKING 2026-06-24: geo_ready now shapes correct strip
  `[1920,2448,5360,2520]` (bottom strip on monitor index:1), ticker online +
  scrolling. ASYNC TRANSITION FULLY PROVEN.
- SEPARATE PRE-EXISTING BUG surfaced (NOT async-related): ticker window is
  positioned wrong (compositor-centered) because `move-window 'expected
  <id> <x> <y>'` fails. ROOT: **`base.X-11.move-window` sends args
  COMMA-joined `"id,x,y,w,h"` but `X-11.cmd.move-window` now SPLITS ON
  SPACES and expects `<id> <x> <y>` (3 parts, no w/h)** — format mismatch,
  almost certainly from the uncommitted mpv-jobqueue `X-11.cmd.move-window`
  change [see [[topic-mpv-jobqueue-startup]] / the CRITICAL mpv UNCOMMITTED
  note]. FIX next session: reconcile the two — likely change
  base.X-11.move-window to space-join + send only `$id $x $y` (or revert the
  cmd-side format). Affects every caller of base.X-11.move-window, verify
  broadly. NOT verified/fixed (session out of tokens).
- LATEST STATE (session very end, 2026-06-24): taeki ADDED a bounded
  fallback timer to base.X-11.get_coordinates_async (log: `[coordinates_async]
  fallback timer fired -- continuing with undefined coordinates`) — works
  (tile didn't reply, timer fired, geo_ready shaped correct strip). BUT
  ticker now CRASHES on startup: `font size '0' is not valid [ticker.
  parse_text:5]` — `read_file` (an INCOMING command) is processed BEFORE the
  window is operational → parse_text sees height 0 → abort. The timer delays
  geo_ready, widening the race. **This is the session-id-gating issue: the
  ticker must NOT accept incoming commands until online/operational. The
  deferred wait_for_window→session_id re-sequencing IS the fix** (online only
  after window-open gates incoming traffic; see SESSION-ID SEMANTICS above).
  Also `protocol-7-menu verification timeout` reappeared — likely tile
  flapping again; check `present tile` first. Interim cheaper guard: make
  ticker.parse_text defer/skip when <x11.window.height> is 0/undef.
- NEXT (in order): (0a) check tile online (flapping breaks menu+ticker);
  (0b) IMPLEMENT the wait_for_window→session_id re-sequencing for ticker so
  incoming cmds gate behind operational state [ fixes the parse_text race ];
  (0c) fix the base.X-11.move-window/X-11.cmd.move-window comma-vs-space
  format mismatch (ticker + others mis-positioned until then);
  (1) [done] GDK fix lands ticker strip correctly;
  (2) ADD BOUNDED FALLBACK TIMER to base.X-11.get_coordinates_async [ taeki
  wants this — fire continuation with coordinates_were_undefined=TRUE if no
  reply in ~Ns, ONCE-ONLY: cancel timer on real reply + guard double-fire;
  makes tile-offline a soft dep not a 64.7s hang ]; (3) write the ABSTRACT
  recipe (not ticker diff — keep ticker swap-mode/startup-settle quirks out);
  (4) **kimi_dispatch (6× beta model) for the other 9 zenki**: remote-cam,
  storchencam, start-anim, reenc-msg, universal, select-region, web-browser,
  impressive, tile [ enumerated set; ticker done ].

**Started 2026-06-24. Foundation + ticker reference BUILT, UNSIGNED/UNVERIFIED.**

**Problem:** an earlier *incomplete* async transition for coordinate
requests left the not-yet-transitioned GTK zenki calling sync
`base.X-11.get_coordinates`/`get_geometry` in their `start` files. On the
staggered multi-monitor layout this breaks two ways: (a) the sync call
blocks before the event loop runs → zenka can't answer verify-instance →
start-timeout → restart loop (this is what killed ticker — NOT a crash in
placement, the stale 06-16 log misled at first); (b) when tile has no
entry, the old fallback anchors at (0,0)/virtual-screen, which is a VOID on
staggered layouts → window off all outputs / wrong (also a bogus ~2940-tall
fallback height). taeki's framing: complete the transition so window
startup moves OUT of the start file INTO a callback fired when required data
[coordinates] is resolved.

**The pattern (reference = ticker), all sync routines + async twins share
the `base.X-11.*` namespace:**
- shared async resolver: `base.X-11.get_coordinates_async` +
  `base.X-11.handler.coordinates_reply` (route-send tile.get_coordinates,
  fire continuation; TRUE→parse+store <x11.coordinates>; FALSE→mark
  <x11.coordinates_were_undefined>). GENERIC — **no shape knowledge.**
  Pairs with the pre-existing `get_geo_async`/`handler.geo_reply`.
- **CRITICAL boundary (advisor catch): fallback SHAPE is per-zenka, NOT in
  the shared handler.** The 10 zenki differ: ticker = full-width strip on a
  *configured* monitor (index:1); the get_geometry zenki = centered window.
  `snap_to_monitor` only fixes (x,y), never w/h — baking one shape into the
  shared handler would multiply a bug. So shaping lives in each zenka's
  `<zenka>.startup.geo_ready`, backed by shared shapers:
  `base.gtk.strip_on_monitor`, `base.gtk.centered_on_monitor`
  (+ `base.gtk.snap_to_monitor`, `base.gtk.list_monitors` from earlier).
- per-zenka: `start` drops the sync calls + window-open, kicks off
  `[base.X-11.get_coordinates_async:<zenka>.startup.geo_ready]` then enters
  `[base.gtk.main_loop]` (loop must run for the async reply); the window-
  open tail moves into the geo_ready continuation. Existing `*.startup`
  loses its own `main_loop` (moved to start).

**ticker reference files (built):** modules base.gtk.{strip_on_monitor,
centered_on_monitor}, base.X-11.{get_coordinates_async,
handler.coordinates_reply}, ticker.startup.geo_ready (new); edits
cfg/zenki/ticker/start, modules/ticker.startup (main_loop removed).
ticker white-list regen'd (588). ALL NEED SIGNING.

**SESSION-ID SEMANTICS (critical — taeki corrected me twice here):**
acquiring the session id flips the zenka to online/initialized, which BOTH
unblocks dependent zenki AND starts accepting INCOMING commands. So it must
NOT be requested upfront (commands would arrive against a not-yet-
operational zenka with no window and be lost), and must NOT sit behind an
unbounded user-interaction wait (start-timeout = 64.7s). Correct placement:
AFTER the main init target (window open) is reached, via a BOUNDED path.
During init the zenka may still do OUTGOING queries to other zenki — only
incoming/online is gated. `base.X-11.*` are the ORIGINAL SYNC routines
(get_coordinates/get_geometry/get_screen_size + **wait_for_window**) used in
start files pre-transition; `wait_for_window` is sync but BOUNDED (sends
X-11.wait_visible, ~7s timeout, aborts on miss) so it's the safe gate.
**Canonical sequence (web-browser.wait_for_window is the reference):**
async-fetch coords/geometry → open window → `base.X-11.wait_for_window`
[bounded, abort on timeout] → `base.X-11.assign_window` →
`base.async.get_session_id`. ticker currently acquires session-id in
`ticker.callback.draw` (works only if the window draws) — re-sequence onto
the wait_for_window-after-open path. BUT that's all downstream of the window
opening; ticker's blocker is the async coordinate chain stalling before
geo_ready (see diagnostics below) — fix that FIRST.

**ROOT CAUSE of the ticker stall (2026-06-24): tile zenka was OFFLINE**
(last seen 2026-06-23). The async chain was correct — it route-sent
`cube.tile.get_coordinates` to a dead zenka, so no reply ever returned →
`coordinates_reply` never fired → continuation never ran → 64.7s timeout.
NOT a routing/handler bug. **Strong lesson → add a BOUNDED FALLBACK TIMER to
`get_coordinates_async`** (and `get_geo_async`): if no reply within ~Ns,
fire the continuation with `coordinates_were_undefined=TRUE` so geo_ready
shapes its fallback and the window opens regardless. Converts a hard
cross-zenka dependency (tile up) into a soft one — a restarting tile must
not wedge every window zenka's startup. Matches taeki's bounded/never-hang
principle. **VERIFIED 2026-06-24: protocol-7-menu came up `online`** — the
menu fix + `snap_to_monitor` work (was crash-looping); snap primitive banked.

**DIAGNOSTICS in place (2026-06-24, await test):** three log lines trace the
async chain — `requesting coordinates [async]` (get_coordinates_async ran),
`[coordinates_reply] cmd=…` (route-send reply dispatched),
`[ticker.geo_ready] continuation fired`. Which appears localizes the stall:
none→config/parse of the start-file call; first only→tile.get_coordinates
route-send reply never dispatched (new-routine bug); first two→continuation
`$code{...}->()` dispatch bug.

**RECIPE GOTCHAS (found verifying the reference):**
- if a `geo_ready` fallback shaper uses GDK (eg. ticker.select_monitor is
  pure `Gtk3::Gdk::Display::get_default`), GDK isn't initialised yet at
  continuation time (the zenka's own Gtk3->init is later, in open_window).
  Call **`base.gtk.ensure_display`** (new shared helper: sets DISPLAY +
  GDK_BACKEND=x11, Gtk3->init once, idempotent) at the top of geo_ready
  first, else select_monitor returns undef → no fallback → `<x11.coordinates>`
  undefined → downstream `move-window` fails 'expected <id> <x> <y>'.
- ticker came up ONLINE end-to-end once tile was online + this fix
  (2026-06-24): full chain requesting→reply→geo_ready→window→session-id→
  verified proven.
- in the `start` file the continuation handler name MUST be quoted:
  `[base.X-11.get_coordinates_async:'<zenka>.startup.geo_ready']` — unquoted
  it parses as a bareword and dies `'bareword not allowed while strict subs'`
  (inside a module, by contrast, use `qw| ... |` like window.place does).

**Affected set (10) — kimi's work after the reference is verified:**
get_coordinates: ticker[done], remote-cam, storchencam, start-anim,
reenc-msg, universal. get_geometry: universal, select-region, web-browser,
impressive, ticker[done]. get_screen_size: tile.

**NEXT (do NOT skip — verify before multiplying 9×):**
1. sign + `v7.start protocol-7-menu` → bank `snap_to_monitor` (load-bearing
   now; still unverified from the earlier iteration).
2. sign + `v7.start ticker` → confirm the reference actually comes up on a
   real monitor strip, no verify-timeout.
3. THEN write the abstract recipe (NOT the ticker diff — ticker's swap-mode/
   startup-settle/target-monitor quirks must not leak into the template;
   dry-run it mentally against a simple one like reenc-msg/start-anim) and
   dispatch via kimi_dispatch/kimi_continue MCP (6× beta model selected).

## related

[[topic-screen-setup-zenka]] · [[feedback-weston-move-unreliable-use-compositor-grab]] · [[feedback-deferred-init]] · [[feedback-cross-zenka-deferred-reply]]

#,,.,,...,..,,...,,,.,,,,,,..,...,,.,,...,...,..,,...,...,..,,,..,.,,,,,.,,.,,
#5AHATVMF7LLVVBVFWGXMPD32APHULPBVUGUNALTUIKHNY6OV5CFACOJSS6B22CH6GKFTYMXG7QUG6
#\\\|XZ644EOG3GIRP7YCH5IUHFO4M3LLRBI5BCBOMIIZJPRKG7BAXJJ \ / AMOS7 \ YOURUM ::
#\[7]RRBTZKEQOJL7444QNB7FJHXVQGSWBB5QL4YWOUBVX4IPLZYKGKDY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::

**>>> SESSION 2026-06-25 (LATER) — LANDED `531aa14db`: ticker subscribed to
screen-change + startup retry timer actually retries now + read_file race
fixed. LIVE-VERIFIED by taeki: ticker starts on bottom-strip of secondary
monitor, swap-to-top works, screen-change recovery path exercised. CONSIDER
THIS THREAD CLOSED unless a NEW failure mode shows up — don't re-open
"check this file first" urgency for the startup-void/screen-change work
specifically; only the items still listed as STILL OPEN below (the
"shadow only, no content" compositor-paint glitch) remain unresolved.**
Three fixes landed together:
1. **ticker never subscribed to X-11 screen-change at all** — tile,
   reenc-msg, and protocol-7-menu all had `<zenka>.subscribe-screen-change`
   + `<zenka>.cmd.screen-change` wired into `callbacks.initialized`; ticker
   had neither, so "our new callbacks on monitor reconfigure" could never
   reach it regardless of how good the recovery logic was. Added
   `ticker.subscribe-screen-change` + `ticker.cmd.screen-change` (relocate
   via `find_safe_position`/`build_strip_candidates`, mirroring
   protocol-7-menu.cmd.screen-change but using strip candidates since
   ticker is a strip window, not a movable corner window), pushed onto
   `<system.callbacks.initialized>` in ticker.init_code. Added
   `ticker.screen-change` to cube `access.cmd.usr.X-11`.
2. **the startup void-recovery timer (added 2026-06-25 earlier this
   session, see below) never actually retried** — `my $landed = defined
   $actual and abs(...) <= $tol and abs(...) <= $tol;` is Perl-precedence
   `(my $landed = defined $actual) and ...`, so `$landed` was just `defined
   $actual` — true on literally the first tick after map (geometry always
   resolves) — so the timer always believed it had landed and cancelled on
   attempt 1, `find_safe_position` never ran. THIS, not "GDK not settled,"
   is most of why the user's complaint ("only tries the same position
   multiple times, nothing recovers automatically") was true — the retry
   loop was dead on arrival despite looking complete. Fixed: `and` → `&&`
   (binds tighter than `=`, so the assignment captures the full boolean).
   **General lesson for future P7 code review: `my $x = A and B` is a
   precedence trap — `and`/`or` bind LOOSER than `=`, `&&`/`||` bind
   TIGHTER; always use `&&`/`||` when the result of a multi-term boolean
   needs to land in a `my` assignment.**
3. **read_file crash race, found live during this session's test**: a
   `read_file` command (default content load) arrived while tile was
   still replying to the coordinates-fallback timer, before ticker's first
   draw callback had computed `<ticker.font.size>` from real window
   height (`ticker.open_window` sets it to 0 placeholder) — `ticker.
   parse_text` unconditionally `die`s on a 0 font size, crashing the
   zenka. Fixed by deferring: `ticker.cmd.read-file-cont` now checks
   `<ticker.status.initialized>` (the same flag that gates the
   `get_session_id`/online flip in `ticker.callback.draw`) and if not yet
   set, pushes `$call` onto `<ticker.pending_read_calls>` and returns a
   "deferred" reply instead of proceeding; `ticker.callback.draw`'s
   init block drains and replays the queue right after it flips
   `status.initialized` TRUE. This is the lightweight version of the
   "wait_for_window→session_id re-sequencing" fix that was flagged as
   still-needed in the 2026-06-24 session notes below — scoped to just the
   read_file entrypoint rather than a full re-sequencing project.
**Also confirmed same session: protocol-7-menu's "working" recovery from
the 2026-06-24 notes below was NOT proven by relocate-logic success** —
taeki clarified live that what was observed was the window minimizing
itself (Weston-level, not protocol-7-menu code) while staying clickable
via the host taskbar [ see [[feedback-wslg-deiconify-limitation]] ], not
`find_safe_position` necessarily landing it. Don't cite protocol-7-menu as
proof the relocate-on-screen-change primitive *works* in the overlap-void
case specifically — only that the subscription plumbing pattern is sound
to copy. taeki separately tested protocol-7-menu again this session: visible
but suboptimal starting placement, and it correctly remembered a manual
move across restart.

**>>> SESSION 2026-06-25 (EARLIER) — confirmed root cause + patience fix for the void-landing fallback:**
taeki confirmed via screen-setup zenka: with beamer off (2-monitor layout) the
two side-by-side screens are TOP-ALIGNED (no Y overlap) — matches the earlier
"works cleanly with 3rd screen off" observation. With beamer on (3-monitor),
the left monitor sits HALF-BELOW the right one, which is what produces the
Y-range overlap (`y:[1860,2520)`-style) that Weston mis-attributes/clamps.
So the overlap bug is purely a function of THIS PARTICULAR layout's vertical
offsets, not something inherent to having 3 monitors — a 3-monitor layout
with all tops aligned should not exhibit it.
Fixed open issue #1 from the prior session: `ticker.open_window`'s startup
void-recovery `elsif` branch was a single 0.2s-delayed check+correct shot,
which the prior session had already diagnosed as unreliable (a fresh
never-mapped window's own Weston initial-placement handshake can still be in
progress at 0.2s, so even the recheck can land in the void). Rewrote it to
poll every 0.2s up to 10 attempts (same cadence as the no-snapshot
settle-timer branch above it), calling `find_safe_position` fresh each
attempt and only giving up + logging after exhaustion. NOT YET LIVE-VERIFIED
against the real 3-monitor overlap layout (needs beamer on to reproduce) —
open issue #2 (the separate "shadow only, no content"/"no draw callback"
compositor-paint glitch that followed void-landing recoveries) is UNCHANGED,
still unconfirmed whether placement patience reduces or fixes it.
Left cfg/zenki/graphics-matrix/zenka-startup.v7 (on-demand
commented out) and cfg/zenki/v7/start-set-up.base
(`zenki.disabled = graphics-matrix`) AS-IS per taeki — confirmed unrelated to
ticker (graphics-matrix isn't referenced anywhere in ticker's modules), just
a leftover debug toggle from a prior session, taeki wants it disabled for now.

#,,..,,,,,..,,...,..,,,.,,,.,,.,,,.,.,.,.,...,..,,...,...,...,.,,,,.,,,,.,...,
#7PYFDFE2VYIKLH4X2IGONABJTZLMKU3ULITDIAAQX5XEYP555APOX6KQK2ONVTXDVZ5WWLPNRRSL6
#\\\|ILWD4R5G57TYGWJBBMWRKYACIRXMDGIXAZGH6DWDMU3D2DBKGOE \ / AMOS7 \ YOURUM ::
#\[7]4LY4QXMBKBC6R2QWXLW2BXDBQIYKZHOGFJBMVAPFYP5M75E4AWCA 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
