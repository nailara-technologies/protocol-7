# task: finish wiring sys-deps in, retire the mechanisms it replaced

## background

`sys-deps` + `AMOS7::deps::*` (see `data/tasks/completed/sys-deps-zenka.md` and
`data/tasks/completed/sys-deps-zenka-audit.md`) was built to replace two older,
cruder dependency-check mechanisms with one library-backed system that works
before cube is up, during v7 startup, and at runtime on-demand. that build is
further along than it looks from the outside — this task is about closing the
gap between "the new system exists and partially runs" and "the old systems
are gone and nothing calls dead code".

verified while auditing v7's `show-buffer undef-subs` output this session:

- `bin/p7-deps` — already refactored onto `AMOS7::deps::module` /
  `os_package` / `debp` / `dist_upgr`, no more hardcoded fallback map. **done.**
- `bin/os-pkg` — already using `AMOS7::deps::os_package` / `debp`. **done.**
- `src/sys-deps.cmd.{check,install,missing,promote,state,undeclared}` —
  all present. **done.**
- `src/v7.check_zenka_deps` — the phase-1 pre-start hook from task 7 of
  the original plan — is wired into `src/v7.autostart_zenki:9`. **done,**
  scans pm/os/binary deps per zenka via `AMOS7::deps::*`, auto-installs when
  `v7.cfg.auto_install_deps` is truthy and root/sudo is available, logs to
  `var/sys-deps/tracked.yaml`.

what's still hanging around, unreachable, calling into namespaces that are
never loaded:

- `src/v7.init_code:128-167` — guarded block calling
  `debian.parent.scan_zenki_dependencies` then
  `v7.verify_and_install_zenka_dependencies`. `debian` has not been in v7's
  own `modules.load` since `ffc44add6` (Nov 2025, "temporarily disabled...
  for testing", never restored) — this entire block has been dead for 8+
  months, superseded in practice by `v7.check_zenka_deps`.
- `src/v7.verify_and_install_zenka_dependencies` — only caller is the
  block above. dead alongside it.
- `src/base.ensure_zenka_dependencies` — guards a call to
  `debian.parent.ensure_zenka_dependencies`. **nothing calls this module at
  all** (checked: no references outside itself and the generated
  `base.list.subroutines`). fully orphaned, not just inert.
- `src/debian.parent.ensure_zenka_dependencies` — the audit already
  flagged this as "move to v7 pre-start hook + sys-deps zenka" — that move
  happened (`v7.check_zenka_deps`), this one was never deleted.
- the whole `session` zenka's dependency-check half (`session.parent.check_and_resolve_deps`,
  `session.parent.check_minimal_deps`, `session.parent.show_startup_help`,
  `session.console.check-deps`, `session.console.stats`) predates `debian`'s
  own dependency wiring (`c52030bcc`, Nov 2025) and was never in the sys-deps
  audit's scope because that audit only covered `debian`. it's the same
  "crude mechanism, superseded" story one layer further back. `session.console.setup-keys`
  / `session.console.config` are a separate concern (AMOS7 signature key dir
  setup) — do not touch those without checking they're not still load-bearing.
- `src/debian.*` (28 files) — the completed audit already has a
  per-module disposition table (retire / absorb / keep). none of the
  "retire" or "absorb" dispositions were executed — the files are all still
  there, most now fully superseded by `AMOS7::deps::*` + `sys-deps`.
  `debian.cmd.install-history` was explicitly flagged "keep" (unique dpkg-log
  parser, not a dependency-management feature) — don't retire that one.

## why this matters

nothing here is presently broken (everything above is either exists-guarded
or genuinely unreachable), but it's exactly the kind of drift that produces
false leads: a future undef-sub scan, a grep for "how does dependency
checking work here", or an LLM reading `v7.init_code` cold will all land on
the dead `debian.parent.*` chain and assume it's live, then either "fix" it
(re-wiring a mechanism that was deliberately abandoned for causing an auth
race condition, see `601b2d248`) or waste a session tracing why it never
fires. the real answer — `v7.check_zenka_deps` / `sys-deps` — is a normal
grep away only if the dead code doesn't out-shadow it.

## task 1 — confirm the new pipeline actually works end to end

before deleting anything: `v7.check_zenka_deps` and the `sys-deps` zenka's
commands have code that looks complete but per the user, may never have been
exercised for real. verify, on a real host:

- a zenka with a genuinely missing `pm-dep/` or `os-dep/debian/` entry
  triggers `v7.check_zenka_deps` correctly at `v7.autostart_zenki` time
