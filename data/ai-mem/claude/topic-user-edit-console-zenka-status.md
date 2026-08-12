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

6. **phase 1 network-connectivity fix** (`43d22a1f8`, hand-edited
   directly, not dispatched — small enough with a tight precedent):
   phase 1's `start` file, cloned from `keys`' fully-standalone pattern,
   had NO network connectivity at all — a real gap in already-committed
   work, caught by the user before phase_3 could get built assuming
   connectivity that didn't exist. Fixed by mirroring `nshell/start`
   closely: `auth.client net protocol io.unix` added to `modules.load`,
   `system.auth-user = <user-edit.unix_user>` (Unix-user auth, not a
   zenka credential — personal console, same reasoning nshell uses),
   `[base.net.connect:'unix']` added, `[base.get_session_id]`
   intentionally skipped (same reason nshell skips it). Five new
   `source/` placeholders. Also fixed in the same commit: `user-edit.
   init_code`'s `HOME_N` keyword was resolving `~/.n` via a raw
   `AMOS7::FILE::get_homepath()` perlmod call — user pointed out
   `base.get_homedir` already exists as the P7-native wrapper for this,
   already used by `crypt.C25519.get_usr_keys_dir` for this exact
   purpose. Switched to match — worth remembering as a general lesson:
   check for an existing `base.*`-namespace wrapper before reaching for
   a raw Perl-module call, even when the raw call works fine.

**Two new design-only additions** (both docs, 2026-08-10, per user
direction — NOT implemented yet, design sections only):
- `external_source_hooks` (`users-zenka.yaml`) — users zenka will need
  async hooks out to external sources: key generation (crypt.C25519,
  not confirmed callable this way yet) and data lookup from other zenki
  (unnamed which ones). Correct mechanism identified: `{ mode =>
  'deferred' }` + `base.callback.cmd_reply`, exactly as `mpv.cmd.quit`/
  `mpv.snapshot.cmd_reply` already do — nested one level for the
  cross-zenka round trip. FALSE START avoided and documented in the doc
  itself: `base.handler.hooks.register/unregister` looked promising
  but is session I/O interception (input-pre/output/command hooks on a
  connection), wrong fit — don't repeat that dead end.
- `display_update_trigger` (`user-edit-console-zenka.yaml`, inside
  `phase_3_form`) — use `base.event.add_var` (real precedent:
  `jobqueue.event.register_job_queues` watches a scalar ref, fires a
  handler on write) to unify keystroke-driven and async-arrival-driven
  re-renders under one mechanism, rather than manually threading
  render calls through every mutation site. Also corrected
  `phase_3_form`'s sketch: NOT a blocking "read key" loop — needs
  `event.add_io` on STDIN mirroring `nshell.setup_stdin_watcher`
  exactly, since keyboard input and network replies (including the
  external-hooks deferred replies above) must both flow through the
  same event loop concurrently. This is why the variable-watcher
  mechanism was upgraded from "additive" to load-bearing in the doc —
  there's no other natural redraw point left once input is event-driven.

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

**Next step, as of end of 2026-08-10 session — two open paths, neither
started**:
  1. 5PN (`users-zenka.yaml`) moving from design to a real `users.*`
     command surface — needed before `phase_3_form` can be built
     against real fields rather than the synthetic fixture. This also
     means starting to resolve 5PN's own still-open questions:
     `discovery_integration` (integrate with `discover.*` or not) and
     `external_source_hooks`' two items above (is crypt.C25519 callable
     for key-gen this way? which zenka(s) for data lookup?).
  2. OR: `user-edit`'s phase_3 event-driven loop scaffolding itself
     (the `event.add_io`/STDIN-watcher + `base.event.add_var` design
     from this session) could be built and exercised against the
     EXISTING synthetic test fixture first, independent of 5PN — same
     "build against a fixture, not real fields yet" approach phase 2
     already used successfully. Might be the better next dispatch
     target if 5PN stalls, since it doesn't block on that work at all.
  Neither has been started; pick either as the next session's opener.

