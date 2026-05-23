## sys-deps zenka + AMOS7::deps::* shared library

centralize dependency declaration, probing, installation, and state tracking
into a `sys-deps` zenka backed by a shared `AMOS7::deps::*` library that works
at every bootstrap phase — before cube is up, during v7 startup, and at runtime.

---

## signatures note

module files have a 4-line AMOS7 signature footer — do not reproduce or invent
these. leave new files without a footer; the signing tool adds it. existing
signatures must not be modified.

---

## background — existing infrastructure

read all of these before implementing:

- `bin/p7-deps` — standalone pre-bootstrap CLI; reads per-zenka `pm-dep/`/
  `os-dep/` dirs and `.deps/profiles.yaml`; has a hardcoded `%fallback_map`
  (10 entries) that duplicates `base.known_dependencies`
- `modules/base.known_dependencies` — authoritative hash: perl module name →
  `{ debian => [...], cpan_fallback => '...' }`
- `modules/base.debian.install_package` — zenka-side debian installer with
  dpkg lock-wait, retry loop (max 5), non-interactive env vars, early exit on
  "Unable to locate package"
- `bin/dependencies/debian_dist_upgrade.sh` — dist-upgrade script: dpkg
  auto-recovery first, then upgrade with full confold/confdef/confmiss/overwrite
  flags, `pam-auth-update`, cache cleanup, autoremove
- `configuration/zenki/*/pm-dep/` — per-zenka perl module declarations (empty
  files, `__` replaces `::` in filename)
- `configuration/zenki/*/os-dep/debian/` — per-zenka apt package declarations
- `configuration/zenki/*/os-dep/binary/` — per-zenka binary/PATH declarations
- `.deps/profiles.yaml` — named install profiles (minimal, runtime, development)
- `.deps/protocol7_full.yaml` — generated consolidated apt list (not authoritative)
- `modules/debian.*` — existing debian zenka (see task 1 audit)
- `data/lib-path/pm/AMOS7/` — project AMOS7 library modules

standalone scripts load AMOS7 modules via:
```perl
BEGIN {
    use FindBin qw($RealBin);
    use lib "$RealBin/../data/lib-path/pm";
}
```

---

## the three bootstrap phases

`AMOS7::deps::*` must work at all three phases — pure Perl, no event loop,
no zenka network required. each phase uses the same underlying library:

```
phase 0 — bin/Protocol-7 (before cube, before any zenka)
  → AMOS7::deps::* directly — checks core runtime deps (libevent-perl etc.)
  → fallback: shell out to bin/p7-deps if AMOS7 not yet loadable
  → hard fail with clear message if core deps missing

phase 1 — v7 pre-start (cube up, sys-deps not yet running)
  → reads configuration/zenki/$zenka/{pm-dep,os-dep} directly
  → AMOS7::deps::* for probing — no network, no zenka
  → installs missing via AMOS7::deps::deb-pkg (or bin/p7-deps as fallback)
  → writes tracked installs to var/sys-deps/tracked.yaml for later collection

phase 2 — sys-deps zenka (full network, on-demand)
  → AMOS7::deps::* as its backend — same logic, now network-facing
  → reads var/sys-deps/tracked.yaml on startup, absorbs v7's install log
  → responds to sys-deps.cmd.check / .missing / .state queries
```

---

## AMOS7::deps::* namespace

four modules, file locations under `data/lib-path/pm/AMOS7/deps/`:

```
AMOS7::deps::module        → module.pm    — perl module probing + mapping
AMOS7::deps::os-pkgs       → os-pkgs.pm  — generic OS scanner + dispatcher
AMOS7::deps::deb-pkg       → deb-pkg.pm  — debian: probe + install
AMOS7::deps::deb-pkg::d-upgr → deb-pkg/d-upgr.pm — dist-upgrade
```

---

## task 1 — audit debian zenka

read all `modules/debian.*` files and `configuration/zenki/debian/start`.
produce a short inventory:
- what commands are live and functional
- what is dead code or stub
- what overlaps with `bin/p7-deps` logic
- recommendation: absorb into sys-deps, keep as install backend, or retire

---

## task 2 — AMOS7::deps::module

create `data/lib-path/pm/AMOS7/deps/module.pm`

authoritative perl module dependency library. standalone, no zenka deps.

```perl
# load base.known_dependencies as plain perl data
# strip P7 header lines (## [:< ## and # name = ...), eval remainder
# returns hashref: module_name => { debian => [...], cpan_fallback => '...' }
sub load_known_deps { my ($p7_root) = @_; ... }

# scan all configuration/zenki/*/pm-dep/ dirs
# returns hashref: module_name => [ zenka_name, ... ]
sub scan_zenki_pm_deps { my ($zenki_base) = @_; ... }

# probe whether a perl module is loadable
# uses eval { require Module::Name } — does not import
# returns 1 or 0
sub probe_module { my ($module_name) = @_; ... }

# return preferred install method and package name for a module
# consults load_known_deps() — prefers debian pkg, falls back to cpan
# returns hashref: { method => 'debian'|'cpan', pkg => '...' }
sub resolve_install { my ($module_name, $known_deps) = @_; ... }
```

