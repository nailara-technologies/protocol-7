# Protocol-7-Menu: Push-Based Update Architecture

## Overview

Protocol-7-menu is a **rendering layer** for dynamic menu systems. It uses **push-based updates** from provider zenki, **timestamp-indexed change propagation**, and **hash watchers** for reactive GUI updates. No polling timers—all event-driven.

## Architecture Layers

```
┌─────────────────────────────────────────────────────────────┐
│ GUI Rendering Layer (protocol-7-menu)                       │
│  • Hash watcher triggers on menu-structure change           │
│  • Diffs old vs new state                                   │
│  • Updates only changed GUI elements                        │
└──────────────────────┬──────────────────────────────────────┘
                       │ Listens for push updates
                       │
┌──────────────────────────────────────────────────────────────┐
│ Provider Zenki (weather, rss, system, etc.)                  │
│  • Maintains own data and update cycles                     │
│  • When data changes: PUSH to protocol-7-menu.menu-update   │
│  • Can implement optional .updated <timestamp> for status   │
└──────────────────────────────────────────────────────────────┘
```

## Data Flow: Push Update Cycle

### 1. Provider Registers (Startup)

```perl
# weather.zenka startup
my $menu_data = {
    'items' => {
        'forecast' => {
            'label' => 'Weather: Loading...',
            'command' => 'weather.show_detail',
        }
    }
};

<[base.protocol-7.command.send.local]>->(
    {
        'command' => 'protocol-7-menu.menu-update',
        'call_args' => { 'args' => 'weather ' . JSON::encode_json($menu_data) }
    }
);
```

### 2. Data Changes → Push Update

```perl
# weather.zenka detects new weather data
my $new_forecast = fetch_weather();

my $updated = {
    'items' => {
        'forecast' => {
            'label' => "Weather: $new_forecast->{temp}°C",
            'command' => 'weather.show_detail',
        }
    }
};

# Push the update (REVERSE ROUTE - zenka sends to protocol-7-menu)
<[base.protocol-7.command.send.local]>->(
    {
        'command' => 'protocol-7-menu.menu-update',
        'call_args' => { 'args' => 'weather ' . JSON::encode_json($updated) }
    }
);
```

### 3. Protocol-7-Menu Receives Update

```
weather.menu-update weather {items...}
    ↓
protocol-7-menu.cmd.menu-update handler executes
    ↓
Updates <protocol-7-menu.menu-structure>{providers}{weather}
    ↓
Sets <protocol-7-menu.menu-structure>{'last-changed'} = NEW_TIMESTAMP
    ↓
Hash watcher fires on 'last-changed' write
    ↓
protocol-7-menu.structure-changed handler invokes
    ↓
Diffs old vs new provider data
    ↓
Calls appropriate GUI updater:
  - add-provider-items (new provider)
  - remove-provider-items (provider removed)
  - update-provider-items (provider changed)
    ↓
GUI reflects updates immediately
```

## Core Modules

### Hash Structure & Watchers

- **`protocol-7-menu.menu-structure-init`** - Initialize canonical menu structure with change watcher
- **`protocol-7-menu.structure-changed`** - Event handler that diffs and determines what changed
- **`<protocol-7-menu.menu-structure>`** - Canonical hash, watched for changes

```perl
<protocol-7-menu.menu-structure> = {
    'last-changed' => '3OMY5G5IPO6VW',  # Timestamp updated by handler
    'providers' => {
        'weather' => {
            'items' => {
                'forecast' => {
                    'label' => 'Weather: Sunny 18°C',
                    'command' => 'weather.show_detail'
                },
                'alerts' => {
                    'label' => 'No Alerts',
                }
            }
        },
        'rss' => {
            'items' => { ... }
        }
    }
};
```

### Update Command & Handlers

- **`protocol-7-menu.cmd.menu-update`** - Command endpoint for incoming push updates from providers
- **`protocol-7-menu.add-provider-items`** - Create GUI menu items for new provider
- **`protocol-7-menu.remove-provider-items`** - Remove GUI menu items when provider unregisters
- **`protocol-7-menu.update-provider-items`** - Fine-grained diff and update of existing provider's items

### Helper Modules

- **`protocol-7-menu.provider-register`** - Helper for providers to register/update/unregister
- **`protocol-7-menu.example-provider`** - Documentation and example implementation pattern

## Optional: Status Polling with Timestamps

For optional status queries without continuous polling:

```perl
# Ask provider if they have updates
> weather.updated
< TRUE 3OMY5G5IPO6VW

# Check specific timestamp—if no changes since, same timestamp returned
> weather.updated 3OMY5G5IPO6VW
< 3OMY5G5IPO6VW  (no changes)

# Or get change tree to see what's new
> weather.updated 3OMY5G3ABCDE1
< SIZE ...
  weather.forecast = 3OMY5G5IPO6VW
  weather.alerts = 3OMY5G5IPO6VW
```

This allows **optional catch-up on startup** while remaining **fully push-driven** during operation.

## Multi-Level Provider Architecture

Composable middleware zenki possible:

```
weather.zenka (raw data)
    ↓ pushes to
weather-display.zenka (formatting/intelligence)
    ↓ pushes to
protocol-7-menu (rendering)
```

Each layer independently registers with protocol-7-menu using same protocol.

## Benefits

✅ **No polling timers** - Fully event-driven
✅ **Efficient updates** - Only changed items re-rendered
✅ **Composable** - Multi-level providers possible
✅ **Stateless renderer** - protocol-7-menu is dumb/simple
✅ **Externalized logic** - Data providers own their content
✅ **Natural cleanup** - Unregister = items disappear
✅ **Scalable** - Unlimited providers possible
✅ **Timestamp-aware** - Optional change tracking per provider

## Future Extensions

### Hash Synchronization Network (Phase 3)

```perl
# Imagine mounting remote hash branches
<[event.mount_remote_branch]>->(
    'remote_zenka.data_branch',
    'protocol-7-menu.menu-structure.providers.remote'
);

# protocol-7-menu.menu-structure now transparently syncs
# with remote zenka's data_branch over the network
```

### Session-Based Menu Hierarchies

```perl
# Providers could spawn long-lived command sessions
# to push continuous status updates
protocol-7-menu.cmd.menu-status-update
    ↓
Stays open, provider sends: "TRUE <new_status>"
    ↓
When provider disconnects or command fails:
Route collapse → menu branch recursively removed
    ↓
Natural session-aware menu lifetime
```

## Implementation Status

- ✅ Hash structure initialization with watchers
- ✅ Push update handler (`cmd.menu-update`)
- ✅ Diff-based GUI update handlers
- ✅ Provider helper module
- 🔄 Integration with graphical-menu-init (needs completion)
- 🔄 Testing with real provider zenki
- 📝 Optional: `.updated` timestamp polling endpoints in providers

## Usage Example

See `modules/protocol-7-menu.example-provider` for complete example.

Quick start:
```perl
# 1. Register on startup
<[base.protocol-7.command.send.local]>->({
    'command' => 'protocol-7-menu.menu-update',
    'call_args' => { 'args' => 'my-provider ' . JSON::encode_json($menu_data) }
});

# 2. Push update when data changes
# (same as above, with updated data)

# 3. Unregister on shutdown (optional)
<[base.protocol-7.command.send.local]>->({
    'command' => 'protocol-7-menu.menu-update',
    'call_args' => { 'args' => 'my-provider' }
});
```

---

**Architecture Vision**: Menu is a **living network dashboard** where services register themselves and push updates. Protocol-7-menu stays clean, simple, and focused purely on rendering changes. All complexity externalized to provider zenki. ✨
