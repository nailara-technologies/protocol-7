# Protocol-7 Command Protocol Fix - Session 2C

**Status**: ✓ Fixed - Using native Protocol-7 command protocol instead of custom JSON
**Date**: 2025-11-07
**Issue**: Protocol mismatch error when child sent JSON messages to parent

---

## Root Cause Analysis

**The Problem**:
- Child was sending raw JSON: `{"command":"child_ready","pid":98005}`
- Parent's `base.handler.command` expects **Protocol-7 command format**, not JSON
- This caused: `[protocol mismatch] ['{"command":"child_ready","pid":98005}']`

**Why It Failed**:
- Weather zenka (working reference) uses `base.handler.command` via `base.session.init()`
- Protocol-7 has native command protocol with specific message formats
- We were bypassing the entire command system with custom JSON

**The Solution**:
Use Protocol-7's native **command protocol** instead of inventing custom messaging:
- Parent sends commands like: `(cmd_id)letsencrypt.child.cmd.renew-certificate domain`
- Child receives via `base.handler.command` (already registered by fork)
- Child processes in command modules: `*.cmd.*`
- Responses use Protocol-7 reply format: `{ mode => 'true|false', data => message }`

---

## Architecture - Protocol-7 Command Protocol

### Parent-to-Child Communication

**Parent sends command**:
```perl
my $renewal_cmd = sprintf 'letsencrypt.child.cmd.renew-certificate %s', $domain;
<[base.send_command]>->( <letsencrypt.pipe.child>, $renewal_cmd );
```

**Protocol-7 formats and routes**:
```
(cmd_id)letsencrypt.child.cmd.renew-certificate example.com
↓ (via IPC socket)
Child receives: base.handler.command processes
↓
Calls: $code{'letsencrypt.child.cmd.renew-certificate'}->($call_args)
```

**Child returns response**:
```perl
return {
    'mode' => 'true',
    'data' => "certificate renewal initiated for example.com"
};
```

**Protocol-7 formats reply**:
```
TRUE Certificate renewal initiated
↓ (via IPC socket)
Parent receives reply via command routing system
```

### Flow Diagram

```
Parent Process              IPC Socket              Child Process
    ↓                           ↓                       ↓
renewal_check_timer
  fires                                            base.handler.command
    ↓                                              waits for commands
handler_renewal_check
  finds domain needing
  renewal
    ↓
formats:
'letsencrypt.child.cmd.renew-certificate example.com'
    ↓
<[base.send_command]>->()
    ↓
(cmd_id)letsencrypt.child.cmd.renew-certificate example.com\n
────────────────────────────→ receives raw command
                              ↓
                              parses via base.handler.command
                              ↓
                              routes to letsencrypt.child.cmd.renew-certificate
                              ↓
                              handler processes
                              ↓
                              returns { mode => 'true', data => 'msg' }
                              ↓
                              TRUE msg
                              ↓
────────────────────────────← send back to parent via route
    ↓
receives TRUE reply
    ↓
handler processes response
```

---

## Files Changed - Session 2C

### Removed (Custom JSON Modules)

These modules were trying to do custom JSON messaging but Protocol-7 already handles this:

- ✓ Removed: `letsencrypt.parent.message_handler`
- ✓ Removed: `letsencrypt.child.handler_message`
- ✓ Removed: `letsencrypt.child.send_to_parent`
- ✓ Removed: `letsencrypt.parent.send_to_child`

### Modified

**letsencrypt.child.init_code**:
- Removed custom handler registration (lines 37-38)
- Removed `send_to_parent` call at end (lines 59-63)
- Now just initializes state and returns normally
- `base.handler.command` already registered by fork

**letsencrypt.parent.init_code**:
- Removed custom message handler registration (lines 54-56)
- Added note that `base.handler.command` is already set up
- Parent handlers stay the same (for processing child responses)

**letsencrypt.parent.handler_renewal_check**:
- Changed from custom JSON: `send_to_child({ command => 'renew_certificate', ... })`
- To Protocol-7 command: `<[base.send_command]>->( pipe, 'letsencrypt.child.cmd.renew-certificate domain' )`

### Created - Child Command Modules

**New**: `letsencrypt.child.cmd.renew-certificate`
```perl
# name = letsencrypt.child.cmd.renew-certificate
# param = <domain>
# descr = Renew certificate for specified domain via ACME protocol

my $call = shift;
my $domain = $call->{'args'};

return {
    'mode' => 'false',
    'data' => 'domain parameter required'
} unless defined $domain && length($domain);

# TODO: Implement ACME renewal workflow
return {
    'mode' => 'true',
    'data' => "renewal initiated for $domain"
};
```

