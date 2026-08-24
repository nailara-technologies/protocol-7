# dunst notification zenka — task

## status [ 2026-08-24 ] — drafted, de-risked by a manual smoke test, not started

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
STATUS: not started

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
STATUS: not started

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
STATUS: not started

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
STATUS: not started

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
STATUS: not started

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
STATUS: not started

## notes

- do not touch notify-osd/notify-osd.* in this task — parallel, not a
  replacement, per binding constraints above.
- if dunst also fails to render visibly on this host, that would be a
  strong signal the problem is structural to this WSLg setup (some
  compositing/window-manager gap affecting override-redirect popup windows
  generally, not specific to notify-osd's GTK3 rendering path) — worth
  documenting as its own finding rather than assumed away.
- a future native GTK3-based notifier (mentioned by user, not scoped here)
  would presumably reuse base.gtk.ensure_display directly (in-process, no
  spawned binary) rather than the open3-wrapper shape both notify-osd and
  dunst use — out of scope for this task, noted for whoever picks that up.

#,,,,,,..,...,.,.,,,,,,..,...,,,.,,,,,,.,,.,,,.,.,...,...,...,.,,,,,,,,,.,,.,,
#AGX72YTKRTLX3MDFGS3RC5ZSRW3KW7LK6WRYDDCXFDW3ZV4DKC6ACIJBTR62X2MFLHRBNEETLKU4E
#\\\|E4SI3GXCYN7JW2JOSJV67DEGXUL7CFELQMDMOGW4FENNLQF4RHQ \ / AMOS7 \ YOURUM ::
#\[7]DZROMEHUH7MCMDOVRL6JB4HEQ3DRR2TYT4ERGL72SV5UUQHHHMCY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
