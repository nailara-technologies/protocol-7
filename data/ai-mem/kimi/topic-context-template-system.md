# Context Template System — April 2026

> Extracted from MEMORY.md. See main memory for cross-references.

**Location**: `data/yaml/context-templates/` (63 templates)
**Used by**: coding zenka (via `coding.cmd.ask` with `template=` parameter)
**Future**: kimi-web zenka will also resolve these via MCP

## Template Architecture

Templates are YAML files defining composable system prompts with:
- **Budget allocation** (`budget_pct`) per section
- **Priority ordering** for resolution when constrained
- **Conditional inclusion** (`when: task_type=debug`, `when: has_tools`)
- **Variable substitution** (`{{target_module}}`, `{{description}}`)
- **Provider pattern** for live data (`context.git.recent_changes`)
- **Post-task hooks** (`on_complete: memory_update`)

## Key Templates for Sub-Agent Offloading

| Template | Purpose | When to Use |
|----------|---------|-------------|
| `integrate-recent` | Wire new features into P7 system | After implementing isolated feature |
| `sub-task-decompose` | Break complex task into ordered chunks | Before large implementation |
| `review-deep` | Multi-pass review with rolling compaction | Large modules (>200 lines) |
| `git-diff-review` | Review changes pre-commit | Before `git commit` |
| `feature-impl` | Implement with reference patterns | When similar module exists |
| `code-review` | Standard code review | Any modified module |
| `style-wrap-ptd` | Format long lines, run ptd | Style cleanup pass |
| `tasks-prioritize` | Rank next tasks by momentum | Planning sessions |
| `session-wrapup` | Git summary + errors + next steps | End of session |
| `system-default` | Composable base with conditional sections | Default system message |
| `zenki-create` | Create new protocol-7 zenka | New zenka development |
| `zenki-feature-port` | Port features between zenki | Feature reuse |

## Template Composition Example

```yaml
# From system-default:
sections:
  - include: system-base           # Always included, 35% budget
    priority: 1
  - include: system-tools          # Only when has_tools
    when: has_tools
    budget_pct: 20
  - provider: context.style.guide  # Live style conventions
    when: task_type=review
    optional: true
  - provider: context.task.active  # Current task context
    when: has_active_task

on_complete:
  - when: [task_type=debug, output_contains=fixed]
    action: compact                # Auto-compact after fixes
    template: summarize-events
```

## Coding Zenka Usage

```bash
# Direct template resolution
p7c coding.ask template=integrate-recent

# With variables
p7c coding.ask template=review-deep target_module=coding.cmd.inference-status
```

The coding zenka's `ask` command resolves templates via `context.template.resolve`, which:
1. Loads YAML template
2. Evaluates conditions (`when:` clauses)
3. Calls providers for live data
4. Allocates budget proportionally
5. Concatenates sections into system message

## Forthcoming: Kimi-Web Integration

**Vision**: Parent kimi process spawns kimi-web sub-agents via P7:
```
Parent kimi → MCP → mcp-server-p7 → P7 cube → kimi-web zenka
                                                ↓
                                         Spawn kimi-cli web
                                                ↓
                                         Resolve templates
                                                ↓
                                         Return structured result
```

**MCP tools to add**:
- `p7_template_resolve` - Resolve template to context
- `p7_agent_spawn` - Spawn kimi-web sub-agent
- `p7_agent_dispatch` - Send work to sub-agent
- `p7_agent_dispatch_parallel` - Map-reduce across agents
- `p7_context_configure` - Set up layered context (hot/warm/cold)

## Critical Template Features

**Rolling Compaction** (`review-deep`):
- Pass 1: Structure overview (survives)
- Pass 2: Line-by-line in 50-line chunks, compacted between
- Pass 3: Cross-cutting concerns with summaries
- Pass 4: Self-review and classification

**Momentum-Based Prioritization** (`tasks-prioritize`):
```
Priority = 0.30*momentum + 0.25*explicit_priority + 0.20*dependencies
         + 0.15*effort + 0.10*staleness
```

**Pattern Compliance Checklist** (`integrate-recent`):
- Access wiring (cmd module in access list?)
- P7 patterns (`<[module.name]>->()` not direct)
- `$ARG` preservation (NEVER `$_`)
- Return format (`{mode => qw| true |, data => ...}`)
- Log format (`<[base.logs]>->(level, fmt, ...)`)

## Files to Know

- `data/yaml/context-templates/system-default.yaml` - Base composable template
- `data/yaml/context-templates/system-review.yaml` - Review checklist (P7 patterns)
- `data/yaml/context-templates/system-tools.yaml` - Tool usage docs
- `src/context.template.resolve` - Template resolution engine
- `src/coding.cmd.ask` - Main interface for template queries

#,,,.,,,.,,..,,,.,...,,,.,,,.,.,.,,,,,,..,.,.,..,,...,...,,.,,,.,,.,,,.,.,,.,,
#ORXN3J54QBGAEOLCAH4OL765XFWHIAMIYZC24L5M3M4TG3DTHOZJUD5H3CRPZCLYPI2XKESNGYRXE
#\\\|CR26P6725NQHFQYNH73A7L7YE6FPAWMEOEKWRGS7MIXVCDDPS4I \ / AMOS7 \ YOURUM ::
#\[7]AYA5TLWDW3ODZT2FCGYKQFFVK5AZKWXELFAWTYKBMP64QXWXYSAI 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
