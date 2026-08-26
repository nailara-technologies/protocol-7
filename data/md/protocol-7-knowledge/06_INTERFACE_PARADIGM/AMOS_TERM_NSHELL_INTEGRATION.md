# amos-term nshell Integration

## Generic Buffer Attachment System

The amos-term 3D terminal supports simultaneous multi-client access through a generic attachment system. Any number of clients (nshell, GTK3 windows, network connections, decoders) can attach to the same 3D buffer with independent cursors.

## Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                    3D Buffer (8×7×13 voxels)                     │
│                    AMOS ID: K9M2P7L4N8                          │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  ┌──────────┐  ┌──────────┐  ┌──────────┐  ┌──────────┐        │
│  │ nshell   │  │ GTK3     │  │ decoder  │  │ network  │        │
│  │ client   │  │ window   │  │ plugin   │  │ client   │        │
│  │ cursor   │  │ cursor   │  │ (read-only)│  │ cursor   │        │
│  │ (0,0,0)  │  │ (3,2,5)  │  │ scan all │  │ (7,6,0)  │        │
│  └────┬─────┘  └────┬─────┘  └────┬─────┘  └────┬─────┘        │
│       │             │             │             │               │
│       └─────────────┴─────────────┴─────────────┘               │
│                     │                                           │
│                     ▼                                           │
│         ┌───────────────────────┐                               │
│         │   SHM Buffer          │                               │
│         │   /dev/shm/amos-term/ │                               │
│         └───────────────────────┘                               │
└─────────────────────────────────────────────────────────────────┘
```

## Attachment Structure

Each client attachment has:
- **Unique ID**: `nshell:K9M2P7L4N8:0`
- **Client type**: `nshell`, `gtk3`, `decoder`, `network`
- **Independent cursor**: (x, y, z) position
- **Viewport**: Optional offset and dimensions
- **Mode flags**: read/write/cursor_visible/follow

## Commands

### Attach to Buffer
```
attach <buffer_id> [client_type]

Examples:
  attach amos:K9M2P7L4N8 nshell     # attach nshell to buffer
  attach name:myterm generic         # attach generic client
  attach current                     # attach to current (for nshell)
```

### List Attachments
```
attachments [buffer_id]

Example output:
  Buffer: myterm [K9M2P7L4N8]
  3 active attachment(s):
    nshell:K9M2P7L4N8:0    | nshell     | cursor(0,0,0) | RW
    gtk3:K9M2P7L4N8:1      | gtk3       | cursor(3,2,5) | RW
    decoder:K9M2P7L4N8:2   | decoder    | cursor(0,0,0) | RO
```

### Detach
```
detach <attach_id>

Example:
  detach nshell:K9M2P7L4N8:0
```

## nshell Bridge

When nshell attaches to a buffer:

1. **Output Redirection**: nshell output goes to 3D buffer Z=0
2. **History Shift**: Newlines trigger Z+1 (history push)
3. **Cursor Sync**: nshell cursor syncs to attachment cursor
4. **Multi-client Aware**: Other clients see changes via callbacks

```perl
## In nshell init or via command:
<[amos-term.nshell.bridge]>->('amos:K9M2P7L4N8', <nshell.state>);

## Or via command:
attach amos:K9M2P7L4N8 nshell
```

## Client Types

| Type | Use Case | Default Mode |
|------|----------|--------------|
| `nshell` | Terminal I/O bridge | RW |
| `gtk3` | GUI window display | RW |
| `decoder` | Pattern analysis | RO |
| `network` | Remote client | RW |
| `generic` | Custom client | RO |

## Implementation

### Generic Attachment
```perl
my $attach = <[amos-term.buffer.attach_generic]>->(
    $buffer_id,
    'client_type',
    {
        cursor_x => 0,
        cursor_y => 0,
        cursor_z => 0,
        write    => TRUE,
        read     => TRUE,
        notify_others => TRUE,  # callback on new attachments
    }
);
```

### nshell-Specific Bridge
```perl
<[amos-term.nshell.bridge]>->($buffer_id, $nshell_state);
```

This:
- Attaches nshell client
- Redirects output handler
- Sets up change callbacks
- Stores attachment ref in nshell state

## Simultaneous Access Scenarios

### Scenario 1: nshell + GTK3 Window
```
1. GTK3 window opens with buffer
2. nshell attaches to same buffer
3. Type in nshell → appears in GTK3 window
4. Navigate in GTK3 → nshell cursor updates
5. Both see same history (Z-layers)
```

### Scenario 2: Multiple nshell Sessions
```
1. nshell A attaches to buffer X
2. nshell B attaches to buffer X (different cursor)
3. Both can write (race conditions possible)
4. Both see same Z-history
```

### Scenario 3: Read-Only Decoder
```
1. Decoder attaches RO to buffer
2. Scans Z-layers for patterns
3. Triggers visual highlights on matches
4. Doesn't interfere with RW clients
```

## DS-Terminal Font

The DS-Terminal font (`data/ttf/DS-Terminal/ds-term.ttf`) is available for 3D terminal rendering - monospaced, terminal-optimized.

## Module Reference

| Module | Purpose |
|--------|---------|
| `amos-term.buffer.attach_generic` | Generic multi-client attachment |
| `amos-term.buffer.detach` | Remove attachment |
| `amos-term.nshell.bridge` | nshell-specific integration |
| `amos-term.cmd.attach_buffer` | Command interface |
| `amos-term.cmd.list_attachments` | List active clients |

---

*Phase 3: nshell Integration with Generic Buffer Attachment*
*Signature: 7VNKDBUU6DTBNJ2OK7EMV3WTD72AHBLQTAGMKOIKBZJI2NXDZOBQ*

#,,,.,...,,,.,,,.,...,,,.,.,.,..,,,..,...,,,.,..,,...,...,...,,..,.,.,..,,,.,,
#ZNTVRLJGRGCIYER3COKY24PCZ3K6UTXHNJ4BGBS64V3UIFOKZLT2GIOBVVWPQIVFLBTIGLLBTK6DA
#\\\|FLWDJFGB6YEBKWAD2EHEEFDUM7TZGYIS5C3N6QWLXWXHP7Z27EJ \ / AMOS7 \ YOURUM ::
#\[7]DJHQMK4ZA5ULHWJQHXGBAPAQOVIZBTBR6F6KADUTZYBYCBKEA6CA 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
