# Storage 9P Integration

9P client integration for the storage zenka - enabling Protocol-7 to assimilate remote filesystems into its deduplication mesh.

## Quick Start

```bash
# Connect to WSL Windows host
storage 9p-connect 127.0.0.1 5640 wsl-host

# Scan Windows Documents (text files only)
storage 9p-scan wsl-host /mnt/c/Users/$USER/Documents \
    --include '\.(txt|md|csv)$' \
    --exclude '~$'

# Scan with multiple filters (AND logic)
storage 9p-scan wsl-host /mnt/c \
    --include-all '2024' \
    --include-all '\.pdf$' \
    --exclude 'temp' \
    --max-depth 3
```

## Commands

### 9p-connect

Connect to a 9P server.

```
9p-connect <host> [port] [name]
```

Parameters:
- `host` - Server address (default: 127.0.0.1)
- `port` - Server port (default: 5640)
- `name` - Connection identifier (default: host:port)

### 9p-scan

Scan directory with advanced filtering.

```
9p-scan <name> <path> [:option: value ...]
```

Options:
- `:include: <regex>` - Include files matching pattern (OR logic)
- `:include-all: <regex>` - Include only if ALL patterns match (AND logic)
- `:exclude: <regex>` - Exclude files matching pattern (OR logic)
- `:exclude-all: <regex>` - Exclude if ALL patterns match (AND logic)
- `:max-depth: <n>` - Maximum recursion depth (default: 10)
- `:no-recurse:` - Don't recurse into subdirectories

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
storage 9p-scan wsl-host /mnt/c/Users/$USER/Downloads \
    :include: '\.(exe|msi|zip)$' \
    > windows-installers.txt
```

### Selective Backup

```bash
# Find important documents from 2024
storage 9p-scan wsl-host /mnt/c/Users \
    :include-all: '2024' \
    :include: '\.(doc|pdf|xls)$' \
    :exclude-all: 'temp' \
    :exclude-all: 'cache'
```

### Code Repository Discovery

```bash
# Find Git repositories
storage 9p-scan wsl-host /mnt/c/dev \
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

## Architecture

### Low-Level 9P Protocol

| Module | Purpose |
|--------|---------|
| `storage.9p.connect` | Establish connection |
| `storage.9p.version` | Protocol version handshake |
| `storage.9p.attach` | Attach to filesystem |
| `storage.9p.walk` | Navigate directories |
| `storage.9p.open` | Open files/directories |
| `storage.9p.readdir` | Read directory contents |
| `storage.9p.stat` | Get file metadata |
| `storage.9p.clunk` | Close/release resources |
| `storage.9p.read-message` | Protocol message handling |

### High-Level Operations

| Module | Purpose |
|--------|---------|
| `storage.9p.scan` | Filtered directory scanning |
| `storage.9p.filter-check` | Pattern matching logic |
| `storage.cmd.9p-connect` | CLI connect command |
| `storage.cmd.9p-scan` | CLI scan command |

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

#,,,.,,,.,...,,,,,,,,,..,,.,,,,,,,..,,..,,...,..,,...,...,..,,.,.,.,,,,.,,,,.,
#6XWFPW4T7WBKALLYR6QD23GV756O3KHYPKGHBNJKJL5XGMMXMCOCVBMTQK32SL6GJRCFXLOIQAPIE
#\\\|CYXESTDFADE5YRCULIDKETOWLABHRLPCMGPVFGITZ2W2JOSNRAS \ / AMOS7 \ YOURUM ::
#\[7]TTOWWWGBD6CTGECJP3FWZ2GVRFC5QWZH2LIV53JRK3D2BKOHF2AI 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
