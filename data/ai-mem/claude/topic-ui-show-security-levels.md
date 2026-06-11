---
name: topic-ui-show-security-levels
description: ui-show security-level system — steps 1-3 (field map, level filtering, caller resolver) LIVE as d3f4e5aca; step 4 (*.ui-show generic grant) deferred
metadata:
  node_type: memory
  type: project
  originSessionId: 9ecacc19-6948-4beb-892e-5af7d7d24068
---

design doc: `data/md/design/UI-SHOW-SECURITY-LEVELS.md`. task files:
`data/tasks/ui-fields-fallback.md`, `data/tasks/ui-unfold-fields-filtering.md`,
`data/tasks/ui-caller-security-level.md`.

## status (2026-06-11)

- steps 1-3 LIVE as `d3f4e5aca`: `ui.fields.fallback` (universal level-0
  field map: pid, uptime, paths, source-age), `ui.caller.security-level`
  (resolves caller level via existing session->user->group identity
  path, admin groups -> unbounded sentinel `1_000_000`), `ui.unfold` /
  `ui.render.fallback` now render the filtered field map instead of raw
  `%data`. verified live via `v7.ui-show` after `v7.reload`.
- known minor gaps: `idle`, `restart-count`, `log-file` fields return
  empty for v7 (no generic tracker / `<log.protocol_7.path>` only set
  by `p7-log.init_code`, not loaded by all zenki) — not blocking,
  follow-up if needed.

## OPEN

- step 4: add `*.ui-show` to `access.cmd.usr.*` in `cube/access.zenki`
  — deferred until step 5 (per-zenka level 1+ field maps) gives the
  attribute slot `access.security-level.usr.<group>` a real non-admin
  consumer to validate against. currently that config key is unused
  (resolver returns 0 for non-admin groups by default).
- step 5: per-zenka level 1+ `<namespace>.ui.fields`, starting with
  `credential_fabric` (slot names/metadata) as the proven case
- step 6: generic key-based level authorization (separate, later)
- [[topic-os-command-zenka]] is a planned *consumer* of the
  `access.security-level.usr.*` attribute / `ui.caller.security-level`
  resolver beyond `ui-show` itself — could be the real-world driver for
  step 5/6.

#,,,,,...,,..,,,.,,.,,.,.,,,.,,..,,.,,,.,,.,,,..,,...,...,.,.,,,.,.,.,,.,,..,,
#2G2TKT53IF6NI7SNXJ72HSHK4NF77HDOVEBGFLTOTFM72NYNSDVFAWH2JXUM4HE7AK3VI3F3PXASE
#\\\|FEF5OITNLO5L2SV7LBIS6FGNZ4G4JACRRL5J2GW5U6UK5R5XBK7 \ / AMOS7 \ YOURUM ::
#\[7]EHF6M6UOP2UT5FJA6IXXWCXGFCKUSOVHDSEFZB2R6RDXXQXS6EBY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
