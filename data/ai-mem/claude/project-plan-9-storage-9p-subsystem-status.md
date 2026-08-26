---
name: project-plan-9-storage-9p-subsystem-status
description: "history and current live status of the storage/plan-9 9P (Plan 9 filesystem protocol) client+server subsystem -- FUSE-abandoned-for-WSL origin, SFTP-for-storage-appliance sibling; full 9P message set (create/remove/write/wstat) live-verified as of 2026-08-22"
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

## update 2026-08-22 (third round, same day): Tcreate/Tremove landed via kimi k2.7

Dispatched to kimi k2.7 as a narrow, precedent-pointed task (per
[[feedback-narrow-scoped-kimi-task-file-pattern]]'s shape), then
independently live-verified myself rather than trusting kimi's own
report — same split used all session.

`plan-9.server.handle-io-create`/`.handle-io-remove` implement
Tcreate/Rcreate and Tremove/Rremove, wired into `handle_request`; both
gate on the same `writable` flag as write support, `Tremove` refuses to
delete an export's own root directory, and a non-empty directory
correctly fails to `rmdir` rather than being recursively deleted.
Client side gained `storage.9p.create`/`.remove` (low-level) and
`.create-file`/`.remove-path` (high-level) plus
`storage.cmd.plan9-create`/`plan9-remove`.

**Real bug caught in review, not by kimi's own report**: all 8 new
files had a malformed signature footer — kimi merged the
`PLACEHOLDER_FOR_AMOS7_SIGNATURE_LINE_*` marker text INTO the
structural signature-block skeleton lines (`#\\\|...`/`#\[7]...`)
instead of using the clean, simple 4-line placeholder form every other
file in this codebase uses before signing. Confirmed by diffing
against this session's own already-signed files — the real signer
fully replaces a clean 4-line placeholder with fresh content, so a
malformed skeleton risked the signer failing to recognize/replace it
(or producing the known double-footer bug, see
`bug-signature-endline-restoration.md`). Fixed by stripping the
malformed block and replacing it with the plain 4-line form in all 8
files before signing.

`Twstat` (rename/chmod) remains explicitly out of scope — needs a new
`decode-stat` codec module (none exists) plus 9P's "don't-touch
sentinel" field semantics, a separate future increment.

Live-verified: file create with content (byte-matched against the
real filesystem), directory create, file remove, directory remove,
export-root removal rejected, duplicate-create rejected, read-only
export rejects both create and remove, non-empty directory removal
fails cleanly with no recursive delete.

## update 2026-08-22 (fourth round, same day): port-default audit + config fix

User asked for a quick audit of the same bug class that produced the
`storage.cmd.plan9-connect` port-default drift (see the second round
above): every OTHER 9P client/server default-port site, checked by
grepping for `5640`/`15640` across the whole tree. Found real drift in
6 more files (`storage.9p.connect`, `storage.9p.mount`,
`plan-9.client`, `amos-term.cmd.mount-9p`/`mount-9p-client`,
`plugin.storage.p7ref.index`/`.resolve`), all fixed.

**Found something bigger while auditing**: `plan-9.client` (used by
`amos-term.cmd.mount-9p-client`) had `$data{'plan-9'}{'client'} = {};`
as its very first line — an unconditional wipe of the ENTIRE client
connection registry on every single connect call, so a second connect
silently discarded the first connection's registry entry (the socket
itself leaked, unreachable by name). Fixed with `//=`. Also found,
while starting `amos-term` for the first time this session to
live-verify: (1) `amos-term`'s `post_init` crashed outright —
`Linux::Inotify2` was never autoloaded (missing the
`<[base.perlmod.autoload]>->('Linux::Inotify2')` call every sibling
zenka using inotify has in its own `.init_code`), fixed; (2) a real
logic bug in `amos-term.handler.interaction-timeout` — `qw| A B C D |
. ' ' . qw| E F G H |` evaluates each `qw//` list in SCALAR context via
comma-operator semantics, silently keeping only the LAST word of each
list and discarding the rest (the "useless use of a constant"
warnings were the tell) — the timeout-reply message was actually just
"degrade] assumption" instead of the full intended sentence, fixed by
using a plain string; (3) a cosmetic `my $reply` shadow warning in
`amos-term.cmd.interaction-reply` (confirmed harmless — framework-level
lexical shadow, doesn't reproduce under standalone `ptd -c` — renamed
to `$reply_text` anyway to silence the noise). None of these three were
related to the port audit; all surfaced purely because `amos-term`
hadn't been started in a long time and nobody had seen its startup log.

