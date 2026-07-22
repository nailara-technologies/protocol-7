---
name: feedback-v7-zenka-startup-config-placement
description: "zenka-startup.v7 keys must sit at top level, not inside a ':' section, or v7 never sees them — and v7.reload config doesn't re-parse the file at all"
metadata: 
  node_type: memory
  type: feedback
  originSessionId: 441e75cb-3feb-4f58-b8c1-d172ab305359
  modified: 2026-07-22T13:30:28.946Z
---

In a `configuration/zenki/<name>/zenka-startup.v7` file, only **top-level**
`key = value` lines (outside any `: section-name :` block) get parsed into
`<v7.start_setup.zenki.config>->{$zenka_name}` — the hash `v7.zenka.cmd.start`
actually reads for things like `max_concurrency` / `max_subname_concurrency`.
Lines placed inside a section like `: v7-init :` are executable init-code
that runs in the *spawned instance's own* namespace instead — they silently
never reach v7's own config hash.

Found live: `configuration/zenki/web/zenka-startup.v7` had `max_concurrency = 1`
nested inside `: v7-init :`. The concurrency gate's own
`exists $zenka_config->{'max_concurrency'}` check was always false for `web`,
so v7 never rejected extra starts — an on-demand-triggered spawn (httpd
routing to `web` with none live) raced against a manual `v7.start web`, both
succeeded, and `web` (meant as a singleton) ended up with multiple live
sessions under one name. Compare `configuration/zenki/cube/zenka-startup.v7`,
which has `max_concurrency = 1` correctly at top level and enforces
correctly (`v7.start cube` rejects as expected).

**Why it's easy to miss**: the file has no visual boundary warning — a
`: v7-init :` section just looks like more indented config, and both
top-level and in-section keys use the same `key = value` syntax.

**How to apply**:
- When adding `max_concurrency` / `max_subname_concurrency` (or anything else
  meant to be read by `v7.zenka.cmd.start`'s own gates) to a
  `zenka-startup.v7` file, put it **before** the first `: section :` header.
  Verify against a working reference file (e.g. `cube`'s) if unsure.
- `v7.reload config` does **not** re-parse `zenka-startup.v7` — that file is
  only parsed by `v7.init_start_setup`, called once from `v7.init_code` at
  v7's own process init. After editing any `zenka-startup.v7`, use
  `v7.reload all` (or `v7.reload init`) to make v7 re-run its own init and
  pick up the change. This is the same class of pitfall as
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

#,,,,,.,,,.,.,...,.,,,,.,,.,.,...,...,.,,,,,.,..,,...,...,..,,,.,,,,.,,.,,..,,
#FKJRJX57QHCEQVLDTAMITTD3ZZ73WAJSMCRXQYCEF3AM7Q5NA3Z2E5YD5YZ363Y3N6BYL2EOOQODY
#\\\|YSPGTMZWBDZ5U5OMTCMOMR23PEK4OWOBBXX7MUW67IIFW7WZZPO \ / AMOS7 \ YOURUM ::
#\[7]W4E7M2TVHSQ6IBQHH62OKQEZ6C46NYTFP6BJCYKK2SRGUMO3I2CQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
