# Storage 9P Integration

9P client integration for the storage zenka - enabling Protocol-7 to assimilate remote filesystems into its deduplication mesh.

## Quick Start

```bash
# Connect to WSL Windows host
storage plan9-connect 127.0.0.1 15640 wsl-host

# Scan Windows Documents (text files only)
storage plan9-scan wsl-host /mnt/c/Users/$USER/Documents \
    --include '\.(txt|md|csv)$' \
    --exclude '~$'

# Scan with multiple filters (AND logic)
storage plan9-scan wsl-host /mnt/c \
    --include-all '2024' \
    --include-all '\.pdf$' \
    --exclude 'temp' \
    --max-depth 3
```

## Commands

### plan9-connect

Connect to a 9P server.

```
plan9-connect <host> [port] [name]
```

Parameters:
- `host` - Server address (default: 127.0.0.1)
- `port` - Server port (default: `<plan-9.default_port>`, `cfg/shared-params`
  — 15640 as shipped; every 9P client/server default reads from this single
  shared value now, see "Config: `plan-9.default_port`" below)
- `name` - Connection identifier (default: host:port)

### plan9-scan

Scan directory with advanced filtering.

```
plan9-scan <name> <path> [:option: value ...]
```

Options:
- `:include: <regex>` - Include files matching pattern (OR logic)
- `:include-all: <regex>` - Include only if ALL patterns match (AND logic)
- `:exclude: <regex>` - Exclude files matching pattern (OR logic)
- `:exclude-all: <regex>` - Exclude if ALL patterns match (AND logic)
- `:max-depth: <n>` - Maximum recursion depth (default: 10)
- `:no-recurse:` - Don't recurse into subdirectories

### plan9-read-file / plan9-write-file

Whole-file content access over 9P — the piece `plan9-scan`/`plan9-connect`
never provided (those only ever did directory listing and metadata).

```
plan9-read-file <connection-name> <path>
plan9-write-file <connection-name> <path> <content>
```

- `plan9-read-file` walks to the path, opens `OREAD`, reads in
  `iounit`-sized chunks until EOF, clunks the fid, returns the whole file.
- `plan9-write-file` walks to the path, opens `ORDWR|OTRUNC` (truncating
  the target first), writes `<content>` at offset 0, clunks the fid. The
  target file must already exist — see `plan9-create` below for making a
  new one. Whether the write actually succeeds also depends on the export
  it resolves through (see "Server: Exporting Real Directories" below) —
  a real 9P client, not just this cube command, hits the same gate.

### plan9-create / plan9-remove

```
plan9-create <connection-name> <path> [:dir:] [<content>]
plan9-remove <connection-name> <path>
```

- `plan9-create` walks to the PARENT directory, issues `Tcreate` for the
  leaf name, and — unless `:dir:` is given — writes `<content>` (if any)
  into the new file at offset 0. `:dir:` creates a directory instead
  (`Tcreate` with the `DMDIR` perm bit) and ignores any trailing content.
  Fails with "already exists" if the target is already there — there is
  no implicit overwrite; use `plan9-write-file` to replace an existing
  file's content instead.
- `plan9-remove` walks directly to the target and issues `Tremove`, which
  deletes it and releases the fid in one step (per 9P spec, `Tremove`
  clunks the fid regardless of whether the removal itself succeeded).
  Removing a non-empty directory fails cleanly (`rmdir` semantics — no
  recursive delete, by design) and removing an export's own root
  directory is rejected outright ("cannot remove export root").
- Both commands hit the same `writable` gate as `plan9-write-file` — a
  read-only export (no `:rw:` at export time) rejects both with "export
  is read-only".

### plan9-rename / plan9-resize

```
plan9-rename <connection-name> <path> <new-name>
plan9-resize <connection-name> <path> <length>
```

`Tstat`/`Rwstat` is implemented for a deliberate subset only: rename
(the `name` field) and resize/truncate (the `length` field). Mode,
atime, mtime, uid, gid, and muid changes are silently ignored — this
virtual filesystem doesn't model real ownership/permission bits, so
honoring those fields wouldn't mean anything. A field carrying its 9P
"don't touch" sentinel (empty string for `name`, `~0` — the max
representable value — for `length`) is left alone; `plan-9.protocol.
codec.encode-wstat` defaults every field it isn't told to change to
that sentinel, which is why it exists as a separate encoder from
`encode-stat` (that one's omitted-field defaults are friendly display
values for directory listings — the opposite of "don't touch").

- `plan9-rename` walks to the target, sends a `Twstat` with only
  `name` set, rejects a name that's `.`/`..`/contains `/`, rejects
  renaming an export's own root, and rejects if the new name already
  exists (no implicit overwrite). The stable qid mapping is migrated
  to the new path so the file keeps its identity across the rename.
- `plan9-resize` walks to the target and sends a `Twstat` with only
  `length` set, real `truncate()` underneath; rejects resizing a
  directory.
- Both hit the same `writable` gate as the other write commands.

## Filter Logic

Filters are applied in this order (first match wins):

