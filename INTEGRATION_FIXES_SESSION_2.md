# Integration Fixes - Session 2 - Event System & Timer Implementation

**Status**: ✓ Event system integration complete and optimized
**Date**: 2025-11-07
**Session**: Protocol-7 Ed25519 ACME - Event System Integration

---

## Overview

Session 2 continued from the runtime fixes completed in Session 1. The focus was on:
1. Proper event timer implementation using `event.add_timer`
2. Guarding optional `event.emit` calls
3. Creating missing handler modules
4. Final validation of all module references

---

## Fixes Applied

### 1. **Renewal Timer Implementation** ✓

**Module**: `letsencrypt.parent.init_code` (lines 27-34)

**Before**:
```perl
## TODO: Implement base.timer.add or use event loop mechanism
# <letsencrypt.parent.renewal_check_timer> = <[base.timer.add]>->(
#     <letsencrypt.renewal.check-interval>,
#     1,  # recurring
#     {...}
# );
<letsencrypt.parent.next_renewal_check> = time() + <letsencrypt.renewal.check-interval>;
```

**After**:
```perl
## Initialize renewal check timer using event system
## Fires every <letsencrypt.renewal.check-interval> seconds (86400 = 24 hours)
<letsencrypt.parent.renewal_check_timer> = <[event.add_timer]>->({
    'interval' => <letsencrypt.renewal.check-interval>,
    'handler'  => qw| letsencrypt.parent.handler_renewal_check |,
    'repeat'   => 1,
    'data'     => {},
});
```

**Key Changes**:
- Removed non-existent `base.timer.add` call (from namespace `base.event.*` which becomes `event.*`)
- Used proper `event.add_timer` API with hash reference parameter
- Removed simple time tracking fallback (now using actual timer)
- Uses recurring mode (`'repeat' => 1`) with `'interval'` for 24-hour checks

---

### 2. **Renewal Retry Timer** ✓

**Module**: `letsencrypt.parent.handler_renewal_failed` (lines 36-45)

**Before**:
```perl
## Schedule retry via timer
<[base.timer.add]>->(
    $next_retry,
    0,  # non-recurring
    { handler => 'letsencrypt.parent.handler_renewal_retry', ... }
);
```

**After**:
```perl
## Schedule retry via event timer
<[event.add_timer]>->({
    'after'    => $next_retry,
    'handler'  => qw| letsencrypt.parent.handler_renewal_retry |,
    'repeat'   => 0,
    'data'     => {
        domain  => $domain,
        attempt => $attempts + 1,
    },
});
```

**Key Changes**:
- Changed from non-existent `base.timer.add` to `event.add_timer`
- Uses `'after'` parameter for one-time scheduling
- Uses `'repeat' => 0` for non-recurring timer
- Properly passes retry attempt number for exponential backoff tracking

---

### 3. **Event.emit Guarding** ✓

Guarded all optional `event.emit` calls with `if defined` checks since `event.emit` module doesn't exist yet:

**Module**: `letsencrypt.parent.handler_renewal_check` (line 49)
```perl
<[event.emit]>->({...}) if defined <[event.emit]>;
```

**Module**: `letsencrypt.parent.handler_cert_ready` (line 44)
```perl
<[event.emit]>->({...}) if defined <[event.emit]>;
```

**Module**: `letsencrypt.parent.handler_renewal_failed` (line 56)
```perl
<[event.emit]>->({...}) if defined <[event.emit]>;
```

**Module**: `letsencrypt.parent.handler_child_ready` (line 24)
Already had guard: ✓

---

### 4. **Missing Handler Module Creation** ✓

**New Module**: `letsencrypt.parent.handler_renewal_retry`

**Purpose**: Handle scheduled renewal retry from timer - resend renewal request to child

**Implementation**:
```perl
my $timer_data = shift;
my $domain = $timer_data->{domain};
my $attempt = $timer_data->{attempt} // 1;

<[base.log]>->( 2, "renewal retry for domain: $domain (attempt $attempt)" );

## Get certificate info
my $cert_info = <letsencrypt.parent.certs>{$domain};
return 0 unless $cert_info;

## Send renewal command to child
<[letsencrypt.parent.send_to_child]>->({
    command => 'renew_certificate',
    domain  => $domain,
    cert_info => $cert_info,
    retry_attempt => $attempt,
});

## Update attempt counter
if ( exists <letsencrypt.parent.renewal_timers>{$domain} ) {
    <letsencrypt.parent.renewal_timers>{$domain}{attempts}++;
}

return 1;
```

