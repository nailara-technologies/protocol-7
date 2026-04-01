# Coding Zenka Inference Server Restart Policy

**Priority:** High
**Type:** Reliability / Fault Tolerance
**Component:** coding zenka
**Related:** modules/coding.inference_servers, modules/coding.handler.spawn_reply

## Problem

The coding zenka spawns llama-server processes but doesn't reliably detect when they crash. When the server dies:
- Tasks fail with "Connection refused" errors
- No automatic restart occurs
- User must manually restart coding zenka

## Current Behavior

```
GPU server spawned [pid=130190] - monitoring startup
inference server spawning complete
... later ...
server error [retrying, 1 left]
server error [retrying, 0 left]
inference error: 500 Can't connect to localhost:8000 (Connection refused)
```

The coding zenka monitors startup but not runtime health.

## Desired Behavior

1. **Detect crashes immediately** via:
   - SIGCHLD signal handler when llama-server process dies
   - STDERR/STDOUT monitoring for "error" or "fatal" patterns
   - Periodic health check (HTTP probe to /health endpoint)

2. **Automatic restart** with:
   - Exponential backoff (5s, 10s, 20s, 30s, max 60s)
   - Max retry limit (5 attempts before marking unavailable)
   - Clear logging of restart attempts

3. **Task handling**:
   - Queue tasks during restart window
   - Fail fast with clear error if max retries exceeded
   - Notify user of server issues

## Implementation Approach

### Option 1: SIGCHLD Handler (Recommended)

In `coding.init_code` or `coding.inference_servers`:

```perl
## register SIGCHLD handler for inference server monitoring ##
<[event.add_signal]>->(
    {   'signal'  => 'CHLD',
        'handler' => 'coding.handler.inference_server_sigchld'
    }
);

## in coding.handler.inference_server_sigchld ##
my $gpu_pid = <coding.inference_servers>{'gpu'}{'pid'};
if ( $child_pid == $gpu_pid ) {
    <[base.logs]>->(0, ': GPU inference server crashed [pid=%d]', $child_pid);
    <[event.add_timer]>->(
        {   'after'   => <coding.inference_restart_delay>,
            'handler' => 'coding.handler.restart_inference_server'
        }
    );
}
```

### Option 2: Health Check Timer

Periodic HTTP health check:

```perl
## add to coding.init_code ##
<[event.add_timer]>->(
    {   'interval' => 30.0,
        'handler'  => 'coding.handler.inference_health_check'
    }
);

## in coding.handler.inference_health_check ##
my $url = <coding.inference_servers>{'gpu'}{'url'} . '/health';
my $healthy = <[http.quick_probe]>->($url);
if ( not $healthy ) {
    <[coding.inference.restart_with_backoff]>->('gpu');
}
```

### Option 3: Pipe Monitoring

Monitor server's STDOUT/STDERR via pipes for crash patterns:

```perl
## when spawning, capture pipes ##
my ($stdout_r, $stderr_r) = ...;
<[event.add_io]>->(
    {   'fd'      => $stderr_r,
        'handler' => 'coding.handler.inference_stderr',
        'read'    => 1
    }
);
```

## Implementation Status

- [x] `modules/coding.init_code` - Register SIGCHLD handler
- [x] `modules/coding.handler.inference_server_sigchld` - Detect crashes
- [x] `modules/coding.handler.inference_crash_restart` - Restart with backoff
- [x] `modules/coding.handler.verify_inference_startup` - Verify recovery
- [ ] `modules/coding.inference_servers` - Track restart state (optional enhancement)

## Files Created/Modified

- `modules/coding.init_code` - Added SIGCHLD registration
- `modules/coding.handler.inference_server_sigchld` - NEW: Crash detection
- `modules/coding.handler.inference_crash_restart` - NEW: Restart with backoff
- `modules/coding.handler.verify_inference_startup` - NEW: Startup verification

## Testing

1. Kill llama-server manually: `kill -9 <pid>`
2. Verify coding zenka detects crash in logs
3. Verify automatic restart occurs
4. Verify queued tasks resume
5. Verify max retry limit enforced

## Acceptance Criteria

- [ ] Inference server crash detected within 5 seconds
- [ ] Automatic restart with exponential backoff
- [ ] Tasks queued during restart, not failed
- [ ] Clear error after max retries exceeded
- [ ] Logs show restart attempts and reasons

## References

- Similar pattern in `kimi-web.handler.agent_health_check`
- `base.event.add_signal` for SIGCHLD handling
- `coding.inference_servers` data structure

#,,,,,,..,.,,,.,.,.,.,,..,,..,.,,,...,,..,.,.,..,,...,...,..,,.,.,,.,,,..,,.,,
#DWLD7HHD32FBMQ2AGANUJLEMUTGZ2NJ2BMAPK73L7Q5CA6J66U4Z44J7H2YY6EF3PGLYONC3AEZLA
#\\\|W2TJKI4U3EEIAHYF36LNJBW7R4LGNQRODP2F2L6PFTUDH46XVZO \ / AMOS7 \ YOURUM ::
#\[7]FDZVJDMSXHLVNVBIIH4R3HEX2PPYD2U5TDTFVGTDO7XYD2WZJ6AA 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
