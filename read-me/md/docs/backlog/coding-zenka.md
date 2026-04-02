# Coding Zenka Backlog

This file tracks feature ideas, improvements, and technical debt for the coding zenka.
Items are categorized and can be claimed by prefixing with `[IN PROGRESS]` or `[DONE]`.

## Documentation

- [ ] Update CLAUDE.md with new `list-tools` and `call-tool` commands
- [ ] Document pagination parameters (`offset`, `length`) for tools
- [ ] Write troubleshooting guide for common tool errors
- [ ] Document the module-health-audit template usage
- [ ] Add examples for search_code with pagination

## Code Improvements

- [ ] Refactor `coding.tools.dispatch` - split into smaller modules (500+ lines)
- [ ] Add comprehensive tests for note handlers (note_list, note_read, note_write)
- [ ] Improve error messages in tool handlers with context
- [ ] Add validation for tool argument types before dispatch
- [ ] Optimize context compaction logic for very large conversations

## Testing & Analysis

- [ ] Run `module-health-audit` on core modules (base.*, coding.*, context.*)
- [ ] Test pagination features with real large files (>100KB)
- [ ] Verify all tools work via `call-tool` command
- [ ] Benchmark tool dispatch performance
- [ ] Test loop detection with various patterns

## New Features

- [ ] Add `tool-help` command for detailed tool usage
- [ ] Create `batch-call` tool for running multiple tools
- [ ] Add category filtering to `list-tools` (file-ops, search, notes, etc.)
- [ ] Add `tool-test` command to validate a tool is working
- [ ] Implement tool result caching for expensive operations
- [ ] Add progress indicator for long-running tool calls

## Bug Fixes / Technical Debt

- [ ] Fix `validate_module` parameter handling (currently returning "module parameter required")
- [ ] Improve `ptd_format` non-writable file warnings
- [ ] Fix `list_files` pattern matching with "." root
- [ ] Enhance `extract_file` "functions" mode to actually extract functions
- [ ] Add timeout handling for external tool calls (grep, ncode)

## Performance

- [ ] Profile token usage for common tool patterns
- [ ] Optimize message serialization for large contexts
- [ ] Implement incremental result streaming for search tools
- [ ] Add memory usage monitoring for long-running tasks

## Integration

- [ ] Add MCP server tool definitions to `bin/mcp-server-p7`
- [ ] Create VSCode extension integration points
- [ ] Add webhook support for task completion notifications
- [ ] Integrate with external code review tools

---

## How to Add Items

1. Add to appropriate category
2. Be specific about what needs to be done
3. Link to related files/modules when relevant
4. Mark as `[IN PROGRESS]` when starting work
5. Mark as `[DONE]` when complete (don't delete, for history)

## Completed Recently

- [DONE] Fix note handlers (note_list, note_read) array reference bugs
- [DONE] Add Jinja template sanitization
- [DONE] Implement loop detection with forced stop
- [DONE] Add pagination support (offset, length parameters)
- [DONE] Create `list-tools` and `call-tool` commands
- [DONE] Create `module-health-audit` template
- [DONE] Add git wrapper to enforce signature policy
- [DONE] Add identical response detection to catch stuck models
- [DONE] Include round/context info in compaction summaries
- [DONE] Fix cumulative score window (8 entries instead of 32)

## Lessons Learned

### Task Scoping
- **Broad tasks cause loops**: "Analyze coding.* namespace" → 473 rounds, hallucinations
- **Focused tasks complete quickly**: "Analyze coding.cmd.submit module" → 4 rounds, perfect results
- **Always specify deliverables**: "Suggest ONE improvement" vs open-ended analysis

### Loop Detection Patterns
- Tool-call patterns alone aren't enough
- Identical model responses are a key signal of stuck models
- Context compaction without round info confuses models (they think "just started")

### Model Behavior
- Models hallucinate when given too much freedom (invented `canonical_cpp`, `canonical_fortran`, etc.)
- Repetitive identical responses indicate the model has stopped reasoning
- Clear constraints prevent runaway tasks

#,,.,,,,,,.,,,.,.,.,.,,..,..,,..,,.,.,..,,.,.,..,,...,...,,..,.,,,..,,,,,,,..,
#FICGYWJ4GLBJ6X53B25XGFRICY7542UE46GFJK2XJLYOVLNEESCKWE55NOOJAOQI5HUT3D5FFQVMC
#\\\|EVLLVZB5BXVSCBUULCLWDQT32XGTIAANSHQVOQQ7J5PTSAM6OYW \ / AMOS7 \ YOURUM ::
#\[7]KWPBK45VT3GXNXE2EAGF6U3ATHUYDJBW3YXAGRNFF25LWAIIHCBQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
