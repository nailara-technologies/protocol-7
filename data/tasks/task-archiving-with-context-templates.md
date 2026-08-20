## task: intelligent task archiving + context template generation

### motivation

task files in `data/tasks/` accumulate. after a feature is implemented,
the task file should be archived with a record of what was done, and a
context template should be written capturing the fresh post-completion
insights — optimized for future AI sessions picking up the same area.

---

### part 1: intelligent task archiving

when archiving a task file, the archiver should:

1. **trace git history** — find commits that touched the files mentioned
   in the task spec (modules, config, HTML). use:
   ```bash
   git log --oneline --all -- <file>
   ```

2. **read memory updates** around those commits — check
   `data/ai-mem/claude/session-*.md` for entries near the commit dates
   that describe implementation state, bugs found, or testing notes.

3. **determine completion state** — from git history + memory:
   - DONE ✓ — implemented, tested, committed
   - PARTIAL — some steps done, others pending
   - NEEDS-TESTING — implemented but not verified in production
   - SUPERSEDED — replaced by a different approach

4. **write archive entry** — move task to `data/tasks/completed/` (or
   `data/tasks/needs-testing/` if NEEDS-TESTING) and prepend a header:
   ```
   ## archive: DONE ✓ — <date>
   ## commit: <hash> — <message>
   ## notes: <one-line summary of what was found in memory>
   ```

5. **do not guess** — if the git history is ambiguous, mark as PARTIAL
   and describe what was found.

---

### part 2: context template generation

after archiving, write a context template at:
`data/yaml/context-templates/<task-slug>-completed.yaml`

the template captures what an AI assistant would need to know to work
efficiently in this area. study the existing templates in
`data/yaml/context-templates/` for style and format.

template should include:
- what was built (modules, config changes, key design decisions)
- gotchas discovered during implementation (encoding issues, API quirks,
  wrong assumptions that had to be corrected)
- how to test/verify the feature
- related src/files for future work in this area
- open items or known limitations discovered

#### self-optimizing templates

when a template is used in a future task and that task completes, the
template should be updated with new insights. the update prompt:

> "you just completed a task in the <area> namespace. update the context
> template at data/yaml/context-templates/<slug>.yaml with any new
> insights, gotchas, or corrections from this session. keep it concise."

---

### part 3: templates for dispatch workflows

create two meta-templates:

#### `data/yaml/context-templates/kimi-dispatch-workflow.yaml`
captures how to write effective kimi task files, common pitfalls
(signature stubs, `$_` vs `$ARG`, fake SUPER:: calls), what context
to include, how to structure the dispatch prompt.

#### `data/yaml/context-templates/claude-dispatch-workflow.yaml`
captures how to use `claude_dispatch` / `claude_continue` efficiently:
- what tasks benefit most from claude vs kimi
- how to structure the outer prompt for minimal token overhead
- the kimi-via-claude pattern (claude orchestrates kimi)
- how to read the result summary efficiently
- when to use claude_continue vs starting fresh

both templates should self-update after each dispatch session.

---

### implementation

can be implemented as:
- a standalone bin script: `bin/dev/archive-task <task-file>`
- OR dispatched via claude_dispatch for a batch of tasks

the script should be runnable standalone without the P7 zenka network.
use YAML::XS, git commands via backticks, and write output to the right
directories.

---

## dispatch

#,,,.,,..,..,,,..,.,,,,..,..,,.,,,...,.,,,.,,,..,,...,..,,.,,,.,.,,..,.,.,,,,,
#I7SR7FEV3MMQ2DMLLLIHDS2UK5VOLHIXSHFKLXPQVTJEG6WQWY3AEV7ZBSVKQKINJVQWOHUGPZBXA
#\\\|LK4YN32LTGDJHHF566BIBWILPFESCGT6TNH2B5WXY35UIOJP3CA \ / AMOS7 \ YOURUM ::
#\[7]355SJINAP3HSJBQX2WTQ63HSMGGEYQ23KMOPSFMV7EQLMYG6KGBA 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
