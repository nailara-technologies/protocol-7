---
name: topic-user-edit-console-zenka-status
description: user-edit console zenka (todo JUE) + users v7-managed zenka (todo 5PN) -- as of 2026-08-13, live features include windowed/scrollable list fields, canonical sort order, plugin detail-tabs (pinned-key custom rendering), a zero-field bootstrap path (contact/location now optional), and multiline note editing; see this file's tail for the most recent work
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


**2026-08-12 (later still) — create-admin landed, then the LIST field type.**
`eef14372d` (create-admin, colours, cursor forms, Esc, clear-on-exit) and
`f0d15bd28` (list field, alignment, hint block).

The record now exists: `users.record.default_fields` +
`users.cmd.create-default` (authority-side, refuses an existing record,
reachable by an installer with no user-edit). Detection is async — user-edit
cannot stat the 0770 store — so the reply handler `Event::unloop()`s and
`user-edit.offer_create` prompts OUTSIDE the loop, then re-enters.
`:create-admin:` skips the prompt only when target == invoker ==
`<system.admin-user>`.

**The interactive form is no longer unverified** — `script -qec` allocates a
pty, which is what finally made it testable. Confirmed: typing repaints (the
`add_var` watcher path), Tab and arrows navigate, the field-transition draft
checkpoint fires, submit round-trips, Esc and ctrl-c exit, and the terminal
is left with `isig icanon echo` restored. **Use `script -qec` for any future
tty-dependent test** — the no-tty `char-add` driver exercises decode/dispatch
faithfully but never touches the ACQUISITION path, which is why it missed the
`sysread() isn't allowed on :utf8 handles` failure entirely.

Colour/rendering conventions now settled — see
[[reference-editor-list-field-and-render-contract]] for the cell/marker
contract, and note: **never hardcode an SGR sequence**, go through `%colors`
so `-nc` and piped output stay honest (a literal `\e[0m` in `term_restore`
was forcing the terminal back to its DEFAULT foreground under `-nc`, the one
thing `-nc` asks us not to do). `-nc` blanks COLOURS but keeps `clear_screen`
and inverse video — it is not a request for plain text; only a non-tty STDOUT
must be escape-free. Message classes: `ok`=amber (matching keys, whose save
messages are amber because `base.log` writes to STDERR), `fail`=TRUE blue,
`no-op`=green meaning the store is untouched, NOT success.

STILL OPEN: `enum` remains interface-only; an
event-loop-safe prompt for secret entry INSIDE a running form is still
unbuilt (`base.term.ask` is blocking, pre-loop only); and there is still no
`users.cmd.remove`, so the `testuser` test record cannot be deleted.


**2026-08-12 (session end) — menu, storage restructure, add-field cycler.**
Commits `c12351f92` (namespace menu), `2bef4639b` (record-as-directory +
contact multi-valued + no vertical jump). The add-field cycler is
UNCOMMITTED and mid-flight -- see [[reference-editor-add-field-cycler]].

`v7.user-edit browse` gives namespace -> record -> form with Esc ascending;
see [[reference-editor-list-field-and-render-contract]] for the row-list
primitive and [[reference-editor-add-field-cycler]] for the inline one.

