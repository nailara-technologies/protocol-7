# Models Zenka Backend Integration
## Clean Multi-Backend Architecture

---

## Backend Types

| Backend | Purpose | Server Management | HTTP Client |
|---------|---------|-------------------|-------------|
| `local` | Coding-managed inference | ✅ spawn + monitor | LWP (blocking) |
| `external` | Unmanaged servers (LM Studio, etc.) | ❌ user-managed | AnyEvent::HTTP |
| `kimi_web` | Kimi-web UI via WebSocket | N/A | WebSocket |
| `api` | Cloud APIs (Claude, etc.) | N/A | TBD |

---

## Architecture Flow

```
models.chat.invoke_model
        │
        ├──► backend: local ──► models.backend.coding.invoke ──► cube.coding.ask-reply
        │                                                    └──► coding zenka
        │                                                            ├── spawn_inference_server
        │                                                            ├── task queue
        │                                                            ├── GPU/CPU routing
        │                                                            └── LWP HTTP to llama-server
        │
        ├──► backend: external ──► models.backend.local.invoke ──► AnyEvent::HTTP
        │                                                    └──► direct to external server
        │                                                        (LM Studio, user-managed, etc.)
        │
        ├──► backend: kimi_web ──► models.backend.kimi_web ──► cube.kimi.ask-reply
        │                                                └──► kimi zenka
        │                                                        └── WebSocket to kimi-web UI
        │
        └──► backend: api [TODO]
```

---

## When to Use Each Backend

### `local` (Default)
**Use when:**
- You want Protocol-7 to manage the llama-server process
- You need automatic GPU/CPU selection based on model size
- You want task queuing and load balancing
- You're using the standard ik_llama.cpp setup

**Example:**
```yaml
# model registry entry
llama-3.1-8b:
  backend: local  # or 'llama' maps to local
  default: true
```

### `external` (New)
**Use when:**
- You have an already-running server (LM Studio, Ollama, etc.)
- You're connecting to an external OpenAI-compatible API
- You want direct control without spawn management

**Example:**
```yaml
# model registry entry
lmstudio-llama3:
  backend: external
  server_url: http://127.0.0.1:1234  # LM Studio default port

# Or set globally
models.external.server_url: http://localhost:8080
```

---

## Clean Integration Checklist

### Phase 1: New Components Only (Current)
- [x] `models.init_code` - AnyEvent::HTTP setup
- [x] `models.backend.local.invoke` - Direct HTTP backend
- [x] `models.handler.llm_response` - Response handler
- [x] `models.callback.send_reply` - Reply helper
- [x] `models.chat.invoke_model` - Routing for 'external' backend

### Phase 2: Testing (Next)
- [ ] Test with LM Studio (external backend)
- [ ] Test with Ollama (external backend)
- [ ] Test error handling (server down, timeouts)
- [ ] Memory profiling (compare to coding backend)

### Phase 3: Stable Integration (Later)
- [ ] Add configuration UI for external server URL
- [ ] Document model registry format for external backends
- [ ] Add health check endpoint for external backend

### Phase 4: Existing System Upgrades (Much Later)
- [ ] Evaluate upgrading coding zenka to AnyEvent::HTTP
- [ ] Benchmark: AnyEvent::HTTP vs LWP in coding context
- [ ] Only upgrade if clear benefit + stability maintained

---

## Key Design Decisions

### 1. Why Two Local Backends?

**Separate concerns:**
- `local` = managed infrastructure (coding zenka's domain)
- `external` = unmanaged/direct access (new capability)

**No overlap:**
- They serve different use cases
- Users choose explicitly via model registry
- No automatic fallback between them

### 2. Why AnyEvent::HTTP for External?

**Requirements for external backend:**
- Must integrate with Event.pm (no polling)
- Must be non-blocking
- No process spawn needed (server already running)

**AnyEvent::HTTP fits perfectly:**
- Native Event.pm integration
- No extra dependencies (already in Debian)
- Simple callback-based API

### 3. Why Keep Coding Zenka on LWP (For Now)?

**Stability priority:**
- Coding zenka works well as-is
- Task queue compensates for blocking HTTP
- Changing it risks regressions

**Upgrade criteria (for future evaluation):**
- AnyEvent::HTTP shows clear performance benefit
- Comprehensive testing possible
- Bandwidth available for regression testing

---

## Configuration

### Model Registry Entry (External Backend)

```yaml
## data/yaml/models/registry/local-external.yaml
models:
  lm-studio-default:
    name: "LM Studio Default"
    backend: external
    server_url: http://127.0.0.1:1234
    model_id: "local-model"  # Model ID to send to server
    system_template: cfg/models/system-messages/coding-assistant.tmpl

  ollama-llama3:
    name: "Ollama Llama 3"
    backend: external
    server_url: http://127.0.0.1:11434/v1
    model_id: "llama3"
```

### Global Configuration

```yaml
## data/yaml/models/config.yaml
models:
  external:
    default_server_url: http://127.0.0.1:8080
    timeout: 300
    max_connections: 4
```

---

## Testing Plan

### LM Studio Test

```bash
## 1. Start LM Studio with server enabled on port 1234

## 2. Configure models zenka
./bin/v7 -c models << 'EOF'
cmd: models.cmd.chat
args: ":. model use lmstudio :."
EOF

## 3. Send test message
./bin/v7 -c models << 'EOF'
cmd: models.cmd.chat
args: "Hello from Protocol-7 external backend"
EOF

## 4. Check logs
## Expected: [local.invoke] request submitted: <id>
## Expected: [handler.llm_response] completed: <id> (XYZms, Ntok, Mchars)
```

### Error Handling Test

```bash
## Test with server down
./bin/v7 -c models << 'EOF'
cmd: models.backend.local.invoke
params:
  model_id: "test"
  messages:
    - role: user
      content: "test"
  llama_server_url: "http://127.0.0.1:19999"  # Wrong port
  reply_id: "test_error_1"
EOF

## Expected: HTTP error logged, graceful failure
```

---

## Files Added/Modified

### New Files
| File | Purpose |
|------|---------|
| `models.init_code` | AnyEvent::HTTP initialization |
| `models.backend.local.invoke` | Direct HTTP backend |
| `models.handler.llm_response` | Response handler |
| `models.callback.send_reply` | YAML reply helper |

### Modified Files
| File | Change |
|------|--------|
| `models.chat.invoke_model` | Added 'external' backend routing |

---

## Dependencies

```yaml
## .deps/profiles.yaml
ai-models:
  apt:
    - libanyevent-http-perl
    - libanyevent-perl
```

**No CPAN dependencies** - pure Debian packages.

---

## Future Possibilities (Not Committed)

1. **coding zenka HTTP upgrade** - Only after extensive testing
2. **vision zenka HTTP** - When ik_llama.cpp adds HTTP vision endpoint
3. **Streaming responses** - For both external and (eventually) local backends
4. **Connection pooling** - Optimize external backend for high throughput

---

#,,.,,..,,...,,,,,,,.,.,,,.,.,.,,,.,,,..,,,,.,.,.,...,...,...,.,,,,.,,...,,.,,
#3RU52QH5NYXSDVQ7VNFRXDH6JLSH42QT42WB6DPTSAOPZN4FIZKFGL4DC4JCG6UKIFMHXKCZL3YUW
#\\\|CNW7FZJZAQE4FJKXOWXV43KNF5HBXB4C5BU5NCHGF5ON57WC6ZW \ / AMOS7 \ YOURUM ::
#\[7]YAHXMQX6EQTOOJGUWRHEUDAZLN774QRWA635TPXJM7OY4GDEKQCQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
