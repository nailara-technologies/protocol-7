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

**Committed as `62923a289`.** Per the user's own suggestion, then
compared directly against `user-edit` via its own `char-add` (see
[[topic-user-edit-console-zenka-status]]'s 2026-09-07 caution — its
char-add mutates LIVE data, briefly edited the real `taeki` record by
accident, caught and corrected, never submitted). That comparison turned
"needs a lot of work" into a concrete spec, not a vibe — persistent
client-owned title bar, labeled fixed layout, inline key hints next to
what they act on, a footer status line, collapsed multi-value previews,
and a reusable technique worth copying directly: `user-edit.form.render`
replaces its card's own closing border row with a one-shot discovery
hint (`ctrl-? : toggle cmd list`, hand-spaced to the border's dot-fill
rhythm) on the very first render only, gone after any keypress — no
extra line, no width reservation. Full list in the task file's own
"`user-edit` comparison" section — that's the next session's actual
starting point, not "make it nicer."

**Round one of that pass, same-day follow-up, 2026-09-07 — written and
syntax-checked (`ptd -c`), NOT YET LIVE-TESTED** [ cube refuses to start
non-root in this environment ]. Decided architecture: vault-edit owns an
outer wrapper (title bar / footer / key hints) around cred-mesh's raw
`data` string, rather than making cred-mesh frame-aware — forced by
confirming directly in `base.handler.command`'s SIZE-mode branch that
only `mode`+`data` survive the wire, so any structured metadata (view/
row/count) has to travel inside `data` itself. New `\x02VEFOCUS
view=%s row=%d count=%d\x03` trailer, appended by `cred-mesh.cmd.ui-show`
and `cred-mesh.ui.interactive.refresh` (the only two places that
actually finalize `$output` — every other interactive-* module funnels
through `refresh`) after their own colourisation, parsed and stripped by
`vault-edit.handler.reply`, rendered by new `vault-edit.render_chrome`.
Landed 4 of 5 spec items directly (persistent title bar, footer w/ `row N
of M` or `[ nothing selectable ]`, always-visible key hints, labeled
layout is inherited from cred-mesh's own render), adapted the 5th
(`user-edit`'s border-splice discovery-hint doesn't apply — nothing to
discover, vault-edit's hint is one always-visible line with no crowding
problem to solve), and separately fixed a 6th real gap the same
comparison surfaced in passing: `cred-mesh.ui.render.registry_detail`
was unconditionally joining the full subscriber list — now collapses to
`:..N.entries..:` past 4, matching the spec's own example syntax.

**A second-opinion pass caught two real defects in the interaction
dimension itself before this got called done** — both instructive
generally: (1) chrome ordering (title→body→footer→hints) put the new
hints line BELOW the grant/approve prompt frame, so
`vault-edit.dispatch_key`'s local character echo landed under the hints
line instead of next to the prompt — fixed by special-casing pending
mode to print title→instruction→body with nothing after, so the prompt
frame stays the last thing on screen exactly like before this session.
(2) the new always-visible hints line advertised `? detail`, which sets
`focus.view='slot'` via `select_view` — and nothing bound `select_view`
back to `overview`, `Esc` being bound to quit instead. Advertising a key
that was previously an unreachable-by-accident dead end turned it into a
reachable one. Fixed with one new binding, `'o' =>
'interactive-select-view overview'` (the command name was already
granted in `cfg/zenki/cred-mesh/zenka.v7`'s access list, just never
bound to a key). **General lesson: a hint line makes previously-obscure
key bindings reachable — auditing "does every advertised action have a
way back" is now part of writing one, not optional polish.**

Files this round: `src/cred-mesh.cmd.ui-show`, `src/cred-mesh.ui.
interactive.refresh`, `src/cred-mesh.ui.render.registry_detail`, `src/
vault-edit.handler.reply`, `src/vault-edit.dispatch_key`, `src/vault-
edit.init_code`, new `src/vault-edit.render_chrome`, regenerated `cfg/
zenki/vault-edit/subroutines.load-early`. No placeholder signature
stubs added [ per `AI-COLLABORATION-GUIDE.md` ] — needs `bin/Protocol-7
sourcecode update-signatures` over those paths, then a live pass
(`Protocol-7 vault-edit show -no-tty` + `char-add`) before this can be
called verified, not just reasoned-through. Full account: data/tasks/
credential-fabric-ui-interactive.md's "interaction-design pass, round
one" section.

#,,.,,..,,..,,...,.,,,,,,,..,,...,..,,...,,.,,..,,...,...,,,.,,.,,,,.,.,,,,.,,
#OEMJMAFC26VQQXKSFASA34CJOHED36UA42EPMF4H7UC25NI4Z6PIKBSKBQNWE4Y5UXH5ZKFCEVZY2
#\\\|FQHTMJ3UBSOEMYDHQTUZXEMGKAZJ25IN2YK6ROXAWJ6NLPQAMCX \ / AMOS7 \ YOURUM ::
#\[7]F6GAN5K3IYZN7J76O3TNCMLFSOQLD35W7UA5FFFS4UNV7JRY4AAY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
