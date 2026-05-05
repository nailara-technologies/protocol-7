# Kimi Development Memory - Protocol-7

> ⚠️ **CRITICAL COMMIT POLICY**: Never commit without valid version number (run `./bin/dev/update-version`) and proper signatures (run `bin/Protocol-7 sourcecode update-signatures`). Use `--no-verify` only in emergencies.

> 📖 **BEFORE STRUCTURAL WORK**: Read `data/md/development/STYLE-PHILOSOPHY.md` alongside
> `data/yaml/code-style/CONVENTIONS.yaml` and `data/md/development/CODE-STYLE-AND-LLM-INTEGRATION.md`.
> The philosophy doc covers *why* the conventions are load-bearing, not just *what* they are.
> Update it if you arrive at refined perspectives after reading it.

## Round-Based Scheduling & Subtask Spawn — COMPLETE (April 2026)

> **STATUS: Fully working as of 2026-04-30.** Full subtask round-trip verified.
> Detailed topic file: `data/ai-mem/kimi/topic-round-scheduling-subtasks.md`

### Post-Handover Fixes (Claude sessions, Apr 29-30 2026)

After kimi's implementation and debugging, three additional Claude sessions resolved
remaining issues:

**1. Double-spawn VRAM starvation (root cause of most timeouts)**
- Two `llama-server` processes spawned simultaneously (same seed) when `model_path_reply`
  and deferred timer called `async_spawn_inference_servers` in the same event loop tick
- Second process held ~250MB VRAM, starving first server's KV cache → silent hang
- Fix: `<coding.spawning_in_progress>` guard in `coding.async_spawn_inference_servers`

**2. Stale-process kill race**
- `fuser` killed stale pid → `waitpid` was no-op (non-child) → `pgrep` immediately
  found same pid as "foreign" → blocked spawn
- Fix: `@killed_stale_pids` array in `coding.spawn_inference_server` skips those PIDs
  in the subsequent foreign-process check

**3. Subtask backend lock deadlock**
- Parent held backend lock while transitioning to `subtask` state; child tried to run
  immediately via jobqueue and hit `select_backend`'s blocking LWP `/health` check
- Fix A: `subtask_spawn` releases parent lock after setting `pending_subtask`
- Fix B: `select_backend` uses cached `inference_servers` status (`'ready'`) fast path
- Fix C: `http_complete` has explicit `subtask` case (clean return, no lock ops)

**4. Timeout recovery**
- After all retries fail on timeout with server status `'ready'`, `http_error` now
  marks server `restart_needed`, clears `<inference.gpu_pid>`, schedules deferred respawn

**Verified**: `coding.submit` + `coding.wait-done` full subtask round-trip working.

### Architecture

**Round-based scheduling** breaks the async inference callback chain into discrete jobqueue jobs.
Each inference round is enqueued as a separate job (`task_id.round_N`). When tool execution
completes, the next round is enqueued rather than chaining directly via `send_request`.

Controlled by: `coding.async.round_scheduling.enabled = yes` in `configuration/zenki/coding/start`

### Subtask Spawn Flow

```
Parent (streaming) --subtask_spawn--> tool_exec
  └─→ creates Child task, Parent state → subtask
  └─→ Child runs independently via jobqueue
  └─→ Child completes → async.complete injects result + resumes Parent
  └─→ Parent transitions subtask → streaming, enqueues next round
```

### Critical Fixes Applied

**1. Duplicate Request Prevention**
- `http_error` sets `retry_pending` flag; duplicate error callbacks are ignored
- `retry_request` clears the flag before calling `send_request`
- `execute_round` skips if `retry_pending` is true (prevents jobqueue re-execution race)
- `async.request` cancels stale `http_state` connections before starting new ones
- Files: `coding.callback.http_error`, `coding.callback.retry_request`, `coding.task.execute_round`, `coding.async.request`

**2. Partial Content Recovery on Connection Close**
- `http_complete` checks `$state->{'chunk_context'}->{'content'}` when `finish_reason` is missing
- Falls back to `$http_state->{'buffer'}` for raw non-SSE JSON responses
- Prevents "connection closed with no data" from losing partial model output
- Files: `coding.callback.http_complete`

**3. Parent Resume from Subtask State**
- `coding.async.complete` transitions parent from `subtask` → `streaming` before enqueueing next round
- Verifies completing child matches `$parent_state->{'pending_subtask'}` before resuming
- Orphaned children (completed after parent already resumed) are logged but ignored
- Files: `coding.async.complete`

**4. Subtask Spawn Deduplication**
- `subtask_spawn` rejects if parent already has `pending_subtask` set
- Rejection happens **before** `coding.task.enqueue` (prevents orphaned child tasks)
- Returns error message to model: "already waiting for subtask X"
- Files: `coding.tools.handler.subtask_spawn`

**5. String Priority Mapping**
- Task priorities are strings (`critical`, `high`, `normal`, `low`) from `coding.intake.normalize_task`
- `coding.task.enqueue_round` maps them to numeric values for jobqueue sorting
- Prevents `argument 'normal' isn't numeric in sort` warning in `jobqueue.get_next_job`

### Modules Added/Modified

| file | purpose |
|------|---------|
| `modules/coding.task.enqueue_round` | enqueue inference round as jobqueue job |
| `modules/coding.task.execute_round` | job callback: execute one round |
| `modules/coding.tools.handler.subtask_spawn` | spawn child task with parent tracking |
| `modules/coding.async.state_machine` | `tools_done` → enqueue round (vs direct chain) |
| `modules/coding.async.send_request` | injected message + pause support |
| `modules/coding.async.complete` | resume parent on child completion |
| `modules/coding.callback.http_complete` | partial content recovery |
| `modules/coding.callback.http_error` | duplicate retry prevention |
| `modules/coding.callback.retry_request` | clear retry_pending flag |
| `modules/coding.async.request` | stale connection cleanup |
| `configuration/zenki/coding/start` | `round_scheduling.enabled = yes` |

### Known Server-Side Issue (Not a Scheduling Bug)

The llama-server occasionally returns incomplete responses (HTTP 200 with no `finish_reason`,
or closes connection with partial data). This manifests as:

```
async.request: inference complete for task-X [N bytes, 1 chunks]
http_complete: task task-X connection closed with no data
```

The client-side retry logic handles this. The server issue is separate from the scheduling system.

---

## Coding Zenka Infrastructure Commands (March 2026)

### New Commands Added

**`coding.inject-message <task_id> <message>`**
- Injects a user message into an active coding task's conversation
- Message appears as user role in next inference round
- Implementation: Adds to `$task->{'injected_messages'}` array
- Processing: `coding.handler.process-queued-task` checks after event yield
- Use case: Human intervention, hints, corrections without stopping task

**`coding.wait-done <task_id> [timeout]`**
- Blocks until task completes, fails, or timeout
- Timeout is optional; 0 or omitted = wait indefinitely (tasks can run very long)
- Returns: `{mode: true, data: result}` on success, `{mode: false, data: error}` on failure
- Fails immediately if task not found
- Note: During active inference, event loop doesn't yield for polling (architectural constraint)

### Files Added/Modified
- `modules/coding.cmd.inject-message` - new command
- `modules/coding.cmd.wait-done` - new command
- `modules/coding.handler.process-queued-task` - injection point after event yield
- `modules/coding.file.strip_trailing_spaces` - extracted helper
- `modules/coding.tools.handler.strip_trailing_spaces` - use extracted helper
- `modules/base.list.subroutines` - register new modules
- `configuration/zenki/coding/start` - command access permissions

---

## Coding Zenka Fixes (April 2025)

### Summary
Major fixes to tool dispatch, error handling, and context management.

### Recent Fixes (March 2026)

**1. Model Name Garbage Detection**
- Problem: GGUF metadata contained garbage names like "Unsloth Gguf 909Acke7"
- Fix: Detect tool signatures and random patterns, fallback to parent directory name
- Files: `models.gguf.file.is_garbage_name`, `models.gguf.file.extract_name`

**2. GPU Spawn Zombie Process Handling**
- Problem: Zombie processes blocked foreign process detection
- Fix: Check `/proc/$pid/stat` for 'Z' state and skip zombies, add `waitpid` reaping
- Files: `coding.handler.spawn_smart`, `coding.spawn_inference_server`

**3. Edit File Chunked Support**
- Added `batch_size` (default 25) and `continue` (offset) parameters
- Prevents JSON truncation on large edit sets
- Returns "[continue=N for more]" hint when more edits remain
- Files: `coding.tools.dispatch`

