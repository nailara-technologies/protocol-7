# Capability Negotiation Protocol

## Overview

The **Capability Negotiation Protocol** provides a unified framework for session features negotiated during authentication and managed at runtime.

**Key features:**
- Modular dispatch pattern with dynamic handler discovery
- Standardized return codes (TRUE/FALSE/3/4)
- Auth-time capability declarations (declare-*, select-*)
- Runtime capability adjustment via commands
- No central registry - handlers discovered by naming convention

**Implementation:** Capabilities are handled by individual `auth.callback.cap-neg.*` modules, dispatched dynamically based on action-capability naming pattern.

## Architecture

### Modular Dispatch Pattern

**Auth-time negotiation** (in `base.handler.auth`):
```
Client sends: "declare-strm-size-support"
       ↓
Extract: action="declare", capability="strm-size-support"
       ↓
Construct handler: "auth.callback.cap-neg.declare-strm-size-support"
       ↓
Dispatch: $code{$handler}->($id, $args)
       ↓
Return: TRUE/FALSE/3/4 → respond to client
```

**Runtime adjustment** (via `cube.cmd.set-capability`):
```
Client sends: "set-capability declare-strm-support true"
       ↓
Parse: action="declare", capability="strm-support", value="true"
       ↓
Construct handler: "auth.callback.cap-neg.declare-strm-support"
       ↓
Dispatch: $code{$handler}->($sid, $value)
       ↓
Return: TRUE/FALSE/3/4 → translate to reply mode
```

### Handler Naming Convention

**Pattern**: `auth.callback.cap-neg.<action>-<capability>`

**Actions:**
- `declare-*` - Client declares support for a feature
- `select-*` - Client selects a mode/option

**Examples:**
- `auth.callback.cap-neg.declare-strm-size-support`
- `auth.callback.cap-neg.declare-strm-support`
- `auth.callback.cap-neg.select-size-mode`
- `auth.callback.cap-neg.select-strm-mode`

### Dispatcher Implementation

**In `base.handler.auth`** (auth-time negotiation):

```perl
} elsif ( $input->$* =~ s{^(auth\.)?(declare|select)-(\S+)\s*(.*?)\n}{} ) {
    ## capability negotiation dispatcher ##

    my $prefix     = $1 // '';
    my $action     = $2;
    my $capability = $3;
    my $args       = $4 // '';

    $event->w->start;

    ## construct handler name ##
    my $handler = sprintf 'auth.callback.cap-neg.%s-%s', $action, $capability;

    if ( defined $code{$handler} ) {
        my $result = $code{$handler}->( $id, $args );

        if ( $result == TRUE ) {
            return 1;  ## success: continue auth ##
        } elsif ( $result == FALSE ) {
            $output->$* .= "FALSE capability negotiation failed\n";
            return 2;  ## disconnect ##
        } elsif ( $result == 3 ) {
            $output->$* .= "FALSE invalid value\n";
            return 1;
        } elsif ( $result == 4 ) {
            $output->$* .= "FALSE limit exceeded\n";
            return 2;  ## disconnect ##
        }
    } else {
        ## unknown capability: log and ignore ##
        return 1;
    }
}
```

**In `cube.cmd.set-capability`** (runtime adjustment):

```perl
my $param = shift;
my $sid   = $param->{'sid'};
my $args  = $param->{'args'} // '';

unless ( $args =~ m{^(declare|select)-(\S+)\s*(.*)$} ) {
    return {
        mode => qw| false |,
        data => 'usage: set-capability <action>-<capability> [value]'
    };
}

my $action     = $1;
my $capability = $2;
my $value      = $3 // '';

my $handler = sprintf 'auth.callback.cap-neg.%s-%s', $action, $capability;

unless ( defined $code{$handler} ) {
    return { mode => qw| false |, data => sprintf( 'unknown capability: %s-%s', $action, $capability ) };
}

my $result = $code{$handler}->( $sid, $value );

## translate result codes to reply mode ##
if ( $result == TRUE ) {
    return { mode => qw| true |, data => sprintf( 'capability %s-%s set', $action, $capability ) };
} elsif ( $result == 3 ) {
    return { mode => qw| false |, data => 'validation error : invalid value' };
} elsif ( $result == 4 ) {
    return { mode => qw| false |, data => 'limit exceeded' };
} else {
    return { mode => qw| false |, data => 'capability negotiation failed' };
}
```

