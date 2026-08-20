# Task 1 — Audit of existing `debian` zenka

## Inventory

### Live / Functional

| Module | Purpose | Disposition |
|--------|---------|-------------|
| `debian.parent.init_code` | Initializes registries (packages, cpan_modules, zenki_deps, binaries), loads `base.known_dependencies`, sets up list views | **Retire** — registries move to `sys-deps`; list views are zenka-specific UI |
| `debian.parent.scan_zenki_dependencies` | Scans `cfg/zenki/*/pm-dep/`, `os-dep/debian/`, `os-dep/binary/` | **Absorb into `AMOS7::deps::module` + `AMOS7::deps::os-pkgs`** |
| `debian.parent.check_installed` | Uses dpkg-query + eval require to probe packages/src, updates registry status | **Absorb into `AMOS7::deps::*`** |
| `debian.parent.ensure_zenka_dependencies` | Zenka startup gatekeeper: checks deps, auto-installs if root | **Move to v7 pre-start hook + `sys-deps` zenka** |
| `debian.parent.install_missing` | Collects missing deps, calls `base.debian.install_package` + cpanm | **Absorb into `AMOS7::deps::deb-pkg`** |
| `debian.parent.resolve_cpan_to_debian` | Looks up `base.known_dependencies`, applies `libfoo-bar-perl` naming convention | **Absorb into `AMOS7::deps::module::resolve_install`** |
| `debian.parent.verify_dependency_state` | Generic probe for pm_module / os_package / binary | **Absorb into `AMOS7::deps::*` probe functions** |
| `debian.cmd.check` | Reports installed/missing counts, zenka-specific filter | **Rewrite as `sys-deps.cmd.state` + `sys-deps.cmd.check`** |
| `debian.cmd.install` | Thin wrapper around `debian.parent.install_missing` | **Rewrite as `sys-deps.cmd.install`** |
| `debian.cmd.scan` | Thin wrapper around `debian.parent.scan_zenki_dependencies` | **Absorb into `sys-deps.init_code`** |
| `debian.cmd.stats` | Formats `debian.stats` hash | **Rewrite as `sys-deps.cmd.stats`** |
| `debian.cmd.zenka` | Lists zenki with dependency status | **Rewrite as `sys-deps.cmd.state`** |
| `debian.cmd.install-history` | Parses `/var/log/dpkg.log*` with filters (action, date, package, count, auto/manual) | **Keep in `debian` zenka** — dpkg history is debian-specific, not dependency management |
| `debian.console.check-deps` | Console-formatted dependency check output | **Retire** — replaced by `bin/p7-deps` + `sys-deps` zenka |
| `debian.console.install-deps` | Installs minimal deps via shell script OR zenka deps via `install_missing` | **Retire** — replaced by `bin/p7-deps` + `bin/os-pkg` |
| `debian.console.list-zenki` | Console-formatted zenki list | **Retire** — replaced by `sys-deps.cmd.state` |
| `debian.parent.callback.*` (5 modules) | Registry helpers for packages, cpan modules, binaries | **Retire** — AMOS7 library does not use zenka registries |
| `debian.parser.*` (5 modules) | Display formatting (emoji status, string truncation, array joining) | **Retire** — UI formatting moves to `sys-deps` cmd modules or `bin/p7-deps` |

### Overlap with `bin/p7-deps`

| `bin/p7-deps` | `debian` zenka equivalent |
|---------------|---------------------------|
| Hardcoded `%fallback_map` (10 entries) | `debian.parent.resolve_cpan_to_debian` |
| `check_apt` / `check_cpan` | `debian.parent.callback.check_package_installed` / `check_module_loadable` |
| `get_zenki_pm_deps` / `get_zenki_os_deps` | `debian.parent.scan_zenki_dependencies` |
| Profile-based install (`check`, `install`) | `debian.cmd.install` + `debian.parent.install_missing` |
| No dpkg lock-wait, no retry loop | `base.debian.install_package` has lock-wait + retry |
| No dist-upgrade command | `bin/dependencies/debian_dist_upgrade.sh` (shell script) |

### Recommendations

1. **Retire the `debian` zenka** as a dependency-management zenka. Its dpkg-history command (`install-history`) can become a standalone utility or move to a `debian-utils` zenka if still needed.
2. **Keep `base.debian.install_package`** unchanged — it remains the zenka-side install path when the cube is up.
3. **Create `AMOS7::deps::*`** library to unify the logic that currently lives in `bin/p7-deps`, `debian.*` modules, and `base.known_dependencies`.
4. **Create `sys-deps` zenka** as the network-facing backend, on-demand only.
5. **`bin/p7-deps`** becomes a thin CLI wrapper around the AMOS7 library.
6. **`bin/os-pkg`** becomes the manual-install tracking tool.

## Summary

- **Live code to absorb:** `debian.parent.scan_zenki_dependencies`, `debian.parent.check_installed`, `debian.parent.install_missing`, `debian.parent.resolve_cpan_to_debian`, `debian.parent.verify_dependency_state`, `debian.cmd.check`, `debian.cmd.install`, `debian.cmd.scan`, `debian.cmd.stats`, `debian.cmd.zenka`
- **Dead / stub code:** `debian.console.*` (superseded by CLI tools), `debian.parser.*` (display-only), `debian.parent.callback.*` (registry boilerplate)
- **Keep as-is:** `base.debian.install_package`, `bin/dependencies/debian_dist_upgrade.sh` (until `AMOS7::deps::deb-pkg::d-upgr` replaces it), `debian.cmd.install-history` (unique dpkg-log parser)

#,,,,,..,,...,,,.,,,,,..,,..,,...,.,,,,,.,.,.,..,,...,...,,,,,.,.,,.,,,..,.,.,
#M6R2PSL6BOLMPRVN6XUGSVFMNBQIR2RIBSWPI6C4ESZ4D6TY5EPM7YQQ4Y3VMSRTP76SS6R6TPDYA
#\\\|ZPLMGTJGHQHMWX7MYID735QWSFGBGK4AHINYTV4O5WFWHY4OSOL \ / AMOS7 \ YOURUM ::
#\[7]LTWNZXPEWSUHOQWRAJUSU3YME7KI4MBT4X2KUMYI2LDAN3Q55WCQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
