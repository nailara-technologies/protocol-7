# N7FS tree layer and categories : stage 1 as built

2026-11-08. this is an additive store-format-3 extension. there is no format
bump. format 1, 2 and pre-extension 3 journals and disks retain their readers;
the new journal lists default to empty when absent. encryption, incoming pool,
sync, placement and enforcement are not part of this stage.

## records

all four kinds use record format 3 and only the parent-signed id's store key.
magic, format byte, label, payload length, signer and signature are checked.

| kind | magic | label | location below `.n7fs/` |
|---|---|---|---|
| tree | `P7FM` | `p7 n7fs tree:0001` | `trees/<ntime14>.<tail8>.tree` |
| tree drop | `P7FL` | `p7 n7fs tree drop:0001` | `tree-drops/<ntime14>.<tail8>.tree-drop` |
| category | `P7FC` | `p7 n7fs category:0001` | `categories/<ntime14>.<tail8>.category` |
| assignment | `P7FB` | `p7 n7fs category assignment:0001` | `assignments/<ntime14>.<tail8>.assignment` |

a tree payload is `{ disk, name, manifest, created, ntime }`. a drop adds the
original tree record's `tree` filename. category definitions carry the complete
policy, not a delta. assignments carry `{ disk, node, reference, holder,
category, ntime }`; the journal repeats their binding fields.

journal `add` gains `trees`, `categories` and `assignments`; `drop` gains
`trees`. tree history, drop history, every category version and every assignment
version remain authenticated. latest category definitions and assignments win.
replay refuses duplicate live tree names, drops of non-live trees, assignments
to unknown references and manifests not added as content nodes.

`verify` compares every record with the journal, verifies each live manifest
content node and checks every address named by a live manifest. missing,
altered and unjournaled records fail. live trees pin both their manifest node
and every content-addressed regular file for release and reclaim. `-force` can
break pins just as it can break ordinary references. `tree-drop` removes only
the live tree assertion; content and meta stay.

a crash between a new stage-1 record and its journal entry leaves the operation
uncompleted. `repair` moves every unjournaled tree, tree-drop, category or
assignment record into `.n7fs/quarantine/<record-type>/`, reports each name and
adopts nothing from it. quarantined files are retained but never scanned as
records. ordinary unjournaled content/meta/reference crash data keeps the older
explicit-adoption behavior. verification passes after quarantine and the
operation can be retried.

## manifest encoding

a manifest is an ordinary content node with signed format-3 meta. its content
is canonical JSON Lines : one header line and one entry per line. it is streamed
while building and read entry-by-entry while restoring; no single JSON document
holding the whole tree is constructed. directory metadata and restore work are
linear in entry count. the existing assimilation report still holds its source
entries in memory.

the header is `{ manifest : 1, root_b32, created }`. each entry has `p`, `t`,
`mode`, `uid`, `gid`, `mtime`, optional `user_b32`, `group_b32`, `mtime_ns` and
`xattrs`. `p` is the base32 of the raw relative-path octets. `l` is a base32
symlink target, `a` a canonical file content address, and `h` the base32 path of
the earlier entry for a hardlink. owner and group names and xattr names and
values are base32 octets too. raw non-UTF-8 names are never passed through a
UTF-8 encode/decode cycle.

manifest addresses include the epoch. any future converter that moves content
nodes to a new epoch MUST rewrite every manifest and its tree binding, or
re-resolve every entry to the new addresses; copying the manifest bytes and
content nodes alone leaves references to the old epoch.

entry types are `file`, `dir`, `symlink`, `hardlink` and `skipped`. the root
directory has an empty relative path. empty directories are ordinary `dir`
entries. fifo, socket and device entries are `skipped`, have a reason and are
printed by assimilation. unreadable or vanished files and directories, files
that appeared during import and files whose size or mtime changed between import
and manifest walk are also named `skipped` entries. those source errors are
counted, the tree and all readable content still complete and journal, and the
command exits nonzero. ordinary record-creation failures journal already
completed content before the error propagates.

