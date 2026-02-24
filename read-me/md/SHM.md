# Protocol-7 Shared Memory (SHM) System

High-performance shared memory implementation for inter-zenka communication.

## Overview

The SHM system provides two layers:

1. **data.mount.shm** - Low-level SHM segment management
2. **data.channel.shm** - High-performance ring buffer channels

## Features

- **File-based SHM**: Uses `/dev/shm` (tmpfs) - works on all Linux systems
- **No POSIX dependency**: Falls back to portable file-based approach
- **Cryptographic identity**: Headers signed with Ed25519 public keys
- **Zero-copy access**: Memory-mapped I/O via Sys::Mmap
- **Ring buffer channels**: Lock-free multi-producer/multi-consumer queues

## Quick Start

### Create SHM Segment

```perl
my $shm = <[data.mount.shm.create]>->(
    $pubkey,           # Owner's Ed25519 public key (base32)
    65536,             # Data size in bytes
    {                  # Options
        'mlock'    => 1,        # Lock memory (prevent swap)
        'encrypted'=> 0,        # Enable encryption
        'sub_path' => 'data',   # Namespace path
    }
);
```

### Open Existing Segment

```perl
my $shm = <[data.mount.shm.open]>->(
    $pubkey,
    { 'sub_path' => 'data', 'read_only' => 0 }
);
```

### Read/Write Data

```perl
# Write at offset (after 512-byte header)
substr(${$shm->{'mmap_ptr'}}, 512, length($data)) = $data;

# Read back
my $read = substr(${$shm->{'mmap_ptr'}}, 512, $length);
```

### SHM-Backed Channels

```perl
# Create channel
my $ch = <[data.channel.shm.create]>->(
    'channel_name',
    $owner_pubkey,
    { 'size' => 256 * 1024 }
);

# Write messages
<[data.channel.shm.write]>->($ch->{'channel_id'}, $message);

# Poll for data
my $status = <[data.channel.shm.poll]>->($ch->{'channel_id'});

# Read messages
my $msgs = <[data.channel.shm.read]>->($ch->{'channel_id'}, 10);
```

## Architecture

### File Naming

```
/dev/shm/p7:M:<pubkey_b32>:<sub_path>
```

Example:
```
/dev/shm/p7:M:TEST1234ABCD5678EFGH9012IJKL3456MNOP7890QRST1234UVWX:channel:queue1
```

### Header Format

| Offset | Size | Field |
|--------|------|-------|
| 0 | 4 | Magic "P7SH" |
| 5 | 1 | Version |
| 7 | 52 | Owner pubkey (base32) |
| 60 | 16 | Created timestamp |
| 76 | 4 | Data size |
| 80 | 4 | Header size (512) |
| 84 | variable | Flags (key=value pairs) |

### Ring Buffer Layout

```
[512 bytes: Cryptographic Header]
[16 bytes: Ring header (read_pos, write_pos, wrap_count, capacity)]
[capacity bytes: Message data]
```

## Security

- **Identity-based access**: Paths derived from public keys
- **Permission system**: Ed25519-signed capability tokens
- **Memory locking**: Optional mlock() to prevent swapping
- **No central registry**: Self-certifying path names

## Performance

- **Latency**: ~100ns for read/write (memory-mapped)
- **Throughput**: Millions of messages/second
- **Zero-copy**: Direct memory access, no kernel buffers
- **Lock-free**: Single-writer atomic updates

## Testing

```bash
# Run SHM tests
data.exec-sub data.mount.shm.test.basic
data.exec-sub data.channel.shm.test.basic
```

## Module Reference

### data.mount.shm.*

| Module | Purpose |
|--------|---------|
| create | Create SHM segment |
| open | Open existing segment |
| unlink | Remove segment |
| stat | Get segment info |
| stats | System-wide statistics |
| header.read | Parse header |
| header.write | Write header |
| lock.memory | mlock() segment |
| lock.unlock | munlock() segment |

### data.channel.shm.*

| Module | Purpose |
|--------|---------|
| create | Create channel |
| read | Read messages |
| write | Write message |
| poll | Check status |
| close | Cleanup channel |
| test.basic | Run tests |

#,,..,,,,,.,,,..,,,..,..,,,,,,..,,,,,,.,,,...,..,,...,...,,,.,,,,,,,,,,,.,.,.,
#5VPQ64Z2JDDULK4S3D4MM4JBJ5L5IU6ZY3LGCSPM6JCTQSWM7A4YI4ZBYNUVA5MRHXVSN5YIEA3IY
#\\\|27TO6DXCB3XZB4YYK2W644YK5YUUMMI3RHAO5AQE3U7PSQZ7SUS \ / AMOS7 \ YOURUM ::
#\[7]HNVITFJAZSBEQ7JXMJNZEVZFNKAXHPAL2T2DVMVSQTVV3HJ2UUCI 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
