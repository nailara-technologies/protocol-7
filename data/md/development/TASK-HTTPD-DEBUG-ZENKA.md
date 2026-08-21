# Task: Implement httpd-debug Zenka for Request State Capture

**Status**: Planned (Next Session)
**Priority**: High
**Harmony Check**: `httpd-debug` ✅ TRUE

## Overview

Create a dedicated `httpd-debug` zenka that captures, stores, and reproduces HTTP request states for debugging event loop blocking issues and providing regression testing infrastructure.

## Problem Statement

The httpd zenka occasionally blocks the event loop, causing response timeouts and restarts. Current challenges:
- Cannot reliably capture request details that triggered the block
- Race conditions may lose request data during crashes
- Need to wait hours for crashes to occur to diagnose issues
- Difficult to reproduce specific blocking requests for debugging

## Solution Architecture

Implement a **request state hook system** where httpd sends all request data to httpd-debug before processing, similar to how external authorization backends work (LDAP, OAuth, etc.).

### Key Design Principles

1. **Proactive capture** - Store request state BEFORE processing starts
2. **Guaranteed persistence** - Acknowledge receipt before httpd proceeds
3. **Reusable pattern** - Generalizable to https, web template zenka, and other integrations
4. **Non-invasive** - Separate zenka means no debug code pollution in regular httpd
5. **Permanent value** - Becomes regression test and performance benchmark infrastructure

## Implementation Plan

### Phase 1: httpd-debug Zenka Core

**New Module**: `cfg/zenki/httpd-debug/zenka.v7`

```perl
# Configuration structure:
modules.load = base httpd-debug.init_code httpd-debug.handler.*

# Startup parameters:
httpd-debug.cfg.storage_dir = '/var/httpd-debug/requests'
httpd-debug.cfg.max_stored_states = 10000
```

**New Modules**:
- `src/httpd-debug.init_code` - Initialize storage, create directories, load handlers
- `src/httpd-debug.handler.store_request` - Receive serialized request, store by AMOS checksum
- `src/httpd-debug.handler.reproduce_request` - Load request state and trigger reprocessing
- `src/httpd-debug.handler.list_states` - List captured request states
- `src/httpd-debug.handler.query_state` - Retrieve details of specific request state

### Phase 2: Request State Hook in httpd

**Modified Module**: `src/httpd.request_handler`

Add hook point at request start:

```perl
# Serialize request before processing
my $request_state = {
    'timestamp'     => time(),
    'method'        => $request->{'method'},
    'uri'           => $request->{'uri'},
    'headers'       => $request->{'headers'},
    'session_id'    => $session_id,
    'http_host'     => $session->{'http_host'},
    'source_ip'     => $session->{'peerhost'},
};

# Send to httpd-debug and wait for ack
my $ack = <[httpd.send_debug_state]>->($request_state);
return <[httpd.send_error_page]>->($session_id, 500)
    unless defined $ack;

# Proceed with normal processing
# ... existing handler code ...
```

**New Module**: `src/httpd.send_debug_state`
- Serialize request state to JSON/AMOS format
- Send to httpd-debug zenka
- Wait for acknowledgement with AMOS checksum
- Return checksum on success

### Phase 3: Request Reproduction Infrastructure

**New Modules**:
- `src/httpd-debug.replay_request` - Simulate request processing from stored state
- `src/httpd-debug.handler.benchmark` - Run performance benchmarks with captured requests
- `src/httpd-debug.handler.regression_test` - Validate stored requests still process cleanly

## Data Storage Format

Stored request state structure:
```
/var/httpd-debug/requests/
├── AMOS_CHECKSUM_1/
│   ├── request.json          # Full serialized request
│   ├── timestamp             # Unix timestamp
│   └── metadata.json         # Processing metadata
├── AMOS_CHECKSUM_2/
└── ...
```

## API

### httpd-debug Commands

```perl
# Store and acknowledge request
httpd-debug.handler.store_request($session_id, $request_state_ref)
  → Returns: { 'amos_checksum' => 'XXXXX' }

# Reproduce exact request
httpd-debug.reproduce_request($amos_checksum)
  → Loads request state, processes through normal httpd handlers

# List all captured states
httpd-debug.list_states()
  → Returns: [ { 'checksum' => 'X', 'method' => 'GET', 'uri' => '/...' }, ... ]

# Get state details
httpd-debug.query_state($amos_checksum)
  → Returns: Full serialized request state
```

## Testing Strategy

1. **Unit tests**: Verify state serialization/deserialization
2. **Integration tests**: Verify hook doesn't impact normal httpd operation
3. **Regression tests**: Build test suite from captured blocking requests
4. **Performance tests**: Benchmark overhead of state capture

## Benefits

- ✅ **Deterministic debugging** - Reproduce exact requests via AMOS checksum
- ✅ **No data loss** - Persistent storage before processing
- ✅ **Comprehensive coverage** - Captures all requests, not just crashes
- ✅ **Reusable pattern** - Extends to https, web templates, other integrations
- ✅ **Permanent infrastructure** - Becomes regression/benchmark suite
- ✅ **Clean separation** - Debug code isolated from production zenki

## Future Extensions

- Integrate with https zenka for SSL/TLS debugging
- Extend to web template zenka for dynamic parsing issues
- Build performance benchmark suite from real captured requests
- Implement request filtering (capture only specific patterns)
- Add statistical analysis of blocking request characteristics

## Notes

- Harmony validated: `httpd-debug` passes AMOS7 harmony script
- Estimated effort: 2-3 sessions
- No impact to production code (separate zenka)
- Can be deployed alongside existing httpd without risk

#,,,,,,.,,.,,,,,,,.,,,...,..,,,,,,...,.,,,,,.,..,,...,..,,...,.,.,,,,,,.,,.,.,
#TC2J7ZODWQCU6S5ERWQCCQ7REG4YMMAIJUSPV2EGIEHCKZUWYGWS5NLMPLKAC7NIMXFVANUNJN754
#\\\|QRZXKCGVG4GTLUICQ7TZD4QSJ7KIRQPGCWVNAQCZQRJPR3WXXSB \ / AMOS7 \ YOURUM ::
#\[7]OH223O2D2WSHVDIELIW5G5DPDB77KJOJO6YVMSCYRXHRPVYRSYCA 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
