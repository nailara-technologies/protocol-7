---
name: feedback-v7-zenka-startup-config-placement
description: "start.cfg keys must sit at top level, not inside a ':' section, or v7 never sees them — and v7.reload config doesn't re-parse the file at all"
metadata: 
  node_type: memory
  type: feedback
  originSessionId: 441e75cb-3feb-4f58-b8c1-d172ab305359
  modified: 2026-07-22T13:30:28.946Z
---

In a `cfg/zenki/<name>/start.cfg` file, only **top-level**
`key = value` lines (outside any `: section-name :` block) get parsed into
`<v7.start_setup.zenki.config>->{$zenka_name}` — the hash `v7.zenka.cmd.start`
actually reads for things like `max_concurrency` / `max_subname_concurrency`.
Lines placed inside a section like `: v7-init :` are executable init-code
that runs in the *spawned instance's own* namespace instead — they silently
never reach v7's own config hash.

Found live: `cfg/zenki/web/start.cfg` had `max_concurrency = 1`
nested inside `: v7-init :`. The concurrency gate's own
`exists $zenka_config->{'max_concurrency'}` check was always false for `web`,
so v7 never rejected extra starts — an on-demand-triggered spawn (httpd
routing to `web` with none live) raced against a manual `v7.start web`, both
succeeded, and `web` (meant as a singleton) ended up with multiple live
sessions under one name. Compare `cfg/zenki/cube/start.cfg`,
which has `max_concurrency = 1` correctly at top level and enforces
correctly (`v7.start cube` rejects as expected).

**Why it's easy to miss**: the file has no visual boundary warning — a
`: v7-init :` section just looks like more indented config, and both
top-level and in-section keys use the same `key = value` syntax.

**How to apply**:
- When adding `max_concurrency` / `max_subname_concurrency` (or anything else
  meant to be read by `v7.zenka.cmd.start`'s own gates) to a
  `start.cfg` file, put it **before** the first `: section :` header.
  Verify against a working reference file (e.g. `cube`'s) if unsure.
- `v7.reload config` does **not** re-parse `start.cfg` — that file is
  only parsed by `v7.init_start_setup`, called once from `v7.init_code` at
  v7's own process init. After editing any `start.cfg`, use
  `v7.reload all` to make v7 re-run its own init and pick up the change.
  **Correction (2026-07-26)**: the parenthetical `(or v7.reload init)`
  this note originally suggested was confirmed to reliably crash the
  entire backend — see [[feedback-v7-reload-init-live-swap-subs-crash]]
  for the full incident and root cause (`base.swap_subs`'s destructive
  wipe firing on a stale snapshot). **Fixed as of that note** (bin/Protocol-7
  + base.swap_subs + base.handler.deferred_compile) — bare `v7.reload init`
  is confirmed safe again on a live process. Still prefer `v7.reload all`
  when in doubt, since it's the one that was always intended for this.
  This is the same class of pitfall as
  [[feedback-config-reload-clobber]] (config-reload semantics being narrower
  or different than expected) but the inverse direction — there it clobbers
  runtime values on reload, here a reload silently *fails to apply* a file
  edit at all.
- To verify a concurrency gate is actually live for some zenka: `v7.list zenki
  <name>` shows instance status, but doesn't prove the gate itself works —
  the only real proof is attempting an over-limit `v7.start <name>` and
  confirming rejection (`reached configured maximum concurrency for zenka
  '<name>'`).

See [[zenka-name-routing-modes]] for the downstream design work this
incident motivated (bare-name routing ambiguity when a supposedly-singleton
zenka ends up with multiple live sessions).

**Confirmed again, 2026-08-22, for a slightly different case — a
zenka with NO `start.cfg` at all yet**: brought `plan-9` from
"never had a `start.cfg`" to startable by writing one from scratch
(see `data/tasks/completed/plan-9-server-event-loop-wiring.md`). Bare
`v7.reload` (not `reload config`) was what made `v7.list available
plan-9` start showing it and `v7.start plan-9` stop saying "zenka
plan-9 not found in set-up" — consistent with this memory's claim that
`start.cfg` is only parsed at `v7.init_code`/`v7.init_start_setup`
time, now confirmed for the "brand new file didn't exist before" case
too, not just "existing file's value changed."

#,,,,,,..,,,.,...,,..,.,.,,,.,,,,,,,.,...,.,.,..,,...,...,,,.,,..,,..,..,,,..,
#J43J7YPAX3OJX54ALJWTPMXH2IAQXRIJAZQ6ZWOIIHFTKURR3BNP54JQRSRSRT7QFH5WIVLLCYSZS
#\\\|SWLO2RNH7WL77PFXHRS4RQ4563NLXXNAASVA7KCWTVR2AXCDUNC \ / AMOS7 \ YOURUM ::
#\[7]ZJQSZYZXTTT3VLANRBCF4762HOBMWV4RD7QI74JY7PLZGUOPFQCY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
