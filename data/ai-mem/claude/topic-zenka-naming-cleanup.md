---
name: zenka-naming-cleanup
description: completed renames of non-conforming zenka names (underscore/dotted) to hyphenated convention
metadata: 
  node_type: memory
  type: project
  originSessionId: 1fae67f1-7fe7-41e7-9119-372afacccc2b
---

protocol-7 zenka names should be short hyphenated single-concept names
(`auto-hide`, `c-trade`, `lm-vision`, `pdf2html`) — never underscores or
dots (dots collide with `zenka.command` routing).

**completed (landed on `base`, pushed):**
- `credential_fabric` → `cred-mesh` (commit e420c9694, 2026-06-14/15).
  zenka dir, all modules, `%data`/`<...>` namespace paths, access.zenki
  entries all renamed. missing weather/jobsite/web-browser grants
  transferred from the now-dead per-zenka `access.zenki` into
  `cfg/zenki/cube/access.zenki`, then per-zenka file deleted.
  also: live `/var/protocol-7/credential_fabric/` data dir manually
  renamed to `/var/protocol-7/cred-mesh/` by user (sudo, outside repo).
- `window.place` → `window-place` (commit 9fd98f38e, 2026-06-15).
  module files keep dotted `window.place.*`/`window.gtk.*` namespace
  (same split as `pdf2html` zenka / `pdf.html.*` modules — only the
  zenka dir+config name needed the hyphen). also fixed startup hang,
  see [[gtk-ondemand-zenka-startup]].

**how to spot more candidates:** `ls -ld cfg/zenki/*_*` and
`ls cfg/zenki/` for dotted names; cross-check with
`v7.list zenki` / `v7.list available <prefix>` for routing collisions.

**how to apply:** when doing a rename like this, use `bin/ncode` —
add a target to `%targets` (`..,` suffix = recursive) for doc/task dirs,
then `ncode -ai-friendly -confirm replace <target> <old> <new>`. user
handles the src/cfg/module rename pass themselves typically.

#,,,.,..,,,..,,,.,,,,,,..,,,.,...,,,,,.,,,.,,,..,,...,...,.,.,,..,..,,,.,,,.,,
#UWJGJ63X5DO2V5MQDEQF7FEPJ3ITVDWCY73A4WWS6RVU2AGPOVBNTC2DJ7TDXSIJ3PL7YWQZVVILE
#\\\|4MADMJOUTSF4ST6IXEGLDG674CECNEPHTL7QUDDGVQOMAON5HWI \ / AMOS7 \ YOURUM ::
#\[7]WQH3WRBYO7F6NH2MBW5IC7NZRM5OVBKHMUJLOB5NIU7D7UCDEIBQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
