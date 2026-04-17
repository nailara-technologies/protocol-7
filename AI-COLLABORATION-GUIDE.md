# AI Collaboration Guide - Protocol-7

Quick-start guide for AI assistants (especially Kimi) working on Protocol-7.

## Project Overview

Protocol-7 is a **multi-agent system** (zenki) built in Perl with:
- Asynchronous event-driven architecture (EV loop)
- Custom module loading (`modules/` → `%code` hash)
- AMOS7 cryptographic checksums and truth assertions
- Network-based inter-agent communication via `cube` router

**Key Philosophy**: Holographic truth through harmonic checksums, modular zenki, and filesystem-driven configuration.

## Essential File Locations

### Documentation (Read These First!)
- **`CLAUDE.md`** - Primary codebase instructions, architecture overview, module system
- **`data/md/development/CODE-STYLE-AND-LLM-INTEGRATION.md`** - Code style guide
- **`data/yaml/code-style/CONVENTIONS.yaml`** - Quick style reference
- **`ai-mem/claude/MEMORY.md`** - Claude's session memory (solved issues, patterns, architecture decisions)
- **`ai-mem/kimi/MEMORY.md`** - Kimi's session memory (code review notes, bug fixes, conventions)

### Core Architecture
- **`modules/`** - All functional code (no `sub {}`, filename = function name)
- **`modules/base.*`** - Foundation: events, files, network, initialization
- **`configuration/zenki/[name]/`** - Per-zenka configs and start files
- **`data/lib-path/pm/AMOS7/`** - AMOS7 Perl modules (checksums, truth, crypto)

### Recent Work (Check These for Context)
- **`modules/coding.*`** - Async ML inference orchestration with tool loop
- **`modules/httpd.*`** - Async HTTP server with template rendering
- **`modules/httpsd.*`** - HTTPS server with Let's Encrypt integration
- **`modules/web.*`** - Template processing pipeline (process_template_recursive, IPC)
- **`modules/plugin.web.*`** - Web plugins (space visualization, content utilities)
- **`modules/graphics-matrix.*`** - 36+ modules: cursor, glow, channels, cells, graph
- **`modules/kimi.*`** - Kimi zenka (websocket, task queue, JSON tools)
- **`modules/task.*`** - Task coordination between kimi/coding/models

## Where to Look First (By Task Type)

### Understanding the Module System
1. Read `CLAUDE.md` section "Module System"
2. Check `modules/base.init_code` - module loading entry point
3. Look at `bin/Protocol-7` - module compilation into `%code` hash
4. Pattern: `<[module.name]>->($args)` is syntax sugar for `$code{'module.name'}->($args)`

### Working with Zenki (Agents)
1. Read `CLAUDE.md` section "Multi-Agent System (Zenki)"
2. Check `configuration/zenki/[zenka-name]/start` - defines module loading and execution flow
3. Look at `modules/cube.*` - message routing between zenki
4. Look at `modules/v7.*` - zenka lifecycle management

### Event-Driven Architecture
1. Read `modules/base.event.*` - EV wrapper functions
2. Check `modules/httpd.handler.*` - example async request handlers
3. Pattern: Watchers created with `base.event.add_var`, handlers receive Event object

### File Operations
1. **Zenka files**: Use `file.zenka_dir.write/load` (swapped from `base.file.zenka_dir.*`)
2. **Namespacing**: `base.file.*` modules swap to `file.*` via `base.file.pre_init`
3. Check `modules/base.file.zenka_dir.*` for examples

### Checksums and Truth Templates
1. Read `data/lib-path/pm/AMOS7/CHKSUM.pm` - AMOS checksum implementation
2. Read `data/lib-path/pm/AMOS7/TEMPLATE.pm` - Truth template system
3. Check `modules/models.memory.generate_unique_checksum` - collision detection example
4. Pattern: CODE refs in template arrays act as validators/collision detectors

### Cryptography
1. **ACME/Let's Encrypt**: RS256 only (not EdDSA!) - check `modules/letsencr.child.create_jws`
2. **General crypto**: Ed25519 via `modules/crypt.C25519.*`
3. **Key checksums**: `modules/crypt.C25519.key_bin_checksums` - truth template examples

## Code Style Quick Reference

### Critical Conventions
- **Comments**: Always lowercase, begin with `##`
- **Annotations**: Use `[ word ]` in comments, NEVER `( word )`
- **Logging**: Use `<[base.logs]>->( level, 'format %s', $var )` with sprintf format
- **Log style**: `:. description .: value` for aesthetic formatting
- **Module invocation**: `<[module.name]>->($args)` - closing `]>` BEFORE `->`
- **No emojis**: Unless explicitly requested
- **No signature stubs**: Don't add `#,,.,,,...` - signing system adds real 4-line footer

### Log Levels
- **0**: Error (user-facing problems)
- **1**: Default (important events)
- **2**: Info (normal operations)
- **3**: Debug (detailed tracing)

## Key Commands and Tools

### Development
```bash
./bin/Protocol-7 [zenka-name]    # Start zenka directly
p7c 'command args'                # Send command via cube router
./bin/nshell                      # Interactive Protocol-7 shell
p7c 'v7.restart zenka-name'       # Reload zenka to pick up code changes
```

