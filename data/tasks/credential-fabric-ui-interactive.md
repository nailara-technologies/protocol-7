# task: credential fabric ui — interactive selection + actions [ phase 2 + 3 ]

## status update [ 2026-09-06 triage — read this first ]

this task file predates the `credential_fabric` → `cred-mesh` rename and the
`modules/` → `src/`, `configuration/` → `cfg/` moves. paths below that say
`src/credential_fabric.*` or `data/md/design/CRED-MESH-INTEGRATION-AND-UI.md`
are stale — real locations are `src/cred-mesh.*` and
`data/md/design/CREDENTIAL-FABRIC-INTEGRATION-AND-UI.md`. `cred-mesh-ui-
frames.md` and `cred-mesh-wiring.md` are archived as
`data/tasks/completed/credential-fabric-ui-frames.md` and
`credential-fabric-wiring.md` — both landed.

**part 1 (selection state) and part 2 (slot actions) are already
implemented**, closely matching this spec:
- `src/cred-mesh.ui.interactive.{up,down,refresh,select_view,action,input}`
  all exist. `action` implements rotate/revoke/grant/approve/detail exactly
  as described (advisory-grant status line included). `input` completes the
  grant/approve prompts.
- phase-1 render modules already carry the `{ rendered, row_keys }` contract
  and apply `focus_index` highlighting (`\e[7m...\e[27m`) — see
  `src/cred-mesh.ui.render.registry_list` for the pattern.
- `grant-prompt.yaml` / `approve-prompt.yaml` exist under
  `data/yaml/ascii-frames/credential-fabric/`.

**what's actually still missing from part 1+2**: the nshell-side key
bindings. `src/nshell.shell_loop` detects `cred-mesh.ui[.-]show` and sets
`<nshell.state>->{'cred-mesh_ui_active'}` / `'cred-mesh_ui_pending'`, but
nothing in `src/` ever *reads* those flags — grep confirms write-only. So
today the interactive modules only work if a user types full command lines
(`cred-mesh.ui.interactive.down` + Enter); the `j`/`k`/`r`/`x`/`g`/`a`/`?`/
`q` single-key UX this task specifies does not exist yet. See "part 1+2
remaining work" below for the corrected scope and hook point — it is
**not** the small edit the original task text implies.

**phase 3 (both 3a and 3b) is blocked and should not be built yet.** the
fabric-secret encryption migration this phase assumes has not landed:
`src/cred-mesh.key_holder.child` still writes `fabric.secret` with the `U:`
(*un*encrypted) prefix unconditionally, and `key_holder.parent` has none of
the fork-without-phrase / `unlock_required` state machine. 3a's own trigger
condition — "route to `protocol-7-menu.cmd.input-password` **when an
unlock is needed**" — never fires while the secret is never encrypted, so
3a is just as dead as 3b, not an independent small win. per this task's own
"what NOT to do" section, stop here and confirm with the design-doc author
before implementing any of part 3.
(`protocol-7-menu.cmd.input-password` itself does already exist and is a
real, usable dependency once the migration lands.)

## part 1+2 remaining work — nshell-relay attempt tried, reverted [ was
## briefly commit 7af528e8c on `base`, local-only, never pushed, soft-reset
## back out before this note was written — see git reflog if the diff is
## ever needed again ]

**this approach does not work and should not be re-attempted.** what was
built: single keys in `src/nshell.read_from_buffer` (mirroring the
existing `search_mode`/history-mode interception pattern) synthesized full
`cred-mesh.interactive-*` commands and returned them for `nshell.shell_loop`
to relay into cube's routing, with `nshell.handler.command_reply` matching
prompt-frame header text in the reply payload to arm a
`cred-mesh_ui_pending` flag for the grant/approve free-text handoff. it
got as far as `cred-mesh.ui-show` rendering correctly through nshell (that
part is fine — a one-shot render over ordinary cube routing works), but
two things kill the interactive layer built on top of it:

- **race condition, not fixable from nshell's side**: `cred-mesh_ui_pending`
  is armed by an async cube reply arriving on its own timing, while
  `nshell.read_from_buffer` fires independently on STDIN readability. type
  fast enough after `g`/`a` and a character lands in the wrong mode before
  the prompt-armed flag catches up. there is no ordering guarantee between
  those two event sources to fix this with.
- **security model**: routing grant/approve payloads (and eventually
  unlock phrases) as literal cube command arguments means they pass
  through `p7-log`/`terminal-history` and any zenka with routing
  visibility — the opposite of what a credential fabric should do. this
  was flagged live during the attempt, not found by inspection after the
  fact.

nshell and cred-mesh are separate OS processes connected only through
cube's routed command/reply protocol — there is no mechanism by which
per-keystroke state can be safely coordinated across that boundary for a
modal, low-latency UI. this is a structural mismatch, not a bug.

## the correct direction: cred-mesh becomes a console zenka, like user-edit

**how "ui" is actually meant to be interactive in this codebase**:
`user-edit` (`cfg/zenki/user-edit/zenka.v7`, `src/user-edit.term_init`,
`src/user-edit.setup_stdin_watcher`, `src/user-edit.handler.stdin_key`)
owns its own terminal directly. every keystroke, the state it mutates, and
the redraw all live in the same process — no routing, no reply hook, no
cross-process flag coordination. `cred-mesh` currently cannot do this: its
`zenka.v7` drops privileges to a service account
(`[root.drop_privs:<system.amos-zenka-user>]`), calls
`[base.get_session_id]`, and enters `[zenka.loop]` immediately as a
headless background service — the opposite shape from `user-edit`'s
auth-as-invoking-user / `[base.call.console_command:<system.args>]` /
no-automatic-loop console pattern. this is why trying to start it
interactively hits a permission wall today.