- with `v7.cfg.auto_install_deps` on and root/sudo available: the install
  actually happens, `var/sys-deps/tracked.yaml` gets written with the right
  shape (`pkg`, `type`, `installed_at`, `source: v7-prestart`, `zenka`,
  `declared: 0`)
- `sys-deps` zenka starts on-demand, reads `var/sys-deps/tracked.yaml` on
  init, `sys-deps.cmd.undeclared` shows the tracked-but-undeclared package,
  `sys-deps.cmd.promote <pkg> <zenka>` writes the empty marker file to
  `cfg/zenki/<zenka>/os-dep/debian/<pkg>` correctly
- `bin/p7-deps check` / `bin/os-pkg list` reflect the same state a running
  zenka would see (same `AMOS7::deps::*` backend, should already agree, but
  confirm)

if any of this doesn't work, fix it before task 2 — deleting the old
mechanism is only safe once the replacement is confirmed live.

## task 2 — retire the dead debian.parent chain in v7

- remove the guarded block in `src/v7.init_code:128-167`
  (`debian.parent.scan_zenki_dependencies` → `v7.verify_and_install_zenka_dependencies`)
- delete `src/v7.verify_and_install_zenka_dependencies`
- delete `src/base.ensure_zenka_dependencies` (confirmed zero callers)
- regenerate `src/base.list.subroutines`
  (`bin/Protocol-7 sourcecode update-sub-list`) and v7's whitelist
  (`bin/dev/gen-sub-whitelist v7`) after

## task 3 — retire debian zenka's dependency-management modules

execute the disposition table in `data/tasks/completed/sys-deps-zenka-audit.md`
verbatim: delete everything marked "retire" or "absorb into ..." (the absorb
targets already exist in `AMOS7::deps::*` / `sys-deps.*`, confirmed present
this session), keep `debian.cmd.install-history` and `base.debian.install_package`
exactly as the audit says. decide separately whether the `debian` zenka
config itself (`cfg/zenki/debian/`) still deserves to exist purely
as a home for `install-history`, or whether that command should move to a
`debian-utils`-style zenka / standalone script instead, per the audit's own
open question.

## task 4 — decide the fate of session's dependency-check half

`session.parent.check_and_resolve_deps` / `check_minimal_deps` /
`show_startup_help` / `session.console.check-deps` / `session.console.stats`
are the original crude mechanism, superseded twice over (first by the
`debian`-zenka attempt, now by `sys-deps`). recommend retiring these too,
same treatment as task 3 — but audit `session.console.setup-keys` and
`session.console.config` first, they may be doing something unrelated
(AMOS7 key directory setup) that's still needed regardless of what happens
to the dependency-check half.

## task 5 — whitelist + signature regen

after tasks 2-4, regenerate whitelists for every affected zenka
(`v7`, `debian`, `session`, and anything else touched) via
`bin/dev/gen-sub-whitelist`, then sign with
`bin/Protocol-7 sourcecode update-signatures cfg/zenki/*/subroutine.white-list`.
run `v7.show-buffer undef-subs` after a real reload to confirm it's clean.

## signatures note

module files have a 4-line AMOS7 signature footer — do not reproduce or
invent these. leave new/edited files without a footer; the signing tool adds
it. existing signatures on files you don't touch must not be modified.

## dispatch notes

- task 1 must run first and gate everything else — do not delete live-looking
  code before confirming the replacement actually works, not just compiles
- tasks 2 and 3 can run in parallel once task 1 passes
- task 4 is a judgment call with a recommended default (retire), not a
  mechanical instruction — flag anything ambiguous rather than guessing
- this whole task exists because a previous session found the dead
  `debian.parent.*` / `session.parent.*` call sites by way of
  `v7.show-buffer undef-subs` after fixing an unrelated `auth.client`
  namespace-split gap — see that session's commits (`81403b3b8`, `c06c9d503`,
  `c80dfacfc`, `e1ca9351e`) for the trail that led here

#,,,,,,..,.,.,,.,,...,,,.,.,.,,,,,,,.,.,,,.,,,..,,...,...,..,,.,,,.,,,..,,...,
#QDXM6C25V3G4YPNM6ZUKLZE5QT473GNEBT2LGHS6B7PRBA7EXJNUXASWAXONTKGD3UDCJK62ZU4NM
#\\\|ZUMDG2EFYDYG2DQXV2TPX2FJLQXLKNRNRDIWEU53FPHB4VXIJUC \ / AMOS7 \ YOURUM ::
#\[7]ICI7OW7FUPL4LJOKD2RGTQTYPISABU5W6XIV742GLAVV7ESG34BI 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
