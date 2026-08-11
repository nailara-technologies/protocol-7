---
name: bug-auth-keypair-client-composition-gotchas
description: eight real, previously-undocumented bugs/traps found composing a native-Perl auth-keypair client (connect + auth + event-driven command dispatch) for users.cmd.remote-fetch -- each one silent or misleadingly-generic, worth checking before anyone else builds a client against plugin.auth.auth-keypair or base.session.init
metadata:
  type: reference
  originSessionId: bb701c28-fcf8-43e8-aab4-bbd5dfd0b711
  modified: 2026-08-11
---

Found landing `users.cmd.remote-get`/`remote-fetch` (commit e4185e78b,
see [[project-users-zenka-unblocks-cross-host-testing]]). Nobody had
composed these exact primitives together before (client-side auth-keypair
+ event-driven post-auth session), so all eight were genuinely dormant.

1. **TOFU pin-key stability.** `plugin.auth.auth-keypair.
   validate-incoming-tofu` pins the CLIENT's session pubkey on first
   contact (`incoming/<user>.public`) and only reaches `authorized` once
   a symlink exists at `authorized/<zenka>/<user>.public` — checked via
   `-l`/`-f` only, content isn't compared there (a SEPARATE mechanism,
   `load-authorized-users`, reads the same path for the actual master
   pubkey). A client that regenerates its session keypair every call can
   never reach `authorized` — each connection re-pins a different key
   forever. The identity must be a stable, disk-persisted key
   (`crypt.C25519.key_exists` + `load_keypair` if present, else
   `gen_keys` + `write_keys`), never regenerated per call.

2. **`crypt.C25519.key_vars` cache hijack.** Calling `key_vars($name)`
   for a name that ISN'T the process's real base key, when it's the
   FIRST `key_vars()` call in the process and that name's key files
   already exist on disk, silently sets `<crypt.C25519.base_key_name>`
   to that name permanently (`crypt.C25519.key_vars:29-33`). A later
   unqualified `sign_data(\$msg)` then signs with the WRONG key, no
   error. Always pass the real base key name explicitly as `sign_data`'s
   second arg once any other named key has touched the process.

3. **`plugin.auth.auth-keypair`'s success line is literally `AUTH_TRUE
   =)`** — a distinct wire format from the generic .cmd.
   TRUE/FALSE/SIZE/CHRSIZE reply grammar used for actual routed
   commands. `auth.client.zenka.process_auth_reply` already checks this
   exact string and is genuinely reusable despite its zenka-only-looking
   namespace.

4. **`protocol.protocol-7.auth.select-method` is NOT generically
   reusable across auth methods.** It hard-requires the reply be
   literally `'TRUE continue'` — correct for `zenka`, wrong for
   `auth-keypair`, whose server side (`auth.auth_select:30`) replies
   `TRUE <server_pubkey_b32>` instead (doubles as TOFU material). Had
   to inline the select-method exchange per-method rather than reuse
   this helper.

5. **`base.session.init`'s `$name` param must satisfy `base.regex`'s
   `usr_str_re`** (alnum/hyphen/underscore only, max 32 chars) or it
   silently returns `undef` with no other symptom — a label like
   `"remote-fetch:<host>:<port>"` (colons, dots) fails outright.

6. **`base.protocol-7.command.send.local` must be called via its
   non-prefixed swap-family alias**, `<[protocol-7.command.send.local]>`,
   not `<[base.protocol-7.command.send.local]>` — matches
   `base.protocol-7.route-send`'s own internal call site. Same family of
   footgun as [[feedback-base-prefix-stripped]].

7. **A registered reply handler's real call signature** (confirmed
   against `base.handler.command.process_reply`, NOT what
   `discover.orbital.handler.local_p7ref_reply`'s single-`shift` shape
   suggested) is ONE hashref: `{ sid, cmd, call_args, params, data? }`.
   `cmd` is the wire-level mode keyword (TRUE/FALSE/SIZE/...); SIZE mode
   carries its payload in a top-level `data` key, TRUE/FALSE carry
   theirs in `call_args->{'args'}` instead.

8. **The real deadlock.** An earlier version did the ENTIRE post-auth
   command/reply via manual blocking socket reads. Self-testing via
   loopback (this host's `users` zenka authenticating to its own host's
   `cube`, then asking cube to route `users.remote-get` back to
   `users`) deadlocked the whole zenka: cube routed the command to
   `users`' own pre-existing link session, which couldn't be serviced
   because the SAME single-threaded process was already blocked waiting
   on its own reply. `v7.restart` could not recover it either — the
   stuck process couldn't process its own restart command while
   blocked. Recovered only via `v7.stop` (TERM then KILL). A racing
   `v7.start` during the hang also produced two live instances at once
   — `max_concurrency` wasn't set (see `image2html`/`window-place` for
   the precedent). Fixed at the root: `base.session.init` +
   `base.session.init_state($id, 1)` hands the post-auth connection to
   the SAME event-driven command-dispatch machinery every regular
   session already uses, so the event loop is never blocked waiting on
   itself.

**How to apply:** before writing ANY new client against
`plugin.auth.auth-keypair`, `base.session.init`, or
`base.protocol-7.command.send.local`, re-check this list first — several
of these (1, 2, 5, 7) fail SILENTLY (wrong reply, `undef` return, no
error) rather than throwing, so they're easy to reintroduce without
noticing. Full detail and file:line references live in
`data/yaml/coding-tasks/users-zenka.yaml`'s `transport_implementation_choice`
section.

[[project-users-zenka-unblocks-cross-host-testing]]

#,,.,,.,.,.,.,...,.,.,...,.,.,,,.,.,,,,,.,,.,,..,,...,...,..,,,,.,..,,..,,,..,
#LQ3QDQJPXPD3KQRLM5WMG2ZOEXUJICHPHAN6P75WF2K5XCW2JLVVTFV7GBFAXHCAQNYMXEBUDGISY
#\\\|F4PGHDZSUGFZ3XNVG2I5CWN7TDZMMO464YLBTWCYMG5OJD4RJFH \ / AMOS7 \ YOURUM ::
#\[7]UQ3EKPNZOTE7T3UUROBVECSWHALDEQBAZZYARHOWZ32KARMOOUCY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
