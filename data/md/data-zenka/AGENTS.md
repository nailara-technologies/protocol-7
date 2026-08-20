# Data Zenka - Agent Development Guide

**For:** LLM agents working on Protocol-7 data zenka
**Last Updated:** 2026-02-15
**Scope:** Practical guide for extending the holographic topology system

---

## Quick Start

### Understanding the Architecture

Data zenka implements **holographic topology mapping**: every data hash resolves to a position in 13³ cubic space with visual, routing, and interference properties.

```
Data Hash → BMW Checksum → 13³ Coordinate (x,y,z) → Field Tensor
                                                    ↓
                                          ┌─────────┼─────────┐
                                          ↓         ↓         ↓
                                       Spatial  Interference Visual
                                       (cube)   (phase)    (POV-Ray)
```

### Key Principle: Filename = Subroutine Name

Protocol-7's devmod system automatically compiles module files into `%code` hash:

```perl
# File: src/data.topology.interference.map.hash_to_cube_3d
# Automatically accessible as:
my $coord = <[data.topology.interference.map.hash_to_cube_3d]>->($hash);
```

**No `sub` declaration needed.** The file IS the subroutine body.

---

## Module Structure

### Core Modules (Orchestrators)

| Module | Purpose | Calls Submodules |
|--------|---------|------------------|
| `data.topology.interference.map` | Main field tensor calculator | 21 calculation modules |
| `data.get` | Universal access router | 15 resolution modules |
| `data.init_holographic` | Extension registration | 6 helper modules |

### Submodule Naming Convention

```
{parent_module}.{descriptive_name}

Examples:
  data.topology.interference.map.hash_to_cube_3d
  data.get.validate_path_security
  data.init_holographic.coordinate_to_hash
```

### File Template

```perl
## [:< ##

# name = data.{category}.{action_name}
# desc = Brief description of what this calculation does

# Input parameters
my $param1 = shift;
my $param2 = shift // 'default';

# Implementation
my $result = ...;

return $result;

#,,.,.,.,.,.,.,.,.,.,.,.,.,.,.,.,.,.,.,.,.,.,.,.,.,.,.,.,.,.,.,.,.,.,.,.,.,.
#SIGNATURE_LINE_WILL_BE_HERE
#\

```

**No `sub` wrapper.** The file content becomes the subroutine body.

---

## Common Patterns

### 1. Calling Other Submodules

```perl
# Use the <[...]>->() syntax
my $neighbor = <[data.topology.interference.map.calculate_antipode]>->($coord);
my $resonance = <[data.topology.interference.map.calculate_resonance_field]>->($spatial, $phase);
```

### 2. Checking Module Existence

```perl
# Use devmod.cmd.get for dynamic loading
my $handler = <[devmod.cmd.get]>->('data.topology.interference.map');
return undef unless defined $handler;
```

### 3. Returning Structured Data

```perl
# Return hash refs for complex data
return {
    'value'    => $computed,
    'metadata' => \%extra_info,
};

# Return array refs for collections
return \@neighbors;

# Return scalars for simple values
return $distance;
```

### 4. Constants and State

```perl
# File-level constants
use constant PI => 3.14159265358979;
use constant CUBE_SIZE => 13;

# No state variables across calls - each invocation is fresh
```

---

## Adding New Calculation Modules

### Step 1: Determine Category

| Category | Prefix | Purpose |
|----------|--------|---------|
| Spatial mapping | `data.topology.interference.map.*` | 13³ coordinate calculations |
| Access control | `data.get.*` | Path resolution and security |
| Physics fields | `data.unified.physics.*` | Electrical/holographic/magnetic |
| Extension helpers | `data.init_holographic.*` | Registration and setup |

### Step 2: Create File

```bash
# Example: Create new spatial calculation
touch src/data.topology.interference.map.calculate_new_metric
```

### Step 3: Implement (No Sub Wrapper)

