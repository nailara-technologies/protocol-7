# MCP Server P7 - Expansion Roadmap

## Phase 1: Sub-Agent Management Tools

### p7_agent_spawn
```perl
{
    'name' => 'p7_agent_spawn',
    'description' => 'Spawn a new sub-agent process (kimi-web, claude-web, etc.) '
        . 'with isolated context. Returns agent_id for subsequent calls.',
    'inputSchema' => {
        'type' => 'object',
        'properties' => {
            'agent_type' => {
                'type' => 'string',
                'enum' => ['kimi-web', 'claude-web', 'local-llm'],
                'description' => 'Type of agent to spawn'
            },
            'context_slice' => {
                'type' => 'string',
                'description' => 'Context identifier or file path to preload'
            },
            'model_config' => {
                'type' => 'object',
                'description' => 'Model parameters (temp, max_tokens, etc.)'
            },
            'priority' => {
                'type' => 'integer',
                'default' => 5,
                'description' => 'Scheduling priority (1-10, lower = higher priority)'
            }
        },
        'required' => ['agent_type']
    }
}
```

### p7_agent_list
```perl
{
    'name' => 'p7_agent_list',
    'description' => 'List active sub-agents with status, token usage, and context size',
    'inputSchema' => {
        'type' => 'object',
        'properties' => {
            'agent_type' => {
                'type' => 'string',
                'description' => 'Filter by agent type (optional)'
            },
            'status' => {
                'type' => 'string',
                'enum' => ['idle', 'busy', 'paused', 'error'],
                'description' => 'Filter by status (optional)'
            }
        }
    }
}
```

### p7_agent_dispatch
```perl
{
    'name' => 'p7_agent_dispatch',
    'description' => 'Send work to a specific sub-agent. '
        . 'Blocks until complete or timeout.',
    'inputSchema' => {
        'type' => 'object',
        'properties' => {
            'agent_id' => {
                'type' => 'string',
                'description' => 'Target agent identifier'
            },
            'prompt' => {
                'type' => 'string',
                'description' => 'Work to dispatch'
            },
            'timeout' => {
                'type' => 'integer',
                'default' => 300,
                'description' => 'Timeout in seconds'
            },
            'stream' => {
                'type' => 'boolean',
                'default' => 0,
                'description' => 'Stream partial results as notifications'
            }
        },
        'required' => ['agent_id', 'prompt']
    }
}
```

### p7_agent_dispatch_parallel
```perl
{
    'name' => 'p7_agent_dispatch_parallel',
    'description' => 'Dispatch same prompt to multiple agents, '
        . 'return aggregated results (map-reduce pattern)',
    'inputSchema' => {
        'type' => 'object',
        'properties' => {
            'agent_ids' => {
                'type' => 'array',
                'items' => { 'type' => 'string' },
                'description' => 'Agents to dispatch to'
            },
            'prompt' => {
                'type' => 'string',
                'description' => 'Work to dispatch to all agents'
            },
            'aggregation' => {
                'type' => 'string',
                'enum' => ['concat', 'vote', 'best', 'merge'],
                'default' => 'concat',
                'description' => 'How to combine results'
            },
            'timeout' => {
                'type' => 'integer',
                'default' => 300,
                'description' => 'Timeout in seconds'
            }
        },
        'required' => ['agent_ids', 'prompt']
    }
}
```

### p7_agent_terminate
```perl
{
    'name' => 'p7_agent_terminate',
    'description' => 'Gracefully terminate a sub-agent, '
        . 'optionally preserving context to storage',
    'inputSchema' => {
        'type' => 'object',
        'properties' => {
            'agent_id' => {
                'type' => 'string',
                'description' => 'Agent to terminate'
            },
            'preserve_context' => {
                'type' => 'boolean',
                'default' => 1,
                'description' => 'Save context to P7 storage before exit'
            },
            'force' => {
                'type' => 'boolean',
                'default' => 0,
                'description' => 'Kill immediately without cleanup'
            }
        },
        'required' => ['agent_id']
    }
}
```

---

## Phase 2: Context Management Tools

### p7_context_configure
```perl
{
    'name' => 'p7_context_configure',
    'description' => 'Configure context compaction strategy for an agent '
        . 'or the parent process. Token-efficient layered storage.',
    'inputSchema' => {
        'type' => 'object',
        'properties' => {
            'target' => {
                'type' => 'string',
                'description' => 'Agent ID or "self" for parent',
                'default' => 'self'
            },
            'layers' => {
                'type' => 'array',
                'items' => {
                    'type' => 'object',
                    'properties' => {
                        'name' => { 'type' => 'string' },
                        'max_tokens' => { 'type' => 'integer' },
                        'compaction' => {
                            'type' => 'string',
                            'enum' => ['none', 'summary', 'checksum', 'p7ref']
                        }
                    }
                },
                'description' => 'Context layer configuration'
            },
            'overflow_action' => {
                'type' => 'string',
                'enum' => ['compact', 'spill', 'halt'],
                'default' => 'compact',
                'description' => 'Action when context exceeds limits'
            }
        }
    }
}
```