Also fixed along the way (unrelated to user-edit, found via a live task
abort during this work — see
[[feedback-stream-repetition-homogeneous-false-positive]]): `coding.
detect_stream_repetition` was false-flagging legitimate homogeneous
character runs (this codebase's own `ascii.frame` border fills and
AMOS7 signature terminators both qualify) as degenerate model output.
Fixed in `c39873f93`.

**2026-08-11 UPDATE — the "next step" above is stale; both paths have
now moved.** 5PN's `users.*` surface is real, not design-only anymore:
`modules/users.cmd.value-get/-set/-all` (phase 1, `df2e83d85`/
`25a4bf1ab`) plus a proper envelope schema
(`modules/users.record.build`/`.validate`, name/checksum/timestamp/
metadata/fields, `24c58a9d1`) and, further out, a working `remote-get`/
`remote-fetch` cross-host pair (`e4185e78b`, see
[[project-users-zenka-unblocks-cross-host-testing]]). `external_source_
hooks`'s two open items are both resolved: key generation is in-process
(`crypt.C25519` added to `users`' own `modules.load`, autocreate
handles it — NOT a cross-zenka hook as originally drafted), and the
data-lookup zenki are named (`udev`/`fs`, see `users-zenka.yaml`'s
`data_lookup_zenki_RESOLVED`). `user-edit` also got its own
LOCAL-vs-DELEGATED key-ownership resolution (LOCAL: `crypt.C25519`
added back to its `modules.load`, live-verified to autocreate the same
`taeki.base` identity `keys` zenka already uses).

Real next blocker now: `user-edit`'s `phase_3_form` event-driven read-
loop / actual field schema still hasn't been built — that's the
genuinely unstarted piece, not 5PN (which was the blocker described
above and no longer is).

**2026-08-12 SESSION — phase 3 BOTH SLICES LANDED, plus four framework
fixes and three new directions.** Commits `c6ff73f57` (slice 1),
`e11800518` (slice 2), `f9c51a636` (keys), `e0cfb09a7` (no-tty driver),
`d0848477b` (subnames), `adf5bb13a`/`2a9617bc6`/`b2aae999f` (memory +
framework).

**Slice 1 — record-derived form.** `user-edit.console.show-form` →
`users.value-get` → envelope → `user-edit.form.schema_from_record` →
`user-edit.form.build_frame` → phase 2's `render_form`. Per user, the
field list is DERIVED FROM THE RECORD at runtime, not declared — the
settings payload is deliberately open and no field list exists anywhere.
Because the field set is unknown until the record arrives there can be no
`data/yaml/ascii-frames/*.yaml` for it: `build_frame` assembles the mockup
in memory, parses it with the same `ascii.frame.parse`, and seeds
`<ascii.frame.cache>` directly, so `render_form` needed NO change.
`form.render` regenerates it when missing (`ascii.frame.init_code` wipes
that cache on reload and there is no file to fall back on).

**HYBRID LOOP MODE resolved** — console commands needing the event loop
call `[init-done:TRUE]` + `[zenka.loop]` THEMSELVES as their last step,
NOT the start file, because `commands`/`describe` must print and exit.

**Slice 2 — event-driven form.** `start [<username>] [-no-tty]`;
termios raw mode (`user-edit.term_init`/`term_restore`, `nshell` shape,
TCSANOW on restore), `event.add_io` on fd 0 → `handler.stdin_key`,
`event.add_var` on `<user-edit.form.dirty>` → `form.render`. Nothing
renders directly: every mutation bumps the counter, the watcher repaints.
New shared `editor.input.next_key` decodes one key (utf-8 char or whole
ANSI sequence) and returns undef WITHOUT consuming on a partial sequence —
that is what makes the non-blocking path safe. Submit is outbox-FIRST then
`users.value-set`; staged entry cleared only on confirmation, KEPT on
rejection. `format.json.encode` is `pretty(1)` so its output is flattened
before going on the line-based wire (safe: a real newline only ever occurs
as formatting, json escapes in-string newlines as `\n` — round-trip
verified).