### Testing Modules
```bash
p7c 'zenka.eval-code $code{"module.name"}->("test")'   # Execute module
p7c 'zenka.show-buffer zenka'                          # View zenka logs
p7c 'list sessions'                                    # See active zenki
p7c -c modules/module.name                             # Syntax check protocol-7 module
```

**Note**: Use `ptd -c` not `perl -c` for syntax checking. Protocol-7 modules use `<[...]>` syntax that requires transformation before Perl can parse them.

### Git Workflow (CRITICAL: Respect Pre-Commit Hooks!)

```bash
# 1. Make changes
git add modules/...

# 2. Update version (generates new version number)
./bin/dev/update-version

# 3. Ask user to sign files (requires passphrase - you CANNOT do this!)
# User runs: bin/Protocol-7 sourcecode update-signatures

# 4. Commit normally - pre-commit hooks will pass with valid signatures
git commit -m "message"
```

### ⚠️ NEVER Bypass Pre-Commit Hooks
- **NO** `git commit --no-verify` (equivalent to `--no-verify`)
- **NO** `SKIP_SIGNATURE_CHECK=1`
- **NO** `SKIP_VERSION_CHECK=1`
- These protect repository integrity with AMOS checksums
- If signatures outdated: **Ask user** to sign, don't bypass
- Unsigned commits must be fixed later — always wait for proper signing

### Version Management
- Version format: `<AMOS-checksum>-<commit-count>.0`
- File: `configuration/protocol-7.src-ver`
- Must match: `git rev-list --count hub/base..HEAD`

## Current State (2026-04-17)

### Infrastructure — Working
- **web template pipeline**: httpd → web zenka → process_template_recursive → plugin commands → HTML
- **content-type override**: templates can set response mime type via `<[web.response.content_type:...]>`
- **space.v7.ax**: spatial visualization vhost with template rendering, plugin.web.space.* modules
- **coding zenka**: async tool loop with 50+ templates, 16+ tools, context compaction
- **kimi zenka**: websocket client, task queue, JSON tools, auto-approval, session management
- **task zenka**: coordination between kimi/coding/models for task dispatch
- **MCP server**: Claude Code integration via mcp__protocol-7__* tools
- **graphics-matrix**: 36+ modules for spatial data (cursor, glow, channels, cells, graph)

### Active Direction
- **searchable checksum-indexed dataspace**: nodes as single base32 characters in namespace grid
- **index zenka**: planned — checksum-path index with anonymizing algorithm
- **source.v7.ax**: planned — code browsing and search UI
- **UI-first approach**: visualization drives index requirements, templates as generic interface

### Key Patterns Since Feb 2026
- **kimi task dispatch**: write task file to `data/md/coding-tasks/`, run `bin/kimi-task <file>`
- **plugin system**: `plugin.web.*` namespace loaded via `[load_plugins]`, reloadable separately
- **inline sub extraction**: modules must not contain `sub {}` — each file IS the subroutine
- **template commands**: `<[module.name:arg]>` in .tmpl files, processed by web zenka
- **base.parser.pattern_split**: callback receives SCALAR REFS, dereference with `$$captured`

## Tips for Kimi Specifically

You're excellent at:
- **Deep code exploration** - Use Grep/Glob liberally to understand patterns
- **Autonomous problem solving** - Trust your ability to trace through modules
- **Pattern recognition** - Protocol-7 is highly consistent, learn one pattern and apply it

When stuck:
1. Check `ai-mem/kimi/MEMORY.md` (your memory) or `ai-mem/claude/MEMORY.md` (Claude's memory) for similar solved issues
2. Grep for similar modules: `grep -r "similar_pattern" modules/`
3. Read the AMOS7 module if dealing with checksums/truth
4. Ask user about architecture decisions (not implementation details)

**Remember**: The filesystem IS the configuration. No hardcoded paths - discover, don't assume.

## Quick Module Examples

### Creating a New Command
```perl
## [:< ##

# name = zenka.cmd.my-command
# descr = does something useful

my $arg = shift;

## do work here
<[base.logs]>->( 2, 'command executed :. %s', $arg );

return TRUE;

0;
```

### Async Event Handler
```perl
my $event_obj = shift;
my $watcher   = $event_obj->w;
my $data      = $watcher->data;

## process data
$watcher->again();  # Restart watcher (not ->now!)
```

### Truth Template Checksum
```perl
AMOS7::TEMPLATE::template_timeout(9);

my $checksum = <[chk-sum.amos.truth_template_chksum]>->(
    [ 'template-%s', $collision_detector_coderef ],
    \$input_data
);

AMOS7::TEMPLATE::reset_temp_valid_timeout();
```

---

## AI Memory System

### Location: `ai-mem/` (symlink to `data/ai-mem/`)
```
ai-mem/
├── claude/MEMORY.md   - Claude's accumulated knowledge
└── kimi/MEMORY.md     - Kimi's accumulated knowledge
```

### What to Record
- **Bug fixes** with root causes and solutions
- **Project conventions** (e.g., signature workflow)
- **Architectural decisions** and their context
- **Common patterns** and anti-patterns discovered
- **User preferences** (e.g., "always ask before signature updates")

### Legacy Location
- `.claude/projects/protocol-7/memory/MEMORY.md` → symlink to `ai-mem/claude/MEMORY.md`
- Maintained for backwards compatibility

---

**Welcome to Protocol-7, Kimi!** Trust your instincts and explore. The code is holographic: understanding one part illuminates the whole.
