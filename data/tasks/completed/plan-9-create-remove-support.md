# 9P Tcreate/Tremove support (plan-9 server + storage client)

## archive: DONE ✓ -- 2026-08-22
## dispatch: kimi k2.7, independently live-verified afterward
## notes: caught a malformed signature-footer bug in kimi's output during
##   review (placeholder text merged into the skeleton lines instead of
##   the clean 4-line form) -- see feedback-fake-signature-marks-ai-
##   scratch-content.md's addendum. All create/remove/root-rejection/
##   read-only-rejection/non-empty-dir-rejection cases live-verified.

## Scope

Implement `Tcreate`/`Rcreate` and `Tremove`/`Rremove` for the 9P subsystem —
**both server side (`plan-9` zenka) and client side (`storage` zenka)**.

**Explicitly OUT OF SCOPE: `Twstat`/`Rwstat` (rename/chmod).** It needs a
`decode-stat` codec module that doesn't exist yet, plus 9P's "don't-touch
sentinel" field semantics (fields set to all-1s bits or an empty string mean
"leave this field unchanged"). That's materially bigger and more error-prone
than Tcreate/Tremove, which only need existing decode primitives. Do not
attempt it — leave it for a separate task.

**Also out of scope**: no live execution, no starting/restarting any zenka,
no `p7c` calls, no `git commit`. Verification is static only (see below) —
someone else will do live verification against a running system afterward.

## Precedent to mirror exactly

Read these four files first — they were all written earlier in this exact
session and define every convention you need:

- `src/plan-9.server.handle-io-write` — the write handler this create/remove
  work sits next to. Shows the fid lookup pattern, the `writable` flag
  check, the `plan-9.protocol.error` error-reply convention, and the
  low-level codec calls (`<[plan-9.protocol.codec.decode-uint32]>`, etc.)
- `src/plan-9.server.handle-io-open` — shows how a fid's `omode`/`open`
  fields get set, and the qid+iounit reply shape used by Ropen (Rcreate
  uses the exact same reply shape: qid[13] + iounit[4])
- `src/plan-9.server.handle_walk` — shows (a) the invalid-path-component
  guard (`$name eq '' or $name eq '.' or $name eq '..' or $name =~ m{/}`)
  — reuse this exact condition for Tcreate's `name` field — and (b) the
  fid-state shape for a `realpath`-type fid: `{ type=>'realpath',
  realpath=>$path, root=>$root, writable=>$writable,
  symlink_policy=>$policy, qid=>{...} }` and the
  `$data{'plan-9'}{'server'}{'realpath_qids'}{$child} //=
  $data{'plan-9'}{'server'}{'next_qid'}++;` qid-assignment idiom — reuse
  both exactly, don't invent a different shape
- `src/storage.9p.write` and `src/storage.9p.write-file` — the client-side
  precedent for the low-level/high-level split you're mirroring. Note the
  variable name `$payload` (NOT `$data`) for the decoded response-body
  scalar — a lexical `$data` next to the global `%data` hash the whole
  codebase reads through `<...>` macros is a readability trap, confirmed
  by the user earlier this session. Use `$payload` in every new file here.