---

## task 3 — AMOS7::deps::os-pkgs

create `data/lib-path/pm/AMOS7/deps/os-pkgs.pm`

generic OS-level scanner and dispatcher. standalone, no zenka deps.

per-zenka declarations use subdirectory names to indicate OS type:
- `os-dep/debian/` — apt packages
- `os-dep/binary/` — binaries in PATH (any OS)
- future: `os-dep/pacman/`, `os-dep/rpm/`, `os-dep/brew/` etc.

`scan_zenki_os_deps` must scan subdirectory names generically — new OS types
appear automatically when their `os-dep/<type>/` dirs exist in any zenka config.

```perl
# detect host OS — returns 'debian' | 'arch' | 'fedora' | 'unknown'
# checks /etc/os-release, /etc/debian_version
sub detect_os { ... }

# scan all configuration/zenki/*/os-dep/*/ dirs generically
# returns hashref: { $os_type => { $pkg => [$zenka,...] }, binary => { $bin => [$zenka,...] } }
sub scan_zenki_os_deps { my ($zenki_base) = @_; ... }

# probe an OS package — dispatches to AMOS7::deps::deb-pkg::probe_apt etc.
# returns 1 or 0
sub probe_os_pkg { my ($pkg, $os_type) = @_; ... }

# probe a binary in PATH
sub probe_binary { my ($binary) = @_; ... }

# install OS packages — dispatches by os_type to the appropriate backend module
# returns { ok => [...], failed => [...] }
sub install_os_pkgs { my ($os_type, @pkgs) = @_; ... }
```

---

## task 4 — AMOS7::deps::deb-pkg

create `data/lib-path/pm/AMOS7/deps/deb-pkg.pm`

debian-specific package operations. called by `os-pkgs` when `detect_os` returns
`'debian'`. replaces the logic in `modules/base.debian.install_package`.

```perl
# check if a debian package is installed (dpkg-query)
# returns 1 or 0
sub probe_apt { my ($pkg) = @_; ... }

# install debian packages — non-interactive, with dpkg lock-wait and retry
# replicates modules/base.debian.install_package:
#   - set env: APT_LISTCHANGES_FRONTEND=none, DEBCONF_PRIORITY=critical,
#     UCF_FORCE_CONFFOLD=true, UCF_FORCE_CONFMISS=true, PAGER=/bin/true
#   - wait for dpkg lock: lslocks|grep ^dpkg, retry with backoff
#   - retry loop up to 5 times on failure
#   - break early on "Unable to locate package"
#   - use sudo if not root
# returns { ok => [...], failed => [...] }
sub install_apt { my (@pkgs) = @_; ... }
```

when called from inside the `sys-deps` zenka, can alternatively delegate to
`<[base.debian.install_package]>` — but `deb-pkg.pm` needs its own standalone
implementation for use before the zenka network is up.

---

## task 5 — AMOS7::deps::deb-pkg::d-upgr

create `data/lib-path/pm/AMOS7/deps/deb-pkg/d-upgr.pm`

debian dist-upgrade. translates `bin/dependencies/debian_dist_upgrade.sh` to
Perl. read that script before implementing.

sequence (from the shell script):
1. set non-interactive env vars (same as install_apt)
2. `dpkg --force-confold --force-confdef --force-confmiss --force-overwrite --configure -a`
3. `apt-get -fy install` (automatic recovery)
4. `apt-get -y $action` where action is 'upgrade' or 'dist-upgrade'
5. `pam-auth-update --force`
6. `rm -rf /var/cache/apt/mediainfo_tmp*`
7. `apt-get update`
8. full upgrade with overwrite flags
9. `apt-get clean && apt-get -y --purge autoremove`
10. cleanup: `/var/cache/apt/mediainfo_tmp*`, `/root/.cpanm`

```perl
# run dist-upgrade (action = 'dist-upgrade' | 'upgrade')
# requires root or sudo
# returns { ok => 1|0, log => '...' }
sub run { my ($action) = @_; $action //= 'dist-upgrade'; ... }
```

---

## task 6 — refactor bin/p7-deps

update `bin/p7-deps` to use the new AMOS7 library modules:

- add BEGIN block to load `data/lib-path/pm` into `@INC`
- remove hardcoded `%fallback_map` — replace with `load_known_deps()` +
  `resolve_install()` from `AMOS7::deps::module`
- replace `check_apt` / `check_cpan` with `AMOS7::deps::deb-pkg::probe_apt`
  and `AMOS7::deps::module::probe_module`
- replace `get_zenki_pm_deps` / `get_zenki_os_deps` with the AMOS7 scan functions
- add `dist-upgrade` command delegating to `AMOS7::deps::deb-pkg::d-upgr::run()`
- style pass: remove all emoji (✅ ❌ ⚠ 📦 💡 🔍), replace with P7 framing:

```
:
::[ dependency status ]
:

  ::[ minimal ]
  ::
  ::  libevent-perl ............... installed
  ::  libcryptx-perl .............. installed
  ::  IO::AIO ..................... missing
  ::
  ::  1 missing — run: bin/p7-deps install minimal
  :
```

