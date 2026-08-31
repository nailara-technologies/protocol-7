---
name: project-deps-tracking-var-relocation
description: "base.register_pm_deps writes per-zenka dependency touch-files directly into tracked cfg/zenki/<zenka>/deps/p-mod/ -- causes real, live-reproduced failures (read-only root installs like atom's nshell, dev-repo ownership hijacking via the EUID==0 chown-fixup path, and inconsistent init_modules/drop_privs ordering across the 124 zenki with deps/ dirs); fix is relocating the write+read path to var/, not a new zenka. Also covers retiring src/base.known_dependencies; base.list.subroutines is NOT dead code (actively updated by sourcecode.console.update-sub-list), see correction inline."
metadata:
  node_type: memory
  type: project
  originSessionId: fee6b203-065d-46ee-9e22-bac7aa31efd1
---

2026-08-31. Grew out of the user floating a "dependencies hybrid zenka"
idea (console + v7-started, consolidating `.deps/`, the 124 per-zenka
`cfg/zenki/*/deps/` dirs, `src/base.known_dependencies`, eventually
`bin/dependencies/*.sh`). Traced the actual mechanism during the
conversation and the real problem turned out much narrower and more
concrete than a new zenka — **no new zenka needed**, per the user's own
"maybe it is indeed obsolete" instinct, confirmed correct once the real
write-path was found.

## the actual bug, confirmed live

`src/base.register_pm_deps` (called automatically whenever a zenka loads
a perl module) writes per-module touch-file placeholders directly into
`$cfg_path/zenki/<zenka>/deps/p-mod/` — inside the **tracked** `cfg/`
tree. Line 78: `if (-w $mod_dir) { ...write... } else { push
@not_registered, ... }` — no fallback when that directory isn't
writable, just a silent drop + warning log.

**Three distinct real problems, one root cause:**

1. **Read-only root installs** — live-reproduced on host `atom`:
   `/usr/local/protocol-7/cfg/zenki/nshell/deps/p-mod/` owned
   `root:root` 755; `taeki` (non-root) running `v7.nshell` hits `<< no
   write access to cfg/zenki/nshell/deps/p-mod >>`, `Event` never gets
   registered.
2. **Dev-repo ownership hijacking** — `register_pm_deps`'s `$EUID==0`
   branch `chown()`s the touch-files to the zenka group (typically
   `protocol-7`). In `/data/projects/protocol-7/` (owned `taeki`), any
   zenka run that hits this branch as root reassigns ownership of files
   inside the dev's own git-tracked working tree away from them — same
   failure *class* as [[feedback-editing-p7-owned-data-files-reowns-them]]
   but caused by P7's own internal logic, not a hand-edit.
3. **init_modules/drop_privs ordering inconsistency** — per user, this
   is "mixed throughout the zenki currently": some `.v7` start files run
   `[init_modules]` (triggering `register_pm_deps`) before
   `[root.drop_privs:...]`, others drop first. Since the chown-fixup
   path only runs `if ($EUID==0)`, whether it's even reachable depends
   on each zenka's own file ordering — unpredictable, not a real
   guarantee.

**Consumers found (all hardcoded to the same `cfg_path`-based location,
would all need the read-side updated together with the write-side):**
- `src/base.register_pm_deps` (writer)
- `src/base.check_dependency_dirs` (dir creation + permission-fixup)
- `src/base.perlmod.all_registered` (reader)
- `AMOS7::deps::module::scan_zenki_pm_deps` (sys-deps' own scan,
  `data/lib-path/pm/AMOS7/deps/module.pm`)

## the fix (not yet started)

Relocate the write+read path to a `var/`-owned location (mirroring
`var/sys-deps/tracked.yaml`'s already-proven pattern, touched directly
this same session in `sys-deps.handler.install_reply`) instead of the
tracked `cfg/` tree. Whoever's actually running (root or already-dropped)
can write there without needing the chown-fixup dance at all — removes
sensitivity to init/drop-privs ordering and the dev-repo-ownership-
hijacking risk simultaneously, not just the read-only-install case.

**Also to retire, same theme, weaker reasons individually but same
direction:**