1. **exclusion-and**: If ALL patterns match → reject
2. **exclusion-add**: If ANY pattern matches → reject
3. **inclusion-and**: If ALL patterns don't match → reject
4. **inclusion-add**: If ANY pattern matches → accept
5. **No inclusion filters**: Accept (if passed exclusions)

### Examples

```bash
# Include: OR - match any
:include: '\.pdf$' :include: '\.doc$'  # PDF or DOC files

# Include-all: AND - must match all
:include-all: 'report' :include-all: '2024'  # Files with "report" AND "2024"

# Exclude: OR - reject any
:exclude: '\.tmp$' :exclude: '~$'  # No temp or backup files

# Exclude-all: AND - reject if all match
:exclude-all: 'temp' :exclude-all: 'backup'  # Reject if both words present
```

## Use Cases

### WSL Windows File Indexing

```bash
# Index Windows Downloads for checksum analysis
storage plan9-scan wsl-host /mnt/c/Users/$USER/Downloads \
    :include: '\.(exe|msi|zip)$' \
    > windows-installers.txt
```

### Selective Backup

```bash
# Find important documents from 2024
storage plan9-scan wsl-host /mnt/c/Users \
    :include-all: '2024' \
    :include: '\.(doc|pdf|xls)$' \
    :exclude-all: 'temp' \
    :exclude-all: 'cache'
```

### Code Repository Discovery

```bash
# Find Git repositories
storage plan9-scan wsl-host /mnt/c/dev \
    :include: '^\.git$' \
    :no-recurse:  # Just find repos, not scan contents
```

## Programmatic Usage

The `storage.9p.scan` module accepts coderef callbacks:

```perl
my $result = <[storage.9p.scan]>->({
    name      => 'wsl-host',
    path      => '/mnt/c/data',
    recursive => 1,
    
    # Regex patterns
    inclusion_add => [ qr/\.csv$/, qr/\.json$/ ],
    exclusion_add => [ qr/~$/, qr/\.tmp$/ ],
    
    # Callback functions
    callbacks => {
        match => sub {
            my ($file_info) = @_;
            # Process matched file
            print "Found: $file_info->{path}\n";
        },
        reject => sub {
            my ($file_info) = @_;
            # Log rejected files
        },
    },
});
```

## Config: `plan-9.default_port`

Every 9P client and server default port reads from one shared config
value, `plan-9.default_port` (`cfg/shared-params`, ships as `15640`) —
`storage.9p.connect`/`.mount`, `storage.cmd.plan9-connect`, `plan-9.client`,
`amos-term.cmd.mount-9p`/`mount-9p-client`, `plan-9.server`, and the
`p7ref` `9p:` type's authority default all read `<plan-9.default_port>
// 15640` (the trailing literal is a last-resort fallback only, in case
`shared-params` somehow wasn't loaded).

**History**: this used to be a hardcoded `15640`/`5640` literal
independently duplicated in 7+ files, and it drifted — some files said
`5640`, others `15640` — a real, silently-broken bug found and fixed
2026-08-22. There was also an earlier attempt at a single source of
truth, `src/plan-9.config` (a plain module returning a config hash),
but it was **never actually wired up**: every reader used
`<plan-9.config.port>` (data-tree read syntax), which only resolves
values populated via `.pre_init`/`.init_code` constants or plain
`key=value` config-file parsing — never a bare `return {...}` module.
Proven empirically (changing the file's value had zero effect on the
real listen port) before being removed and replaced with the
`shared-params` approach, which is confirmed working the same way
(`system.zenka.verbosity.*` already relies on it) and is genuinely
per-zenka overridable: any zenka wanting a non-standard default can add
its own `plan-9.default_port = <value>` line to its own `zenka.v7`,
after its `[load_config_file:'shared-params']` line.

## Server: Exporting Real Directories

The `plan-9` zenka (separate from `storage`, see below) is the 9P
*server* side — it exports either fake in-memory vterm-style buffers or
real local directories for a client like `storage` to connect to.

```
plan-9.export-directory <path> <name> [:rw:] [:symlinks: reject|contained|allow]
```

- `<path>` must be an absolute, existing directory.
- Without `:rw:` the export is **read-only** — this is the safe default;
  writes against it fail with "export is read-only" regardless of what
  the connecting client requests.
- `:symlinks:` controls what happens when a walked path component is a
  symlink, checked with a non-following `-l` test so a blocked or broken
  link is caught before anything follows it:
  - `reject` (default) — any symlink component fails the walk outright,
    whether or not its target is inside the exported tree.
  - `contained` — allowed only if the resolved real path
    (`Cwd::abs_path`) still lives under the export's own canonical root;
    a symlink pointing outside the export fails the walk.
  - `allow` — no check at all. Given this repo's own tree uses a handful
    of symlinks, blocking them unconditionally would limit legitimate
    use — `contained` is the middle ground for exports where that
    matters.
