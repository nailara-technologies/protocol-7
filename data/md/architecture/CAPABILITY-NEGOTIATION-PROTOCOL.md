# Capability Negotiation Protocol

## Overview

The **Capability Negotiation Protocol** provides a unified framework for session features that can be:
- Enabled/disabled at different lifecycle phases (pre-auth, post-auth, runtime)
- Locked after initial setup (preventing bypass through routing)
- Fully unloaded with code cleanup
- Managed through custom command names via aliases

This protocol replaces scattered auth-phase options with a clean, extensible architecture using a **capability registry and dispatcher pattern** with optional callbacks for complex features.

## Architecture

### Three-Layer Design

```
User/Client Layer:
  Custom command names: "select-size-mode", "enable-tracking", etc.
       ↓ (via aliases)
Interface Layer:
  auth.zenka.cmd.set-session-attribute (wrapper)
       ↓
Dispatcher Layer:
  base.handler.auth.set_session_capability (registry-based dispatcher)
       ↓ (delegates complex features)
Handler Layer:
  base.handler.auth.callback.* (focused handlers for each capability)
```

### Capability Registry

**Location**: Within `base.handler.auth.set_session_capability`

```perl
my $capability_handlers = {
    # SIMPLE CAPABILITIES (direct state setting)
    'select-size-mode' => {
        type => 'simple',
        description => 'Set session read mode (SIZE or CHRSIZE)',
        handler => sub {
            my ($session, $mode) = @_;
            return FALSE if $mode !~ m|^(SIZE|CHRSIZE)$|i;
            $session->{'mode'}{'size'} = uc($mode);
            return TRUE;
        },
        lock_after_auth => TRUE,
        min_calls => undef,
        max_calls => 1,  # Only set once
    },

    'select-strm-mode' => {
        type => 'simple',
        description => 'Set stream mode (locked or normal)',
        handler => sub {
            my ($session, $mode) = @_;
            return FALSE if $mode !~ m|^(locked|normal)$|i;
            $session->{'stream_mode'} = lc($mode);
            return TRUE;
        },
        lock_after_auth => TRUE,
        max_calls => 3,  # Limited attempts
    },

    # COMPLEX CAPABILITIES (delegated to callbacks)
    'enable-character-editing' => {
        type => 'complex',
        description => 'Enable character-stream editing (\r, \b)',
        handler => 'base.handler.auth.callback.enable_character_editing',
        lock_after_auth => TRUE,
        requires_auth => FALSE,  # Can be pre-auth
    },

    'enable-tracking' => {
        type => 'complex',
        description => 'Enable temporal proximity mapping with buffer size',
        handler => 'base.handler.auth.callback.enable_tracking',
        lock_after_auth => FALSE,  # Can be toggled
        requires_auth => FALSE,
    },

    'unload-features' => {
        type => 'complex',
        description => 'Unload capabilities (level: unsafe or full)',
        handler => 'base.handler.auth.callback.unload_features',
        lock_after_auth => FALSE,  # Can be triggered anytime
    },
};
```

### Dispatcher Implementation

```perl
# base.handler.auth.set_session_capability

my $capability = $call_args->{'cmd'}{'unalias'} // '';
my $params = $call_args->{'args'} // {};
my $cap_def = $capability_handlers->{$capability};

return error("unknown capability: $capability") if not $cap_def;

# Check if already locked
if ($cap_def->{'lock_after_auth'} && $session->{'authenticated'}) {
    # Check if this capability was already set
    if ($session->{'capabilities'}{$capability}{'locked'}) {
        return error("capability locked after authentication");
    }
}

# Dispatch to handler
my $result;
if ($cap_def->{'type'} eq 'simple') {
    # Simple: inline handler
    $result = $cap_def->{'handler'}->($session, $params);
} elsif ($cap_def->{'type'} eq 'complex') {
    # Complex: invoke callback
    $result = <[$cap_def->{'handler'}]>->($session, $call_args, $cap_def);
}

if ($result) {
    # Track in session
    $session->{'capabilities'}{$capability}{'enabled'} = 1;
    if ($cap_def->{'lock_after_auth'}) {
        $session->{'capabilities'}{$capability}{'locked'} = 1;
    }
}

return $result;
```

## Command Aliases

Map custom command names to the generic interface:

```perl
# In base.init_code or auth configuration:

$data{'alias'}{'select-size-mode'} = 'auth.zenka.cmd.set-session-attribute';
$data{'alias'}{'select-strm-mode'} = 'auth.zenka.cmd.set-session-attribute';
$data{'alias'}{'enable-character-editing'} = 'auth.zenka.cmd.set-session-attribute';
$data{'alias'}{'enable-tracking'} = 'auth.zenka.cmd.set-session-attribute';
$data{'alias'}{'unload-features'} = 'auth.zenka.cmd.set-session-attribute';
```

**Per-user customization** (if needed):
```perl
$data{'user'}{$username}{'alias'}{'my-custom-size-mode'} =
    'auth.zenka.cmd.set-session-attribute';
```

## Wrapper Command

