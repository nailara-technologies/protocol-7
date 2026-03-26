# protocol.amos-term Architecture

## Overview

First-class window/buffer management for 3D terminal using Protocol-7's session and event system. Windows are addressable objects with AMOS checksum IDs, attached to routable events.

## Design Principles

1. **Windows as Sessions**: Each window/buffer is a session in `$data{'session'}{$id}`
2. **AMOS Checksum IDs**: Windows identified by `amos-chksum` (42-bit truncated)
3. **Protocol Namespace**: `protocol.amos-term` for window operations
4. **Plugin System**: Reloadable extensions for decoding/routing
5. **Event Integration**: Native Event.pm watcher integration

## Protocol Registration

```perl
## protocol.amos-term.init_code
$data{'protocol'}{'amos-term'} = {
    'connect' => {
        'callback' => undef,           # windows created via API, not connect
        'banner'   => ''
    },
    'state' => {
        '0' => {                       # window created, awaiting buffer
            'read-mode' => 'linewise',
            'input'  => { 'handler' => 'amos-term.handler.command' },
            'output' => { 'handler' => 'amos-term.handler.output' },
            'error'  => { 'handler' => 'base.handler.session_error' }
        },
        '1' => {                       # window active with buffer
            'read-mode' => 'binary',   # 3D buffer data
            'input'  => { 'handler' => 'amos-term.handler.buffer_input' },
            'output' => { 'handler' => 'amos-term.handler.render' }
        }
    }
};
```

## Window Identity

### AMOS Checksum Generation
```perl
## amos-term.window.create
my $window_id = <[chk-sum.bmw.filesum]>->(256, "$client_name:$session_id:$timestamp");
my $amos_id   = substr($window_id, 0, 10);  # 42-bit AMOS identifier
```

### Window Structure
```perl
$window = {
    ## Identity ##
    'amos_id'     => 'K9M2P7L4N8',     # AMOS checksum (display/address)
    'session_id'  => $sid,              # Internal session ID
    'client_name' => 'term-001',        # User-defined name
    
    ## 3D Buffer ##
    'buffer' => {
        'dimensions' => [8, 7, 13],     # X, Y, Z
        'voxels'     => $shm_ref,       # SHM reference
        'cursor'     => { x => 0, y => 0, z => 0 },
        'frame_node' => 57              # Frame intelligence at 56+1
    },
    
    ## Display ##
    'window' => {
        'gtk_window' => $gtk_win,
        'cairo_surface' => $surface,
        'fullscreen' => FALSE,
        'geometry'   => '640x480',
        'alpha'      => 0.95
    },
    
    ## Event Management ##
    'watchers' => {
        'render'   => $render_timer,    # 60 FPS
        'input'    => $input_watcher,
        'buffer'   => $shm_watcher      # buffer change events
    }
};
```

## Addressing System

### Numeric (Session ID)
```perl
<[amos-term.cmd.buffer.write]>->($session_id, $data);
```

### AMOS Checksum
```perl
<[amos-term.cmd.buffer.write]>->('amos:K9M2P7L4N8', $data);
```

### Client Name
```perl
<[amos-term.cmd.buffer.write]>->('name:term-001', $data);
```

### Routed Events
```perl
## Event routing uses 'amos-term' protocol prefix
$event = {
    'target'  => 'amos-term:K9M2P7L4N8',
    'command' => 'buffer.write',
    'data'    => $voxel_data
};
```

## Command API (Object-Oriented Style)

### Window Lifecycle
```perl
## Create window
my $win_id = <[amos-term.window.create]>->({
    'client_name' => 'editor-main',
    'geometry'    => '800x600',
    'fullscreen'  => FALSE
});

## Open/close
<[amos-term.window.open]>->($win_id);      # Show GTK window
<[amos-term.window.close]>->($win_id);     # Hide (keep buffer)
<[amos-term.window.destroy]>->($win_id);   # Destroy window + buffer

## Move/resize
<[amos-term.window.move]>->($win_id, $x, $y);
<[amos-term.window.resize]>->($win_id, $w, $h);
<[amos-term.window.fullscreen]>->($win_id, TRUE);
```

### Buffer Operations
```perl
## Write to 3D buffer
<[amos-term.buffer.write]>->($win_id, $x, $y, $z, $char, $color);

## Read from buffer
my $voxel = <[amos-term.buffer.read]>->($win_id, $x, $y, $z);

## Z-navigation (history)
<[amos-term.buffer.shift_z]>->($win_id);   # Push to Z+1
<[amos-term.buffer.get_z]>->($win_id, 5);  # Get Z-layer 5

## Cursor
<[amos-term.cursor.move]>->($win_id, $dx, $dy, $dz);
<[amos-term.cursor.set_pos]>->($win_id, $x, $y, $z);
```

