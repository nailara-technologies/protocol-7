# Notes Tools Expansion

**Priority:** Medium
**Type:** Feature — Tool Expansion
**Component:** coding zenka notes system
**Related:** modules/note.*, modules/coding.tools.handler.note_*, modules/coding.tools.definitions

## Overview

Expand the notes tool system from 7 tools to 14. The current toolkit handles
write/read/list/search/summarize/categorize/init. Missing are CRUD operations
(delete, update), organization (tag, filter), cross-task access (recent, history),
and batch efficiency.

## Implementation Pattern

Each new tool requires 3 files + 2 config entries:

1. **Backend module**: `modules/note.<name>` — core logic, uses `file.*` operations
2. **Tool handler**: `modules/coding.tools.handler.note_<name>` — thin wrapper, returns `{ content => ... }`
3. **Tool definition**: add to `modules/coding.tools.definitions` — OpenAI function schema
4. **Whitelist**: add both module names to `cfg/zenki/coding/subroutine.white-list`

### Reference implementation — follow `note.write` / `coding.tools.handler.note_write`:
- backend receives raw args, returns `{ mode => 'true'|'false', data => ... }`
- handler extracts args from hashref, calls backend, formats content string
- tool definition has name, description, parameters with json schema

### Storage layout (existing):
```
/var/protocol-7/coding/notes/<task_id>/
  .meta              — json: { rounds, last_update, ... }
  summary.short      — L1 summary
  summary.long       — L2 summary
  workspace/         — section files
    findings.md
    questions.md
    observations.md
    ...
```

## Tools to Implement (7 new tools, priority order)

### Phase 1: Core Operations (implement first)

#### 1. note_delete
Remove a note section or entire task notes.
```
parameters:
  task_id:  optional, defaults to current task
  section:  optional — if given, delete single section file; if omitted, delete entire task notes
```
- backend: `note.delete` — unlink section .md file, or rmtree task dir
- safety: refuse to delete if task_id not found; log deletion
- return: "deleted section '<name>' from <task_id>" or "deleted all notes for <task_id>"

#### 2. note_update
Replace content in an existing note section (not append like note_write).
```
parameters:
  section:  required — section name
  content:  required — new content (replaces entire section)
  task_id:  optional, defaults to current
```
- backend: `note.update` — overwrite section file (not append)
- difference from note_write: write appends with timestamp, update replaces entirely
- add timestamp header to replacement content
- return: "updated section '<name>' (<bytes> bytes)"

#### 3. note_tag
Add tags to a note section for flexible organization.
```
parameters:
  section:  required — section to tag
  tags:     required — comma-separated tag list
  task_id:  optional
```
- backend: `note.tag` — store tags in `.meta` json under `tags.<section>` array
- tags are lowercase, alphanumeric + hyphens only
- return: "tagged '<section>' with: <tag1>, <tag2>"

### Phase 2: Cross-Task Access (implement second)

#### 4. note_recent
List recent notes across all tasks (not just current task).
```
parameters:
  count:    optional — how many recent entries, default 10
  section:  optional — filter by section name
```
- backend: `note.recent` — scan notes base dir, sort task dirs by .meta last_update
- return: list of { task_id, section, timestamp, preview } entries
- preview: first 80 chars of most recent entry in each section

#### 5. note_filter
Multi-criteria filtering across notes.
```
parameters:
  tag:      optional — filter by tag
  section:  optional — filter by section name pattern
  after:    optional — only notes updated after this timestamp
  task_id:  optional — limit to specific task
```
- backend: `note.filter` — combine criteria, return matching sections
- uses .meta for tag filtering, file mtime for date filtering
- return: list of matching { task_id, section, tags, last_update }

### Phase 3: Efficiency (implement third)

#### 6. note_history
Show modification history for a note section.
```
parameters:
  section:  required
  task_id:  optional
  count:    optional — how many entries, default 5
```
- backend: `note.history` — note.write already appends with timestamps and `---` separators
- parse section file, split on `---`, return most recent N entries with timestamps
- return: list of { timestamp, content_preview } entries

#### 7. note_merge
Combine notes from multiple sections or tasks.
```
parameters:
  source_sections:  required — comma-separated list of "section" or "task_id:section"
  target_section:   required — destination section name
  target_task_id:   optional — defaults to current task
```
- backend: `note.merge` — read source sections, concatenate with headers, write to target
- add source attribution: `## merged from <task_id>/<section> ##`
- return: "merged N sections into '<target>' (<bytes> bytes)"

## Implementation Rules

### CRITICAL — follow these exactly:
- use `$ARG` not `$_` — the local model regresses this after context compaction
- lowercase comments: `## delete section file ##` not `## Delete Section File ##`
- annotations use `[ word ]` not `( word )`
- module files do NOT use `sub { }` — filename IS the subroutine
- do NOT add the single-line `#,,.,,,...` stub at end of new files
- leave new files clean — `bin/Protocol-7 sourcecode update-signatures` adds the real footer
- use `<[file.path.make_dir]>` not raw `mkdir`
- use `<[file.read]>` and `<[file.write]>` not raw open/close
- use `<[base.logs]>->( $level, $format, @args )` for logging (sprintf format, no interpolation)
- use `<[base.time]>->(2)` for human timestamps, `->(3)` for epoch float
- tool handlers return `{ 'content' => $string }` — always a hashref with content key
- backend modules return `{ 'mode' => 'true'|'false', 'data' => ... }`
- add both module names to `cfg/zenki/coding/subroutine.white-list`
- add tool definition to `modules/coding.tools.definitions` following existing note_* pattern
- verify syntax with `ptd -c modules/<name>` after writing each file

### One tool at a time:
Implement one complete tool (backend + handler + definition + whitelist), verify with
`ptd -c`, then move to the next. Do not batch implementations.

### Round budget: 5 rounds per tool (35 total for all 7)

#,,,.,.,,,,..,.,,,.,.,,,.,..,,,,,,...,,,,,...,..,,...,..,,,..,...,,.,,.,,,,.,,
#7MJ26JQQUKAAJQR5WNH4O7TGZKBDE2IYZBNJAUXIEWZ6XSR2HVQ6STQEWQXNQC2E64SRXVHOFZGQO
#\\\|XJIUHKAT3OBH2JOAPBC2AGFT6V5K3UDVGBZ6SS2FFQUPKSNMSWZ \ / AMOS7 \ YOURUM ::
#\[7]UVFT4U36RLUT6NUIMKRQG47WX3VTW62PZVAXDCYRLCWWPLVPYUDY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
