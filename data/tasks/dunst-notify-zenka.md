# dunst notification zenka — task

## status [ 2026-08-24 ] — phases 1+2+3 complete, dunst renders visible,
## properly-styled dark popups on this WSLg host; one follow-up defect
## remains (randomized position, structural/compositor-level, see bottom)

## context

design: [[topic-smtpd-actionable-mail-channels-notify]]
source: same-session follow-on, 2026-08-24 — after fixing the dbus regex bug
        and notify-osd's missing child-pid registration (commit 80320f339),
        notify-osd reaches `online` reliably and notify-send succeeds
        end-to-end (no more `ServiceUnknown`), but the popup itself still
        doesn't render visibly on this WSLg host. Root cause not found —
        likely an X11/compositing quirk in notify-osd's own GTK3 bubble
        drawing, not a protocol-7 bug (see topic-smtpd-actionable-mail-
        channels-notify.md, problem 3 section, for the full trail:
        `dnd_is_idle_inhibited` GNOME-sessionmanager warning, confirmed X11
        protocol + D-Bus traffic via strace, GDK_BACKEND=x11 forced with no
        change).

user direction: rather than keep debugging notify-osd's rendering blind,
stand up `dunst` (a much simpler cairo/pango-based notification daemon,
`Provides: notification-daemon` in apt, not currently installed) as a
**parallel**, not replacement, implementation. Both zenki coexisting is
fine — a future native GTK3-based notifier is also plausible once real
control over rendering (features neither notify-osd nor dunst can deliver)
is actually needed. This task only stands up the dunst zenka; it does not
remove notify-osd or its zenka.

**binding constraints:**
- do not delete or disable `notify-osd`/`notify-osd.*` — parallel
  implementations, operator picks which is actually started.
