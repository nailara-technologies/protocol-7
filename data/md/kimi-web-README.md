# Kimi-Web Zenka

Sub-agent spawner for local kimi-cli web processes. Enables parallel LLM inference with P7 context template integration.

## Architecture

```
Parent kimi (MCP) → P7 cube → kimi-web zenka → spawns kimi-cli web
                                            ↓
                                     HTTP API (port 16000+)
                                            ↓
                                     Local inference
```

## Commands

### Agent Lifecycle

| Command | Description | Parameters |
|---------|-------------|------------|
| `kimi-web.spawn_agent` | Spawn new sub-agent | `context_slice`, `model_config`, `priority`, `template` |
| `kimi-web.list_agents` | List active agents | `status` (optional filter) |
| `kimi-web.terminate_agent` | Kill agent gracefully | `agent_id`, `preserve_context`, `force` |

### Work Dispatch

| Command | Description | Parameters |
|---------|-------------|------------|
| `kimi-web.dispatch` | Send work to one agent | `agent_id`, `prompt`, `timeout`, `stream` |
| `kimi-web.dispatch_parallel` | Map-reduce across agents | `agent_ids[]`, `prompt`, `aggregation`, `timeout` |

### Context Templates

| Command | Description | Parameters |
|---------|-------------|------------|
| `kimi-web.resolve_template` | Render P7 context template | `template`, `vars`, `budget` |

## Usage Examples

### Spawn Single Agent

```bash
p7c kimi-web.spawn_agent \
    template=integrate-recent \
    priority=3
# Returns: kw-0001
```

### Spawn with Context

```bash
p7c kimi-web.spawn_agent \
    context_slice=/data/ai-mem/kimi/MEMORY.md \
    model_config='{ "temperature": 0.7 }'
```

### Parallel Map-Reduce

```bash
# Spawn 3 agents
for i in 1 2 3; do
    p7c kimi-web.spawn_agent template=code-review &
done

# Wait for ready
sleep 10

# Parallel dispatch
p7c kimi-web.dispatch_parallel \
    agent_ids='["kw-0001","kw-0002","kw-0003"]' \
    prompt="Review src/coding.cmd.inference-status" \
    aggregation=merge \
    timeout=300
```

### With Context Template

```bash
# Resolve template first
CONTEXT=$(p7c kimi-web.resolve_template \
    template=review-deep \
    vars='{"target_module":"coding.handler.spawn"}' \
    budget=5000)

# Spawn agent with resolved context
p7c kimi-web.spawn_agent \
    context_slice="$CONTEXT" \
    priority=5
```

## Aggregation Strategies

- `concat`: Join all outputs with headers
- `vote`: Select most common response
- `merge`: Combine unique insights
- `best`: Select based on completeness heuristics

## Port Allocation

- Base port: 16000
- Max agents: 8 (ports 16000-16007)
- Dynamic allocation on spawn

## Context Preservation

Agents can preserve context on termination:

```bash
p7c kimi-web.terminate_agent \
    agent_id=kw-0001 \
    preserve_context=true
```

Context saved to `zenka_dir/contexts/` with P7REF checksum.

## Integration with MCP

The `mcp-server-p7` exposes these as tools:

```perl
p7_agent_spawn   -> kimi-web.spawn_agent
p7_agent_list    -> kimi-web.list_agents  
p7_agent_dispatch -> kimi-web.dispatch
p7_agent_dispatch_parallel -> kimi-web.dispatch_parallel
p7_agent_terminate -> kimi-web.terminate_agent
p7_template_resolve -> kimi-web.resolve_template
```

## Files

- `kimi-web.init_code` - Zenka initialization
- `kimi-web.cmd.spawn_agent` - Agent spawning
- `kimi-web.cmd.list_agents` - Agent listing
- `kimi-web.cmd.dispatch` - Single dispatch
- `kimi-web.cmd.dispatch_parallel` - Parallel dispatch
- `kimi-web.cmd.terminate_agent` - Agent cleanup
- `kimi-web.cmd.resolve_template` - Template resolution
- `kimi-web.handler.agent_health_check` - Health monitoring
- `kimi-web.handler.batch_result` - Result collection
- `kimi-web.handler.batch_timeout_check` - Timeout handling
- `kimi-web.internal.*` - HTTP helpers and aggregation

#,,,.,,,,,..,,...,.,.,.,.,,,.,..,,...,,,.,,..,..,,...,...,.,,,.,.,...,,.,,...,
#EQGKZY672UMZUXAJI7YDAJ5JGEYY37IOBJXJJ52TNY74J6T24NDKY6OMZPCSVHU2RNQSRC5INJ42M
#\\\|X7GWHARPIKR6QKAFIVJGTKHIO2WVDRXUTT7ZKMIKP6GGPOXDWBH \ / AMOS7 \ YOURUM ::
#\[7]EO7WJJCTDDMDL5HYEBAI3ZSG35WC6LO4UEBPMISW5NOBI6VLHQAQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
