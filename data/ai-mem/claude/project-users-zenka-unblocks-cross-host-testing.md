---
name: users-zenka-unblocks-cross-host-testing
description: "why users zenka (5PN) was prioritized now — per user, it's the missing piece blocking real testing/adoption of the already-built cross-host stack (p-7-r, link-upgrade, ssh zenka, discover/orbital)"
metadata:
  type: project
---

**2026-08-10, per user.** The `users` zenka (todo 5PN, see
[[data/yaml/coding-tasks/users-zenka.yaml]]) wasn't prioritized in isolation —
it's what several already-built cross-host components (`bin/c_src/p-7-r.c`,
the Perl link-upgrade handshake, `ssh` zenka tunneling, `discover`/`orbital`
presence) have been waiting on: none of them had a real per-user identity/
record system to actually test or adopt against. Phase 1 (host-system/ CRUD,
shipped this session, commits df2e83d85/25a4bf1ab) gives that a concrete
target for the first time.

**How to apply:** phase 2 (`remote/`) isn't a from-scratch integration
project — it's the real-world exercise of transport infrastructure that
mostly already exists (see users-zenka.yaml's `discovery_integration`
section: `p-7-r` is a complete working auth-keypair+TOFU client;
link-upgrade's DH handshake is real and wire-compatible client/server, only
the post-handshake cipher-application step is an open TODO; `ssh` zenka is a
complete transparent tunnel; `nodes.cmd.add-tronk`/orbital connect is the one
genuinely unimplemented `[LLL]` stub). Don't treat phase 2 as "design a new
transport" — treat it as "wire users.remote.* onto the transport that's
already there, and that exercise IS the adoption test this was waiting for."

**UPDATE 2026-08-11: slice 1 landed exactly this way, and it WAS the
adoption test.** `users.cmd.remote-get`/`remote-fetch` (commit e4185e78b)
composes `plugin.auth.auth-keypair` + a new `auth.client.auth-keypair.
authenticate` (client-side, modeled on `auth.client.zenka.authenticate`)
+ `base.session.init`/`init_state` for event-driven dispatch — live-verified
via a loopback self-test. Doing so surfaced 8 real, previously-undocumented
bugs/gaps in shared framework code nobody had exercised this combination of
before (TOFU pin-key stability, a `crypt.C25519.key_vars` cache-hijack trap,
`plugin.auth.auth-keypair`'s distinct `AUTH_TRUE =)` wire format,
`protocol.protocol-7.auth.select-method` NOT being generically reusable
across auth methods, `base.session.init`'s session-name regex constraint,
the `protocol-7.command.send.local` non-prefixed alias requirement, a reply
handler's real single-hashref call signature, and a genuine self-deadlock
when a blocking-read client implementation loops back through the same
zenka process — recovered only via `v7.stop`/TERM+KILL, `v7.restart`
couldn't reach the stuck process). Full writeup in `users-zenka.yaml`'s
`transport_implementation_choice` section. Still open: `discover.orbital.
known` -> host:port resolution, `remote/{incoming,outgoing}` sync-cache
storage, link-upgrade encryption, command-level signing.

[[project-checksum-addressing-implementation-survey]]

#,,..,..,,,..,...,.,.,.,,,,,.,...,...,.,,,.,,,..,,...,...,..,,.,.,,.,,.,,,..,,
#55Y65AQC66O2QKUXNPYAVM5NX52XIWMPAMUQP5R7WYQ42ITCOIJE6FWIOUW6VVY6FXVJUURLNA5WY
#\\\|QOXO2ZWU4JW5ZJXG7Y2ZQR5U7JPPCWPET7ERBFUP6AO4E5JLHGH \ / AMOS7 \ YOURUM ::
#\[7]T5SJ7HQFAFZOBYBUOBTZU6H5N26Q2KFXSZ3QHBQBVPOQZVFDXKBY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
