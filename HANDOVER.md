# Session Handover — 2026-09-06 (continued)

**Built the decided-on replacement for the reverted nshell-relay
attempt: a new console zenka, `vault-edit`. Full scaffold written,
syntax-checked against the same baseline as `user-edit`'s own working
files — but it has NEVER BEEN EXECUTED, not once.** No live terminal
test, no `Protocol-7 vault-edit commands` smoke test, nothing. Treat
everything below as "should work by careful analogy," not "works."

## What's here (previous entry's summary of the revert still applies —
see git history / `data/tasks/credential-fabric-ui-interactive.md` for
the full account of what was tried and killed before this)

New zenka `vault-edit` — a thin interactive terminal client to `cred-mesh`,
modeled on `user-edit`↔`users`:

- `cfg/zenki/vault-edit/zenka.v7` — auth as invoking unix user (subname
  `[vault-edit]`), no `[base.get_session_id]`,
  `[base.call.console_command:<system.args>]`, deliberately no top-level
  `[zenka.loop]` (same hybrid-console shape as `user-edit`).
- `src/vault-edit.init_code` — auth_name/subname setup, per-session state
  reset.
- `src/vault-edit.term_init` / `.term_restore` — near-verbatim
  `user-edit` clones (raw termios, hide cursor, `end_code` restore
  callback).
- `src/vault-edit.setup_stdin_watcher` — just the STDIN `event.add_io`
  registration (no local render-on-mutation watcher needed — there is no
  local render step, cred-mesh renders everything server-side).
- `src/vault-edit.console.show` — entry point: resolves `$cube_sid`,
  sends the initial `cred-mesh.ui-show [<view>]`, then
  `[init-done:TRUE]` + `[zenka.loop]`.
- `src/vault-edit.send_action` — builds and sends one routed
  `cred-mesh.<verb>` call, addressed via the same self-loopback
  `"$cube_sid.cred-mesh.<verb>"` form `user-edit.console.start` uses to
  reach `users` (NOT a bare `cred-mesh.<verb>` target — see the module's
  own header comment for why that distinction matters). Checks
  `send.local`'s return value and clears the busy flag with a visible
  error if cred-mesh is unreachable, rather than wedging silently.
- `src/vault-edit.handler.reply` — clears `<vault-edit.busy>`, prints the
  reply payload, arms `<vault-edit.pending>` on a prompt-frame header
  match (`[ grant access to ]` / `[ approve relay ]`), resumes decoding
  any keys buffered while the call was outstanding.
- `src/vault-edit.process_input_buffer` — the actual key table: `j`/`k`
  (also arrows) = nav, `r`/`x`/`g`/`a`/`?` = actions, `q`/Esc = quit;
  while a grant/approve prompt is open, ordinary characters are purely
  local text entry (no round trip) until Enter submits the whole line,
  Esc cancels locally with no round trip either.
- `src/vault-edit.handler.stdin_key` — drains STDIN into a buffer
  unconditionally (even while busy, so the fd empties and the watcher
  doesn't spin), then calls `process_input_buffer`.
- `src/vault-edit.quit` — terminal restore + `[base.exit]`.

**The actual race-fix, simpler than expected**: not a nested
`[zenka.loop]` per keystroke. `user-edit` only needs that once (its
bootstrap fetch) because its field editing afterward is entirely local.
Every `vault-edit` action needs a real round trip (cred-mesh owns all
state/rendering), so the fix is a plain `<vault-edit.busy>` flag —
`process_input_buffer` won't decode further keys while a call is
outstanding, `handler.reply` clears it and resumes. Safe specifically
because Perl's event loop is single-threaded (callbacks always run to
completion before the next fires), unlike nshell's cross-process flag
coordination which had nothing serializing it.

**Self-review before commit found two things**: fixed the real one
(`send_action` now checks `send.local`'s return so a dead cred-mesh
can't wedge the client forever); left one as a documented non-issue in
the task file (a prompt payload ending in something matching cred-mesh's
own `session_id=NNN` suffix pattern would get mis-parsed — far-fetched,
not worth guarding).

Full detail: `data/tasks/credential-fabric-ui-interactive.md`. Memory:
`data/ai-mem/claude/project-cred-mesh-console-ui-architecture.md`.

Signing status as of writing: **PLACEHOLDER signature blocks on every new
file** — not signed, not committed. Whoever holds the sourcecode signing
passphrase needs to run the sign tool over all eleven new files
(`cfg/zenki/vault-edit/zenka.v7` + ten `src/vault-edit.*`) before this can
be committed.

## Open Items — Not Started

1. **Run it, at all.** First test, cheapest first: `Protocol-7 vault-edit
   commands` (should print-and-exit — proves the start file's hybrid
   shape works before a real terminal is involved; if this hangs, the
   start file is wrong and nothing else matters). Only then `vault-edit
   show` (or bare `vault-edit`) at a real tty.
2. Everything from the prior entry in this same file that predates this
   session's work (older `data/tasks/` backlog sweep,
   `transport.init_code`'s missing zenka-name guard,
   `transport.handle.quic-hysteria:85`'s sprintf warning,
   `models.discover :clear:` alone untested) — still untouched, see
   `f36dbb66f`/`48e0dee44` if still relevant.
3. Phase 3 (cred-mesh's key-holder unlock dialog) — still correctly
   blocked on the fabric-secret encryption migration, unrelated to this
   session's work and not re-examined.

## Verified Live

Nothing from this session's `vault-edit` work — explicitly, deliberately,
repeatedly not yet run. The only thing live-verified this session (in the
earlier, reverted attempt) was `cred-mesh.ui-show` rendering through
nshell, which stays true regardless and is unaffected by any of this.