### Render Control
```perl
## Config
<[amos-term.render.set_fps]>->($win_id, 60);
<[amos-term.render.set_curve]>->($win_id, 'gaussian_pulse');
<[amos-term.render.set_alpha]>->($win_id, 0.9);

## Force render
<[amos-term.render.redraw]>->($win_id);
```

## Plugin System

### Plugin Registration
```perl
## protocol.amos-term.plugin.init_code
<amos-term.plugin.decoder> = {
    'pattern-match' => 'amos-term.handler.decode.pattern',
    'entropy'       => 'amos-term.handler.decode.entropy',
    'resonance'     => 'amos-term.handler.decode.resonance'
};

<amos-term.plugin.routing> = {
    'multicast' => 'amos-term.handler.route.multicast',
    'bridge'    => 'amos-term.handler.route.bridge'
};
```

### Reloadable Extensions
```perl
## Load plugin without restart
<[amos-term.plugin.load]>->('decoder.pattern-match');
<[amos-term.plugin.reload]>->('decoder.pattern-match');
<[amos-term.plugin.unload]>->('decoder.pattern-match');
```

### Plugin Events
```perl
## Plugin receives window events
sub amos_term_plugin_handler {
    my ($window_id, $event_type, $data) = @_;
    ## Process and optionally modify
    return $modified_data;
}
```

## SHM Integration

### Buffer Naming
```
/dev/shm/amos-term/<amos_id>/buffer      # 3D voxel data
/dev/shm/amos-term/<amos_id>/cursor      # Cursor state
/dev/shm/amos-term/<amos_id>/metadata    # Window metadata
```

### Zero-Copy Access
```perl
## decoder zenka reads directly
my $shm = <[data.mount.shm.open]>->("/dev/shm/amos-term/$amos_id/buffer");
```

## Event Flow

```
User Input → GTK3 Event → amos-term.handler.input → Buffer Update
                                              ↓
Decoder Plugin ← SHM Notification ← amos-term.handler.buffer_change
                                              ↓
Render Timer → amos-term.handler.render → Cairo → GTK3 Window
```

## Comparison: httpd vs amos-term

| Feature | httpd | amos-term |
|---------|-------|-----------|
| Protocol | `http`/`https` | `amos-term` |
| Client ID | IP:port | AMOS checksum |
| State | Request/response | Window/buffer lifecycle |
| Handler | `httpd.request_handler` | `amos-term.handler.*` |
| Storage | Request buffer | 3D SHM buffer |
| Plugins | Content handlers | Decoder/routing extensions |

## Implementation Modules

```
modules/protocol.amos-term.init_code         # Protocol registration
modules/protocol.amos-term.connect_callback  # [none - API only]
modules/protocol.amos-term.command-handler   # Window commands

modules/amos-term.init_code                  # Zenka init
modules/amos-term.window.create              # Window factory
modules/amos-term.window.open                # GTK3 window open
modules/amos-term.window.close               # GTK3 window close
modules/amos-term.window.move                # Position control
modules/amos-term.window.fullscreen          # Fullscreen toggle

modules/amos-term.buffer.create              # 3D buffer allocation
modules/amos-term.buffer.write               # Write voxel
modules/amos-term.buffer.read                # Read voxel
modules/amos-term.buffer.shm_attach          # SHM mapping

modules/amos-term.render.loop                # 60 FPS render
modules/amos-term.render.cairo_draw          # Cairo drawing
modules/amos-term.render.cursor              # Cursor overlay

modules/amos-term.plugin.load                # Plugin loader
modules/amos-term.plugin.reload              # Hot reload
modules/amos-term.handler.decode.pattern     # Pattern decoder plugin
```

## Next Steps

1. Create `protocol.amos-term.init_code` with state machine
2. Implement `amos-term.window.create` with AMOS ID generation
3. GTK3 window integration with Event.pm watchers
4. Plugin loader for reloadable extensions
5. SHM buffer integration with data zenka

---

*Architecture for first-class window objects in Protocol-7*
*Signature: 7VNKDBUU6DTBNJ2OK7EMV3WTD72AHBLQTAGMKOIKBZJI2NXDZOBQ*

#,,,.,..,,,.,,,.,,...,,..,...,.,,,.,,,,.,,,.,,..,,...,...,,.,,.,.,,,.,.,.,,,.,
#M7QNVDOJ2THIDE45LTRYK6CFOQ3S2TNTGS74F6VARWJ6TNKQDEK6RM573QDGP733W5D6Y5F4LMETS
#\\\|LW25YBLQ6T5V7VXMYPKFZRVVXEJ37AZTXWRW4MG2QQPBOFON77J \ / AMOS7 \ YOURUM ::
#\[7]PG4ZVOKZQOPIGMDU4IMUXB2SZPCU4L3ZCDYEJSJAW3JZMDRXJ4AY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
