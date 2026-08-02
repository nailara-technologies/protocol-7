---
name: topic-reload-safe-transient-config-keys
description: modules.load/modules.preload cleanup design paused before implementation -- base.register_prune + config.reload.prune + base.pre_init/base.reload_config hooks, full design in data/md/design/RELOAD-SAFE-TRANSIENT-CONFIG-KEYS.md
metadata:
  node_type: memory
  type: project
---

Design work paused deliberately (user wanted thinking time) before any
of the new code gets written. Full technical detail, including the
false starts and why each was rejected, lives in
`data/md/design/RELOAD-SAFE-TRANSIENT-CONFIG-KEYS.md` — read that file
first, this is just the index pointer.

## one-paragraph summary

`modules.load`/`modules.preload` are unenforced convention variables
(~127 start files), already read by one vestigial dependency
(`devmod.cmd.unload-devmod`). `base.prune_key` (landed `0425b210f`,
useful standalone) deletes them right after `[load_modules:...]` but
only survives the *initial boot* — `base.cmd.reload`'s `config`/`all`
paths recreate `modules.load` on every reload via the values-only
`base.reload_values` path, which never re-runs bracket-commands, so the
prune line never fires again. Converged design: `base.register_prune`
(pure registration, no immediate delete) pushes onto a new
`<config.reload.prune>` list; a small not-yet-named shared routine
processes that list (deletes each key via `prune_key`, leaves the
registry itself alone) from two call sites — `base.pre_init` (already
exists, already runs once per boot via `[init_modules]`, no new hook
needed) for the boot case, and `base.reload_config` *after*
`base.reload_values` for every reload cycle. `<config.reload.cleanup_keys>`
(existing, unrelated pre-reload-freshness mechanism) was considered and
explicitly rejected for reuse — different contract, would invert its
meaning.

## current state

- `modules/base.del_key`, `modules/base.prune_key` — landed, `0425b210f`.
- `configuration/zenki/mod-test/start` — carries
  `[base.prune_key:'modules.load']` as a **known-incomplete**
  placeholder/reminder (boot-only, resets on reload); left in
  intentionally, not reverted.
- Not yet done: name the shared registry-processing routine, implement
  `base.register_prune` + the two call sites, re-verify `mod-test` with
  a real reload (not just boot), then resume the tiered start-file
  migration (low-traffic zenki → the 7 `modules.preload` zenki/irregular
  shapes → bulk → `cube`/`v7`/`system` last, one commit per tier, each
  tier actually restarted and live-verified).
- Separate, smaller, still-open item noted in the design doc but not
  fixed by it: `base.cmd.reload`'s fallback for newly-added-but-never-
  loaded modules only checks `<modules.load>` by name, missing
  `<modules.preload>` — real (7 zenki affected) but low blast-radius,
  no fix decided (a hardcoded 2-name union was considered and rejected
  as the same "chasing an arbitrary convention" mistake).

## related

`modules/base.reload_config`, `modules/base.execute_zenka_code`,
`modules/base.pre_init`, `modules/devmod.cmd.unload-devmod`

#,,,.,...,...,.,.,,,.,.,.,.,.,,.,,..,,,,,,,,.,..,,...,..,,..,,..,,,,.,,,.,,,.,
#VAQDOQQRRT7AX4EGJ3PFRS5LAV2RS5E4EAZ4U6ZCGO6IWZVXX2J3PBU22NXPUJJTEVNC2QH4KNCLE
#\\\|HOZ5XBWLH6GPNWHMLRRWT5YGCEWNGLNU5MGTD2KHOCT3PSSBR3H \ / AMOS7 \ YOURUM ::
#\[7]ACJNBLONHVRDWDYKUOTPOY45IGWIOHORONWKXJ4K3LJFQ3KKCQDQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
