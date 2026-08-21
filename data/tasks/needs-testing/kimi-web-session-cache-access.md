## [:< ##

# name  = task: kimi-web session cache access commands
# descr = expose kimi-cli session cache files via kimi-web zenka commands

## kimi memory

if in doubt about P7 patterns, coding style, or project context — read first:
```bash
cat data/ai-mem/kimi/MEMORY.md
cat data/ai-mem/kimi/coding-style.md
```

## context

kimi-cli sessions store accumulated reasoning in `~/.kimi/sessions/<uuid>/`:
- `context.jsonl` — compressed reasoning context (hundreds of MB for deep tasks)
- `state.json`   — session metadata (model, timestamps, status)
- `wire.jsonl`   — raw protocol messages

when a kimi session hits the context limit and compacts, or when a local
model needs to continue a kimi analysis, the context.jsonl provides the
full accumulated understanding without re-reading source files.

the kimi-web zenka already manages kimi-cli agents and their lifecycle —
reading the session cache files is a natural extension of that ownership.
direct file access, no httpd transport needed.

## use cases

1. **resume interrupted session** — kimi hit 100-round limit or compacted;
   read context.jsonl, inject into new agent to continue

2. **local model handoff** — kimi analysis too large; feed context.jsonl
   to coding zenka (local model) for continuation with rolling window

3. **session inspection** — find which session contains analysis of a
   specific topic (grep context.jsonl content)

4. **cross-session context** — inject reasoning from session A into agent B

## what to read first

```bash
cat src/kimi-web.init_code
cat src/kimi-web.bridge.ensure_local_agent
cat src/kimi-web.cmd.list_agents
cat src/kimi-web.cmd.spawn_agent
cfg/zenki/kimi-web/start.cfg
## session directory structure:
ls -la ~/.kimi/sessions/ | head -10
cat ~/.kimi/sessions/<any-uuid>/state.json
```

---

## modules to implement

### kimi-web.cmd.list-sessions

lists available kimi-cli session caches with metadata from state.json:

```
p7c kimi-web.cmd.list-sessions
p7c kimi-web.cmd.list-sessions 'recent:10'   ## last 10 by mtime
p7c kimi-web.cmd.list-sessions 'search:letsencr'  ## by content hint
```

output format (base.sort order — most recent last):
```
<session-id>  <timestamp>  <size-mb>  <model>  <message-count>
```

### kimi-web.cmd.get-session-state

reads state.json for a session:

```
p7c kimi-web.cmd.get-session-state '<session-uuid>'
```

### kimi-web.cmd.read-session-context

reads context.jsonl — returns as STRM for large files:

```
p7c kimi-web.cmd.read-session-context '<session-uuid>'
p7c kimi-web.cmd.read-session-context '<session-uuid>' 'tail:1000'  ## last N lines
```

use STRM (unbounded) since context.jsonl can be hundreds of MB.

### kimi-web.cmd.find-session

searches context.jsonl content across sessions:

```
p7c kimi-web.cmd.find-session 'handler_renewal_reply'
## returns: list of session UUIDs where that string appears
```

### kimi-web.cmd.resume-session

spawns a new agent with a previous session's context pre-loaded.
reads context.jsonl, constructs a resume prompt, dispatches to new agent:

```
p7c kimi-web.cmd.resume-session '<session-uuid>'
p7c kimi-web.cmd.resume-session '<session-uuid>' 'continue the letsencr analysis'
```

### kimi-web.cmd.distill-session

feeds context.jsonl to local model to produce a condensed summary —
strips redundant reasoning loops, dead ends, superseded hypotheses.
output is a compact "essential understanding" document (~10KB vs hundreds of MB)
that can be used as the starting point for a resumed session:

```
p7c kimi-web.cmd.distill-session '<session-uuid>'
## returns: condensed session summary saved to kimi-web.cfg.sessions_dir/<uuid>/distilled.md
```

the distilled.md becomes the context for resume-session instead of full context.jsonl.

### kimi-web.cmd.inject-context-to-coding

feeds context.jsonl to the coding zenka (local model) for continuation.
uses coding.submit with the context as system prompt:

```
p7c kimi-web.cmd.inject-context-to-coding '<session-uuid>' 'what is different between enrollment and renewal reply routing?'
```

---

## configuration

```
## cfg/zenki/kimi-web/start.cfg (additions)
kimi-web.cfg.sessions_dir  = ~/.kimi/sessions
kimi-web.cfg.context_file  = context.jsonl
kimi-web.cfg.state_file    = state.json
kimi-web.cfg.wire_file     = wire.jsonl
```

---

## access control

add new commands to kimi-web start access list:
```
access.cmd.usr.cube = ... list-sessions get-session-state read-session-context \
                          find-session resume-session inject-context-to-coding
```

---

## test sequence

```bash
## list available sessions
p7c kimi-web.cmd.list-sessions 'recent:5'

## inspect the letsencr debug session state
p7c kimi-web.cmd.get-session-state '<uuid-of-letsencr-session>'

## search for relevant sessions
p7c kimi-web.cmd.find-session 'handler_renewal_reply'

## read tail of context for quick summary
p7c kimi-web.cmd.read-session-context '<uuid>' 'tail:500'

## resume with local model
p7c kimi-web.cmd.inject-context-to-coding '<uuid>' \
  'what is the root cause of the not-defined reply handler error?'
```

## success criteria

- [ ] `list-sessions` returns sessions sorted with metadata
- [ ] `get-session-state` returns parsed state.json
- [ ] `read-session-context` streams context.jsonl via STRM
- [ ] `find-session` searches across all sessions
- [ ] `resume-session` spawns agent with previous context
- [ ] `inject-context-to-coding` feeds context to local model
- [ ] no signature stubs, no whitelist changes made

#,,..,...,.,.,...,,,.,...,,,.,,,,,...,,.,,.,.,..,,...,.,.,..,,,,.,,,.,..,,.,.,
#Y6XMRC7AAZ7ZZPOKQZL5P62L62NFN6KVPJGQJUQ27TTIAPYF6GJAC7PM2OG5UMQ3POWPP6TH3ZPYQ
#\\\|P2GZDXA3B6S6MGS6Q6PCYMRW4UQB2VSWWMR6ITPBSMTHOH7SVVT \ / AMOS7 \ YOURUM ::
#\[7]IVFMBYVK2SKZZEHCR5EHVC6P26R22SWLXQX47BUYC3QZK5EALOAI 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
