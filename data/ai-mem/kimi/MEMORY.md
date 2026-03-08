# Kimi Development Memory - Protocol-7

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

#,,,,,.,,,,,.,,,.,,.,,,,,,,,,,...,.,.,.,,,,,,,..,,...,...,.,.,...,.,.,..,,,.,,
#RQWQJ5U4MQXLEQ2FV7Y4SJPIADP2BVABGCDQMPC4I2IZMB7YHEPZYGYBWAKYFWZWD5N3ZQMNJ3DRY
#\\\|AGYZRP2J2E5D5VDMBQZE42ZY2CAUTILC74OYVQNO7F5BGMREI56 \ / AMOS7 \ YOURUM ::
#\[7]5RTDDU3ULQ5AOOQSK5XXBKHXJ475FJOVJCHRZA6WXAM3Q77UPSAQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
