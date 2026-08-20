# local.invoke Event.pm Integration
## Using AnyEvent::HTTP (No Polling!)

---

## The Problem with IO::Async

`IO::Async::Loop::Event` **does NOT** integrate cleanly with existing Event.pm instances:

```perl
## ❌ WRONG: Creates separate loop that needs polling
my $http_loop = IO::Async::Loop::Event->new;  ## Own Event.pm instance!
my $http = Net::Async::HTTP->new;
$http_loop->add($http);

## Must poll manually from main loop:
$http_loop->loop_once(0.01);  ## Timer-based polling 😞
```

This requires `loop_once()` polling - exactly what we wanted to avoid!

---

## The Solution: AnyEvent::HTTP

**AnyEvent acts as a thin abstraction layer** over Event.pm (among others):

```
┌─────────────────────────────────────────────────────────────┐
│                    Event.pm (existing)                       │
│  ┌──────────────┐  ┌──────────────┐  ┌─────────────────┐   │
│  │  IO timers   │  │  fd watchers │  │  signal handlers│   │
│  └──────┬───────┘  └──────┬───────┘  └─────────────────┘   │
│         │                 │                                  │
│  ┌──────▼─────────────────▼──────┐                          │
│  │      AnyEvent::HTTP           │  ← registers directly    │
│  │      (uses Event.pm API)      │     into YOUR Event.pm   │
│  └───────────────────────────────┘                          │
└─────────────────────────────────────────────────────────────┘
```

**Key difference**: AnyEvent::HTTP calls `Event->io()` and `Event->timer()` directly on YOUR existing Event.pm instance.

---

## Code Comparison

### ❌ IO::Async (requires polling)
```perl
use IO::Async::Loop::Event;
use Net::Async::HTTP;

my $http_loop = IO::Async::Loop::Event->new;
my $http = Net::Async::HTTP->new;
$http_loop->add($http);

my $future = $http->do_request(request => $request);
$future->on_done(sub { handle_response(shift) });

## MUST add timer to main loop:
<[event.add_timer]>->(
    interval => 0.01,
    callback => sub { $http_loop->loop_once(0) }
);
```

### ✅ AnyEvent::HTTP (native integration)
```perl
use AnyEvent::HTTP;

$AnyEvent::MODEL = 'Event';  ## Use Event.pm backend

http_post($url, $body, headers => \%headers, sub {
    my ($body, $headers) = @_;
    handle_response($body, $headers);
});

## No polling needed! Watcher registered directly in Event.pm
```

---

## Implementation

### Init Code
```perl
## src/models.init_code
$AnyEvent::MODEL = 'Event';  ## Ensure Event.pm backend
<[base.perlmod.autoload]>->('AnyEvent::HTTP');
$AnyEvent::HTTP::MAX_PER_HOST = 4;
$AnyEvent::HTTP::TIMEOUT = 300;
```

### Invocation
```perl
## src/models.backend.local.invoke
http_post(
    "$llama_url/v1/chat/completions",
    $json_body,
    headers => { 'Content-Type' => 'application/json' },
    sub {
        my ($body, $headers) = @_;
        <[models.handle.llm_response]>->(
            { inference_id => $inference_id,
              body => $body, headers => $headers }
        );
    }
);
```

### Response Handler
```perl
## src/models.handle.llm_response
my ($body, $headers) = ($params->{'body'}, $params->{'headers'});

if ($headers->{'Status'} =~ /^2/) {
    my $data = JSON::PP::decode_json($body);
    my $content = $data->{'choices'}[0]{'message'}{'content'};
    ## ... send reply
}
```

---

## How Event.pm Integration Works

When you call `http_post()`:

1. AnyEvent::HTTP creates an HTTP request
2. AnyEvent detects Event.pm is loaded (`$AnyEvent::MODEL = 'Event'`)
3. AnyEvent calls `Event->io(fd => $socket_fd, ...)` to watch socket
4. Your existing Event.pm loop waits (alongside other watchers)
5. When llama-server responds, Event.pm triggers callback
6. AnyEvent::HTTP callback runs with response body/headers

**Zero polling. Zero separate loops. True event-driven.**

---

## Dependencies

```yaml
## .deps/profiles.yaml
ai-models:
  apt:
    - libanyevent-http-perl   ## Already installed ✓
    - libanyevent-perl        ## Already installed ✓
```

**No CPAN modules needed!** (Remove `IO::Async::Loop::Event`)

---

## Memory Comparison

| Approach | Memory | Polling | Integration |
|----------|--------|---------|-------------|
| Fork | 100MB | N/A | Process-based |
| IO::Async | 2MB | Yes (loop_once) | Separate loop |
| **AnyEvent::HTTP** | **2MB** | **No** | **Native** |

---

## Testing

```bash
## 1. Verify Event.pm backend
perl -MAnyEvent -e '$AnyEvent::MODEL="Event"; print AnyEvent->detect, "\n"'
## Should output: Event

## 2. Start models zenka
./bin/v7 -r models

## 3. Test request
./bin/v7 -c models << 'EOF'
cmd: models.backend.local.invoke
params:
  model_id: "test-model"
  messages:
    - role: user
      content: "Hello"
  reply_id: "test_123"
EOF
```

---

## Summary

✅ **No polling** - Watches registered directly in Event.pm
✅ **Native integration** - Uses AnyEvent's Event.pm backend
✅ **Pure Debian packages** - No CPAN dependencies
✅ **Memory efficient** - ~2MB per concurrent request
✅ **Callback-based** - Simple, proven async pattern

---

#,,.,,,,.,..,,,,,,,,,,.,,,,..,,,,,...,,,.,..,,.,.,...,...,...,..,,...,,,.,,,.,
#V5PGOXQTHW3VNELUWUV6BMCQD57OJJ4V52MNDABC3I66KEDUDXU5QO5D4WHL4GBWMEM7V2IDOC7ZQ
#\\\|ORRLPSFBOO7T3PEY7TAXIQSXPXWR3LKM64HCU7F6HOD3Y5I5K7A \ / AMOS7 \ YOURUM ::
#\[7]ENKFMG75WVONPG3BOALTUWTMGUABRZWYMNRVA6GYJGK7G2ZHPQBQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
