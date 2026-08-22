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

Test harnesses used during live verification were rescued from
`/tmp/p7-9p-test/` into `bin/test-scripts/9p-live-test/` (would not
have survived a reboot otherwise) — that directory's own `README.md`
explains each script.

## update 2026-08-22 (same day, second round): write support landed

`plan-9.cmd.export-directory <path> <name> [:rw:] [:symlinks:
reject|contained|allow]` — both flags default to the safe/restrictive
option (read-only, `reject`). `handle_walk` enforces the symlink
policy at walk time (checked with `-l`, never following an untrusted
link) and propagates `writable`/`root`/`symlink_policy` through every
level of a nested walk; `handle-io-open`/`handle-io-write` gained
`OTRUNC` handling and a real write-mode gate (fixed a latent bug where
`OEXEC` was incorrectly treated as writable — `& 0x03 == 0` isn't the
right check when `OEXEC == 3`).

`storage.9p.*` had **no file-content read/write at all** before this
round — only directory listing/stat (`storage.9p.open` existed but
nothing called `Tread`/`Twrite`). Added `storage.9p.read`/`.write`
(low-level) and `.read-file`/`.write-file` (high-level: walk+open+
read-loop-or-write+clunk) plus `storage.cmd.plan9-read-file`/
`plan9-write-file`. No `Tcreate`/`Tremove`/`Twstat` — writes only
replace bytes of a file that already exists.

Also fixed a real, independently-hit bug: `storage.cmd.plan9-connect`
defaulted to port 5640, but the server's actual default
(`plan-9.config`) is 15640 — silent "connection refused" for anyone
omitting the port. Client and server config defaults drifting apart
like this is a class worth checking for elsewhere in the codebase
whenever a client/server pair has its config split across two files.

Recursive descent (multi-level `Twalk`, `storage.9p.scan`'s recursive
client walker) turned out to already be fully implemented from before
real-directory export existed — this round was the first time it was
exercised against a real one. Live-verified with a 3-level nested test
tree containing both a contained symlink and one escaping the export
root, confirming all three symlink policies behave correctly and
recursion/byte-content is correct at every level.

Landed as `f36ccfd7b`.

## how to use this if picking the subsystem back up

- Client-side entry points: `storage.9p.*` (connect/scan/read-file/
  write-file/mount/umount/walk/stat/readdir), routed through cube as
  `storage.<name>` (the `.9p.`/`.cmd.` segment is stripped by cube's
  own convention — don't include it when typing a live command).
- Server-side entry points: `plan-9.cmd.export-directory`/
  `plan-9.cmd.export-buffer` (also cube-routed as `plan-9.export-*`),
  backed by `plan-9.server.*`.
- Still open, not started: `Tcreate`/`Tremove`/`Twstat` (create/
  delete/rename over 9P) — deliberately out of scope so far, a
  separate and larger increment if ever needed.
- If extending further, re-read `data/md/design/STORAGE-9P.md` (now
  documents the write commands, the symlink-policy flag, and the
  server/client module tables) and `STORAGE-MAPPING-PLUGINS.md` first
  — and re-verify the double-size-prefix stat-record quirk
  (`storage.9p.stat`'s buffer INCLUDES the entry's own leading size[2]
  field, `storage.9p.readdir`'s EXCLUDES it) before touching either.

#,,.,,,,,,.,,,,,,,,,.,.,,,.,,,,..,,,.,,.,,,,,,..,,...,..,,,,,,...,,.,,,..,..,,
#K25H7KGAZB567T4RIZYXXCF73D3K4WRYNJNHPTXO6ORWUYIZJFV7UUI2SF2WHFUPMOHL2VSSX433S
#\\\|UMISMC5EMDHSTCHTY7OI3V7IQQPNMCS6QXYDJ3THEOV7SHEQUPH \ / AMOS7 \ YOURUM ::
#\[7]YTHVF5JLQYLSAUGU2NJOEG3C3D6SFK6CVVJCTI75YKNEVURI5CAI 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
