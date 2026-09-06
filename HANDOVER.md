# Session Handover — 2026-09-06

**No code shipped this session — an architecture decision landed instead,
after a wrong attempt was caught live, built out further, and cleanly
reverted.** Working tree carries only `data/tasks/credential-fabric-ui-
interactive.md` (uncommitted, needs signing) and the two `data/ai-mem/
claude/*.md` files below.

## What happened, in order

1. Read `data/tasks/credential-fabric-ui-interactive.md`. Found it stale
   (predates the `credential_fabric`→`cred-mesh` rename) and found that
   its phase 1+2 scope (read-only views, selection state, slot actions —
   rotate/revoke/grant/approve) was **already implemented** in
   `src/cred-mesh.ui.interactive.*` and the render layer. Phase 3
   (key-holder unlock dialog) is correctly blocked: the fabric-secret
   encryption migration it assumes hasn't landed (`key_holder.child`
   still writes the secret with the `U:` unencrypted prefix
   unconditionally).

2. What was actually missing: nshell had the `cred-mesh_ui_active`/
   `cred-mesh_ui_pending` flags stubbed in `nshell.shell_loop` but nothing
   ever read them — no real single-key (`j/k/r/x/g/a/?/q`) dispatch
   existed. Built it: a new branch in `nshell.read_from_buffer` (mirroring
   the existing `search_mode`/history-mode key interception) plus a
   prompt-mode handoff via `nshell.handler.command_reply` matching a
   returned ascii-frame's header text. Committed locally as `7af528e8c`.

3. **Live-tested by the user, immediately** — this is the part worth
   internalizing: two real bugs surfaced only by actually running it
   (`cred-mesh.ui.show` vs the registered `cred-mesh.ui-show`; then the
   deeper one, wire command names being the hyphenated `<base.cmd>`
   aliases in `cred-mesh.init_code`, not the dotted internal module
   names). Both got fixed. `cred-mesh.ui-show` then rendered correctly
   through nshell.

4. **The user then correctly killed the whole design direction**, not
   just those two bugs: nshell and cred-mesh are separate OS processes
   connected only through cube's async command/reply routing. The
   prompt-mode handoff has a genuine, client-side-unfixable race (an
   async reply arms a flag on its own timing while the keystroke loop
   fires independently on STDIN), and routing grant/approve payloads as
   plain cube command arguments exposes them to `p7-log`/
   terminal-history — a real security regression for a credential
   feature, not a style complaint. Full reasoning + comparison against
   `user-edit` (which owns its own terminal and never routes keystrokes)
   is in the task file and in
   `data/ai-mem/claude/feedback-check-console-zenka-precedent-before-
   cross-zenka-keystroke-relay.md`.

5. Cleanly reverted — `7af528e8c` was local-only (`hub/base` never had
   it), so `git reset --soft f6a59105a` + `git restore --source=
   f6a59105a` fully backed out all three nshell files and the
   version-bump churn from signing, no trace left, nothing force-pushed.

6. Worked out the correct direction with the user, confirmed with a
   second-opinion advisor pass: **a new, separate, thin console zenka**,
   modeled exactly on `user-edit`↔`users` — own terminal (`term_init`/
   `setup_stdin_watcher`/`handler.stdin_key`), auth as the invoking unix
   user, and route data operations (`interactive-*`, `resolve`,
   `rotate`, etc.) to the real `cred-mesh` by name over cube. Cred-mesh's
   existing headless `zenka.v7` (privilege-drop, `get_session_id`,
   `zenka.loop`) stays untouched — this is additive, not a rewrite of the
   background service. The load-bearing detail: `user-edit.console.
   start`'s HYBRID LOOP MODE (send one routed command, then block for
   *that specific* reply before reading the next key) is what actually
   removes the race — not "own the terminal" alone.

   A same-name dual-mode option (branching inside cred-mesh's own
   `zenka.v7`) was considered and dropped: the user pointed out outbound
   routing already has selection modes (e.g. oldest-first) and replies
   route back numerically by sid/cmd_id, so the console zenka needs no
   inbound addressability under the `cred-mesh` name — removing the
   concern that made same-name reuse look necessary.

Full writeup, including exact code excerpts of the reverted attempt (for
reference, not to resurrect) and the decided direction: `data/tasks/
credential-fabric-ui-interactive.md`. Memory: `data/ai-mem/claude/
project-cred-mesh-console-ui-architecture.md` (state/decision) and
`feedback-check-console-zenka-precedent-before-cross-zenka-keystroke-
relay.md` (the general lesson).

## Open Items — Not Started

1. **The new console zenka itself** — nothing built yet. Still open: its
   name (candidates floated: `cred-mesh-console`, `cred-console`,
   `vault-console` — user's call), its console-command entry-point shape
   mirroring `user-edit.console.start`, and whether it needs
   `[base.get_session_id]` at all (likely not, per `user-edit`'s own
   precedent).
2. **Phase 3 (key-holder unlock dialog)** — still correctly blocked on
   the fabric-secret encryption migration, which is its own separate,
   not-yet-scoped task. Don't build the unlock dialog before confirming
   that migration exists.
3. **The task file itself** is uncommitted and needs re-signing before a
   commit — do that first thing next session if nothing else has touched
   it.
4. Everything in the previous handover's still-open items (older
   `data/tasks/` backlog sweep, `transport.init_code`'s missing
   zenka-name guard, `transport.handle.quic-hysteria:85`'s sprintf
   warning, `models.discover :clear:` alone untested) was not touched
   this session — see `f36dbb66f`/`48e0dee44` if still relevant.

## Verified Live

`cred-mesh.ui-show` rendering through nshell (both before and after the
command-name fixes) — the one part of this session's exploration that
does work and stays as-is. Everything else (the single-key dispatch, the
prompt-mode handoff) was live-tested, found broken at the architecture
level, and reverted rather than kept — see above.

No commits this session as of writing; the reverted commit (`7af528e8c`)
never left local `base` and no longer exists on any branch tip.
