# Multi-Model Chat System

**Status:** ✅ Operational (2025-02-20)

Natural language communication infrastructure for collaboration between multiple model instances (Claude, kimi-code, local models).

## Quick Start

```bash
## send message to model
p7c models.chat test-model "Hello! Testing multi-model communication."

## view recent chat buffer (last 20 messages)
p7c models.chat

## view full buffer with escape sequences
p7c models.show-buffer models-chat
```

## Features

### Automatic Source Tracking
Messages automatically tagged with sending zenka name via cube `source_zenka` alias:
```
[04:28:29] [unix-taeki]: Hello from Claude!
[04:28:29] [test-model]: :note: received from Claude
```

### Escape Sequences
Protocol-7 style formatting preserved in storage and interpreted for display:
- `:n:` - Newline
- `:t:` - Tab (default width: 10 spaces)
- `:t4:` `:t8:` - Tab with specific width

### Keywords
Embedded keywords for task coordination:
- `:note:` - General annotations
- `:task:` - Task assignments
- `:output:` - Command output markers (future)
- `:done:` - Completion signals (future)

### Content-Addressed Announcements
Large messages (>5 lines) auto-announced with AMOS checksums:
```
[:content:ABC123XYZ:15:342] Code snippet for async handler
```

Retrieve full content:
```bash
p7c models.request ABC123XYZ
```

## Architecture

### Dual Storage
Messages stored in two formats:
1. **Structured:** `<models.chat.messages>` array (max 500 messages)
2. **Buffer:** Protocol-7 buffer `models-chat` (max 128 KB)

### Command Flow
```
User → p7c models.chat test-model "Hello!"
     ↓
Cube adds source → "unix-taeki test-model Hello!"
     ↓
models.cmd.chat → Parse args, extract sender
     ↓
models.chat.append → Store with timestamp
     ↓
models.chat.process_keywords → Extract keywords
     ↓
Generate response (placeholder)
     ↓
models.chat.format_buffer → Format last 3 messages
     ↓
Return via SIZE protocol
```

### Key Modules
- `models.cmd.chat` - Command entry point
- `models.chat.append` - Store messages
- `models.chat.get_recent` - Retrieve messages
- `models.chat.format_buffer` - Format for display
- `models.chat.auto_announce` - Large message handling
- `models.escape.encode/interpret` - Escape sequence handling
- `models.cmd.request` - Retrieve announced content

## Configuration

### Chat Buffer Size
Default: 500 messages (configurable via `<models.cfg.chat_buffer_size>`)

### Auto-Announce Threshold
Default: 5 lines (configurable via `<models.cfg.auto_announce_threshold>`)

### Tab Width
Default: 10 spaces (configurable via `<models.cfg.tab_width>`)

## Integration Points

### Cube Alias
`cfg/zenki/cube/command_aliases`:
```
setup.aliases.source_zenka = ... models.chat
```

### Access Permissions
`cfg/zenki/models/zenka.v7`:
```
access.cmd.usr.cube = ... chat request ...
```

## Next Steps

### High Priority
1. **Real Model Integration** - Replace placeholder with actual API calls
   - kimi-code API
   - Local llama-server
   - Claude API for multi-instance coordination

2. **models.memory** - Conversation memory storage/retrieval
   - Store important context across sessions
   - Retrieve by topic/checksum
   - Integrate with chat system

### Medium Priority
1. **Keyword Actions** - Implement `:output:` and `:done:` handling
2. **Multi-Instance Sync** - Synchronize chat across Claude/kimi instances

## Examples

### Basic Chat
```bash
p7c models.chat coding-assistant "Can you review this function?"
```

### Multi-Line Message
```bash
p7c models.chat kimi-code "Here's the code::n::n:def process()::n::t:return True"
```

### View Conversation
```bash
p7c models.chat  # Shows last 20 exchanges
```

## See Also
- `data/yaml/project-context/session-2025-02-20-multi-model-chat.yaml` - Full implementation details
- `SIZE_PROTOCOL_MODES.md` - SIZE response format specification
- `src/models.chat.*` - Chat system modules
- `src/models.escape.*` - Escape sequence handling

## Commits
- `7fe6c1493` - Implement multi-model chat system with source zenka tracking
- `e00193a32` - Fix chat buffer integration and logging bug
- `9a1d9ccdc` - Add chat/request commands to permissions
- `310ea2236` - Use bracket notation for content markers
- `6b1382aa4` - Add content-addressed announcement system

#,,,,,,,,,,.,,..,,,,.,.,.,.,,,...,.,,,.,,,.,.,..,,...,...,,..,,..,,,,,,,,,.,.,
#KDEZ3T6CCHVPMVI4XLBHMPWNKVRY7E5OF6UN7ID24QZUAJFHTQC6WGRV4S2WBVS422YKIM3VQJ3ZC
#\\\|HKJIJIZP6DMHZNSIS5JI7ND6PLRMPUJS7V6C24SCIGDTHCL5LNO \ / AMOS7 \ YOURUM ::
#\[7]PMZUX2NRA5ITOWS62MT57J73QNHYKGRKVWBIQDU6PILXJQ3BU4AY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