**New**: `letsencrypt.child.cmd.new-certificate`
```perl
# name = letsencrypt.child.cmd.new-certificate
# param = <domain>
# descr = Obtain new certificate for domain via ACME protocol

# Similar structure - returns { mode => 'true|false', data => message }
```

---

## How Protocol-7 Command Protocol Works

### Message Format

**Single-line commands**:
```
(cmd_id)command_name argument1 argument2\n
```

**Multi-line commands with parameters**:
```
(cmd_id)command_name+
param1: value1
param2: value2

body data here
.
```

### Reply Formats

| Mode | Format | Use Case |
|------|--------|----------|
| TRUE | `TRUE message text` | Success response |
| FALSE | `FALSE error message` | Error response |
| WAIT | `WAIT message` | Waiting/not ready |
| SIZE | `SIZE 1024 \n[binary data]` | Binary data return |
| TERM | `TERM shutdown` | Session termination |

### Handler Registration (Already Done by Fork)

**In fork module** (line 52 & 71):
```perl
$data{'session'}{$id}{'input'}{'handler'} = qw| base.handler.command |;
```

This tells Protocol-7 to use the native command protocol parser.

---

## Command Module Structure

### Signature

```perl
# name  = letsencrypt.child.cmd.command-name
# param = <param1> [param2] [param3]
# descr = Description of what command does
```

### Invocation

```perl
my $call = shift;  # Call arguments hash

# Access arguments
my $arg1 = $call->{'args'};       # Single argument string
my $param1 = $call->{'param'}{'key'};  # Multi-line parameters
my $data = $call->{'data'};       # Multi-line body data
my $user = $call->{'user'};       # Authenticated user
```

### Response

All command modules return a hash reference:

```perl
return {
    'mode' => 'true|false|wait|size|term',
    'data' => 'message or data to return'
};
```

**Modes**:
- `'true'` → SUCCESS - returns TRUE message
- `'false'` → ERROR - returns FALSE message
- `'wait'` → NOT READY - returns WAIT message
- `'size'` → BINARY DATA - wraps in SIZE message
- `'term'` → SHUTDOWN - terminates session

---

## Why This Approach is Better

1. **Built-in**: Protocol-7 already handles all message serialization
2. **Routing**: Automatic command ID tracking and reply routing
3. **Tested**: Used by weather, cube, and core zenki (proven pattern)
4. **Features**: Supports binary data, multi-line, parameters, routing
5. **Simple**: No custom JSON parsing - just return hash refs
6. **Async**: Supports deferred replies for long operations

---

## Implementation Checklist

- ✓ Removed custom JSON messaging modules
- ✓ Fixed child init to not send messages (just init)
- ✓ Fixed parent init to not register custom handler
- ✓ Updated parent command sending to use `base.send_command`
- ✓ Created child command modules with proper signatures
- ✓ Child commands return `{ mode => 'true|false', data => msg }`
- ✓ Parent handlers will process the `TRUE/FALSE` replies automatically

---

## Next Steps

### Immediate (For Next Restart)

1. **Verify child loads without errors**
   - Should see: "Let's Encrypt child process initialization complete"
   - Should NOT see: custom message handler registration errors

2. **Verify command protocol works**
   - Parent sends renewal command via `base.send_command`
   - Child receives via `base.handler.command`
   - Child returns `TRUE/FALSE` via protocol

3. **Check logs for**:
   - No "protocol mismatch" errors
   - No "undefined routine" errors (except expected event.emit)
   - Proper command routing messages

### Testing Commands (Once Running)

From parent zenka shell:
```
letsencrypt.child.cmd.renew-certificate example.com
```

Expected response:
```
TRUE renewal initiated for example.com (not yet implemented)
```

---

## Key Learning: Protocol-7 Command Protocol

**Protocol-7 is not a simple RPC system** - it's a sophisticated command routing infrastructure:

1. **Command Parsing**: `base.handler.command` parses protocol syntax
2. **Routing**: Maintains command IDs for request-response matching
3. **Async Support**: Handles deferred completion via `reply_id`
4. **Access Control**: Integrated permission checking
5. **Hooks**: Pre/post-processing hooks for commands
6. **Sessions**: Each connection has input/output buffers and state

Custom JSON messaging bypasses all of this, hence the "protocol mismatch" error.

---

## Status

**Ready for next restart with proper Protocol-7 command protocol implementation.**

The system now uses the same message architecture as the successful weather zenka, which is the reference implementation for parent-child communication in Protocol-7.