## Standardized Return Codes

All capability handlers return numeric codes:

| Code | Constant | Meaning | Auth Response | Command Response |
|------|----------|---------|---------------|------------------|
| 5 | TRUE | Success | Continue auth | mode: true |
| 0 | FALSE | Failure | Disconnect | mode: false |
| 3 | - | Validation error (invalid value) | Continue with FALSE | mode: false, "invalid value" |
| 4 | - | Limit exceeded (too many calls) | Disconnect | mode: false, "limit exceeded" |

**Usage in handlers:**
```perl
return TRUE;   # capability set successfully
return FALSE;  # critical failure, disconnect
return 3;      # invalid value, allow retry
return 4;      # call limit exceeded, disconnect
```

## Implemented Capabilities

### declare-strm-size-support

**Module**: `auth.callback.cap-neg.declare-strm-size-support`

**Purpose**: Client declares support for STRM-SIZE transparent fragmentation protocol

**Usage:**
```
Client: declare-strm-size-support
Server: (continues auth)
```

**Implementation:**
```perl
my $id    = shift;
my $value = shift // 'true';

return FALSE unless defined $id and exists $data{'session'}{$id};

my $session = $data{'session'}{$id};

my $bool_value = <[base.cfg_bool]>->($value);

if ( not defined $bool_value ) {
    return 3;  ## validation error ##
}

if ($bool_value) {
    $session->{'strm_size_support'} = TRUE;
} else {
    delete $session->{'strm_size_support'};
}

return TRUE;
```

**Effect**: Enables cube to send STRM-SIZE directly instead of converting to SIZE

### declare-strm-support

**Module**: `auth.callback.cap-neg.declare-strm-support`

**Purpose**: Client declares support for STRM explicit streaming protocol

**Implementation**: Similar pattern to declare-strm-size-support

### select-size-mode

**Module**: `auth.callback.cap-neg.select-size-mode`

**Purpose**: Select SIZE vs CHRSIZE mode for responses

**Usage:**
```
Client: select-size-mode SIZE
Server: (continues auth)
```

**Implementation** with call limiting:
```perl
my $id       = shift;
my $req_mode = shift // '';

return FALSE unless defined $id and exists $data{'session'}{$id};

my $session     = $data{'session'}{$id};
my $size_select = $session->{'counter'}{'auth'}{'size_select'} //= {};

$size_select->{'limit'}  //= 3;
$size_select->{'errors'} //= 0;
$size_select->{'calls'}  //= 0;

if ( $size_select->{'calls'} >= $size_select->{'limit'} ) {
    return 4;  ## limit exceeded ##
}

$req_mode = lc($req_mode);
if ( $req_mode !~ m{^(size|chrsize)$} ) {
    $size_select->{'errors'}++;
    return $size_select->{'errors'} > 2 ? 4 : 3;
}

$session->{'size_mode'} = uc($req_mode);
$size_select->{'calls'}++;
return TRUE;
```

**Features**:
- Call limit (max 3 attempts)
- Error tracking (disconnect after 3 validation errors)
- Counter tracking in session

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

## Adding New Capabilities

### Step 1: Create Handler Module

**File**: `modules/auth.callback.cap-neg.<action>-<capability>`

**Template**:
```perl
## [:< ##

# name = auth.callback.cap-neg.declare-my-feature
# descr = client declares support for my-feature

my $id    = shift;
my $value = shift // 'true';

return FALSE unless defined $id and exists $data{'session'}{$id};

my $session = $data{'session'}{$id};

## validation using base.cfg_bool wrapper ##
my $bool_value = <[base.cfg_bool]>->($value);

if ( not defined $bool_value ) {
    return 3;  ## validation error : invalid boolean value ##
}

if ($bool_value) {
    $session->{'my_feature_support'} = TRUE;
} else {
    delete $session->{'my_feature_support'};
}

return TRUE;

0;
```