**what needs building** (additive — the existing headless service and
`ui-show` stay exactly as they are, for programmatic/routed callers):
- a `cred-mesh.console.*` entry point mirroring `user-edit.console.start`
  (auth as invoking unix user, `[base.call.console_command:<system.args>]`
  dispatch, hybrid loop mode — `[init-done:TRUE]` + `[zenka.loop]` called
  by the console command itself, not the start file)
- `cred-mesh.term_init` / `cred-mesh.setup_stdin_watcher` /
  `cred-mesh.handler.stdin_key`, same shape as `user-edit`'s
- the existing phase-2 modules (`interactive.up/down/action/input/refresh`,
  the `row_keys`/`focus_index` contract) are NOT wasted — they're the
  right primitives, they just need to be called directly from the local
  stdin handler instead of dispatched as routed commands. the
  `%interactive_cmds` → `<base.cmd>` aliases stay useful for
  scripted/`p7c` access, separate from the interactive console path.
- unlike `user-edit start <username>`, which must name a target record
  (there's inherently something to name — like `vim <file>`), cred-mesh's
  UI is a shared-registry browser with no per-target identity: `ui-show`
  already defaults its view to `overview` with no argument, so the
  console entry point can plausibly need no required parameter at all.
  [ `user-edit`'s own console-invocation ergonomics — needing to type an
  exact subcommand word like `start` — aren't fully solved either; that's
  a separate, minor thing to adjust once a better idea has been found, not
  a blocker here ]
- once interactivity lives inside cred-mesh's own process, grant/approve
  payloads (and later, unlock phrases) never need to cross cube as command
  arguments at all — closing the security gap found above, not just the
  race condition.

**decided [ 2026-09-06, confirmed with a second opinion ]: a separate thin
console zenka, not a mode-branch inside cred-mesh's own `zenka.v7`.**
naming-collision on cube was the concern that made a same-name dual-mode
option look necessary — dropped once confirmed that outbound routing
already has selection modes (e.g. oldest-first) and replies route back
numerically by sid/cmd_id, so the console instance needs no inbound
addressability under the `cred-mesh` name at all. that leaves the
`user-edit`↔`users` shape as the strictly better option: cred-mesh's
existing headless `zenka.v7` (privilege-drop, `get_session_id`,
`zenka.loop`) stays completely untouched — no new conditionals on the
zenka that holds credential material — and the new console zenka is a
pure client, auth'd as the invoking unix user, that routes every action
(`interactive-*`, `resolve`, `rotate`, etc.) to the real `cred-mesh` by
name over cube, exactly as those commands already work today.

the load-bearing implementation detail, carried over from `user-edit.
console.start`: send one routed command, then `[base.init-done:TRUE]` +
`[base.zenka.loop]` to block **for that specific reply** before reading
the next keystroke. this is what actually eliminates the nshell-relay
race — not "own the terminal" alone, but serializing keystroke → routed
call → reply → repaint as one sequential turn per key, so there are never
two independent async event sources racing over the same modal state.

**named [ 2026-09-06 ]: `vault-edit`.** not considered final — per user,
easy to rename later via `bin/rename` + `ncode replace` once a better name
turns up, same as any other rename in this codebase.

**implemented [ 2026-09-06 ] — NEVER EXECUTED, not once.** full scaffold
written: `cfg/zenki/vault-edit/zenka.v7` (auth as invoking unix user, no
`[base.get_session_id]`, `[base.call.console_command:<system.args>]`, no
top-level `[zenka.loop]`) plus ten `src/vault-edit.*` modules —
`init_code`, `term_init`/`term_restore` (near-verbatim `user-edit`
clones), `setup_stdin_watcher` (stdin-only, no local render-on-mutation
watcher needed since there is no local render step), `console.show` (the
entry point: resolves `$cube_sid` from `<user.cube.session>`, sends the
initial `cred-mesh.ui-show [<view>]`, then `[init-done:TRUE]` +
`[zenka.loop]`), `send_action` (builds and sends one routed
`cred-mesh.<verb>` call, self-loopback-addressed via
`"$cube_sid.cred-mesh.<verb>"` exactly as `user-edit.console.start`
addresses `users` — NOT a bare `cred-mesh.<verb>` target, see its own
header comment for why), `handler.reply` (clears busy, prints the
payload, arms `pending` on a prompt-frame header match), and
`process_input_buffer` (the actual key→verb table: `j`/`k`=nav,
`r/x/g/a/?`=actions, `q`/Esc=quit, free-text prompt entry entirely local
until Enter submits).

**the actual race-fix mechanism, simpler than first planned**: not a
nested `[zenka.loop]` per keystroke (user-edit only needs that once, for
its one bootstrap fetch, because its field editing afterward is entirely
local). every vault-edit action needs a real round trip since cred-mesh
owns all state/rendering, so the fix is a plain `<vault-edit.busy>` flag:
`process_input_buffer` refuses to decode further keys while a call is
outstanding, and `handler.reply` clears the flag and resumes decoding any
keys that piled up in the meantime. this works only because Perl's
event loop is single-threaded (callbacks always run to completion before
the next fires) — the flag has nothing concurrent to race against, unlike
nshell's cross-process flag coordination.

**two caveats from a self-review, one fixed, one left as a note**:
- fixed: `send_action` now checks `send.local`'s own return value (`1+`
  sent, `0` unknown target, `-1` empty session table, `-2` malformed
  command) — a non-positive result now clears `busy` and prints a
  visible error, instead of leaving the client permanently wedged
  (accumulating dead keystrokes with no visible cause) if cred-mesh isn't
  running when a call goes out.
