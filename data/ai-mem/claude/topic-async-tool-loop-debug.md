---
name: Async Tool Loop — Resolved
description: async tool execution loop debugging history and final fixes — XML tool calls, reasoning_content, loop detection
type: project
---

## status: RESOLVED (2026-04-04)

### what works now
- async HTTP non-blocking I/O with full tool execution loop (verified 29+ rounds)
- XML tool call parsing from reasoning_content (root cause of early completion)
- context compaction matching blocking version (graduated summarization)
- loop detection with assertion prompts and force-stop after 3 warnings
- jinja-safe argument re-encoding (clean JSON strings for server template)
- shared jinja sanitization module (coding.sanitize.jinja_messages)
- retry on 500/timeout with tool_calls stripping
- 30+ tools verified working by model autonomously

### root cause chain (discovered over multiple sessions)
1. **missing assistant message** — tool_calls not passed back in transition data → fixed
2. **jinja crash on arguments** — server template iterates arguments as dict but gets string → re-encode as clean JSON
3. **concatenated JSON from model** — extract first valid object, fallback to '{}'
4. **reasoning_content not captured** — `content=""` is defined, `//` won't fall through → use length check
5. **XML tool calls in reasoning_content** — model emits `<tool_call><function=name>` instead of structured tool_calls → new parser module
6. **no loop detection** — model stuck repeating same tool call → ported from blocking version

### key modules (final state)
- `coding.parse.xml_tool_calls` — NEW: extracts structured tool_calls from XML in content
- `coding.async.chunk_handler` — reasoning_content length-check fallback, XML parsing on stop
- `coding.async.state_machine` — loop detection, XML markup stripping from output buffer
- `coding.async.compact_context` — NEW: graduated context compaction
- `coding.sanitize.jinja_messages` — NEW: shared jinja sanitization
- `coding.async.send_request` — calls compact_context, uses shared sanitizer
- `coding.async.tool_executor` — passes tool_calls back in transition data
- `coding.callback.http_error` — strips tool_calls on 500, retry support

### commits
- `a3285f5de` — XML tool call parsing, context compaction, reasoning_content fallback
- `fea9e9be5` — async loop detection + strip XML markup from output buffer
- `8b0fe7d9c` — jinja-safe tool_calls, retry, shared sanitization
- `54ec6e47b` — include tool_calls in assistant messages, add jinja sanitization

#,,,,,.,,,,,.,..,,...,,..,.,.,,..,...,...,,,.,..,,...,..,,...,...,,..,,,,,..,,
#LSKJQ23WMJHX5NFAUQEH55TCCPQKEFLIPIQW3LJ45GQVXVUPGRSWJOFZZEX2H7ICL3WPVQH3OUELO
#\\\|NFT4XU25DKCYYHX36PIB4EGLKIFOWUUZ6MRV3PB2HB4N3DZWZW2 \ / AMOS7 \ YOURUM ::
#\[7]JRSW4CUWJAWPQT2KV4P7VUG5Z4ILR2G3YPDJQIOJKKWUQ3WU3UCY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
