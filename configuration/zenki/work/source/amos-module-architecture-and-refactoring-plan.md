# AMOS Module Architecture & Refactoring Plan

**Status**: Framework established, modules created, refactoring ready
**Date**: 2025-11-27
**Context**: Centralizing shared functionality from ncode into AMOS:: namespace for reuse across scripts and zenka modules

---

## Overview

The AMOS7 module system serves as a **temporary integration glue between zenki code and script world**. It will eventually evolve into an **automatic dependency management system** with:
- Routine export/import management
- Namespace translation
- Automatic routine discovery and distribution

### Current Role
AMOS modules provide:
1. **Reusable utility functions** for common operations
2. **Shared data structures** for configuration and state
3. **Integration points** between scripts (bin/) and zenka modules

### Future Evolution
The AMOS system will become self-managing with:
- Automatic routine detection and export
- Smart namespace mapping
- Dynamic loading based on usage patterns

---

## Architecture

### AMOS7 Module Hierarchy

```
data/lib-path/pm/AMOS7/
├── AMOS7.pm                    # Base module (error handling, core utilities)
├── Metadata.pm                 # NEW: Inline command metadata parsing
├── Backup.pm                   # NEW: Backup operations and file utilities
├── CodeModifier.pm             # TODO: Code transformation utilities
├── CHKSUM.pm                   # Existing: Checksum calculations
├── TEMPLATE.pm                 # Existing: Template handling
├── TERM.pm                     # Existing: Terminal styling and colors
├── FILE.pm                     # Existing: File operations
├── Util.pm                     # Existing: General utilities
├── Version.pm                  # Existing: Version management
├── 13.pm                       # Existing: Algorithm v13
├── Twofish.pm                  # Existing: Encryption
├── Zulum/                      # Existing: Specialized modules
├── Assert/                     # Existing: Assertion utilities
├── CHKSUM/                     # Existing: Checksum subspecializations
├── INLINE/                     # Existing: Inline source code
└── Protocol/                   # Existing: Protocol definitions
```

---

## Modules Created (This Session)

### AMOS7::Metadata (288 lines)
**Purpose**: Parse and manage inline command documentation

**Exports**:
- `parse_inline_metadata($source_code)` - Extract metadata from source files
- `find_metadata_blocks($source_code)` - Locate metadata blocks
- `build_command_registry($zenka_root)` - Build searchable command registry
- `search_registry($registry, $pattern)` - Search by name/description/usage
- `filter_by_tag($registry, $tag)` - Filter commands by tag
- `filter_by_zenka($registry, $zenka)` - Filter commands by zenka
- `registry_to_json($registry)` - Convert to JSON output
- `registry_to_yaml($registry)` - Convert to YAML output
- `get_command_info($registry, $cmd)` - Get details for single command

**Metadata Format**:
```perl
## [:< command-metadata
#  command  = work.ncode-replace
#  descr    = Replace text patterns using ncode
#  usage    = work ncode-replace <target> <search> <replace>
#  examples = work ncode-replace cfg workflow work
#  features = auto-confirms, structured output, full backups
#  tag      = development-tool, code-transformation, ai-friendly
#  related  = list-amos-components, ncode-restore
## ]>
```

**Use Cases**:
- Foundation for `bin/list-amos-components` command discovery
- Enables `bin/describe <command>` for help system
- Powers command registry for AI/automation introspection
- Tag-based filtering for workflow discovery

---

### AMOS7::Backup (433 lines)
**Purpose**: Unified backup operations and file utilities

**Exports**:
- `create_backup($source_hash, $metadata, $modified_source)` - Create checksummed backup
- `pack_backup($dir, $file, $cut_path)` - Create tar.gz archive
- `restore_backup($backup_file, $target_root)` - Restore from archive
- `load_metadata($file)` - Load backup metadata
- `save_metadata($file, $metadata)` - Save backup metadata
- `create_checksums($source_hash)` - Generate BMW-256 checksums
- `check_path($path)` - Ensure directory exists (recursive creation)
- `clean_dir($path)` - Remove and recreate directory
- `create_dir($path)` - Create single directory
- `timestamp_string()` - Generate ISO-format timestamp
- `load_source($filepaths)` - Load files into memory hash
- `save_source($hash, $cut_path)` - Write file hash to disk

**Backup Metadata Format**:
```
backup.time = 1732704000
backup.created_by = developer
backup.created_on = hostname
operation.type = replace
original_bmw.<filename> <checksum>
modified_bmw.<filename> <checksum>
```

**Use Cases**:
- Shared backup infrastructure for ncode and other tools
- Instant rollback capability (`bin/ncode restore-backup --latest`)
- AI tool confidence in making changes (backups provide safety net)
- Code transformation auditing (before/after checksums)
- File system utilities used by multiple scripts