**Location**: `auth.zenka.cmd.set-session-attribute`

```perl
# auth.zenka.cmd.set-session-attribute

my ($capability_cmd, $params) = parse_command(@_);

# Validate caller is authenticated or in pre-auth phase
return error("not authenticated") if not authorized_for_capability($capability_cmd);

# Delegate to dispatcher
my $result = <[base.handler.auth.set_session_capability]>->(
    $call_args,
    $session,
    $capability_cmd,
    $params
);

return $result ? TRUE : FALSE;
```

## Capability Types

### Simple Capabilities

**Direct state setting**, no complex logic:

```perl
'set-buffer-size' => {
    type => 'simple',
    handler => sub {
        my ($session, $buffer_size) = @_;
        return FALSE if $buffer_size !~ m|^\d+$| || $buffer_size < 1024;
        $session->{'buffer'}{'size'} = $buffer_size;
        return TRUE;
    },
}
```

**Use when**:
- Just updating session state
- No validation beyond type/range check
- No external calls needed
- No side effects (code execution, cleanup, etc.)

### Complex Capabilities

**Delegate to focused callback handler**:

```perl
'enable-tracking' => {
    type => 'complex',
    handler => 'base.handler.auth.callback.enable_tracking',
}

# Then in base.handler.auth.callback.enable_tracking:
my ($session, $call_args, $cap_def) = @_;

my $buffer_size = $call_args->{'args'}[0];

# Complex logic:
# 1. Validate buffer size
# 2. Initialize temporal mappings
# 3. Set up cube-side tracking
# 4. Configure auto-expiry
# 5. Return result

$session->{'tracking'}{'enabled'} = 1;
$session->{'tracking'}{'buffer_size'} = $buffer_size;
$session->{'temporal_map'} = {};  # Initialize

return TRUE;
```

**Use when**:
- Multiple validation steps
- Calling other handlers/routines
- Crypto operations
- Complex state initialization
- Cleanup required on disable/unload

## Lifecycle Phases

### Pre-Authentication

Features that can be enabled before full authentication:

```
Allowed:
  - enable-tracking (useful for forensics)
  - enable-character-editing (locked after auth)
  - select-size-mode (negotiation)
  - select-strm-mode (negotiation)

Flow:
  nshell: "enable-tracking buffer_size=10485760"
  cube:   "OK, tracking enabled (cannot disable later)"
```

### Post-Authentication

Features that can change after authentication:

```
Locked (cannot change):
  - enable-character-editing (locked at auth)
  - select-size-mode (locked at auth)
  - select-strm-mode (locked at auth)

Changeable (can toggle at runtime):
  - debug_level (if implemented)
  - feature_x (if runtime-modifiable)
```

### Full Unload

Cleanly remove capability, including compiled code:

```
Level 1: unload-unsafe-features
  → Disable risky operations
  → Keep safe features
  → Keep compiled code

Level 2: unload-entire-capability
  → Remove all code related to capability
  → Purge from memory
  → No recovery without re-enabling
```

## Integration Examples

### Example 1: Extract Existing Auth Option

**Current code in base.handler.auth**:
```perl
} elsif ( $input->$* =~ s|^(auth\.)?select-size-mode (?<mode>\S+)\n|| ) {
    my $req_mode = $+{mode};
    # validation and setup
}
```

**Extracted to registry**:
```perl
'select-size-mode' => {
    type => 'simple',
    handler => sub {
        my ($session, $mode) = @_;
        return FALSE if $mode !~ m|^(SIZE|CHRSIZE)$|i;
        $session->{'mode'}{'size'} = uc($mode);
        return TRUE;
    },
    lock_after_auth => TRUE,
    max_calls => 1,
}
```

**Remove from base.handler.auth**, let alias route through dispatcher.

### Example 2: Add New Complex Capability

**Create callback**:
```perl
# modules/base.handler.auth.callback.enable_new_feature

my ($session, $call_args, $cap_def) = @_;

# Validation
my $param = $call_args->{'args'}[0] // '';
return FALSE if not validate_param($param);

# Complex setup
setup_feature($session, $param);

# Initialize state
$session->{'new_feature'}{'enabled'} = 1;
$session->{'new_feature'}{'config'} = $param;

return TRUE;
```

**Add to registry**:
```perl
'enable-new-feature' => {
    type => 'complex',
    handler => 'base.handler.auth.callback.enable_new_feature',
    lock_after_auth => FALSE,
}
```

**Create alias** (optional, if custom name wanted):
```perl
$data{'alias'}{'my-custom-feature'} = 'auth.zenka.cmd.set-session-attribute';
```

**Done**. No changes to dispatcher, no scattered code.

### Example 3: Per-User Customization

```perl
# Different users can have different capability names

# User 'admin': gets all features with standard names
$data{'alias'}{'enable-tracking'} = 'auth.zenka.cmd.set-session-attribute';

# User 'guest': gets limited features with custom names
$data{'user'}{'guest'}{'alias'}{'enable-basic-tracking'} =
    'auth.zenka.cmd.set-session-attribute';

# But both call the same dispatcher with same capability definitions
```

