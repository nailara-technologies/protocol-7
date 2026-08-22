---
name: project-plan-9-storage-9p-subsystem-status
description: "history and current live status of the storage/plan-9 9P (Plan 9 filesystem protocol) client+server subsystem -- FUSE-abandoned-for-WSL origin, SFTP-for-storage-appliance sibling, now a fully live-verified real-directory 9P server as of 2026-08-22"
metadata:
  type: project
---

## why this subsystem exists

`storage`'s original design intent was a **protocol-7-powered storage
appliance** [network] concept — giving Windows/other clients real
filesystem access to data served by a P7 zenka. That began as a real
FUSE mount attempt (`Fuse2`), which stalled when `Fuse2` became
uncompilable on the target hosts; the fallback that followed was
`Filesys::Fuse3` as the dependency, plus a `::`→`__` module-name-marker
rename specifically so the codebase could be checked out cleanly on
Windows filesystems (which reject `::` in some contexts) — this rename
detail is why some AMOS7-lib paths look unusual if you go looking.

**The appliance idea itself got parked** — waiting on more
dependencies to land (see `appliances/` in the repo tree) — but two
concrete protocol implementations survived independently as
`storage`'s two sibling client-facing subsystems:
- **SFTP** — added first, as the practical near-term way to give
  Windows clients file access without needing a real FUSE mount.
  Confirmed still legitimate and intentional (not a duplicate-process
  bug) when two socket paths were seen logging simultaneously during
  this session's work — SFTP and the 9P work run side by side by
  design, not by accident.
- **9P2000 (Plan 9 filesystem protocol)** — the FUSE replacement path:
  since the appliance never needed to be a literal mounted filesystem
  on the SERVING side, `storage`/`plan-9` implements 9P as a real
  client+server protocol pair instead of a kernel-level FUSE mount.
  This is what this session's work brought from "written 2026-03-27,
  never actually worked" to fully live, byte-verified functionality.

## state as of 2026-08-22 (end of this session's work)

Fully live-verified end to end: a real `plan-9` server zenka
(v7-managed, cube-authenticated, modeled directly on `storage`'s own
`zenka.v7`/`start.cfg` shape) serving both fake in-memory vterm-style
buffers AND real, arbitrary local directories over the actual 9P2000
wire protocol, read to by a real `storage.9p.*` client side, through
cube routing, with directory listings and file reads byte-correct.

Every layer of this was broken before this session and is now fixed —
see [[feedback-use-constant-vs-data-tree-const]] (root cause: constants
never actually shared across modules), the `bug-forensics-dotted-
command-names` addendum (cube command-name leading-digit rejection,
`9p-connect`→`plan9-connect` rename), and
`data/tasks/completed/plan-9-server-event-loop-wiring.md` (the event
loop was bound but never registered with `event.add_io`, socket-vs-fd
passing to `base.net.send_to_socket`, `File::stat` shadowing on the
new real-directory export code — see [[feedback-file-stat-shadowing]]).

**Read-only, single real-path export granularity right now**:
`plan-9.cmd.export-directory <path> <name>` registers one directory at
a time into the server's buffer registry; no recursive auto-export,
no write support yet (`plan-9.server.realpath-read` only implements
reads). Test harnesses used during live verification were rescued
from `/tmp/p7-9p-test/` into `bin/test-scripts/9p-live-test/` (would
not have survived a reboot otherwise) — that directory's own
`README.md` explains each script.

## how to use this if picking the subsystem back up

- Client-side entry points: `storage.9p.*` (connect/mount/umount/
  walk/stat/readdir/scan), routed through cube as `storage.<name>`
  (the `.9p.` segment, like `.cmd.`, is stripped by cube's own
  convention — don't include it when typing a live command).
- Server-side entry points: `plan-9.cmd.export-directory`/
  `plan-9.cmd.export-buffer` (also cube-routed as `plan-9.export-*`),
  backed by `plan-9.server.*`.
- If extending write support or recursive export, re-read
  `data/md/design/STORAGE-9P.md` and `STORAGE-MAPPING-PLUGINS.md`
  first (both were updated this session for the rename, so should be
  current) — and re-verify the double-size-prefix stat-record quirk
  (`storage.9p.stat`'s buffer INCLUDES the entry's own leading size[2]
  field, `storage.9p.readdir`'s EXCLUDES it) before touching either.

#,,,,,,..,,,,,,,,,.,,,,..,,,.,.,,,...,.,.,.,,,..,,...,...,...,,..,.,,,,.,,,,.,
#7QBAL2SEW2GTIK3IQJT2YST575W3LR53VPGPB5NBUSKLSKO34C6VAETIVC26INSL4B3KYMVH64SRY
#\\\|HZSCUZ5ART4XSFNNUC6RXDN76VSVE55SPRPAEZ425CX6L3DVYC3 \ / AMOS7 \ YOURUM ::
#\[7]S5CVEP3E3V34XHZQJ5ICAYOHTQQ6HUZO5IEWGXKSIMO4UUHJFICQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
