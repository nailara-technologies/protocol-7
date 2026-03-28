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

### Tool Calling Pipeline (13 tools)
- Defined in `coding.tools.definitions`, dispatched via `coding.tools.dispatch`
- Tools: read_file, read_module, list_modules, module_deps, recent_changes,
  recent_errors, list_files, extract_file, search_code, dep_graph, ncode_search,
  edit_file (preview+apply), write_new_file (overwrite-protected)
- **Critical**: llama-server sends args as JSON strings — must parse before hashref check

### Inference Loop Features
- Max 42 tool rounds per task
- Context compaction at 70% of context_length (graduated: old=aggressive, recent=preserved)
- `event.once(0.0007)` yield between tool rounds for network responsiveness
- Model: Qwen3.5 9B (MBZAAII:ZRCGL5Q), context_length=16384

### Template Categories
- **System**: system-base, system-tools, system-memory, system-review, system-default
- **Review**: module-review, tool-review, review-cycle (CONFIDENT/FIXABLE/UNCERTAIN), review-deep (multi-pass)
- **Style**: style-fix, code-review
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

#,,..,...,,,,,,,,,,,,,.,.,...,.,,,,,.,.,,,...,..,,...,...,,..,,,.,,,,,..,,.,.,
#NYF7LYK5XDZ4FFE3IKG7F3SJ3OR5RVDK5MBBCTUE3PB6NX3UEEY67KVCU6DOW3WDNTERVVHC4ZF7Q
#\\\|P6PC3MSEKUNZNLDJPIZ7TV3VO546SN7KHYMS4ZZXMNDSASD3RD3 \ / AMOS7 \ YOURUM ::
#\[7]7UNLF2PZZKUTOUEX5BW5J5O52KJB4WHMVRRKM2FEOG6KGSRWNADI 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
