---
name: ondemand-zenki-registry-wipe
description: "v7.set_up_ondemand_zenki unconditionally resets <v7.ondemand_zenki> to [] then rebuilds strictly from its args; v7.post_init only ever called it with the added-since-last-run delta, so on any reload that didn't happen to touch every ondemand zenka the list quietly shrank -- confirmed live at 0/56 entries, breaking the online-vs-clean-shutdown distinction in v7.process_zenka_end and causing restart-loop-despite-restart.disabled for every ondemand zenka"
metadata:
  node_type: memory
  type: project
  modified: 2026-07-20
---

Surfaced while live-testing the `sys-deps` zenka's on-demand idle-shutdown path (see
[[project-sys-deps-wiring-completion]]) — the user reported it restarting immediately after a clean
64s idle shutdown despite `restart.disabled = 1` in its `start.cfg` config.

**Root cause, confirmed live via `v7.dump ondemand` on the `base` branch's running system**:
`v7.ondemand_zenki = []` — completely empty — despite ~56 zenki configured `start.on-demand = 1`.

Two pieces combine to cause this:

1. `src/v7.post_init` (pre-fix) only called `<[v7.set_up_ondemand_zenki]>->( @{$added_all_ref} )`
   inside `if ( @{$added_all_ref} )` — `$added_all_ref` is the diff between the zenki config list this
   run and the list from the *previous* `v7.post_init` run (`<[base.diff_array]>->( $prev_all,
   \@all_zenki )`), i.e. only zenki whose config is *newly discovered* since last time. On a fresh v7
   boot `$prev_all` is empty so this happens to be everything — but on any subsequent `v7.reload` it's
   only whatever's new in that specific reload.
2. `src/v7.set_up_ondemand_zenki` does `<v7.ondemand_zenki> = [];` unconditionally, then rebuilds
   strictly from `@_` (whatever it was called with). It's a full-state-rebuild function being fed a
   partial delta.

Net effect: the very first zenka added after boot correctly gets the full ondemand list built. Any
*later* reload that discovers even one new zenka config re-triggers the rebuild with only that one
name, wiping every previously-known ondemand zenka off the list — including ones that were never
touched, never reconfigured, just already-known. Over enough reloads the list decays toward whatever
was most recently "new," in this case ending at empty.

**Why this breaks idle shutdown specifically**: `src/v7.process_zenka_end:78-106` sets
`$next_status = 'error'` whenever `$current_status` was `online|error|starting` (which a healthy
running-then-idle zenka always is), then has an override block that flips it back to `'offline'` *only
if* the zenka's name is found in `<v7.ondemand_zenki>`. `base.handler.ondemand_timeout` calls `exit(0)`
cleanly on idle shutdown — the exit code is fine — but once the zenka has fallen off the ondemand list,
the override never fires, `next_status` stays `'error'`, and `'error'` is one of the two statuses (the
other being anything not matching `offline|shutdown`) that triggers `<[v7.init_restart_timer]>`. This
happens *before* `restart.disabled` is ever consulted (presumably checked inside the restart timer
itself) — the zenka is misclassified as crashed before that gate is reached. Not sys-deps-specific:
every on-demand zenka on the host was exposed, including a graphics-matrix restart-loop the user had
separately tried to fix with a timeout increase (which didn't help, for the same reason).

**Fix** (`src/v7.post_init`): moved `<[v7.set_up_ondemand_zenki]>->(@all_zenki)` out of the
`if (@{$added_all_ref})` gate entirely, calling it unconditionally every `v7.post_init` run with the
*full* current zenki list, not the delta. `v7.set_up_zenka_dependencies` stayed delta-gated — not
touched, out of scope, no evidence it has the same full-state-rebuild shape.

**Confirmed fixed live**: post-fix `v7.dump ondemand` → `v7.ondemand_zenki = ARRAY:...  [56]`. sys-deps
now stays offline after idle shutdown. graphics-matrix expected to behave the same on its next idle
cycle (not independently re-verified in this session, same mechanism).

## related

[[project-sys-deps-wiring-completion]] · [[project-reload-modules-load-registry-fix]] (a sibling
"reload doesn't fully refresh derived state" bug in the same area, found the same week)

#,,..,.,,,..,,,.,,.,,,,,.,,..,...,.,.,,.,,,,,,..,,...,..,,...,...,..,,,.,,.,.,
#AP6MUWBPCIIESLM5VLNSTVOR5K6F2GJUNYBKF35JWY2EB535JJ5AMKHP2CM6E6ERSALYCALYV6K2O
#\\\|3JKF2BAETXTH5J6TDV4OUJ764G44VJ7FKWDWOELQKZNDCJU5PP2 \ / AMOS7 \ YOURUM ::
#\[7]Q7G4STTLGX6DR7BQSAIC7QAIWRKQI7YODH2PO2NJAJY4662FLEBQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
