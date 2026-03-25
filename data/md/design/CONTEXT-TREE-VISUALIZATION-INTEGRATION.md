# Context Tree ↔ Visualization Integration

## Overview

The context tree connects directly to Protocol-7's **"network desktop"** — a layered 3D visualization system with 97 HTML visualizations across 5 categories. The context tree nodes render as interactive elements in this holographic space.

## The Network Desktop Architecture

### Core Visualization

**File:** `data/html/visual.v7.ax/grid-v14-layered.refactored.html`

A multi-layer 3D topology viewer featuring:

```javascript
// 5 recursive hyperspace scales for BASE32 5-bit addressing
const SCALE_20      = FORMATION_SPACING * 20;      // Local group
const SCALE_200     = FORMATION_SPACING * 200;     // Neighborhood
const SCALE_10000   = FORMATION_SPACING * 10000;   // Regional
const SCALE_100000  = FORMATION_SPACING * 100000;  // Continental
const SCALE_1000000 = FORMATION_SPACING * 1000000; // Global

// 13³ cube topology (2197 cells minimum processing space)
const CUBE_SIZE = 140;
const SUB_SIZE = CUBE_SIZE / 4;  // 4 sub-cubes per dimension

// Layer system with zoom-based visibility
layers = {
    mainGrid:    { vis: { rangeStart: -2.5, rangeEnd: 0.7777 } },
    hyper20:     { vis: { rangeStart: 0.3,   rangeEnd: 3.70 } },   // ×20
    hyper200:    { vis: { rangeStart: 3.4,   rangeEnd: 4.00 } },   // ×200
    hyper10000:  { vis: { rangeStart: 4.1,   rangeEnd: 5.77 } },   // ×10k
    hyper100000: { vis: { rangeStart: 5,     rangeEnd: 7.77 } },   // ×100k
    hyper1000000:{ vis: { rangeStart: 7,     rangeEnd: 13.5 } },   // ×1M
}
```

### 5 Visualization Categories (97 Files Total)