### Step 2: Test

**No dispatcher changes needed!** Handler auto-discovered by naming convention.

**Auth-time test:**
```
Client: declare-my-feature
Server: (continues auth if TRUE, disconnects if FALSE/4)
```

**Runtime test:**
```
p7c cube.cmd.set-capability declare-my-feature true
```

### Step 3: Document

Add capability to this file's "Implemented Capabilities" section.

## Use Cases

### Protocol Capability Negotiation

**STRM-SIZE fragmentation support:**
```
Client startup:
  nshell: declare-strm-size-support
  cube:   (enables STRM-SIZE protocol for this session)

Result:
  - Cube can send STRM-SIZE directly to client
  - No conversion to SIZE (with timeout risks)
  - Client receives termination reason if timeout occurs
```

**STRM explicit streaming:**
```
Client: declare-strm-support
Cube:   (enables STRM protocol)

Result:
  - Multi-packet streaming without size limit
  - No timeout protection (client must handle)
  - Explicit stream control
```

### Mode Selection

**SIZE vs CHRSIZE:**
```
Client: select-size-mode SIZE
Cube:   (uses character count for SIZE responses)

Client: select-size-mode CHRSIZE
Cube:   (uses byte count for SIZE responses)
```

**Call limiting prevents abuse:**
- Max 3 attempts to select mode
- Disconnect after 3 validation errors
- Prevents hammering with invalid values

### Runtime Adjustment

**Change capabilities after auth:**
```
p7c cube.cmd.set-capability declare-strm-size-support false

Result: Disables STRM-SIZE for that session
```

**Query capability status** (future):
```
p7c cube.cmd.get-capability strm-size-support
→ enabled/disabled
```

## Session State Tracking

Capabilities modify session state directly:

```perl
## STRM-SIZE support flag
$session->{'strm_size_support'} = TRUE;

## STRM support flag
$session->{'strm_support'} = TRUE;

## SIZE mode selection
$session->{'size_mode'} = 'SIZE';  # or 'CHRSIZE'

## Call counters (for limiting)
$session->{'counter'}{'auth'}{'size_select'} = {
    limit  => 3,
    errors => 0,
    calls  => 1,
};
```

**No central capability registry** - state stored per-capability as needed.

## Design Principles

### No Central Registry

**Why**: Avoid single point of maintenance and version conflicts

**Instead**: Handler discovery by naming convention
- Add new capability → create new module
- No dispatcher changes needed
- Module filename defines capability name

### Standardized Return Codes

**Why**: Consistent error handling across all capabilities

**Benefits**:
- TRUE/FALSE for success/failure (clear semantics)
- 3 for validation errors (allow retry)
- 4 for limit exceeded (prevent abuse)
- Dispatcher translates codes to appropriate responses

### Stateless Handlers

**Why**: Handlers are pure functions of (session_id, arguments)

**Benefits**:
- No hidden dependencies
- Easy to test in isolation
- Session state is only shared state
- Handlers can be called from auth or runtime equally

## Conclusion

The Capability Negotiation Protocol provides:

1. **Modular dispatch** - Add capabilities without changing core code
2. **Dynamic discovery** - Handlers found by naming convention
3. **Standardized contracts** - Return codes, parameter patterns
4. **Runtime flexibility** - Adjust capabilities after auth via commands
5. **Protocol evolution** - STRM-SIZE, STRM, SIZE mode selection

By using **modular handlers with dynamic dispatch**, the system remains:
- Maintainable (one file per capability)
- Extensible (add file, done)
- Testable (handlers are pure functions)
- Documented (handler name = capability name)

---

**Current capabilities**: declare-strm-size-support, declare-strm-support, select-size-mode, select-strm-mode, declare-strm-size-timeout

**Adding new**: Create `auth.callback.cap-neg.<action>-<capability>` module → auto-discovered
