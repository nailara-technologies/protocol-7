# 9P (Plan 9) Protocol Server Implementation

## Overview

Protocol-7 includes a 9P (Plan 9 Filesystem Protocol) server for exporting amos-term 3D buffers as mountable filesystems. This replaces the abandoned FUSE 2.x approach due to modern glibc incompatibility.

## Architecture

### Module Structure

```
plan-9.config                    - Server configuration (port, host)
plan-9.protocol.constants        - 9P message type constants
plan-9.protocol.codec            - Wire format encoding/decoding
plan-9.protocol.error            - Error response helper
plan-9.server                    - Main server and connection handling
plan-9.server.export_buffer      - Buffer export utility
plan-9.server.handle_version     - Tversion/Rversion handler
plan-9.server.handle_attach      - Tattach/Rattach handler
plan-9.server.handle_walk        - Twalk/Rwalk handler
plan-9.server.handle_io          - Open/Read/Write/Clunk/Stat handlers
amos-term.cmd.mount-9p           - User command to mount buffers
```

### Filesystem Layout

When mounted, each exported buffer appears as:

```
/mnt/amos-term/
└── AMOSXXXXXX/           # Buffer directory (named by AMOS ID)
    ├── z-0               # Layer 0 content
    ├── z-1               # Layer 1 content
    ├── ...
    ├── z-12              # Layer 12 content
    └── metadata          # Buffer information
```

## Usage

### Start the 9P Server

```bash
# In amos-term
mount-9p <buffer_id> [mount_point]

# Examples:
mount-9p amos:ABC123DEF0
mount-9p name:my-session /mnt/my-buffer
mount-9p <session_id> /tmp/export
```

### Mount with Kernel 9P

```bash
# Create mount point
sudo mkdir -p /mnt/amos-term/AMOSXXXXXX

# Mount via kernel 9P
sudo mount -t 9p 127.0.0.1 /mnt/amos-term/AMOSXXXXXX \
    -o port=15640,trans=tcp,uname=root

# Or shorter form (if buffer is already exported)
sudo mount -t 9p 127.0.0.1:/AMOSXXXXXX /mnt/buffer -o port=15640,trans=tcp

# Unmount
sudo umount /mnt/amos-term/AMOSXXXXXX
```

### Using 9pfs (FUSE-based 9P client)

```bash
# Install 9pfs
sudo apt-get install 9pfs

# Mount
9pfs 127.0.0.1:15640 /mnt/buffer
```

## Protocol Details

### Message Types Supported

| Type | Value | Description |
|------|-------|-------------|
| Tversion | 100 | Protocol version negotiation |
| Tattach  | 104 | Attach to filesystem root |
| Twalk    | 110 | Walk directory tree |
| Topen    | 112 | Open file |
| Tread    | 116 | Read file/directory |
| Twrite   | 118 | Write to file |
| Tclunk   | 120 | Release fid |
| Tstat    | 124 | Get file attributes |

### Wire Format

All messages follow the 9P2000 format:
```
[4: size] [1: type] [2: tag] [payload...]
```

### Qid Structure

```
[1: type] [4: version] [8: path]
```

## Configuration

Edit `modules/plan-9.config`:

```perl
return {
    'port'     => 15640,      # TCP port to listen on
    'host'     => '127.0.0.1', # Bind address
    'max_msize' => 65536,     # Max message size
    'auth_required' => 0,     # Authentication (future)
};
```

## Advantages Over FUSE 2.x

1. **Native Linux Support**: 9P has been in Linux kernel since 2.6.14
2. **No Kernel Module**: Works with stock kernel, no compilation needed
3. **Simple Protocol**: Text-based, easier to debug than FUSE
4. **Network Transparent**: Can export buffers over network
5. **QEMU/Container Support**: Native integration with virtualization

## Security Notes

- Server binds to 127.0.0.1 by default (local only)
- No authentication implemented yet (9P2000 auth is complex)
- Buffer access is read/write - changes affect live buffers
- Future: integrate with auth zenka for authentication

## Future Enhancements

- Authentication via auth zenka
- Wstat support (file modification)
- Create/Remove for dynamic layer creation
- Flush support for write caching
- Multiple buffer exports per server instance
- Unix domain socket transport option

## References

- [9P Protocol Specification](http://man.cat-v.org/plan_9/5/intro)
- [Linux 9P Documentation](https://www.kernel.org/doc/Documentation/filesystems/9p.txt)
- [cat-v.org 9P Resources](http://cat-v.org/plan_9/4th_edition/papers/9p/)

#,,.,,..,,.,.,,..,...,,,,,,,.,.,,,,.,,.,.,...,..,,...,...,,..,...,.,,,..,,,,,,
#PD5MV5RNSTTRCRVC7VA4FG5YQNQZAVVPW6ZH6YDDFSQTEQRCF2GMA6EOEQIVSQ2APR5TAY5YL5GRS
#\\\|PEPEMYAQG5UR2A4QVX3U3BUSWA3LEKXMRTWEP3XCEB7MFLYQSN4 \ / AMOS7 \ YOURUM ::
#\[7]KVJ3JZUQ5E2U2QAFUR2SGV3ID47XCSSTID6GQ7JCOCAV4LRSTGBI 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
