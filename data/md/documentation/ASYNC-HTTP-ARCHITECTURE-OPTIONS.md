# Async HTTP Architecture Options for Local Models

## Problem Statement

Current approach forks the entire zenka (100MB) for each HTTP request to llama-server.

Requirements:
- ✅ Non-blocking (models can take seconds)
- ✅ Memory efficient (avoid 100MB fork)
- ✅ Project-style integration
- ✅ Reusable for download zenka and others

---

## Option 1: HTTP::Async (Recommended)

### Overview
Process multiple HTTP requests in parallel without forking.

### Pros
- ✅ **No forking** - runs in same process
- ✅ **Memory efficient** - minimal overhead
- ✅ **Already installed** (`libhttp-async-perl`)
- ✅ **Simple integration** - works with Event.pm
- ✅ **Well-tested** - CPAN stable

### Cons
- ❌ **Requires polling** - need event loop integration
- ❌ **Not truly event-driven** - must call `next_response()` periodically

### Integration Pattern
```perl
## In init_code ##
<local.async.http> = HTTP::Async->new(
    slots => 4,           ## concurrent requests
    timeout => 30,
);

## In invoke ##
my $request = HTTP::Request->new(POST => $url, $headers, $json);
<local.async.http>->add($request);

## In event handler (periodic or io watch) ##
if (my $response = <local.async.http>->next_response) {
    ## Handle completed request
}
```

### Event Loop Integration
```perl
## Add periodic timer to check for responses
<[event.add_timer]>->(
    {   'interval' => 0.1,  ## 100ms
        'repeat'   => TRUE,
        'handler'  => 'models.handler.check_local_responses',
    }
);
```

---

## Option 2: Lightweight Fork (base.start.unlink_child pattern)

### Overview
Spawn minimal perl process with only required code.

### Pros
- ✅ **True process isolation** - crashes don't affect parent
- ✅ **Memory efficient** - ~10MB instead of 100MB
- ✅ **Project pattern** - base.start.unlink_child exists
- ✅ **Self-contained** - passes code via stdin/file

### Cons
- ❌ **More complex IPC** - need response routing
- ❌ **Process management** - zombie prevention, cleanup
- ❌ **Code duplication** - need minimal perl script

### Integration Pattern
```perl
## Spawn minimal perl with HTTP code ##
my $minimal_code = generate_minimal_http_client();
my $pid = fork();
if ($pid == 0) {
    ## Child: minimal perl
    exec('perl', '-e', $minimal_code, $url, $json);
}
## Parent: watch via pipe/socket
```

### Minimal HTTP Client Template
```perl
#!/usr/bin/perl
use HTTP::Request;
use LWP::UserAgent;
## Read request from parent
## POST to llama-server
## Write response back to parent
## Exit
```

---

## Option 3: Protocol-7 Native Networking

### Overview
Use existing protocol-7 async networking primitives for HTTP.

### Pros
- ✅ **Most project-native** - no external deps
- ✅ **Full event integration** - io.add_event, callbacks
- ✅ **Flexible** - handle any protocol
- ✅ **Reusable** - benefits all network code

### Cons
- ❌ **Most complex** - implement HTTP/1.1 from scratch
- ❌ **Time investment** - weeks not days
- ❌ **Error prone** - HTTP edge cases

### Implementation
Need to implement:
- HTTP request formatting
- Chunked transfer encoding
- Response parsing
- Keep-alive handling
- Error handling

---

## Option 4: STRM Mode + Download Zenka

### Overview
Extend download zenka to handle POST requests with STRM reply mode.

### Pros
- ✅ **Existing infrastructure** - download zenka mature
- ✅ **Streaming support** - natural for large responses
- ✅ **Process separation** - clean architecture

### Cons
- ❌ **Significant work** - new features needed
- ❌ **Not local-optimal** - download zenka is for remote
- ❌ **Complex protocol** - STRM-SIZE fragmentation

---

## Option 5: Net::Async::HTTP

### Overview
Event-driven HTTP using IO::Async framework.

### Pros
- ✅ **True async** - event-driven, no polling
- ✅ **Modern** - built for this use case

### Cons
- ❌ **IO::Async conflict** - different event system than Event.pm
- ❌ **Integration risk** - may not work with existing code

---

## Recommendation: HTTP::Async + Periodic Timer

### Why This Option

1. **Immediate availability** - already installed
2. **Minimal code changes** - drop-in replacement for fork
3. **Proven stability** - CPAN module, widely used
4. **Memory efficient** - no fork overhead
5. **Reusable** - same pattern works for download zenka

### Architecture

```
models.backend.local.invoke
    |
    |-- HTTP::Async->add($request)
    |
    |-- Return immediately (pending)
    |
event.timer (100ms)
    |
    |-- HTTP::Async->next_response
    |       |
    |       +-- Response ready? -> Handle it
    |       +-- No response? -> Wait for next timer
    |
    +-- Continue polling...
```

### Implementation Sketch

```perl
## src/models.backend.local.invoke ##

## Add request to async queue
my $request = HTTP::Request->new(POST => $url, $headers, $json);
my $id = <local.async.http>->add($request);

## Store pending request metadata
<local.pending_requests>->{$id} = {
    inference_id => $inference_id,
    start_time   => time(),
};

## Return immediately
return { pending => TRUE, inference_id => $inference_id };

## src/models.handler.check_local_responses ##

## Called by periodic timer
while (my $response = <local.async.http>->next_response) {
    my $id = $response->request->header('X-Request-ID');
    my $pending = delete <local.pending_requests>->{$id};

    ## Process response, call completion handler
    handle_response($response, $pending);
}
```

### Benefits Over Current Fork

| Metric | Fork Approach | HTTP::Async |
|--------|--------------|-------------|
| Memory | 100MB (fork) | ~2MB (same process) |
| Startup | Fork overhead | Immediate |
| Cleanup | PID management | Object destruction |
| Complexity | Fork + pipes | Event + polling |
| Debug | Hard (separate process) | Easy (same process) |

### Migration Path

1. **Phase 1**: Implement HTTP::Async in local.invoke
2. **Phase 2**: Test with local models (2 days available)
3. **Phase 3**: Apply same pattern to download zenka
4. **Phase 4**: Deprecate fork-based curl approach

---

## Decision

**Go with HTTP::Async + periodic timer polling**.

- Immediate implementation possible
- Proven technology
- Minimal memory overhead
- Reusable across codebase
- Clean integration with Event.pm

Next step: prototype the integration in `models.backend.local.invoke`.

---

#,,,.,,,.,,,,,.,.,,.,,,,.,,,,,,.,,,,.,,..,.,.,.,.,...,...,,,.,,.,,.,,,...,...,
#5NNOZT67KV4OITQXKSLSPQ2N3OZ23SBPMB3BNW6EBAK2XMNYJTNTHZ4U5XNSZDSVMUNYGT43XCZ5E
#\\\|3UY3N5DHSRANMA6WODXEOQS6KJRS6UEKXKU2VFYO3XH3B73BKT6 \ / AMOS7 \ YOURUM ::
#\[7]NRWVKYXYY77FKBYP4MHOUBCEMLSGXJE3S6AYMW2AOJ4R5GSDSWDI 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