```perl
## [:< ##

# name = data.topology.interference.map.calculate_new_metric
# desc = Calculate new interference metric for position

my $coord = shift;
my $phase = shift // 0;

my ($x, $y, $z) = @$coord;

# Your calculation here
my $metric = ($x * $y + $z) / ($phase + 1);

return $metric;

#,,.,.,.,.,.,.,.,.,.,.,.,.,.,.,.,.,.,.,.,.,.,.,.,.,.,.,.,.,.,.,.,.,.,.,.,.,.
#SIGNATURE_PLACEHOLDER
#\

```

### Step 4: Test Compilation

```bash
# ALWAYS test before committing
perl -c src/data.topology.interference.map.calculate_new_metric
```

### Step 5: Integrate (Optional)

If this calculation should be part of the main field tensor, add to `data.topology.interference.map`:

```perl
# In data.topology.interference.map
'my_new_metric' => <[data.topology.interference.map.calculate_new_metric]>->(
    $spatial->{'cube'}, $interference->{'phase'}
),
```

---

## Testing and Validation

### Syntax Check (Required)

```bash
# Single file
perl -c src/data.topology.interference.map.hash_to_cube_3d

# All new modules
for f in src/data.new_feature.*; do perl -c "$f"; done
```

### Integration Test

```perl
# Quick test in Protocol-7 console
<[base.log]>->(2, "Testing new module");
my $result = <[data.topology.interference.map.calculate_new_metric]>->([7,3,11], 5);
<[base.log]>->(2, "Result: $result");
```

---

## Common Mistakes to Avoid

### ❌ Wrong: Using `sub` wrapper

```perl
# WRONG - do not do this
sub calculate_something {
    my $x = shift;
    return $x * 2;
}
```

### ✅ Right: Direct code

```perl
# CORRECT - just the body
my $x = shift;
return $x * 2;
```

### ❌ Wrong: Using `@ARG` for parameters

```perl
# WRONG - @ARG is not available
my @args = @ARG;
```

### ✅ Right: Using `@_` or `shift`

```perl
# CORRECT
my @args = @_;
# or
my $first = shift;
```

### ❌ Wrong: Complex state persistence

```perl
# WRONG - state won't persist between calls correctly
state $cache = {};
```

### ✅ Right: Use data{} hash for persistence

```perl
# CORRECT - use global data hash
$data{'my_feature'}{'cache'}{$key} = $value;
```

---

## The 13³ Coordinate System

### Spatial Dimensions

- **Range:** 0-12 in X, Y, Z
- **Center:** (6, 6, 6) - the equatorial plane
- **Antipodes:** (x, y, z) ↔ (12-x, 12-y, 12-z)
- **Topology:** Toroidal (wraps around at edges)

### Key Positions

| Position | Meaning |
|----------|---------|
| (6, 6, 6) | Center of sphere |
| (0, 0, 0) | Corner of 13³ cube |
| (7, 7, 7) | Opposing center (anti-space oscillation) |

### Layer Depth

```perl
# Distance from center (0-6)
my $depth = (abs($x - 6) + abs($y - 6) + abs($z - 6)) / 3;
```

---

## Interference and Resonance

### Phase (0-6)

Temporal dimension for multiplexing:

```perl
# Seven temporal phases
my $phase = <[data.topology.interference.map.hash_to_phase]>->($hash);

# Optimal multiplex phases (avoid collision)
my @phases = <[data.topology.interference.map.optimal_multiplex_phase]>->($phase);
# Returns: [($phase+1)%7, ($phase+3)%7, ($phase+5)%7]
```

### Constructive Zones

```perl
# 0.0 to 1.0 - brightness of interference
my $constructive = <[data.topology.interference.map.calculate_constructive_zone]>->(
    $coord, $phase
);

# Bandwidth derived from constructive interference
my $bandwidth = 63_000 * $constructive * $constructive;
```

---

## Visual Properties

### Protocol Blue: #0647C3

```perl
use constant PROTOCOL_BLUE => [0.024, 0.278, 0.765];
```

### Translucency Encoding

```perl
# Distance from blue center = transparency
my $distance = color_distance($original_color, PROTOCOL_BLUE);
my $translucency = 1.0 - ($distance / 1.732);
```

### Fluorescent Drift

