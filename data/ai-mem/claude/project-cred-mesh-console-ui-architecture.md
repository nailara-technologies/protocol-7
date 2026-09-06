---
name: project-cred-mesh-console-ui-architecture
description: cred-mesh interactive-ui task (data/tasks/credential-fabric-ui-interactive.md) — `vault-edit` (new console zenka, mirroring user-edit<->users) built, plumbing verified end-to-end after fixing 6 real bugs (2 pre-existing framework defects). Correct but per the user "I don't understand the UI at all" on first real-terminal test — no interaction design yet, that's the explicit next step
metadata:
  type: project
---

`data/tasks/credential-fabric-ui-interactive.md` is the source of truth for
this work — this memory is a pointer + the reasoning trail, not a
duplicate of its content.

**Phase 1 (read-only views) and phase 2 (selection state + slot actions —
rotate/revoke/grant/approve) are already implemented and correct**:
`src/cred-mesh.ui.interactive.{up,down,refresh,select_view,action,input}`,
the `{rendered,row_keys}`/`focus_index` render contract, `grant-prompt.yaml`/
`approve-prompt.yaml`. These are good primitives regardless of what
transport drives them.

**2026-09-06 session: tried wiring nshell's per-keystroke loop
(`nshell.read_from_buffer`) to relay `j/k/r/x/g/a/?/q` as routed
`cred-mesh.interactive-*` commands over cube, with `nshell.handler.
command_reply` detecting a returned prompt frame (by matching its ascii-
frame header text — `$reply->{'cmd'}` at that point is the wire reply word
[SIZE/STRM], not the routed command name, a gotcha worth remembering on
its own) to arm a pending-input handoff in `nshell.shell_loop`. Got as far
as live-testing `cred-mesh.ui-show` rendering correctly through nshell
(one-shot render over ordinary routing — fine, unaffected by any of this).
Two live bugs found and fixed along the way before the deeper problem
surfaced: (1) `cred-mesh.ui.show` vs the actually-registered `cred-mesh.
ui-show` — cube splits a routed command on the first dot only, so a
dotted command word after the zenka name never matches; (2) the wire
command names are the hyphenated aliases in `src/cred-mesh.init_code`'s
`%interactive_cmds` → `<base.cmd>` table (`interactive-down`, not `ui.
interactive.down`) — the internal module/file name is never automatically
the wire command name in this codebase.**

**Then the user (correctly) killed the whole approach**: nshell and
cred-mesh are separate OS processes connected only through cube's async
routed command/reply protocol. The prompt-mode handoff (`cred-mesh_ui_
pending`, armed by an async reply arriving on its own timing while
`read_from_buffer` fires independently on STDIN) is a genuine
unfixable-from-nshell's-side race — type fast enough after `g`/`a` and a
keystroke lands in the wrong mode. Separately, routing grant/approve
payloads (and eventually unlock phrases) as literal cube command arguments
exposes them to `p7-log`/terminal-history/any zenka with routing
visibility — the opposite of what a credential fabric should do. Both
findings were caught by the user, not by inspection ahead of time — see
[[feedback-check-console-zenka-precedent-before-cross-zenka-keystroke-relay]].