Also skim `src/plan-9.server.handle-io-clunk` (Tremove's "always clunk the
fid" behavior mirrors this exactly) and `src/plan-9.protocol.constants.pre_init`
for the constants already defined and ready to use: `Tcreate`, `Rcreate`,
`Tremove`, `Rremove`, `DMDIR`.

## What to build

### Server (`plan-9` zenka)

**`src/plan-9.server.handle-io-create`** (Tcreate/Rcreate):
- decode `fid[4] name[s] perm[4] mode[1]` from the request payload (`fid`
  and `perm` are uint32, `name` is a 9P string via `decode-string`, `mode`
  is uint8 — same decode calls `handle-io-write`/`handle-io-open` already
  use)
- look up `$f = $client->{fids}{$fid}`; error "invalid fid" if missing
- error unless `$f->{type} eq 'realpath'` and `-d $f->{realpath}` (must be
  creating INSIDE an already-open directory fid)
- error on an invalid `$name` (reuse `handle_walk`'s exact guard)
- error unless `$f->{writable}` ("export is read-only")
- `$child = "$f->{realpath}/$name"`; error "already exists" if `-e $child`
- if `$perm & <plan-9.protocol.constants.DMDIR>`: `mkdir($child)`; else
  `open(my $fh, '>', $child)` then `close($fh)` (create empty file) — on
  either OS-level failure, return a `plan-9.protocol.error` with `$!`
- assign a qid the same way `handle_walk` does:
  `$data{'plan-9'}{'server'}{'realpath_qids'}{$child} //=
  $data{'plan-9'}{'server'}{'next_qid'}++;`
- **mutate `$client->{fids}{$fid}` in place** to now represent the new
  child: `{ type=>'realpath', realpath=>$child, root=>$f->{root},
  writable=>$f->{writable}, symlink_policy=>$f->{symlink_policy},
  qid=>{...}, open=>1, omode=>$mode }` — the SAME fid number now refers to
  the newly created file (this is 9P Tcreate semantics, not a new fid)
- reply: `encode-message(Rcreate, $tag, encode-qid(...) .
  encode-uint32($client->{msize} // 8192))`

**`src/plan-9.server.handle-io-remove`** (Tremove/Rremove):
- decode `fid[4]`
- look up `$f = $client->{fids}{$fid}`; error "invalid fid" if missing
- if `$f->{type} ne 'realpath'`: error "cannot remove this file" (do not
  attempt removal of vterm-buffer/layer/metadata constructs)
- error unless `$f->{writable}`
- error if `$f->{realpath} eq $f->{root}` ("cannot remove export root")
- `-d $f->{realpath}` ? `rmdir(...)` : `unlink(...)` — if this fails
  (e.g. a non-empty directory), return a `plan-9.protocol.error` with
  `$!` — **do not attempt a recursive delete**, a failed rmdir on a
  non-empty directory is correct, intentional behavior
- **regardless of whether the remove succeeded or failed, per 9P spec
  Tremove always clunks the fid** — `delete $client->{fids}{$fid}` (same
  line `handle-io-clunk` has), even on the error-return path
- reply on success: `encode-message(Rremove, $tag, '')` (empty payload,
  same shape as Rclunk)

**`src/plan-9.server.handle_request`**: add two `elsif` branches for
`Tcreate` and `Tremove`, same shape as the existing `Twrite`/`Tclunk`
branches (pull the constants into local `my $Tcreate = ...` /
`my $Tremove = ...` vars at the top alongside the others already there).

### Client (`storage` zenka)

**`src/storage.9p.create`** — low-level Tcreate wrapper, same shape as
`storage.9p.write`: args `($conn, $fid, $name, $perm, $mode)`, increment
`++$conn->{tag} & 0xFFFF`, encode `fid[4] name[s] perm[4] mode[1]`, send,
`storage.9p.read-message`, decode the qid+iounit reply, store
`$conn->{fids}{$fid}{iounit}` (same as `storage.9p.open` already does),
return `{ mode=>'true', data=>{...} }`.

**`src/storage.9p.remove`** — low-level Tremove wrapper: args `($conn,
$fid)`, encode `fid[4]`, send, `storage.9p.read-message`, then **delete
`$conn->{fids}{$fid}` unconditionally** after (mirror `storage.9p.clunk`'s
unconditional delete — the fid is gone either way per 9P spec).

**`src/storage.9p.create-file`** — high-level: args `($conn, $path,
$content, $is_dir)`. Split `$path` into parent-directory parts + leaf
name (the parent must already exist — you're walking to it, not to the
new file). Walk to the parent dir fid (same pattern as
`storage.9p.write-file`'s walk-to-target, just one level up). Call
`storage.9p.create` with the leaf name and `perm = $is_dir ?
<plan-9.protocol.constants.DMDIR> : 0`. If `$content` is given and
`$is_dir` is false, call `storage.9p.write` at offset 0 with it. Clunk
the fid at the end (create leaves it open, same as walk+open would).

**`src/storage.9p.remove-path`** — high-level: args `($conn, $path)`. Walk
directly to the existing target path, then `storage.9p.remove` on that
fid (Tremove auto-clunks — do not call `storage.9p.clunk` separately,
that would double-clunk an already-removed fid).

**`src/storage.cmd.plan9-create`** — cube command, same shape as
`storage.cmd.plan9-write-file`: `<connection-name> <path> [:dir:]
[<content>]`. Parse tokens the same way `plan-9.cmd.export-directory`
parses its `:rw:`/`:symlinks:` flag tokens (a bare `:dir:` token anywhere
in the remaining args means "create a directory," everything else after
the path/name is joined back as `<content>`). Look up the connection via
`$data{'storage'}{'9p'}{'connections'}{$name}` (same as
`storage.cmd.plan9-read-file`/`plan9-write-file` already do). Call
`storage.9p.create-file`.

**`src/storage.cmd.plan9-remove`** — cube command, same shape as
`storage.cmd.plan9-read-file`: `<connection-name> <path>`. Call
`storage.9p.remove-path`.

**`cfg/zenki/storage/zenka.v7`**: add `plan9-create plan9-remove` to the
`access.cmd.usr.cube` list, right next to the existing
`plan9-read-file plan9-write-file` entries. Do not touch
`modules.load` — the `storage`/`plan-9` namespace tokens already there
cover any new file under those namespaces automatically.

## Style reminders (established this session)

- Use `# PLACEHOLDER_FOR_AMOS7_SIGNATURE_LINE_1` through `_4` as the
  footer on every new file — never fabricate a plausible-looking
  signature block.
- `descr =` header line must be under ~55 characters or the pre-commit
  hook will flag it (informational only, doesn't block you here since
  you aren't committing).
- lowercase comments, `[ word ]` bracket style for annotations (see
  CLAUDE.md's Code Style section if you need more examples) — but keep
  comments minimal; only explain non-obvious WHY, not WHAT.

## Verification (static only — do not execute anything)

For every new/changed file:
```
bin/dev/ptd -c <file>
```
must report "syntax ok". Beyond that, hand-trace the wire format for both
new message types against `src/plan-9.protocol.constants.pre_init` and
confirm your encode/decode byte offsets line up (Tcreate's payload layout
is `fid[4] name[s] perm[4] mode[1]`; a 9P string via `encode-string`/
`decode-string` is length-prefixed, check those existing codec files if
you're unsure of the exact framing).

Do not start any zenka, do not run any `p7c` command, do not commit. Leave
all new/changed files on disk for review.

#,,,,,,.,,,..,..,,..,,.,,,.,.,.,.,,..,..,,,,,,..,,...,..,,..,,,..,,..,.,,,,,,,
#TFFIWZWBHLPFADLIOHOYOORZJXCPVPCZPCDLCGPDBVKELIZXFKBECJPE7NCQKFHDSJD4FBC2QIS5M
#\\\|S3B2RJS3V56SFFGJ4UFLS6L3SWIWWH64Y7WSPQFNHC4JSLEGOO2 \ / AMOS7 \ YOURUM ::
#\[7]36P5HMGBQV3GDGVTR67D7MDYNSWDQMPL2J6CV77MJHAEVHUEOCDA 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
