# AI Scripts

Simplified command-line wrappers for common AI assistant operations.

These scripts provide ergonomic CLI access to protocol-7 functionality
without needing to construct JSON-RPC calls manually.

## Available Scripts

### `note` - Note System Access

Quick access to the persistent note system:

```bash
# Write a finding
note write finding "socket timeout issue identified"

# Search previous notes
note search "transport"
note search "socket timeout" L2

# List all notes
note list

# Read specific note
note read task-abc123 L1
```

Aliases: `w` (write), `r` (read), `ls` (list), `s` (search)

### `validate` - Module Validation

Quick validation before declaring work complete:

```bash
# Validate a module
validate coding.validate.module
validate note.search
```

Checks: syntax, format, metadata, signatures, whitelist.

## Design Principles

1. **Minimal typing** - Short commands, sensible defaults
2. **Human-friendly output** - Formatted for readability
3. **Consistent interface** - Similar patterns across all scripts
4. **Fail gracefully** - Clear error messages, helpful suggestions

## Adding New Scripts

When creating new ai-scripts:

1. Use perl for consistency
2. Support `-help` and `help` subcommand
3. Include shorthand aliases for common operations
4. Output plain text (not JSON) for human consumption
5. Exit 0 on success, 1 on error with message to stderr

## Future Ideas

- `task` - Task queue operations (list, status, retry)
- `search` - Code search with formatted results
- `module` - Module info and dependency lookup
- `test` - Run integration tests for a module

#,,.,,.,.,.,.,.,,,.,,,.,.,,,,,.,,,,..,.,.,..,,..,,...,...,.,,,,..,..,,.,.,,.,,
#OCVVV5I2FQYVUK3ZNLG66HMIJ73YLRYBD74D7CY4ZQV3NFCEXSJNDWS6U46RWY22FTBVQZSEYSF7A
#\\\|SDIDP2EH67E6IFWRSCHIQNX5HF4NEVD53O52II6XQGYM23LNLCQ \ / AMOS7 \ YOURUM ::
#\[7]GVU7ESE6BFD2TV44INFAPXVUVIQVFALSOERUTMJDO5SSLIOFIYDA 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
