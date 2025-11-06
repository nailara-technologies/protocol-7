# Understanding Protocol-7 Command Reply Modes

**Key Insight**: Protocol-7 commands don't send data back through custom channels - they return structured replies that the command protocol understands natively.

---

## The Simple Reply Model

### All commands return a hash reference:

```perl
return {
    'mode' => 'true|false|wait|size|term|deferred',
    'data' => 'content or binary data'
};
```

### Protocol-7 Understands These Reply Modes

The `base.handler.command` module automatically converts these return values into protocol messages:

| Mode | Protocol Message | Meaning |
|------|------------------|---------|
| `'true'` | `TRUE message\n` | Command succeeded |
| `'false'` | `FALSE error message\n` | Command failed |
| `'wait'` | `WAIT message\n` | Not ready, try again |
| `'size'` | `SIZE 1024\n[binary data]\n` | Binary data response |
| `'term'` | `TERM message\n` | Session terminating |
| `'deferred'` | Command continues async | Response sent later |

### Example: Renewal Command

```perl
# letsencrypt.child.cmd.renew-certificate
my $call = shift;
my $domain = $call->{'args'};

if (!$domain) {
    return { 'mode' => 'false', 'data' => 'domain required' };
    # Protocol-7 converts this to: FALSE domain required
}

# TODO: Do renewal work...

return { 'mode' => 'true', 'data' => "renewal started for $domain" };
# Protocol-7 converts this to: TRUE renewal started for example.com
```

---

## Parent Receives These Replies Automatically

The parent doesn't need to parse anything - `base.handler.command` handles it:

```perl
# In parent.handler_renewal_check:
my $renewal_cmd = sprintf 'letsencrypt.child.cmd.renew-certificate %s', $domain;
<[base.send_command]>->( <letsencrypt.pipe.child>, $renewal_cmd );

# Parent waits for:
# - TRUE message → command succeeded
# - FALSE message → command failed
# - WAIT message → not ready yet
```

The reply comes back **through the same command routing system** that sent it.

---

## Why This Is Better Than JSON Messages

### ❌ Custom JSON Approach (What We Were Doing)

```
Parent: Send JSON via pipe
        {"command": "renew", "domain": "example.com"}
        ↓
Child:  Parse custom format
        Extract command and domain
        ↓
Child:  Do work
        ↓
Child:  Send JSON reply via custom channel
        {"result": "success", "message": "..."}
        ↓
Parent: Parse custom format
        Extract result and message
```

**Problem**: Protocol-7's `base.handler.command` doesn't understand JSON, so it reports "protocol mismatch"

### ✓ Protocol-7 Reply Mode Approach (What We're Doing Now)

```
Parent: <[base.send_command]>->(..., 'letsencrypt.child.cmd.renew-certificate domain')
        ↓ (Protocol-7 formats as command)
        (cmd_id)letsencrypt.child.cmd.renew-certificate domain\n
        ↓
Child:  base.handler.command receives and parses
        Routes to: $code{'letsencrypt.child.cmd.renew-certificate'}->($call)
        ↓
Child:  Handler executes
        ↓
Child:  return { 'mode' => 'true', 'data' => 'message' }
        ↓ (Protocol-7 converts to)
        TRUE message\n
        ↓ (via reply routing system)
Parent: Receives TRUE message
        (routing system tracks which command this replies to)
```

**Benefit**: Protocol-7 handles ALL the message formatting and routing - we just return hash refs!

---

## The Three-Part Pattern

All Protocol-7 command/reply cycles follow this pattern:

### 1. **Command** (Parent → Child)

Sent via normal command protocol:
```perl
<[base.send_command]>->( $pipe, 'zenka.cmd.action param1 param2' );
```

### 2. **Processing** (Child)

Command module receives `$call` hash and does work:
```perl
my $call = shift;
my $param1 = $call->{'args'};
# ... do work ...
```

### 3. **Reply** (Child → Parent)

Return standard reply mode:
```perl
return { 'mode' => 'true|false', 'data' => 'result' };
```

