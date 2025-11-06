# Protocol-7 Command Protocol - Quick Reference Card

## The Three Simple Steps

### 1️⃣ Parent Sends Command

```perl
my $cmd = 'letsencrypt.child.cmd.renew-certificate example.com';
<[base.send_command]>->( <letsencrypt.pipe.child>, $cmd );
```

### 2️⃣ Child Processes Command

```perl
# modules/letsencrypt.child.cmd.renew-certificate
my $call = shift;
my $domain = $call->{'args'};

# ... do work ...

return { 'mode' => 'true', 'data' => 'renewal initiated' };
```

### 3️⃣ Parent Gets Reply

Protocol-7 automatically delivers the reply back via command routing.

---

## Reply Modes at a Glance

| Mode | Meaning | Protocol Message |
|------|---------|------------------|
| `'true'` | ✓ Success | `TRUE message\n` |
| `'false'` | ✗ Error | `FALSE error\n` |
| `'wait'` | ⏳ Not ready | `WAIT please try later\n` |
| `'size'` | 📦 Binary data | `SIZE 1024\n[data]\n` |
| `'term'` | 🔴 Shutdown | `TERM goodbye\n` |

---

## Command Module Template

```perl
## [:< ##

# name  = letsencrypt.child.cmd.action-name
# param = <required_param> [optional_param]
# descr = What this command does - shown in zenka.commands list

my $call = shift;

# Get arguments
my $arg = $call->{'args'};
my $param_value = $call->{'param'}{'key'} // 'default';

# Validate
return { 'mode' => 'false', 'data' => 'param required' }
    unless defined $arg;

# Do work
# ... your code here ...

# Return result
return { 'mode' => 'true', 'data' => 'success message' };

0;  # Always end with 0
```

**Important**: The `# descr =` header is **automatically parsed and displayed** when users query `zenka.commands`. Write it as if it's help text:
- Clear and concise
- Describe what the command does
- Mention required/optional parameters if not obvious
- Makes the zenka self-documenting

---

## Parent Sending Commands

```perl
# Simple command (no parameters)
<[base.send_command]>->( $pipe, 'letsencrypt.child.cmd.action domain' );

# With multiple parameters (use multi-line format in real code)
my $cmd = 'letsencrypt.child.cmd.action domain';
<[base.send_command]>->( $pipe, $cmd );
```

---

## Child Receiving Commands

### Access Command Arguments

```perl
my $call = shift;

# Single argument (everything after command name)
my $domain = $call->{'args'};

# Multi-line parameters (from headers)
my $value = $call->{'param'}{'header_key'};

# Multi-line body data
my $body = $call->{'data'};
```

### Return Replies

```perl
# Success
return { 'mode' => 'true', 'data' => 'operation succeeded' };

# Error
return { 'mode' => 'false', 'data' => 'reason: invalid input' };

# Not ready yet
return { 'mode' => 'wait', 'data' => 'still processing' };

# Binary data
return { 'mode' => 'size', 'data' => $binary_blob };
```

---

## Real Examples From Codebase

### Weather Example (Parent Command)

```perl
# modules/weather.parent.cmd.station-id
return { 'mode' => qw| false |, 'data' => 'station id not defined' }
    if not defined <weather.station_id>;

return { 'mode' => qw| true |, 'data' => <weather.station_id> }
```

### Our ACME Example (Child Command)

```perl
# modules/letsencrypt.child.cmd.renew-certificate
my $call = shift;
my $domain = $call->{'args'};

return { 'mode' => 'false', 'data' => 'domain required' }
    unless defined $domain;

# TODO: ACME renewal...

return { 'mode' => 'true', 'data' => "renewal started for $domain" };
```

---

## Key Concepts

**Command Names**:
- Pattern: `zenka.child.cmd.action-name` (hyphens, not underscores)
- The `.cmd.` part **tells Protocol-7 this is a zenka command**
- Example: `letsencrypt.child.cmd.renew-certificate`
- Without `.cmd.`, Protocol-7 treats it as data/navigation

**Arguments**:
- Single line: `command_name arg1`
- Accessed as: `$call->{'args'}` → `"arg1"`

**Return Format**:
- Always: `{ 'mode' => 'string', 'data' => 'string|binary' }`
- Protocol-7 converts automatically to protocol messages
- `'size'` mode: Can return multiple lines or arbitrary binary format
  - Protocol-7 handles framing with size prefix
  - Perfect for certificates, JSON, serialized data, etc.

**Routing**:
- Parent sends command
- Child receives via `base.handler.command`
- Child returns reply hash
- Protocol-7 routes reply back to parent automatically
- **Parent doesn't need to listen for replies - Protocol-7 handles routing**

---

## Anti-Pattern: What NOT To Do

❌ Don't invent custom message formats
```perl
# WRONG - Protocol-7 doesn't understand this
<[custom.send_json]>->( { command => 'renew', domain => 'example.com' } );
```

❌ Don't send raw JSON
```perl
# WRONG - Will cause "protocol mismatch"
my $json = JSON::XS::encode_json({...});
<[base.s_write]>->( $pipe, $json );
```

❌ Don't register custom message handlers
```perl
# WRONG - fork already registers base.handler.command
$data{'session'}{$id}{'input'}{'handler'} = qw| custom.handler |;
```

---

## Pattern: What TO Do

✓ Use `base.send_command` to send
✓ Return `{ mode => '...', data => '...' }` from commands
✓ Let Protocol-7 handle routing
✓ Follow `*.cmd.*` module naming

---

## Checklist: Creating a Child Command Module

- [ ] File: `modules/letsencrypt.child.cmd.action-name`
- [ ] Header comment with `name`, `param`, `descr`
- [ ] Accept `$call = shift`
- [ ] Extract arguments: `my $arg = $call->{'args'}`
- [ ] Validate inputs
- [ ] Do work
- [ ] Return `{ 'mode' => '...', 'data' => '...' }`
- [ ] End with `0;`
- [ ] Include signature footer

---

## For ACME Implementation

**Parent sends**:
```perl
<[base.send_command]>->( <letsencrypt.pipe.child>,
    'letsencrypt.child.cmd.renew-certificate example.com' );
```

**Child processes** in `letsencrypt.child.cmd.renew-certificate`:
1. Extract domain from `$call->{'args'}`
2. Implement ACME renewal (fetch nonce, create order, etc.)
3. Get certificate from Let's Encrypt
4. Return with `'size'` mode for binary certificate data

**Return certificate data**:
```perl
my $cert_pem = read_certificate_file();

return { 'mode' => 'size', 'data' => $cert_pem };
# Protocol-7 handles framing: SIZE [length]\n[certificate]\n
```

**Parent receives**:
- `SIZE` reply → extract certificate binary data, store in registry
- `TRUE` → just status message, no binary data
- `FALSE` → error message, trigger retry

---

## That's It!

3 steps, 3 reply modes, and Protocol-7 handles the rest.

No custom JSON. No message handlers. Just simple command modules that return status.

This is the Protocol-7 way. This is what works.

