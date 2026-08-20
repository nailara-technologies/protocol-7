# Net::Async::HTTP + Event.pm Integration

## Breakthrough Discovery

`IO::Async::Loop::Event` allows Net::Async::HTTP to use Event.pm as its underlying event loop!

**Key Insight**: We don't need timer-based polling. We can have truly event-driven HTTP without forking.

---

## Architecture

```
Event.pm (existing)
    |
    +-- IO::Async::Loop::Event (bridge)
            |
            +-- Net::Async::HTTP
                    |
                    +-- HTTP requests (truly async, no polling)
```

All event handling still goes through Event.pm underneath - no duplicate loops!

---

## Why This is Better Than HTTP::Async

| Feature | HTTP::Async | Net::Async::HTTP |
|---------|-------------|------------------|
| Event handling | Timer polling (100ms) | True event-driven |
| Memory | ~2MB | ~2MB |
| CPU | Wakes every 100ms | Only on I/O activity |
| Complexity | Simple | Medium |
| Integration | Timer handler | Event.pm native |
| Futures | No | Yes (modern async) |

**Winner**: Net::Async::HTTP with Event bridge

---

## Implementation Sketch

### 1. Init Code (One-time setup)

```perl
## src/models.init_code ##

## Load required modules
<[base.perlmod.autoload]>->('IO::Async::Loop::Event');
<[base.perlmod.autoload]>->('Net::Async::HTTP');

## Create loop bridge using Event.pm
<models.io_async.loop> = IO::Async::Loop::Event->new();

## Create HTTP client
<models.async.http> = Net::Async::HTTP->new(
    max_connections_per_host => 4,
    timeout                  => 30,
);

## Add HTTP client to loop
<models.io_async.loop>->add(<models.async.http>);

## Start the loop bridge (integrates with Event.pm)
## Note: Loop runs via Event.pm callbacks, no separate run() needed
```

### 2. Invocation (Non-blocking)

```perl
## src/models.backend.local.invoke ##

my $request = HTTP::Request->new(
    POST => "$llama_server_url/v1/chat/completions",
    [ 'Content-Type' => 'application/json' ],
    $json_payload
);

## Start async request, get Future
my $future = <models.async.http>->do_request(
    request => $request,
);

## Attach callback for completion
$future->on_done(sub {
    my $response = shift;
    handle_success($response, $inference_id);
});

$future->on_fail(sub {
    my $error = shift;
    handle_error($error, $inference_id);
});

## Return immediately (non-blocking)
return {
    'success'        => TRUE,
    'pending'        => TRUE,
    'inference_id'   => $inference_id,
};
```

### 3. No Timer Needed!

The Event.pm loop (already running) handles everything:
- Socket readability → triggers HTTP response handling
- No polling, no timers
- Zero CPU when idle

---

## Integration with Existing Code

### Event.pm Compatibility

```perl
## Our existing Event.pm code continues unchanged:
<[event.add_timer]>->(...);      ## Still works
<[event.add_io]>->(...);          ## Still works
<[event.add_signal]>->(...);      ## Still works

## IO::Async integrates transparently:
## - Uses same Event.pm select/poll/epoll
## - Shares same file descriptor watchers
## - No conflicts
```

### Lifecycle Management

```perl
## Startup (in zenka init)
## - Create IO::Async::Loop::Event
## - Create Net::Async::HTTP
## - Add to loop

## Runtime
## - Event.pm runs as usual
## - HTTP responses handled via Futures

## Shutdown
## - Remove HTTP from loop
## - Destroy loop bridge
```

---

## Memory Comparison

| Approach | Memory | Notes |
|----------|--------|-------|
| Fork (current) | 100MB | Per request |
| HTTP::Async | 2MB | + timer overhead |
| **Net::Async::HTTP** | **2MB** | **Zero polling overhead** |

---

## Dependencies

Already installed:
- ✅ `libnet-async-http-perl`
- ✅ `Event.pm` (existing)

Need to verify:
- `IO::Async::Loop::Event` (may need separate install)

---

## Migration Strategy

### Phase 1: Verify IO::Async::Loop::Event
```bash
## Check if available
perl -MIO::Async::Loop::Event -e 'print "OK\n"'

## If not, install:
## apt-get install libio-async-loop-event-perl
## or cpan IO::Async::Loop::Event
```

### Phase 2: Prototype in models.init_code
- Add loop bridge
- Add Net::Async::HTTP
- Test with simple request

### Phase 3: Update local.invoke
- Replace fork with async HTTP
- Use Future-based API
- Remove all curl/pipe code

### Phase 4: Production
- Deploy with local models
- Monitor memory usage
- Apply to download zenka

---

## Example: Complete Flow

```perl
## 1. Init (once at startup)
use IO::Async::Loop::Event;
use Net::Async::HTTP;

my $loop = IO::Async::Loop::Event->new();
my $http = Net::Async::HTTP->new();
$loop->add($http);

## 2. Request (in local.invoke)
my $future = $http->do_request(
    request => HTTP::Request->new(POST => $url, $headers, $body),
);

$future->on_done(sub {
    my $response = shift;
    ## Handle response
    process_llama_response($response);
});

## 3. Event.pm loop runs everything
## No explicit loop->run() needed!
## Event.pm calls IO::Async callbacks as needed
```

---

## Risks and Mitigations

| Risk | Mitigation |
|------|------------|
| IO::Async::Loop::Event not available | Install from CPAN or use HTTP::Async fallback |
| Event loop conflicts | Test thoroughly, both loops use same underlying fd watchers |
| Memory leaks | Proper Future cleanup, monitor with valgrind |
| Debugging complexity | Log extensively, add tracing |

---

## Recommendation

**Proceed with Net::Async::HTTP + IO::Async::Loop::Event**

This gives us:
- ✅ True event-driven HTTP (no polling)
- ✅ Memory efficient (2MB, no fork)
- ✅ Event.pm compatible
- ✅ Modern Future-based API
- ✅ Clean project integration

Next step: Verify IO::Async::Loop::Event availability, then prototype.

---

#,,,.,,,.,,,,,,,.,,..,.,,,,.,,...,,,,,,..,,.,,.,.,...,...,.,,,,,.,...,..,,.,,,
#BHGUWCITCVEIMVPAJQXY7EB2WX56WFHXDX4PN5WEUMKXDUU7E363WTBRLWWI35VDSS2IL2LRTI6VG
#\\\|OAMDEYSGP6HC7ILPBXEOVEXOO6XRFF5RNSWJQS4RGCCGLZQPHWY \ / AMOS7 \ YOURUM ::
#\[7]JYUDVRVWKS6WWUKX3PSBDULNMB7HXTOREQINUUHFMQZ7HHTLQECQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