**Features**:
- Retrieves timer data from event system
- Logs retry attempt with domain
- Validates certificate info exists before retry
- Sends renewal command to child with attempt tracking
- Updates attempt counter for exponential backoff calculation

---

### 5. **Child Init Code Message Path** ✓

**Module**: `letsencrypt.child.init_code` (line 55)

**Before**:
```perl
<[letsencrypt.parent.send_from_child]>->({...});  # WRONG: parent module called from child
```

**After**:
```perl
<[letsencrypt.child.send_to_parent]>->({...});    # CORRECT: child sends to parent
```

**Reason**: The child process must use `send_to_parent`, not the parent's `send_from_child` module. Each process has its own perspective:
- Child → Parent: uses `letsencrypt.child.send_to_parent`
- Parent → Child: uses `letsencrypt.parent.send_to_child`
- Parent receives: routes via `letsencrypt.parent.send_from_child`

---

## Event System API Reference

### `event.add_timer` (from `base.event.add_timer`)

**Parameters** (hash reference):
- `'after'` or `'at'` - Timing specification
  - `'after' => $seconds` - Relative delay (most common)
  - `'at' => $timestamp` - Absolute Unix timestamp
- `'interval'` - Recurring interval in seconds (for repeating timers)
- `'repeat'` - Boolean flag (0 or 1)
  - Set to 1 if using `'interval'` for recurring timers
  - Set to 0 for one-time timers
- `'handler'` - Module name (string) of callback handler
- `'data'` - User data hash passed to handler
- `'prio'` - Priority level (default: 1)
- `'reentrant'` - Allow reentrant callbacks (default: 1)

**Returns**: Event timer object (or undef on error)

**Example - Recurring Timer** (24-hour renewal check):
```perl
<[event.add_timer]>->({
    'interval' => 86400,
    'handler'  => qw| letsencrypt.parent.handler_renewal_check |,
    'repeat'   => 1,
    'data'     => {},
});
```

**Example - One-Time Timer** (retry after delay):
```perl
<[event.add_timer]>->({
    'after'    => 300,  # 5 minutes
    'handler'  => qw| letsencrypt.parent.handler_renewal_retry |,
    'repeat'   => 0,
    'data'     => { domain => 'example.com', attempt => 1 },
});
```

---

## Namespace Swap Reference

### `base.event.*` → `event.*`

Just like `base.file.*` modules are swapped to `file.*` at pre_init via `base.swap_subs`:

**modules/base.event.pre_init**:
```perl
<[base.swap_subs]>->( 'base.event', 'event' );
```

**Runtime References**:
- ✓ `<[event.add_timer]>` (swapped from `base.event.add_timer`)
- ✓ `<[event.add_io]>` (swapped from `base.event.add_io`)
- ✓ `<[event.add_signal]>` (swapped from `base.event.add_signal`)
- ✗ `<[event.emit]>` (does not exist, so guarded)

---

## Dependencies Status

### ✓ Available & Working
- `Event` - Perl event loop (used by `base.event.add_timer`)
- `Crypt::Ed25519` - Account key signing
- `Crypt::OpenSSL::X509` - CSR generation
- `JSON::XS` - JSON encoding/decoding
- `MIME::Base64` - Base64url encoding
- `Crypt::Misc` - Base32r encoding
- `Digest::SHA` - Hashing

### ✗ Not Available (Non-Critical)
- `event.emit` - Optional monitoring (guarded, system works without it)

---

## Verification Checklist

✓ Renewal timer uses proper `event.add_timer` API
✓ Retry timer uses proper `event.add_timer` API with `'after'` parameter
✓ All `event.emit` calls are guarded with `if defined`
✓ Missing `letsencrypt.parent.handler_renewal_retry` module created
✓ Child init code uses correct `send_to_parent` function
✓ No references to non-existent `base.timer.add`
✓ No references to non-existent `base.json`
✓ All file operations use `file.*` namespace (swapped from `base.file.*`)
✓ All PRNG references use hyphenated names (`chars-anum` not `chars_anum`)

---

## System Architecture - Complete Flow

