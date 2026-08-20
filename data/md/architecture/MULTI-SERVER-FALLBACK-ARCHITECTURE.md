# Multi-Server Fallback Architecture for Coding Zenka

## Overview

The coding zenka needs to support multiple llama-server instances as fallback options. This enables:
- Graceful degradation when one server is unavailable
- Load balancing across multiple servers
- Testing different server variants (GPU, CPU, quantized models)
- Easy switching between model sizes

## Architecture

### Server Registry

Configuration file: `cfg/zenki/coding/llama-servers`

```ini
# Server registry with priority-based fallback
servers = [
    {
        name       = "gpu-large",
        variant    = "7B-GGUF",
        port       = 8080,
        cuda_min   = "12.8",
        priority   = 1,
        enabled    = true,
        models = [
            "mathstral-7B-q8_0",
            "mistral-7B-q8_0"
        ]
    },
    {
        name       = "gpu-small",
        variant    = "360M-GGUF",
        port       = 8081,
        cuda_min   = "12.8",
        priority   = 2,
        enabled    = true,
        models = [
            "smollm-360M-q8_0"
        ]
    },
    {
        name       = "cpu-fallback",
        variant    = "360M-CPU",
        port       = 8082,
        cuda_min   = "none",
        priority   = 10,
        enabled    = true,
        models = [
            "smollm-360M-q4_0"
        ]
    }
]

# Primary server selection
primary_server = "gpu-large"

# Health check settings
health_check.interval   = 30      # seconds
health_check.timeout    = 5       # seconds
health_check.endpoint   = "/health"

# Failover settings
failover.retry_count    = 3
failover.retry_delay    = 1       # seconds
failover.backoff_factor = 2.0     # exponential backoff
```

### Module Architecture

New modules needed:

1. **`coding.server.registry`** - Manage server configuration
   ```perl
   # Responsibilities:
   # - Load server registry from configuration
   # - Provide server list with priority ordering
   # - Track server health status
   ```

2. **`coding.server.health_check`** - Monitor server availability
   ```perl
   # Responsibilities:
   # - Periodic health checks on all servers
   # - Update availability cache
   # - Detect server recovery
   ```

3. **`coding.server.router`** - Route requests to available servers
   ```perl
   # Responsibilities:
   # - Select server based on priority and availability
   # - Handle failover to next server
   # - Implement exponential backoff
   # - Record failures for analysis
   ```

4. **`coding.service.llama_invoke`** - Execute inference
   ```perl
   # Responsibilities:
   # - Invoke inference on selected server
   # - Format requests/responses
   # - Handle server-specific APIs
   # - Implement retry logic
   ```

### Request Flow

```
coding.service.invoke_llama
    ↓
coding.server.router (get_available_server)
    ↓
Check if primary server is healthy
    ├─ YES → Use primary
    └─ NO → Get next available from priority list
    ↓
coding.service.llama_invoke (invoke_server)
    ↓
HTTP POST to server endpoint
    ├─ Success → Return response
    └─ Failure → Register failure, try next server
    ↓
Return to caller
```

## Implementation Strategy

### Phase 1: Basic Registry & Router (Week 1)

```perl
# coding.server.registry - Load and cache server config
sub get_servers { ... }
sub get_server_by_name { ... }
sub get_healthy_servers { ... }

# coding.server.router - Select available server
sub select_server {
    my ($primary_name, $models_needed) = @_;

    # Get servers by priority
    my @available = get_healthy_servers($models_needed);
    return undef if !@available;

    # Return highest priority available
    return $available[0];
}
```

### Phase 2: Health Monitoring (Week 2)

```perl
# coding.server.health_check - Async health checks
sub check_server_health {
    my ($server) = @_;

    my $url = "http://localhost:$server->{port}/health";
    my $response = curl_request($url, timeout => 5);

    return $response->{status} eq "ok";
}

sub start_health_monitor {
    # Fork child process for periodic checks
    # Run every $config->{health_check.interval} seconds
    # Update cache with health status
}
```

### Phase 3: Request Routing & Failover (Week 3)

```perl
# coding.service.llama_invoke with failover
sub invoke_with_failover {
    my ($request) = @_;

    my @servers = get_available_servers();
    my $retry_delay = $config->{failover.retry_delay};

    foreach my $server (@servers) {
        eval {
            my $response = invoke_server($server, $request);
            return $response if $response;
        };

        log_server_failure($server, $@);
        $retry_delay *= $config->{failover.backoff_factor};
        sleep($retry_delay);
    }

    die "All servers exhausted after " . scalar(@servers) . " attempts";
}
```

