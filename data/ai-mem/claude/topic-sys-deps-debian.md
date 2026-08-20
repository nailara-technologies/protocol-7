---
name: topic-sys-deps-debian
description: "sys-deps zenka + debian zenka architecture — root apt-child, AptPkg probing, cpanm root-only, auto-scan"
metadata: 
  node_type: memory
  type: project
  originSessionId: 2ca0eefc-058c-451a-bf77-a8393a00d2ab
---

## sys-deps zenka (session 47 — 2026-05-23)

live and working: on-demand startup, 64s idle shutdown, `sys-deps.state`/`check`/`missing`/`install`

### architecture

- `sys-deps` zenka: on-demand, scans `cfg/zenki/*/pm-dep/` and `os-dep/` dirs
- `sys-deps.cmd.install` → routes to `debian.install` via `protocol-7.route-send` (fire-and-forget)
- `debian.cmd.install` auto-scans if registry is empty (handles fresh on-demand startup)
- `AMOS7::deps::*` shared library: `module.pm`, `os_package.pm`, `debp.pm`, `dist_upgr.pm`
- `v7.check_zenka_deps` — v7 pre-start dep check hook

### debian zenka root apt-child pattern

debian zenka drops privs (`[root.drop_privs]`) so can't run apt-get directly.
solution: `debian.start.apt_child` forks a root perl child **before** drop_privs.

start file order:
```
[init_modules]
[debian.start.apt_child]        ← forks root child while still root
[root.drop_privs:<amos-user>]
[base.net.connect:'unix']
```

child protocol (line-based via IPC::Open2):
- parent → child: `install pkg1 pkg2\n`
- child → parent: `> <apt-get output line>\n` per line, then `< <exit_code>\n`
- parent logs each `>` line at level 1, reads until `< N`

`base.debian.install_package`:
- if `<debian.apt_child.w_fh>` defined: use root child
- elif `$> == 0`: direct apt-get
- else: skip with level-1 log (not root, no child)

### AptPkg::Cache probing

`debian.parent.callback.check_package_installed` uses `AptPkg::Cache->new` instead of dpkg-query backtick.
`AMOS7::deps::debp::probe_apt` uses `AptPkg::Cache` with dpkg-query fallback.
AptPkg is `libapt-pkg-perl` — already installed, no extra deps.

### cpanm — root-only, system-wide

`debian.parent.install_missing` cpanm block skips entirely when `$> != 0`, logs at level 1.
Uses `--no-man-pages` to suppress doc install noise.
Each module installed independently — one failure does not block others.

### stale pm-dep cleanup

- `letsencr/pm-dep/Crypt__Random` — removed (declared but never used, session leftover)
- `ssh/pm-dep/Modules::Refresh` — has literal `::` in filename + wrong name (should be `Module__Refresh`)
  → pattern: pm-dep filenames use `__` not `::`, and module name must be exact

### tested and confirmed working (session 48b)

both sys-deps zenka and debian zenka tested together in session 48b — confirmed working end-to-end.

### auto-installation chain — planned layered extensions

current state: sys-deps tracks declared deps (pm-dep/os-dep/ dirs + base.known_dependencies).

planned layers (add step by step, each independently useful):
1. **external call wrappers** — wrap `system()`, `qx//`, backticks to auto-register invoked binaries
   into sys-deps registry at runtime (no manual declaration needed)
2. **perl module dependency scanning** — scan `use`/`require` at module load time →
   auto-register → sys-deps verifies/installs before zenka starts
3. **auto-install on demand** — sys-deps hooks into zenka startup: missing deps → install → retry
   (extends existing `v7.check_zenka_deps` pattern)

key: each layer works standalone and can be verified before building the next one.

### Debian::Apt::PM (planned)

declared in `debian/pm-dep/Debian__Apt__PM` — will replace `resolve_cpan_to_debian` hardcoded map.
needs: cpanm install (not in apt repos) + pmindex apt source + `apt-pm update`.

### task zenka fix (same session)

`reasoning.branch.*` not loaded → `task.post_init` timer callback failed at startup.
fix: added `reasoning.branch` to `modules.load` in `cfg/zenki/task/start`.
also added `cfg/zenki/task/source/reasoning.branch` empty source marker.

#,,..,,.,,,,,,.,,,,,,,,,,,,..,,.,,,..,,,,,,.,,..,,...,...,..,,,,,,.,,,..,,.,.,
#LP2V4BAIBATAYE4SUXGONX7L54AFA6MCD6R6R6PIRT5YAGWMNLMGI6J2T5LOZPDN3YXJBN5OYSDMY
#\\\|R4MWJUC46ZY45UBRNDRXIZGQ7YWAD76G2NA62V73M3SNSR4BK4P \ / AMOS7 \ YOURUM ::
#\[7]JLLDV5PVYYAC4URCKKGQQQYK44VSA5OLTUYYIEPYEJRVQKQNVODA 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
