# dunst notification zenka — task

## status [ 2026-08-24 ] — drafted, not started

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
  version of this file, not as a later patch. Include the same
  `GDK_BACKEND=x11` / `delete $ENV{'WAYLAND_DISPLAY'}` guard even though
  dunst is cairo/pango rather than GTK3 — dunst links `libgdk-pixbuf`/
  `libwayland-client` per its apt dependencies, so it may still probe
  Wayland at startup; cheap insurance, matches the established house
  pattern (`base.gtk.ensure_display`).
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
'/usr/bin/dunst' (apt's real install path — confirm via `dpkg -L dunst`
once installed rather than assuming), with a base.file.which-based fallback
(not a hardcoded find /usr/lib/ search — that pattern is already stale in
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
$ENV{'WAYLAND_DISPLAY'} before spawning <dunst.path.exec_bin> via open3.
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
inline base.handler.child_output.simple usage (or dbus.handler.
process_output's shape if dunst's output needs custom parsing — check
actual dunst stdout on this system first via a manual `dunst` run before
deciding). Start with an empty or minimal log_whitelist and add entries
only for warnings actually observed running dunst here, not speculatively.
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
before creating a new one) so `p7-deps` can install it.
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

#,,,,,,,.,.,.,,,,,.,.,...,.,.,,,,,..,,..,,,,.,.,.,...,...,...,,,.,.,.,,..,..,,
#E442BABRCK6M3WCZOOFOVPKIOYTEA37YD7KNYY2BUKQU2ZDGBEPW4F6PVGRVGJTLCJB6RUDBQM5XU
#\\\|ODFUMJNCLJHJWQGI6ADPTLVJDN2NQYYTFRZXFVIX2CLZS3ZCUBW \ / AMOS7 \ YOURUM ::
#\[7]IVO4EDVXMV3SCQODM4OWQWRHOAFXKXVEWQICKOEIYEPS7MDCF4BY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