## Configuration Integration Points

### Existing Coding Zenka Files to Modify

1. **`cfg/zenki/coding/start`**
   - Load llama-servers configuration
   - Initialize server registry module
   - Start health monitor child process

2. **`cfg/zenki/coding/zenka-startup.v7`**
   - Add server registry settings
   - Add health check parameters
   - Add failover configuration

### New Files to Create

1. **`cfg/zenki/coding/llama-servers`** - Server registry
2. **`src/coding.server.registry`** - Config management
3. **`src/coding.server.health_check`** - Health monitoring
4. **`src/coding.server.router`** - Server selection
5. **`src/coding.service.llama_invoke`** - Request execution with failover

## Example Usage from Other Zenka

```perl
# In any zenka that needs inference:
my $request = {
    prompt      => "What is 2+2?",
    n_predict   => 50,
    temperature => 0.3
};

my $response = <[coding.service.llama_invoke]>->($request);
print $response->{content};

# Router automatically:
# 1. Selects healthiest server
# 2. Retries with failover if server fails
# 3. Logs performance metrics
```

## Testing Strategy

### Unit Tests
```bash
bin/Protocol-7 coding
# Test direct module calls
coding.server.registry list
coding.server.router select
coding.service.llama_invoke test-prompt
```

### Integration Tests
```bash
# Test with actual llama-server instances
./bin/dev/tests/ml/test-multi-server-failover.sh
```

### Failure Scenarios to Test
1. Primary server offline → fallback to secondary
2. All servers offline → graceful error
3. Server recovery → resume using recovered server
4. Slow server → timeout and failover
5. Model unavailable on server → select different server

## Monitoring & Observability

### Health Check Log Format
```
[2025-12-04 12:34:56] server.check: gpu-large port=8080 status=healthy
[2025-12-04 12:34:56] server.check: gpu-small port=8081 status=healthy
[2025-12-04 12:35:00] server.check: cpu-fallback port=8082 status=healthy

[2025-12-05 10:00:00] server.failure: gpu-large attempt=2 timeout=5s
[2025-12-05 10:00:05] server.recovery: gpu-large status=recovered
```

### Metrics to Track
- Server availability (uptime %)
- Request latency per server
- Failover frequency
- Model-specific performance

### Debug Output Format
```
# When inferencing
coding.llama_invoke:
  request_id: 12345
  primary_server: gpu-large (priority=1)
  server_status: healthy
  request_bytes: 256
  response_bytes: 1024
  inference_time_ms: 2345
  status: success
```

## Deployment Considerations

### Startup Sequence
1. Load server registry from configuration
2. Validate server connectivity
3. Start health monitoring child process
4. Log server availability summary
5. Accept inference requests

### Graceful Degradation
- Primary server unavailable → use highest priority available
- All servers unavailable → return error with retry suggestion
- Model unavailable → suggest alternative server with that model

### Security Considerations
- Servers on localhost only (no remote access)
- HTTP-only (not HTTPS) for internal communication
- No authentication between zenka (protocol-7 network security handles it)

## Future Enhancements

1. **Load Balancing**: Round-robin across healthy servers
2. **Adaptive Selection**: Choose server based on response time history
3. **Model Caching**: Keep track of which models are loaded where
4. **Dynamic Registration**: Add/remove servers without restart
5. **Resource Monitoring**: CPU/Memory metrics from servers
6. **Persistent Metrics**: Store failure patterns for analysis

## Related Files

- `docs/LLAMA-SERVER-INTEGRATION-FINDINGS.md` - Infrastructure analysis
- `docs/CUDA-12.8-REBUILD-INSTRUCTIONS.md` - Build instructions
- `bin/dev/tests/ml/test-llama-server-gpu.sh` - Test script
- `CLAUDE.md` - Project overview with zenka architecture

#,,,,,,,,,..,,.,.,..,,,.,,,.,,,..,..,,...,.,,,..,,...,...,,.,,,..,.,.,...,,,.,
#F7XOXIQJ3SOVAYAH6DQGPXZRTTTAQVVDPOAX4YNUGUG675I77FNESOBBQEMC4CU5YXZ6A7OPH5VMS
#\\\|54FS3KIH5MPY76TEOOXASTPWQLB2HZPPANME7L3KS5D6QFLDPVW \ / AMOS7 \ YOURUM ::
#\[7]R427LL5QPHCNIIWHGOJ4Y5CMKZA2UNKW67BXCXCNIMODVDWDTGCA 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
