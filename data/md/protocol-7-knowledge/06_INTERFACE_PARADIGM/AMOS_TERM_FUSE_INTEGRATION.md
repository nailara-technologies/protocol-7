# amos-term FUSE Integration

## Overview

FUSE filesystem mount for 3D terminal buffers, enabling external tools and scripts to access buffer content via standard file operations.

## Mount Structure

```
/data/terminals/<amos_id>/
├── current       -> z-0 (symlink to current Z layer)
├── z-0           # Layer 0 (surface) - 112 bytes binary
├── z-1           # Layer 1 - 112 bytes binary
├── ...
├── z-12          # Layer 12 (deepest) - 112 bytes binary
├── metadata      # JSON buffer info
├── cursor        # Text cursor position "x,y,z\n"
└── attachments   # List of attached clients
```

## File Formats

### Z-Layers (z-0 to z-12)
Binary voxel data: 8 columns × 7 rows × 2 bytes = 112 bytes
- Byte 0: Color index (P7 palette)
- Byte 1: Attributes (cursor bit, alpha, etc.)

### metadata (JSON)
```json
{
  "amos_id": "K9M2P7L4N8",
  "name": "myterm",
  "session_id": 42,
  "created": "2026-03-25T10:00:00",
  "dimensions": { "x": 8, "y": 7, "z": 13 },
  "cursor": { "x": 3, "y": 2, "z": 0 },
  "state": 1,
  "visible": 1,
  "attachments": 3,
  "layer_size": 112,
  "version": "0.7.13"
}
```

### cursor
```
3,2,0
```

### attachments
```
nshell:K9M2P7L4N8:0
gtk3:K9M2P7L4N8:1
decoder:K9M2P7L4N8:2
```

## Commands

### Mount Buffer
```
mount [buffer_id] [mount_point]

Examples:
  mount                          # mount current buffer to default path
  mount amos:K9M2P7L4N8          # mount specific buffer
  mount name:myterm /mnt/term    # mount with custom path
```

### Unmount Buffer
```
umount [buffer_id|mount_point]

Examples:
  umount                         # unmount current buffer
  umount amos:K9M2P7L4N8         # unmount by AMOS ID
  umount /data/terminals/K9M2P7L4N8  # unmount by path
```

## External Access Examples

### Read Z-Layer from Shell
```bash
# Read layer 0 (surface)
xxd /data/terminals/K9M2P7L4N8/z-0

# Get metadata
cat /data/terminals/K9M2P7L4N8/metadata | jq .

# Check cursor position
cat /data/terminals/K9M2P7L4N8/cursor
```

### Python Access
```python
import json

# Read metadata
with open('/data/terminals/K9M2P7L4N8/metadata') as f:
    meta = json.load(f)
print(f"Buffer: {meta['name']} ({meta['amos_id']})")

# Read layer 0
with open('/data/terminals/K9M2P7L4N8/z-0', 'rb') as f:
    layer = f.read()
    
# Parse voxels (8x7 grid)
for y in range(7):
    for x in range(8):
        offset = (y * 8 + x) * 2
        color = layer[offset]
        attr = layer[offset + 1]
        print(f"({x},{y}): color={color}, attr={attr}")
```

### Real-time Monitoring
```bash
# Watch cursor position
watch -n 0.5 cat /data/terminals/K9M2P7L4N8/cursor

# Monitor layer changes
inotifywait -e modify /data/terminals/K9M2P7L4N8/z-0
```

## Implementation

### Modules
| Module | Purpose |
|--------|---------|
| `amos-term.fuse.init_code` | Initialize FUSE subsystem |
| `amos-term.fuse.getattr` | File attributes (stat) |
| `amos-term.fuse.readdir` | Directory listing |
| `amos-term.fuse.read` | File read operations |
| `amos-term.fuse.get_window` | Resolve AMOS ID to window |
| `amos-term.fuse.build_metadata` | Generate JSON metadata |
| `amos-term.cmd.mount_fuse` | Mount command |
| `amos-term.cmd.umount_fuse` | Unmount command |

### Dependencies
- `Fuse` Perl module (loaded on demand)
- `JSON::XS` for metadata encoding
- Kernel FUSE support (`/dev/fuse`)

## Security

- Mount permissions follow user permissions
- Read-only access to buffer data
- No write support via FUSE (use amos-term commands)
- Mounts are user-specific (not system-wide)

## Performance

- Layer reads are direct SHM access (zero-copy)
- Metadata is generated on-demand
- Symlink resolution is instant
- Suitable for real-time monitoring tools

---

*Phase 5: Data Coupling via FUSE*
*Signature: 7VNKDBUU6DTBNJ2OK7EMV3WTD72AHBLQTAGMKOIKBZJI2NXDZOBQ*

#,,,,,...,,,.,,,.,,,,,,,,,.,.,..,,..,,,.,,.,,,..,,...,...,...,.,.,,..,,..,,,.,
#DAQRAFHOJLV7D3DNK2SRHLROHKJYMJCBXEFL66RX4KUE3ULITFSNJ7NW5EZFBFZUFQDQ2GLQXP6T2
#\\\|KX4HE7RHPADJCOUOB55KMTIZ6REK3TBOXRTEP4MHSHHTMT7HQ7V \ / AMOS7 \ YOURUM ::
#\[7]4LMFUBZL6ORYAMZCHM2BYEGKI44F2CM2IXCRN4TRQ6OLYZYB7YDY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
