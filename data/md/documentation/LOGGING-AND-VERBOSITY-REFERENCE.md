# Protocol-7 Logging and Verbosity Reference

A comprehensive guide to the Protocol-7 logging system, log levels, and verbosity targets.

---

## Overview

Protocol-7 uses a multi-target logging system where verbosity can be controlled independently for different output destinations. The system supports 10 log levels (0-9) with specific behaviors and use cases.

---

## Log Levels

### Level Correspondence to -v Flags

Log levels correspond to `-v[v[v[v[v]]]]` flags when starting a zenka:

| Level | Flag | Name | Behavior |
|-------|------|------|----------|
| 0 | (always) | error | Always visible, color highlighted |
| 1 | default | normal | Normal operation logging |
| 2 | -vv | info | Info/debug combined, development use |
| 3 | -vvv | extended debug | Compiles routines with call tracing |
| 4 | -vvvv | source dump | Dumps parsed sourcecode on startup |
| 5 | -vvvvv | data dump | Dumps %data hash on shutdown (requires devmod) |
| 6-9 | — | (reserved) | Technically possible, currently unused |

### Color Coding (from base.log.format_entry)

```perl
## color index per log level [ 0=error 1=default 2=info 3+=debug ] ##
```

- **Level 0**: Error color (highlighted, always visible)
- **Level 1**: Default color (normal operation)
- **Level 2**: Info color (development/debug)
- **Level 3+**: Debug color (extended debugging)

### Usage Guidelines

#### Level 0 - Error
```perl
<[base.log]>->(0, "critical failure: %s", $error);
```
- Always visible regardless of verbosity settings
- Use for critical errors that require immediate attention
- Color-highlighted for visibility

#### Level 1 - Normal (Default)
```perl
<[base.log]>->(1, "starting service: %s", $service_name);
```
- Normal operation logging
- Visible at default verbosity
- Use for operational status messages

#### Level 2 - Info/Debug Combined
```perl
<[base.log]>->(2, "processing request: %s", $request_id);
```
- Development and debugging information
- Use for detailed operational flow
- Often collected in memory buffers only

#### Level 3+ - Extended Debug
```perl
<[base.log]>->(3, "entering subroutine: %s", $sub_name);
```
- Compiles additional logging code into routines
- Traces routine calls and parameters
- Significant performance impact
- Use sparingly during active debugging only

---

## Verbosity Targets

Protocol-7 supports three independent verbosity controls:

### Console Output
```perl
<system.zenka.verbosity.console>
```
- Controls logging to terminal/console
- Affects interactive visibility

### UIM-Memory Buffer
```perl
<system.zenka.verbosity.buffer>
```
- Controls logging to in-memory buffer
- Used for runtime log inspection
- Accessible via `p7-log` commands

### Log Files (Network)
```perl
<system.zenka.verbosity.logfile>
```
- Controls logging to persistent files
- Uses network requests to `p7-log` zenka
- Survives process restarts

### Effective Verbosity

The effective verbosity is the **maximum** of all three targets:

```perl
my ( $verbosity_low, $max_verbosity ) = <[base.minmax]>->(
    <system.zenka.verbosity.console>,
    <system.zenka.verbosity.buffer>,
    <system.zenka.verbosity.logfile>
);
```

See `modules/base.get_max_verbosity` for implementation.

---

## Practical Examples

### Example 1: Production Deployment
```bash
## Start with default verbosity (level 1)
./bin/Protocol-7 start zenka-name

## Logs: errors (0) + normal operations (1)
## Console: visible
## Buffer: collected
## Logfile: written
```

### Example 2: Development/Debugging
```bash
## Start with increased verbosity (level 2)
./bin/Protocol-7 -vv start zenka-name

## Logs: errors (0) + normal (1) + info/debug (2)
## Good for development without heavy overhead
```

### Example 3: Deep Debugging
```bash
## Start with extended debug (level 3)
./bin/Protocol-7 -vvv start zenka-name

## Additional: routine call tracing compiled in
## Performance impact expected
```

### Example 4: Code Analysis
```bash
## Start with source dump (level 4)
./bin/Protocol-7 -vvvv start zenka-name

## Dumps parsed sourcecode after syntax parsing
## Useful for debugging parser issues
```

---

## Code Patterns

### Basic Logging
```perl
<[base.log]>->(1, "message format %s", $variable);
```

### Conditional Logging
```perl
<[base.log]>->(2, "debug info: %s", $data)
    if <system.zenka.verbosity.console> >= 2;
```

### Error Logging
```perl
<[base.log]>->(0, "error: %s [code: %d]", $msg, $code);
```

### sprintf-Style Only
```perl
## CORRECT
<[base.log]>->(1, "value: %s", $value);

## WRONG - never interpolate
<[base.log]>->(1, "value: $value");  ## DON'T DO THIS
```

---

## Related Modules

| Module | Purpose |
|--------|---------|
| `base.log` | Primary logging subroutine |
| `base.logs` | Log at default level with sprintf |
| `base.s_warn` | Non-fatal warning logging |
| `base.get_max_verbosity` | Calculate effective verbosity |
| `base.log.format_entry` | Format log entries with colors |
| `p7-log` zenka | Network log aggregation service |

---

## Best Practices

1. **Use level 0 sparingly** - Reserve for actual errors
2. **Level 1 for operations** - Normal status and flow
3. **Level 2 for development** - Detailed info, acceptable overhead
4. **Level 3+ temporarily** - Only during active debugging
5. **Never interpolate** - Always use sprintf-style format strings
6. **Consider all targets** - A log may appear in one place but not another
7. **Check verbosity before heavy ops**:
   ```perl
   if (<system.zenka.verbosity.console> >= 2) {
       ## expensive debug info
   }
   ```

---

## Troubleshooting

### "My logs don't appear"
- Check all three verbosity targets
- Verify p7-log zenka is running (for logfile target)
- Ensure log level is ≤ max verbosity

### "Too much log output"
- Reduce to `-v` (level 1) or default
- Adjust specific target verbosities
- Use level 2+ only in development

### "Level 3+ is slow"
- Expected - compiles in tracing code
- Use only during active debugging
- Disable for production

---

## See Also

- `data/ai-mem/claude/coding-style.md` - Claude-specific logging notes
- `data/ai-mem/kimi/coding-style.md` - Kimi-specific logging notes
- `modules/base.log.format_entry` - Color/format implementation
- `modules/base.get_max_verbosity` - Effective verbosity calculation

---

#,,.,,..,,,.,,,.,,,,,,,,.,,..,,.,,,,,,.,.,.,,,.,.,...,..,,..,,..,,..,,..,,,.,,
#SIATP2FCBAL2U4326BRJ646DFCZIETWSHUYBDJAUKY3XIPAGG6Q7GZJVY7KFS6EGPYAXVG5MAU5IM
#\\\|AOY2TEMLO2FM5NZ3E3M5T4PRWN4WOTCAXHPKS3ZPVDSEHDP3DC2 \ / AMOS7 \ YOURUM ::
#\[7]B4K2ELH4SCSEIKHZSYACNAYCXRL55NQNMKLTNBOREK7QGTMDKEBI 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
