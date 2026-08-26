---
name: coding zenka template system
description: context template system for coding zenka — tool calling, review cycles, meta-reflection
type: project
---

## Coding Zenka Template System (Mar 28, 2026)

The coding zenka now has a full context template system with 25+ YAML templates
at `data/yaml/context-templates/`. Templates are resolved by `context.template.resolve`
with recursive includes, `when` conditions, providers, and `on_complete` hooks.

### Key Architecture
- Templates resolved in `coding.prompt.assemble` → system prompt for inference
- `system-default.yaml` is the root template, includes `system-base`, `system-tools`, `system-memory`
- `_evaluate_when` strips `has_` prefix: context key `tools` matches `when: has_tools`
- Budget-aware: each section gets `budget_pct` of total, truncated to fit

### Tool Calling Pipeline (16+ tools)
- Defined in `coding.tools.definitions`, dispatched via `coding.tools.dispatch`
- Auto-dispatch fallback: `$code{"coding.tools.handler.$name"}` for any tool not in dispatch table
- Core tools: read_file, read_module, list_modules, module_deps, recent_changes,
  recent_errors, list_files, extract_file, search_code, dep_graph, ncode_search,
  edit_file (preview+apply), write_new_file (overwrite-protected), replace_in_file,
  validate_module_format, list_inline_subs
- Tree tools: tree_read, tree_write, tree_list (wrappers around base.resolve_key/base.set_key)
- Completion: task_complete, record_question, record_suggestion
- **Critical**: llama-server sends args as JSON strings — must parse before hashref check

### Inference Loop Features
- Max 247 tool rounds per task (raised from 42 via 1.4x JSON overhead multiplier)
- Context compaction at 70% of context_length (graduated: old=aggressive, recent=preserved)
- `event.once(0.0007)` yield between tool rounds for network responsiveness
- Model: Qwen3.5 9B (MBZAAII:ZRCGL5Q), context_length=77777
- **Round budget hints in templates** — autonomous templates include explicit round
  budget guidance (e.g. "aim for 15-25 tool rounds max") to prevent exhaustive exploration

### Template Categories
- **System**: system-base, system-tools, system-memory, system-review, system-default
- **Review**: module-review, tool-review, review-cycle (CONFIDENT/FIXABLE/UNCERTAIN), review-deep (multi-pass)
- **Style**: style-fix, code-review, cmd-style-fix
- **Autonomous**: namespace-audit, review-and-improve, fix-format-issues, git-diff-review, header-tags-fix
- **Exploration**: tree-explore, sub-task-decompose, whats-next
- **Extraction**: extract-inline-subs, extract-redundancy
- **Tasks**: tasks-open, tasks-completed, tasks-prioritize (momentum-weighted)
- **Tools**: tool-errors, tool-fix
- **Meta**: meta-reflect (5 streams), meta-create-template, meta-cascade (orchestrator)
- **Utility**: commit-msg, git-context, session-cleanup, session-wrapup

### Known Issues
- `context.error.recent`: readline on unopened filehandle (error log file not found)
- `context.git.recent_changes`: git error on clean trees (no changes to diff)
- Cache keyed by prompt hash only, not model ID — clear-cache needed on model switch
- Inference server cleanup: duplicate llama-server processes on restart

**Why:** This is the foundation for self-improving P7 ��� model reviews code, generates
templates for repeatable workflows, and the meta-cascade orchestrates follow-up actions.

**How to apply:** When working on coding zenka, reference this for template format,
tool list, and known issues. Template vars use `{{name}}` syntax, conditions use
`has_X` / `task_type=value` / `not_X` patterns.

#,,..,...,..,,,,,,,,.,,,,,..,,,,.,.,.,.,,,,..,..,,...,...,.,.,,.,,,,,,.,,,,,.,
#4YU3ATMRUX6RQLVUOM2O2H7CY4OFTWCXDQ7KCJFMO353ZMQRK4XMUAOSPAFMVUAIYYOSEIQTH3RUE
#\\\|QKDSYGYQBPBYZNVAGGI6VEQAY66HNGRD7J7UFUUBWFRTCN3KY7H \ / AMOS7 \ YOURUM ::
#\[7]FL3M32GFDJ77BYJI6FFNPR2MNZJKUHJYXKCMKB4NK7CJPSPQS4AA 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