**The real fix, following the user's own design ask**: rather than
just re-syncing every hardcoded literal to `15640` (which is exactly
what drifted before), added `plan-9.default_port = 15640` to
`cfg/shared-params` as the single source of truth, genuinely
per-zenka overridable (any zenka can add its own
`plan-9.default_port = <value>` in its own `zenka.v7` after loading
shared-params — same pattern `system.zenka.verbosity.*` already uses).
Every port-default site now reads `<plan-9.default_port> // 15640`.

**A second dead-config discovery along the way**: `src/plan-9.config`
(the ORIGINAL attempt at a single source of truth for these defaults)
turned out to have never actually worked — every reader used
`<plan-9.config.port>` (data-tree syntax), which only resolves values
populated via `.pre_init` constants or plain config-file `key=value`
parsing, never a bare `return {...}` module. Proved this empirically:
changed the file's port value, restarted, confirmed zero effect on
the real listen port, then reverted the test and deleted the file
(also had to drop the now-nonexistent `plan-9.config` token from
`plan-9`'s own `modules.load`, since it was named there explicitly,
not swept in via a namespace token). See
[[feedback-use-constant-vs-data-tree-const]] for the closely related,
first instance of this same "config that looks wired but isn't" class
found earlier the same day.

The whole chain — server listen port AND every client's own default —
was live-verified by changing `plan-9.default_port` to a distinctive
test value (15642), restarting, confirming both server and clients
moved together, confirming the OLD hardcoded port no longer worked at
all, then reverting.

## update 2026-08-22 (fifth round, same day): amos-term's missing .cmd. wrappers

User caught a sharper diagnosis than my own memory note from the
fourth round: `amos-term.cmd.mount-9p-client`'s follow-up commands
weren't just misnamed (dots violating `cmd_re`) — there was no
`.cmd.`-prefixed wrapper file for them AT ALL
(`ls src/*.cmd.*list-dir` → nothing). Added
`amos-term.cmd.list-dir`/`amos-term.cmd.read-file` (mirroring
`storage.cmd.plan9-read-file`'s shape, calling the already-correct
`plan-9.client.list-dir`/`.read-file` subs), fixed `mount-9p-client`'s
help text to the real command names, granted both plus the
already-existing-but-ungranted `mount-9p-client` in `amos-term`'s
`access.cmd.usr.cube`. Live-verified: connect → list-dir → read-file
round-trips correctly. See
[[bug-forensics-dotted-command-names]]'s correction for the general
lesson (check for a missing `.cmd.` wrapper before reaching for a
naming/regex diagnosis).

## update 2026-08-22 (sixth round, same day): Twstat landed (rename + resize)

After a clean audit for other instances of the "config that looks
wired but isn't" class (`base.parser.config` is genuine parser
machinery, not the same bug; every other candidate plain-return-hash
module either has real `<[name]>->()` call sites or is orphaned dead
code, a different and lower-priority issue, left untouched), moved on
to the one remaining deferred 9P feature.

