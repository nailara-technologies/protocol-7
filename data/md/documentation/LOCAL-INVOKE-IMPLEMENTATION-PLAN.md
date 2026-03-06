# local.invoke Implementation Plan
## Net::Async::HTTP + Event.pm Integration

---

## Prerequisites

- [ ] Install `IO::Async::Loop::Event` from CPAN globally
- [ ] Verify `libnet-async-http-perl` is installed (apt)

---

## Architecture Overview

```
┌─────────────────────────────────────────────────────────────┐
│                    Event.pm (existing)                       │
│  ┌──────────────┐  ┌──────────────┐  ┌─────────────────┐   │
│  │  IO timers   │  │  fd watchers │  │  signal handlers│   │
│  └──────┬───────┘  └──────┬───────┘  └─────────────────┘   │
│         │                 │                                  │
│  ┌──────▼─────────────────▼──────┐                          │
│  │   IO::Async::Loop::Event      │  ← bridge layer         │
│  │   (uses Event.pm underneath)  │                          │
│  └──────────────┬────────────────┘                          │
│                 │                                            │
│  ┌──────────────▼────────────────┐                          │
│  │   Net::Async::HTTP            │  ← async HTTP client     │
│  │   (truly event-driven)        │                          │
│  └───────────────────────────────┘                          │
└─────────────────────────────────────────────────────────────┘
```

**Key Insight**: No polling! Event.pm handles all I/O; HTTP responses trigger callbacks directly.

---

## Implementation Phases

### Phase 1: Init Code (models.init_code)

Create the loop bridge once at zenka startup:

```perl
## modules/models.init_code ##
# name = models.init_code
# descr = one-time setup for models zenka

## Load event loop bridge
<[base.perlmod.autoload]>->('IO::Async::Loop::Event');
<[base.perlmod.autoload]>->('Net::Async::HTTP');

## Create loop (uses Event.pm underneath)
<models.io_async.loop> = IO::Async::Loop::Event->new();

## Create HTTP client
<models.async.http> = Net::Async::HTTP->new(
    max_connections_per_host => 4,
    timeout                  => 30,
    user_agent               => "Protocol-7-Models/1.0",
);

## Add to loop (registers with Event.pm)
<models.io_async.loop>->add(<models.async.http>);

<[base.log]>->(2, "models: async HTTP initialized (Event.pm loop)");
```

### Phase 2: Invoke Module (models.backend.local.invoke)

Non-blocking request with Future-based callbacks:

```perl
## modules/models.backend.local.invoke ##
# name = models.backend.local.invoke
# descr = local backend with async HTTP

my $params = shift;
my $job_id = $params->{'job_id'};
my $model_id = $params->{'model_id'};
my $messages = $params->{'messages'};

## Render system message from template (existing code)
my $system_prompt = render_system_template($params);

## Build request
my $payload = {
    model       => $model_id,
    messages    => $messages,
    temperature => $params->{'temperature'} // 0.7,
    max_tokens  => $params->{'max_tokens'} // 2048,
};
$payload->{system} = $system_prompt if length($system_prompt);

my $request = HTTP::Request->new(
    POST => "http://localhost:8080/v1/chat/completions",
    [ 'Content-Type' => 'application/json' ],
    JSON::PP::encode_json($payload)
);

## Start async request
my $future = <models.async.http>->do_request(request => $request);

## Generate inference ID for tracking
my $inference_id = generate_inference_id($job_id);

## Attach completion handlers
$future->on_done(sub {
    my $response = shift;
    handle_llm_response($response, $inference_id, $job_id);
});

$future->on_fail(sub {
    my $error = shift;
    handle_llm_error($error, $inference_id, $job_id);
});

## Return immediately (non-blocking)
return {
    success      => TRUE,
    pending      => TRUE,
    inference_id => $inference_id,
};
```

### Phase 3: Response Handlers

```perl
## modules/models.handle.response ##
# name = models.handle.response
# descr = process completed LLM response

my ($response, $inference_id, $job_id) = @_;

if (!$response->is_success) {
    <[base.log]>->(0, "LLM request failed: " . $response->status_line);
    <[models.report.failure]>->($job_id, $response->status_line);
    return;
}

my $data = eval { JSON::PP::decode_json($response->content) };
if ($@) {
    <[base.log]>->(0, "JSON parse error: $@");
    <[models.report.failure]>->($job_id, "parse error");
    return;
}

my $content = $data->{choices}[0]{message}{content} // '';

## Report completion
<[models.report.completion]>->(
    job_id       => $job_id,
    inference_id => $inference_id,
    content      => $content,
    tokens_used  => $data->{usage}{total_tokens} // 0,
);
```

---

## Event Flow

```
1. local.invoke called
        ↓
2. Create HTTP request
        ↓
3. $http->do_request() returns Future
        ↓
4. Future callbacks attached (on_done, on_fail)
        ↓
5. Return immediately (job marked "pending")
        ↓
[Event.pm continues running]
        ↓
6. [Later] llama-server responds
        ↓
7. Event.pm sees socket readable
        ↓
8. IO::Async::Loop::Event callback fires
        ↓
9. Net::Async::HTTP processes response
        ↓
10. Future->on_done callback executes
        ↓
11. models.handle.response processes result
        ↓
12. Completion reported to parent
```

**Zero polling. Zero forks. Pure event-driven.**

---

## Memory Comparison

| Approach | Per-Request Memory | CPU When Idle |
|----------|-------------------|---------------|
| Fork (current) | 100MB | N/A (process exits) |
| HTTP::Async + timer | 2MB | Wakes every 100ms |
| **Net::Async::HTTP** | **2MB** | **Zero** |

---

## Error Handling

| Scenario | Handling |
|----------|----------|
| llama-server down | Future->on_fail triggers, report failure |
| Timeout | Net::Async::HTTP timeout, Future fails |
| JSON error | eval wrapper, report parse failure |
| Connection reset | Retry logic or immediate failure |

---

## Testing Strategy

1. **Unit test**: Mock llama-server response
2. **Integration test**: Start llama-server, send request, verify callback
3. **Stress test**: 100 concurrent requests
4. **Memory test**: Monitor RSS during test

---

## Migration Checklist

- [ ] Install dependencies (`IO::Async::Loop::Event`)
- [ ] Create `models.init_code` with loop setup
- [ ] Refactor `models.backend.local.invoke` for async
- [ ] Create `models.handle.response` callback
- [ ] Create `models.handle.error` callback
- [ ] Test with mock server
- [ ] Test with real llama-server
- [ ] Remove old fork-based code
- [ ] Update documentation

---

## Next Step

**Waiting for**: Global installation of `IO::Async::Loop::Event`

Once installed, we can proceed with Phase 1 implementation.

---

#,,.,,,,.,,.,,,,,,,,.,,,,,,..,,..,...,,,,,,.,,.,.,...,...,...,...,,,,,,..,,.,,
#L65TVI2B4H26U6DWTOSK2UEQGUBHX7GHLXEDCW4E2LTTHJUGD6ZYAQKMFAPHE5OISCUI5X5MZEU3O
#\\\|DAHGXTORNJ2MIJCZ2LXJRPIVK7YL233HWKNF73MA4IMSBI6GARF \ / AMOS7 \ YOURUM ::
#\[7]BTC6MOX57FL7FGKOFBS3DT5DF3QPCHWU44ABIYGKNAQUCVWHM4CY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