---

## Functions to Extract into AMOS7::CodeModifier (Future)

The following functions from ncode should eventually move to `AMOS7::CodeModifier`:

### Code Inspection Functions
```perl
get_perl_subs($source_code)         # Extract subroutine definitions
show_perl_sub($name, $source_code)  # Display specific subroutine
cut_out_sub($name, $source_code)    # Remove subroutine
insert_sub($name, $code, $source)   # Insert subroutine
```

### Code Transformation
```perl
replace_all($pattern, $replacement, $source)  # Global replacement
adjust_subroutine_calls($old_name, $new_name) # Refactor calls
remove_unmodified($original, $modified)       # Filter unchanged code
```

### Search and Analysis
```perl
find_subs($pattern, $source_code)   # Find matching subroutines
show_diff($before, $after)          # Show differences
preview($original, $modified)       # Interactive preview
```

---

## Functions to Extract into AMOS7::UI (Future)

User interaction and display functions:

```perl
user_confirmed($question)           # Interactive confirmation
user_confirmed_ai($question)        # AI-friendly auto-confirmation
get_user_input($prompt)             # Get user text input
done($message)                      # Print completion message
warn_apply($message)                # Warning before action
aborted()                          # Abort operation message
```

---

## Refactoring Phases

### Phase 1: Foundation (COMPLETE)
- ✅ Create AMOS7::Metadata module
- ✅ Create AMOS7::Backup module
- ✅ Update bin/list-amos-components to use AMOS7::Metadata
- ✅ Document module architecture

### Phase 2: Update bin/ncode (NEXT SESSION)
- [ ] Update to use AMOS7::Backup
  - Replace `create_backup()` with `AMOS7::Backup::create_backup()`
  - Replace `pack_backup()` with `AMOS7::Backup::pack_backup()`
  - Replace `restore_backup()` with `AMOS7::Backup::restore_backup()`
  - Replace file utility functions
  - Keep local implementations that reference ncode-specific globals

- [ ] Add metadata to ncode commands:
  ```perl
  ## [:< command-metadata
  #  command  = work.ncode-replace
  #  descr    = Replace text patterns with in-place regex
  #  usage    = work ncode-replace <target> <pattern> <replacement>
  #  flags    = --ai-friendly    Auto-confirm, structured output
  #           = --verify-only    Show changes without applying
  #  examples = work ncode-replace cfg workflow work
  #            work ncode-replace cfg workflow work --ai-friendly
  #  features = Full backup with checksums
  #             In-place regex replacement
  #             Preview before application
  #             Instant restore with --latest
  #  tag      = development-tool, code-transformation, ai-friendly
  #  see-also = list-amos-components, describe, restore-backup
  ## ]>
  ```

### Phase 3: Create AMOS7::CodeModifier (SESSION 3+)
- [ ] Extract code inspection functions
- [ ] Extract code transformation functions
- [ ] Extract search and analysis functions
- [ ] Update bin/ncode to use AMOS7::CodeModifier
- [ ] Make available to other scripts

### Phase 4: Create AMOS7::UI (SESSION 3+)
- [ ] Extract user interaction functions
- [ ] Create unified confirmation/input handling
- [ ] Support AI-friendly mode globally
- [ ] Make available to all scripts using interactive features

### Phase 5: Implement bin/list-amos-components (SESSION 3)
- [ ] Scan all zenka modules for metadata blocks
- [ ] Build command registry using AMOS7::Metadata
- [ ] Support options:
  - `--all` - List all commands
  - `--json` - JSON output
  - `--yaml` - YAML output
  - `--tag <tag>` - Filter by tag
  - `--search <pattern>` - Search commands
  - `--zenka <name>` - Commands from zenka
  - `--describe <cmd>` - Full documentation

### Phase 6: Implement bin/describe (SESSION 3+)
- [ ] Show full documentation for command
- [ ] Display examples
- [ ] Show related commands
- [ ] Show availability (zenka, requirements)
- [ ] Support `--json` format for AI

### Phase 7: Continuous Enhancement
- [ ] Add metadata to all 100+ console commands
- [ ] Create command dependency discovery
- [ ] Build workflow definition system
- [ ] Enable AI to query available commands
- [ ] Evolve toward automatic dependency management

---

## Integration Points

### bin/list-amos-components
Uses `AMOS7::Metadata` to discover and list commands:

```perl
use AMOS7::Metadata;

my $registry = AMOS7::Metadata::build_command_registry(
    $PATH->{'root'} . '/configuration/zenki'
);

if ($search_pattern) {
    $registry = AMOS7::Metadata::search_registry($registry, $search_pattern);
}

if ($filter_tag) {
    $registry = AMOS7::Metadata::filter_by_tag($registry, $filter_tag);
}

my $output = AMOS7::Metadata::registry_to_json($registry);
```