That's it! Protocol-7's routing system handles everything else.

---

## Live Example: Weather Zenka

The weather zenka demonstrates this perfectly:

### Parent Sends Command

```perl
# In parent.handler.update_current_reply:
my $reply = $call->{'data'};  # Weather data received
# Process it...
# Internally uses command protocol for async operations
```

### Child Executes Command

```perl
# modules/weather.child.cmd.request-data
my $call = shift;
my $station_id = $call->{'args'};

# Query weather API...
my $json_response = <[weather.child.query_api]>->($query_str);

if (not defined $json_response) {
    return { 'mode' => 'false', 'data' => 'query failed' };
}

return { 'mode' => 'true', 'data' => $json_data };
```

### Parent Receives Reply

Protocol-7 automatically routes the `TRUE` or `FALSE` message back to the handler that initiated the command.

---

## Key Reply Modes Explained

### TRUE - Success Response

```perl
return { 'mode' => 'true', 'data' => 'operation succeeded' };

# Becomes:
# TRUE operation succeeded\n
```

Used when command completed successfully.

### FALSE - Error Response

```perl
return { 'mode' => 'false', 'data' => 'invalid parameter' };

# Becomes:
# FALSE invalid parameter\n
```

Used when command failed. The 'data' field contains error message.

### WAIT - Not Ready Yet

```perl
return { 'mode' => 'wait', 'data' => 'still processing' };

# Becomes:
# WAIT still processing\n
```

Tells caller to retry later. Useful for long-running operations.

### SIZE - Binary Data Response

```perl
my $binary_data = <[read_cert_file]>->();

return { 'mode' => 'size', 'data' => $binary_data };

# Becomes:
# SIZE 1024\n[1024 bytes of binary data]\n
```

Automatic length calculation and binary safe transmission.

### DEFERRED - Async Response

```perl
return { 'mode' => 'deferred', 'data' => $reply_id };

# Command returns immediately
# Later, when work completes:
<[base.cmd_reply]>->{$reply_id} = {
    'mode' => 'true',
    'data' => 'operation complete'
};
```

For operations that take too long to block on.

---

## Our ACME Implementation Uses This

### Renewal Check Timer Fires

```perl
# letsencrypt.parent.handler_renewal_check (called by event timer)
for my $domain ( keys %{<letsencrypt.parent.certs>} ) {
    if ($days_remaining <= $renewal_threshold) {
        # Send command via Protocol-7
        my $cmd = sprintf 'letsencrypt.child.cmd.renew-certificate %s', $domain;
        <[base.send_command]>->( <letsencrypt.pipe.child>, $cmd );
    }
}
```

### Child Receives & Processes

```perl
# modules/letsencrypt.child.cmd.renew-certificate
my $call = shift;
my $domain = $call->{'args'};

# TODO: ACME renewal workflow
# - Fetch nonce
# - Create order
# - Respond to challenges
# - Finalize order
# - Get certificate

if ($success) {
    return { 'mode' => 'true', 'data' => 'certificate received' };
} else {
    return { 'mode' => 'false', 'data' => 'ACME error: ' . $error };
}
```

### Parent Receives Reply

Protocol-7's command routing automatically delivers the `TRUE` or `FALSE` message back through the session that sent the command. Parent can then:
- Log success
- Store certificate
- Update renewal timers
- Emit events

---

## Summary: The Protocol-7 Way

1. **Don't invent custom messages** - use the built-in command protocol
2. **Commands are simple strings** - parent sends text commands
3. **Replies are simple hashes** - child returns `{ mode => '...', data => '...' }`
4. **Protocol-7 handles routing** - message formatting, delivery, acknowledgment
5. **Everything stays in sync** - command IDs automatically match replies to requests

This is why the weather zenka works - it follows this pattern. This is why our custom JSON failed - it tried to bypass the system.

**For ACME we use**: Command modules (`*.cmd.*`) that return reply modes Protocol-7 understands.