STORAGE: a record is now a DIRECTORY -- `host-system/<user>/details.yaml`.
This RESTORED the resolved design (users-zenka.yaml's directory-as-session
fallback: "a plain record can always grow a log/ subdirectory without
changing its address"), it was not a new idea. Layout lives in ONE place,
`users.record.path`. No migration code was written -- the system was fresh
and the three flat files were converted by hand. `users.record.build` still
hardcodes `"host-system:$username"` into the identity checksum: that is now
the ONLY place assuming a namespace, and the thing to revisit when remote/
lands.

STILL OPEN: the add-field cycler's live path (Left/Right + Enter) is
unverified at a pty; `enum` proper is unbuilt; the event-loop-safe secret
prompt is unbuilt (`base.term.ask` is pre-loop only); no `users.cmd.remove`.


**2026-08-12 (later) — capped list-field height + PgUp/PgDn windowed
scroll.** User request: an 8-entry `contact` field was reserving 8 blank
rows (`user-edit.form.build_frame`'s expand/collapse height-matching
reservation had no cap), making the card mostly empty space for the common
case. Fixed by capping every list field's window at 3 rows
(`editor.control.list.window_cap`, single source of truth) with a
`:..start-end.of.total..:` position row (`editor.control.list.window_info`,
same bracket family as `list.summary`) and PgUp/PgDn paging the window —
Up/Down/Tab still just move between fields as before, unchanged.

New/changed: `editor.control.list.expand` (+optional `$offset`, slices
`(@entries,'')` into a `cap`-wide window named RELATIVE to the window —
always `<field>_0..<field>_(cap-1)`, never absolute position, so
`build_frame`'s "list block starts here" detection and this module's own
first-row `active_field` targeting both keep working unchanged for every
window, not just the first; seeds `list_source.entries`/`.offset` on
EVERY call now, windowed or not), new `editor.control.list.scroll` (pure
harvest-current-window → **splice into `list_source.entries` at
`list_source.offset`** → filter blanks → re-`expand` at the new offset —
splicing rather than replacing is what stops entries scrolled off-screen
from being silently dropped), `editor.control.list.collapse` (same
splice-not-replace fix — below the cap this is exactly the old behaviour,
since the window then covers everything), new `user-edit.form.scroll_list`
(glue, mirrors `sync_list_mode`), `user-edit.form.build_frame` (reservation
capped at `window_cap` instead of full entry count — the actual fix for
the bloat — plus the indicator row's width folded into the frame's
`min_width` floor, measured at the field's LAST window since that has the
most digits), `user-edit.handler.stdin_key` (PgUp/PgDn `\e[5~`/`\e[6~`
converted to actions in the same block that already converts Up/Down),
`editor.ui.ascii_frame.render_form` (indicator row added to the
`cursor_bearing` exclusion — bracket-only focus framing, no cursor
overlaid on static text).

**Real bug caught by the live test, not by reading the diff**: the first
implementation of `editor.control.list.scroll` built a temp
`{ schema => ..., kill_buffer => ... }` stub to re-drive `expand`, skipping
`editor.control.create` — every OTHER field's value went blank on the
first PgDn (`full_user_name`/`location` vanished from the render) because
`expand`'s own "carry current buffer content across" logic reads via
`editor.control.get_value($given_state, $name)`, which needs a real
`fields` buffer hash to read from; a bare schema-only stub has none, so
`get_value` returned undef and expand's `// ''` fallback silently blanked
every field beside the list. **General lesson, extends
[[reference-editor-add-field-cycler]]'s TRAP 2** ("appending a schema def
after `create` leaves no buffer"): ANY hand-assembled state passed to code
that calls `get_value`/`get_display_value` on it needs to go through
`editor.control.create` first, not just carry a `schema` key — a state is
schema+buffers together, not schema alone, and nothing enforces that at
the call site.

**Verified live** via the `-no-tty`/`char-add` headless driver (see
[[reference-user-edit-headless-driving]]) against a throwaway
`p7-fieldtest` record seeded with 9 `contact` entries (8 + one added
during the test) and a 1-entry `phone` (regression control): frame width
AND height identical across collapsed, every window (`1-3`, `4-6`, `7-9`
of 9), and the clamped-last-window boundary (repeated PgDn there is a
byte-identical no-op); PgUp/PgDn while focused OUTSIDE any list is a true
no-op (state and render both untouched); an edit made in the last window
plus a new 9th entry both survived PageUp back through every earlier
window AND a full Tab-away collapse + Tab-back re-expand round trip —
confirming the splice-based merge actually prevents the data loss the
naive "harvest visible rows, replace the array" approach would have
caused. `phone` (1 entry, under the cap) rendered identically to before
throughout — no windowing engaged, no indicator row, confirming the
below-cap path is unchanged.

**Testing-harness gotcha, cost one lost shell**: a multi-line `kill $pid`
cleanup loop run in the SAME Bash invocation as the `./bin/Protocol-7
user-edit start ...` command that followed it killed the invoking shell
itself — `ps aux | grep '[u]ser-edit'` (the self-exclusion trick from
[[reference-user-edit-headless-driving]]) only protects against matching
the grep process's own line; it does NOT protect against matching some
OTHER process on the machine whose full command line happens to contain
the literal string "user-edit" — and the harness's own `bash -c
"<the whole multi-line script>"` invocation, still running the kill loop
partway through when `ps aux` is read, IS such a process once the script
text further down contains that substring. Exit code 144, no output at
all. **Fix: run a `ps aux | grep` cleanup/kill step as its own, separate
tool call — never in the same shell invocation as (before or after) a
command whose literal text contains the pattern being matched.**

**Outstanding, not a design gap — needs the user's key passphrase**:
these module files carry AMOS7 signature footers; `sourcecode.console.sign
<path>` (`./bin/Protocol-7 sourcecode sign <path>`, or `sourcecode.console.
update-signatures` for a batch) is the real per-file resigning tool
(distinct from `work.console.fix-signatures`, which re-signs GIT COMMITS,
not file content) — but it prompts interactively for the `proto-7.
sourcecode` key decryption password, which is not something to attempt
non-interactively. New files were left with an obvious `PLACEHOLDER...`
signature block rather than a fabricated one. Whoever holds that
passphrase should run the sign command over every file this session
touched before treating the change as commit-ready.

**Same session, right after — Left/Right also page the scrollinfo row.**
Per user: once the position row is focusable, Left/Right should mean what
PageUp/PageDown already do rather than nothing. Added to
`user-edit.handler.stdin_key` as a `$focus_def->{'list_info'}` check
matched directly on `$key` (same TRAP-3 reason the add-a-field row's own
Left/Right claim exists a few lines above it: `process_key` already claims
`\e[D`/`\e[C` for cursor movement, so they never arrive as `passthrough`).
Verified live on a second throwaway record (`p7-fieldtest2`, 5 entries,
cap 3): Right on the position row pages forward and clamps at the last
window exactly like PageDown; Left pages back; Left/Right on an ORDINARY
row still just moves the text cursor (confirmed no regression — the
window stayed put while editing). Same file already in the
not-yet-signed batch above, no new file added.

**Immediately after — focus was bouncing off the position row.** User:
Left/Right from `:..1-3.of.8..:` should STAY on that row across the page,
not jump down to the window's first data row. Root cause:
`editor.control.list.expand` (what `.scroll` re-drives internally) always
lands `active_field` on the new window's first row — right for PgUp/PgDn,
which start from a data row anyway, wrong for a gesture that started ON
the position row itself. Fixed with a second, optional
`$keep_on_indicator` param on `user-edit.form.scroll_list`: when true, it
re-targets `active_field` to `<field>_scrollinfo` by NAME after the
re-expand (same by-name re-targeting pattern `.expand`'s own first-row
logic and `.collapse`'s "park the cursor back on the field" both already
use) — silently falls back to whatever `.expand` picked if the field
dropped under the cap during this same scroll and the row no longer
exists. `stdin_key`'s Left/Right-on-`list_info` branch now calls
`scroll_list($direction, TRUE)`; the PageUp/PageDown action branches stay
at the one-arg call, unchanged. Verified live (third throwaway record,
`p7-fieldtest3`): Right/Left from the position row now stay parked on it
across every page; PageDown from the SAME row still lands on the first
data row as before, confirming the two gestures diverge only where
intended.

**Next session, same thread — two ordering features, on opposite sides of
the record.** Per user: field ROW display order via
`<[base.reverse-sort]>`, and `contact` entry order via `<[base.sort]>`
normalised on write. Neither is a plain alphabetical sort — both are the
codebase's own `base.sort`/`base.reverse-sort` idiom [ `base.each_sort`,
`base.cmd.commands`, `base.diff.hash_keys`, etc. already use it
pervasively for hash-key/list iteration order ]: length ascending
(`base.sort`) or descending (`base.reverse-sort`), tiebreak
alphabetical-descending in both. Confirmed by hand-deriving the expected
order first, then matching it exactly against a live capture — worth
doing for any future call site, since the length-primary/alpha-secondary
shape is easy to mis-predict as a plain alpha sort otherwise.

- **Display order** (`user-edit.form.schema_from_record`): `sort keys
  %{$fields}` → `<[base.reverse-sort]>->($fields)` — passed the HASHREF
  directly, not `keys %{...}`, matching `base.each_sort`/
  `base.diff.hash_keys`'s call shape (`base.context.list` expands a
  hashref to its keys internally). Verified: an 8-field test record
  rendered `full_user_name, full_real_name, timezone, location, contact,
  shell, phone, note` — exactly the hand-derived length-desc/alpha-desc
  order, not the old plain-alphabetical one.
- **Write-time contact normalisation** (`users.record.build`, NOT
  `editor.control.list.collapse` or anywhere in `editor.control.*`): per
  user, scoped to `contact` specifically, not a generic list-field
  behaviour — `phone` etc. are untouched. Placed in the AUTHORITY's
  `record.build` rather than the form/editor layer because it is the one
  place every write path converges (`user-edit`'s submit, a direct
  `users.value-set`, an installer), so every reader downstream
  (`value-get`/`value-all`, a future export) sees the normalised order
  for free without re-sorting itself — "normalizing on writing, export
  included" is satisfied by having exactly one write-time choke point
  rather than sorting at each read/display site. Builds a shallow `%fields`
  copy rather than mutating the caller's arrayref in place. Verified: an
  8-entry contact list submitted in arbitrary order came back sorted
  length-ascending/alpha-descending-tiebreak, byte-matching a hand-derived
  prediction.
- **Gotcha re-hit**: `users.*` code changes need `v7.restart users` before
  they take effect — the FIRST post-edit `value-set` in this session still
  wrote unsorted contact, silently, because the zenka was still running
  the pre-edit code (already documented in
  [[reference-editor-add-field-cycler]]'s testing-gotcha section, worth
  the reminder since it bit again here on a totally different feature).

**Immediately after — write-time-only left `show` disagreeing with a fresh
record.** User's real `taeki` record predates the fix (last written before
it landed), so `users.value-get`/`show-form`/the interactive form's initial
load all still showed the OLD on-disk order — correctly, per the
write-time-only design, but not what the user wanted: they'd rather `show`
never depend on write history at all. Added the identical `<[base.sort]>`
normalisation to `users.cmd.value-get` — the one place BOTH `show-form` and
the interactive form's initial/every fetch already converge through (`user-
edit.console.show-form` → `N.users.value-get` over the cube link →
`user-edit.handler.value_get_reply`), so this single edit covers every
'show' path at once. Read-only by design: builds a shallow
`{ %record, fields => {%fields} }` copy before reordering, specifically so
a plain GET can never have the side effect of rewriting stored state —
verified live by md5summing `taeki`'s `details.yaml` before and after a
`value-get` call and confirming it is byte-identical, while the REPLY now
shows contact sorted. `users.record.validate` was deliberately NOT the
injection point despite structural symmetry with `record.build` — its own
contract is shape-checking only, no data transforms, and giving it one
would be a scope violation for a function named "validate".

**Immediately after — extended to `phone` too.** User's reasoning
generalises cleanly: neither `contact` nor `phone` has a manual reorder
control anywhere in the editor, so insertion order is arbitrary and reads
as unintentional mess. Both `users.record.build` and `users.cmd.value-get`
now loop `qw| contact phone |` instead of naming `contact` alone (write
side: `foreach my $sorted_field (...) { ... if ref eq ARRAY }`; read side:
`grep`s down to which of the two are actually array-shaped on this record,
then sorts each found). Verified live (`p7-fieldtest5`, phone
`["+49176 5839 2477","555-9999","+1 415 555 0100","0170-1234"]`): came
back `555-9999, 0170-1234, +1 415 555 0100, +49176 5839 2477` — lengths
8/9/15/16, exactly `base.sort`'s length-ascending rule. Deliberately NOT
generalised further to "every array-valued field automatically" — the
vocabulary only HAS these two array-shaped fields today, so the two forms
are behaviourally identical right now, and hardcoding the two names
matches what was actually asked rather than committing to a policy for
fields that don't exist yet.

**Immediately after — re-sort on ENTRY too, and a real cross-zenka bug
caught live.** User: contact/phone should also re-sort the moment focus
enters the list, mid-session, not only at write/read time — so a
just-typed entry lands in its canonical position immediately rather than
waiting for a submit. Design: `editor.control.list.expand` gained a
per-field-def `sort_on_focus` flag it honours generically [ sorts
`@entries` via `base.sort` before windowing, so the rule applies across
the WHOLE array, not per-window — verified with a 4-then-5-entry windowed
case, a newly-typed 6-char entry added in the LAST window correctly
jumped all the way to the FRONT of the first window on re-entry ] — the
module stays unaware of WHICH fields want it, same as `validator`/`noun`.
`user-edit.form.schema_from_record` sets the flag, since it's the layer
already naming `contact`/`phone` for display order.

First attempt factored the name list into a new `users.record.sorted_
fields` module and called it from THREE places, including `schema_from_
record` — **broke immediately, live**: `protocol-7 subroutine users.
record.sorted_fields not defined`. Real architecture lesson, not a typo:
`user-edit` and `users` are SEPARATE ZENKA PROCESSES, each compiling its
own `%code` from its own `modules.load` — a module living in one is
simply not callable from the other via `<[module.name]>`, no matter how
pure/stateless it is. `user-edit` only ever reaches `users` over the cube
link (`N.users.value-get`, see `user-edit.console.show-form`), and its
`modules.load` is deliberately narrow (see that zenka's own start-file
header — no trailing `*`, no reason to be reachable beyond `char-add`).
Loading the whole `users` family into `user-edit` just to reach one
two-item list would be a far bigger coupling than the fix: kept `users.
record.sorted_fields` for the two same-process call sites (`users.record.
build`, `users.cmd.value-get` — both genuinely run inside `users`, so the
shared module is correct THERE), and duplicated the literal `qw| contact
phone |` in `schema_from_record` with a comment explaining why it's a
duplicate on purpose rather than an oversight. **General rule for this
codebase**: a "single source of truth" module only actually is one within
ONE zenka's `modules.load` — sharing a constant/helper ACROSS zenki needs
either a real network round trip or accepting hand-kept-in-sync
duplication, there is no third option.

Verified live end-to-end (`p7-fieldtest6`/`7`, both cleaned up after):
adding a new short entry to an unwindowed 2-entry contact list, tabbing
away then back, showed it re-sorted to the front with zero submit; same
for a windowed 4→5-entry case, confirming the sort runs on the full
pre-windowing array.

**Next session — a real regression, a timing refinement, and a new
per-entry Del, all in one thread.**

1. **REGRESSION, caught by user, root-caused and fixed**: "Del on an empty
   optional field row" (see [[reference-editor-add-field-cycler]]'s CLOSED
   section) stopped working once a list field was WINDOWED. Root cause:
   `user-edit.form.removable_field`'s "is every row of this list empty"
   loop iterates every `list_row_of` row including the NEW `list_info`
   [ scrollinfo ] row — its display text (`:..N-M.of.T..:`) is never
   empty, so a windowed list could never be judged empty and Del silently
   did nothing, "until it collapses [ tabbing away ] and that cleans up
   the empty ones anyway" [ the entries, not the FIELD itself — collapse's
   `grep{length}` was never the same thing as removing the field from the
   form ]. Fixed with one `next if $row_def->{'list_info'};` line, the
   same skip `.collapse`/`.scroll` already had — a THIRD call site I
   missed when introducing the marker. Verified live with a 4-entry
   windowed phone list emptied out via navigation: Del now removes the
   field once truly empty, exactly as before windowing existed.

2. **Timing refinement, per user**: sort-on-focus [ previous session ]
   only resorted on ENTERING the whole list from outside. User wanted it
   to also fire "the moment you exit focus from the [ row ] you entered
   the new value from" — i.e. on ordinary Up/Down/Tab movement BETWEEN
   rows within an already-open list, not only on the list-wide
   enter/leave transition. Real design trap avoided: a naive
   "resort + `editor.control.list.expand`'s own land-on-row-0 default"
   would make it IMPOSSIBLE to navigate past row 0 whenever anything
   needed reordering — every Down press would immediately bounce back.
   Fixed by extending `editor.control.list.scroll` to accept `$direction
   == 0` [ "resort in place, same window, no page" — required relaxing
   TWO guards : `not defined $direction` instead of `not $direction` so 0
   passes through, and the window_cap short-circuit now only applies when
   `$direction` is truthy, since a 2-entry list has nothing to PAGE but
   still has something to SORT ], and by making the caller
   (`user-edit.form.sync_list_mode`'s `$still_inside` branch) PRESERVE the
   destination `active_field` INDEX after the resort rather than accepting
   `.expand`'s row-0 default — sorting can change which entry occupies
   which row, but the cursor still needs to visibly move the direction
   just pressed. `editor.control.list.collapse` got the same
   `sort_on_focus`-gated sort too, so leaving the list ENTIRELY also
   normalises immediately rather than waiting for a future re-entry.

3. **New feature, same thread, per user**: "Del on empty multi-fields" —
   clarified via AskUserQuestion into: an INTERIOR row of a multi-entry
   list that is empty while SIBLING rows still hold content should be
   removable with Del immediately, not only once the whole field is
   empty [ the existing `removable_field`/`remove_field` pair only ever
   handled the whole-field case ] and not only after navigating away
   [ which already dropped it via the ordinary harvest-and-merge, per
   item 2 above — the gap was specifically Del pressed WITHOUT first
   moving off the row ]. Key realisation that avoided a whole new
   removal primitive: an empty row's live buffer already fails
   `grep{length}` in the SAME harvest-and-merge `.scroll`/`.collapse`
   already do — "resort in place" and "remove this one empty row" are
   THE SAME OPERATION from the merge's point of view. So Del on an empty
   interior row just triggers a `$direction 0` resort immediately,
   instead of waiting for a navigation event to trigger the same thing.
   Factored the position-preserving resort+state-write+frame-rebuild
   sequence [ shared by BOTH item 2's trigger and this one ] into a new
   `user-edit.form.resort_list` glue module, called two different ways :
   `sync_list_mode` gates its own call on `sort_on_focus` [ this resort
   trigger is genuinely about sorting, contact/phone-specific ], while
   `stdin_key`'s new Delete-on-empty-interior-row check does NOT gate on
   it [ removing an empty slot is general list hygiene, not a sorting
   behaviour, and should work for any list field ]. Verified live
   (`p7-fieldtest9`, phone `["a@x","X","b@x"]`): cleared the MIDDLE row
   without navigating away, pressed Delete — the row vanished
   immediately, the entry below shifted up into its place, cursor stayed
   at the same visual row ; confirmed Delete-as-character-delete on a
   non-empty row is unaffected ; confirmed the field still collapses
   correctly afterward.

**A real `and`/`or`-precedence bug, caught by a live Perl warning before
it shipped** (`Useless use of not in void context`, item 3's implementation):
`my $x = A and B and C` assigns only `A` to `$x` — `and` binds LOWER than
`=`, so `B`/`C` execute as discarded void-context statements rather than
contributing to the assignment. Same trap with `not` : it ALSO binds
lower than `&&`, so mixing `A && not B` is not the tight grouping it
looks like either. Fixed by rewriting the whole `$remove_empty_row`
boolean-and-chain with `&&`/`!` throughout rather than `and`/`not` — the
existing `$still_inside` line elsewhere in this same codebase already
uses `&&` for exactly this reason, worth pattern-matching against BEFORE
writing a new multi-condition assignment, not after a warning catches it.
Re-grepped every file touched this session for the same shape
(`= .* and/or`) to confirm this was the only instance — worth doing as a
matter of course after finding one, since it is very unlikely to be an
isolated slip in a single sitting.

**Next session (2026-08-13) — three more features landed: plugin detail
tabs, a zero-field bootstrap path, and multiline note editing.** Design
docs for the first two are `data/yaml/coding-tasks/user-edit-plugin-
detail-tabs.yaml` and the bootstrap work is folded into `users.record.
default_fields`'s own header comment (no separate doc — it's a small,
self-contained change); the third has its own doc, `data/yaml/coding-
tasks/user-edit-multiline-note.yaml`. Committed as `7592bdbc0`/`7d66dfa6d`
(plugin tabs phase_1/phase_2), `2b504e4ef` (hotfix), `a8b99c923`
(bootstrap), `989e5ebb3` (multiline note) — all pushed.

1. **Plugin detail tabs**: a `plugin.user-edit.<name>` module family lets
   a zenka-external plugin PIN itself to a specific record key and take
   over that field's rendering/key-handling entirely (`display_override`
   — a new generic coderef hook on `editor.control.get_display_value`,
   zenka-agnostic). Discovery is ONE parent `plugin.user-edit.registry.
   post_init`, not N per-plugin self-registrations (per user preference).
   TWO real bugs only live testing caught, both fixed before shipping —
   see the design doc's own Status note for the full account : (a) Tab
   dual-bound to "enter a pinned field" made a visited field permanently
   un-Tab-able-past ever again — fixed by dropping Tab from the trigger
   entirely and making Right a TWO-STAGE entry [ first press just moves
   the cursor normally, a SECOND press with the cursor already >0 enters
   ] ; (b) `editor.buffer.memory.insert/delete` enforce `readonly`
   THEMSELVES, independently of `editor.control.process_key`'s own guard
   — toggling it off on entry had to happen in three separate places, not
   the one `process_key` bypass first assumed.
   **CRITICAL LIVE BUG, immediately after shipping**: the kept-around
   throwaway test plugin (`plugin.user-edit.example`, deliberately left
   wired into the real `configuration/zenki/user-edit/start` per an
   earlier "keep it for testing" decision) had `pinned_keys => ['location']`
   — a REAL, universally-present field, not a placeholder name. This
   silently made `location` readonly/plugin-mode/test-edited on every
   real user's own record the moment the code shipped — user reported it
   within the same session as "location can no longer be edited, allows
   only 3 characters in with the arrow keys". Fixed by repinning to
   `example_test_field` (verified nowhere in `users.record.*_fields`).
   **Lesson for next time a throwaway test fixture is kept wired into a
   real zenka's live config**: its test data must be checked against the
   REAL vocabulary it could collide with, not just assumed safe because
   it "was just for testing" — the collision was invisible in the diff
   review and only surfaced as a live production bug.

2. **Zero-field bootstrap path**: `users.record.default_fields` now
   returns `{}` — `contact` and `location` moved to `users.record.
   optional_fields` alongside the rest, so a fresh record has NOTHING
   editable until the user adds something (per user : "the minimal is the
   username and the list of options to include"). This made a genuinely
   empty record reachable for the first time, which both `user-edit.form.
   schema_from_record` (`return undef` on zero field defs) and `editor.
   control.create` (refuses an empty `fields` array) independently
   refused. Fix: `user-edit.handler.value_get_reply` gained an
   interactive-only branch that, on the zero-fields case, puts the
   terminal in raw mode and registers the watchers FIRST [ these don't
   depend on any state existing ], then requests the field-options
   vocabulary with a NEW reply handler (`user-edit.handler.field_options_
   bootstrap_reply`) instead of the normal one — that handler founds the
   FIRST schema as just the add-a-field cycler row, hand-mirroring `add_
   field_row`'s field-def shape rather than sharing code with it [ that
   module's contract is specifically "append to an existing state", which
   doesn't fit founding one from nothing ]. Vocabulary-wire parsing was
   extracted into a new shared `user-edit.form.parse_field_options` so
   both reply handlers use one implementation. One-shot [ `show-form` ]
   mode was deliberately NOT given the same bootstrap treatment — it has
   no round trip to chain a vocabulary fetch onto, still aborts on a
   truly empty record. Verified live end-to-end on a throwaway
   `create-default`'d record : opened without aborting, added `contact`
   and `location` through the cycler, submitted, reloaded — both
   persisted correctly, and a normal populated record was completely
   unaffected by any of this.

3. **Multiline note editing** — the full account, including the auto-
   scroll-to-cursor / manual-PgUp-PgDn conflict and the Up/Down-within-
   field gap found only by testing against a REAL populated record, lives
   in `data/yaml/coding-tasks/user-edit-multiline-note.yaml`'s own Status
   note — worth reading directly rather than duplicating here. The one
   lesson worth calling out on its own: **a throwaway record built by
   hand for a feature test will not surface every UX gap a real, already-
   lived-in record does** — the reserved blank rows below a short note
   only read as "obviously not navigable" once a real person tried to use
   them on their own actual note field ; every synthetic throwaway test
   run during development had either an empty note or one that
   conveniently filled every reserved row, so the gap never came up until
   the user hit it live. Worth deliberately testing a genuinely
   mixed/partial case, not just the two clean extremes, next time a
   capped/windowed field ships.

**Headless-testing gotcha, same session**: `list subnames` can show BOTH
the user's own live TTY session and a `-no-tty` throwaway side by side,
and casually picking "whichever looks newest" is not reliable when both
were touched recently — cross-check the SID against `list sessions`'
age column before routing `char-add` to it. Got this wrong once this
session and routed a `char-add` at the user's own live pts/4 session by
mistake ; `user-edit.cmd.char-add`'s own `<user-edit.mode.no_tty_debug>`
guard refused it outright [ "form is not running in no-tty mode" ] rather
than silently injecting into a real interactive session — a real safety
net that did its job, not just a nice-to-have gate. See [[reference-user-
edit-headless-driving]] for the fuller driving notes this refines.

## multiline width-explosion fix — non-destructive viewport (2026-08-13, `434c289b7`)

A REAL latent bug in the shipped multiline feature, found while designing
the address-cluster plugin's own tab view (not hypothetical) : note/address
rows placed each windowed line's FULL raw text into its frame slot with no
length cap at all, and `user-edit.form.build_frame`'s own width-floor scan
gives a multiline field's row ZERO contribution — so one very long line
already blew the card wide open, unbounded, in already-shipped code.

Two fixes were on the table for the plugin's own single-row tab view [ hard-
wrap content into real `\n` vs a non-mutating slice viewport ] — user chose
the viewport, specifically because hard-wrap is DESTRUCTIVE [ inserted `\n`
indistinguishable from typed, re-wrapping at a different width later
silently rewrites content and can ratchet ] where a slice viewport reads
the SAME unmodified text and just bounds what one render shows. Scoped
GENERAL per user, not plugin-only — fixes the existing note/address bug
too, one helper, not a plugin-private reimplementation.

**New**: `editor.control.multiline.viewport_slice($line_text, $width,
$cursor_col)` → `($slice, $cursor_display_col)` [ two-value return, mirrors
`cursor_line`'s own convention ] — cursor-following window with `<`/`>`
overflow markers, pure text function, never touches stored content.

**Width source**: `user-edit.form.build_frame`'s own `min_width` [ already
computed from every OTHER field/label in the form — multiline content
never contributes to it, which is exactly what keeps this non-circular ],
now also exposed as `$descriptor->{'label_width'}` for `render_form` to
derive a per-row body budget from (`min_width - label_width - 10`, floored
at 20). Cross-layer read, flagged in-code: `render_form` is generic
`editor.ui.*`, `label_width` is a key only `user-edit.form.build_frame`
sets, not part of the generic frame contract — `// 0` fallback means any
other caller just gets a wider budget rather than breaking.

**Verified, measured not inferred** (advisor pushed back on an early
inference-only claim) : `git stash`'d the two changed core modules, drove
the identical long address line through a throwaway record on unpatched
code (178 chars), restored the fix, repeated on a fresh throwaway (108
chars) — same content, real A/B measurement. Separately swept
`viewport_slice`'s cursor math exhaustively in a standalone harness [ every
width 3..40 × every cursor position across a 150-char line, 5,738 cases ]
to confirm the cursor's display position never lands on an overflow marker
— zero failures once the legitimate "cursor exactly at end-of-text lands
one-past-the-last-index" case [ same convention the pre-existing non-
viewport cursor overlay already uses ] was excluded from the check.

**Real bug caught on the user's own live restart, not in review**: `my
$has_cursor = defined $cursor_col and $cursor_col >= 0;` — Perl's `and`
binds looser than `=`, so this parsed as `(my $has_cursor = defined
$cursor_col) and (...)`, silently dropping the `>= 0` guard and throwing
"Useless use of numeric ge in void context". Benign in practice [ the real
call site never passes a negative cursor_col ] but a genuine instance of
the project's own documented perl and/or-precedence trap — fixed with
explicit parens: `( defined $cursor_col and $cursor_col >= 0 )`. My own
exhaustive sweep test had copied the same unparenthesized line and did not
catch it, because the sweep never exercised a negative cursor_col — a
reminder that a passing test only proves what it actually checks.

See `data/yaml/coding-tasks/user-edit-address-cluster-plugin.yaml`'s
`MULTILINE VIEWPORT` section for the full design trace.

## address-cluster plugin — built and live-verified (2026-08-13, `63e0db701` + follow-up)

`plugin.user-edit.address-cluster.*` (8 files: init_code, tab_info pinning
'address', gen_ref, parse_blob, serialize_blob, write_buffer, render,
handler.key) reuses the viewport-slice helper above for its own single-row
tab view, as planned. Multiple labelled addresses per user, referenced by a
short stable checksum ref, one marked primary, edited through the plugin
detail-tab mechanism. Full design trace and the final implementation
record (keybinding table, verified test matrix, every bug found) are both
in `user-edit-address-cluster-plugin.yaml` — not duplicated here.

**Three real bugs found and fixed at the source, not worked around,
affecting the shipped plugin-tabs feature generally, not just this
plugin**: `user-edit.form.add_field` never wired plugin-pinned fields when
added fresh via the cycler (same drift-bug class as multiline/
sort_on_focus, twice already this session — this one needed no
hand-duplicated list, since the fix reads the plugin registry directly);
`user-edit.handler.stdin_key`'s two-stage Right-entry trigger required the
cursor to move past position 0, impossible on a field starting EMPTY —
this plugin's own primary use case (a user's first address) could never
be entered at all until fixed; `editor.ui.ascii_frame.render_form`'s
generic cursor overlay fired on any plugin's restructured display string
using the RAW BUFFER's meaningless offset — 'plugin' added to the same
exclusion list list/menu_row/add_field/list_info already use.

**One bug caught by advisor before it shipped**: an early handler.key
draft let Backspace's write-through be conditional on a guard, with the
fallthrough landing in the printable-character check — which does not
exclude `"\x7f"` (ord 127, satisfies the same `>= 32` test as real
printable bytes). Backspace at cursor 0 would have inserted a literal DEL
byte. Fixed by having Enter/Backspace/Delete-forward each return
unconditionally once matched, matching plugin.user-edit.example.
handler.key's own long-standing pattern.

**A live quirk of the ALREADY-SHIPPED trigger, not introduced here**,
cost real testing time and is worth remembering: once a plugin-pinned
field has been entered and left at least once, its raw buffer cursor is
never 0 again, so the two-stage Right-entry protection collapses to
single-stage on every later visit — a `Right` intended to just move past
the field re-enters it instead. Use Tab to leave a field's ROW after a
Left-exit, never Right.

**add-a-field horizontal-scroll cycler — built and live-verified, proactive
fix, no live bug preceded it.** The add-a-field row's own width reservation
(`user-edit.form.build_frame`) used to render the FULL addable vocabulary
through `editor.control.cycler.render` just to measure it — unbounded as
the vocabulary grows, the same width-explosion class already fixed twice
for the multiline note/address fields, fixed here before it ever bit
live. New `editor.control.cycler.window_width` (fixed constant, 40) is
read directly by BOTH `build_frame`'s reservation and
`editor.ui.ascii_frame.render_form`'s render budget, so the two cannot
disagree — deliberately NOT derived from `min_width` the way the
multiline fix derives its own budget, because the add-a-field row is one
of `min_width`'s own drivers (`build_frame` pushes a synthetic row into
`@current_rows` even when the schema doesn't carry it yet, specifically
because it is normally the form's widest row) — deriving its render width
from `min_width` while `min_width` still partly depends on it would be
circular. New `editor.control.cycler.render_windowed` packs whole choice
cells greedily from a caller-decided offset, always including the offset
cell first (even oversized) so the `+choice+` marker never vanishes. The
scroll-offset SETTLE logic lives inline in `render_form` (mirroring
`multiline_offset`'s own live-state-on-the-field-def pattern), modeled on
`nshell.render.viewport`'s lookahead-margin scrolling rather than
`viewport_slice`'s per-render recentering — Left/Right move one discrete
choice at a time, so holding the window steady until an edge is reached
reads better than reshuffling every neighbour on every keystroke.
Two settle rules, both traced through the wrap-around case live: scroll
LEFT pins the new current at the window's left edge directly
(`offset = current`); scroll RIGHT does a single backward pack FROM
current (not an `offset++` loop — an earlier draft's mistake, which
converges to current pinned at the wrong edge and re-packs the whole
vocabulary on every step) landing current at the right edge. Caught by
advisor before any code was written, not live: the circular width-
derivation risk above, and the backward-pack-not-increment correction.

Live-tested against a throwaway `cyclertest` record: correct `<`/`>`
markers through a full forward cycle, both wrap directions (last→first
and first→last) landing the wrapped choice at the correct edge, adding a
field from mid-scroll adds the right one and the fresh row resets to
offset 0, and a small remaining vocabulary (≤3 choices) renders with no
markers at all — identical in shape to `cycler.render`'s own unbounded
output. One live finding worth remembering: the DEFAULT vocabulary is 9
fields, which already doesn't fit one 40-column window unscrolled — so a
brand-new record now shows the scrolled/marked view immediately, not only
once the vocabulary grows further. Treated as the fix correctly engaging
right away (matches the user's own earlier complaint about this row
carrying dead width), not a regression, but worth knowing it's a visible
day-one behavior change, not purely future-proofing.

#,,,,,..,,...,...,.,.,,..,..,,,.,,..,,,.,,,,,,..,,...,..,,..,,...,,.,,..,,,.,,
#X6UBNDFBZ66SFGSBG7AJ7PSSTSJOFZSJ6N54SD7O6GEG2ZKCYUWQXMBNJT4RRP7AW3EEFOA5J2TGG
#\\\|5VMXZ4W26ZAICY224DDNKSFY6HWQT6FQM3UJZCDTM5DNBF7ZU5E \ / AMOS7 \ YOURUM ::
#\[7]L7UQHLZBJ4OSXEKKXMKHADRR6JXDJ2PAZPRKHWAGOECCVOKESWCY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
