---
name: access-grant-scope
description: per-zenka access.zenki entries for the taeki/admin user are redundant — only cube/access.zenki (cross-zenka) and <zenka>/start (enabling commands/modules) are needed
metadata: 
  node_type: memory
  type: feedback
  originSessionId: 1fae67f1-7fe7-41e7-9119-372afacccc2b
---

When a command is denied to the `taeki`/admin user, do NOT add a
per-zenka `access.zenki` grant for that user — `taeki` already has full
wildcard access at the cube level.

**Why:** user corrected a kimi-added
`access.cmd.usr.unix-taeki = eval-code exec-sub` entry in
`configuration/zenki/transport/access.zenki` as redundant
(2026-06-15, transport.eval-code/F16 fix).

**How to apply:** for "no perm" fixes, only two things are normally
required:
1. `<zenka>/start` — add the module group (e.g. `devmod`) to
   `modules.load` so the command compiles/loads at all.
2. The zenka's `subroutine.white-list` — add the specific
   `devmod.cmd.eval-code` / `devmod.cmd.exec-sub` etc. entries so the
   command is callable.

`configuration/zenki/cube/access.zenki` is only needed for *cross-zenka*
access (one zenka calling another's command), per
[[feedback-buffer-access-control]]. Per-zenka `access.zenki` user grants
are for non-admin users; don't add them for `taeki`.

#,,..,..,,.,,,.,.,.,.,..,,,,.,..,,,,,,...,.,,,..,,...,...,...,,.,,,,,,,,.,.,.,
#5PNLUTT4U2XPJQL43ZYJ4RF24FBZI35PR2LUDPOC5L7NNFC3ZL4RWFAFBO6BYIXXF53EDZB4SMXEM
#\\\|KX7EVDOS5YM55DGPXM5XL6ME3QZI2TYQTEDSILDQ7JSAGAT2HZ5 \ / AMOS7 \ YOURUM ::
#\[7]5ST5C52OEQXPRGARAPVNC6RVG63N5NFJVEYQO5K5GMGHXMCEJSAI 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