- left as a note, not code: `interactive-input`'s wire line is `text
  session_id=NNN`; if typed prompt text itself happened to END in
  something matching `\s+session_id=\d{3,17}`, cred-mesh's own suffix
  strip would eat the wrong tail. far-fetched for a zenka name or a
  relay payload, not worth guarding against here.

**first test should be the cheapest possible, in order**: (1)
`Protocol-7 vault-edit commands` — should print and exit immediately,
proving the no-`[zenka.loop]`-in-start-file hybrid shape works at all
before touching a real terminal; if this hangs, the start file itself is
wrong and nothing past it matters. (2) only then `vault-edit show` (or
bare `vault-edit`) at a real tty. expect untracked files to appear under
`cfg/zenki/vault-edit/deps/` after the first start — same auto-generated
scaffolding seen when `credentials` was started manually earlier this
session, not a bug.

no `access.zenki` changes were needed: vault-edit authenticates as the
plain invoking unix user (subname `[vault-edit]` is stripped before any
access check, `user-edit.init_code`'s own precedent), which already falls
under `cfg/zenki/cube/access.zenki`'s `access.cmd.usr.*` wildcard —
exactly the same group nshell's own working `cred-mesh.*` calls already
go through.

**first live test [ 2026-09-06, same day ] — two real bugs found, both
fixed, `vault-edit.dispatch_key` added along the way**:

1. **display-width bug**: `console.show`'s `# param =` header comment was
   multi-line; the `commands` listing generator only reads the first line
   after `param =` and concatenates it with `descr` with no wrapping,
   blowing out the frame width. Fixed by shortening to a one-line
   `# param = [ <view> ]`, matching `user-edit`'s own terse style, with
   the fuller explanation moved to a body comment.