**keys zenka loaded directly** (`f9c51a636`) — per user, rather than
reimplementing key handling as user-edit grows. Verified already safe, no
changes to `keys.*` needed. Safe for a NETWORKED zenka because keys has NO
`.cmd.` modules at all — pure `.console.*` + helpers, so zero network
surface added. Curses::UI/Term::Clui stay lazy (phase 1's criterion holds).
Side effects to know: `keys.init_code` overwrites `<system.amos-zenka-user>`
globally, and `keys.post_init` hard-exits on `crypt.C25519.key_vars_error`.

**Network-driven form input** (`e0cfb09a7`) — `user-edit.cmd.char-add`,
modelled on nshell's, plus shared `editor.input.parse_key_spec`. Reply is
the RENDERED FORM, so it is a test surface not just a debug poke. Gated
twice (`-no-tty` required, narrow `access.cmd.usr.cube`). This is
user-edit's first `.cmd.` module. It immediately caught a shipped bug —
see [[feedback-backslash-keyword-is-not-a-reference]].

**Subname routing** (`d0848477b`) — `taeki[user-edit]` vs bare `taeki`
(nshell); see [[reference-session-subname-routing-convention]].

**STILL NOT DONE — the honest list:**
- **the interactive form has NEVER been run at a real terminal.** Only the
  no-tty driver path is verified (insert, Ctrl+a/Ctrl+e, Backspace,
  Delete, named keys, sequences). Tab/field navigation, the
  `form.field_changed` draft checkpoint and submit are ALL unexercised —
  Tab is gated behind `$multi_field` and `selftest` has ONE field.
- **`masked`/`enum` field types** — `editor.control.create` still
  hard-rejects everything but `freeform_line`. This is the single blocker
  on [[project-credential-types-into-user-edit]], since all three
  secret-holding paths collect input with BLOCKING prompts that cannot run
  inside the event loop. `base.term.ask` does NOT solve this — see
  [[reference-console-question-ask-primitive]] for why an event-loop-safe
  prompt is a separate unbuilt thing.
- **the offline retry trigger** and the `end_code` draft flush.
- **no `taeki` record exists** — `show-form` errors with "user 'taeki' not
  found". Design in progress per user: detect the case where the invoking
  unix user equals `<system.admin-user>` (`configuration/system-user-map`,
  resolved via `base.access.special-user-map`'s `<admin-user>`) and offer
  to create a default record, interactively unless a `:create-admin:` tag
  is passed. `base.term.ask` was built for exactly this. **BLOCKED on deciding
  the DEFAULT FIELD SET for a host-system record** — creating it empty
  does not work (`schema_from_record` returns undef, so the error just
  moves). That decision also sets the template the uninstalled desktop
  node's `taeki` AND `root` accounts would inherit.


**2026-08-12 (later) — create-admin LANDED, and the record now exists.**
`v7.user-edit show-form` no longer dead-ends on "user 'taeki' not found".

Authority side owns the shape, per user: `users.record.default_fields`
(freshly-built hashref each call, NOT cached) + `users.cmd.create-default
<username>`, which **refuses an existing record** and deliberately does NOT
route through `users.cmd.value-set` (that one is create-or-overwrite by
design — right for an edit, wrong here). Reachable without user-edit at all,
which is the point: an installer provisioning the desktop node's `root`
account calls `p7c users.create-default root`. Default fields: `contact`,
`location`, `note`, all empty strings — empty values render fine
(`schema_from_record` only skips non-`\w+` names and REF values; the keys are
what make an empty record editable).

**The control-flow problem and its solution — the interesting part.** The
"record does not exist" answer is necessarily ASYNC (user-edit runs as the
invoking unix user and cannot even stat `USERS_HOST`, `0770` owned by
`<system.amos-zenka-user>`), so it lands in a reply handler INSIDE the event
loop — where `base.term.ask` must never run. So `user-edit.handler.
value_get_reply` sets `<user-edit.pending.create>` and calls
`Event::unloop()`; `base.zenka.loop` returns; the console command resumes in
`user-edit.offer_create` OUTSIDE the loop and prompts there; on yes it sends
`create-default` and RE-ENTERS the loop, whose reply re-issues `value-get`
and stays in the loop so the render path is untouched. **Re-entry is
explicitly supported** — `Event.pm:157` sets `$TopResult = undef; # allow
re-entry of loop after unloop_all`, and `base.zenka.loop`'s init-done guard
is already satisfied on the second call. Note `base.zenka.loop` DISCARDS the
unloop result, so a pending-state variable is the only channel back.

Four guards, all verified live:
- `<user-edit.offer.create>` — **the caller owns the loop**. Gating on
  admin-ness alone would let this handler tear down a loop belonging to some
  other caller (a `char-add`-driven flow, say).
- `<user-edit.create.attempted>` set BEFORE the send — a create that succeeds
  while `value-get` still 404s would otherwise re-offer forever.
- exact-match on `sprintf("user '%s' not found", $username)`. `false` mode is
  OVERLOADED on the users side (not-found, usage errors, AND `"record
  invalid"`), so a substring test would offer to overwrite a CORRUPT record.
  Coupled string, cross-referenced in both files; a near-miss logs at level 1
  so wording drift shows up instead of silently killing the feature.
- `-t STDIN`, **not** `AMOS7::TERM::has_tty` — has_tty also accepts a
  `Term::ReadLine->findConsole` `/dev/tty` hit, so `show-form | cat` would
  print the prompt into the pipe and block on the terminal.

`:create-admin:` skips the prompt via `base.term.ask`'s `given`, and is
honoured ONLY when target == invoker == `<system.admin-user>` — otherwise it
is ignored and falls through to the prompt, so it cannot silently create
third-party records. `user-edit.parse_params` does the tag splitting
(`base.call.console_command` does exactly ONE split, so there is no framework
tag parsing; `keys.console.list`'s whole-string equality cannot handle
`show-form taeki :create-admin:`). It is NOT under `user-edit.console.*` —
that namespace IS the command registry, so a helper there becomes invocable.

**Verified live, headlessly:** create/refuse-if-exists/read-back; tag path;
third-party guard (`show-form bob :create-admin:` creates nothing); pipe
safety (no hang, no prompt into the pipe); a non-not-found `false` falls
through to the original error; regressions clean.

**AND — the long-outstanding tests finally ran**, since `taeki` now has three
fields (previously blocked: `selftest` has one, and Tab is gated behind
`$multi_field`): Tab navigation moves 1-of-3 -> 2-of-3 with values retained;
the field-transition draft checkpoint writes `[VAR_P7]/draft/taeki.yaml`
(`/var/protocol-7/user-edit/`, 0640 taeki:taeki) containing only the
completed field; submit does outbox -> `value-set` -> `<< saved >>` -> outbox
AND draft cleared -> process exits; the record keeps its creation `timestamp`
while `updated_at` bumps.

STILL not run: the INTERACTIVE prompt at a real terminal (needs a tty; every
path around it is verified). Gap found: there is **no `users.cmd.remove`**, so
a record cannot be deleted once created — a `testuser` test record is stuck
in the store.

#,,,,,,,.,...,,,,,,,,,.,,,,..,.,.,,.,,.,.,..,,..,,...,...,.,,,,,.,,..,.,,,,..,
#AA562NQCZPTGV7IROKWHTCJSELGL63753BK4KG5DY2Y4VSAETHAJVZSJC3JOWNMC4QLBQZMOKBN6E
#\\\|K37INFT76PZM3TT5TBHMB6TKCMP47LSCTWH4XRANOPIAUSEEIXN \ / AMOS7 \ YOURUM ::
#\[7]QHCPOAW6ZRIX65FMHVEZ7Z7I7VN3JRCI4DEWR5UNJKY5B4LWEGAQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