New `plan-9.protocol.codec.decode-stat` (mirrors `encode-stat`'s exact
byte layout, name field starts at offset 41 — same `2+4+13+4+4+4+8=39`
math as the readdir/list-dir fix, +2 for the leading size field this
buffer still carries) and a SEPARATE `encode-wstat` (not a reuse of
`encode-stat` — wstat's omitted-field semantics are the opposite of a
directory listing's: omitted must mean "don't touch", not "here's a
friendly default", so every field defaults to its own 9P sentinel).
`plan-9.server.handle-io-wstat` honors only `name` (rename) and
`length` (resize/truncate) — mode/atime/mtime/uid/gid/muid are
silently ignored, this virtual filesystem doesn't model real
ownership/permission bits. Rename migrates the stable qid mapping to
the new path (file keeps its identity across rename, matching real 9P
semantics), rejects renaming an export's own root, and rejects an
already-existing target name. Client side gained `storage.9p.wstat`
(low-level) and `.rename-path`/`.resize-path` (high-level) plus
`storage.cmd.plan9-rename`/`plan9-resize`.

**Caught a real bug myself, missed by `ptd -c` entirely**: the natural
"max uint64" sentinel written as a literal `0xFFFFFFFFFFFFFFFF`
triggers Perl's "Hexadecimal number > 0xffffffff non-portable"
warning — `ptd -c` reported clean "syntax ok" regardless (it only
catches fatal errors, not warnings), only visible via
`plan-9.show-buffer compile-errors` after an actual zenka restart. The
user caught this from their own terminal ("startup errors") before I
did. Fixed by using `~0` instead of the literal (also more portable,
matches the build's native word size). See
[[feedback-ptd-syntax-check]]'s addendum for the general lesson.

Live-verified: rename (byte content + identity preserved), rename to
an already-existing name rejected, renaming an export root rejected,
rename against a read-only export rejected, resize/truncate (byte-exact
against the real filesystem), resizing a directory rejected.

## how to use this if picking the subsystem back up

- Client-side entry points: `storage.9p.*` (connect/scan/read-file/
  write-file/create-file/remove-path/rename-path/resize-path/mount/
  umount/walk/stat/readdir), routed through cube as `storage.<name>`
  (the `.9p.`/`.cmd.` segment is stripped by cube's own convention —
  don't include it when typing a live command). `amos-term.cmd.
  mount-9p-client` is a SEPARATE, parallel client entry point (via
  `plan-9.client.*`, not `storage.9p.*`), with its own cube-routable
  follow-ups `amos-term.list-dir`/`amos-term.read-file` — these didn't
  exist at all until found+fixed the same day (the underlying
  `plan-9.client.list-dir`/`.read-file` subs already worked, they just
  had no `.cmd.` wrapper; the dots-in-name framing in
  [[bug-forensics-dotted-command-names]] was a secondary, not the main,
  cause — see that file's correction).
- Server-side entry points: `plan-9.cmd.export-directory`/
  `plan-9.cmd.export-buffer` (also cube-routed as `plan-9.export-*`),
  backed by `plan-9.server.*`.
- Port/host defaults: single source of truth is now
  `<plan-9.default_port>` (`cfg/shared-params`) — see
  `data/md/design/STORAGE-9P.md`'s "Config: plan-9.default_port"
  section. Never hardcode a 9P port literal in a new file; read this
  value instead.
- The full `Tversion`/`Tattach`/`Twalk`/`Topen`/`Tcreate`/`Tread`/
  `Twrite`/`Tclunk`/`Tremove`/`Tstat`/`Twstat` set is now implemented
  on the server side — no more deliberately-deferred 9P message types
  remain. `Twstat` is subset-only (rename+resize, see the sixth round
  above), which is a permanent design choice, not a gap.
- **Live in-memory only**: exports (`plan-9.cmd.export-directory`)
  don't survive a `plan-9` zenka restart — re-export before testing
  anything after any restart, hit this repeatedly during live
  verification this session.
- If extending further, re-read `data/md/design/STORAGE-9P.md` (now
  documents create/remove, the write commands, the symlink-policy
  flag, the shared port config, and the server/client module tables)
  and `STORAGE-MAPPING-PLUGINS.md` first — and re-verify the
  double-size-prefix stat-record quirk (`storage.9p.stat`'s buffer
  INCLUDES the entry's own leading size[2] field, `storage.9p.readdir`'s
  EXCLUDES it) before touching either.
- When dispatching further work on this subsystem to kimi (or anyone
  else), explicitly check the signature footer on every new file
  before signing — don't assume the placeholder convention was
  followed correctly just because it looks plausible at a glance.

#,,,.,...,...,.,.,.,,,...,,.,,,,.,,,,,,,.,...,..,,...,...,,,,,,..,...,.,.,.,,,
#VLKJOJQL2YJNO6PJTZPDFTKVLH4SNREXSIXZ3VHAJNIX4T5MLVKVJXDGW6VNWOJIG3TR2RTYH4HBG
#\\\|FIDQH7VPIOKMULKBIBG6U4UNDQAKLSQHELMP4E3GBTFCBXY566C \ / AMOS7 \ YOURUM ::
#\[7]6TYLDCK3YIFI3MIK7PBYLW52O3ZKXCY5QBL2J4XXP2SUMCUENACI 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