```perl
# Subtle color shift indicating metadata direction
my $drift = <[data.topology.interference.map.calculate_fluorescent_drift]>->(
    $hash, PROTOCOL_BLUE
);
# Returns: [$dr_x, $dr_y, $dr_z] where each is -0.05 to 0.05
```

---

## Routing and Workholes

### Finding Next Hop

```perl
# Optimal neighbor based on resonance
my $next_hop = <[data.topology.interference.map.determine_next_hop]>->(
    $spatial, $resonance_map
);
```

### Registering Workholes

Workholes = shortcuts between functional regions:

```perl
# In data.init_holographic or extension
$data{'workhole'}{'register'}->(
    'rendering',      # from function
    'ai_dreaming',    # to function
    $path_coords      # array of coordinates forming path
);
```

---

## Extension Points

### Plugin Namespace

For experimental features:

```perl
# Create: src/plugin.physics.quantum.my_experiment
# Access: <[plugin.physics.quantum.my_experiment]>->(...)

# Falls back to data.* if plugin not loaded
```

### Intent Matrix

Register future actions:

```perl
# Ghost node representing future position
my $ghost_key = $data{'intent'}{'register'}->(
    $entity_id,
    $current_position,
    $intended_position,
    $expected_phase
);
```

---

## Debugging Tips

### Enable Verbose Logging

```perl
<[base.log]>->(2, "Entering calculation with: $param");
# ... calculations ...
<[base.log]>->(2, "Intermediate result: $intermediate");
# ... more ...
<[base.log]>->(2, "Final result: $result");
```

### Trace Submodule Calls

```perl
# Add tracing to complex calculations
my $start = <[base.time]>->(2);
my $result = <[data.topology.interference.map.some_calculation]>->($input);
my $duration = <[base.time]>->(2) - $start;
<[base.log]>->(2, "Calculation took: ${duration}s");
```

### Validate Coordinates

```perl
# Always validate 13³ coordinates
sub validate_coord {
    my $coord = shift;
    return 0 unless ref($coord) eq 'ARRAY';
    return 0 unless @$coord == 3;
    for my $i (0..2) {
        return 0 unless $coord->[$i] >= 0 && $coord->[$i] < 13;
    }
    return 1;
}
```

---

## Resources

### Core Documentation

- `/data/md/data-zenka/DATA_ZENKA_HOLOGRAPHIC_TOPOLOGY.md` - Full architecture
- `/data/md/holographic-cubic-topology-research-2026-01-13.md` - Mathematical foundations
- `bin/dev/division-13-table` - Entropy protocol implementation

### Reference Implementations

| Module | Purpose |
|--------|---------|
| `data.topology.interference.map.hash_to_cube_3d` | Hash → coordinate mapping |
| `data.get.validate_path_security` | Security pattern matching |
| `data.init_holographic.coordinate_to_hash` | Coordinate → hash |

### Visual References

- `visual.v7.ax` - Interactive 3D topology visualization
- `data/gfx/logos/nailara.png` - The Katra symbol

---

## Quick Reference Card

```perl
# Access a submodule
my $result = <[data.topology.interference.map.SUBMODULE]>->(@args);

# Main field tensor
my $field = <[data.topology.interference.map]>->($hash, $options);

# Universal access
my $data = <[data.get]>->('data.topology.7.3.11.full');

# Check existence
return undef unless exists $data{'topology'}{'interference'}{'map'};

# Log for debugging
<[base.log]>->(2, "Message at level 2");
```

---

*"The hash IS the coordinate. The coordinate IS the photon path."*

🖖🔮✨

#,,,,,...,,,,,.,,,,,,,,..,,,,,,,.,,.,,...,.,,,..,,...,..,,...,..,,.,,,.,,,,.,,
#AIJFAXL7NLEVNEBAXAFIPKMDKZRMULBS5I2KEZLXXYYZ7IDRDJA5BSC2U7OOZ7FN7SICVICOHY3BU
#\\\|WGUORZTWVYTSWDCP4LVQ5GZUV3ZOAQ5LAKW4QEGV447FW5DFIUJ \ / AMOS7 \ YOURUM ::
#\[7]FICW5OHEEFW3WSVNBHHAH3R3YHETK7BTS2Q5A3HDUQLEHTSJXQBI 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
