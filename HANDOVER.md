# Session Handover — 2026-04-18

> **Previous session**: 2026-04-05 — see bottom of file for archived notes.

## What Just Happened

### Searchable Index Build Pipeline — IMPLEMENTED, BLOCKED ON ASYNC
Implementation of section 5.2 of `SEARCHABLE-INDEX-SESSION-STATE.md` — persistent, checksummed, on-demand code repository indexing for `space.v7.ax`.

**New modules** (6):
- `plugin.web.space.index.init_code` — cache init, cfg defaults, restore from disk
- `plugin.web.space.index.scan` — manual dir walk, BMW 512-bit checksum, gen_path, stats
- `plugin.web.space.index.persist` — atomic JSON+YAML write via `file.zenka_dir.write`
- `plugin.web.space.index.load` — restore cache from persisted JSON on startup
- `plugin.web.space.index.cmd.rebuild` — on-demand `web.index-rebuild` trigger
- `plugin.web.space.index` — template command with `summary`, `json`, `json-raw`, `yaml-raw` sections

**Templates**:
- `/var/httpd/space.v7.ax/index.json.tmpl` — JSON API endpoint
- `/var/httpd/space.v7.ax/index.yaml.tmpl` — YAML API endpoint
- `/var/httpd/space.v7.ax/index.tmpl` — updated with `plugin.web.space.index:summary` block

**Runtime verified**:
- `web.index-rebuild` completes in ~5.5s, indexes 3548 files
- Persists to `/var/protocol-7/web/space-index/modules.json` (~1MB)
- Idempotent: two consecutive rebuilds with no file changes produce identical output

**Bug fix applied** — `index.gen_path` list context leak:
- Root cause: `map { <[chk-sum.amos]>->(...) }` evaluates in list context, so `amos_chksum` returned `($encoded, $numerical)` — the numerical value (e.g. `559104`, `57601`) is shorter than 7 chars, causing `substr outside of string` warnings
- Fix: `map { scalar <[chk-sum.amos]>->(...) }` — forces scalar context, only base32 encoded string returned
- Affects 2 files out of 3548 when seeded with BMW checksums (rare but consistent)

---

## What Is Blocking Us

### HTTP Endpoint Timeouts — CRITICAL
**Symptom**: Requesting `http://space.v7.ax/index.json` causes httpd zenka to hang for 23s, then get SIGTERM'd by cube timeout watchdog and restarted.

**Log chain**:
```
httpd : [NNNN] static file route [default]
httpd : [NNNN] serve_static : request : '/index.json'
httpd : [space.v7.ax/index.json.tmpl] <-- < web zenka >
: instance X [ httpd ] response timeout , retrying ,
: instance X [ httpd ] response timeout `:|
: instance X ['httpd']   online --> error
: : <TERM> instance PID NNNN
```

**Root cause**: `httpd.process_template` dispatches to the **web zenka** for template rendering. The web zenka processes `<[plugin.web.space.index:json-raw]>` synchronously. Inside that template command, the current on-disk code does:
```perl
<web.space.index.json_cached>
    = eval { JSON::XS::encode_json($payload) } // '{}';
require YAML::XS;
<web.space.index.yaml_cached>
    = eval { YAML::XS::Dump($payload) } // "--- {}\n";
