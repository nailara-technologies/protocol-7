# Inline Documentation System for Protocol-7

## Vision
Replace centralized documentation headers with distributed, inline documentation that lives with the code. Each console command defines its own metadata and help text inline, making it:
- Discoverable via `bin/list-amos-components` command
- Token-efficient (not dumped on every routine check)
- Maintainable (documentation with code)
- Contextual (developers see help when they need it)

## Current State
- **100+ console commands** across zenki modules
- **Centralized headers** in each module (token-heavy)
- **No central registry** of available commands

## Proposed Format

### Inline Command Metadata
```perl
## [:< command-metadata
#  command  = work.ncode-replace
#  descr    = Replace text patterns using ncode with AI-friendly output
#  usage    = work ncode-replace <target> <search> <replace> [--ai-friendly]
#  examples = work ncode-replace cfg workflow work
#             work ncode-replace cfg workflow work --ai-friendly
#  features = auto-confirms, structured output, full backups, instant restore
#  tag      = development-tool, code-transformation, ai-friendly
#  related  = list-amos-components, ncode-restore, ncode-search
## ]>
```

### Usage in Code
```perl
sub cmd_ncode_replace {
    my @params = @ARG;

    # Metadata available to list-amos-components
    if ($params[0] eq 'describe') {
        return get_command_metadata('work.ncode-replace');
    }

    # Implementation...
}
```

## Implementation Plan

### Phase 1: Define Metadata Schema
- [ ] Create `AMOS7::Metadata` module for parsing inline metadata
- [ ] Define schema: command, descr, usage, examples, features, tags
- [ ] Support searching by tag (development-tool, testing, deployment, etc.)

### Phase 2: Implement list-amos-components
- [ ] Scan all modules in cfg/zenki/*/source/
- [ ] Parse inline metadata from each module
- [ ] Build registry: command → metadata
- [ ] Output: human-readable list OR structured JSON/YAML

```bash
# Usage examples:
bin/list-amos-components              # List all commands
bin/list-amos-components --tag development-tool
bin/list-amos-components --search workflow
bin/list-amos-components work         # Commands in 'work' zenka
bin/list-amos-components --json       # Structured output for AI
```

### Phase 3: Implement describe Command
- [ ] Show full documentation for a single command
- [ ] Show examples with explanations
- [ ] Show related commands
- [ ] Show availability (which zenka, requirements)

```bash
bin/describe work.ncode-replace      # Full docs
bin/describe --json work.ncode-replace  # For AI parsing
```

### Phase 4: Enhance Existing Modules
- [ ] Add metadata to workflow zenka commands
- [ ] Add metadata to ncode AI-friendly features
- [ ] Add metadata to other key console commands
- [ ] ~100+ commands to document gradually

## Benefits

### For Developers
- `bin/list-amos-components` to discover available commands
- `bin/describe <command>` for quick help
- Documentation stays with code
- Less scrolling through headers

### For AI/Automation
- Structured metadata (JSON/YAML output)
- Easy to parse and understand
- Tag-based searching
- Programmatic access to command registry

### For Maintenance
- Single source of truth
- Documentation updated when code changes
- Semantic structure for analysis
- Enable future features (command dependencies, workflows, etc.)

## Example: Recent ncode AI-Friendly Features

```perl
## [:< command-metadata
#  command  = work.ncode-replace-ai
#  descr    = AI-friendly ncode replace with auto-confirmation
#  usage    = work ncode-replace-ai <target> <search> <replace>
#  flags    = --ai-friendly    Auto-confirm prompts, structured output
#           = --verify-only    Show changes without applying
#           = --backup-name    Name for the backup
#  examples = work ncode-replace-ai cfg workflow work
#             work ncode-replace-ai cfg workflow work --verify-only
#  features = Auto-confirms all prompts
#             Structured output (JSON/tagged format)
#             Full backup with checksums
#             Optional instant restore with --latest flag
#  requires = ncode, AMOS7::Backup
#  tag      = development-tool, code-transformation, ai-friendly
#  see-also = list-amos-components, describe, restore-backup
## ]>
```

## Next Steps

1. **This Session**: Create bin/list-amos-components stub with description
2. **Next Session**: Implement metadata parsing module
3. **Ongoing**: Add metadata to commands as they're developed/updated
4. **Future**: Build advanced discovery system (AI can learn what's available)

## Storage Locations

- **Metadata**: Inline in `cfg/zenki/*/source/*` files
- **Registry**: Built dynamically by `bin/list-amos-components`
- **Cache** (optional): ~/.code/command-registry.json (for fast lookups)
- **Documentation**: Generated from metadata on demand

## Connection to Broader Vision

This system supports:
- **Intent Parsing** (Layer 2): AI can ask "what commands do I have?"
- **System Introspection** (Layer 1): Self-awareness of capabilities
- **Self-healing** (Layer 7): Commands can discover dependencies
- **Knowledge Sharing**: New developers quickly see what's available

Aligns with Protocol-7 philosophy:
- ✓ Distributed (not centralized)
- ✓ Emergent (evolves as commands added)
- ✓ Self-documenting (code carries own documentation)
- ✓ Relaxed (no big upfront planning needed)

#,,..,,,.,..,,,,,,.,.,,,.,...,.,,,.,,,.,.,..,,..,,...,..,,..,,,,,,...,,..,,,,,
#TIB47MFZJVTDTCCNAW345PO3WIZODD7FGAJJDUXT6LI342AGMX4EUZQAQLILM42VHBIEFNHIT7IVY
#\\\|YMMM3VNL5NVVYEIOTLRUCZP3L6HZS4D7ZJUOHSS6FJJLPFUYPSX \ / AMOS7 \ YOURUM ::
#\[7]QJEYE4GW3KHUMZYLCD3VKI6KH4JDTUW63ZQ6ITEZWBONUEZDSIDA 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