### p7_context_compact
```perl
{
    'name' => 'p7_context_compact',
    'description' => 'Manually trigger context compaction '
        . 'on specified layer or all layers',
    'inputSchema' => {
        'type' => 'object',
        'properties' => {
            'target' => {
                'type' => 'string',
                'description' => 'Agent ID or "self"',
                'default' => 'self'
            },
            'layer' => {
                'type' => 'string',
                'description' => 'Specific layer to compact (optional)'
            },
            'strategy' => {
                'type' => 'string',
                'enum' => ['summary', 'extract', 'checkpoint'],
                'default' => 'summary',
                'description' => 'Compaction strategy'
            }
        }
    }
}
```

### p7_context_spill
```perl
{
    'name' => 'p7_context_spill',
    'description' => 'Spill cold context layer to P7 storage, '
        . 'replace with P7REF checksum reference (zero-cost recall)',
    'inputSchema' => {
        'type' => 'object',
        'properties' => {
            'target' => {
                'type' => 'string',
                'description' => 'Agent ID or "self"',
                'default' => 'self'
            },
            'layer' => {
                'type' => 'string',
                'description' => 'Layer to spill'
            },
            'storage_path' => {
                'type' => 'string',
                'description' => 'P7 storage path (auto-generated if omitted)'
            }
        },
        'required' => ['layer']
    }
}
```

### p7_context_recall
```perl
{
    'name' => 'p7_context_recall',
    'description' => 'Recall spilled context from P7 storage back to active layer',
    'inputSchema' => {
        'type' => 'object',
        'properties' => {
            'target' => {
                'type' => 'string',
                'description' => 'Agent ID or "self"',
                'default' => 'self'
            },
            'p7ref' => {
                'type' => 'string',
                'description' => 'P7REF checksum of spilled context'
            },
            'layer' => {
                'type' => 'string',
                'description' => 'Target layer for recall'
            }
        },
        'required' => ['p7ref', 'layer']
    }
}
```

---

## Phase 3: Backend Routing Tools

### p7_backend_list
```perl
{
    'name' => 'p7_backend_list',
    'description' => 'List available inference backends '
        . '(local GPU, CPU, cloud APIs) with status and capabilities',
    'inputSchema' => {
        'type' => 'object',
        'properties' => {
            'capability' => {
                'type' => 'string',
                'enum' => ['text', 'vision', 'code', 'long-context'],
                'description' => 'Filter by capability'
            }
        }
    }
}
```

### p7_backend_select
```perl
{
    'name' => 'p7_backend_select',
    'description' => 'Select optimal backend for a task based on '
        . 'cost, latency, and capability requirements',
    'inputSchema' => {
        'type' => 'object',
        'properties' => {
            'requirements' => {
                'type' => 'object',
                'properties' => {
                    'capability' => { 'type' => 'string' },
                    'min_quality' => { 'type' => 'number' },
                    'max_cost' => { 'type' => 'number' },
                    'max_latency_ms' => { 'type' => 'integer' }
                }
            },
            'fallback' => {
                'type' => 'boolean',
                'default' => 1,
                'description' => 'Allow fallback to available backends'
            }
        },
        'required' => ['requirements']
    }
}
```

---

## Phase 4: Notifications (MCP streams)

```perl
# Subscribe to agent lifecycle events
# → notifications: agent.spawned, agent.completed, agent.error, agent.terminated

# Subscribe to context compaction events  
# → notifications: context.compacted, context.spilled, context.recalled

# Subscribe to backend status
# → notifications: backend.ready, backend.busy, backend.error
```

---

## Kimi-Web Zenka Design

```perl
# modules/kimi-web.init_code
# Spawns kimi-cli --web processes, manages their lifecycle

# Key features:
# - Port allocation (dynamic or configured)
# - Context preloading from P7 storage
# - Health checking and auto-restart
# - Token usage tracking
# - Graceful shutdown with context preservation

# Commands:
# kimi-web.spawn <config_hash> → returns agent_id
# kimi-web.status <agent_id>
# kimi-web.send <agent_id> <prompt>
# kimi-web.terminate <agent_id> [preserve_context]
```

## Usage Flow Example

```yaml
# Parent kimi-cli (me) wants to parallelize code review:

1. p7_context_configure:
   target: self
   layers:
     - name: hot
       max_tokens: 8000
       compaction: none
     - name: warm
       max_tokens: 32000
       compaction: summary
     - name: cold
       max_tokens: 128000
       compaction: p7ref

2. p7_agent_spawn x3:
   - agent_type: kimi-web
     context_slice: /data/md/coding-standards.md
   - agent_type: kimi-web
     context_slice: /data/md/security-guidelines.md
   - agent_type: local-llm
     model_config: { model: qwen-3.5-9b, quant: q4_k_m }

3. p7_agent_dispatch_parallel:
   agent_ids: [agent-1, agent-2, agent-3]
   prompt: "Review this code for [standards/security/performance]"
   aggregation: merge

4. p7_agent_terminate:
   agent_ids: [agent-1, agent-2, agent-3]
   preserve_context: true  # Learn from this review session

5. p7_context_compact:
   layer: warm
   strategy: extract  # Key learnings → warm layer
```