```

Both `JSON::XS::encode_json` and `YAML::XS::Dump` of 3548-cell payload are **blocking CPU-intensive operations** that stall the web zenka's single event loop. The httpd zenka is waiting for a reply from web zenka via IPC. Web zenka never replies in time → httpd timeout → SIGTERM → restart.

**Why pre-encoding during scan doesn't help** (currently):
The pre-encoded values are stored in `<web.space.index.json_cached>` and `<web.space.index.yaml_cached>`, but `JSON::XS::encode_json` in `scan` and `load` is STILL blocking on 3548 cells during rebuild/load. The HTTP request then asks for `json-raw` which returns the cached string instantly — but if a rebuild is running concurrently, or if the web zenka is busy with the blocking encode, the httpd request starves.

**The real fix needed**: Make the scan/load/rebuild chain **non-blocking** or move the heavy serialization off the web zenka's event loop.

---

## What Needs Doing

### 1. Non-Blocking Serialization for Index Pipeline
**Priority: critical** | **Where**: `plugin.web.space.index.scan`, `plugin.web.space.index.load`, `plugin.web.space.index.persist`

Options to explore:
- **Async file I/O**: Replace `chk-sum.bmw.filesum` (blocking `addfile` on 3548 files) with event-based chunked reads. `base.chk-sum.bmw.filesum` itself has a note: `this will block on large files --> event based async. method ..,`
- **Offload to worker/callback**: Use `base.callback` or `base.timer` to run scan in background, store result when done. HTTP endpoints serve stale cache during rebuild.
- **Incremental/ streaming JSON**: Build JSON string incrementally per cell instead of `encode_json($payload)` on giant hashref.
- **YAML fallback without YAML::XS**: `YAML::XS::Dump` is unreliable at runtime (sometimes undefined despite `require YAML::XS`). Manual YAML string construction works but is fragile. Consider skipping YAML entirely or using a lightweight serializer.

**Important constraints**:
- `bin/Protocol-7` does `use File::stat` globally — must use `File::stat::stat($path)->size/->mtime` OO form
- `JSON::XS` is available via `web.init_code` autoload
- `YAML::XS::Dump` is NOT reliably available at runtime — persist/load must handle failure gracefully
- `file.zenka_dir.write` / `file.zenka_dir.load` are the correct persistence paths (web zenka runs as `protocol-7` user, cannot write arbitrary project paths)

### 2. HTTP Endpoint Verification
**Priority: high** | **Where**: `/var/httpd/space.v7.ax/index.{json,yaml}.tmpl`

Once non-blocking, verify:
- `NO_PROXY=space.v7.ax curl http://space.v7.ax/index.json` returns valid JSON instantly
- `NO_PROXY=space.v7.ax curl http://space.v7.ax/index.yaml` returns valid YAML instantly
- `http://space.v7.ax/` renders summary block without delay
- Concurrent rebuild + HTTP request does not crash httpd zenka

### 3. `index.gen_path` Hardening
**Priority: medium** | **Where**: `modules/index.gen_path`

The `scalar` fix is applied but the module still has a pre-existing validation gap:
- It assumes 7-char AMOS checksum output without validating
- Could be made more robust by checking `length($checksum) >= 7` before `substr` loops
- Reseed loop `while (!@path_structure)` could theoretically infinite-loop on pathological input

### 4. Grid + Index Coordination
**Priority: medium** | **Where**: `plugin.web.space.grid.scan`, `plugin.web.space.index.scan`

Both scan modules exist but are independent:
- Grid scans `data/md/design` for content-addressed paths (seeded by file path)
- Index scans `modules` for BMW checksums + gen_path (seeded by checksum)
- Consider unified scan scheduler to avoid duplicate directory walks
- Grid scan also calls `index.gen_path` — verify it doesn't trigger the same list-context bug (it passes plain strings, not checksums, so numerical return values weren't an issue there)

---

## Key Files

### Index Pipeline
- `modules/plugin.web.space.index.init_code`
- `modules/plugin.web.space.index.scan`
- `modules/plugin.web.space.index.persist`
- `modules/plugin.web.space.index.load`
- `modules/plugin.web.space.index.cmd.rebuild`
- `modules/plugin.web.space.index`
- `modules/index.gen_path` (fixed list-context bug)

### Templates
- `/var/httpd/space.v7.ax/index.tmpl`
- `/var/httpd/space.v7.ax/index.json.tmpl`
- `/var/httpd/space.v7.ax/index.yaml.tmpl`

### Documentation
- `data/md/design/SEARCHABLE-INDEX-SESSION-STATE.md` — section 5.2
- `data/md/coding-tasks/space-index-build-pipeline.md`
- `data/md/coding-tasks/space-index-grid-endpoint.md`

---

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