### bin/ncode
Uses `AMOS7::Backup` for backup operations:

```perl
use AMOS7::Backup;

my $backup_file = AMOS7::Backup::create_backup(
    \%original_source,
    { operation => { type => 'replace' } },
    \%modified_source
);

# Later, restore with:
AMOS7::Backup::restore_backup($backup_file, $PATH->{'root'});
```

### Future scripts
Can reuse both modules:

```perl
# Command discovery
use AMOS7::Metadata;
my $commands = AMOS7::Metadata::build_command_registry($zenka_root);

# Safe file operations with backup
use AMOS7::Backup;
my $backup = AMOS7::Backup::create_backup(\%files, \%metadata);
```

---

## Design Principles

### 1. Modularity
- Each module focuses on single responsibility
- Functions are composable and chainable
- No assumptions about caller's environment

### 2. Flexibility
- Global state (`$verbose`, `$color`) controlled by caller
- Support both interactive and programmatic use
- Work with or without TTY

### 3. Backwards Compatibility
- ncode keeps existing API while using modules internally
- Migration happens incrementally
- No breaking changes for dependent scripts

### 4. Documentation
- Inline metadata for all commands
- Metadata format is fixed, discoverable, machine-parseable
- Enable AI to introspect system capabilities

### 5. Temporary Nature
- AMOS modules are glue, not final solution
- Designed to evolve into automatic dependency management
- Current structure supports future namespace translation

---

## Current Code Duplication (Candidates for Extraction)

### Across ncode instances
If ncode is instantiated multiple times or copied:
- Backup functions (now in AMOS7::Backup)
- File utilities (now in AMOS7::Backup)
- Metadata parsing (future)

### Between different tools
- Error handling (could use AMOS7)
- File operations (AMOS7::Backup)
- Terminal styling (AMOS7::TERM)
- Checksum operations (AMOS7::CHKSUM)

### Between scripts and zenka
- Code inspection (will be AMOS7::CodeModifier)
- Code transformation (will be AMOS7::CodeModifier)
- Backup operations (AMOS7::Backup)

---

## Testing Strategy

### Unit Tests (Future)
```perl
use Test::More;
use AMOS7::Metadata;
use AMOS7::Backup;

# Test metadata parsing
my $meta = AMOS7::Metadata::parse_inline_metadata($perl_source);
is($meta->{'command'}, 'work.ncode-replace');

# Test backup creation/restore
my $backup = AMOS7::Backup::create_backup(\%files, \%metadata);
ok(-f $backup, 'Backup file created');

AMOS7::Backup::restore_backup($backup, $target_root);
is_deeply(\%restored, \%original, 'Restore successful');
```

### Integration Tests
- bin/ncode with AMOS7::Backup
- bin/list-amos-components with AMOS7::Metadata
- Multiple scripts using shared modules

---

## Timeline

**This Session**: ✅ Create AMOS7::Metadata and AMOS7::Backup

**Next Session** (Recommended):
1. Update bin/ncode to use AMOS7::Backup (30 min)
2. Implement bin/list-amos-components (1 hour)
3. Add metadata to key commands (1 hour)

**Future Sessions**:
1. Create AMOS7::CodeModifier
2. Create AMOS7::UI
3. Implement bin/describe
4. Add metadata to all 100+ commands
5. Build command dependency system

---

## References

- **AMOS Module Pattern**: data/lib-path/pm/AMOS7/CHKSUM.pm, TEMPLATE.pm
- **Inline Metadata Format**: Defined in this document and inline-documentation-plan.md
- **ncode Backup Functions**: bin/ncode lines 1070-1244
- **ncode File Utilities**: bin/ncode lines 1289-1700

---

## Notes

### Why AMOS Modules for This?

1. **Established Pattern**: AMOS7 modules already exist for many utilities
2. **Integration Point**: Natural place for script↔zenka shared code
3. **Temporary Structure**: Allows evolution without breaking changes
4. **Self-Contained**: Each module is importable independently
5. **Precedent**: bin/amos-chksum already uses multiple AMOS modules

### Why Not Zenka?

- Zenka modules are for Protocol-7 operational code
- AMOS modules are glue between systems
- Scripts need instant access (no zenka startup overhead)
- Keeps business logic separate from infrastructure

### Future Automatic Management

The AMOS system will eventually:
1. **Discover routines** automatically in all files
2. **Translate namespaces** (work.ncode-replace → &cmd_ncode_replace)
3. **Manage exports** (automatically determine what's reusable)
4. **Distribute routines** (embed only needed functions in packages)
5. **Resolve dependencies** (automatically find and include dependencies)

This architecture supports that evolution without redesign.

---

**Next Step**: Implement bin/list-amos-components using AMOS7::Metadata
