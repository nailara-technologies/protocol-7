# user-edit: key-actions tab -- create a new key (first interactive key action)

## archive: DONE ✓ — 2026-08-16
## commit: b056a04c4 — user-edit: event-loop-safe in-frame prompt primitive, fix loader deferred-compile bugs
## notes: landed alongside editor-inframe-prompt-primitive.md in the same commit; submit_name/submit_passphrase live-verified via script -qec (real pty); became the copy-this-shape template rename and delete both followed

**Read first:**
- `data/ai-mem/kimi/coding-style.md` and `data/ai-mem/kimi/MEMORY.md` -- P7
  module conventions, common mistakes to avoid.
- `data/tasks/completed/user-edit-key-details-tab.md` and `data/tasks/
  completed/user-edit-user-keys-field.md` -- the two prior key-related tabs
  this extends past. Both are DISPLAY ONLY; this task is the first one that
  actually DOES something.
- `data/ai-mem/claude/topic-user-edit-console-zenka-status.md` -- read the
  "control-flow problem and its solution" section describing `user-edit.
  offer_create` (search for that heading) and the multiline/plugin sections
  describing `plugin.user-edit.address-cluster`. Both are load-bearing
  precedent for this task, not background colour.
- `data/ai-mem/claude/project-keys-zenka-integration-direction.md` -- read
  the 2026-08-15 entries at the bottom (the scoping note and the "signature
  trees" note). Identity-switching is explicitly NOT this task; it is
  deferred to that not-yet-designed mechanism.

## Goal

Add a self-record-only "key actions" tab to `user-edit`'s interactive form
that lets the invoking Unix user create a NEW named C25519 key (real,
passphrase-encrypted, via `keys.console.create`'s own existing password
prompt) without leaving the form. **Create only** -- no rename, no remove,
no identity-switching, no generic "run any keys.console.* command" surface.
Those are explicitly future tasks, not this one.

This is harder than it looks because it is the first time anything in
`user-edit` needs to run a REAL BLOCKING TERMINAL PROMPT in the middle of an
already-running interactive session (not just once at startup, which is the
only case that exists today). Read the whole task before writing code --
the two sections below ("risk" and "control flow") are the actual point of
this task, the plugin/tab scaffolding around them is comparatively
mechanical.

## THE #1 RISK -- read this before calling anything in `keys.console.*`

`modules/base.exit`'s last line is `CORE::exit($exit_code)`. It ends the
WHOLE PROCESS, not just the current command or console call.

`modules/keys.console.create` calls `<[base.exit]>->(...)` on **every**
guard failure: empty name, invalid keyname
(`crypt.C25519.validate_keyname`), key already exists
(`crypt.C25519.key_exists`), missing `Crypt::Mode::CBC`, an empty or
too-short password, key-generation failure, write failure. Only the true
success path avoids it (`return TRUE` at the very end).

`keys` is normally a disposable standalone console zenka, where dying like
this is harmless -- the whole point of a console command. `user-edit` loads
`keys`' modules DIRECTLY into its own long-lived, networked process (see
commit `f9c51a636`). **Calling `keys.console.create` from `user-edit`
without pre-checking every one of those guard conditions yourself first
will kill the entire user-edit zenka** on something as ordinary as a user
typing a key name that already exists.

**Required, before ever calling `<[keys.console.create]>->(...)`:**
verify independently, in your own code, all of:
- a non-empty name was actually entered
- `<[crypt.C25519.validate_keyname]>->($name)` is true
- `<[crypt.C25519.key_exists]>->($name)` is FALSE
- `defined &Crypt::Mode::CBC::new` (mirror `keys.console.create`'s own
  check exactly)

Only call `keys.console.create` once none of the above can fire inside it.
The remaining internal guard (password too short/empty) is harder to
pre-empt since the password is read INSIDE `keys.console.create` itself via
`AMOS7::TERM::read_password_repeated` -- if you cannot find a clean way to
avoid that one too, say so explicitly in your own status note rather than
silently shipping a zenka that can still die on it; do not treat "the
common guards are covered" as "the risk is handled."

## Design part 1 -- the excursion control flow (the hard part)

Two existing pieces of precedent, neither of which alone covers what this
task needs:

1. **`modules/user-edit.offer_create`** and **`modules/user-edit.handler.
   value_get_reply`** -- read both in full. This is the only existing
   "leave the event loop, run something blocking on the terminal, come
   back" shape in this codebase. It works because `Event::unloop()`
   unwinds to whichever `<[base.zenka.loop]>;` call is currently active,
   and the caller of THAT loop call is what catches the return and decides
   what to do next (checks a pending-flag, does its blocking work,
   re-enters `<[base.zenka.loop]>;` itself). Re-entry is confirmed
   supported (`Event.pm` resets `$TopResult` specifically to allow it;
   `base.zenka.loop`'s init-done guard is already satisfied on a second
   call).
