---
name: async-window-startup-transition
description: completing the async coordinate-request transition — window startup moves from sync start-file calls to dependency-resolved callbacks; ticker reference built 2026-06-24
metadata: 
  node_type: memory
  type: project
  originSessionId: e46832a1-30ee-4a35-b48d-ba1e45979b28
---

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
NOT YET COMMITTED — user signs the module set, then commit as the ticker
resilience batch. STILL OPEN: the centered-on-WRONG-monitor regression (3rd
monitor on) — geo_ready shapes the correct rect [1920,2448,5360,2520] but
ticker.open_window doesn't apply it as INITIAL placement before show_all
(gravity+default_size+move pre-map like the menu); distinct open_window pass.
<<<**

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
  removed), configuration/zenki/ticker/start, ticker subroutine.white-list.
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
configuration/zenki/ticker/start, modules/ticker.startup (main_loop removed).
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

#,,.,,.,,,...,,.,,..,,.,,,.,.,..,,,,.,...,..,,..,,...,...,..,,,,.,,,.,.,.,..,,
#N2DKABVDJGN5S7M6NCOPC6ZTTZVSVITGAP3375WKJYSKM6Z4DD7LFDPZE7K4FKENROWWNZPI6CU64
#\\\|TIWIC7EAZGZ4S7BQQ53T7EB2DXPWM4ZUNZ4SPLFBNSBGYSGC37B \ / AMOS7 \ YOURUM ::
#\[7]CHTKJAQ3NHO3Q4SFAJ6D4QSVV6DUVZBJZB6FQN6FTGVGZMDEPQAI 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
