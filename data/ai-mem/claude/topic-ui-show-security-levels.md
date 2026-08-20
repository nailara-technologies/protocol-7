---
name: topic-ui-show-security-levels
description: ui-show security-level system — steps 1-4 ALL LIVE (687f7daba, 2026-06-13); generic *.ui-show grant now active. steps 5-6 (per-zenka level 1+ fields, key-based auth) open
metadata:
  node_type: memory
  type: project
  originSessionId: 9ecacc19-6948-4beb-892e-5af7d7d24068
---

design doc: `data/md/design/UI-SHOW-SECURITY-LEVELS.md`. task files moved to
`data/tasks/completed/`: `ui-fields-fallback.md`, `ui-unfold-fields-filtering.md`,
`ui-caller-security-level.md`.

## status (2026-06-13) — steps 1-4 COMPLETE

- `ui.fields.fallback` + `ui.unfold`/`ui.render.fallback` field-map +
  level filtering landed earlier (`d3f4e5aca`, `c2d400dfe`).
- `ui.caller.security-level` got its real implementation this session
  as `5c5deed50`: resolves caller via new shared helper
  `base.session.user` (also used by `base.handler.command` and
  `base.cmd.whoami`), expands groups via `base.access.special-user-map`,
  admin groups (cmd_mask matching `**`) -> unbounded sentinel
  `1_000_000`, per-group `access.security-level.usr.<group>` attribute
  validated in `base.parser.access_conf`.
- step 4 landed as `687f7daba`: added `*.ui-show` to the generic
  `access.cmd.usr.*` block in `cube/access.zenki`. confirmed this
  wildcard shape (`*` as the zenka-name segment left of `.`, compiles
  to `[^\.]+\.ui-show` per `base.parser.access_conf`) is identical to
  already-proven patterns `*.subname`/`*.heart`/`*.host-status`/etc, and
  `system.access.wildcards.allow = yes` is set globally in
  `cfg/shared-params` — no new wildcard infra needed.
- known minor gaps: `idle`, `restart-count`, `log-file` fields return
  empty for v7 (no generic tracker / `<log.protocol_7.path>` only set
  by `p7-log.init_code`, not loaded by all zenki) — not blocking,
  follow-up if needed.
- live test still pending: `p7c <zenka-without-own-ui-show>.ui-show`
  after reload, to confirm the generic grant resolves through cube
  routing for a non-admin caller.

## step 5 COMPLETE (2026-06-13, `36d605896`)

`credential_fabric.cmd.ui-show` (tier-2 custom command) now calls
`<[ui.caller.security-level]>` directly and gates two views: `slots`
(registry_list, slot names) requires level >= 1, `slot <name>`
(registry_detail, metadata) requires level >= 2. below threshold ->
plain `[ restricted — ... ]` message, no frame call. `overview` and
`relays`/`holder` unchanged. no `<namespace>.ui.fields` map needed —
tier-2 renderers self-gate per design. kimi dispatch, verified
`perl -c` clean, task file in `data/tasks/completed/
ui-credential-fabric-slot-levels.md`. live caller-level test (level 0
vs 1 vs 2 vs admin) still pending.

## OPEN

- step 6: generic key-based level authorization (separate, later)
- [[topic-os-command-zenka]] is a planned *consumer* of the
  `access.security-level.usr.*` attribute / `ui.caller.security-level`
  resolver beyond `ui-show` itself — could be the real-world driver for
  step 5/6.

#,,..,,,,,...,,.,,,..,...,,.,,.,,,,,,,,..,,.,,..,,...,...,..,,..,,,.,,.,.,.,.,
#6FA4C2V52DJFIOWERPXTD5KOAIHLYBT3LL6N7RTNO4CZAJ3EIDTIQHEV3BYWSC2DROTSK3ANFPXAI
#\\\|6MZ2MREB7XPSXU7CVM2RCRLZLS4KDRTYEH5CHOAUCQWDRI2UPLB \ / AMOS7 \ YOURUM ::
#\[7]ZBWP2IUEBSKN47MP4V6OVYHFSHWDAJZJHDZGJRNS2NBWA2GBOCCQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
