---
name: topic-user-edit-console-zenka-status
description: user-edit console zenka (todo JUE) + users v7-managed zenka (todo 5PN) -- two design docs written 2026-08-09/10, four implementation phases landed on user-edit via kimi K2.7 dispatch (skeleton/path-registry/outbox/draft-storage), next phases blocked on real open questions
metadata:
  type: project
---

Two new-zenki design docs, both signed and committed:
- `data/yaml/coding-tasks/user-edit-console-zenka.yaml` (todo JUE) — an
  interactive multi-field settings console, built on `editor.control.*`
  (see [[topic-editor-namespace-migration-status]] — its step_4 blocker
  turned out to already be resolved), `ascii.frame.*`/amos-term rendering,
  a `base.path.register_keywords` path registry, and an offline-capable
  local outbox + draft-auto-save pair modeled on `mpv.snapshot.*` and
  `protocol-7-menu`'s drag-handler save-on-release pattern.
- `data/yaml/coding-tasks/users-zenka.yaml` (todo 5PN) — the canonical
  backing zenka: `/etc/protocol-7/users/host-system/` (local authority)
  + `/etc/protocol-7/users/remote/{incoming,outgoing}/` (discovery),
  likely integrating with the existing `discover.*` namespace
  (`discover.orbital.store_remote` already tracks hostname+pubkey+p7ref
  per known remote node, in memory only — persistence is the actual gap
  5PN would fill), plus a key-authority role for routing. user-edit has
  NO local canonical storage of its own — it's a thin client that will
  call a `users.*` command surface 5PN has not yet defined.

**Implementation landed on `user-edit`** (all four dispatched to kimi
K2.7 via self-contained task files in `data/tasks/user-edit-phase*.md`,
each reviewed against the actual diff before signing, not just the
kimi auto-summary — see [[feedback-narrow-scoped-kimi-task-file-pattern]]
for why this dispatch shape worked well four times in a row):
1. **phase 1 skeleton** (`0fee40f7c`) — `configuration/zenki/user-edit/`
   + `modules/user-edit.init_code`, cloned from `keys`' thin
   standalone-console shape (no crypt.C25519, no network modules). Kimi
   caught and fixed a real contradiction in the task prompt itself (a
   generic networked-zenka boot sequence I'd pasted, vs. the actual
   `keys/start` standalone pattern the task also pointed at) —
   documented its own reasoning in `data/ai-mem/kimi/
   topic-user-edit-phase1-skeleton.md`. User then manually fixed the
   `start` file's shebang line (not needed — the `v7.<zenka>` symlink
   in `/usr/local/bin/` handles invocation instead).
2. **phase 1b path registry** (`2a49e0226`) — registers `VAR_P7`/
   `ETC_P7`/`HOME_N` (the zenka's own dirs + `~/.n`, not previously a
   registered keyword anywhere despite being a real live convention —
   `crypt.C25519.get_usr_keys_dir` etc. all hardcode it independently)
   via `base.path.register_keywords` in `user-edit.init_code`. Kimi
   correctly used the swapped-module-family short form
   (`<[file.zenka_dir.data_path]>`, not `base.file.*`) — a documented
   common kimi mistake area it got right here.
3. **outbox primitives** (`81d58ccd4`) — `user-edit.outbox.write/list/
   clear`, `[VAR_P7]/outbox/<id>.yaml` via `format.yaml.write_file`.
   Found and fixed one real bug after kimi's syntax-check-passed
   summary: `outbox.list` called `file.all_files` on a possibly
   nonexistent directory, which logs a `base.s_warn` warning for a
   totally normal state (outbox never written to yet) — added a `-d`
   guard before the call.
4. **draft storage primitives** (`15c7707aa`) — `user-edit.draft.write/
   load/clear`, mirroring the outbox set under `[VAR_P7]/draft/`, plus
   an empty-state guard on write (mirroring `mpv.snapshot.write`'s
   precedent) returning a distinct `'skipped'` state so a caller can
   tell "nothing to save" apart from both `TRUE`/`FALSE`. This one
   was clean — no fixes needed, and it proactively avoided the outbox
   bug (`draft.load` uses a plain `-f` check instead of `file.all_files`).

**What's NOT built and why** (real blockers, not just "not gotten to
yet"):
- `phase_2_rendering` / `phase_3_form` (the actual editor UI, submit
  loop, end_code shutdown flush, field-transition draft-save trigger)
  are blocked on an unresolved runtime-surface question: does
  user-edit run as a plain terminal console (`ascii.frame.*` only) or
  hosted inside an amos-term window (`amos-term.plugin-render`/
  `plugin-input`, a general 5-hook-type plugin system amos-term
  gained recently — decoder/routing/render/input/interaction)? Both
  are consistent with everything built so far; the design doc's
  `amos_term_plugin_overlap` section flags real overlap risk on
  `render`/`input`/`interaction` hooks specifically, not yet resolved.
- the `users.*` command surface (get/set for a user's editable
  fields) is 5PN's to define — nothing in `users-zenka.yaml` is
  implemented yet, it's design-only.
- a third, unrelated zenka named `settings` is still planned (the name
  was freed by `set-up`'s rename from `settings`, commit `089844a94`)
  — its relationship to 5PN's `host-system/` storage claim is an open
  question flagged in both docs, not resolved.

Also surfaced along the way: `modules/format.json.*`/`format.yaml.*`
are already-existing symmetric shared serialization modules (JSON::XS/
YAML::XS-backed, `format.yaml.load_keyword_path` already composes with
`base.path.resolve_keywords`) — used throughout the outbox/draft
modules instead of bespoke `YAML::XS Load/Dump` call sites. set-up's
JSON-only profile format is a kiosk-appliance-era holdover per the
user, not a convention to match; project direction is minimize JSON,
YAML as the fallback where no native format exists.

**Next step**: resolve the runtime-surface question (terminal vs
amos-term-hosted) before dispatching phase_2_rendering — it changes
which of `ascii.frame.*` vs `amos-term.plugin-render` is the actual
integration point.

#,,,.,...,.,.,.,.,.,,,,..,..,,.,.,,..,,,.,,.,,..,,...,...,.,,,...,.,.,,,,,.,.,
#YPFXY2GHQBI42453XKE5VCH4U6H7EEQSJBRH2NTBRNYUFVQPI77K3IZBCDUWZX3FY3SI4AWUZJEYW
#\\\|5USEOLRTQZ2QK7LPJ3O3HTTLAOD5F4ZJDXPDNG25KYWAQX3LJON \ / AMOS7 \ YOURUM ::
#\[7]TPUIHPIALI723NDWKASDG22C2FZKCY65DVNORPFPVLDBJGOIDGBQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