---

## Phase 5: Zenka-Desk — ASCII + Graphical Interface Layer

zenka-desk is a unified interface zenka providing both terminal and graphical
desktop surfaces for users and llm zenki alike. it extends bin/chat with a
full interactive environment: message system, notes, task view, detachable
buffers, and optional X11 graphical layer.


### architecture

```
zenka-desk
  ├── tui layer          — ascii art panels, ncurses-style layout
  │     ├── panel.chat   — bin/chat frontend, channel list, history view
  │     ├── panel.notes  — note_read / note_list / note_write via coding tools
  │     ├── panel.tasks  — task tree view, status, subtask drill-down
  │     ├── panel.plan   — live plan editor, linked to task tree
  │     └── panel.log    — tail of /dev/shm/.7/STDOUT/* or zenka stdout
  │
  ├── buffer system      — named, pipeable, shareable buffers
  │     ├── attach/detach any panel to a named buffer
  │     ├── pipe external command output → buffer → panel
  │     ├── models and users subscribe to buffers by name
  │     └── buffers committed to data/chat/channel/<name>/ on demand
  │
  ├── menu layer         — protocol-7-menu zenka for interactive routines
  │     ├── command palette (fuzzy match over zenka commands)
  │     ├── modal dialogs, confirmations, selection lists
  │     └── composable menus from yaml or live zenka command sets
  │
  └── x11 layer          — optional graphical desktop via X11 zenka
        ├── Xvfb virtual display (headless or forwarded)
        ├── openbox window manager + tile-groups zenka for layout
        ├── web-browser zenka for page rendering
        ├── screenshot zenka for capturing rendered output
        └── image pipeline → vision model → context injection
```


### key properties

- **node-transcending** — zenka-desk sessions roam with the user across nodes
  (same self-contained zenka design as topic-self-contained-zenka.md)
- **model-native** — llm zenki use the same interface as human users;
  context.* modules already provide most of the data access primitives
- **pipeable** — any zenka stdout can be piped to a named buffer and shared;
  models see the same output stream as the terminal user
- **detachable** — panels can detach (like tmux panes) and re-attach to
  any session or zenka-desk instance on any node
- **integrated with existing infrastructure** — reuses:
    - bin/chat for message routing
    - context.* for memory and note access
    - coding zenka tools for task/note/tree operations
    - protocol-7-menu zenka for interactive routines
    - X11/Xvfb + openbox + tile-groups for graphical layer
    - screenshot + web-browser zenki (needed anyway for job-site screenshots)


### mcp tools for zenka-desk

```perl
p7_desk_open       # open or attach to a zenka-desk session
p7_desk_panel      # show / hide / resize a named panel
p7_desk_buffer     # write to / read from / subscribe to a named buffer
p7_desk_pipe       # pipe command output to a buffer
p7_desk_menu       # invoke a protocol-7-menu routine by name
p7_desk_screenshot # capture current graphical display (x11 layer)
p7_desk_browser    # navigate browser zenka, return rendered html + screenshot
```


### x11 layer — screenshot + browser pipeline

```
web-browser zenka (chromium headless or firefox)
  → renders url inside Xvfb display
  → screenshot zenka captures framebuffer
  → image written to data/chat/channel/<name>/screenshots/
  → vision model analyzes image
  → summary injected into chat history or task context

same pipeline used for:
  - job site page rendering (job-pipeline)
  - visualization snapshots (space.v7.ax orbital view)
  - ui regression capture
  - document / pdf screenshot ingestion
```


### implementation path

```
phase 1 — buffer system + panel.chat
  wire bin/chat history into a scrollable tui panel
  named buffers with attach/detach and pipe-in support
  no x11 required

phase 2 — panel.notes + panel.tasks + menu layer
  context.* read/write via panel.notes
  task tree view via coding tools
  protocol-7-menu integration for command palette

phase 3 — x11 layer
  X11 zenka + Xvfb + openbox + tile-groups
  web-browser zenka (headless chromium)
  screenshot zenka
  image → vision pipeline

phase 4 — node-transcending sessions
  self-contained zenka serialization (topic-self-contained-zenka.md)
  session handover across nodes
  roaming panels follow the user
```

#,,..,,,.,,,,,...,,,,,.,,,.,.,,..,...,,,.,..,,.,.,...,...,...,.,.,...,,,,,,,.,
#XHZG424ZUBYJGJJI5LAIFCRZDSEPIHM3GSGLN6G3YJP5JNZ3CYOQGKLLJF7WEZPQELAKXNFGP3FNM
#\\\|2ZGNARDTFR64IU2VZC3SU7KUJPWUYQO4PLJBMWFM5KCAEUVOBFA \ / AMOS7 \ YOURUM ::
#\[7]C6RQ6ZHYLAYJZAQP6RRMBZ6TI3CZO3HIABVLELZP7N6O5DHWBSAI 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
