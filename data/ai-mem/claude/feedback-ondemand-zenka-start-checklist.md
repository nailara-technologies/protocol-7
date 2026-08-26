---
name: ondemand-zenka-start-checklist
description: full checklist for a working zenki/<name>/start file when bringing up a never-before-started on-demand zenka
metadata: 
  node_type: memory
  type: feedback
  originSessionId: 1fae67f1-7fe7-41e7-9119-372afacccc2b
---

A `cfg/zenki/<name>/start` file needs ALL of the following or the zenka fails/hangs at some stage:

1. `[load_config_file:'shared-params']` — sets `<system.amos-zenka-user>`, required by `base.check_dependency_dirs` (pm-dep/os-dep/source auto-creation) and by drop_privs. Without it, dependency-dir creation fails silently (undef getgrnam warnings) and drop_privs has nothing to drop to.
2. `modules.load = auth net protocol io.unix <zenka-namespace>` (+ extra namespaces like `ui`/`ui.branch` as needed) — `[load_modules:<modules.load>]` then `[init_modules]`. Listing individual sub-names instead of the namespace under-populates the dep-graph-derived `subroutines.load-early`. Regenerate via `./bin/dev/gen-sub-whitelist <zenka>` and sign with `bin/Protocol-7 sourcecode update-signatures cfg/zenki/*/subroutines.load-early`.
3. `[root.drop_privs:<system.amos-zenka-user>]`
4. `[base.net.connect:'unix']` then `[base.get_session_id]` — without these the zenka never registers a session with cube, so it never reaches "online" and v7 kills it after the start-timeout (~64.7s), looping restarts forever.
5. `[zenka.loop]`

Also required on the cube side:
- `cfg/zenki/cube/auth.zenki`: `auth.setup.usr.<zenka> = :zenka:` — without this, cube rejects the session key ("user '<zenka>' not accepted for auth type :zenka:") and the zenka can't connect at all.
- In the zenka's own `start` file, an `access.cmd.usr.cube = verify-instance commands heart reload show-buffer src-age src-ver list ...` grant — without it, cube's `verify-instance` (etc.) calls get "no perm." and the instance never transitions starting->online.
- `reload config` on cube (via `p7c reload config`) is needed to pick up `auth.zenki` changes on a running cube — `cube.reload`/`reload config/all` are NOT valid.

For dev-only `eval-code`/`exec-sub`/`set`/`del`/etc., add `devmod` to `modules.load` and `access.cmd.usr.cube`, but per [[feedback-devmod-leave-disabled]] leave the write-capable ones commented out by default.

If `v7.start <zenka>` enters a restart loop (each attempt ~64.7s), stop it with `p7c v7.stop reasoning` between fix iterations to avoid resource churn — used this repeatedly while debugging [[topic-zenka-naming-cleanup]]-adjacent reasoning zenka startup (2026-06-16).

#,,,,,,,,,.,.,..,,..,,,,.,...,...,.,.,,..,,,,,..,,...,...,...,...,,,,,,.,,...,
#F4FAFJTZWJQRVHVLLNAQXOXZ4XXGJLJST4PJ3SQEV7FU52KMSHAA5AMR2HK6S2TVWYXC7XBF4G4HM
#\\\|NBH2JAMXCR7IVE5YDF2ORJGJBI7UA3TTAGDW6VYKOQOTOO4X34P \ / AMOS7 \ YOURUM ::
#\[7]YD5UVR5VNADHL4G7TUUKNJTRW2XYO46KYN6PKZBLHMS44EICZWDA 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
