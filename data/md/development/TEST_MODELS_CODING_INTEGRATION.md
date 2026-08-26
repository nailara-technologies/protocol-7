# Testing Models → Coding Integration

## What Was Changed

The chat system now routes inference requests through coding's dependency-based task queue:

```
models.chat → invoke_sync → coding.invoke → coding.ask-reply → jobqueue → llama-server
```

## Prerequisites for Testing

1. Protocol-7 running with coding and models zenka
2. llama-server configured and models discovered
3. Dependencies initialized (memory_system, memory_gpu, model_gpu, server_gpu)

## Test Commands

### 1. Check Dependencies Status
```bash
p7c coding.dependencies
# Should show all dependencies as "satisfied"
```

### 2. Test Basic Chat (should auto-start server if needed)
```bash
p7c models.chat gemma3-glitter-4b "Hello, can you hear me?"
```

Expected flow:
1. If server not running: waits for dependency chain → spawns server → submits task
2. If server running: submits task immediately
3. Response appears after inference completes

### 3. Check Task Queue Status
```bash
p7c coding.status
# Shows queued/running/completed tasks
```

### 4. Check Logs for Integration Flow
```bash
tail -f var/log/coding.log | grep -E "(coding.invoke|coding.reply|invoke_sync)"
```

Expected log messages:
- `[coding.invoke] inference queued: id=...`
- `[invoke_sync] completed: id=... result_len=...`
- `[coding.reply] received result: id=...`

## Troubleshooting

### If "coding.ask-reply command not found"
The coding zenka might not be fully initialized. Check:
```bash
p7c coding.status
```

### If "llama-server not available"
The dependency chain might not have triggered. Check:
```bash
p7c coding.dependencies
# Should show server_gpu dependency status
```

### If timeout waiting for result
The server might be starting up (first time takes ~10-30s). Check logs:
```bash
tail -f var/log/coding.log | grep spawn
```

## Key Differences from Old System

| Aspect | Old | New |
|--------|-----|-----|
| Server startup | Direct spawn (racy) | Dependency-based with memory checks |
| Inference call | Direct HTTP curl | Queued via jobqueue |
| Error handling | Immediate failure | Retries with dependency waits |
| Memory safety | None | 4GB RAM + 3GB VRAM minimum |

## Rollback (if needed)

To revert to old direct-HTTP system:
1. Edit `models/chat.invoke_model` line 55
2. Change `models.backend.local.invoke_sync` back to `models.backend.local.invoke`
3. Remove `invoke_sync` wrapper

## Files Modified/Created

- `src/models.backend.coding.invoke` (NEW)
- `src/models.handler.coding_inference_reply` (NEW)
- `src/models.backend.local.invoke_sync` (REFACTORED)
- `src/models.chat.messages_to_prompt` (NEW)

#,,,,,..,,..,,,.,,...,,.,,,..,..,,...,,..,,.,,..,,...,...,...,,,,,...,...,..,,
#UBZ76DVLXGSXEJI2NLVMD4LBH7M4BS2D6GDCIUUPXDKDR2KICKYMATUWTDU4EAZUEDUO7HW4OWPCW
#\\\|TADTJVM4NRKIQTR3XTLMTQ6BLX3TTHTH7QG3WB5K7NYMC5WIIM2 \ / AMOS7 \ YOURUM ::
#\[7]V23JQ7IWJUDSDV6CSQPAVH2MEFURWMVKPZ4ESDWF22IDTHSP4KDA 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