2. **dead keyboard, two separate causes, not one**: a diagnostic print
   confirmed the `event.add_io` watcher itself fires fine (bytes really
   are arriving) — the bug was entirely downstream, in key decoding:
   - arrow keys did nothing: the terminal was sending SS3 form (`\eOA`..
     `\eOD`, 3 bytes) rather than CSI (`\e[A`..`\e[D`) — `%key_verb` only
     had CSI entries. Missed porting nshell's own SS3-to-CSI
     normalization (`nshell.read_from_buffer`'s `%ss3_arrow_map`) when
     building vault-edit fresh. Fixed, same table.
   - Esc needed two presses: `editor.input.next_key` deliberately never
     resolves a lone `"\e"` on its own (can't distinguish a bare Esc from
     the first byte of a still-arriving escape sequence, by its own
     documented contract) — needs the same one-shot timeout `user-edit`
     already has (`.esc.timer` armed in the drain loop, cancelled on new
     input in `handler.stdin_key`, resolved by a new
     `vault-edit.handler.esc_timeout`) which was simply omitted from the
     first pass. Fixed.

   Fixing bug 2's Esc-timeout path required calling the exact same
   per-key handling logic from two places (the normal drain loop AND the
   timeout handler) — factored into a new `src/vault-edit.dispatch_key`
   module (returns TRUE if it sent a routed call, so the caller knows to
   stop draining) rather than duplicating the pending/nav-mode branches.
   `process_input_buffer` is now just the decode loop + Esc-timer arming;
   `dispatch_key` holds the actual per-key behavior.

3. **safety fix, unprompted by a specific failure but real regardless**:
   `term_init` turns `ISIG` off, so Ctrl-C reaches the key handler as a
   byte (`\x03`), not a signal — but nothing handled that byte, leaving a
   stuck session with no way out short of killing the process from
   elsewhere. `dispatch_key` now checks for it unconditionally, before
   the pending-prompt branch, so it works from any state.

still not confirmed by a live test as of this note: whether `j`/`k`/
`r`/`x`/`g`/`a`/`?` and the grant/approve free-text prompt actually work
end to end now that the two decode bugs are fixed — only the `ui-show`
render and the (broken, now-fixed) Esc/arrow paths have been exercised so
far.

**second live test round, same day — one more real bug found, in
`handler.reply` this time, not in key decoding.** with the SS3/Esc fixes
in, `j` produced no visible effect either — but two targeted diagnostics
(printing `send.local`'s return value and confirming `handler.reply`
actually fires) showed the reply DOES arrive every time
(`handler.reply fired, cmd=FALSE data_len=<undef>` for `interactive-
down`, vs `cmd=SIZE data_len=792` for the working `ui-show`). the bug:
`handler.reply` only ever read `$reply->{'data'}` — but a plain `TRUE`/
`FALSE` reply carries its short message in `$reply->{'call_args'}{'args'}`
instead, `data` is only populated for a `SIZE`-style multi-line payload.
this exact distinction is spelled out in `nshell.handler.command_reply`,
read directly earlier in this same session, and simply didn't carry over
into `vault-edit`'s version. fixed: `my $payload = $reply->{'data'} //
$reply->{'call_args'}{'args'};`. both diagnostics removed once the cause
was confirmed.

this means every prior "nothing happens" report for nav/action keys was
this one bug, not a deeper session/routing problem — `cred-mesh.ui.
interactive.down`'s reply was arriving correctly the whole time, just
never displayed.

**third live test round, same day — the FALSE reply's real text turned
out to be a permission error, a pre-existing gap independent of anything
built this session.** with the display fix in, the actual message was
finally visible: `no perm. [ src 'cube' cmd|usr 'interactive-down' ]`
(and the same for `interactive-up`). two SEPARATE permission lists exist,
both required, and only one of them had ever been updated:

1. `cfg/zenki/cube/access.zenki`'s `access.cmd.usr.*` wildcard — governs
   what cube will route at all. Already correctly listed every
   `interactive-*` alias (checked earlier this session, correctly).
2. `cfg/zenki/cred-mesh/zenka.v7`'s OWN `access.cmd.usr.cube` — governs
   what cred-mesh accepts from cube AS THE IMMEDIATE PEER (cred-mesh sees
   the connection as literally *from cube*, regardless of who originated
   it further upstream — hence `src 'cube'` in the error, not `taeki` or
   `taeki[vault-edit]`). This list only ever had `ui-show` added to it,
   never the `interactive-*` commands — a gap in the original Phase 2
   work that simply never surfaced before, because nothing had actually
   routed those commands through cube until `vault-edit` this session
   (the reverted nshell attempt never got far enough to hit it either —
   it was killed by the architecture concern before `interactive-down`
   was ever actually tried against a live cred-mesh).

Fixed: added `interactive-up interactive-down interactive-refresh
interactive-select-view interactive-action interactive-input` to
`cfg/zenki/cred-mesh/zenka.v7`'s `access.cmd.usr.cube` list, alongside
the existing `ui-show`. **Needs `cred-mesh` itself reloaded or restarted
to take effect** — reloading `cube` (tried once already this round, had
no effect, as expected) does nothing here since the list lives entirely
in cred-mesh's own config. Try `cred-mesh.reload` first; if a config
reload doesn't pick up an `access.cmd.usr.*` change, `v7-zenki.restart
cred-mesh` will.

**fourth live test round, same day — permission fix confirmed working
(no more "no perm"), replaced by "no active ui focus" on every
`interactive-down`/`interactive-up` press.** root cause: a session-key
mismatch caused by two DIFFERENT session_id-extraction regexes disagreeing
on a bare call.

`cred-mesh.cmd.ui-show`'s own extraction is `s|\s+session_id=(\d{3,17})$||`
— it requires LEADING WHITESPACE before `session_id=`, i.e. it assumes the
wire shape is always `<view> session_id=NNN`. `vault-edit.console.show`'s
bare call (no view given) sent just `session_id=2754747` with nothing in
front of it — that regex silently failed to match [ no error, no warning
], `$session_id` stayed `''` [ `cmd.ui-show` has no missing-session_id
guard at all, unlike every interactive-* module ], and cred-mesh
initialized focus under the EMPTY-STRING session key instead of ours.
Meanwhile `cred-mesh.ui.interactive.down`'s own extraction
(`m|session_id=(\d{3,17})|`, no anchor, no whitespace requirement)
correctly found `2754747` and looked in the right bucket — which was
simply never populated. `ui-show` itself kept "working" throughout every
prior test because rendering doesn't require pre-existing focus to
already exist; only the interactive.* actions do.

fixed on vault-edit's side: `console.show` now always sends an explicit
view word (`ui-show overview`, never bare `ui-show`), guaranteeing the
`\s+session_id=` shape `cmd.ui-show`'s regex expects.

**not fixed, flagged instead**: `cred-mesh.cmd.ui-show`'s own regex is
the more fragile of the two designs here — every OTHER interactive.*
module tolerates a bare `session_id=NNN` with no anchor/whitespace
requirement, and has an explicit "missing session_id" guard besides.
`cmd.ui-show` has neither. Any other future caller sending a bare
`ui-show session_id=NNN` (no view) would hit the exact same silent
empty-string-key bug. Worth hardening `cmd.ui-show` to match the other
modules' pattern (`m|session_id=(\d+)|` + an explicit guard) in a
follow-up — left alone this session per the "additive, don't touch
already-tested Phase 2 code beyond what's needed" principle, since the
vault-edit-side fix fully resolves the reported symptom on its own.

**not yet re-tested after this fix — and before it could be, a separate,
real infrastructure gap surfaced: two `cred-mesh` zenki instances were
found running simultaneously**, almost certainly from the `cred-mesh.
reload`/`v7-zenki.restart cred-mesh` cycle used to pick up the
access.zenki fix racing against the still-shutting-down prior instance.
`cfg/zenki/cred-mesh/start.cfg` had no `max_concurrency` setting at all —
confirmed against `cube`/`p7-log`/`httpd`'s own `start.cfg` files, all of
which set `max_concurrency = 1` as a bare top-level key. Added the same
to `cred-mesh/start.cfg`.

this retroactively casts doubt on how much of the "no active ui focus"
diagnosis above was the WHOLE story versus partly an artifact of two
independent cred-mesh processes each holding their own separate,
inconsistent focus state, with `base.zenki.resolve_routing_sids`
[ the same multi-instance disambiguation the user pointed out earlier
this session handles oldest-first-style selection ] not necessarily
picking the same instance for every call. the `cmd.ui-show` regex bug is
real and independently confirmed by direct code reading regardless, so
that fix stands either way — but the "no active ui focus" symptom may
have been two overlapping causes, not one, and can only be properly
re-tested once the duplicate is cleaned up and exactly one cred-mesh
instance is confirmed running (`list` / `cred-mesh.subname`, then
`v7-zenki.stop` — NOT `.restart`, an in-band command a stuck instance may
not answer — on any strays) before the next `vault-edit show` attempt.

## RESOLVED [ 2026-09-07 ] — "no active ui focus" was two real,
## pre-existing framework bugs, both now fixed, unrelated to vault-edit

Added `src/vault-edit.cmd.char-add` (mirroring `user-edit.cmd.char-add`
exactly: gated on `<vault-edit.mode.no_tty_debug>`, set by `show -no-tty`,
injects keys into the same buffer a real keystroke would, drives the
event loop with `event.once` until the outstanding call replies, returns
`<vault-edit.last_render>`) specifically so this investigation no longer
needed a human relaying screen output for every test round. This is what
made finding the actual root cause tractable — direct `p7c
cred-mesh.ui-show ...` calls plus `cred-mesh.dump`/`cred-mesh.get`
introspection (bypassing vault-edit entirely) is what isolated the bug to
cred-mesh/framework code, not vault-edit.

**Duplicate `cred-mesh` instance turned out to be a dead end** — after
cleanup, "no active ui focus" persisted identically. Not the cause (or
not the whole cause); `max_concurrency = 1` stays as a good defensive fix
regardless.

**Bug 1 — `src/ui.unfold`, a shared/generic module, silently dropped all
arguments when delegating to a zenka-specific `<namespace>.cmd.ui-show`
override.** `<base.cmd>{'ui-show'}` resolves to `ui.cmd.ui-show` (the
*generic* base implementation, part of the `ui` module every zenka using
`[zenka.loop]` loads) — NOT to `cred-mesh.cmd.ui-show` directly, despite
cred-mesh's own file existing and visibly running (confirmed by an early,
wrong theory about "last-registration-wins" being disproven via `cred-
mesh.get base.cmd.ui-show` → `ui.cmd.ui-show`). `ui.cmd.ui-show` detects
a zenka-specific override exists and delegates to it through
`ui.unfold`'s own "[ 2 ] specific ui-show command" branch — which called
`$code{$cmd}->()` with **zero arguments**. Confirmed directly: `p7c
cred-mesh.ui-show overview` (bypassing vault-edit, cube, and self-
loopback routing entirely) landed in `cred-mesh.cmd.ui-show` with
`$call->{'args'}` completely `undef`, regardless of what was typed.
Fixed: `ui.cmd.ui-show` now forwards its own unparsed `$args_str` into
`ui.unfold` as a new `raw_args` field (additive — any other existing
caller not passing it gets the same `undef` as before), and `ui.unfold`
now calls the override with it: `$code{$cmd}->($raw_args)`. `cred-mesh`
is currently the only zenka with a `.cmd.ui-show` override
(`find src -iname '*.cmd.ui-show'` confirms just the two files), so this
carried no other-zenka regression risk.

**Bug 2 — `cred-mesh.cmd.ui-show` itself, a classic Perl auto-
vivification trap.** Even after bug 1's fix restored real args, focus
still never persisted. `my $ui = $data{'session'}{$session_id}
{'cred-mesh'}{'ui'};` **copies** the current value — `undef`, on first
entry — into `$ui`; the later `$ui->{'focus'} = $focus;` then
autovivifies a brand-new hashref disconnected from `%data`, so the write
silently never reaches `%data{session}{...}{cred-mesh}{ui}` at all.
Confirmed directly via `cred-mesh.dump session.<id>` immediately after a
real `ui-show` call: `session.<id>.cred-mesh = { }`, genuinely empty,
matching every subsequent `interactive-down`'s correctly-resolved-but-
never-populated session_id. Fixed: `my $ui = $data{...}{'ui'} //= {};` —
`//=` operates on the hash element itself, so `$ui` becomes a real alias
into `%data` whether newly created or pre-existing. Checked every sibling
`cred-mesh.ui.interactive.*` module for the same pattern — all of them
only ever *read* `$ui`/`$focus` after `cmd.ui-show`'s init has already
run (and correctly guard on "not defined" before writing anything), so
none of them share this bug.

**Verified end-to-end after both fixes**, via `char-add` against a fresh
instance: `cred-mesh.dump session.<id>` shows real, persisted
`cred-mesh.ui.focus.{view,row_index,row_count,row_keys,pending_action}`
after `ui-show`; pressing `r` (rotate) now returns `no slot focused` —
the CORRECT status (overview's registry section has 0 rows, nothing to
select) — instead of `no active ui focus`; `q` cleanly terminates the
session.

**Not yet verified**: the actual interactive TTY experience (real
terminal, not `-no-tty`/`char-add`) — only headless testing has happened
since these fixes landed. `j`/`k`/`g`/`a`/`?` and the grant/approve
free-text prompt specifically still need a real-terminal pass. All
temporary diagnostics (`cred-mesh.debug.*` %data writes, one `base.logs`
call) have been removed from `cred-mesh.cmd.ui-show` and `cred-mesh.ui.
interactive.down`; leftover test session-id debris in `%data` (fake ids
like `555444`, `999888`) is harmless and untouched.

Every file touched this round — `src/ui.unfold`, `src/ui.cmd.ui-show`,
`src/cred-mesh.cmd.ui-show`, `src/vault-edit.cmd.char-add`,
`cfg/zenki/vault-edit/zenka.v7` (added `char-add` to
`access.cmd.usr.cube`) — needs signing before commit.

**fifth live test round, first REAL terminal test since the framework
fixes landed — core functionality confirmed working (a keypress DID
trigger a fresh render), but the screen was never cleared between
frames**: each new render just printed below the previous one, scrolling
the terminal instead of updating in place. `vault-edit.handler.reply`
only ever did `print "\r\e[2K"` [ clear the CURRENT LINE ] before
printing, copied from `nshell.handler.command_reply`'s own precedent —
but nshell's replies are one-shot command output, never a repeated
full-screen redraw, so clearing one line is correct there. vault-edit is
a full-screen browser; every action re-renders the whole frame. Fixed:
`print $colors{'clear_screen'} // ''` before each render [ same
convention already used in `vault-edit.quit`/`term_restore`,
`base.cmd.clear`, `user-edit.form.quit` ], skipped in `-no-tty` mode
where nothing is watching the terminal and `char-add`'s returned text
should stay plain content, not ANSI noise.

**sixth live test round — screen-clear fix confirmed working (core
mechanism: keypress → routed call → real state change → re-render, now
proven end-to-end on a real terminal). But per the user, directly: "I
don't understand the UI at all... compared to user-edit, which behaves
well interactively... it will need a lot of work until anything
productive can be done with it." Taking that at face value — it's an
honest, accurate read, not a bug to argue away.**

**Concrete cause of the most disorienting symptom (the header vanishing
after the first keypress)**: `ui.cmd.ui-show`'s generic header-wrapping
(the `.:[ cred-mesh ]:.` line, from its `ascii-frame.load('ui-show-
fallback-header')` + `TITLE=$address` logic) only ever runs on the
*initial* `ui-show` call. Every subsequent action (`j`/`k`/`r`/etc.)
calls `cred-mesh.ui.interactive.refresh` directly — a separate code path
this session never built and that was never wrapped by that header logic
in the first place. So the header was never actually a persistent part
of the UI; it only appeared once, by accident of which call path
happened to run first. **Pre-existing Phase 2 gap, not something this
session's changes touched** — but it directly explains why the browser
feels disorienting the moment you move past the first screen.

**What this session actually delivered, stated plainly**: a correct
plumbing layer (keypress → routed call → persisted state change →
re-render), verified end-to-end, with the underlying framework bugs that
blocked it fixed. What it is NOT: a *designed* interface. No persistent
orientation (which view / whose session), no on-screen key hints [
`user-edit` has this and vault-edit doesn't ], no distinct visual
treatment for the common "0 rows, nothing selectable" state beyond a
bare restriction notice. Closing that gap is real interaction-design
work, not a bug fix, and per the user deserves its own dedicated session
rather than more reactive patching on top of tonight's fixes.

**Per the user: ready to sign and commit as a checkpoint anyway** — this
round's plumbing fixes (`ui.unfold`, `ui.cmd.ui-show`, `cred-mesh.cmd.ui-
show`, the screen-clear fix, `char-add`) are real, independently
verified, and worth landing regardless of the UX gap above. The UX/
interaction-design pass is the explicit next step, not done here.
**Committed as `62923a289`.**

## `user-edit` comparison [ per the user's own suggestion, same session ]

Started `user-edit` headlessly (`Protocol-7 user-edit start -no-tty`) and
drove it via its own `char-add` for a concrete quality/feature-
completeness bar to aim `vault-edit` at. **Caution for next time**:
`user-edit`'s `char-add` directly mutates LIVE form data on every
keystroke (unlike `vault-edit`'s, which only triggers safe nav/actions) —
a stray test key edited the real `taeki` record's `full_user_name`
in-memory. Caught immediately, corrected with `[Backspace]`, and exited
via `[Ctrl+c]` without ever submitting — `users.cmd.value-set` is only
ever called on explicit submit, confirmed after the fact via `users.
value-get` showing the real record untouched. Anyone driving `user-edit`
`char-add` again against a real record should be aware of this.

what the comparison actually showed, concretely — the bar `vault-edit`
needs to reach, and specific reusable techniques, not just a vibe:

- **a persistent title bar** (`.:[ user-edit : taeki ]:.`) that `vault-
  edit` doesn't have past its first screen (the header-vanishes bug
  above) — owned by the CLIENT, not borrowed from a one-shot server-side
  wrapper the way vault-edit currently (accidentally) relies on.
- **labeled fields in a fixed layout**, never a raw dump.
- **inline key hints placed next to what they act on** (`key actions:
  '-> create key .:. [r]ename .:. [d]elete`), not left for the user to
  memorize or guess.
- **a footer status line** (`active field : X [ N of M ]`) — constant
  orientation regardless of what else is on screen.
- **collapsed previews** for anything multi-valued (`:..8.entries..:`)
  instead of dumping everything or showing nothing.
- **a one-shot discovery hint woven into the frame's own border**, not a
  separate line: `user-edit.form.render` replaces the card's closing
  border row with `.c.t.r.l-?.:.t.o.g.g.l.e..c.m.d..l.i.s.t` [ hand-spaced
  to match the border's own dot-fill rhythm ] on the very first render
  only, gated on `<user-edit.form.hint_seen>`, and reverts to a plain
  border the instant ANY key is pressed. No extra line, no width
  reservation — directly reusable technique for `vault-edit`'s own first
  screen (e.g. hinting at `?`/the key table) rather than inventing
  something new.

`vault-edit` currently has none of these — it just prints cred-mesh's raw
rendered block. This is the concrete spec for the next session's
interaction-design pass, not a vague "make it nicer."

## relation to CONSOLE-FOLD-TREE-PHILOSOPHY

the **interactive verbs** here (select / act / unlock) operate on
nodes that, per `data/md/design/CONSOLE-FOLD-TREE-PHILOSOPHY.md`, are
already foldable handles into the namespace. selection is "give this
folded handle attention" and unfold is the response — proving the
fold/unfold verbs flow naturally into interaction without a separate
interaction model.

## dispatch
add interactive selection, slot actions, and key-holder unlock to the
cred-mesh ui. requires `cred-mesh-ui-frames.md` to have
landed. read first:
`data/md/design/CRED-MESH-INTEGRATION-AND-UI.md` (part 2,
"selection layer", "actions", "key-holder dialog integration");
`data/tasks/cred-mesh-ui-frames.md`;
the render modules created by the frames task
(`cred-mesh.ui.render.*`);
`src/keys.console.list` for the ansi colorisation pattern that
highlight rendering will mirror;
`src/cred-mesh.rotate`, `src/cred-mesh.register`,
`src/cred-mesh.key_holder.parent`,
`src/cred-mesh.key_holder.child` for the operations the ui
will trigger and the unlock pipe contract.
this task does NOT add a new windowing system, vterm integration, or
multi-pane layout. it operates inside one tty session at a time.

## scope

three layers added on top of phase 1's read-only views:

1. **selection state + highlight rendering** — per-session focus row,
   re-render-on-input loop
2. **slot actions** — rotate, revoke, grant, approve
3. **key-holder unlock dialog** — phrase-prompt frame, no-echo input,
   pipe contract to key-holder.child for decrypting `fabric.secret`

## part 1 — selection state

### where state lives
`<session.$session_id.cred-mesh.ui.focus>` — per-session, so
multiple nshell users do not collide. shape:
```perl
{
    view      => 'slots',              ## current view name
    row_index => 3,                    ## 0-based row in current view
    row_count => 12,                   ## last-rendered row count, for clamping
    row_keys  => [ 'openweathermap.api-key', ... ],  ## resolved keys per row
    pending_action => undef,           ## or 'approve_payload', 'grant_zenka'
}
```

`row_keys` is filled by the render module — when a render layer produces
the rows, it ALSO returns the ordered keys to the dispatch layer. tiny
contract change on the render layer: instead of returning just the
string, return `{ rendered => $str, row_keys => \@keys }`. update the
phase-1 render modules to add `row_keys` (which can be `[]` for views
without selectable rows like `overview`).

[ note: this is a backward-compatible extension — callers that only
  want the string can read `$result->{rendered}`. the phase-1
  acceptance still holds. ]

### selection modules

under `src/cred-mesh.ui.interactive.*`:

- `cred-mesh.ui.interactive.up` — decrement `row_index`,
  clamp to 0
- `cred-mesh.ui.interactive.down` — increment, clamp to
  `row_count - 1`
- `cred-mesh.ui.interactive.refresh` — re-run the active
  view's render and reprint. returns the new rendered string.
- `cred-mesh.ui.interactive.select_view` — switches the
  current view, resets row_index to 0, returns first refresh

### highlight rendering

selection is colorisation, not a new frame primitive. each render
module receives an optional `focus_index` param. when present and
the row index matches, that row's content line is wrapped with the
project's ansi inverse marker (`$C{T}` background swap or
`\e[7m...\e[27m`). pattern: the row format is already a single line
inside the block slot; pre-render the row, then conditionally wrap.

update phase-1 render modules that have selectable block slots
(`registry-list`, `rotation-log`, `auth-relay-queue`) to accept and
apply `focus_index`. detail and key-holder-status views ignore it.

## part 2 — slot actions

### action dispatch
`src/cred-mesh.ui.interactive.action` — args: `action_name`,
`session_id`. reads focus state, finds the focused slot/req_id from
`row_keys`, dispatches.

```perl
my $key = <session.$sid.cred-mesh.ui.focus>->{'row_keys'}
    ->[ <session.$sid.cred-mesh.ui.focus>->{'row_index'} ];
```

### actions to implement

**`rotate`** — calls `cred-mesh.rotate` with the focused slot
name. on success, refreshes the current view. on failure, sets a
one-line status message in `<session.$sid.cred-mesh.ui.status>`
that the render layer prints below the frame.

**`revoke`** — sets `<cred-mesh.registry>->{$slot}->{'revoked'}`
= TRUE and persists the registry. `cred-mesh.resolve` returns
undef for revoked slots — small edit to `cred-mesh.resolve` to
check the flag and bail early. revoked slots stay in the list but are
rendered with a strikethrough marker (e.g. `[revoked]` suffix) so the
user sees them.

**`grant`** — opens a sub-frame prompt (`grant-prompt.yaml`, new
template) asking for a zenka name. sets `<session.$sid.credential_
fabric.ui.focus>->{'pending_action'} = 'grant_zenka'`. on the next
input cycle, the input is captured as the zenka name and appended to
the slot's `access_grants` list (new field; default `[]`). this is
**advisory** for now — the actual access check still belongs to
`cfg/zenki/cube/access.zenki`. mention this clearly in the
status line: `granted (advisory — update cube access for enforcement)`.

**`approve`** — only valid on the auth-relay queue view. opens
`approve-prompt.yaml` (new template) asking for the credential payload.
on submit, calls `cred-mesh.cmd.approve` (created by the wiring
task). for high-sensitivity types, the prompt routes through the
unlock-prompt frame instead (no echo).

### action key bindings

mapped at the nshell-side input handler — `nshell.editor.process` or
its key dispatch table — when the active view is one of the credential-
fabric ui views. bindings:

```
j / down arrow      → interactive.down
k / up arrow        → interactive.up
r                   → interactive.action rotate
x                   → interactive.action revoke
g                   → interactive.action grant
a                   → interactive.action approve
?                   → interactive.action detail   [ switch to registry-detail of focused slot ]
q / ESC             → exit ui mode, return to normal nshell
```

[ this is the only nshell-touching change in the task — confirm the
  key dispatch table location in `src/nshell.editor.process` or
  `src/nshell.handler.command_reply` during implementation. keep
  the bindings active only when the current command was a
  `cred-mesh.ui.show` view. ]

### action prompts

new frame templates under `data/yaml/ascii-frames/cred-mesh/`:

**`grant-prompt.yaml`** — one-line input frame:
```
.:[ grant access to ]:::::::::::::::::::::::::[ zenka name ]:.
:  > {{ZENKA_NAME}}                                          :
:............................................................:
```

**`approve-prompt.yaml`** — one-line input frame:
```
.:[ approve relay ]:::::::::::::::::::::[ {{REQ_ID}} ]:.
:  > {{PAYLOAD}}                                       :
:......................................................:
```

both have one editable slot (`ZENKA_NAME`, `PAYLOAD`). the editor
itself runs in the nshell-side input layer — the frame is the visual
container only.

## part 3 — key-holder unlock dialog

**revision**: the primary path is now `protocol-7-menu.cmd.input-
password` (gtk modal, masked entry — read that module). the custom
`unlock-prompt.yaml` + nshell no-echo handler described below is the
**secondary headless-fallback** path, used only when the gtk dialog
returns `{ mode => 'false', data => 'graphical mode not enabled' }`.

phasing inside this part splits accordingly:

- **phase 3a** (small): edit `cred-mesh.key_holder.parent` to
  route-send to `protocol-7-menu.cmd.input-password` when an unlock is
  needed. on `reply.mode == 'true'`, write phrase to the child pipe.
  on graphical-mode-not-enabled, branch to 3b. on cancellation, leave
  child locked and surface failure to the next resolve call.
- **phase 3b** (the original work below): the frame + no-echo nshell
  handler, only invoked when 3a falls back.

cross-zenka note: `cred-mesh` calling `protocol-7-menu.cmd.
input-password` is a new edge — see `cred-mesh-wiring.md` §5
for the same plumbing on the auth-relay path. land that first or in
parallel; the same access.zenki entry covers both call sites.

### the migration this assumes
currently `cred-mesh.key_holder.child` (src/credential_
fabric.key_holder.child) auto-generates `var/cred-mesh/
fabric.secret` unencrypted on first run. the design assumes this
secret will be twofish-encrypted with a user phrase. **migrating
existing unencrypted stores is out of scope of this task** — it is
flagged as a follow-up in the design doc's risks section. this task
implements the dialog and pipe contract assuming the encrypted form;
the actual encryption switch lands separately.

if no encrypted-secret form exists on disk when this task lands,
the unlock dialog is dead code — confirm with the design doc author
before merging.

### the contract
`cred-mesh.key_holder.parent` will get a new state machine:

```
start
  → read fabric.secret header
  → if header indicates encrypted form (magic prefix, e.g. "EU:")
      → fork child without phrase
      → child blocks on its pipe for an `UNLOCK <phrase_b32>` line
      → parent emits event cred-mesh.ui.event.unlock_required
      → ui renders unlock-prompt frame
      → user types phrase (no echo)
      → ui sends phrase via cred-mesh.cmd.unlock
      → cmd writes UNLOCK line to parent → forwards to child
      → child decrypts secret, derives keys, prints "READY"
      → parent unblocks
```

### new template

**`unlock-prompt.yaml`**:
```
.:[ key-holder ]::::::::::::::::::::[ phrase required ]:.
:  > {{PHRASE_MASKED}}                                  :
:.......................................................:
```

`PHRASE_MASKED` is `*` per character, length = phrase length. echo
suppression lives in the nshell-side input handler — the frame just
renders the mask.

### new modules

- `src/cred-mesh.cmd.unlock` — receives the phrase from
  the ui, forwards to `key_holder.parent`. clears the phrase from
  memory after send (set to undef, no logging).
- `src/cred-mesh.ui.interactive.unlock_dialog` — renders
  the unlock-prompt frame, sets `<session.$sid.cred-mesh.ui.
  input_mode> = 'no_echo'`, registers a one-shot input handler that
  sends the phrase to `cmd.unlock` then closes.

### edits to existing modules

- `cred-mesh.key_holder.child` — add UNLOCK op alongside
  ENCRYPT/DECRYPT/SIGN. when received, decrypts `fabric_secret` using
  the phrase via `AMOS7::13::key_32` + `AMOS7::Twofish::decrypt`.
  responds `READY\n` on success, `ERR <msg>\n` on failure.
- `cred-mesh.key_holder.parent` — buffer pre-unlock requests,
  flush them once child sends `READY`. on `ERR` from child, do NOT
  retry automatically — emit a fresh `unlock_required` event so the
  user can correct the phrase.

## what NOT to do

- do not add a new zenka.
- do not extend `ascii.frame.*` or `pager.*` or `vterm.*` internals.
- do not write the actual fabric.secret-encryption migration here.
  that is its own task — flag it in the design doc and stop.
- do not log the phrase, ever. not at level 5, not at trace level,
  not in error messages. an accidental log line here is a hard
  failure of this task.
- do not add the `#,,..` signature stub to any new file.

## acceptance

phase 2 (selection + actions):
- with the ui active, `j`/`k` move the highlight up/down in the slot
  registry view. row count is clamped correctly.
- pressing `r` on a focused slot rotates it; the view re-renders with
  a new `last_rotated` timestamp visible in the detail card.
- pressing `x` marks the slot revoked; `resolve` returns undef for it
  afterwards; the row shows `[revoked]`.
- pressing `g`, then typing a zenka name, then enter, appends the
  zenka to `access_grants`. status line shows the advisory message.
- pressing `a` on a pending relay row, typing a payload, hitting
  enter, calls the wiring task's `cmd.approve` and removes the relay
  entry.

phase 3 (unlock):
- with an encrypted fabric.secret in place, starting the credential_
  fabric zenka renders the unlock prompt automatically.
- typing the wrong phrase shows an error status and re-prompts.
- typing the right phrase unblocks the holder; subsequent
  `cred-mesh.resolve` calls succeed.
- the phrase never appears in any log file or in-memory data tree.

## harmony checks
```
harmony cred-mesh.ui.interactive.up
harmony cred-mesh.ui.interactive.down
harmony cred-mesh.ui.interactive.refresh
harmony cred-mesh.ui.interactive.select_view
harmony cred-mesh.ui.interactive.action
harmony cred-mesh.ui.interactive.unlock_dialog
harmony cred-mesh.cmd.unlock
```

re-run harmony on edited modules (`cred-mesh.resolve`,
`cred-mesh.key_holder.parent`, `cred-mesh.key_holder.
child`, the phase-1 render modules that added `row_keys`).

## signatures note
do not add the `#,,..` stub to any new file. lowercase comments,
`[ word ]` annotations. no emoji.

#,,.,,.,.,,.,,..,,..,,,,,,.,,,.,.,.,,,.,.,,,.,..,,...,...,...,,.,,,.,,,..,,.,,
#I5LGX7F5DXWCFRMS5LCHH2OBWSWBDH7AKQMDRUXKXDDGFZWZ57JFFU7S7KVR4MSMDIR3LCOAKNURM
#\\\|VHP2AT7UN3K7Z26PXG7XBCOEBACVZRMBG3YK5JVSYPX3F26L2VM \ / AMOS7 \ YOURUM ::
#\[7]Q4LTJCA6PQWS3REUPOJWGFVMPYSQSPLKZV5BD6DTURONPZ3Z5YCI 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