## Integration with Temporal Proximity Mapping

**Enable tracking capability passes buffer size**:
```
Command: "enable-tracking buffer_size=10485760"
       ↓
auth.zenka.cmd.set-session-attribute
       ↓
base.handler.auth.set_session_capability (dispatcher knows it's 'enable-tracking')
       ↓
base.handler.auth.callback.enable_tracking
       ↓
Initializes: $session->{'tracking'}{'buffer_size'} = 10485760
Starts: temporal mapping in cube with buffer awareness
```

Later, when output arrives:
- Cube's temporal map has buffer size
- Maps replies by temporal proximity
- Knows when to degrade mappings (when data rolls out)
- Automatic expiry without manual cleanup

## Integration with Character Stream Editing

**Enable character editing capability locks in feature**:
```
Pre-auth:
  nshell: "enable-character-editing"
  cube:   "OK, \r and \b enabled (locked at auth)"

Post-auth:
  nshell: "disable-character-editing"
  cube:   "DENIED - feature locked at auth time"
         (cannot be bypassed through routing)
```

This implements the **session state gating** from base.handler.command.analysis.yaml:
- Feature locked after authentication
- Prevents routed commands from changing it
- Protects against authorization bypass

## Session Capability State

Tracked in `$session->{'capabilities'}`**:

```perl
$session->{'capabilities'} = {
    'select-size-mode' => {
        enabled => 1,
        locked => 1,           # locked after auth
        value => 'SIZE',
        set_at => 1234567890.123,
    },
    'enable-tracking' => {
        enabled => 1,
        locked => 0,           # can be toggled
        buffer_size => 10485760,
        started_at => 1234567890.456,
    },
    'enable-character-editing' => {
        enabled => 1,
        locked => 1,
        set_at => 1234567890.200,
    },
};
```

Used for:
- Tracking what's enabled
- Preventing re-enabling locked features
- Audit/logging
- Cleanup on session termination

## Adding New Capabilities

**Process**:

1. **Decide complexity**:
   - Simple → Inline handler in registry
   - Complex → Create callback module

2. **Add to registry**:
   ```perl
   'my-capability' => {
       type => 'simple' or 'complex',
       description => '...',
       handler => $coderef or 'path.to.callback',
       lock_after_auth => TRUE/FALSE,
       max_calls => N,  # optional
   }
   ```

3. **Create callback** (if complex):
   ```perl
   # modules/base.handler.auth.callback.my_capability
   # Implement the feature logic
   ```

4. **Create alias** (if custom name wanted):
   ```perl
   $data{'alias'}{'my-feature-name'} = 'auth.zenka.cmd.set-session-attribute';
   ```

5. **Done**. Dispatcher auto-discovers from registry.

## Security Model

### Lock-After-Auth Pattern

Some capabilities are **locked after authentication** to prevent:
- Routed commands from changing session features
- Privilege escalation through routing
- Inconsistent session state

Example: Character editing enabled pre-auth, locked, cannot be disabled by routed commands.

### Per-User Customization

Different users can have different:
- Available capabilities
- Command names (via per-user aliases)
- Capability limits (max_calls, timeouts)

Without affecting core dispatcher.

### Audit Trail

Every capability change tracked in:
- `$session->{'capabilities'}{...}{'set_at'}`
- Terminal-history buffer
- Optional: separate audit log

## Future Enhancements

### Configuration-Driven Registry

Load capability definitions from configuration file:
```
configuration/zenki/cube/capabilities.v7:
  capability.enable-tracking = complex base.handler.auth.callback.enable_tracking
  capability.enable-tracking.lock-after-auth = FALSE
  capability.enable-tracking.max-calls = unlimited
```

### Capability Dependencies

Some capabilities might require others:
```perl
'enable-advanced-tracking' => {
    requires => ['enable-tracking'],  # Must enable tracking first
    ...
}
```

### Runtime Capability Discovery

Clients query what capabilities are available:
```
Command: "list-capabilities"
Response: [enable-tracking, enable-character-editing, ...]
```

### Capability Groups

Group related capabilities:
```perl
'group:editing' => [
    'enable-character-editing',
    'enable-backspace-support',
    'enable-line-editing',
]

Command: "enable-group editing"  # Enables all
```

## Conclusion

The Capability Negotiation Protocol provides:

1. **Unified framework** - Single interface for all session features
2. **Extensible architecture** - Add new capabilities without touching dispatcher
3. **Clean separation** - Simple vs complex, interface vs implementation
4. **Flexible lifecycle** - Pre-auth, post-auth, locked, unlocked, unloadable
5. **Security-aware** - Lock-after-auth, per-user customization, audit trail
6. **Integration-ready** - Works with temporal mapping, character editing, harmonic topology

By using a **registry-based dispatcher with optional callbacks**, the system remains:
- Maintainable (no scattered code)
- Extensible (add new capabilities easily)
- Documentable (all capabilities in one place)
- Testable (each callback independent)

---

*"Capabilities are negotiated once, locked where needed, and managed through a clean, extensible interface."*