| Category | Files | Purpose | Context Tree Integration |
|----------|-------|---------|------------------------|
| **cubic-space/** | 51 | 3D topology, hyperspace | Main context tree rendering |
| **purr-field/** | 28 | Bioluminescent harmonic | Node glow, resonance patterns |
| **harmonic/** | 8 | Resonance frequencies | Standing wave visualization |
| **zenki-cosmos/** | 5 | Cosmic-scale networks | Cross-zenka context forest |
| **spectrum/** | 5 | Psychedelic portals | Context transition effects |

## Context Tree Rendering in 3D Space

### 1. Checksum → 3D Coordinate Mapping

```perl
## Server-side: Map context node to 13³ cube coordinates ##
my $render_context_node = sub {
    my ($node_checksum) = @ARG;

    # Use data zenka's topology mapper
    my $field = <[data.topology.interference.map]>->($node_checksum);
    my $coords = $field->{'spatial'}{'cube'};  # [x, y, z] in 0-12

    # Scale to visualization coordinates
    my $viz_coords = {
        'x' => $coords->[0] * 140 - 910,  # Center in 13³ space
        'y' => $coords->[1] * 140 - 910,
        'z' => $coords->[2] * 140 - 910,
    };

    # Get visual properties
    my $visual = $field->{'visual'};

    return {
        'checksum'   => $node_checksum,
        'position'   => $viz_coords,
        'color'      => $visual->{'rgba'},         # [r,g,b,a]
        'glow'       => $visual->{'emission'},     # glow radius
        'translucency' => $visual->{'translucency'},
        'layer'      => determine_layer($field),
    };
};
```

### 2. JavaScript Rendering Hook

```javascript
// Add context tree layer to visualization
layers.contextTree = {
    label: 'Context Tree',
    enabled: true,
    color: '#00d4ff',
    vis: { rangeStart: -2, rangeEnd: 8, fade: 2.0 },
    render: {
        baseAlpha: 0.8,
        alphaScale: 0.9,
        maxAlpha: 0.95,
        hue: 190,        // Cyan - context color
        light: 50,
        lineWidth: 1.5
    },
    nodes: [],      // Populated from server
    edges: [],      // Parent-child connections
    ghosts: [],     // Intent trajectories
    workholes: [],  // Shortcut tunnels
};

// Render context tree nodes
function renderContextTree() {
    const layer = layers.contextTree;
    if (!layer.enabled || layer.visibility <= 0) return;

    for (const node of layer.nodes) {
        // Project 3D to 2D
        const projected = project(node.x, node.y, node.z);
        if (!projected) continue;

        // Draw node glow (from purr-field visual style)
        const glowRadius = node.glow * layer.visibility;
        const gradient = ctx.createRadialGradient(
            projected.x, projected.y, 0,
            projected.x, projected.y, glowRadius
        );
        gradient.addColorStop(0, `rgba(${node.color.join(',')})`);
        gradient.addColorStop(1, 'transparent');

        ctx.fillStyle = gradient;
        ctx.beginPath();
        ctx.arc(projected.x, projected.y, glowRadius, 0, Math.PI * 2);
        ctx.fill();

        // Draw node core
        ctx.fillStyle = `rgba(255,255,255,${0.9 * layer.visibility})`;
        ctx.beginPath();
        ctx.arc(projected.x, projected.y, 3, 0, Math.PI * 2);
        ctx.fill();

        // Draw checksum label (if zoomed in)
        if (manualZoom > 0.5) {
            ctx.fillStyle = `rgba(200,230,255,${0.7 * layer.visibility})`;
            ctx.font = '10px monospace';
            ctx.fillText(node.checksum.slice(0, 7), projected.x + 8, projected.y);
        }
    }

    // Draw edges (parent-child relationships)
    ctx.strokeStyle = `rgba(0,212,255,${0.3 * layer.visibility})`;
    ctx.lineWidth = 0.5;
    for (const edge of layer.edges) {
        const from = project(edge.from.x, edge.from.y, edge.from.z);
        const to = project(edge.to.x, edge.to.y, edge.to.z);
        if (!from || !to) continue;

        ctx.beginPath();
        ctx.moveTo(from.x, from.y);
        ctx.lineTo(to.x, to.y);
        ctx.stroke();
    }
}
```

### 3. Intent Ghost Visualization

```javascript
// Render "ghosts" - pending context traversals
function renderIntentGhosts() {
    const layer = layers.contextTree;
    const time = performance.now() / 1000;

    for (const ghost of layer.ghosts) {
        const from = project(ghost.from.x, ghost.from.y, ghost.from.z);
        const to = project(ghost.to.x, ghost.to.y, ghost.to.z);
        if (!from || !to) continue;

        // Animate trajectory
        const progress = (time % 3) / 3;  // 3-second cycle
        const currentX = from.x + (to.x - from.x) * progress;
        const currentY = from.y + (to.y - from.y) * progress;

        // Draw as fading trail
        const trailLength = 20;
        for (let i = 0; i < trailLength; i++) {
            const t = progress - (i / trailLength);
            if (t < 0) continue;

            const tx = from.x + (to.x - from.x) * t;
            const ty = from.y + (to.y - from.y) * t;
            const alpha = (1 - t) * 0.5 * layer.visibility;

            ctx.fillStyle = `rgba(255,100,200,${alpha})`;  // Pink = intent
            ctx.beginPath();
            ctx.arc(tx, ty, 2 * (1 - t/2), 0, Math.PI * 2);
            ctx.fill();
        }
    }
}
```

### 4. Workhole Shortcut Visualization

```javascript
// Render workholes as shortcut tunnels
function renderWorkholes() {
    const layer = layers.contextTree;

    for (const wh of layer.workholes) {
        // Draw tunnel entrance
        const from = project(wh.from.x, wh.from.y, wh.from.z);
        const to = project(wh.to.x, wh.to.y, wh.to.z);
        if (!from || !to) continue;

        // Pulsing tunnel effect
        const pulse = Math.sin(performance.now() / 200) * 0.5 + 0.5;

        // Draw tunnel as dashed line with glow
        ctx.save();
        ctx.setLineDash([5, 5]);
        ctx.strokeStyle = `rgba(200,100,255,${(0.4 + pulse * 0.3) * layer.visibility})`;
        ctx.lineWidth = 2 + pulse * 2;
        ctx.shadowBlur = 10;
        ctx.shadowColor = 'rgba(200,100,255,0.5)';

        ctx.beginPath();
        ctx.moveTo(from.x, from.y);
        ctx.lineTo(to.x, to.y);
        ctx.stroke();
        ctx.restore();

        // Label bandwidth
        if (manualZoom > 1) {
            const midX = (from.x + to.x) / 2;
            const midY = (from.y + to.y) / 2;
            ctx.fillStyle = `rgba(200,150,255,${0.8 * layer.visibility})`;
            ctx.font = '9px monospace';
            ctx.fillText(`${wh.bandwidth}bps`, midX, midY);
        }
    }
}
```

## Server→Client Data Flow

### WebSocket Protocol

```perl
## Server: context.tree.visual.stream ##
my $stream_visual_updates = sub {
    my ($client_id) = @ARG;

    return sub {
        my ($event) = @ARG;

        # Format for visualization
        my $update = {
            'type' => $event->{'type'},  # node_add, node_remove, ghost, workhole
            'data' => encode_for_vis($event),
        };

        # Send to client
        <[protocol.ws.send]>->($client_id, $update);
    };
};

sub encode_for_vis {
    my ($event) = @ARG;

    my $field = <[data.topology.interference.map]>->($event->{'checksum'});
    my $coords = $field->{'spatial'}{'cube'};

    return {
        'checksum'  => $event->{'checksum'},
        'x'         => $coords->[0] * 140 - 910,
        'y'         => $coords->[1] * 140 - 910,
        'z'         => $coords->[2] * 140 - 910,
        'color'     => $field->{'visual'}{'rgba'},
        'glow'      => $field->{'visual'}{'emission'},
        'parent'    => $event->{'parent_checksum'},
        'depth'     => $event->{'tree_depth'},
    };
}
```

### Client Update Handler

```javascript
// WebSocket connection to context tree visual stream
const ws = new WebSocket('wss://localhost:4200/context-tree-visual');

ws.onmessage = (event) => {
    const update = JSON.parse(event.data);
    const layer = layers.contextTree;

    switch(update.type) {
        case 'node_add':
            layer.nodes.push(update.data);
            if (update.data.parent) {
                layer.edges.push({
                    from: update.data.parent,
                    to: update.data.checksum
                });
            }
            break;

        case 'node_remove':
            layer.nodes = layer.nodes.filter(n => n.checksum !== update.data.checksum);
            layer.edges = layer.edges.filter(e =>
                e.from !== update.data.checksum &&
                e.to !== update.data.checksum
            );
            break;

        case 'ghost':
            layer.ghosts.push({
                from: update.data.from_coords,
                to: update.data.to_coords,
                timestamp: Date.now()
            });
            // Remove old ghosts after 30 seconds
            layer.ghosts = layer.ghosts.filter(
                g => Date.now() - g.timestamp < 30000
            );
            break;

        case 'workhole':
            layer.workholes.push(update.data);
            break;
    }
};
```

## Interactive Features

### 1. Click to Select Context Node

```javascript
// Raycasting for node selection
canvas.addEventListener('click', (e) => {
    const rect = canvas.getBoundingClientRect();
    const mouseX = e.clientX - rect.left;
    const mouseY = e.clientY - rect.top;

    // Find closest node to click
    let closest = null;
    let closestDist = Infinity;

    for (const node of layers.contextTree.nodes) {
        const projected = project(node.x, node.y, node.z);
        if (!projected) continue;

        const dist = Math.hypot(projected.x - mouseX, projected.y - mouseY);
        if (dist < 20 && dist < closestDist) {
            closest = node;
            closestDist = dist;
        }
    }

    if (closest) {
        // Select this node
        selectedNode = closest;

        // Jump camera to it
        selX = closest.x / 140;
        selY = closest.y / 140;
        selZ = closest.z / 140;

        // Request node details from server
        ws.send(JSON.stringify({
            action: 'get_node_details',
            checksum: closest.checksum
        }));
    }
});
```

### 2. Keyboard Navigation

```javascript
// Navigate context tree with keyboard
document.addEventListener('keydown', (e) => {
    if (!selectedNode) return;

    switch(e.key) {
        case 'ArrowUp':
            // Jump to parent
            const parent = findParentEdge(selectedNode);
            if (parent) selectNode(parent.from);
            break;

        case 'ArrowDown':
            // Jump to first child
            const child = findChildEdge(selectedNode);
            if (child) selectNode(child.to);
            break;

        case 'Enter':
            // Expand/collapse node
            ws.send(JSON.stringify({
                action: 'toggle_expansion',
                checksum: selectedNode.checksum
            }));
            break;
    }
});
```

## Layer Integration with Existing Visuals

### Combining with Purr-Field (Bioluminescence)

```javascript
// Context nodes inherit purr-field glow dynamics
function renderContextWithPurr() {
    const ctxLayer = layers.contextTree;
    const purrLayer = layers.purrField;  // From purr-field visualization

    for (const node of ctxLayer.nodes) {
        // Get interference from purr field at this position
        const interference = calculateInterference(
            node.x, node.y, node.z,
            purrLayer.waves
        );

        // Modulate glow by interference
        node.effectiveGlow = node.glow * (1 + interference.constructive);

        // Color shift by phase
        const phaseShift = interference.phase * 60;  // Hue shift
        node.effectiveColor = shiftHue(node.color, phaseShift);
    }
}
```

### Combining with Zenki-Cosmos (Cosmic Scale)

```javascript
// At extreme zoom, show context forest as cosmic clusters
if (manualZoom < 0.0001) {
    // Aggregate context trees by zenka
    const clusters = aggregateByZenka(layers.contextTree.nodes);

    for (const cluster of clusters) {
        // Render as cosmic body (from zenki-cosmos style)
        renderCosmicBody({
            x: cluster.centerX,
            y: cluster.centerY,
            z: cluster.centerZ,
            mass: cluster.nodeCount,
            color: cluster.dominantColor,
            glow: Math.log10(cluster.nodeCount) * 10
        });
    }
}
```

## Summary: The Network Desktop

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                         PROTOCOL-7 NETWORK DESKTOP                            │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                               │
│  VISUALIZATION LAYERS                                                        │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │  Layer: Context Tree [Cyan]                                         │   │
│  │  ├── Nodes: Checksum-addressed content (glowing orbs)               │   │
│  │  ├── Edges: Parent-child relationships (lines)                      │   │
│  │  ├── Ghosts: Intent trajectories (animated trails)                  │   │
│  │  └── Workholes: Shortcuts (pulsing tunnels)                         │   │
│  ├─────────────────────────────────────────────────────────────────────┤   │
│  │  Layer: Purr Field [Magenta]                                        │   │
│  │  └── Bioluminescent harmonic interference                           │   │
│  ├─────────────────────────────────────────────────────────────────────┤   │
│  │  Layer: Main Grid [Blue]                                            │   │
│  │  └── 13³ cube topology base                                         │   │
│  ├─────────────────────────────────────────────────────────────────────┤   │
│  │  Layers: Hyper ×20, ×200, ×10k, ×100k, ×1M [Purple gradient]        │   │
│  │  └── Recursive scale levels (zoom-dependent visibility)             │   │
│  └─────────────────────────────────────────────────────────────────────┘   │
│                                                                               │
│  DATA SOURCES                                                                │
│  ├── data.topology.interference.map → 13³ coordinates + field tensor    │   │
│  ├── data.init_holographic → Intent registry, workholes                    │   │
│  ├── context.tree.data.map → Context node metadata                         │   │
│  └── discover/nodes zenki → Remote context sources                         │   │
│                                                                               │
│  INTERACTION                                                                 │
│  ├── Mouse: Rotate, zoom, select nodes                                     │   │
│  ├── Keyboard: Navigate tree, expand/collapse                              │   │
│  └── WebSocket: Real-time updates from server                              │   │
│                                                                               │
└─────────────────────────────────────────────────────────────────────────────┘
```

The context tree isn't just storage — it's a **navigable, visual, interactive holographic knowledge space**! 🌐✨

---

#,,.,,...,,.,,,,.,.,.,.,.,...,,.,,.,.,.,.,,,.,.,.,...,...,..,,,.,,.,,,.,.,...,
#6PC7BZIKSVSMDSS64PGS5SC3CUHEGOLAFC2GC5JDQQOPXV6RMLPY4HWJAFOPWAYINEYIU32BALIHW
#\\\|XQ4JA264SN7WY2NVEWBOG2GMEORCGE4WYHVR2W4PPNZ5IOWNVLY \ / AMOS7 \ YOURUM ::
#\[7]26EVEV5FM3RTFT6R2N5H5ORQ653FAJZWQTEPSLLAPXDH5AX7ZKAY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
