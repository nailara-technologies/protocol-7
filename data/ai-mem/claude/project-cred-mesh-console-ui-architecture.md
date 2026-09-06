---
name: project-cred-mesh-console-ui-architecture
description: cred-mesh interactive-ui task (data/tasks/credential-fabric-ui-interactive.md) — nshell-relay approach tried 2026-09-06, reverted (race + security exposure); decided direction is a new, separate thin console zenka mirroring user-edit<->users, not yet named or built
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

**Still open, not yet decided**: the new zenka's name (candidates
discussed: `cred-mesh-console`, `cred-console`, `vault-console` — user's
call, not decided as of this session), its console-command entry-point
shape, and whether it needs `[base.get_session_id]` at all (likely not,
per `user-edit`'s own precedent of skipping it).

Also noted but out of scope for this task: `user-edit`'s own
console-invocation ergonomics (needing to type an exact subcommand word
like `start`, plus a target username with only a soft default) aren't
fully solved either — a separate, minor, deliberately-deferred item, not
a blocker on this work.

#,,,,,..,,,.,,,,.,.,.,,,,,,,,,,,.,.,,,,.,,.,.,..,,...,..,,.,.,,..,,,,,..,,.,.,
#JTPRKDEXW5QR2F2LK6WVRGAURMMDUHKZAWU3N2V3AZK2TWNHQDS4HMLBI2NRGHZYYJPRMVNQZVF3M
#\\\|4BUAIWZKZAS6ZQZ54Z2EPRRJMC4GJ3REXRZUFLQ4TH5B5WLTC4D \ / AMOS7 \ YOURUM ::
#\[7]QWPYNJVDFHMZWXLLDGKOAVKFWZXXHLZLWH42LCCTJ4W64V465CBA 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
