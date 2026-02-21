# Protocol-7 Symlink Chain Architecture

## Overview

Symlink chains provide a flexible, filesystem-based interface for accessing Protocol-7 zenka and services. By following symlink chains, users can invoke commands with parameters using intuitive, mnemonic shortcuts while maintaining security and operational simplicity.

## Basic Concept

Protocol-7 follows symlink chains to discover the actual command and parameters:

```
user-friendly-name → p7.zenka-name → Protocol-7
```

The system resolves the chain from **first to last** symlink, extracting the zenka name and parameters from the **last link before Protocol-7**.

### Chain Resolution Logic

1. Follow readlink chain to find last link before Protocol-7
2. Check if last link matches `p7.<zenkaname>` or `p7.<zenkaname>:<parameters>` pattern
3. **If matched:** Extract zenka name and parameters, execute
4. **If not matched and `:` present:** Error (parameter intent without valid zenka)
5. **If not matched and no `:`:** Fall back to stdin mode (interactive)

## Minimalist Shortcuts

Symlinks can use single or double-character names for ultimate brevity:

| Shortcut | Target | Purpose |
|----------|--------|---------|
| `:` | `p7.nshell` | Interactive shell entry point |
| `::` | `p7c` | Command execution |
| `:.` | `p7.data-import` | Data import container |
| `:::` | `p7-r` | Remote operations |

These are discovered through use - test what feels intuitive and stick with what becomes muscle memory.

## Parameter Format

Parameters follow the colon syntax:

```
p7.zenka:param1,param2,param3
```

### Space Encoding

Spaces in parameters are encoded using underscores with an escape pattern:

- `___` → single space
- `____` → literal `___` (3 underscores)
- `_____` → literal `____` (4 underscores)
- Pattern continues: N underscores become (N-1) underscores

This allows:
```
p7.work:video___import___config
↓
Becomes: "video import config"
```

### Valid Parameter Forms

```
p7.work-overview              # No parameters
p7.work:overview              # Single parameter
p7.work:video,audio,text      # Multiple parameters (comma-separated)
p7.work:video___import        # Parameter with space
```

## Historical Naming Convention

Following AmigaOS and DOS traditions, parameters can use `:` suffix notation:

```
DATA: → p7.terminal-mount → Protocol-7
DISK_000: → p7.data-import → Protocol-7
```

The `:<suffix>` is collected as context and passed to the zenka, which can interpret it according to its design.

## Use Case: Jailed Data Import

A powerful application of symlink chains is secure data import from restricted environments:

### Architecture

```
Jailed Environment:
  cat file.mkv | DISK_000:
         ↓
  [precompiled p7c binary - checksummed]
         ↓
  [unix domain socket: /var/run/UNIX/data-import]
         ↓
Backend:
  [p7.data-import zenka or import handler]
  Routes to storage based on context
```

### Security Properties

1. **No source code access** - Precompiled binary only
2. **No network required** - Unix domain socket connection
3. **Binary integrity** - Checksummed before execution
4. **Context-aware routing** - Parameters guide backend decisions

### Operational Example

```bash
# Simple automatic import
cat categorize-this.mkv | DISK_000:

# Explicit namespace routing
cat file_0000.mkv | DISK_000: video.parties.psytrance

# Faster with explicit hint
cat file_0001.mkv | DISK_001: video.psytrance.full-albums
```

## Operational Scaling: Disk Pools

Multiple import endpoints can be created via hardlinks:

```
network/DATA_IMPORT (p7c binary, checksummed)
  ↑
  └── DISK_000: (hardlink)
  └── DISK_001: (hardlink)
  └── DISK_002: (hardlink)
  └── DISK_NNN: (hardlink)

network/DATA_SOCKET (unix domain socket)
```

### Provisioning

```bash
# Add a single disk to the pool
ln network/DATA_IMPORT DISK_003:

# Or provision many at once
for i in {0..99}; do ln network/DATA_IMPORT DISK_$i:; done
```