- `src/base.known_dependencies` — static, nothing auto-updates it, and
  being one global file it can't track a user-installed or user-written
  zenka's own dependencies at all (no way to extend it per-installation
  without editing the shared committed file). Already had one real bug
  fixed this session (stale `modules/` path, see
  [[topic-sys-deps-debian]]'s 2026-08-31 addendum) — this is the
  deeper reason it should go away entirely, not just get patched again.
  **Update, 2026-09-01**: the ACCESS-MECHANISM half of this is now fixed
  (K3 dispatch, task `v7-check-zenka-deps-jobqueue-and-binary-gap.yaml`,
  reviewed and verified) — `AMOS7::deps::module::load_known_deps` is now
  the single canonical accessor (confirmed zero remaining
  `<[base.known_dependencies]>` invocations anywhere in `src/`, including
  a second holder found beyond the original `v7.check_zenka_deps` case,
  `base.perlmod.install`), and it also gained a `binary` section (16
  binary-name -> debian-package mappings, closing the "detected but never
  installed" gap for `v7.check_zenka_deps`'s `@missing_bin`). The
  STALENESS concern above is still real and separate — fixing who reads
  the file doesn't fix whether its content stays current.

  **Bootstrap-ordering check, closed 2026-09-01**: `v7.check_zenka_deps`
  now routes apt installs to `debian.install-packages` via
  `<[protocol-7.route-send]>`, which only delivers to an already-connected
  session (`base.protocol-7.command.send.local`) — raised as a real open
  question whether this could deadlock for `cube` itself (the first zenka
  `v7.autostart_zenki` starts, before `debian`'s own `dependencies = cube`
  could be satisfied). Checked all 66 on-demand zenki's `start.cfg`:
  `dependencies = cube` is the near-universal pattern (61/66), and
  crucially **`sys-deps` itself declares only `dependencies = cube`** (no
  explicit `debian` dependency) yet its `sys-deps.cmd.install` already
  routes to `debian.install-packages` the identical way, in production,
  since earlier this session — direct proof that reaching an on-demand
  zenka by bare name via `route-send` needs only `cube` up, not a
  pre-declared dependency on the target itself. (`session`'s
  `dependencies = debian` is a second confirmation that depending on
  `debian` directly is itself a normal pattern.) So the only real edge
  case is `cube`'s own bootstrap, which is out of scope for this
  mechanism by design — that's `bin/p7-deps`'s pre-flight job, not
  something `v7`/`debian` are meant to self-resolve at runtime. Not a gap
  in the K3 dispatch above; closed, no action needed.

  **False alarm on ondemand-timeout-vs-long-install, closed 2026-09-01**:
  I initially suspected a real gap — `debian`'s `set_ondemand_timeout:420`
  (`sys-deps`'s is `:64`) looked too short for a genuinely slow apt
  install, and the idle-shutdown arm guard in
  `base.event.callback.io-idle-restart` (lines 33-71) only checks
  outstanding `$data{'route'}` entries and open producer streams —
  neither of which reflects a running `jobqueue` job. **Corrected by the
  user**: this is already solved structurally, not by a manual guard.
  `$data{'watcher'}{'io'}{'transfer'}` (`base.event.init_code:14`) is a
  real `Event->idle(...)` watcher — it only gets a chance to fire (and
  thus only re-arms the ondemand-shutdown timer) when the event loop has
  nothing else pending. A live `event.add_io` watcher on the apt child's
  stdout/stderr (the established pattern `debian.handler.apt_child_output`
  already uses) inherently keeps the loop non-idle for the whole
  subprocess lifetime — no jobqueue-specific check needed. The explicit
  `->start if not ->is_active` "nudge" calls in `base.handler.write`,
  `base.handler.input`, and `base.stream.close` exist only for the
  narrower edge case of state changing without going through the normal
  I/O path (e.g. a synthetic buffer write) — not a workaround for a
  missing background-job check. No action needed; don't re-raise this.

  Fuller picture from [[ondemand-heartbeat-upgrade]] (2026-08-24 rollout,
  already landed): `debian` was deliberately left **heartbeat-disabled**
  in that rollout, explicitly for "package-install duration uncertainty"
  (same bucket as `ext-pkg`/`ffmpeg`/`fs`/`melt`) — so there's no
  heartbeat-timeout exposure on it at all, by design. The other half of
  that same landed work is what makes the `Event->idle` mechanism above
  safe generally: `heart` probes are explicitly excluded from resetting
  `<base.ondemand.last_activity>`, and the idle timer arms with the
  *remaining* time since last real activity rather than the full window —
  so heartbeats can't artificially keep a zenka alive forever, while
  genuine subprocess I/O (not a heartbeat) correctly keeps it alive via
  `Event->idle` simply not firing during real work. `sys-deps` itself is
  heartbeat-*enabled* (17s default, in that rollout's "zero blocking
  code found" group) — consistent, since `sys-deps.cmd.install` returns
  `'deferred'` immediately rather than blocking on debian's reply.
  the file doesn't fix whether its content stays current.
- `src/base.list.subroutines` — **correction, 2026-08-31**: this is NOT
  static/unmaintained — it's actively updated by
  `src/sourcecode.console.update-sub-list` (confirmed: real file, real
  writer). Per user, its actual purpose: a security integrity safeguard
  — a known-good manifest meant to catch the case where a subroutine
  file is correctly signed AND still namespace-matches, but has actually
  been *removed from `src/`* and shouldn't load anymore (a stale-but-
  still-valid-signature resurrection risk). **Nothing currently consumes
  this data to actually perform that check** — the manifest gets
  maintained but the validation logic that would use it was never built.
  Retiring it was postponed for unrelated reasons (a stalled bigger
  redesign, see [[vision-tree-based-module-storage-and-namespace-manifests]]),
  not because the safeguard concept itself is unwanted. Separately, per
  user: will eventually connect to a BMW-checksum-for-all-files system
  (including non-Perl files like HTML/config that can't take an embedded
  AMOS7 signature footer without breaking syntax) — but that's a distinct,
  larger thread, not a reason this file is already dead today.

**`.deps/profiles.yaml` needs reorganizing, 2026-09-01**: separate file,
`bin/p7-deps`'s own data (deployment-scale profiles: `minimal`,
`runtime`, `network`, `cryptography`, `tools`, `zenka-common`,
`graphics-matrix`, `opencv`, `basic-remote-server`, `ai-models`) — not
the same thing as `base.known_dependencies` or the per-zenka
`cfg/zenki/*/deps/` declarations, but related enough to note here.
Surfaced while checking whether the 16 new binary->package mappings
(above) should also be transferred into this file: they shouldn't be —
all existing profiles here are Perl-module/library focused (apt+cpan
package lists), none are a natural fit for general utility binaries
(`ffmpeg`, `pciutils`, `kmod`, X11 nested-display tools, etc.), and
those are correctly zenka-specific — belong in the per-zenka declarative
system, not a "every fresh install gets this" baseline profile. Only
`cpanminus` looked like a plausible universal-baseline candidate (not
zenka-specific, though `base.perlmod.install_cpanm` already has its own
apt-or-manual-bootstrap fallback, so it may not strictly need to be
here either — undecided). Per user: the profile set itself is "still
slightly chaotic" and likely needs reorganizing — no concrete direction
yet, just confirmed as a known, real gap, not urgent.

## status

Fully traced, not implemented. Same treatment as the debian/sys-deps
async pipeline fix this session — worth a proper task file + dispatch
given it touches foundational bootstrap code used across all 124 zenki
with a `deps/` dir, not something to freehand at the tail of a long
session. `base.known_dependencies` and `base.list.subroutines`
retirement can follow once the `var/` relocation lands and (for
list.subroutines specifically) once the BMW-for-all-files checksum
system exists — don't retire either prematurely on its own.

#,,,.,,,.,,,,,,..,.,.,..,,,,,,.,,,,,,,.,.,,..,..,,...,...,.,,,...,..,,,..,,..,
#5HUATYRLJMS3GDH7NLOWM6GHXIZDVKEXL3WOKLJXDNJNJULWHHSIK2A2ZIRES6IMHU3FOHDLTG4RY
#\\\|QXMG35LIGMCFHDPS6OQ3WZKHNSMYRJJ7AFRQACC54WPOQKSPONO \ / AMOS7 \ YOURUM ::
#\[7]PXJ6S24Z7OLUPDR5XLIFWUNEVK6YE2ZLQVK6ALFLY2WSZWVC4QDA 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
