# Architecture: Chat-Coding Integration

## Overview

The models zenka chat system now uses coding zenka's dependency-based inference pipeline. This provides memory-safe, queued inference with automatic server lifecycle management.

## Architecture Diagram

```
User Request
    |
    v
models.cmd.chat [deferred reply]
    |
    +-- stores user message in buffer
    |
    v
models.chat.invoke_model
    |
    +-- builds conversation context (last 20 messages)
    +-- converts to messages array
    |
    v
models.backend.coding.invoke
    |
    +-- base32r encodes prompt (for multiline support)
    +-- sends to cube.coding.ask-reply
    +-- specifies reply handler: models.handler.coding_result_forward
    |
    v
[coding zenka processes via dependency chain]
    |
    +-- memory_system check (4GB RAM)
    +-- memory_gpu check (3GB VRAM)
    +-- model_gpu check (model available)
    +-- server_gpu check (llama-server ready)
    |
    v
llama-server inference
    |
    v
models.handler.coding_result_forward [route reply]
    |
    +-- receives coding result (TRUE/SIZE/FALSE)
    +-- stores model response in chat buffer
    +-- formats chat buffer (last 3 entries)
    +-- base.callback.cmd_reply -> User
```

## Key Components

### 1. models.cmd.chat
**Purpose**: Command entry point for chat interface
**Pattern**: Deferred reply - returns immediately, response comes async
**Key behaviors**:
- Stores user message before sending to model
- Returns `{mode => 'deferred'}` to release client
- Response delivered via callback when ready

### 2. models.chat.invoke_model
**Purpose**: Prepares conversation context and routes to backend
**Context building**:
- Retrieves last 20 messages from chat buffer
- Maps senders to roles (user/assistant)
- Builds messages array for model
**Backend routing**:
- `local` -> coding.invoke (with memory safety)
- `api` -> Not yet async (returns error)
- `test` -> Local echo response

### 3. models.backend.coding.invoke
**Purpose**: Submits inference job to coding's task queue
**Encoding**: Uses Crypt::Misc::encode_b32r for multiline prompts
**Parameters passed**:
- `participant_id`: Model name
- `messages`: Array of {role, content}
- `reply_id`: Original caller's reply ID
- `sender`, `model`: For response handling

### 4. models.handler.coding_result_forward
**Purpose**: Receives coding result and completes chat flow
**Inputs**:
- `cmd`: TRUE/SIZE/FALSE (reply type)
- `call_args`/`data`: Response content
- `params`: {original_reply_id, sender, model}
**Actions**:
1. Extracts response text
2. Stores in chat buffer (via models.chat.append)
3. Formats buffer for display
4. Sends reply to original caller

## Data Flow: Conversation Context

```
Chat buffer (models.chat.messages):
[
  {time: 123, sender: 'unix-taeki', message: 'Hello'},
  {time: 124, sender: 'gemma3-glitter-4b', message: 'Hi there'},
  {time: 125, sender: 'unix-taeki', message: 'How are you?'},
]

Converted to messages array:
[
  {role: 'user', content: 'Hello'},
  {role: 'assistant', content: 'Hi there'},
  {role: 'user', content: 'How are you?'},
]
```

**Role mapping**:
- `unix-*` or `cube.models` -> `user`
- Model name (e.g., `gemma3-glitter-4b`) -> `assistant`

## Memory Safety

The integration leverages coding's dependency system:

| Dependency | Check | Minimum |
|------------|-------|---------|
| memory_system | /proc/meminfo MemAvailable | 4 GB |
| memory_gpu | nvidia-smi memory.free | 3 GB |
| model_gpu | Model exists in registry | - |
| server_gpu | HTTP health check on port 8000 | - |

If any check fails, the job remains in 'depending' state until resolved.

## Base32r Encoding

Multiline conversation history requires encoding for single-line command transmission:

```perl
# Before encoding:
$prompt = "user: Hello\nassistant: Hi\nuser: How are you?"

# After encode_b32r:
$encoded = "KRCFGUSJOJSSAU2BLFYXC4TBKVCE6RCCFQRHG5DJN5X..."

# Decoded by coding.cmd.ask-reply automatically
```

## Error Handling

| Scenario | Behavior |
|----------|----------|
| Coding not ready | Error stored in buffer, returned to user |
| Server spawn fails | Dependency chain retries automatically |
| Timeout (>120s) | Error message with elapsed time |
| Model not found | Error from coding routing |

## Files and Modules

| File | Purpose |
|------|---------|
| `models.cmd.chat` | Command entry, deferred reply handling |
| `models.chat.invoke_model` | Context building, backend routing |
| `models.backend.coding.invoke` | Coding submission, base32r encoding |
| `models.handler.coding_result_forward` | Result processing, buffer update |
| `models.chat.messages_to_prompt` | Message array to prompt string |
| `models.chat.get_recent` | Retrieves conversation history |

## Related Documentation

- `TEST_MODELS_CODING_INTEGRATION.md` - Testing procedures
- `ARCHITECTURE-dependency-system.md` - Dependency chain details
- `coding.handler.deferred_reply` - How deferred replies work

#,,,,,,.,,,,,,,..,,..,,..,...,.,,,,..,,,.,,,.,.,.,...,..,,,..,,.,,..,,...,,,,,
#UVY2GJTSMWSPJQ5Q742EO4ZNWLUHQE35QCU7SGE66UYY2WEYY2TXZ4MTGNGCCJBVNSICT6UPQDIMA
#\\\|NSPNROJKJ7SMVVK2ADLXK2BDHQ45VN7SRUJMJAL5JZKNSPZ3QNJ \ / AMOS7 \ YOURUM ::
#\[7]TEGMY33CPPLDYY5BPIDBJ4NPBPAIKOYJYA63YMGVZ6VQP2PFTGBY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