Each symlink routes to the same binary and socket, but represents a logical data endpoint. The backend can differentiate based on the endpoint name or parameters.

### Self-Documenting

```bash
$ ls -l | grep DISK
DISK_000: → network/DATA_IMPORT
DISK_001: → network/DATA_IMPORT
DISK_002: → network/DATA_IMPORT
```

Users and admins immediately understand:
- What each endpoint does (data import)
- How to add new capacity (create new hardlink)
- Where the implementation lives (network/DATA_IMPORT)

## Unix Socket Protocol Adapters

Symlink chains work with any protocol-aware unix socket:

### Example: AMOS Checksum Socket

```
data | CHECKSUM_SERVICE: → [unix socket] → amos_chksum handler
```

### Example: SFTP Protocol Adapter

```
filesystem operations | SFTP_MOUNT: → [unix socket] → SFTP protocol handler
```

**Intelligent Protocol Detection:**

The SFTP protocol adapter detects connection types and provides helpful feedback:

- **SFTP connection** (`\0\0` in protocol buffer) → accepted
- **SCP connection** (`\0` single null byte) → redirects with message
- **SSH shell connection** (no protocol signature) → redirects with message

When an unexpected connection type is detected, the adapter closes the channel while sending a usage disclaimer suggesting proper configuration or available alternatives. This guides users to correct usage without breaking existing SSH sessions.

### Example: Remote SSH Tunneling

When SFTP is blocked or unavailable, symlink chains work seamlessly through SSH:

```bash
cat archive_0000.xz | ssh user@storage.local DISK_000:
```

The remote system receives the symlink reference `DISK_000:` which routes to its local p7c binary and unix socket. This enables secure remote data import through SSH tunnels when restrictive network policies prevent SFTP access.

### General Pattern

```
<[base.protocol.bind]>->( $socket, qw| protocol_name | );
```

Any protocol can be bound to a unix socket and accessed via symlink chains.

## Security Considerations

### Intent Signaling

The presence of `:` signals **structured command intent**:

```
DISK_000:           # Just the endpoint name
DISK_000: namespace # Parameters follow

p7.work:param       # Intent: execute with parameters
p7.work             # Intent: execute command
```

If `:` is present but zenka pattern doesn't match, the system rejects execution rather than falling back to stdin mode. This prevents accidental privilege escalation from structured command to raw interpreter access.

### Access Control

- Jailed environments get precompiled binaries (hardened, checksummed)
- No source code access (can't modify behavior by editing)
- Unix socket connection is contextualized (no open network)
- Backend sees socket identity for routing/auditing

## Design Philosophy

**"Just worx"** - The filesystem becomes the API:

1. **Self-explanatory** - `ls -l` shows exactly what's available
2. **User-friendly** - Mnemonic shortcuts work immediately
3. **Admin-friendly** - Adding capacity is one command
4. **Script-friendly** - Standard tools work unchanged
5. **Secure** - Clear intent boundaries, no ambiguity

## See Also

- Technical specifications: `data/yaml/symlink-chains.yaml`
- Protocol binding: Protocol-7 base modules
- Unix socket configuration: System administrator guide

#,,,,,..,,...,,,.,,,,,,..,,,,,,.,,,,.,,.,,,.,,..,,...,...,,,.,.,,,..,,,.,,.,,,
#QQQ2YM3T3XCX2AI64LN72GOCFO5A52VNWMXZAEN2WA3G5RIH36OIW4SBETTDSYC4VJYRIW2TO5RBG
#\\\|V2TH2GZ65CEUBGUO7WWF3KQV7GUWKCAIHEBLZKL3S7GE2IA7NU3 \ / AMOS7 \ YOURUM ::
#\[7]HWYURAP57FTSZFDQJRABY3T7WDNGWCB5BQ5WTMT2ZIOU4MJXIQAQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