a field unavailable from the source API or filesystem is omitted.
`Time::HiRes::lstat` supplies `mtime` plus `mtime_ns` without following symlinks.
linux xattrs use size-first `l*xattr` syscalls. a list or attribute read failure
is recorded in `xattr_errors` with a base32 name and reason, and counted in the
output; successfully read attributes are retained.

## commands

```
n7fs assimilate -disk <disk> -tree <name> [ -category <name> ]
    [ -category-rule <glob>=<name> ] <one-directory>
n7fs trees <disk>
n7fs tree-drop <disk> <name>
n7fs restore <disk> <tree-name> <target> [ -owners ] [ -dry-run ]
n7fs category <disk> set <name> [ -local-encryption none|cascade ]
    [ -copies <n> ] [ -priority <n> ] [ -replica full|manifest ]
    [ -want <holder,..> ] [ -foreign-work no|yes ]
    [ -layer private|generic ]
n7fs category <disk> list
n7fs category <disk> show <address>
n7fs set-category <disk> <address|tree:path-prefix> <name>
```

`-tree` takes exactly one directory root. category rules also work without a
tree; `*` and `?` are matched against the absolute source holder and the first
match wins. unknown category names refuse before content or records change.
the built-in `default` definition is none, 1, 0, full, empty want, no, private.
category values are stored and displayed only. `set` with cascade says plainly
that encryption is not enforced yet.

`category show` prints each historical reference's current assignment and the
effective node policy : cascade over none, maximum copies, maximum priority,
full over manifest, no over yes, private over generic, and sorted union of want.
address assignment covers all live references to that address. `tree:` prefix
assignment matches live reference holder paths.

restore authenticates the tree and manifest and checks each file node before
copying it. a preflight refuses duplicate paths, absolute paths, empty, dot and
`..` components, NULs and any entry or hardlink target with a proper symlink
prefix. symlinks are deferred, and every parent is checked again with `lstat`
immediately before creation. regular files use no-follow, exclusive opens.
trailing target slashes are normalized; a nonempty target refuses.

the target is built as `<target>.tmp.<random>`, containing `.n7fs-incomplete`.
non-root directories receive metadata children first. the marker is removed,
then root ownership, mode and xattrs are applied, with root mtime last, before
the atomic publish. cleanup makes real directories owner-writable without
following symlinks. an abrupt process crash can leave the clearly named
temporary sibling, never a published partial target.

ownership uses a resolvable stored owner/group name first, then the numeric id
with a counted fallback. symlinks use `lchown`. per entry the order is chown,
chmod, xattrs, then time, so chown cannot clear subsequently applied mode bits
or capabilities. setuid/setgid and ownership require `-owners` as root.
`utimensat` applies what the manifest holds and uses `AT_SYMLINK_NOFOLLOW` for
links. the source value comes through a perl double, so an mtime is accurate to
about a microsecond, not to the nanosecond. unavailable or failed timestamp operations are counted as omitted, not fatal.
xattr failures are counted. dry-run verifies but creates nothing. command
failures return nonzero.

## known limits

- xattrs and exact restore timestamps require the platform's linux syscall
  interface; unsupported source fields stay absent and destination failures are
  counted.
- one tree name per assimilation invocation and one directory root per tree.
- category encryption, replica selection, copies, priority, want, foreign-work
  and layer have no operational enforcement in stage 1.
- no incoming pool, network, sync, sealed replica or placement behavior is
  included.

#,,,,,,..,.,.,,,.,,.,,,,.,,,,,.,.,...,,,,,...,..,,...,...,...,...,..,,...,,,.,
#WLQW7AIC6GFW7566Z3SS5JGXRV3XCFJXIUNROP4WA2MIK5P55NN6PUB4FK54TVBVU2HUZX6X7VVG2
#\\\|R5Z762TPSCKGT6N7PTUIZXANDHXKMKC7SOSWTKK3O6SFEW3DS66 \ / AMOS7 \ YOURUM ::
#\[7]ODP2NT7MEVY7PLFAI7PXEN7IGIIUSQHG3E6BJTHGHD5SXS7CVUAA 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