**4. NShell History Navigation**
- Fixed `arrow_up` off-by-one error in history index
- Added `current_history_index` reset after command execution
- Files: `nshell.input.arrow_up`, `nshell.cmd.execute`

**5. Git Tools Added**
- `git_restore_file`: Restore files from git with change detection
- `strip_trailing_spaces`: Remove trailing whitespace with permission handling
- `write_with_perms`: Helper for permission-aware file writes via chmod child

### Key Changes

**1. Jinja Template Sanitization**
- Problem: Model outputs `namespace(value=0)` triggered server errors
- Fix: Sanitize `{{`, `{%`, and `namespace(` patterns in:
  - Tool call arguments before storing
  - Tool result content before adding to context
  - Model responses before storing in history
- Files: `coding.handler.process-queued-task`

**2. Note Handler Fixes**
- Problem: `note.list` and `note.read` returned references-to-references
- Fix: Changed `\\@results` to `\@results`, `\\%sections` to `\%sections`
- Files: `note.list`, `note.read`

**3. File Module Namespace Fix**
- Problem: `file.*` modules existed but weren't loaded (overwritten by swap)
- Fix: Renamed to `base.file.*` to use swap mechanism properly
- Files: `file.basename`, `file.glob`, `file.path.make_dir`, `file.read`, `file.write`

**4. Loop Detection Improvements**
- Added forced stop after 3 consecutive loop warnings
- Reset counter when no loop detected
- Variable: `coding.loop_detect_count`

**5. Context Compaction**
- Truncate protected messages >8000 chars when still over threshold
- Prevents 114% CTX from accumulating large messages

**6. New Commands**
- `list-tools`: List available tools with descriptions
- `call-tool`: Direct tool execution
- `module-health-audit`: Comprehensive module analysis template

**7. Pagination Support**
- `read_file`: `offset` and `length` parameters
- `search_code`: `offset` parameter
- `ncode_search`: `offset` parameter

**8. Connection Error Handling**
- Increased retries: 2 → 5
- Detect "Connection refused" errors
- Use `event.once(2.0)` to yield for server restart

### Test Results
- Total Tools Tested: 50+
- Working: 41
- With Issues: 9
- Crashing: 0 ✅

---

## May 1 2026 Session — Regression, Revert, and nshell (0) Bug

### What Happened

Kimi was given an nshell debugging task. During the session it made a minor unrelated
fix but **introduced a regression** in `modules/base.log.send-buffer.send-idle-callback`:
it removed the cube-only guard on the `node.zenka + sid` push, causing **all non-cube
zenki to double-prepend the prefix** — p7-log received `node.zenka sid node.zenka sid ...`
and rejected it as a non-numeric log-level. Logging broke silently for all non-cube zenki.

Kimi then spent most of the session confused, debugging the symptom rather than the cause,
until it ran out of tokens (2% weekly credits left). It noted the intention to revert
before stopping but did not complete it.

### Claude Revert (commit `3b01d2e81`)

Claude reverted the regression: restored the `if ( $id == 1 )` / cube-only guard in
`send-idle-callback` and added a comment to prevent future regressions:

```perl
## only push node.zenka+sid prefix from cube (id==1) ##
## non-cube zenki: send buffer without node prefix   ##
if ( $id == 1 ) {
    $send_buf = "node.zenka $id\n$send_buf";
}
```

### nshell cmd_id (0) Bug — Pre-Existing, Not Kimi's Fault

During investigation, a pre-existing bug surfaced: the **first command in an nshell session**
gets `cmd_id = 0` instead of a positive integer. This causes cube to log `[0] unknown route`
for the reply. The bug was present before kimi's session and was not worsened.
**Not yet fixed** — it's a cmd_id assignment issue in nshell startup, not related to logging.

### Kimi Memory State After Session

Kimi's memory is **frozen mid-session** (during its own debugging loop). It does not yet
reflect the revert. When starting the next kimi session, inform it:
- The logging regression was reverted by Claude — `base.log.send-buffer.send-idle-callback`
  is correct now, do not touch that guard
- The nshell (0) bug is pre-existing and still open, but low priority
- Weekly credits are at ~2%, so task scope should be minimal this week

---

## NShell Ctrl+O Cycle Fixes (February 2025)

### Bugs Fixed

**1. Double-Shift Bug (CRITICAL)**
- **Issue**: `ctrl_o_start_position` was being incremented along with `ctrl_o_entries_added`
- **Effect**: Index calculation drifted, wrong history entries loaded
- **Fix**: Removed `$state_ref->{'ctrl_o_start_position'}++` - only track `entries_added`
- **Commit**: 684c7f64a

**2. Index Calculation Order (CRITICAL)**
- **Issue**: `next_index` calculated BEFORE `history_add()`, but used AFTER
- **Effect**: After history_add() shifts indices up by 1, next_index points to wrong entry
- **Fix**: Reorder code - calculate indices AFTER history_add() when shift is known
- **Code pattern**:
  ```perl
  # WRONG: Calculate before add
  my $next_index = calculate_index();  # Uses old shift
  history_add($cmd);                    # Shifts everything
  load_entry($next_index);              # Wrong index!

  # RIGHT: Calculate after add
  history_add($cmd);                    # Shifts everything
  my $shift = $state_ref->{'ctrl_o_entries_added'};
  my $next_index = $start_position + $shift;  # Correct with new shift
  load_entry($next_index);              # Correct index!
  ```
- **Commit**: Part of b2777cc0b

**3. State Reset When Editing History**
- **Issue**: When user edits a command from history, Ctrl+O cycle state wasn't reset
- **Effect**: Wrong indices on next Ctrl+O cycle
- **Fix**: Added `ctrl_o_start_position` and `ctrl_o_entries_added` reset to `nshell.state.reset_history`
- **Commit**: 684c7f64a

**4. Preloaded Entry Display**
- **Issue**: `display_preloaded_entry` flag set but never checked
- **Effect**: After Ctrl+O, next command loaded in buffer but not displayed (empty prompt)
- **Fix**: Check flag in `read_from_buffer` when showing cursor:
  ```perl
  if ($show_cursor_on_call) {
      if ($state_ref->{'display_preloaded_entry'}) {
          $state_ref->{'display_preloaded_entry'} = FALSE;
          print "\r\e[K" . $colors{'p7_fg_0004'}
              . $state_ref->{'editor'}->{'buffer'}
              . $colors{'p7_fg_0003'} . "_\e[0m";
      }
      ...
  }
  ```
- **Commit**: Part of b2777cc0b

### Key Implementation Details

**Ctrl+O Cycle Logic**:
- `ctrl_o_start_position`: Fixed anchor point where cycle started (never changes during cycle)
- `ctrl_o_entries_added`: Counter incrementing each time command added to history
- `$shift`: Applied dynamically = `ctrl_o_entries_added`
- `index_a = start_position + shift` (current command)
- `index_b = (start_position - 1) + shift` (previous command)
- Toggle between index_a and index_b based on current position

**Why This Works**:
- Each `history_add()` shifts ALL indices up by 1
- `start_position` stays constant (the original cycle start)
- `shift` compensates for entries added since cycle started
- Calculating after add ensures correct post-shift indices

---

## fork-child Critical Gotchas (Mar 2026)

### access.cmd.usr.child — keep cube. prefix (CRITICAL)
- `access.cmd.usr.child = cube.v7.notify_online cube.p7-log.append`
- ⚠️ do NOT strip the `cube.` prefix — `has_access` checks the command AFTER the
  `parent.` routing hop is consumed, not the full routed path
- child sends `parent.cube.v7.notify_online`; parent receives `cube.v7.notify_online`
- access list must match the post-hop form: `cube.v7.notify_online` ✅

### event.add_signal — hashref form only (CRITICAL)
- ❌ `<[event.add_signal]>->('CHLD', 'dev.null')` — positional args, silently wrong
- ✅ `<[event.add_signal]>->( { 'signal' => 'CHLD', 'handler' => 'dev.null' } )`

### protocol-7.route-send — when and when not to use
- Use for cube-routed zenka commands (`v7.*`, `httpd.*`, `p7-log.*`, `X-11.*`, etc.)
- route-send auto-prepends `<protocol-7.network.parent_route>` → correct for both
  root zenki (`['cube']`) and fork-child children (`['parent','cube']`)
