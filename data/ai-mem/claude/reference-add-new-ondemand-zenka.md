---
name: reference-add-new-ondemand-zenka
description: full procedure to make an on-demand zenka actually startable by v7 -- config/start alone is not enough, three more pieces are required, verified live getting opencv running
metadata:
  type: reference
---

Having `cfg/zenki/<name>/start` (with `start.on_demand = 1`) and
the zenka's own modules loaded is NOT sufficient for `v7.start <name>` to
work. Verified live end-to-end bringing up a real zenka (`opencv`, which
had `start` + `subroutines.load-early` but nothing else) — three more
pieces are required, each failing with a distinct, informative error if
missing:

1. **`cfg/zenki/<name>/start.cfg`** — the actual file
   `v7` reads to register the zenka for start-up at all. Missing →
   `. . not configured for v7 start-up . . required file
   'start.cfg' not present`. Copy from a sibling on-demand zenka
   (e.g. `povray`'s, which omits `stdio.multiplex` — used `calc`'s first,
   then `povray`'s on user correction as the closer template) and adjust
   `[base.zenki.set_ondemand_timeout:N]` to match the `idle_timeout` in
   the zenka's own `start` file.
2. **`v7.reload`** after adding the file above — `v7` caches its known-zenki
   list at its own init/load time; a newly-added `start.cfg` isn't
   picked up until reloaded. Without this: `v7.start <name>` →
   `zenka <name> not found in start set-up ..,` even though the file now
   exists on disk.
3. **`cfg/zenki/cube/auth.zenki`** — needs
   `auth.setup.usr.<name> = :zenka:` (copy the line for a sibling zenka,
   e.g. `povray`). Missing → the zenka process actually spawns and
   connects to the unix socket, then fails immediately: `[#]
   authentication protocol error` / `<< cannot to connect to local cube
   >>` / `terminating zenka start-up`. This is a distinct, later failure
   stage than #1/#2 — the zenka gets further before dying, which is the
   tell that this specific piece is what's missing.
4. **`cfg/zenki/cube/access.zenki`** — needs
   `access.cmd.usr.<name> = v7.register_child` (again, copy a sibling's
   line, e.g. `povray`'s). Grouped with #3 in practice — add both auth.zenki
   and access.zenki entries together, they're both cube-side registration.
5. **`reload config`** sent directly to `cube` (not `cube.reload` — that
   returned `client not present`; cube is the console itself, so per
   CLAUDE.md's "direct cube commands, no dots" convention, send `reload
   config` bare) — separate from `v7.reload` in step 2. auth.zenki/
   access.zenki live on `cube`, not `v7`, so cube needs its own reload
   before the new auth/access entries take effect.

**How to apply**: when standing up any new on-demand zenka that already
has a `start` file but has never actually been started, expect to need
all five pieces above, not just the ones needed for parsing --
`start.cfg` + `v7.reload` gets it to the point of actually
spawning and connecting, `auth.zenki` + `access.zenki` + cube's own
`reload config` gets past the connection handshake. Each missing piece
produces a different, specific error message — use the error stage to
tell which piece is still missing rather than guessing.

#,,.,,,,,,.,.,.,,,.,.,.,.,..,,...,,.,,,..,...,..,,...,...,...,,.,,,..,,,,,,,.,
#PBLGFAVFFR5KNUNAVNCUKH3O6OKIAIXINTBYR7377LG2NVDKGDRYQAYOODCHVRZDQRL6CCWOHU7SA
#\\\|QAB647PXVPOID6BJYAZQQQLVISUVHVX6GA5S4B5DLARVJCQGKHI \ / AMOS7 \ YOURUM ::
#\[7]7LOOJJYYWLBDPAEDMNWFCH6V6ORLMZ3ZNDQ4ZKPI5GWJEF53P4BI 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
