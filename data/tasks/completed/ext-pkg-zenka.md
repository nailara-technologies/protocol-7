# ext-pkg zenka — task

## status [ 2026-07-29 ] — phase 1 DONE, live-verified (e9b437f6c); phase 2 (unified coverage audit) not started

## context

related: [[build-zenka]], os-pkg zenka (cfg/zenki/os-pkg/,
currently a stub — src/os-pkg.init_code is just `0;`)
source: dependency-coverage discussion 2026-07-29 — while scoping
build-zenka's recipe registry, kimi-cli and claude turned out to be
normal package-manager packages (pip/npm), not unpackaged software, so
they don't belong in build-zenka's git-build/tarball-extract/vendor-deb/
pip-venv schema. they need a home that speaks pip and npm the way
os-pkg speaks apt and .deps/profiles.yaml speaks apt+cpan.

naming: parallel to `os-pkg` ("OS-distro package installer") — `ext-pkg`
covers package-manager ecosystems EXTERNAL to the OS distro: pip, npm,
uv tool (cpan technically fits this shape too — .deps/profiles.yaml
already covers it under bin/p7-deps; whether cpan moves under ext-pkg
or stays where it is is an open question for task 1.2, not decided
here).

the goal stated during scoping: a user should never have to manually
look up a source, fetch it, and install it by hand because the thing
they need falls into a categorical gap between the project's automated
dependency coverage systems. `.deps/profiles.yaml` + os-pkg cover
apt/cpan. build-zenka covers unpackaged source/tarball/vendor-deb/venv
installs. ext-pkg fills the remaining gap: anything installable via a
language/tool package manager that isn't apt or cpan.

first two real entries, both currently manually-installed on this host:

    kimi-cli  — `pip install kimi-cli` (or `uv tool install kimi-cli`,
                which is how it's actually installed today: shim at
                ~/.local/bin/kimi → ~/.local/share/uv/tools/kimi-cli/)
    claude    — `npm install -g @anthropic-ai/claude-code` (installed
                today via claude's own self-managing installer instead:
                shim at ~/.local/bin/claude →
                ~/.local/share/claude/versions/2.1.220)

both are self-updating once installed — this shapes the lifecycle
contract (see goals below), not just the install step.

## goals

1. `ext-pkg.<manager>.check` / `ext-pkg.<manager>.install`: given a
   package name, check presence+version via the declared package
   manager (pip, npm, uv tool), install if absent
2. install-if-missing ONLY, never force-reinstall/upgrade: these tools
   manage their own updates (kimi-cli via uv tool upgrade path, claude
   via its own versions/ directory and updater) — ext-pkg's job is
   bootstrap onto a fresh machine, not ongoing version management
3. registry entries for kimi-cli (pip) and claude (npm) as the first
   two real, currently-manually-installed dependencies this replaces
4. coverage-audit hook: the entries here should be visible from the
   same status view as `.deps/profiles.yaml` (bin/p7-deps status/check)
   and build-zenka's recipe registry — see task 2.1
5. everything local — no build step, no docker, just package-manager
   invocation; this is deliberately the simplest of the three systems

## phase 1 — zenka scaffold + package-manager backends

### task 1.1 — create ext-pkg zenka
```
## dispatch + prompt
create cfg/zenki/ext-pkg/ following the start.cfg +
start script pattern from cfg/zenki/os-pkg/ (closest existing
sibling — same "given a package name, install it" shape, just a
different package-manager family). access.zenki pattern from
cfg/zenki/cube/ or cfg/zenki/transport/. bootable,
stoppable, registered. no modules yet.
```

### task 1.2 — registry format + package-manager backends
```
## dispatch + prompt
design a registry: one yaml file per external package under
cfg/zenki/ext-pkg/packages/<name>.yaml — fields: package
manager (pip | npm | uv-tool), package name, presence-check command
(e.g. `which kimi && kimi --version`), install command. decide during
this task whether cpan (currently under bin/p7-deps /
.deps/profiles.yaml) should also register here as a fourth manager for
a single unified external-package view, or whether it stays where it
is — document the decision either way, don't leave it implicit.
encode kimi-cli (pip/uv-tool) and claude (npm) as the first two
entries, matching how they are ACTUALLY installed on this host today
(uv tool install for kimi, claude's own installer for claude) rather
than the more generic pip-install/npm-install-g form, unless the two
are equivalent in practice — verify before choosing.
```

### task 1.3 — ext-pkg.package.ensure
```
## dispatch + prompt
new module ext-pkg.package.ensure: args package name. loads the
registry entry, runs the presence-check; if present, reports version
and does nothing else (no reinstall, no upgrade — see goal 2). if
absent, runs the declared install command, then re-runs the presence-
check to confirm success. writes a status record per check (present/
absent/installed-this-run) — this is the data task 2.1's coverage audit
reads.
```

## phase 2 — coverage integration

### task 2.1 — unified coverage audit
```
## dispatch + prompt
tie ext-pkg's registry into the same status view as bin/p7-deps
status/check (.deps/profiles.yaml) and build-zenka's recipe registry
(once it exists): one command or report that walks all three and shows
installed / missing / auto-installable for everything the project
depends on, across apt, cpan, pip, npm, uv-tool, git-build, tarball-
extract, vendor-deb, and pip-venv. this is the concrete answer to "no
categorical blind spots" — a single place to check before anyone goes
looking up a source and installing something by hand.
```

## notes

- keep this zenka's scope narrow: package-manager-backed installs only.
  if something needs building from source or fetching a raw tarball,
  it belongs in [[build-zenka]] instead, not here.
- install-if-missing, never force-upgrade, is the load-bearing
  constraint — these tools' own update mechanisms must remain the
  source of truth for version management once bootstrapped.
- os-pkg zenka (apt-only) and this zenka (pip/npm/uv-tool) are
  deliberately separate, not merged, so each package-manager family's
  quirks (apt's dpkg locking, pip's venv-vs-global ambiguity, npm's
  global-install permission questions) stay isolated per zenka instead
  of accumulating as special cases in one shared module.

#,,..,,,.,..,,,,.,,.,,...,,,,,.,.,...,,.,,...,..,,...,...,...,...,..,,,,,,,,,,
#FGWY45IB2DE5XEFDJDILW47RX5XRADA5ZJ5WX72MZSCWDKDJ75P6CO4WISMWT7JME7RHXMHJIJQPY
#\\\|F7YSK7CIJZ5A4Z2N6JA3BXCMTKD7VJLM7HVXYJM4ZKABIGK7AM4 \ / AMOS7 \ YOURUM ::
#\[7]GA7IJM73637SVOQMVAR6ISX6B2X4KE7YTPTDLDCV5LAKUGDETWDI 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
