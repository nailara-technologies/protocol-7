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

[[project-checksum-addressing-implementation-survey]]

#,,..,,,.,..,,,.,,,.,,.,,,,,.,.,.,..,,,,.,..,,..,,...,..,,..,,...,...,...,.,,,
#VSSLUCYOSJGARX3XRXLHIPKFSCYM4EF542CDZ3CS7YGIJCFNV4OYME4YZEBBBJ6PJBM27MZV2BYUK
#\\\|6BUU2HMX34UP4DGXRGTGEZMGDBBELUDMN3Q4I7CRY2AOPRJTXTL \ / AMOS7 \ YOURUM ::
#\[7]H5ZYVKQT6EGLSSX4ECG66FJ5BJ5AP2MSO7GMHTRARKVEHOBFEUDI 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