- `dunst` and `notify-osd` both register the same D-Bus well-known name
  (`org.freedesktop.Notifications`) — they must never both be started at
  the same time against the same session bus (last one to register wins or
  is refused, depending on bus policy; either way it's not useful to run
  both). This is an operational rule (don't `v7.start` both), not something
  to enforce in code for this task.
- `notify.cmd.message`/`.loves`/`.warn`/`.info`/`.msg_reload` are backend-
  agnostic already (they just shell out to `notify-send`, which talks to
  whatever implements `org.freedesktop.Notifications` on the bus) — no
  changes needed there regardless of which daemon is running.

## live smoke test (2026-08-24, informs the approach below)

`dunst` (and `dunstctl`/`dunstify`) turned out to already be installed on
this host (`/usr/bin/dunst`), and running it bare from an interactive shell
(no p7 wiring at all) gave real, useful signal rather than needing to guess:

```
CRITICAL: g_water_wayland_source_get_display: assertion 'self != NULL' failed
CRITICAL: g_water_wayland_source_set_error_callback: assertion 'self != NULL' failed
WARNING: failed to create display
WARNING: Couldn't initialize wayland output. Falling back to X11 output.
WARNING: Could not find theme AdwaitaLegacy
Xlib:  extension "MIT-SCREEN-SAVER" missing on display ":0".
CRITICAL: [dbus_cb_name_lost:1438] Cannot connect to DBus.
```

Reading this precisely: dunst tries Wayland FIRST, fails cleanly (the two
"CRITICAL" lines are just dunst's own null-checks on a failed connect
attempt, not a crash), and falls back to X11 automatically on its own --
**no `GDK_BACKEND=x11` forcing is required for dunst** the way it was for
notify-osd (unlike notify-osd, dunst doesn't need to be told to skip
Wayland; it tries and recovers by itself). The theme and MIT-SCREEN-SAVER
warnings are cosmetic/non-fatal. The one real, fatal line --
`Cannot connect to DBus` -- is fully expected and NOT evidence against this
approach: a bare interactive shell never has `DBUS_SESSION_BUS_ADDRESS`
pointing at the `dbus` zenka's ad-hoc bus. This is exactly the gap
`base.X-11.get_dbus_addr` fills for `notify-osd`/`notify` today (sets
`$ENV{'DBUS_SESSION_BUS_ADDRESS'}` from the live dbus zenka's actual
socket) -- confirms the "mirror notify-osd's zenka shape" approach below is
the right one, not a new unknown. Binary paths are also now confirmed
directly rather than needing `dpkg -L` later: `/usr/bin/dunst` (daemon),
`/usr/bin/dunstctl` (control CLI, not needed for this task),
`/usr/bin/dunstify` (a notify-send-compatible CLI, also not needed --
`notify.cmd.*` already uses plain `notify-send`, which works against
whichever daemon owns `org.freedesktop.Notifications`).

## from `man dunst` -- relevant CLI/config knowledge

- `dunst -config FILE` uses an explicit config file and DISABLES dunst's own
  search for others -- worth using explicitly in `dunst.startup`'s open3
  args rather than relying on ambient discovery. Without `-config`, dunst
  searches `$XDG_CONFIG_HOME` (`$HOME/.config` if unset) then
  `$XDG_CONFIG_DIRS` (`/etc/xdg` if unset) for `dunst/dunstrc` -- under
  `<system.AMOS-user>` (dropped privs, per zenka.v7), that account's `$HOME`
  may not have any dunst config at all, silently falling back to system
  defaults (`/etc/xdg/dunst/dunstrc`). That's a workable default for phase
  1, but an explicit `-config` pointing at a project-owned dunstrc (branding
  -- timeout, icon size/position, colors matching protocol-7's palette) is
  the more deliberate, reproducible choice and worth a follow-up once the
  basic zenka is running; don't block phase 1 on writing that config file.
- `-verbosity (crit|warn|mesg|info|debug, default mesg)` controls dunst's
  OWN log verbosity independent of `-print` (which echoes actual
  notification content to stdout, useful for a future logging/debug
  command but not needed for phase 1). Passing `-verbosity warn` explicitly
  would keep `dunst.handler.process_output`'s whitelist smaller/more
  predictable than relying on the 'mesg' default.
- the man page itself confirms the existing binding constraint in this
  task, not just this project's own reasoning: "This is not recommended
  when multiple notification daemons are installed, because D-Bus will not
  know which one to start" (re: D-Bus-triggered autostart -- doesn't apply
  to our explicit-spawn approach directly, but same underlying reason
  `notify-osd`/`dunst` must never both be started against the same bus).
- `dunstctl set-paused true/false` (or SIGUSR1/SIGUSR2, `dunstctl` is
  preferred per the man page -- signal meanings aren't guaranteed stable)
  is a real pause/resume control surface dunst has that notify-osd doesn't
  expose the same way. Not needed for parity with notify-osd, but worth
  remembering as a natural `dunst.cmd.pause`/`.resume` extension point for
  later (e.g. wired to a future "do not disturb" feature) -- out of scope
  for this task.

## approach

mirror `notify-osd`'s zenka shape as closely as possible — it's the
existing, just-fixed precedent for "wrapper zenka spawns a real binary that
needs DISPLAY + DBUS_SESSION_BUS_ADDRESS, tracks its child PID with v7":

- `cfg/zenki/dunst/zenka.v7` — same skeleton as `cfg/zenki/notify-osd/
  zenka.v7` (`[load_config_file:'X11-vars']`, `[base.X-11.get_display]`,
  `[base.X-11.get_dbus_addr]` before starting the binary), swap
  `[notify-osd.startup]` for `[dunst.startup]`.
- `src/dunst.init_code` — binary path detection, mirror `notify-osd.
  init_code`'s shape but do NOT reproduce its narrow fallback bug: the
  current `notify-osd.init_code` fallback search
  (`qx(find /usr/lib/ -name notify-osd)`) only searches `/usr/lib/`, which
  is already stale now that the real path moved to `/usr/libexec/` — for
  dunst, default to `/usr/bin/dunst` (apt's actual install path) and make
  the fallback search a real PATH-based lookup (`base.file.which`, already
  whitelisted/used elsewhere — see `notify.init_code`'s
  `<[base.required_bin_path]>->('notify-send')` for the established, better
  pattern) instead of a hardcoded single directory.
- `src/dunst.startup` — mirror `notify-osd.startup`'s open3 spawn, but
  learn from the bug just fixed there: call
  `<[base.zenki.report_child_pid]>->(<dunst.pid>)` from the very first
  version of this file, not as a later patch. `GDK_BACKEND=x11` /
  `delete $ENV{'WAYLAND_DISPLAY'}` is OPTIONAL for dunst (unlike
  notify-osd) -- confirmed live: dunst tries Wayland, fails cleanly, and
  falls back to X11 on its own. Setting it anyway is harmless and silences
  two cosmetic startup warnings, so still worth including for a clean log,
  but it is not load-bearing here the way it was for notify-osd.
- `src/dunst.handler.process_output` — mirror `dbus.handler.process_output`/
  notify-osd's `base.handler.child_output.simple` usage for logging dunst's
  stdout/stderr; dunst is typically quiet once running, so the whitelist
  will probably stay short — don't invent noise-suppression entries that
  don't correspond to real observed output (mirrors the mistake avoided by
  reading actual output before writing whitelists, not guessing).
- `cfg/zenki/dunst/subroutines.load-early` — regenerate with
  `bin/dev/gen-sub-whitelist dunst` per the standard header convention seen
  in every other zenka's whitelist file (confirmed present in notify-osd's
  own file) — do not hand-write this list from scratch.
- `cfg/zenki/cube/access.zenki` — add `access.cmd.usr.dunst = dbus.
  socket_address v7.register_child` (exact same two grants notify-osd
  needed, for the exact same reasons: fetching the dbus zenka's address,
  registering the child PID).
- `.deps/profiles.yaml` and/or `cfg/zenki/dunst/deps/` — dunst is an apt
  package, not a CPAN module; needs an `apt: [dunst]` entry somewhere
  reachable by `p7-deps` (check whether `zenka-common` or a new profile
  section is the right home — dunst is desktop/notification-specific, not
  a generic zenka dependency, so probably its own small profile or grouped
  with `notify`/`notify-osd` if such a grouping already exists — verify
  before assuming).

## phase 1 — dunst zenka scaffold

### task 1.1 — cfg/zenki/dunst/zenka.v7 + directory structure

```
## dispatch + prompt
create cfg/zenki/dunst/zenka.v7 mirroring cfg/zenki/notify-osd/zenka.v7's
structure exactly (load_config_file shared-params + X11-vars, modules.load
= auth.client net protocol io.unix ui dunst, drop_privs to
<system.AMOS-user>, base.net.connect, base.X-11.get_display,
base.X-11.get_dbus_addr, then [dunst.startup] in place of
[notify-osd.startup], base.get_session_id, zenka.loop). Confirm whether
dunst needs its own on-demand timeout/restart-disabled flags matching
notify-osd's conventions (check cfg/zenki/notify-osd/start.cfg for any such
settings) before assuming zenka.v7 alone is sufficient.
```
STATUS: done — `cfg/zenki/dunst/zenka.v7`, `cfg/zenki/dunst/start.cfg`
(dispatched to Kimi, k3-256k; live-verified clean startup end-to-end)

### task 1.2 — src/dunst.init_code

```
## dispatch + prompt
create src/dunst.init_code: default <dunst.path.exec_bin> to
'/usr/bin/dunst' (confirmed live on this host, no need to guess via
`dpkg -L`), with a base.file.which-based fallback (not a hardcoded
find /usr/lib/ search — that pattern is already stale in
notify-osd.init_code, don't propagate it to new code). die with a clear
message naming the apt package ('dunst') if not found, matching
notify.init_code's existing die message style
("please install 'notify-osd'").
```
STATUS: done — `src/dunst.init_code`

### task 1.3 — src/dunst.startup

```
## dispatch + prompt
create src/dunst.startup mirroring notify-osd.startup's open3-based spawn:
set $ENV{'DISPLAY'}, $ENV{'GDK_BACKEND'}='x11', delete
$ENV{'WAYLAND_DISPLAY'} before spawning <dunst.path.exec_bin> with
'-verbosity', 'warn' as args (see "from man dunst" section above -- keeps
startup logging predictable without relying on the 'mesg' default) via
open3.
IMPORTANT, do not skip: call <[base.zenki.report_child_pid]>->(<dunst.pid>)
right after confirming the pid, in this FIRST version of the file — this
was a bug fixed in notify-osd.startup after the fact (v7 couldn't
track/kill the real binary on restart without it), don't reintroduce it
here by omission. Register an event.add_io handler
(src/dunst.handler.process_output, task 1.4) for the child's stdout/stderr
the same way notify-osd.startup does.
```
STATUS: done, then AMENDED live — `src/dunst.startup`. Kimi's version
matched this prompt exactly (GDK_BACKEND=x11 forced, WAYLAND_DISPLAY
deleted, report_child_pid called immediately) and worked without errors,
but rendered NO visible popup -- same symptom as notify-osd. Live
investigation found the real fix: point dunst at the ACTUAL wslg wayland
socket (`/mnt/wslg/runtime-dir`, `WAYLAND_DISPLAY=wayland-0`) instead of
forcing X11 -- v7 hides the real socket via a sandboxed `XDG_RUNTIME_DIR`
for other GTK zenki (see `base.gtk.ensure_display`), which was blocking
dunst from ever reaching wayland at all. The file now checks for the real
socket (`-S '/mnt/wslg/runtime-dir/wayland-0'`) and only falls back to the
original X11-forcing behavior if it's absent. This DOES render a visible
popup -- see phase 3 and the notes below for the two remaining defects.

### task 1.4 — src/dunst.handler.process_output

```
## dispatch + prompt
create src/dunst.handler.process_output mirroring notify-osd.startup's
inline base.handler.child_output.simple usage. A manual `dunst` run on
this host already showed the real startup output to whitelist as benign:
"Couldn't initialize wayland output. Falling back to X11 output.",
"Could not find theme AdwaitaLegacy", and the Xlib MIT-SCREEN-SAVER
extension warning are all non-fatal noise once DBUS_SESSION_BUS_ADDRESS is
actually set correctly (which it wasn't in that manual test — see the
"live smoke test" section above); confirm the DBus-connected startup
sequence looks clean once wired through the real zenka before finalizing
this whitelist, since a correctly-connected run may emit different lines
than the disconnected manual test did.
```
STATUS: done, then AMENDED live — `src/dunst.handler.process_output`. The
DBus-connected run under real wayland (see task 1.3's amendment) emitted
two NEW warnings not seen in the earlier disconnected/X11-fallback manual
test: `compositor doesn't support zwlr_layer_shell_v1, falling back to
xdg_shell` and `compositor doesn't support zwlr_foreign_toplevel_v1`.
Confirmed non-fatal (notifications still work) and added to the
whitelist. These two lines are actually the most important diagnostic
output this task produced -- see phase 3 / notes.

## phase 2 — wiring

### task 2.1 — access.zenki + subroutines.load-early + deps

```
## dispatch + prompt
add `access.cmd.usr.dunst = dbus.socket_address v7.register_child` to
cfg/zenki/cube/access.zenki (same two grants notify-osd needed and for the
same reasons). Generate cfg/zenki/dunst/subroutines.load-early via
`bin/dev/gen-sub-whitelist dunst` (do not hand-write). Add an apt: [dunst]
entry to .deps/profiles.yaml in whatever profile section is the right home
(check whether notify/notify-osd already have a shared profile grouping
before creating a new one) so `p7-deps` can install it on other hosts --
dunst is already installed on this dev host, so this step doesn't block
testing here, but still needs doing for reproducibility elsewhere.
```
STATUS: done — `access.cmd.usr.dunst` added to `cfg/zenki/cube/
access.zenki`; `cfg/zenki/dunst/subroutines.load-early` generated via the
real tool; `apt: dunst` added to `.deps/profiles.yaml`'s `X11-Desktop`
profile (grouped with `notify-osd`, which already lived there). Also
needed but NOT anticipated in this task's original scope: an
`auth.setup.usr.dunst = :zenka:` entry in `cfg/zenki/cube/auth.zenki`
(separate from `access.zenki` -- this one governs whether cube recognizes
`dunst` as a valid zenka-class auth identity at all, every other zenka in
that file has its own line) -- added live, both `cube` and `v7` needed a
reload to pick it up. Also switched `cfg/zenki/notify/start.cfg`'s
`dependencies = notify-osd` to `dependencies = dunst` for this host's
current parallel-testing state (notify-osd was stopped to free the
`org.freedesktop.Notifications` bus name for dunst) -- this is a
per-deployment operator choice, not something this task should have
hardcoded either way; whichever backend is actually running needs to be
the one `notify` depends on, or its on-demand startup loops trying to
reach a dependency that never comes online.

## phase 3 — verification

### task 3.1 — end-to-end live test

```
## dispatch + prompt
install dunst (`p7-deps` after task 2.1's profile entry lands, or manually
first to unblock testing sooner). p7c v7.start dunst, confirm `online` via
p7c v7.list zenki dunst. p7c notify.loves '<title>' '<message>' and confirm
a VISIBLE popup renders on screen (not just "message sent" / no error --
that already succeeds with notify-osd and still doesn't render; visual
confirmation is the actual bar here). p7c v7.stop dunst then
`ps aux | grep dunst` to confirm the real binary is gone too (proves the
report_child_pid wiring actually works, don't just trust the zenka status
line). p7c v7.restart dunst and repeat the visible-popup test to confirm a
clean restart cycle.
```
STATUS: done — `p7c v7.start dunst` reached `online` cleanly (after also
adding the `auth.zenki` entry noted in task 2.1). First `notify.loves`
test succeeded with NO error but ALSO no visible popup -- same as
notify-osd, under the originally-planned X11-forced startup. Live
investigation (not scoped in this task's original phase 3 prompt) found
and applied the wayland-socket fix described in task 1.3's amendment,
after which the popup rendered visibly, top-right on the primary monitor,
large correct `loves.png` icon. `p7c v7.stop dunst` + `ps aux | grep
dunst` confirmed the real binary dies with the zenka (report_child_pid
wiring works). Two real defects found; styling was fixed live (project
dunstrc, see notes), notification position remains randomized (structural
compositor limitation, not fixed).

## notes

- do not touch notify-osd/notify-osd.* in this task — parallel, not a
  replacement, per binding constraints above. (notify-osd was `v7.stop`ped
  during live testing purely to free the `org.freedesktop.Notifications`
  bus name for dunst -- an operational step, not a code change.)
- **the actual root-cause finding of this task**: dunst only renders
  visibly on this WSLg host when connected to the REAL wayland socket
  (`/mnt/wslg/runtime-dir`, `WAYLAND_DISPLAY=wayland-0`), not under X11
  (whether via XWayland directly or dunst's own X11 fallback). Once
  connected via real wayland, dunst logs `compositor doesn't support
  zwlr_layer_shell_v1, falling back to xdg_shell` -- WSLg's Weston doesn't
  implement the wlr-layer-shell protocol proper anchored notification
  popups use. This is very likely the same underlying gap that made
  notify-osd's popup render nothing at all (X11/XWayland path, no wayland
  fallback available to it) -- worth treating as resolved-by-explanation
  rather than a remaining mystery, see
  `topic-smtpd-actionable-mail-channels-notify.md`.
- **defect 1, not fixed**: notification position is randomized across the
  screen -- plain `xdg_shell` toplevels (the fallback from
  `zwlr_layer_shell_v1`) have no anchor/position hint, so Weston places
  them itself with no consistent policy observed. Likely the same flavor
  of issue as the still-open `gtk-wsl-window-positioning` investigation
  (Wayland compositors generally don't let clients position their own
  toplevels; layer-shell exists specifically to give panels/notifications
  an exception to that rule, which this compositor doesn't implement).
  Possible angles for whoever picks this up: check for a newer
  Weston/WSLg build with layer-shell support, or check if dunst has a
  wlr-layer-shell-independent positioning fallback config option.
- **defect 2, FIXED live**: default dunst theme was light-mode (green-blue
  background, light grey frame). Fixed with a project-owned `cfg/zenki/
  dunst/dunstrc` passed via `-config` in `dunst.startup`. Two real gotchas
  found getting there, both worth remembering for anyone touching this
  file again:
  - **`-config` disables dunst's OWN config search entirely** (per man
    dunst) -- a MINIMAL override file doesn't just override colors, it
    loses every other shipped default too (font, icon size, padding),
    falling back to dunst's much smaller compiled-in minimums instead of
    `/etc/xdg/dunst/dunstrc`'s generous values. Confirmed live: the whole
    notification, icon included, rendered tiny before `padding`/
    `min_icon_size`/`max_icon_size`/`font` were added explicitly (values
    carried over from the shipped config, see the dunstrc's own comments).
  - **Pango point-sizes render far smaller than expected under this WSLg
    Wayland session** -- confirmed via a live DPI-scale test: 11pt was
    "far too small", 24pt was "very large", 17pt landed about right. Pixel-
    based settings (`min_icon_size`, `width`) were NOT affected, only the
    point-based `font` size -- consistent with a compositor DPI/scale-
    factor mismatch specific to Pango's text layout under this session,
    not a font-loading failure (confirmed separately: `fc-match "White
    Rabbit"` resolves correctly even reproducing dunst's exact
    environment). If a future WSLg/Weston update changes this scale
    factor, `font = White Rabbit Regular 17` may need retuning again --
    treat 17 as empirically-fit-to-this-host, not a portable constant.
  - custom project font also wired up: `data/ttf/console/white-rabbit.
    flipped.ttf` ("White Rabbit" family) is made discoverable to Pango/
    fontconfig WITHOUT installing it system-wide, via a small fontconfig
    snippet `dunst.startup` regenerates fresh at every zenka boot
    (`/tmp/protocol-7-dunst-fontconfig/fonts.conf`, chains in the real
    `/etc/fonts/fonts.conf` via `<include>` then adds just this one font
    dir) and points `$ENV{FONTCONFIG_PATH}` at it before spawning dunst.
  - final settled `dunstrc` values, for reference: `width = (300, 777)`
    (auto-sizes to content within that range), `horizontal_padding = 14`,
    foreground colors deliberately kept well short of white/pure-grey per
    this user's real screen-brightness sensitivity (see `[[user-screen-
    brightness-sensitivity]]`) and pushed toward a blue/violet
    "blacklight" hue rather than neutral grey (`#8070e0` for
    urgency_normal, dimmer/warmer variants for low/critical) -- all tuned
    live against the actual rendered output, not guessed.
- a future native GTK3-based notifier (mentioned by user, not scoped here)
  would presumably reuse base.gtk.ensure_display directly (in-process, no
  spawned binary) rather than the open3-wrapper shape both notify-osd and
  dunst use — out of scope for this task, noted for whoever picks that up.

#,,..,.,,,,..,.,.,.,,,..,,,,,,,,,,...,,..,.,,,.,.,...,...,...,,,.,,,.,.,.,.,.,
#OMBTTEKWLRJN2ZS6WCE7EQQXD4CR7WHGGXMO6PCSL6UOASPDHFJBSGFDBRRMRZQT2PGDODBPKO66C
#\\\|XRROVFHTQ64IFKNW3I3OYONG27RWS36SHQYLBSM4IAHQARTSKMH \ / AMOS7 \ YOURUM ::
#\[7]RTJYPG6BVK3XKHYI44OW2NXHBMLG5O5RZW7NJ5ZYHEHARS4CQQAI 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
