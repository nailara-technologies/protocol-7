---
name: loader-nested-hooks-eager-compile
description: FIXED 2026-08-04 (bin/Protocol-7 p7_load_code whitelist-gate) — nested base.*.pre_init/init_code hooks were always solo-lazy-compiled even when their ancestor namespace was already in the current batch; also polluted $data{base}{p7_mod}{loaded} with bogus per-hook pseudo-module keys, needing one v7.restart to clear
metadata:
  type: feedback
---

Root cause and fix: [[loader-eager-compile-nested-hooks-under-loaded-ancestor]]
(`data/tasks/completed/loader-eager-compile-nested-hooks-under-loaded-ancestor.md`).
Landed same session as, and interacting with, [[loader-reload-stale-cmd-modules]]
— same whitelist-gate block in `p7_load_code`, deliberately kept as a
separate patch on top per that task's own caution against bundling.

The whitelist-gate already computed "is this nested hook's ancestor part
of the current compile batch" (used to decide whether to even install a
stub) but then installed/left a deferred stub either way, `next`ing past
eager compilation. Every `base.locales.pre_init`, `base.chk-sum.*.*`
style hook ended up compiled lazily, one at a time, on first
`base.init_modules` call — each hit paying a full solo `p7_load_code`
overhead (its own staging-hash seed copy of the entire `%code`) just to
compile a few bytes. Fix: when the ancestor-in-batch flag is true, fall
through to normal eager compile instead of stubbing.

**Non-obvious gotcha**: each solo lazy-compile (via
`base.load_runtime_modules`) registers the hook's own full name as its
own key in `$data{'base'}{'p7_mod'}{'loaded'}` — a registry meant for
top-level module names. `base.cmd.reload`'s `source` step reads that
registry (`base.clear_p7_mods`) to decide what to re-load, so these
bogus per-hook keys got fed back in as their own pseudo-"modules" on
every subsequent reload, forever, once created. Fixing the eager-compile
path stops new bogus keys from being created, but **does not retroactively
clean up ones already accumulated in a long-running zenka's memory** — a
`reload` alone stays "dirty" (still lists old per-hook pseudo-module
`p7-source` lines) until one `v7.restart` resets `$data{'base'}{'p7_mod'}`
fresh; every `reload` after that restart is clean. Confirmed on `cube-13`
and the `coding` zenka.

**How to apply**: when verifying a loader-registry-shaped fix on an
already-running zenka, don't conclude a fix failed just because
`reload` still shows the old symptom — check whether restarting once
first is needed to clear accumulated registry state, before treating a
lingering symptom as evidence the fix itself is wrong.

#,,..,.,,,..,,..,,,,.,.,,,..,,..,,.,,,,..,,.,,..,,...,...,.,,,,..,...,.,,,.,.,
#EED7KPXW477MOHUYKU6T6A53ALRDFSP4BWZYNDOGBKLUPMUEDENR4FB2S5MEZNPFBUPWHL5SSBTC4
#\\\|TK4FITFR5JVCJRR3N3ZVMLLIKSLTFCMJEQUW7EIVJ4I3N4S3X5Y \ / AMOS7 \ YOURUM ::
#\[7]U4FBPVAMNZ7D7GKWYHINUL7AZBGQD5YBQY6W2SUCINLRHDUMVGCI 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