2. **`modules/user-edit.term_init`** and **`modules/user-edit.
   term_restore`** -- toggle the terminal between raw/non-blocking (form
   input) and normal (blocking reads) mode. `term_init` is already safe to
   call more than once (no-ops if already raw, via its `<user-edit.term.
   orig_termios>` guard). `term_restore` always restores fully and clears
   `O_NONBLOCK`.

**The gap you have to close**: `modules/user-edit.console.start`'s own
`<[base.zenka.loop]>;` call today only expects ONE kind of unloop-and-
resume (the bootstrap create-offer) and falls straight through to `return
<[user-edit.offer_create]>->(...)` right after it. A mid-session key-create
trigger -- fired from deep inside `user-edit.handler.stdin_key`, through
this task's new plugin's `handler.key`, itself called from inside the
STDIN io-watcher's callback -- needs `Event::unloop()` too. If it just
falls through the SAME way, `offer_create` sees its own pending-flag unset,
returns TRUE immediately, and `console.start` returns -- **silently ending
the whole interactive session** instead of resuming it. Confirm this for
yourself by reading `console.start` end to end before writing anything.

**There are TWO places an unloop can resume, not one.** If this session
already went through the create-admin bootstrap earlier, `console.start`'s
ORIGINAL `<[base.zenka.loop]>;` frame already returned once (into
`offer_create`), and `offer_create` made its OWN nested `<[base.zenka.
loop]>;` call -- THAT is the frame actually on the stack for the rest of
the session. A mid-session `Event::unloop()` resumes at WHICHEVER of these
two call sites happens to be active, and which one that is depends on this
session's own history. Handling only `console.start`'s site will work in
manual testing (where you'll likely test against an existing record and
never trigger the bootstrap path) and then silently misbehave for a
freshly-bootstrapped record -- do not let that happen.

**Fix: one shared helper, called after BOTH sites, not two copies of the
same logic.** New module, e.g. `user-edit.check_pending_excursions`, a
`while` loop (not an `if` -- so the action can also fire more than once in
one session):

```perl
while ( <user-edit.pending.key_create> ) {
    <user-edit.pending.key_create> = FALSE;
    <[user-edit.term_restore]>;
    ## prompt for a key name, pre-validate (see the risk section above),
    ## call keys.console.create, record the result for the tab's render
    <[user-edit.term_init]>;
    <[base.zenka.loop]>;    ## re-enter ; may unloop again for another
                             ## excursion, OR for the real end-of-session quit
}
```

Call it in exactly two places, right after the EXISTING `<[base.zenka.
loop]>;` line in each, and BEFORE whatever already follows it:
- `user-edit.console.start`: `<[base.zenka.loop]>;
  <[user-edit.check_pending_excursions]>; return <[user-edit.offer_create]>
  ->( $username, $tags );`
- `user-edit.offer_create`: `<[base.zenka.loop]>;
  <[user-edit.check_pending_excursions]>; return TRUE;`

New pending flag: `<user-edit.pending.key_create>`, set by the plugin's
`handler.key` right before its own `Event::unloop()` call -- mirror
`<user-edit.pending.create>`'s existing shape exactly, same variable
family, same "set flag, unloop, let the resumer check it" contract. Once
the real session-ending unloop fires (`user-edit.form.quit`), the flag is
unset, the `while` exits immediately on the first check, and both call
sites fall through to their existing next line completely unchanged -- this
must NOT alter behaviour for a session that never uses the key-create
action at all. Verify that no-regression case explicitly.

**Do NOT explicitly cancel/re-register the STDIN `event.add_io` watcher
around the excursion.** Leave it registered throughout. Reasoning: the
watcher's callback only fires while `Event::loop()` (i.e. `<[base.zenka.
loop]>`) is actively pumping; between `Event::unloop()` and the next
`<[base.zenka.loop]>;` call, Event is not pumping, Perl is single-threaded,
and the blocking read inside `base.term.ask`/`keys.console.create` is the
only thing touching fd 0 -- no concurrent-reader conflict.
`term_restore`/`term_init` toggle the fd's `O_NONBLOCK` flag and termios
mode, which is what actually governs whether a read blocks and whether
it's raw or canonical; neither touches the watcher's registration, and
nothing about re-entering `zenka.loop` afterward requires re-adding it.
This is the same implicit assumption `offer_create`'s own blocking
`base.term.ask` call already relies on -- just exercised here for the
first time with a watcher that (unlike the bootstrap case, where
`setup_stdin_watcher` hasn't even run yet at that point) was already
active before the excursion started.

**This assumption is REASONED, not directly verified against precedent --
it is the single most important thing to confirm live, before trusting
anything else in this feature.** See the acceptance checks below; the
first one exists specifically to test this.

## Design part 2 -- the plugin/tab itself

New synthesized field `key_actions`, added in `user-edit.form.
schema_from_record` the same way `identity_key` and `user_keys` already
are (self-record-only gate -- `<user-edit.unix_user> eq ( $record->{'name'}
// '' )`, same comparison `user-edit-key-details-tab.md`'s own precedent
established; carries `plugin => 'plugin.user-edit.key-actions'` directly on
its own field_def).