### Renewal Check Flow
```
1. Parent init
   └─ event.add_timer( interval => 86400 )
      └─ Fires: letsencrypt.parent.handler_renewal_check

2. Check timer fires (every 24 hours)
   └─ Iterate <letsencrypt.parent.certs> for domains
   └─ Check expiration vs renewal threshold (30 days)
   └─ If needs renewal:
      ├─ Send 'renew_certificate' command to child
      ├─ Track in <letsencrypt.parent.renewal_timers>
      └─ Emit 'renewal_check_complete' event (if emit exists)
```

### Renewal Failure & Retry Flow
```
1. Renewal attempt fails
   └─ Child sends 'renewal_failed' to parent

2. Parent receives failure
   └─ handler_renewal_failed called
   ├─ Increment attempt counter
   └─ If attempts < 5:
      ├─ Calculate backoff: 300 * (2^attempts) seconds
      ├─ event.add_timer( after => backoff )
      │  └─ Fires: letsencrypt.parent.handler_renewal_retry
      └─ Else:
         ├─ Log critical failure
         └─ Emit 'critical_renewal_failure' event (if emit exists)

3. Retry timer fires
   └─ handler_renewal_retry called
   ├─ Get certificate info
   ├─ Send renewal command to child
   └─ Update attempt counter
```

### Success Flow
```
1. Certificate successfully renewed
   └─ Child sends 'cert_ready' with certificate data

2. Parent receives cert_ready
   └─ handler_cert_ready called
   ├─ Store in <letsencrypt.parent.certs>
   ├─ Write to disk
   ├─ Clear renewal timers
   ├─ Increment stats
   └─ Emit 'certificate_updated' event (if emit exists)
```

---

## Configuration Parameters Reference

### Renewal Timing
- `<letsencrypt.renewal.check-interval>` = 86400 seconds (24 hours)
- `<letsencrypt.renewal.days-before>` = 30 days before expiration
- `<letsencrypt.renewal.retry-delay>` = Base retry delay (300 seconds = 5 minutes)

### Exponential Backoff Calculation
```
Attempt 0: 300 * (2^0) = 300 seconds (5 min)
Attempt 1: 300 * (2^1) = 600 seconds (10 min)
Attempt 2: 300 * (2^2) = 1200 seconds (20 min)
Attempt 3: 300 * (2^3) = 2400 seconds (40 min)
Attempt 4: 300 * (2^4) = 4800 seconds (80 min)
Max retries: 5 attempts total
```

---

## Testing Instructions

### Verify Event Timer Setup
1. Start parent process: `./bin/Protocol-7 [parent-zenka]`
2. Check logs for: "initializing Let's Encrypt ACME parent process"
3. Check logs for: "Let's Encrypt parent process initialization complete"
4. Verify timer created (may not show explicit log, but no errors)

### Test Renewal Check
1. Manually trigger renewal check (if admin command exists)
2. Monitor logs for: "renewal check timer fired"
3. Should iterate through `<letsencrypt.parent.certs>` domains
4. Check for either "needs renewal" or "no renewal needed" messages

### Test Retry Mechanism
1. Manually cause renewal to fail (if test mode exists)
2. Verify logs: "renewal FAILED for domain"
3. Check: "scheduling retry in [N] seconds"
4. Wait for exponential backoff timer to fire
5. Verify: "renewal retry for domain" appears in logs

---

## Next Steps for Full Integration

1. **Implement `event.emit` module** (optional)
   - Enables system notifications for certificate updates
   - Currently guarded, system works without it

2. **Test full ACME renewal cycle**
   - Certificate expiration simulation
   - Multiple domain renewal
   - Failure and retry scenarios

3. **Monitor renewal statistics**
   - Check `<letsencrypt.stats.renewals_completed>`
   - Check `<letsencrypt.stats.renewals_failed>`
   - Check `<letsencrypt.stats.last_renewal_check>`

4. **Production deployment**
   - Verify cron job for HTTPSD certificate reload
   - Monitor Let's Encrypt rate limits
   - Set up alerts for critical renewal failures

---

## Summary

**All event system integration complete:**

✓ Proper `event.add_timer` implementation for both recurring and one-time timers
✓ Exponential backoff retry mechanism with configurable attempts
✓ Optional event.emit guarding for future monitoring capability
✓ Complete parent-child handler architecture for renewal orchestration
✓ Renewal statistics tracking and timeout management

The Ed25519 ACME implementation is now **fully integrated with Protocol-7's event system** and ready for production testing with Let's Encrypt staging server.