- Do NOT use for `child.*` commands — local socketpair aliases, not cube-routed
  (route-send would produce `cube.child.*` which doesn't exist)
- Direct cube protocol commands (`whoami`, etc.) → stay `send.local` with literal `cube.`

---

## Project Workflow Rules (CRITICAL)

### Signature Updates Require User Passphrase
**NEVER use `SKIP_SIGNATURE_CHECK=1` or `SKIP_VERSION_CHECK=1`**

- Pre-commit hooks enforce signatures and version numbers for integrity
- Circumventing them violates project policy
- **Correct workflow**:
  1. Make code changes
  2. Run `./bin/dev/update-version` (updates version number)
  3. **Ask user to sign files** (requires passphrase)
  4. Commit normally WITHOUT override flags
  5. Pre-commit hook will pass with valid signatures

- **If signatures outdated**: Ask user: "Files need signatures updated. Can you run the signing command?"
- **User will**: Use passphrase to sign, then commit proceeds normally

### Version Management
- Version file: `configuration/protocol-7.src-ver`
- Format: `<AMOS-checksum>-<commit-count>.0`
- Update with: `./bin/dev/update-version`
- Commit count must match `git rev-list --count hub/base..HEAD`

### Pre-Commit Hook Checks
1. File permissions normalized
2. Version number matches commit count
3. All signatures valid and present
4. Source code integrity verified

**Respect these checks** - they protect repository integrity!

---

## No-TTY Debug Infrastructure (Enhanced February 2025)

### Extended Key Syntax
Module: `nshell.no-tty-debug.cmd.char-add`

**Key Mappings Added**:
- Navigation: `Up`, `Down`, `Left`, `Right`, `Home`, `End`, `PageUp`, `PageDown`
- Editing: `Backspace`, `Delete`, `Tab`, `Insert`
- Control: `Ctrl+a` through `Ctrl+z` (most common)
- Special: `Escape`, `Enter`, `Space`
- Function: `F1`, `F2`, `F3`, `F4`

**Dual Syntax Support**:
```
[Up,Down,Ctrl+o,Enter]   # Bracket syntax
:Up,Down,Ctrl+o,Enter:   # Colon syntax
```

### Debug State Tracking
- Buffer: `nshell-state-track` (12K max)
- Logs: Input events, mode changes, Ctrl+O state transitions
- Purpose: LLM-friendly debugging of complex state machines

### Commands Exposed
- `char-add <sequence>`: Inject key sequence into nshell input
- `debug-status`: Query current nshell state

## SSH Zenka Recovery (February 2025)

### Race Condition Fix: Auto-User-Creation

**Issue**: Multiple `register_*_deps` calls racing when creating system user during startup, causing duplicate "not in passwd" errors.

**Root Cause**: SSH zenka loads `ssh.set-up` and `set-up.json` before base module init (unusual pattern), triggering multiple `register_pm_deps`, `register_bin_deps`, `register_src_deps` calls before user exists.

**Fix Strategy**: Check if dependencies already registered before attempting user creation:

```perl
## early return if deps already registered [ prevents user creation race ] ##
if ( -d $mod_dir and scalar( glob("$mod_dir/*") ) > 2 ) {
    return TRUE;    ## already registered, skip user check ##
}
```

**Files Modified**:
- `modules/base.register_pm_deps`
- `modules/base.register_bin_deps`
- `modules/base.register_src_deps`
- `modules/base.load_modules` (add user auto-creation)
- `modules/base.check_dependency_dirs` (add user auto-creation)
- `modules/base.root.check_system_user` (auto-detect make_path for pre_init)

**Commit**: 6a2d76206

---

## Terminal Color Consistency (February 2025)

### Problem: White Text in keys.console.list

Unstyled text appeared white/default, breaking visual consistency of Protocol-7 color scheme.

**Solution**: Base teal color on ALL output first, then specific element coloring:

```perl
##  1. base teal on everything  ##
$key_list_string =~ s|^(.+)$|$C{T}$1|mg;

##  2. specific colors - always restore to teal after  ##
$key_list_string =~ s|  (\.)$|  $C{b}$C{0}$1$C{T}|mg;
```

**Key Principle**: Never use `$C{R}` (reset) mid-string - always restore to base color `$C{T}` to prevent white gaps.

**Color Assignments**:
- Key names: Teal (`$C{T}`)
- Extensions (.public/.private/.secret): Purple (`$C{0}`)
- Quotes, markers, colons: Purple
- Background: Dark (`$C{b}`)

**Files Modified**:
- `modules/keys.console.list`

**Commits**: d3747de61, 0cee4bd9c

---

## Research: Dynamic Harmonic Color Templates

**Document**: `data/md/design/CONCEPT-DYNAMIC-HARMONIC-COLOR-TEMPLATES.md`

**Vision**: Replace fragile regex-based coloring with template system using multi-buffer masks (retro video game approach):

1. **TEXT BUFFER**: Raw content for layout calculation
2. **TYPE BUFFER**: Semantic type IDs (key_name, extension, checksum)
3. **COLOR BUFFER**: Harmonic palette mapped from types
4. **OUTPUT**: Composited result

**Benefits**:
- No sprintf width issues (layout before colors)
- Semantic coloring ("key name" not "purple")
- Dynamic palette adaptation via ELF truth assertions
- Consistent across all tools

**Phases**:
- Phase 1: Forward templates with semantic registry
- Phase 2: Dynamic reverse template inference from data streams

---

## VTERM Buffer System (Mar 2 2026)

**Status**: Committed ✅ `B5DBE8DB1FD92B02F973FE855C7746E126B5FFB1`

**22 modules**: `vterm.*` namespace implementing 5-of-7 visual consensus rendering

**Core Architecture**:
- **Cell format**: 23-byte packed structure with sub-bit accumulators (-128..+127)
- **11-member consensus**: `-5..0..+5` with 0 as alternation router
- **5-of-7 threshold**: 5+ layers agree = sharp pixel; <5 = sub-visible interference
- **SHM backing**: Optional, auto-detects data zenka, falls back to local hash

**Key Modules**:
- `vterm.init_code` — constants, configuration, SHM auto-detection
- `vterm.cell` — 23-byte cell structure (pack/unpack/create)
- `vterm.subbit` — ±5 threshold voting, 0-state routing
- `vterm.consensus` — 5-of-7 consensus with superposition collapse
- `vterm.compositor` — blend modes (consensus/normal/additive) + forensic expansion
- `vterm.shm` — shared memory interface with data zenka integration
- `vterm.instance` — zenka-specific buffer lifecycle

**Extracted Helpers** (one-callable-one-file):
- `vterm.subbit.check_threshold`, `vterm.subbit.determine_route`
- `vterm.consensus.check_channel`, `declaration_value`, `interference_pattern`, `ghosts`
- `vterm.compositor.blend.consensus`, `normal`, `additive`
- `vterm.compositor.layout.grid`, `stack`, `diff`
- `vterm.util.clamp`, `vterm.shm.path`, `vterm.consensus.cell_fingerprint`

**Critical Bugs Fixed During Review**:
1. **BUG-3**: Cell size constant 16→23 bytes (pack format miscalculation)
2. **BUG-4**: Missing `->` on hashref access in instance.pm
3. **BUG-2**: Channel argument handling broken in subbit.vote
4. **BUG-1**: Sort on flattened hash (fixed to `values %hash`)

**Design Philosophy**:
- Generic namespace: any zenka can use vterm for multi-layer output
- Visual truth: disagreement literally creates blur/ghost trails
- Connection to stdout log: vterm is the visual evolution of the text buffer
- Forensic mode: split-view showing all 7 layers for debugging consensus

**Next Steps for Decoder Integration**:
- Connect 7 zulum streams to input layers
- Wire division-by-13 truth to sub-bit votes
- Add Term::VTerm Screen integration for actual terminal output
- Implement damage tracking and spiral sync optimization

## Data Directory Structure Reorganization (March 2026)

### Overview
Reorganized `data/yaml/` and `data/md/` directories to eliminate root clutter and establish clear categorization patterns. All loose files now have proper homes.

### Directory Structure Created

**data/yaml/:**
```
archive/
  build-logs/           # Build history files
  broken-symlinks/      # Moved broken symlinks (point to ../asc/...)
  completed-tasks-archive.yaml
  deferred-tasks/
  completed-fix-tasks/
  completed-coding-tasks/
build-instructions/     # Build configurations
code-reviews/           # Module review documents
code-style/             # CONVENTIONS.yaml, STYLE-AS-SYNTAX.yaml
coding-tasks/           # Active task definitions
docs/
  architecture/         # ARCHITECTURE-NOTES.md, DESIGN-PRINCIPLES.md
  formats/              # Signature format specs
  processing/           # Processing workflows
  workflows/            # Git, LLM, buffer workflows
docs/                   # PHASE-4-YAML-TOOL-CALLING.md, yaml-tool-calling-system.md
indexes/                # todos-index.yaml, workspace-transfer-index.yaml
meta/                   # (created for future metadata)
project-context/        # Session summaries and plans
research/               # fabric-reference, image-batch-processing, vision-models-registry
system/                 # Configuration templates, symlink-chains, templates
```

**data/md/:**
```
archive/
  completed-sessions/   # Session status/history
  completed-projects/   # Completed project docs
architecture/           # System architecture docs
concepts/               # CONCEPT-* files (moved from root)
data-zenka/             # Data zenka documentation
design/                 # VTERM, GFX toolkit specs
design-patterns/        # symlink-chains.md
development/            # Integration, coding docs
documentation/          # General documentation
guides/
  deployment/           # CUDA rebuild instructions
  testing/              # TOFU testing plan
investigation/
  yaml/                 # YAML gateway investigations
philosophy/             # Harmonic entropy, anti-entropic principles
protocol-7-knowledge/   # Structured knowledge base (00-09 topics)
research/               # holographic-topology-research, comprehensive-research
system/                 # CODING_TASK_KNOWLEDGE_BASE, MENU-CHECKLIST, SCENARIO-JOURNEY
vision/                 # VISION docs (complete, data-sync, timestamp)
  habitat/              # Context, nomadic, desktop UX
  infrastructure/       # Tool-use protocol, dev environment
  topology/             # Routes as signatures
```

### Key Moves Made

**From data/yaml/ root:**
- ARCHITECTURE-NOTES.md → docs/architecture/
- DESIGN-PRINCIPLES.md → docs/architecture/
- PHASE-4-YAML-TOOL-CALLING.md → docs/
- protocol-7-coding-style.md → docs/
- yaml-tool-calling-system.md → docs/
- SELF-IMPROVING-AGENT-ECOSYSTEM.md → docs/
- build-ik_llama_* → archive/build-logs/
- level-3-configuration-templates.yaml → system/
- symlink-chains.yaml → system/
- template-markup-syntax.yaml → system/
- zenki-creation-requirements.yaml → system/
- protocol-7-export-tasks-manager.yaml → system/
- workflow-suggestions.yaml → system/
- fabric-reference-architecture.yaml → research/
- image-batch-processing-architecture.yaml → research/
- vision-models-registry.yaml → research/
- completed-tasks-archive.yaml → archive/
- protocol-7-coding-style-refactoring-2025-12.yaml → code-style/

**From data/md/ root:**
- CONCEPT-*.md (7 files) → concepts/
- holographic-cubic-topology-research-2026-01-13.md → research/
- protocol7-comprehensive-research-feb2026.md → research/
- FABRIC-*.md (3 files) → research/
- GENERIC-DATA-SYNCHRONIZATION-FABRIC.md → research/
- INDEX-DATA-FABRIC-DOCUMENTATION.md → research/
- CODING_TASK_KNOWLEDGE_BASE_INDEXING.md → system/
- PROTOCOL-7-MENU-IMPLEMENTATION-CHECKLIST.md → system/
- SCENARIO-TRAIN-JOURNEY-ADAPTIVE-BUFFERING.md → system/
- VISION-*.md (3 files) → vision/

**Broken symlinks (all pointed to ../asc/... which doesn't exist):**
- harmonic-visualization-principles.md → archive/broken-symlinks/
- holistic-convergence-roadmap.md → archive/broken-symlinks/
- models-zenka-complete-architecture.md → archive/broken-symlinks/
- pattern-repository-and-authentic-agency.md → archive/broken-symlinks/
- protocol7-holistic-convergence-architecture.yaml → archive/broken-symlinks/
- the-receipts-efficiency-principle.md → archive/broken-symlinks/

**Cross-location move:**
- protocol7-math-topology-reference.yaml (was in md/) → yaml/research/

### Result
Both `data/yaml/` and `data/md/` root directories are now clean - no loose files. All content is categorized for easier navigation and maintenance.

## Coding Tasks Audit (March 3 2026)

### Overview
Comprehensive audit of `data/yaml/coding-tasks/` (30 files) cross-referenced with git commit history. Identified 6+ completed tasks still in active folder and significant consolidation opportunities.

### Key Findings

**Completed Tasks (Ready to Archive):**
1. **data-zenka-fuse-implementation.yaml** - ✅ Completed 2026-03-03 (commits 15e281462, 77522954d)
2. **next-session-httpsd-web-zenka-completion.yaml** - ✅ Mostly complete (commit 0975ecf98)
3. **fork-child-pattern-remaining** - ✅ Completed (commits 0c1f202ba, 1ffe1d2fa)
4. **route-send migration** - ✅ Completed (commit 523af79a3)
5. **kimi-web websocket** - ✅ Completed (commit 68af03d0a)
6. **vterm 22-module system** - ✅ Completed (commit b5dbe8db1)

**High Priority Active:**
1. **httpsd-daily-crash-investigation.yaml** - Production stability issue, crashes ~1/day
2. **models-dynamic-context-templates.yaml** - High value, all dependencies ready
3. **httpsd-fix-requirements.yaml** - Blocked on remote-model verification
4. **httpd-async-https-expansion.yaml** - Partially complete, needs route dispatcher
5. **phase-1-session-cleanup-nshell-debugging.yaml** - Blocks 6-phase roadmap

**Duplicates to Consolidate:**
- PRIORITIZED-TASKS-SESSION-2025-11-27.yaml
- PRIORITY-WEIGHTING-CORRECTED.yaml
- 3LE3NKOYM63SA.user-encountered-taks.yaml

### Recommended Next Actions
1. Archive 6+ completed task files
2. Start models-dynamic-context-templates (high value, ready)
3. Investigate httpsd daily crash
4. Begin Phase 1 session cleanup

### Reference Files
- Full audit: `data/yaml/CODING-TASKS-AUDIT-REPORT-2026-03-03.md`
- Updated index: `data/yaml/indexes/todos-index-UPDATED-2026-03-03.yaml`

---

## Dynamic Context Templates - Integration Complete (March 3 2026)

### What Was Built

**Foundation (Phases 1-3):**
1. web.cmd.render-template - Generic template renderer with budget support
2. Context providers: git.recent_changes, task.active, modules.list, file
3. System message templates: coding-assistant.tmpl, default.tmpl

**Integration (Phase 4):**
- Modified models.backend.kimi_web to render dynamic system messages
- System message rendered fresh for each request
- Includes: active task, recent git changes, relevant modules
- Budget: 2000 tokens (~8000 chars)
- Fallback: minimal message if render fails

### How It Works

```
User query → models.backend.kimi_web
    ↓
Render system message template
    ↓
Template executes context providers:
  - context.task.active → current task
  - context.git.recent_changes → git diff stat
  - context.modules.list → module list
    ↓
Prepend system message to conversation
    ↓
Send to kimi zenka with full context
```

### Testing

```bash
## Test template rendering directly ##
p7c web.render-template template_path=configuration/models/system-messages/coding-assistant.tmpl budget=2000

## Test context provider ##
p7c context.git.recent_changes budget=500

## Test kimi with dynamic context (via chat interface) ##
```

### Next Steps

1. Test end-to-end with kimi chat
2. Add context.history.recent provider
3. Implement budget allocation (system:history:current = 25:50:25)
4. Update models.backend.coding.invoke similarly

### Files Modified/Created

New modules:
- modules/web.cmd.render-template
- modules/context.git.recent_changes
- modules/context.task.active
- modules/context.modules.list
- modules/context.file

Modified:
- modules/models.backend.kimi_web (integrated system message rendering)

New templates:
- configuration/models/system-messages/coding-assistant.tmpl
- configuration/models/system-messages/default.tmpl

Documentation:
- data/md/documentation/DYNAMIC-CONTEXT-TEMPLATES-USAGE.md

---

## Coding Zenka Event Loop Stability (March 2025)

### The Return TRUE Bug (CRITICAL)

**Issue**: Style fix changed `return 1` to `return TRUE` in base.handler.auth
**Effect**: `TRUE` evaluates to non-zero (5 or string), triggering defensive disconnect (codes > 2 = unknown state)
**Root Cause**: Defensive coding treats return codes > 2 as errors, but `TRUE` constant != 1

**Fix**: Reverted to `return 1`, added explicit logging for return code anomalies

**Lesson**: Never change numeric return codes to boolean constants in protocol handlers. Document return code contracts explicitly.

### Blocking I/O Fix (CRITICAL)

**Issue**: base.s_read used blocking sysread, freezing event loop during auth
**Effect**: Authentication timeout never fired, heartbeats blocked, v7 restarted cube
**Chain**: Missing `blocking(0)` on Unix sockets + incomplete line handling + sysread blocking

**Fix**: Three-part solution
1. Add `$read_fh->blocking(0)` for Unix sockets (TCP already had it)
2. Fix incomplete line return code in base.handler.auth
3. Proper EAGAIN handling in base.s_read

**Commit**: 0C590DE229E2F3E2A6A61F710320464667A2654D, A28A159C6BC45D8096B7DFA51C9B2BD774C9E284

---

## Registry Consolidation (March 2025)

### JSON to YAML Migration

**Goal**: Unify model registry on YAML format, remove redundant JSON system

**Changes**:
- Deleted: `models.registry.load.load_registry`, `save.save_registry`, etc.
- Added: `models.resolve.entry` for shared model lookup
- Updated: All zenki use `<models.registry>` data path directly
- Format: Both commands now return YAML via `YAML::XS::Dump`

**Vision Model Support**:
- mmproj_path now included in registry entries
- Required for llama-server even for text-only inference on vision models

**Files**: See `data/md/coding-tasks/remove-redundant-json-registry.md`

---

## Multiline Command Protocol (March 2025)

### Specification for p7c/p-7-r

**Format**:
```
command+
Header: value

body content
more lines
.
```

**Suffixes**:
- `+` : Simple mode, terminates on `\n.\n`
- `++` : Dot-safe mode, caller space-prefixes each line, terminator is ` \n.\n`

**Status**: Task file created, implementation pending
- Task: `data/md/coding-tasks/add-multiline-command-support-to-clients.md`

---

## Zenki Profile Configuration (March 2025)

### Design Overview

**Subname → Profile Mapping**:
```
v7[minimal]    → start-set-up.minimal
v7[desktop]    → start-set-up.DESKTOP-FP4OP26
v7[setup]      → first-run wizard
```

**Resolution Cascade**:
1. `start-set-up.<hostname>` (normal operation)
2. `start-set-up.local` (manual override)
3. `start-set-up.setup` (first-run)
4. `start-set-up.base` (fallback)

**UI Design**: Color-as-feedback living options table (see amos-chksum -options style)

**Task**: `data/md/coding-tasks/zenki-profile-configuration-interface.md`

---

## Task Execution Quality Patterns (March 2025)

### What Works Well

**1. Structured Context Preparation**
- `MEMORY.md` as index → `coding-style.md` for conventions → `HANDOVER.md` for architecture
- This creates progressive disclosure: overview → details → current state
- Result: fewer syntax errors, better pattern adherence

**2. Explicit File Reading Order**
When a task specifies files to read in order, it creates mental model before implementation:
```
1. MEMORY.md — understand my own history
2. coding-style.md — syntax constraints
3. HANDOVER.md — architecture context
4. next-steps-plan.md — specific requirements
5. existing modules — patterns to follow
```

**3. Handler Chain Pattern for Async Flows**
- `v7.notify_online` returns send count, not result
- Must use reply handler chain: `caller → notify_online → handler → next_step`
- Each handler validates result, either continues flow or falls back
- Key: handler receives `{ data, mode, params }` from original call

**4. Module Decomposition Strategy**
- Split complex flows into single-purpose modules:
  - `*_bridge` — entry point / coordination
  - `handler.*-reply` — async reply processing
  - `do_*` — actual work after preconditions met
  - `fallback-*` — extracted fallback logic
- Benefits: testable, reusable, clear failure points

**5. Todo List as State Machine**
Using SetTodoList to track progress:
- Creates clear checkpoints
- Allows parallel work streams
- Easy to resume if interrupted
- Good for reporting status

### Red Flags to Avoid

**1. Assuming Synchronous Returns**
- `protocol-7.route-send` returns send count (0/1), never reply data
- Always check if command is async before interpreting return value
- When in doubt: read the command module's source

**2. Inline Fallback Logic**
- Duplicating dispatch code in multiple places
- Better: extract `fallback-*` module, call from multiple handlers
- Keeps handlers focused on flow control, not implementation

**3. Missing Reset of Active State**
When falling back after partial progress:
```perl
## reset before fallback ##
<models.task.active_id>  = $task_id;
<models.task.active_job> = $job_id;
```
Otherwise downstream code sees wrong state.

---

## amos-term Window Management Fixes (March 2026)

### Hash Dereference Syntax Compatibility

**Issue**: Perl's `//=` operator doesn't work with typeglobs (`<var>`)
```perl
# INVALID - causes compilation error:
<amos-term.windows.by_amos> //= {};

# VALID - use hash reference syntax:
my $by_amos = <amos-term.windows.by_amos> // {};
my @windows = keys %$by_amos;
```

### Command Return Format

**Valid modes for `*.cmd.*` modules**:
- `'true'` - Success with data
- `'false'` - Error with message
- `'size'` - Data with size prefix (for multi-line replies)
- `'deferred'` - Async operation, reply via handler chain

**Invalid modes**:
- `'immediate'` - NOT a valid mode (causes protocol errors)

### Handle Mode Initialization for Pipe Sessions

When creating sessions with pipes (not sockets), set handle mode BEFORE `base.session.init`:

```perl
## set handle mode BEFORE session init (required by init_state) ##
$data{'handle'}{$reader}{'mode'} = qw| internal |;

my $session_id = <[base.session.init]>->(
    $reader,      qw| amos-term |,
    qw| client |, $client_name
);
```

Without this, `base.session.init_state` fails with "handle mode not defined".

### Argument Parsing in *.cmd.* Modules

**CRITICAL**: In `*.cmd.*` modules, `shift` gives you `$call`, NOT the arguments:

```perl
# WRONG - shift gives $call hashref:
my $amos_id = shift;  # Actually gets { args => "...", session_id => ... }

# RIGHT - use $call->{'args'}:
my $amos_id = $call->{'args'};
$amos_id =~ s/^\s+|\s+$//g;  # trim whitespace
```

### WARNING: 'deferred' Mode Can Appear Blocking

**Issue**: `{ 'mode' => 'deferred' }` appears to hang when async activity stalls

**Why**: Deferred mode tells Protocol-7 that a reply handler will send the response later. If that handler:
- Never gets called
- Crashes silently
- Returns without sending reply
- Has a routing error

The client sees an indefinite timeout (appears blocking).

**Debugging**:
```bash
# Check if handler was registered:
p7c zenka.show-buffer amos-term  # Check logs for handler errors

# Test with 'true'/'size' mode first:
return { 'mode' => 'true', 'data' => 'test' };  # If this works, routing is OK

# Then convert to deferred once flow verified
```

**Best Practice**: Always implement the reply handler and error path BEFORE using deferred mode.

### Access Configuration for Zenka Commands

**Three layers of access control**:

1. **Zenka's own start file** (`access.cmd.usr.cube`) - Exposes commands generically
2. **cube/access.zenki** - Routes commands between zenki (needs `zenka.command-name` prefix)
3. **Per-command SID prefix** - Rarely needed, configured in `command_aliases`

**Example - Routing amos-term commands**:
```
# In configuration/zenki/amos-term/start:
access.cmd.usr.cube = window-create window-open list-windows

# In configuration/zenki/cube/access.zenki:
access.cmd.usr.amos-term = amos-term.window-create amos-term.window-open amos-term.list-windows
```

### Authentication for Zenka-to-Zenka Commands

To test commands as specific user:
```bash
# Add unix auth support for the zenka user in cube/auth.zenki:
auth.setup.usr.amos-term = :zenka:,:unix:<unix-AMOS-user>,:unix:<unix-admin>

# Reload and test:
p7c reload
p7c amos-term.list-windows
```

---

## Coding Zenka Massive Cleanup — March 30 2026

### Inline Sub Extraction Complete

**Scope**: pager.*, plugin.storage.*, context.* namespaces — 45+ inline subs extracted to .util.* modules.

**Key commits**:
- `50d6a8a4a` — Removed 12 remaining pager inline subs, created 4 missing util modules (load_page_items, apply_filters, apply_sort, update_lru). **Zero inline subs remain in pager.* namespace.**
- `40c9d0ec5` — Extracted 18 inline subs, fixed compilation errors, removed 5 .disabled modules.
- `f4b3da34c` — Modernized pager namespace: unwrapped return sub declarations, fixed headers, renamed commands.
- `f300f68f7` — Extracted 6 inline subs from plugin.storage.visual.proximity-calc.
- `c0f31ed72` — Extracted context.* inline subs, hardened coding zenka paths and security.

**Pattern established**: `extract-inline-subs` template refined through 8+ autonomous tasks. Handles:
- Return sub unwrap (`sub { return sub { ... } }` → flat sub)
- One-call-per-round discipline
- `task_complete` signal for clean loop exit
- Known pitfalls documented

### Tree Tools Layer 1

**Commit**: `42d44704a`

Exposed `%data` namespace to coding zenka inference model and interactive P7 commands:
- `coding.tools.handler.tree_read` / `coding.cmd.tree-read`
- `coding.tools.handler.tree_write` / `coding.cmd.tree-write`
- `coding.tools.handler.tree_list` / `coding.cmd.tree-list`

Wraps existing `base.resolve_key` / `base.set_key` / `data.*` infrastructure.

**Fixes**:
- `5decf1906` — `tree_list` uses `base.resolve_key` instead of broken `data.resolve_hash_path`
- `e74d30053` — Fixed undef warning in `tree_read` array/hash preview slice
- `e0ea93b56` — Improved error resilience in `tree_read`

### Event Loop Hardening

**Commit**: `4e9b5dfda`

Added explicit stop signals to prevent infinite inference loops:
- `task_complete` — clean success exit
- `escalate` — human handover exit

`coding.handler.process-queued-task` resets and checks the stop flag each tool round.

**Additional hardening**:
- `e3e763a0b` — Retry on timeout/5xx errors in inference loop
- `30ca7a286` / `49829741b` — Refined "working" log message style
- `0bcfa4668` — Fixed storage module loading, log truncation, spawn race, log levels

### Passive Observation Collection

**Commit**: `4e9b5dfda`

- `record_question` / `record_suggestion` — off-band observation tools
- Append to `observations/questions.jsonl` and `suggestions.jsonl` via zenka_dir
- Observations directory created at init alongside other zenka paths

**Commit**: `48bba2967`

- `observations-triage` template — processes accumulated JSONL, dismisses invalid items, acts on clear ones, escalates uncertain items
- `post-task-verify` template — quality gate after code-editing tasks (syntax, `$ARG` regressions, module format, style, reference integrity)

### Autonomous Task Templates Added

**March 30 batch** (commits `42d44704a`, `dc50af1b2`, `927dd0d18`, `090d77f4f`, `5f91d5f9d`, `931cd871b`, `99ba2c161`, `48bba2967`, `ca1925fc1`):
- `namespace-audit` — scan namespace for style/structure issues
- `sub-task-decompose` — break large tasks into extractable chunks
- `tree-explore` — navigate %data tree for investigation
- `review-and-improve` — self-review cycle
- `autonomous-direction` — project intelligence and task triage
- `integrate-recent` — incorporate recent changes
- `p7-style-enforce` — style correction pass
- `header-tags-fix` — fix missing descr/param tags
- `fix-format-issues` — formatting cleanup
- `git-diff-review` — review diff before commit
- `regex-style-fix` — regex pattern corrections
- `param-validation-fix` — argument validation improvements
- `error-resilience` — defensive coding additions
- `cross-namespace-wiring` — inter-namespace call fixes
- `observations-triage` — process observation stash
- `post-task-verify` — post-task quality gate

**Template refinements**:
- `ca1925fc1` — Added round budget hints to autonomous task templates
- `99ba2c161` — Added `$ARG` preservation reminder to 12 code-editing templates + system-review
- `3e65f857c` — Refined extraction template: return sub unwrap, one-call-per-round, `task_complete`

### NShell History Fix

**Commit**: `496e91f34`

Repaired off-by-one history navigation bug in `nshell.history.arrow_up`.

### Plugin Init Order Fix

**Commits**: `952cbe3b9`, `d75743f99`

- Fixed plugin initialization order: `load_plugins` before `init_modules`
- Storage plugins now loaded via `load_plugins` in coding zenka start

### Verbosity Reset

Coding zenka verbosity reset from 3 (debug) back to 2 in `configuration/zenki/coding/start`.

---

## Context Template System (April 2026)

**Location**: `data/yaml/context-templates/` (63 templates)
**Used by**: coding zenka (via `coding.cmd.ask` with `template=` parameter)
**Future**: kimi-web zenka will also resolve these via MCP

### Template Architecture

Templates are YAML files defining composable system prompts with:
- **Budget allocation** (`budget_pct`) per section
- **Priority ordering** for resolution when constrained
- **Conditional inclusion** (`when: task_type=debug`, `when: has_tools`)
- **Variable substitution** (`{{target_module}}`, `{{description}}`)
- **Provider pattern** for live data (`context.git.recent_changes`)
- **Post-task hooks** (`on_complete: memory_update`)

### Key Templates for Sub-Agent Offloading

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

### Template Composition Example

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

### Coding Zenka Usage

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

### Forthcoming: Kimi-Web Integration

**Vision**: Parent kimi process (me) spawns kimi-web sub-agents via P7:
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

### Critical Template Features

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

### Files to Know

- `data/yaml/context-templates/system-default.yaml` - Base composable template
- `data/yaml/context-templates/system-review.yaml` - Review checklist (P7 patterns)
- `data/yaml/context-templates/system-tools.yaml` - Tool usage docs
- `modules/context.template.resolve` - Template resolution engine
- `modules/coding.cmd.ask` - Main interface for template queries

---

## Zenka Creation Guide (April 2026)

**Template**: `data/yaml/context-templates/zenki-create.yaml`

Based on successful implementation of kimi-web zenka, this guide covers
creating new protocol-7 zenki with proper structure.

### Zenka Types

| Type | Characteristics | Examples |
|------|-----------------|----------|
| **Standard** | Background service, no console | coding, models, data, storage |
| **Console** | Interactive terminal | amos-term, nshell |
| **Child-bearing** | Spawns sub-processes/zenki | v7, kimi-web |
| **Hybrid** | Multiple characteristics | coding (service + inference) |

### Critical Implementation Rules

1. **Never `my $call = shift` in *.cmd.* modules**
   - $call is pre-declared by dispatcher
   - Use: `my $args = $call->{'args'} // {}`

2. **Auth wiring is mandatory**
   ```
   # configuration/zenki/cube/auth.zenki:
   auth.setup.usr.<zenka-name> = :zenka:
   ```
   Missing this causes: "user not accepted for auth type :zenka:"

3. **Don't load self in modules.load**
   ```
   # WRONG:
   modules.load = auth net ... <zenka-name>

   # RIGHT:
   modules.load = auth net ...  # <zenka-name> auto-loaded
   ```

4. **Return format for cmd modules**
   ```perl
   return { 'mode' => qw| true |, 'data' => $result };
   # NOT: return { mode => TRUE, ... }
   ```

5. **$ARG/@ARG preservation**
   - ALWAYS use English.pm aliases
   - NEVER use `$_` or `@_`

### File Structure

```
modules/<zenka-name>.init_code                    # required
modules/<zenka-name>.cmd.<command>                 # exposed commands
modules/<zenka-name>.handler.<event>               # event handlers
modules/<zenka-name>.internal.<helper>             # utilities

configuration/zenki/<zenka-name>/
├── start                                          # main config
├── zenka-startup.v7                               # v7 integration
├── pm-dep/                                        # perl deps
└── source/                                        # source tracking

cube/access.zenki: access.cmd.usr.<name> = <commands>
cube/auth.zenki:   auth.setup.usr.<name> = :zenka:
```

### Child-Bearing Zenki Specifics

From kimi-web implementation:
- Call `<[v7.register_child_zenka]>->(qw| <name> |)` in init_code
- Track child PIDs in registry hash: `<zenka-name>.agent.registry`
- Use `event.add_timer` for health checks
- Implement graceful shutdown with context preservation

### Console Zenki Specifics

- Use AMOS7::TERM patterns for input handling
- Handle terminal state (raw mode, echo)
- Restore terminal on exit
- Consider SHM buffer for output

### Testing Checklist

```bash
# 1. Syntax check
./bin/ptd modules/<zenka-name>.*

# 2. Start zenka
p7c v7.start <zenka-name>

# 3. Test command
p7c <zenka-name>.commands

# 4. Check logs if failure
p7c show-buffer <zenka-name>
```

### Common Error Messages

| Error | Cause | Fix |
|-------|-------|-----|
| "my variable $call masks earlier declaration" | `my $call = shift` in cmd | Remove `my $call = shift` |
| "file.zenka_dir.make_path not defined" | Using non-existent function | Use `file.make_path` or create on-demand |
| "user not accepted for auth type :zenka:" | Missing auth.zenki entry | Add `auth.setup.usr.<name>` |
| "no match /modules/<zenka-name>" | Loading self in modules.load | Remove from modules.load |

### Template Usage

```bash
# Use the zenka creation template
p7c coding.ask template=zenki-create zenka_name=my-zenka zenka_type=standard
```

---

## Footer Cleanup Template (April 2026)

**Template**: `data/yaml/context-templates/footer-cleanup.yaml`

Cleans up signature blocks and file footers after edits.

### Use Cases

- Duplicate signatures after merge conflicts
- Partial/mangled signature fragments
- Wrong file type signatures
- subroutine.white-list stale entries

### Patterns Handled

| Issue | Detection | Fix |
|-------|-----------|-----|
| Duplicate sigs | Multiple `#,,,.,,` blocks | Keep last, remove others |
| Fragments | Truncated `#\\\|` or `#\[7]` | Remove, regenerate |
| Wrong format | Check file extension | Apply correct format |
| White-list stale | Module doesn't exist | Remove entry |

### Workflow

```bash
# 1. Run cleanup template
p7c coding.ask template=footer-cleanup

# 2. Sign files (user action with passphrase)
./bin/dev/sign-files <paths>

# 3. Verify
./bin/ptd -verify <files>
```

### Future: coding.tools Expansion

Potential tools to add for reliable footer cleanup:
- `coding.tools.handler.check_signatures` - Verify all file signatures
- `coding.tools.handler.find_duplicate_sigs` - Detect duplicate blocks
- `coding.tools.handler.white_list_cleanup` - Remove stale entries

### Note: Existing Protection

`modules/source.extract_sig_body` already has PLACEHOLDER detection:
- Line 69-73: Strips PLACEHOLDER stub footers before processing
- Line 111-114: Skips PLACEHOLDER during signature matching

The regex pattern handles edge cases:
```perl
\n?#[\.,]{70,85}\n(?:#[^\n]*PLACEHOLDER[^\n]*\n)+#[:]{70,80}\n?
```

Files cleaned in this session were created before this protection was in place.

---

## Zenki Routing Analysis (April 2026)

### Kimi vs Coding: Architecture Comparison

| Aspect | Kimi Zenka | Coding Zenka |
|--------|------------|--------------|
| **Connection** | WebSocket to external service | Task queue + inference |
| **Routing** | Direct: prompt → wire → ws | Pipeline: intake → analyze → route → enqueue |
| **State** | Connection-based (ready/busy/disconnected) | Task-based (queued/running/complete) |
| **Deferred** | Simple reply tracking | Complex with meta-jobs |
| **Templates** | ✅ Dynamic system messages | ✅ Dynamic system messages |
| **Base32r** | ✅ Encoded prompts | ✅ Encoded prompts |
| **Task Queue** | ❌ None | ✅ Full queue system |
| **Budget Tracking** | ❌ None | ✅ Per-task budgets |
| **Tool Calling** | ❌ None | ✅ Full framework |
| **Session Mgmt** | ✅ Persistent sessions | ❌ Task-scoped |
| **:next: prefix** | ✅ Fresh session trigger | ❌ N/A |

### Routing Flow Comparison

**Kimi (Simple):**
```
ask-reply → wire.prompt → websocket → handler.ws_message → reply
```

**Coding (Complex):**
```
ask-reply → task.intake → task.analyze → routing.decide → 
  task.enqueue → process-queued-task → inference → reply
```

### Features to Port

**From Coding → Kimi:**
- Task queue (for request batching)
- Budget tracking (per-session limits)
- Tool calling framework (if kimi supports it)

**From Kimi → Coding:**
- :next: prefix (force fresh context)
- Session persistence patterns
- Connection state management

### Unified Interface Goal

Both should support:
```bash
# Direct prompt (kimi: websocket, coding: task queue)
p7c <zenka>.ask-reply "prompt"

# With template
p7c <zenka>.ask-reply template=code-review target_module=X

# Force fresh context
p7c <zenka>.ask-reply :next: "fresh prompt"

# Check status
p7c <zenka>.status
```

---

## Kimi + Kimi-Web Integration (April 2026)

**kimi** zenka: Connects to external kimi-web service via HTTP/WebSocket  
**kimi-web** zenka: Spawns local kimi-cli web processes as sub-agents

### Integration Architecture

```
kimi.connect → kimi.handler.pre_connect → [if local mode enabled]
                                                    ↓
                                      kimi-web.bridge.ensure_local_agent
                                                    ↓
                              Check for ready agent → Spawn if needed
                                                    ↓
                              Return agent port/url → kimi connects locally
```

### Configuration

**configuration/zenki/kimi/start:**
```
## local agent mode [ uses kimi-web zenka to spawn local agents ]
kimi.cfg.use_local_agent = 1        ## enable local mode
kimi.cfg.work_dir = /path/to/work   ## default: <system.root_path>
kimi.cfg.local_template = code-review  ## context template for agents

## admin group for spawned agent file access
kimi.cfg.assume_admin_group = 1     ## use project admin group
```

### User/Group Handling

Following coding zenka pattern:
- Spawns run as `<system.amos-zenka-user>` (protocol-7)
- Admin group auto-detected from `<system.root_path>` gid
- Enables spawned agents to access project files

### Flow

1. **kimi.connect** triggers **kimi.handler.pre_connect**
2. Pre-connect checks if local mode enabled
3. If enabled, calls **kimi-web.bridge.ensure_local_agent**
4. Bridge checks kimi-web registry for ready agents
5. If none found, spawns new agent via **kimi-web.spawn_agent**
6. Waits for agent to become ready (health check)
7. kimi temporarily overrides base_url/ws_base to local agent
8. Standard websocket connection proceeds

### Fallback

If local agent spawn fails:
- Logs warning
- Falls back to configured remote kimi-web endpoint
- Existing session logic unchanged

### Commands

```bash
## Check if local agent mode is active
p7c kimi.get use_local_agent

## Switch to local mode
p7c kimi.set use_local_agent 1

## Force new local agent spawn
p7c kimi-web.spawn_agent template=code-review

## List active local agents
p7c kimi-web.list_agents
```

---

## 2026-04-02 — Bug #5 Fixed: Empty Task Result

**Issue**: Tasks completed with `result_len=0` despite correct output in buffer.

**Root cause**: `coding.async.complete_task` used `//` (defined-or):
```perl
# BUG: response_text = '' (defined), so returns '' not final_content
result => $state->{'response_text'} // $state->{'final_content'} // ...
```

**Fix**: Use `||` (logical or) for proper empty-string handling:
```perl
my $result_text = $state->{'final_content'}
    || $state->{'content'}
    || $state->{'response_text'}
    || '';
```

**Lesson**: `//` checks definedness, `||` checks truthiness. For string fields
that may be empty, use `||` for fallback chains.

**Status**: All 5 async bugs now fixed. Tool loop working end-to-end.

---

## Algorithm Profile System — April 2026

### Design Pattern: Profiles as Modules, Not Data

For configurable algorithm variants in P7, the elegant approach is:
- **Category modules** on disk (e.g., `base.chk-sum.profile.harmonic-slide`)
- Each returns a hashref with defaults + optional preset merge from `%data`
- **Generic wrapper** (`base.chk-sum.profile.calc`) handles input normalization,
  profile resolution, and dispatch
- **Presets stored as deltas** in `%data` — category module merges them with
  default hash before returning

This is superior to dynamic code generation (`perlmod.load` of generated strings)
because it uses existing infrastructure (files, `swap_subs`, git tracking,
AMOS signatures) and is debuggable.

### Syntax Conventions

```perl
# default category
<[chk-sum.profile.harmonic-slide]>->();

# with preset id (delta merged from %data)
<[chk-sum.profile.harmonic-slide]>->('X7K9');

# direct calc with string profile id
<[chk-sum.profile.calc]>->("harmonic-slide.X7K9", $input);

# store a deviation preset
$data{'chk-sum'}{'profile'}{'harmonic-slide'}{'X7K9'} = {
    length => 7,
};
```

### White-List Registration for Dynamic Namespaces

Dynamic dispatch via `$code{$mod}` is invisible to `dep-graph` static analysis.
Two solutions:

1. **dep-graph rule** (`configuration/dep-graph/rules/*.rules`):
   ```
   chk-sum.profile.calc : mod ~ /chk-sum\.profile/ -> chk-sum.profile.*
   ```

2. **`base.white-list.register`** (preferred hybrid):
   - Call in zenka start file: `[base.white-list.register:'base.chk-sum.profile']`
   - `dep-graph` parses this and eagerly includes all matching modules in whitelist
   - Runtime: verifies files exist, reports missing ones
   - Generic pattern reusable for any dynamic namespace

### Critical Syntax Pitfalls

**`$call` is ONLY predefined for `*.cmd.*` modules**
- Regular modules (including `base.white-list.register`) use `@ARG` / `shift`
- Using `$call` in non-cmd modules causes compilation error

**`//= {}` on data access can break compilation**
- `<data.path> //= {}` looks like typeglob assignment to Perl parser
- Use explicit hashref: `my $ref = <data.path> // {}` or `$data{'key'} //= {}`
- Even `ptd -c` may pass while actual P7 compilation fails

**Dynamic module dispatch syntax**
- `<[$mod]>->(...)` does NOT work — `<[...]>` is static key lookup
- Correct: `$code{$mod}->(...)` with `$mod` as computed string

**No-arg calls: `->()` is implicit**
```perl
<[base.exit]>        ## correct — implicit ->()
<[base.exit]>->()    ## redundant but valid
```
The P7 parser automatically adds `->()` when omitted. This keeps no-arg
calls clean and concise.

### dep-graph Rule Format

```
module_glob : var_name ~ /context_pattern/ -> resolution_template
```

- `module_glob`: `*` for any, or specific module name
- `var_name`: variable used in `$code{$var}`
- `context_pattern`: regex on ±15 lines around dispatch site
- `resolution_template`: `prefix.*` for wildcard (adds all matching graph nodes)

### Files Created/Modified

| file | purpose |
|------|---------|
| `modules/base.chk-sum.profile.calc` | generic checksum wrapper |
| `modules/base.chk-sum.profile.harmonic-slide` | spatial coordinate category |
| `modules/base.chk-sum.profile.gen-path` | path generation category |
| `modules/base.chk-sum.profile.pre_init` | swap_subs |
| `modules/base.white-list.register` | whitelist + runtime verification |
| `bin/dev/dep-graph` | parse white-list.register in start files |

## Async Round-2+ Timeout Bug (2026-04-29)

**Status**: OPEN — server-side hang, not client-side.

**Pattern**: Round 0 works, Round 1 works, Round 2+ hangs every time. Server processes request (GPU active briefly) then stops, but never sends HTTP response headers. Client times out after 780s.

**Critical finding**: Bug occurs with `coding.jinja.convert_tool_role = yes` AND `= no`. Also occurs with ALL `tool_calls` stripped from assistant messages. This rules out jinja template issues.

**Client fixes applied**:
- `stream` boolean: `JSON::PP::true()` ✅
- EOF buffer: `length()` instead of `bytes::length()` ✅
- Backend lock leak: release in `coding.async.complete` before state delete ✅
- HTTP client race: register I/O watcher BEFORE writing request ✅
- State init before lock check: fixes `messages=0` on deferral ✅
- Tool role conversion + tool_calls stripping ✅
- Loop detection threshold: 5→3 ✅

**Suspected root cause**: llama-server-side. Possible KV cache limit (startup reports `calc=6701 clamped=7777 [minimum]`) or model-specific bug with multi-turn history. Request at round 2 has ~4700 context + 7777 max_tokens = ~12455 total.

**Key log signature**:
```
async.request: http_client returned success for task-XXX
[780s silence]
async.http_timeout: request timed out after 780 seconds
```

The `200 : streaming started` log is **present** for working rounds, **absent** for hanging rounds.

**File**: `data/ai-mem/claude/topic-async-round-2-timeout.md` (handover for Claude)

## Session 2026-05-05 — UTF-8 Encoding, Git Diff Tools, Timeouts, Crash Restart Fixes

### UTF-8 Encoding Support for File Tools

Added optional `encoding` parameter to all file write/edit tools:
- `write_new_file` — fixed corrupted file (trailing garbage, broken regexes `\.\w+\.` and `\.\./`)
- `write_append` — added full encoding support + chmod_child `gw` for existing files
- `edit_file` — already had encoding, verified working
- `replace_in_file` — already had encoding, verified working
- `base.file.append` — added optional encoding as last argument (popped from `@file_content` if matches `^:(raw|bytes|encoding\([^\)]+\))$`)
- `coding.parser.normalize_encoding` — fixed hardcoded `Encode::find_encoding("euc-cn")` -> `Encode::find_encoding($enc_name)`
- `coding.tools.definitions` — added `encoding` to `write_new_file` and `write_append` schemas

### Line Numbers in `read_file`

- `coding.tools.handler.read_file` — added `show_line_numbers` parameter (default `true`)
- `modules/context.file` — added `show_line_numbers` support, prepends `sprintf "%5d\t%s"` before markdown backticks
- `coding.tools.definitions` — added `show_line_numbers` boolean to `read_file` schema

### Git Diff Tools

Created proper AI-callable tools using `Git::Wrapper`:
- `coding.tools.handler.git_diff_output` — core routine, runs `git diff` or `git diff --cached` via `Git::Wrapper`
- `coding.tools.handler.git_diff_staged` — tool handler for `git diff --cached`
- `coding.tools.handler.git_diff_unstaged` — tool handler for `git diff`
- `coding.tools.definitions` — registered both tools with `git_args` and `max_lines` parameters

### Cleanup of Confused Namespace Routines

Deleted non-conforming/orphaned files:
- `coding.cmd.unstaged-diff`, `coding.cmd.git-diff-staged`, `coding.cmd.git-diff-unstaged`
- `coding.cmd.recent-changes`, `coding.cmd.recent-changes-staged`, `coding.cmd.recent-changes-unstaged`
- `coding.tools.handler.recent_changes_cached`, `coding.tools.handler.recent_changes_unstaged`
- `coding.tools.handler.git_diff_output` (empty), `git_diff_staged`, `git_diff_unstaged` (recreated properly)

Kept legitimate `coding.cmd.staged-diff` (internal staging diff command).

### Inference Crash Restart — Task Resume Fix

`coding.handler.verify_inference_startup` was only resetting `restart_count` when server came back up, but NOT calling `jobqueue.check_dependencies`. If the dependency callback (`coding.callback.object_inference_server`) found the HTTP health endpoint not yet responding when `monitor_inference_startup` first triggered, jobs stayed blocked forever.

**Fix**: Added `<[jobqueue.check_dependencies]>;` to `verify_inference_startup` ready-path. Also removed unnecessary `exists $code{...}` guards from both `monitor_inference_startup` and `verify_inference_startup` (jobqueue is reliably loaded).

### Data-Start Timeout for Inference Streaming

Added two-tier timeout system:
- `coding.http-timeouts.data-start = 47` — fires if server accepts connection but no streaming chunks arrive within 47s (catches GPU-stall-before-first-token)
- `coding.http-timeouts.request-completed = 777` — total request timeout (existing)

**New handler**: `coding.handler.http_data_start_timeout`
- Cancels itself on first chunk via `coding.handler.http_io_parse_line`
- Cleaned up by `coding.async.http_cleanup`
- Set up alongside total timeout in `coding.async.http_client`

### Commits

- `bb1a60bfa` — UTF-8, line numbers, git diff tools, namespace cleanup
- `9d81d4f83` — data-start timeout, verify_inference_startup dependency recheck

#,,,,,,,,,,,.,,,.,...,...,.,.,,.,,,,.,...,...,.,.,...,...,...,,..,,..,...,,.,,
#JDYN7OJXYEUVOGIS2SOEE76DRWU5AC3PG7A5BHEPQE3HUHMSSQUFYCLIR4ZY2DMU4ZMMJC46FSVXQ
#\\\|LWKLZOZCVU6NQ3IYKFY4MZ3ZLACSSB4QGHYFLOYBOUH4MFO2CT5 \ / AMOS7 \ YOURUM ::
#\[7]57J4K6DXWDL2447NTHZD56WX5PMK4DVJSRPMMNVCS4EKI3QJTKDI 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
