---
name: sys-deps-wiring-completion
description: "K3-dispatched: retired the debian-zenka dependency-management stack and session zenka's dependency-check half per the pre-existing sys-deps-zenka-audit disposition table, after live-verifying the v7.check_zenka_deps/sys-deps replacement pipeline actually works end to end (it had real bugs of its own, now fixed)"
metadata:
  node_type: memory
  type: project
  modified: 2026-07-20
---

Follow-on from [[topic-auth-client-namespace-split]]'s undef-sub sweep: fixing v7's `auth.client`
gap surfaced a chain of dead code in `v7.init_code` (guarded `debian.parent.*` calls,
`v7.verify_and_install_zenka_dependencies`, an orphaned `v7.post_init_code` with the wrong hook-name
suffix) that traced back to two superseded dependency-management mechanisms: the `debian` zenka
(disabled in v7's own `modules.load` since Nov 2025, "temporarily... for testing", never restored)
and, one layer further back, `session` zenka's `check_and_resolve_deps` (Nov 2025, reverted from v7
for causing an auth race condition). Both had already been functionally replaced by `sys-deps` +
`AMOS7::deps::*` (`data/tasks/completed/sys-deps-zenka.md`, May 2026) — the audit
(`data/tasks/completed/sys-deps-zenka-audit.md`) had a full per-module disposition table for `debian`
that was simply never executed.

Wrote `data/tasks/sys-deps-wiring-completion.md`, dispatched to Kimi K3 (via `claude_dispatch`
orchestrating `kimi_dispatch model=k3`, per [[project-kimi-k2.7-vs-k3-tier-economics]]'s guidance —
this is exactly the "correctness-critical, judgment-involved, code deletion with history" shape K3
suits). Gated destructively (tasks 2-4) behind a verification step (task 1: confirm the sys-deps
replacement pipeline actually works, not just compiles) — this paid off: K3 found and fixed real bugs
in the "already built" replacement before deleting anything —

- stale `AptPkg` cache in `data/lib-path/pm/AMOS7/deps/debp.pm`
- a compile-time `use debp qw(...)` in `os_package.pm` that broke under `Module::Refresh` (now
  fully-qualified runtime calls)
- `var/sys-deps` ownership/perms in `v7.check_zenka_deps`
- a `return`-inside-`eval{}` bug in `bin/os-pkg load_tracked`
- `modules/sys-deps.cmd.install` was a stub, filled in for real

Then executed: deleted `v7.init_code:128-167`'s dead block + `v7.verify_and_install_zenka_dependencies`
+ `base.ensure_zenka_dependencies` (zero callers, fully orphaned) + 26 `debian.*` files per the audit
table (kept `debian.cmd.install-history`, `base.debian.install_package`, `debian.start.apt_child` as
directed). Retired `session`'s dependency-check half too (not in the original audit's scope, same
"superseded" story one layer back) — K3 caught two entangled files I hadn't listed
(`session.parent.init_code`, `session.console.config`), kept `session.console.setup-keys` (unrelated
AMOS7 key-dir setup). No item left ambiguous — task 4 was flagged as a judgment call in the task file
and K3 resolved it cleanly rather than punting.

**Not part of this dispatch, found afterward through live testing**: the `sys-deps` on-demand
idle-shutdown path itself hit a real, unrelated, systemic bug — see
[[project-ondemand-zenki-registry-wipe]].

**Outcome**: 57 files touched, all still uncommitted pending human signing (`proto-7.sourcecode`
passphrase — neither K3 nor the orchestrating session had it). `v7.show-buffer undef-subs` clean
after a live reload. Two harmless untracked runtime marker files appeared
(`cfg/zenki/sys-deps/source/{auth.client,ui}`) from live-testing the zenka — kept, same
pattern as other zenki's `source/` marker files. Test packages `sl`/`cowsay`/`cmatrix` (~180KB) remain
apt-installed on the host from K3's live dep-install testing — no root to remove them.

## related

[[project-ondemand-zenki-registry-wipe]] · [[topic-auth-client-namespace-split]] ·
[[project-kimi-k2.7-vs-k3-tier-economics]] · [[project-depgraph-conditional-calls-blindspot]]

#,,.,,..,,...,,..,...,,,.,,.,,..,,,.,,.,.,..,,..,,...,..,,.,,,...,,,,,,..,,,,,
#CN6OSQV2DQE4IDN57FFNX3Z3LAJGR22AMF6BARIK7U3WUE54K3F5EHREWTPQJBQSMS4DTFFKFUDY4
#\\\|YMPSIHVSAFCOHHDONODQF4GUSBRJMRGEYNXZZERUWACCZMUY2UY \ / AMOS7 \ YOURUM ::
#\[7]WVBB23LA6AMNZRBACDHL3476Y4A4DO3X6KNIUSRWYYTUXOEF5KBQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