- `Tcreate`, `Tremove`, and `Twstat` are all implemented (see
  `plan9-create`/`plan9-remove`/`plan9-rename`/`plan9-resize` above) —
  all respect the same `writable` gate, `Tremove` refuses to delete an
  export's own root directory, and `Twstat` only honors the `name`
  (rename) and `length` (resize) fields — mode/atime/mtime/uid/gid/muid
  changes are silently ignored, this virtual filesystem doesn't model
  real ownership/permission bits.

Recursive descent (multi-level `Twalk`, and `storage.9p.scan`'s
recursive client-side walker) was already implemented before real
directories existed to test it against — it turned out to work
correctly once real-directory export landed and was live-verified
against a multi-level tree with both a contained and an escaping
symlink, exercising all three policies.

## Architecture

### 9P Server (`plan-9` zenka)

| Module | Purpose |
|--------|---------|
| `plan-9.server` | Listener startup, event-loop wiring |
| `plan-9.server.export_directory` | Register a real directory export |
| `plan-9.server.export_buffer` | Register a vterm-buffer export |
| `plan-9.server.handle_walk` | Twalk — buffer + realpath dispatch, symlink policy |
| `plan-9.server.handle-io-open` | Topen — write-mode gate, OTRUNC |
| `plan-9.server.handle-io-read` / `.realpath-read` | Tread — directory listing / file bytes |
| `plan-9.server.handle-io-write` | Twrite — vterm layer + realpath file writes |
| `plan-9.server.handle-io-create` | Tcreate — new file/directory, writable + name-validity gated |
| `plan-9.server.handle-io-remove` | Tremove — delete, writable-gated, always clunks the fid |
| `plan-9.server.handle-io-wstat` | Twstat — rename + resize only, writable-gated |
| `plan-9.protocol.codec.decode-stat` / `.encode-wstat` | Stat blob decode / sentinel-defaulted wstat encode |
| `plan-9.cmd.export-directory` | CLI export command |

### 9P Client, Low-Level (`storage` zenka)

| Module | Purpose |
|--------|---------|
| `storage.9p.connect` | Establish connection |
| `storage.9p.version` | Protocol version handshake |
| `storage.9p.attach` | Attach to filesystem |
| `storage.9p.walk` | Navigate directories |
| `storage.9p.open` | Open files/directories |
| `storage.9p.readdir` | Read directory contents |
| `storage.9p.read` | Read bytes from an open file (Tread) |
| `storage.9p.write` | Write bytes to an open file (Twrite) |
| `storage.9p.create` | Create a new file/directory (Tcreate) |
| `storage.9p.remove` | Delete a file/directory (Tremove) |
| `storage.9p.wstat` | Rename/resize a file (Twstat) |
| `storage.9p.stat` | Get file metadata |
| `storage.9p.clunk` | Close/release resources |
| `storage.9p.read-message` | Protocol message handling |

### High-Level Operations

| Module | Purpose |
|--------|---------|
| `storage.9p.scan` | Filtered directory scanning |
| `storage.9p.filter-check` | Pattern matching logic |
| `storage.9p.read-file` | Whole-file read (walk+open+read-loop+clunk) |
| `storage.9p.write-file` | Whole-file write (walk+open+write+clunk) |
| `storage.9p.create-file` | Create file/directory (walk-to-parent+create[+write]+clunk) |
| `storage.9p.remove-path` | Delete file/directory (walk+remove, auto-clunks) |
| `storage.9p.rename-path` | Rename file/directory (walk+wstat+clunk) |
| `storage.9p.resize-path` | Resize/truncate a file (walk+wstat+clunk) |
| `storage.cmd.plan9-connect` | CLI connect command |
| `storage.cmd.plan9-scan` | CLI scan command |
| `storage.cmd.plan9-read-file` | CLI whole-file read command |
| `storage.cmd.plan9-write-file` | CLI whole-file write command |
| `storage.cmd.plan9-create` | CLI create-file/directory command |
| `storage.cmd.plan9-remove` | CLI remove command |
| `storage.cmd.plan9-rename` | CLI rename command |
| `storage.cmd.plan9-resize` | CLI resize/truncate command |

## Future: Checksum Integration

The storage zenka will integrate 9P scans with Protocol-7's deduplication:

```
1. Scan remote 9P filesystem
2. Hash files incrementally
3. Check against local checksum database
4. New content: Add to assimilation queue
5. Existing content: Create reference link
6. Index metadata for global search
```

This creates the "implosion vortex" - remote data naturally flowing into Protocol-7's deduplicated storage mesh.

---

*9P is the ingestion membrane of the storage singularity.*

#,,.,,,,.,,,,,.,.,.,,,..,,,,,,...,.,.,..,,,,.,..,,...,...,.,,,.,,,,.,,.,.,,..,
#5N2ZBXKGZALOBZVL2ZLNP3E5BJXBR327PKS4HHI7HR4FS4VTHDQFEF6GTR6JJBJM4Z36GPPBSEH46
#\\\|W7LA5WAYCQMPQIQ5HPSXUPAJAJ3F5EGRCAA7YM262IBRFV7GTU4 \ / AMOS7 \ YOURUM ::
#\[7]QU7EFGDYHV6BY2F2HJNLLMQRZMQM3ESGDJ2UL52PM3TFWSYIHEDY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
