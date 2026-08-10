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
5. **phase 2 rendering** (`a291e63a1`, dispatched to kimi K3-256k, not
   K2.7 — genuine interface-design work, not pattern-mirroring):
   `editor.ui.ascii_frame.render_form`/`render_field`, implementing the
   `editor.ui.*` contract from `editor-namespace-interface-design.yaml`
   against the existing `ascii.frame.*` mockup/render engine. Built
   against a synthetic test fixture (`data/yaml/ascii-frames/
   user-edit-test-form.yaml`, modeled on the pre-existing
   `user-profile.yaml` mockup format) since no real settings field list
   exists yet. Focus/cursor indication: the active field's value is
   bracket-wrapped with an inline `|` cursor marker inserted at the
   character offset, BEFORE being handed to `ascii.frame.render` — this
   works cleanly because `ascii.frame.render` computes both its
   required-width and per-row fill padding from `length()` on the same
   values hash, so a decorated value stays self-consistent automatically
   (independently re-verified against the actual render code, not just
   trusted from kimi's summary). Cosmetic-only caveat: total frame width
   can shift ±3 columns across focus changes when the active row becomes
   the widest one. No bugs found this round.

**Runtime-surface question RESOLVED (2026-08-10, per user)** — was the
prior blocker on phase 2, now settled: `user-edit` is terminal-first
(`ascii.frame.*`, no amos-term dependency — this is what phase 2 above
implements), `users`/5PN is HEADLESS entirely (no UI of any kind), and a
GTK3-class GUI backend via amos-term (its plugin system's `render`/
`input`/`interaction` hooks) is real and planned but explicitly a LATER,
ADDITIVE second `editor.ui.*` backend — not something phase 2 needed to
build toward, and not amos-term-specific to this zenka (general
infrastructure for other settings UIs too, per user direction).

**What's NOT built and why** (real blockers remaining):
- the actual interactive read-key loop / `phase_3_form`'s submit flow,
  the `end_code` shutdown flush, and the field-transition draft-save
  trigger — all need either a real field schema to test against or at
  minimum a live console session, neither of which exist yet
- the `users.*` command surface (get/set for a user's editable
  fields) is 5PN's to define — nothing in `users-zenka.yaml` is
  implemented yet, it's design-only. This is the actual current
  blocker: phase 3 needs real fields to build a real form around, and
  those come from 5PN.
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

**Next step**: 5PN (`users-zenka.yaml`) needs to move from design to a
real `users.*` command surface before `phase_3_form` (the interactive
loop) can be built against real fields rather than the synthetic
fixture. Until then, this is a natural pause point on the `user-edit`
side specifically.

Also fixed along the way (unrelated to user-edit, found via a live task
abort during this work — see
[[feedback-stream-repetition-homogeneous-false-positive]]): `coding.
detect_stream_repetition` was false-flagging legitimate homogeneous
character runs (this codebase's own `ascii.frame` border fills and
AMOS7 signature terminators both qualify) as degenerate model output.
Fixed in `c39873f93`.

#,,.,,,..,,..,...,.,.,,..,.,.,...,.,.,,,.,,,.,..,,...,...,.,.,,,,,.,,,...,..,,
#JKXKL6DAVJ5HH32W4KQU7ME2L66EH7M6ZXNPRGEDQ6UX7AXBZX5W323H4I24AQIKNYQF45W3FZ6DK
#\\\|RIP5AD4Y2KZDJT7NWJQGUCEF3HX443OT257HP25BS563RSTNL2U \ / AMOS7 \ YOURUM ::
#\[7]ZM52D5IQIVEMYNZOGDGZOOK6EMPCSAF24IARXHZYROX6EGAPCEBQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
