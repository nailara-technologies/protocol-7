# Session Handover — 2026-04-05

## What Just Happened

### Notes Tools Expansion — COMPLETE
Expanded the coding zenka notes system from 7 to 12 tools. All tools tested via MCP.

**New backends** (5): `note.tag`, `note.recent`, `note.filter`, `note.history`, `note.merge`
**New handlers** (5): `coding.tools.handler.note_{tag,recent,filter,history,merge}`
**Tool definitions**: 5 new entries in `coding.tools.definitions`

**Implementation notes:**
- Backends for list-type results use `{ mode => 'size', data => $formatted_string }` NOT arrayref
- `$meta->{'tags'}` needs type guard (`ref eq 'HASH'`), not just `//` — legacy data may not be hashref
- Local model (Qwen 3.5 9B) generated initial backends but consistently produced bugs:
  missing headers, bare `basename()`, hash deref `$info{'key'}` instead of `$info->{'key'}`,
  wrong return formats. All backends were rewritten or heavily fixed by Claude.
- Model also couldn't find whitelist path or write to large files (tool definitions)

**Task file**: `data/md/coding-tasks/notes-tools-expansion.md` — all 7 tools complete

### Async Tool Execution Loop — RESOLVED (Multi-Session Effort)
The async coding zenka tool execution loop is now fully working. Model autonomously
tested 30+ tools over 29 rounds and completed successfully.

**Root cause chain** (6 bugs found over Apr 2-4):
1. Missing assistant message — tool_calls not passed back in transition data
2. Jinja crash — server template iterates arguments as dict but gets string
3. Concatenated JSON — model emits `{...}{...}`, extract first valid object
4. `reasoning_content` not captured — `content=""` is defined, `//` won't fall through
5. **XML tool calls** — model emits `<tool_call><function=name>` in `reasoning_content`
   instead of structured `tool_calls` array (ROOT CAUSE of early completion)
6. No loop detection — model stuck repeating same tool, no break mechanism

**New modules:**
- `coding.parse.xml_tool_calls` — extracts structured tool_calls from XML in content
- `coding.async.compact_context` — graduated context compaction matching blocking version
- `coding.sanitize.jinja_messages` — shared jinja sanitization for both paths

**Key fixes in existing modules:**
- `coding.async.chunk_handler` — reasoning_content length-check fallback, XML parsing
- `coding.async.state_machine` — loop detection, XML markup stripping from output
- `coding.handler.process-queued-task` — same XML + reasoning_content fixes for blocking

**Commits:**
- `fea9e9be5` — loop detection + XML markup stripping
- `a3285f5de` — XML parsing, context compaction, reasoning_content fallback
- `8b0fe7d9c` — jinja-safe tool_calls, retry, shared sanitization
- `54ec6e47b` — tool_calls in assistant messages, jinja sanitization

## What Needs Doing

### 1. Async Stabilization & Edge Cases
**Priority: high** | **Where**: coding zenka async modules

Tool loop works end-to-end. Remaining:
- Test multi-tool calls per round (model calling 2+ tools simultaneously)
- Test rate limiting / pause-resume flow
- Test user_input state (model requesting human input)
- Monitor context compaction behavior over long sessions
- Consider removing blocking mode fallback once stable

### 2. Namespace Tree Intelligence — Layer 2
**Priority: high** | **Where**: context-tree modules

Layer 1 (tree_read/write/list) is complete. Layer 2 = search and intelligence:
- `tree_search` — find nodes matching pattern
- `tree_diff` — compare branches across time
- `tree_prune` — archive old branches
- Persistent storage for %data persistence

See: `data/ai-mem/claude/topic-namespace-tree-intelligence.md`

### 3. Task Zenka State Machine Expansion
**Priority: high** | **Where**: task zenka modules

Current: pending -> claimed -> done/failed
Target: open -> assigned -> in_progress -> blocked -> review -> completed -> archived

Missing:
- `task.next` — autonomous work routing
- `task.handover` — session context packaging
- File watcher for external yaml changes

### 4. Multi-Model Consensus Testing
**Priority: medium** | **Where**: llm.service.consensus_vote.*

Modules extracted but untested. Needs:
- Real model provider wiring
- 5-of-7 algorithm group testing
- Integration with task dispatch

### 5. Self-Improving Loop Closure
**Priority: vision** | **Where**: llm coordination zenka

Current: coding zenka can extract, review, observe, self-fix, stop cleanly
Next steps:
- Token budget awareness
- Session-limit tracking
- Affinity-based routing (kimi=sustained impl, claude=design/review)
- task.next picking work autonomously

## Coding Zenka Task Submission

```bash
## submit a task with template
p7c coding.submit ':template: <name>' ':context: modules/<file>' ':description: <text>' ':priority: 5'

## available templates
ls data/yaml/context-templates/   # 63+ templates

## check task status
p7c coding.queue
p7c coding.show <task-id>
```

## Key Technical Insight: XML Tool Calls

The ik_llama.cpp server with certain models returns tool calls as XML in
`reasoning_content` instead of structured `tool_calls` in the API response:

```json
{
  "finish_reason": "stop",
  "message": {
    "reasoning_content": "...\n<tool_call>\n<function=read_file>\n<parameter=path>README.md</parameter>\n</function>",
    "content": "",
    "tool_calls": []
  }
}
```

Both async and blocking paths now parse this format via `coding.parse.xml_tool_calls`.
The `content=""` (empty but defined) trap requires `length` check, not `//` operator.

## Key Files

### Async Pipeline (now working)
- `modules/coding.async.state_machine` — core state machine with loop detection
- `modules/coding.async.chunk_handler` — XML tool call detection + reasoning_content
- `modules/coding.async.tool_executor` — tool dispatch and result collection
- `modules/coding.async.send_request` — request building with context compaction
- `modules/coding.async.compact_context` — graduated context summarization
- `modules/coding.parse.xml_tool_calls` — XML tool call parser
- `modules/coding.sanitize.jinja_messages` — shared jinja safety

### Documentation
- `CLAUDE.md` — full system reference
- `data/ai-mem/claude/MEMORY.md` — persistent context index
- `data/ai-mem/claude/topic-async-tool-loop-debug.md` — full debug history
- `data/yaml/context-templates/` — all coding zenka templates