color palette (already in script — keep as-is):
```perl
my $reset      = "\e[0m";
my $blacklight = "\e[38;2;68;39;172m";
my $TRUE_color = "\e[38;2;6;71;195m";
my $neon_green = "\e[38;2;71;195;6m";
my $neon_amber = "\e[38;2;197;141;7m";
```

---

## task 7 — tracking layer + bin/os-pkg

### the problem

manual package installs happen constantly and informally. if tracked from the
start, recreating a host (or replicating a setup to a remote node) becomes
possible without prior planning — the system has learned what was actually
installed, not just what was declared.

### tracking state file

`var/sys-deps/tracked.yaml` — written by both v7 pre-start installs and
`bin/os-pkg`. format:

```yaml
tracked:
  - pkg: libmediainfo-dev
    type: debian
    installed_at: <ntime_b32>
    source: manual        # 'manual' | 'v7-prestart' | 'sys-deps'
    zenka: ~              # zenka name if installed by v7-prestart, else null
    declared: false       # true once promoted to an os-dep/ config dir
```

### bin/os-pkg

new standalone script. installs OS packages and tracks them:

```
bin/os-pkg install <pkg> [<pkg> ...]   — install and track
bin/os-pkg list                        — show tracked installs
bin/os-pkg undeclared                  — tracked but not in any os-dep/ dir
bin/os-pkg declare <pkg> <zenka>       — promote to configuration/zenki/<zenka>/os-dep/debian/
```

uses `AMOS7::deps::deb-pkg` for installation and `AMOS7::deps::os-pkgs` for
OS detection. writes to `var/sys-deps/tracked.yaml` after each install.

### v7 pre-start hook

before starting any zenka, v7 reads its `pm-dep/` and `os-dep/` dirs using
`AMOS7::deps::*` directly (no network needed). if deps are missing:
- if `v7.cfg.auto_install_deps = yes` (and root/sudo available): install, log
  to `var/sys-deps/tracked.yaml` with `source: v7-prestart`
- if not: abort zenka start with explicit "missing deps: ..." message

this is the only mechanism that covers ext-bin zenki — external scripts/binaries
registered as zenki have no init_code to self-check. v7 is the gatekeeper.

### sys-deps zenka absorbs tracking log

on `sys-deps.init_code`: read `var/sys-deps/tracked.yaml`, merge into
`<sys-deps.tracked>`. expose via:

```
sys-deps.cmd.undeclared   — packages tracked but not formally declared
sys-deps.cmd.promote <pkg> <zenka>  — write to os-dep/ config dir
```

---

## task 8 — sys-deps zenka

create:

### configuration/zenki/sys-deps/start

on-demand zenka, no idle timeout. load modules: `auth net protocol io.unix sys-deps`
`start.on-demand = 1`, `restart.disabled = 1`, `heartbeat.disabled = 1`

### modules/sys-deps.init_code

scan zenki pm/os deps via AMOS7 libs, read tracking log, detect host OS.
load AMOS7 library modules via `<[base.perlmod.load]>` with lib path setup.

### modules/sys-deps.cmd.state
full dependency state report: declared + probe status for all zenki.

### modules/sys-deps.cmd.check
`# param = <zenka-name>` — dep status for one zenka.

### modules/sys-deps.cmd.missing
all unsatisfied deps across all zenki.

### modules/sys-deps.cmd.undeclared
packages in tracking log not yet promoted to any `os-dep/` config dir.

### modules/sys-deps.cmd.promote
`# param = <pkg> <zenka>` — write empty file to
`configuration/zenki/<zenka>/os-dep/debian/<pkg>`.

---

## dispatch notes

- dispatch with `kimi -y` — auto-approves tool calls, required for reasonable
  roundtrip time. use `kimi -C` to continue with guidance if redirecting
- implementation order: tasks 2→5 first (AMOS7 library), then 6 (bin/p7-deps),
  then 7 (tracking + bin/os-pkg), then 8 (sys-deps zenka)
- task 1 (audit) runs in parallel with tasks 2–5
- `base.debian.install_package` is not modified — it remains the zenka-side
  install path; `AMOS7::deps::deb-pkg` is the standalone equivalent
- do not add `sys-deps` to `v7/start-set-up.base` — on-demand only
- do not modify `.deps/protocol7_full.yaml` — generated output, not source
- `var/sys-deps/` directory must be created if missing (tracked.yaml lives here)

#,,.,,.,.,,..,..,,.,,,,,.,...,,.,,,,.,,..,,.,,..,,...,...,.,,,,,.,.,,,,,.,.,.,
#NNWVSSTY56KBZJSPQ6ZA3QXZQA3CY5FX7LBCVT6UAN2YCIQFMRQ45FPEFB76WK67JFHNHG3TY4LPE
#\\\|2K5I7ELXELEZMY4P2KRYTTN54NMF2NZ62CJH7KRED5ZZKPSRFBC \ / AMOS7 \ YOURUM ::
#\[7]BLD7BX7CWF3YDNWVESH4Y3SQWRZJTAZ2KTKKREE6WCO7ESH4JCBI 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
