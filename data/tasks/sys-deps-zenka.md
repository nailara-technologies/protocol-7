## sys-deps zenka + AMOS7::deps::* shared library

centralize dependency declaration, probing, and state resolution into a
`sys-deps` zenka backed by two new shared AMOS7 library modules. the standalone
`bin/p7-deps` script gets a style pass and delegates its core logic to the same
libraries so both layers share one authoritative implementation.

---

## signatures note

module files have a 4-line AMOS7 signature footer — do not reproduce or invent
these. leave new files without a footer; the signing tool adds it. existing
signatures must not be modified.

---

## background

existing infrastructure (read before implementing):

- `bin/p7-deps` — standalone pre-bootstrap CLI, pure stdlib Perl, already reads
  per-zenka `pm-dep/`/`os-dep/` dirs and `.deps/profiles.yaml`. has a hardcoded
  `%fallback_map` (10 entries) that duplicates `base.known_dependencies`
- `modules/base.known_dependencies` — authoritative hash: perl module name →
  `{ debian => [...], cpan_fallback => '...' }` mappings
- `configuration/zenki/*/pm-dep/` — per-zenka Perl module declarations (empty
  files, filename = module name with `__` replacing `::`)
- `configuration/zenki/*/os-dep/debian/` — per-zenka apt package declarations
- `configuration/zenki/*/os-dep/binary/` — per-zenka binary/PATH declarations
- `.deps/profiles.yaml` — named install profiles (minimal, runtime, development)
- `.deps/protocol7_full.yaml` — generated consolidated apt list (auto-generated,
  not authoritative)
- `modules/debian.*` — existing debian zenka (see audit task below)
- `data/lib-path/pm/AMOS7/` — project AMOS7 library modules (see existing
  structure: `AMOS7::CHKSUM::*`, `AMOS7::Assert::Truth`, etc.)

standalone scripts load AMOS7 modules via this BEGIN block pattern:
```perl
BEGIN {
    use FindBin qw($RealBin);
    use lib "$RealBin/../data/lib-path/pm";
}
use AMOS7::deps::module;
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

this module is the authoritative Perl module dependency library. it must work
standalone (no zenka, no Event loop). exports:

```perl
# load base.known_dependencies as plain perl data (eval the file, extract hash)
# returns hashref: module_name => { debian => [...], cpan_fallback => '...' }
sub load_known_deps { ... }

# scan all configuration/zenki/*/pm-dep/ dirs
# returns hashref: module_name => [ zenka_name, ... ]  (module may be needed by multiple zenki)
sub scan_zenki_pm_deps { my ($zenki_base) = @_; ... }

# probe whether a perl module is loadable
# uses eval { require Module::Name } — does not import
# returns 1 (loadable) or 0
sub probe_module { my ($module_name) = @_; ... }

# given a module name, return preferred install method and package name
# consults load_known_deps() result
# returns hashref: { method => 'debian'|'cpan', pkg => '...' }
sub resolve_install { my ($module_name, $known_deps) = @_; ... }
```

note: `base.known_dependencies` is a module file with P7 header — load it by
reading the file, stripping the header lines (`## [:< ##` and `# name = ...`
lines), then `eval`-ing the remainder to get the returned hashref.

---

## task 3 — AMOS7::deps::os-pkgs

create `data/lib-path/pm/AMOS7/deps/os-pkgs.pm`

OS-level dependency probing. standalone, no zenka deps.

### design constraint — keep generic across host OS

this module must not hardcode debian as the only OS. structure all OS-specific
logic behind a `detect_os()` function and dispatch through an OS type string.
the `debian` zenka init already does this detection — move that pattern here.

per-zenka declarations use subdirectory names to indicate OS type:
- `os-dep/debian/` — apt packages (debian/ubuntu)
- `os-dep/binary/` — binaries required in PATH (any OS)
- future: `os-dep/pacman/`, `os-dep/rpm/`, `os-dep/brew/` etc.

`scan_zenki_os_deps` must scan by subdirectory name generically, not hardcode
`debian` and `binary` — so new OS types appear automatically when their
`os-dep/<type>/` dirs are declared in any zenka config.

exports:

```perl
# detect host OS type — returns 'debian' | 'arch' | 'fedora' | 'unknown'
# checks /etc/os-release, /etc/debian_version, etc.
sub detect_os { ... }

# scan all configuration/zenki/*/os-dep/*/ dirs generically
# returns hashref: { $os_type => { $pkg => [$zenka,...] }, binary => { $bin => [$zenka,...] } }
sub scan_zenki_os_deps { my ($zenki_base) = @_; ... }

# probe an OS package — dispatches to probe_apt / probe_pacman / etc. by detected OS
# returns 1 or 0
sub probe_os_pkg { my ($pkg, $os_type) = @_; ... }

# check if a debian package is installed (dpkg-query)
sub probe_apt { my ($pkg) = @_; ... }

# check if a binary is in PATH
sub probe_binary { my ($binary) = @_; ... }

# install OS packages — dispatches by OS type, uses sudo when not root
# returns { ok => [...], failed => [...] }
sub install_os_pkgs { my ($os_type, @pkgs) = @_; ... }
sub install_apt     { my (@pkgs) = @_; ... }
```

---

## task 4 — refactor bin/p7-deps

update `bin/p7-deps` to use `AMOS7::deps::module` and `AMOS7::deps::os-pkgs`:

- remove the hardcoded `%fallback_map` — replace with `load_known_deps()` +
  `resolve_install()`
- replace inline `check_apt` / `check_cpan` / `get_zenki_pm_deps` /
  `get_zenki_os_deps` with calls to the AMOS7 library functions
- style pass: remove all emoji (✅ ❌ ⚠ 📦 💡 🔍), replace with P7 text style
  using `::[ section ]` framing and lowercase narrative output
- keep the existing commands: check, install, list, status, zenka-modules,
  zenka-packages, validate, clear-cache

color reference (already in bin/p7-deps):
```perl
my $reset      = "\e[0m";
my $blacklight = "\e[38;2;68;39;172m";
my $TRUE_color = "\e[38;2;6;71;195m";
my $neon_green = "\e[38;2;71;195;6m";
my $neon_amber = "\e[38;2;197;141;7m";
```

output style examples:
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

---

## task 5 — sys-deps zenka

create the following new files:

### configuration/zenki/sys-deps/start

on-demand zenka, no idle timeout (dependency queries are infrequent).
load modules: `auth net protocol io.unix sys-deps`

### modules/sys-deps.init_code

```
# name  = sys-deps.init_code
# descr = initialize sys-deps zenka — scan zenki dependency declarations
```

on init: call `scan_zenki_pm_deps` and `scan_zenki_os_deps` from the AMOS7
libraries. store results in `<sys-deps.pm_deps>` and `<sys-deps.os_deps>`.

load the AMOS7 libraries via `<[base.perlmod.load]>` with lib path setup.

### modules/sys-deps.cmd.state

```
# name  = sys-deps.cmd.state
# descr = full system dependency state: all declared deps and their probe status
# return = { mode => 'size', data => <formatted report> }
```

iterate all declared deps, probe each, format as text report.

### modules/sys-deps.cmd.check

```
# name  = sys-deps.cmd.check
# descr = dependency status for a specific zenka
# param = <zenka-name>
# return = { mode => 'size', data => <formatted report> }
```

### modules/sys-deps.cmd.missing

```
# name  = sys-deps.cmd.missing
# descr = list all unsatisfied dependencies across all zenki
# return = { mode => 'size', data => <formatted list> }
```

---

## dispatch notes

- implement tasks 2 and 3 first (the shared libraries) — tasks 4 and 5 depend on them
- task 1 (audit) can run in parallel with tasks 2/3
- the `debian` zenka is not modified in this task — it may become the privileged
  install backend in a follow-up once sys-deps is stable
- do not add `sys-deps` to `v7/start-set-up.base` — it is on-demand only
- do not modify `.deps/protocol7_full.yaml` — it is generated output, not source

#,,.,,,,.,..,,...,.,.,..,,.,,,..,,..,,,.,,,..,.,.,...,...,,.,,.,,,..,,.,.,,.,,
#I2YIF227KWOXQOBPLOY4TNSMESCKCFZJP3HQN2JNCLQWIJEFKFMQYSG4J5T4AL23HV7GYRCFGZJLY
#\\\|M3YH66PQFZFBSEQB7AQCJ7WQLNIXZVAAOLA3H4VGADDDKL3FFWN \ / AMOS7 \ YOURUM ::
#\[7]TMPHHPQK4G4L5YJUC6M7QGSQUYQENWDS6POXTKSS4RACKKQR7MDY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
