---
name: feedback-new-zenka-boot-checklist
description: "live-verified checklist for scaffolding a NEW zenka into the running system: cube auth.zenki grant + v7.reload are both required, and base.file.make_path-style subs are only callable during init (post-init deferred-compile sources are cleaned, calls resolve to undef) — create dirs in init_code with an owner param, not lazily in handlers"
metadata:
  type: feedback
---

Scaffolding a zenka (config + modules) is NOT enough for `v7.start_once`
to work. Two live-system gates, both hit and confirmed 2026-07-29 with
the forensics zenka (phase 1, task data/tasks/forensics-agent.md):

1. **cube auth grant** — without
   `auth.setup.usr.<zenka> = :zenka:` in
   `cfg/zenki/cube/auth.zenki` the zenka boots, then dies with
   exit code 0004 ("cannot to connect to local cube") in a limitless
   v7 restart loop (same failure as commit 2f11bc91c fixed for
   build/openvas). Fix: add the line, then `p7c reload` (unprefixed =
   cube; `p7c cube.reload` reports "client not present" — cube is the
   default route, the explicit `cube.` prefix does NOT resolve).
2. **v7 start set-up is cached** — a new zenka dir is invisible to
   `v7.start_once` ("zenka X not found in start set-up") until
   `p7c v7.reload` (reload config + p-mods rescans
   zenki/*/zenka-startup.v7). `p7c ondemand-zenka add <name>` registers
   at cube level but does NOT fix the v7 start set-up.

Third landmine, verified by live probe: **subs outside the eager
compile set resolve to undef post-init.** The zenka compiles the
whitelist eagerly (~325 of ~424 subs), then cleans deferred-compile
sources at init-done ("cleaning up referenced subroutine hash").
Calling e.g. `<[base.file.make_path]>` from a timer/command handler
after init dies with "undefined value as subroutine reference
[<module>:<line>]". The `file.*` alias form (`<[file.make_path]>`,
p7-log.init_code style) is the convention; dir creation that must
happen belongs in `<zenka>.init_code` with an explicit owner param
(`<[file.make_path]>->( $dir, 0750, <system.amos-zenka-user> )`) —
init runs as root before drop_privs, so without the owner param the
dir ends up root-owned (build.init_code documents the same hazard).

Useful live-verification commands: `p7c v7.list available|zenki`,
`p7c <zenka>.show-buffer zenka` (boot log incl. errors),
`p7c <zenka>.reload` (picks up module edits without restart, re-runs
init_code), `p7c v7.stop_implicit <zenka>` (clean stop),
`p7c events.list events` + `p7c events.trigger_event <id>` (manual
event-slot firing without waiting for the clock).

**How to apply:** any new-zenka task — after writing config + modules
and running gen-sub-whitelist, do: auth.zenki grant → `p7c reload` →
`p7c v7.reload` → `p7c v7.start_once <zenka>` → check
`show-buffer zenka` for early exit codes (0004 = cube auth/connect,
0110 = drop_privs when run unprivileged manually). Create needed dirs
in init_code, never lazily in post-init handlers.

#,,,,,,..,..,,...,..,,..,,.,.,..,,...,,,.,...,..,,...,...,,,,,,..,,.,,,.,,,,.,
#RUKWY4JNW5AFRT654Z7R5GC7TWJP3IYWTBDWVFOUR7ECUVATE6E4SK2UAINPJXLYT7224OR6RSSDW
#\\\|B4LBIRQ7L3EDZQVSZWPOVT6XS277ASEAMPO7PK3SVBOGJSNUGTF \ / AMOS7 \ YOURUM ::
#\[7]MVFBENQLJUURSU7PGSTLWPTLYSSWNFLURFVI5BVAGZICEK3ATSBI 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