Reverted cleanly: the commit (`7af528e8c`) was local-only, never pushed
(`hub/base` didn't have it), so `git reset --soft` + selective `git
restore --source=f6a59105a` fully backed out `nshell.read_from_buffer`/
`nshell.shell_loop`/`nshell.handler.command_reply` with no trace, no
force-push needed.

**Decided direction (confirmed via a second-opinion advisor call)**: a
new, separate, thin console zenka — not a mode-branch inside cred-mesh's
own `zenka.v7` (which stays untouched: privilege-drop to
`<system.amos-zenka-user>`, `get_session_id`, `zenka.loop`, unchanged).
Modeled exactly on `user-edit`↔`users` (see
[[topic-user-edit-console-zenka-status]] for the full precedent — `user-
edit` owns its own terminal via `term_init`/`setup_stdin_watcher`/
`handler.stdin_key`, holds NO canonical data itself, and routes every data
op to the separately-named `users` zenka over cube). The new zenka would
do the same: auth as the invoking unix user (not
`<system.amos-zenka-user>`), its own termios/stdin watcher, and route
`interactive-*`/`resolve`/`rotate`/etc. to the real `cred-mesh` by name.

Naming-collision on cube (two sessions both claiming to be `cred-mesh`)
was the concern that initially made a same-name dual-mode option look
necessary — dropped once confirmed (by the user) that outbound routing
already has selection modes (e.g. oldest-first) and replies route back
numerically by sid/cmd_id, so the console zenka needs no inbound
addressability under the `cred-mesh` name at all.

**Load-bearing implementation detail** (the actual fix for the race,
carried from `user-edit.console.start`'s HYBRID LOOP MODE): send one
routed command, then `[base.init-done:TRUE]` + `[base.zenka.loop]` to
block for THAT SPECIFIC reply before reading the next keystroke. Owning
the terminal alone doesn't fix the race — serializing keystroke → routed
call → reply → repaint into one sequential turn per key does, because it
removes the second independent async event source entirely.

**Named: `vault-edit`** (not final — trivially renameable later via
`bin/rename` + `ncode replace`, same as any other rename in this
codebase).

**Built [ 2026-09-06 ] — NEVER EXECUTED, not once.** Full scaffold:
`cfg/zenki/vault-edit/zenka.v7` + ten `src/vault-edit.*` modules, mirroring
`user-edit`'s shape (auth as invoking unix user, no `get_session_id`,
`console_command` dispatch, no top-level `zenka.loop`). Full detail,
including the exact module list and the two self-review findings (one
fixed: `send_action` now checks `send.local`'s return value so a dead
cred-mesh doesn't wedge the client forever; one left as a documented
non-issue), is in `data/tasks/credential-fabric-ui-interactive.md` — read
that before touching this code, not this summary.

**The actual race-fix turned out simpler than user-edit's own pattern**:
not a nested `zenka.loop` per keystroke — that only matters for user-edit
because ITS field editing is local and only the bootstrap fetch/final
submit are routed. Every vault-edit action is routed (cred-mesh owns all
state/rendering), so the fix is a plain `<vault-edit.busy>` flag:
`process_input_buffer` won't decode further keys while a call is
outstanding, `handler.reply` clears it and resumes. Safe only because
Perl's event loop is single-threaded — no second thing is ever running
concurrently to race against, unlike nshell's cross-process flag
coordination which is what made the original attempt unfixable.

**First test, cheapest first**: `Protocol-7 vault-edit commands` (should
print-and-exit, proving the start file's hybrid shape works before a real
tty is involved) before `vault-edit show` at an actual terminal. No
`access.zenki` changes were needed — vault-edit's bare unix-user identity
already falls under the existing `access.cmd.usr.*` wildcard, same as
nshell's own working `cred-mesh.*` calls (though `cred-mesh`'s OWN
`access.cmd.usr.cube` list — a second, separate permission list, see
below — was itself missing every `interactive-*` entry, a real
pre-existing gap; fixed).

**RESOLVED 2026-09-07**: live testing surfaced a chain of real bugs, none
of them in the original architecture decision above, all now fixed —
full account in `data/tasks/credential-fabric-ui-interactive.md`, read
that for detail. Summary: (1) a display-width bug in `console.show`'s
header comment; (2) SS3 arrow keys + bare-Esc timeout, both omitted from
the first pass, needed porting from `nshell`/`user-edit`; (3) `vault-
edit.handler.reply` only read `$reply->{'data'}`, never `$reply->{
'call_args'}{'args'}` — the field a plain TRUE/FALSE reply's message
actually lives in (the exact distinction `nshell.handler.command_reply`
already documented, missed copying over); (4) `cred-mesh`'s OWN
`access.cmd.usr.cube` list in its `zenka.v7` — separate from cube's own
`access.zenki` wildcard — never had `interactive-*` added, only `ui-show`
(a real, pre-existing Phase 2 gap); (5) **the big one**: `src/ui.unfold`
(shared/generic, part of the `ui` module every zenka loads) silently
dropped ALL arguments (`$code{$cmd}->()`, zero args) when delegating to a
zenka-specific `<namespace>.cmd.ui-show` override — `<base.cmd>
{'ui-show'}` resolves to the generic `ui.cmd.ui-show`, not `cred-mesh.
cmd.ui-show` directly, confirmed via `cred-mesh.get base.cmd.ui-show`;
(6) `cred-mesh.cmd.ui-show` itself had a classic Perl auto-vivification
bug (`my $ui = $data{...}{'ui'};` copies undef instead of aliasing the
slot, so the later `$ui->{'focus'} = ...` write never reached `%data` at
all). (5) and (6) are genuine, pre-existing framework/Phase-2 bugs,
completely unrelated to vault-edit or anything built this session — only
surfaced because vault-edit was the first thing to actually exercise
`ui-show`'s args and the interactive-* focus lookup together, live.

Added `src/vault-edit.cmd.char-add` (mirrors `user-edit.cmd.char-add`)
specifically to stop needing a human to relay every test round — this is
what made isolating (5)/(6) tractable at all: direct `p7c cred-mesh.ui-
show ...` + `cred-mesh.dump`/`.get` introspection, bypassing vault-edit
entirely, is what proved the bug lived in shared framework code, not in
anything this session built. See
[[feedback-verify-dependency-layer-before-blaming-own-code]] for the
general lesson.

Verified end-to-end via `char-add`: focus persists in `%data` now
(`cred-mesh.dump session.<id>` shows real `cred-mesh.ui.focus.*` after
`ui-show`); `r` on an empty selection correctly returns `no slot focused`
(not `no active ui focus`); `q` cleanly exits. **Not yet verified**: a
real interactive terminal session (only `-no-tty`/`char-add` tested so
far) — that and re-signing everything are the next steps.

Also noted but out of scope for this task: `user-edit`'s own
console-invocation ergonomics (needing to type an exact subcommand word
like `start`, plus a target username with only a soft default) aren't
fully solved either — a separate, minor, deliberately-deferred item, not
a blocker on this work.

**First real-terminal test, same day** — a screen-clear fix
(`$colors{'clear_screen'}` before each render, `nshell`'s narrower
`\r\e[2K`-one-line-clear precedent was the wrong thing to copy for a
full-screen browser) confirmed the plumbing works end-to-end on a real
tty: a keypress genuinely triggers a routed call, a persisted state
change, and a fresh render. But per the user, directly: **"I don't
understand the UI at all... compared to user-edit, which behaves well
interactively... it will need a lot of work until anything productive
can be done with it."** Taken at face value, not argued away. Concrete
cause of the worst symptom (header vanishing after the first keypress):
`ui.cmd.ui-show`'s generic header-wrapping only wraps the *initial*
`ui-show` call — every subsequent action calls `cred-mesh.ui.interactive
.refresh` directly, a path never wrapped by that header logic, so the
header was never actually persistent to begin with. Pre-existing Phase 2
gap, not something this session touched. **What's real: correct
plumbing. What's missing: an actual designed interface** — persistent
orientation, on-screen key hints (`user-edit` has these), distinct
treatment for the common empty-selection state. That's interaction
design, not a bug fix, and is the explicit next session's work — ready to
commit this round's plumbing fixes as a checkpoint regardless.

#,,..,,,,,.,,,..,,.,.,..,,,.,,,.,,...,,,.,.,,,..,,...,...,.,.,.,,,,,.,...,..,,
#TWKEI6HWNDADVBH64NYWXTQ5FOGW5RNUBR5NQSZ5DWTL5V3GF2YTDJ5MCPA5OYSERPPYKIFLMYM3A
#\\\|ZYKYL7EBLDW5FI2J7LUS5VQV4BTHTXCKOCFHQUYZOW7F5CJVQH6 \ / AMOS7 \ YOURUM ::
#\[7]EOFLXDTOIF5GR4WHXHYTDMMDOUI72VST6R7F3M5J5XP66JIEOWAQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