**Difference from `identity_key`**: `identity_key` is deliberately kept OUT
of the plugin registry's `by_key` map so it can never enter plugin/action
mode at all (read `plugin.user-edit.key-details.tab_info`'s own comment on
this -- it explains exactly why). `key_actions` is the opposite -- it MUST
be enterable, so it needs a real `tab_info` with `pinned_keys =>
[qw| key_actions |]`. Confirmed by reading `user-edit.handler.stdin_key`'s
Right-entry trigger block directly (search for `plugin_cursor_before`):
entry requires `defined $focus_def->{'plugin'}` **and**
`exists <user-edit.plugin.registry>{'by_key'}{$focus_def->{'name'}}`. Using
a synthetic field name as a "pinned key" is fine here -- `by_key` is just a
string-to-plugin-name map; it does not care whether the name came from a
real record field (`address-cluster`'s case, a real `address` field) or a
synthesized one (this task's case).

New module family, mirroring `plugin.user-edit.address-cluster.*`'s SHAPE
(read its `.tab_info`, `.render`, and `.handler.key` -- it's the only real
*editable* plugin precedent in this codebase; `key-details`/`example` are
display-only and the wrong model to copy here):

- `plugin.user-edit.key-actions.init_code` -- nothing to initialise, same
  as `plugin.user-edit.key-details.init_code`.
- `plugin.user-edit.key-actions.tab_info` -- `{ qw| label | => q| key
  actions |, qw| pinned_keys | => [qw| key_actions |] }`. Use `q|..|`, NOT
  `qw|..|`, for the multi-word label -- `qw()` splits on whitespace and
  would silently collapse `key actions` into `label => 'key'` plus a stray
  `actions` key (the exact trap `plugin.user-edit.key-details.tab_info`
  already documents).
- `plugin.user-edit.key-actions.render` (the `display_override`, called by
  `<[editor.control.get_display_value]>`) -- shows a short static hint
  normally (e.g. "press enter to create a new key"), and the LAST action's
  outcome after one runs. Keep the last-result state in a small transient
  scalar, e.g. `<user-edit.key_actions.last_result>`, set by the excursion
  code and read here. Do not persist it anywhere -- it is UI feedback, not
  record data.
- `plugin.user-edit.key-actions.handler.key` -- claims exactly ONE trigger
  key for "create." Enter should be free to use here: `<user-edit.form.
  submit_on> = qw| enter |` only governs `editor.control.process_key`'s
  NORMAL dispatch, and `stdin_key`'s own comment states plugin mode routes
  every key DIRECTLY to the plugin's `handler.key`, bypassing
  `process_key` entirely once entered -- **confirm this is actually true
  live before relying on it** (this project distrusts untested claims
  about control flow, including ones written in a task file like this
  one). On the trigger key: set `<user-edit.pending.key_create> = TRUE`,
  call `Event::unloop()`, and return whatever "handled" signal
  `address-cluster.handler.key`'s own contract uses (check its exact
  return-value convention and mirror it exactly, don't guess). Left should
  exit plugin mode without triggering anything, same FALSE-return decline
  convention `plugin.user-edit.key-details.handler.key` already documents
  for "no further left to go."

Use the existing `<[user-edit.message]>` helper for the ok/fail/no-op
result message after an excursion completes (existing colour convention:
ok=amber, fail=TRUE blue, no-op=green meaning "nothing changed", not
success -- read `topic-user-edit-console-zenka-status.md`'s colour section
if the exact call shape isn't obvious from other call sites).

## Explicitly out of scope

- No rename, no remove -- create only. Future tasks, not this one.
- No identity-switching, no touching `identity_key`'s own rendering or
  `crypt.C25519.key_vars`'s base identity in any way.
- No changes to `key-details`/`user_keys` (their fields, rendering, or
  gating) beyond what's unavoidable to add `key_actions` alongside them in
  `schema_from_record`.
- No generic "run any `keys.console.*` command from a form field"
  dispatcher -- this task wires up `create` specifically; a future task
  can generalize once this one's control-flow piece is proven live and
  correct.
- No `-U`/unencrypted shortcut -- use `keys.console.create`'s real
  passphrase prompt, unmodified. (Per user direction: unencrypted keys are
  of limited practical use; blocking briefly for a real passphrase is not
  a problem for this zenka -- it has no v7 heartbeat/restart watchdog.)
- Do not touch `users.record.default_fields`/`optional_fields` -- key data
  is not record data, same reasoning `identity_key`/`user_keys` already
  established.

## Acceptance checks -- run live, via `script -qec` (needs a real pty)

Read `reference-user-edit-headless-driving.md` in `data/ai-mem/claude/`
first. The no-tty/`char-add` driver CANNOT exercise this feature at all --
it never touches the real terminal acquisition/blocking-prompt path, only
the decode/dispatch side. `script -qec` is what finally made the
interactive form testable in an earlier session (see `topic-user-edit-
console-zenka-status.md`'s own note on this) -- use it here too, do not
attempt to fake this with the headless driver.

Use a THROWAWAY record for every destructive/creation check below -- never
`taeki`'s own real record. Clean up with `p7c users.remove <name>`
afterward.

1. **First, before anything else**: start the interactive form on a
   throwaway record, type at least one ordinary character into an ordinary
   field first (so the STDIN watcher has definitely already been exercised
   at least once), THEN navigate into `key_actions` and trigger create.
   Confirm the blocking name-prompt reads input correctly -- no
   double-read, no lost keystroke, no hang -- and that typing in the form
   resumes working identically once the loop re-enters afterward. This is
   the load-bearing, previously-unverified assumption from the design
   section above; if this doesn't hold cleanly, stop and report it rather
   than working around it silently.
2. Trigger create with a name that ALREADY EXISTS as a key (pick one from
   `v7.keys list`). Confirm the zenka process is STILL ALIVE afterward (`ps
   aux | grep user-edit`, as its own separate tool call per this project's
   own testing-harness gotcha -- never combine a `ps`/`kill` check with a
   command whose own text contains "user-edit" in the same shell
   invocation), the form is still responsive, and a clear failure message
   is shown. This is the core risk check -- do not skip it.
3. Trigger create with a genuinely new name. Confirm it succeeds
   (passphrase prompt appears and is answerable), the key is visible
   afterward via `v7.keys list`, and the form remains fully interactive
   afterward -- Tab and typing still work, proving the term_init/re-loop
   resume actually completed cleanly, not just that the create call
   itself returned.
4. Confirm Left exits `key_actions` plugin mode without triggering create.
5. Confirm the record's OTHER fields are byte-identical before and after
   the excursion (read `details.yaml` off disk, or diff a `value-get`
   before/after) -- no stray draft-save, no unrelated field mutation. A
   resumed-loop bug is likely to show up here first if the excursion
   dispatch loop is wrong.
6. If this session ever goes through the create-admin bootstrap path
   BEFORE testing key-create (i.e. open a record for a brand-new admin
   user that doesn't exist yet, answer yes to create it, THEN try
   key-create in that same session) -- confirm key-create still works
   correctly in that case too. This is the specific "which of the two
   call sites is active" scenario the design section above calls out;
   don't skip it just because it's inconvenient to set up.

Report actual command/capture output for each check, not just "passed" --
this project always re-verifies the diff and live behaviour independently
of any self-reported summary.

When done, write a short note to `data/ai-mem/kimi/coding-style.md` or
`data/ai-mem/kimi/MEMORY.md` on whatever the STDIN-watcher-during-blocking-
excursion check (item 1) actually showed, and on which of the two resume
sites you ended up exercising in testing -- both are exactly the kind of
non-obvious, load-bearing findings future work in this area will need.

#,,..,...,,.,,,..,.,,,.,.,.,.,,..,.,.,.,.,..,,..,,...,...,..,,,,,,,,.,...,...,
#CYSHU2MSGSIFU2Q5QAYCJTWYRS62LYKLEVCP4NLC77EZDWV3MT4A5UTVLE5HV3RT6R7R3THQGZO6A
#\\\|3GATJY4KGWWOTB4RSH2MLKJWNK6INNV27LFBN3SD7EOCM6HJAJJ \ / AMOS7 \ YOURUM ::
#\[7]VX5IXU5PM3NWZREJV5NTN43UQM3N6AUOEF6ATDZFXQ4WMQ7BNCCY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
