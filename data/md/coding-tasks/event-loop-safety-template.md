# event-loop-safety — context template for tight loop detection and repair

**Priority:** Medium
**Type:** Research + Template Creation
**Component:** coding zenka context templates, event loop patterns

## Overview

Write a context template `event-loop-safety` that teaches models to recognize
and fix while loops that bypass the native AnyEvent/EV event system. The
template should be grounded in real P7 patterns found in the codebase, not
generic advice.

The coding zenka itself is the right tool to write this template because it
can investigate the actual event integration patterns used in well-designed
zenki and contrast them with the problematic cases.

## Background

A 100% CPU spin was observed in the coding zenka (session 2026-05-09). The
likely cause was a while loop running without yielding to the event loop. This
class of bug is subtle because:
- the loop may exit in the normal case but spin on an edge case
- it produces no error — the process just becomes unresponsive
- it cannot be detected from inside the frozen event loop
- only heartbeat timeout or external kill recovers it

Known while loops in coding zenka (some safe, some suspected):
- src/coding.handler.http_io      line 127  buffer regex — appears safe
- src/coding.handler.http_poll    line 116  buffer regex — appears safe
- src/coding.handler.process-queued-task line 204  LWP blocking loop — SUSPECT
- src/coding.cmd.wait-done        line 27   event.once poll — safe
- src/coding.handler.drain_pipe   line 24   sysread loop — safe

## Your Task

Investigate and then write the template. Two phases:

### Phase 1: Research

**search_code note:** use simple literal patterns only — no \Q, no \s*, no complex
regex metacharacters. backslashes in search patterns corrupt over rounds.
good: `search_code(pattern: "while (1)")` or `search_code(pattern: "event.once")`
bad: `search_code(pattern: "while\s*\(\s*1\s*\)")` — will spiral.
prefer reading modules directly over searching for complex patterns.

1. Search for well-designed event-integrated patterns in the codebase:
   - How do handler modules register and cancel io/timer watchers?
   - How does `event.once` work and when is it the right tool?
   - What is the `event.add_timer` / `event.add_io` pattern?
   - How do blocking operations (LWP, sysread) get wrapped safely?
   - How do zenki avoid blocking the event loop during long operations?
   - use search_code(pattern: "event.once") and search_code(pattern: "event.add_timer")

2. Read examples of good event integration:
   - src/base.event.* — the event primitives themselves
   - src/coding.async.* — async request/response patterns
   - src/coding.handler.drain_pipe — sysread-safe example
   - At least one zenka that handles network I/O cleanly

3. Identify the taxonomy of while loop risks:
   - tight spin (no yield, no blocking syscall)
   - blocking syscall (yields OS but not event loop)
   - polling loop (yield via event.once — generally safe)
   - watcher callback loop (fine if watcher is cancelled properly)
   - regex buffer loop (safe only if regex cannot match empty + advance)

4. Identify legitimate outlier cases where a blocking loop is acceptable:
   - what makes it acceptable? (bounded iterations, startup-only, forked child)
   - how should it be documented?

### Phase 2: Write the Template

Write the template to:
  data/yaml/context-templates/event-loop-safety.yaml

The template should:

1. **Explain the event model** — brief section on how AnyEvent/EV works in P7
   zenki, what "blocking the event loop" means, why it's severe (all network
   I/O, all other watchers freeze)

2. **Provide a detection checklist** — for each while loop found:
   - does it call event.once or event.add_timer inside?  → safe
   - does it call a blocking syscall (sysread, LWP)?     → blocks OS thread, investigate
   - does it call neither?                               → DANGER — tight spin
   - is it bounded by a small constant?                  → acceptable if documented
   - is it in a forked child or startup-only path?       → acceptable

3. **Provide repair patterns** — for each class of unsafe loop:
   - tight spin → convert to timer watcher with cancel on completion
   - blocking LWP call → move to forked child or use async http_client
   - regex buffer loop → add guard: `last if $prev_len == length $buffer`
   - polling loop → use event.once(N) with minimum interval

4. **Document legitimate exceptions** — with required annotation format:
   ```perl
   ## event-loop-safe: bounded N iterations, startup-only [ no yield needed ] ##
   while ( ... ) { ... }
   ```

5. **Include audit instructions** — when this template is active, the model
   should search for while/until/for loops in any module under review and
   apply the checklist to each one, using consensus_query(mode: verify) to
   validate any DANGER classification before flagging it.

## Template Structure

```yaml
name: event-loop-safety
descr: detect and repair while loops that bypass the AnyEvent/EV event loop
budget: 5000
sections:
  - provider: context.style.guide          ## P7 style conventions
  - static: <event model explanation>
  - static: <detection checklist>
  - static: <repair patterns>
  - static: <audit instructions>
  - provider: context.file.extract         ## target module ({{target_module}})
    params:
      path: "{{target_module}}"
    optional: true
```

## Output

After writing the template:
1. `ptd -c data/yaml/context-templates/event-loop-safety.yaml` — verify syntax
2. Test it: submit a review of `src/coding.handler.process-queued-task`
   using the new template and report what it finds
3. Write a brief note (note_write) summarizing the key patterns discovered
   during research — this becomes training data for future reviews

## Acceptance Criteria

- template file exists at data/yaml/context-templates/event-loop-safety.yaml
- detection checklist covers all 5 loop taxonomy classes
- repair patterns are concrete (specific P7 syntax, not generic advice)
- legitimate exceptions are documented with the annotation format
- template tested on at least one real module
- research note written with key patterns found

## Notes

- signatures_note: leave signing to the system, no stub lines
- the template is the deliverable, not a module fix — do not modify any
  modules during this task, only write the template and research notes
- if you find a clear DANGER case during research, note it in note_write
  with the module name and line — a separate fix task will address it

#,,,,,.,.,,,.,...,,..,,,.,...,.,,,.,.,.,.,.,.,..,,...,..,,,..,,.,,..,,.,.,..,,
#UCY4FZUWFYXQ56HQPUZRZ2GKETKYPJMVHH6CM52EI5HEMT6FNXQGYO4AXGTYDY3IVO4G2TMLXNUEY
#\\\|WPZV35AORP7GWWPBDNQZ6AOXNVIRKUCMP5TS4NMRFHEZPQ4U7RA \ / AMOS7 \ YOURUM ::
#\[7]4L3NZKARGL2A5CGLG6P7AMTH6PBN6GJGZWAVCNGTOK7X4T4FMACI 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
