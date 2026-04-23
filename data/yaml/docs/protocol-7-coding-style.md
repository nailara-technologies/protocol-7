# Protocol-7 Coding Style Guide

A comprehensive guide to coding conventions, best practices, and patterns for Protocol-7 module development.

## Table of Contents

1. [Module Structure](#module-structure)
2. [Function Calls and Data Access](#function-calls-and-data-access)
3. [Configuration Management](#configuration-management)
4. [String Literals and Quoting](#string-literals-and-quoting)
5. [Exception Handling](#exception-handling)
6. [Logging and Debugging](#logging-and-debugging)
7. [Variable Management](#variable-management)
8. [JSON Processing](#json-processing)
9. [Asynchronous I/O and Event Handling](#asynchronous-io-and-event-handling)
10. [HTTP Request Handling](#http-request-handling)
11. [File Operations](#file-operations)
12. [Console Commands](#console-commands)
13. [Init Code Constraints](#init-code-constraints)
14. [Code Organization](#code-organization)

---

## Module Structure

### Basic Module Format

All modules follow a consistent structure:

```perl
## [:< ##

# name = module.name.here
# descr = Brief description of what this module does

# Implementation code starts here...

# At the end of file: AMOS7 data signature (auto-generated)
```

### Key Points

- **No subroutine declarations**: Modules don't use `sub { }` - the filename itself becomes the callable subroutine
- **Module invocation syntax**:
  - Standard Perl: `$code{'module.name'}->()`
  - Special syntax: `<[module.name]>->()` (parsed to Perl before compilation)
  - Config values: `<config.key>` (resolved to configuration values)
- **Naming convention**: Use dot notation (e.g., `base.init_code`, `httpd.handler.acme_request`)
- **Module organization**: Group related modules with shared prefixes (e.g., all httpd modules start with `httpd.`)

---

## Function Calls and Data Access

### Function Call Syntax

The `<[...]>` notation is a Protocol-7 parser feature. **The key in `%code` is EXACTLY the module filename** from `modules/*`.

```perl
## Module filename: modules/debian.parent.scan_zenki_dependencies
## %code key: 'debian.parent.scan_zenki_dependencies'
## Function call:
my $result = <[debian.parent.scan_zenki_dependencies]>;
## Parses to:
my $result = $code{'debian.parent.scan_zenki_dependencies'}->();

## The dots in the filename are preserved as-is in the %code key
## They are NOT converted to nested hash access!
## NOT this (wrong):
my $result = $code{'debian'}{'parent'}{'scan_zenki_dependencies'}->();

## With arguments:
my $result = <[debian.parent.install_missing]>->({
    zenka => $zenka_name,
    prefer_debian => 1
});
## Parses to:
my $result = $code{'debian.parent.install_missing'}->({
    zenka => $zenka_name,
    prefer_debian => 1
});
```

### Function Call Patterns

| Pattern | Parsed To | Example |
|---------|-----------|---------|
| `<[func]>` | `$code{'func'}->()` | `<[base.log]>` |
| `<[func]>->($arg)` | `$code{'func'}->($arg)` | `<[base.log]>->(2, "message")` |
| `<[func]>->({...})` | `$code{'func'}->({...})` | `<[install]>->({zenka => 'v7'})` |

**Note**: The parser does NOT support storing `<[func]>` as a code reference without calling it. Always call the function directly using one of the patterns above.

### Data Access Patterns

Protocol-7 uses different syntax for data access depending on context:

#### In `init_code` Modules

Use `<data.key.path>` notation for initialization:

```perl
## modules/service.init_code

## ✓ CORRECT - Init_code data notation
<service.config.port> //= 8080;
<service.registry.clients> //= {};
```

#### In Regular Modules

Use `$data{...}` hash notation:

```perl
## modules/service.cmd.list

## ✓ CORRECT - Regular hash access
my $clients = $data{'service'}{'registry'}{'clients'};
my $port = $data{'service'}{'config'}{'port'};

## ✗ WRONG - <...> notation doesn't work outside init_code
my $clients = <service.registry.clients>;  # Won't resolve properly
```

### Critical: Dot Handling Difference

This is the fundamental difference between the two notations:

#### `<[function.name]>` - Function Calls (key is EXACTLY the module filename)
```perl
# Module file: modules/debian.parent.scan
# Function call:
<[debian.parent.scan]>;
# Parses to: $code{'debian.parent.scan'}->()
# The key 'debian.parent.scan' matches the filename exactly
```

#### `<data.name.path>` - Data Access in init_code (dots CONVERTED to nested structure)
```perl
<debian.cfg.timeout> = 30;
# Parses to: $data{'debian'}{'cfg'}{'timeout'} = 30
# Creates nested hash: $data{'debian'} → {'cfg'} → {'timeout'}
```

#### `$data{'key'}{'path'}` - Data Access in Regular Modules (explicit hash)
```perl
my $timeout = $data{'debian'}{'cfg'}{'timeout'};
# Direct hash access in regular modules
```

### Key Distinction Summary

**Module Namespace Pattern: Files use dot notation for namespacing**

- **`<[module.name.function]>`** = Function call: Uses exact module filename as %code key
  - Module file: `modules/module.name.function`
  - Parser converts to: `$code{'module.name.function'}->()`
  - Dots in filename become dots in key (NOT nested hash structure)

- **`<config.key.path>`** = Data init (init_code only): Dots converted to nested hashes
  - Parser converts to: `$data{'config'}{'key'}{'path'}`
  - Used ONLY in init_code modules

- **`$data{'key'}{'path'}`** = Data access (regular modules): Explicit nested hash structure
  - Used in all regular (non-init_code) modules

### Common Mistakes and Fixes

```perl
## MISTAKE 1: Module filenames use dot notation for namespacing
# Module file: modules/debian.parent.scan
# ✓ CORRECT: <[debian.parent.scan]>;
#            Parses to: $code{'debian.parent.scan'}->()
# ✗ WRONG:   $code{'debian'}{'parent'}{'scan'}->()  - NOT nested!

## MISTAKE 2: The %code key is EXACTLY the module filename
# If file is: modules/zenki.parent.ensure_cube
# Then key is: 'zenki.parent.ensure_cube' (with all the dots)
# Call it with: <[zenki.parent.ensure_cube]>;

## MISTAKE 3: Confusing function dots (preserved) with data dots (converted)
# In init_code - data dots ARE converted to nested structure:
<service.config.timeout> = 30;
# Parses to: $data{'service'}{'config'}{'timeout'} = 30 (nested!)

# But function calls - module filename dots are PRESERVED:
<[service.config.get_timeout]>;
# Parses to: $code{'service.config.get_timeout'}->()  (NOT nested!)

## MISTAKE 4: Using <...> data notation in regular modules
my $x = <service.config.value>;        # ✗ Won't work in regular modules
my $x = $data{'service'}{'config'}{'value'};  # ✓ Correct - use $data{...}

## MISTAKE 5: Remember: Module names DON'T nest, data paths DO
<foo.bar>;           # Data in init_code: $data{'foo'}{'bar'}  - nested!
<[foo.bar]>;         # Function call: $code{'foo.bar'}->()  - NOT nested!
```

---

## Configuration Management

### The Elegant Pattern: Define Once, Reference Everywhere

Protocol-7 uses the `%data` hash with the `//=` operator to create **elegantly overridable** configuration. This pattern ensures:

- **Single source of truth**: Configuration defined once in `init_code`
- **Overridable anywhere**: Can be overridden before module initialization
- **Consistent references**: All code references the same `<namespace.cfg.key>` path
- **No redundant fallbacks**: Default values never repeated in functions

### Pattern Overview

```perl
## In modules/service.parent.init_code
## Define configuration ONCE with overridable defaults
<service.cfg.listen_port>      //= 8080;
<service.cfg.max_connections>  //= 100;
<service.cfg.enable_logging>   //= 1;
<service.cfg.data_directory>   //= '/var/lib/service';

## In all other modules - reference consistently
## modules/service.parent.start_server
sub service_parent_start_server {
    my $port = <service.cfg.listen_port>;      ## No fallback needed
    my $max_conn = <service.cfg.max_connections>;

    # Server startup logic using config values...
}

## modules/service.cmd.configure
sub service_cmd_configure {
    my $params = shift || {};

    ## Use config as default, allow parameter override
    my $log = $params->{logging} // <service.cfg.enable_logging>;
    my $dir = $params->{directory} // <service.cfg.data_directory>;
}
```

### Why This is Elegant

Like `<system.zenka.name>` which is set once and used everywhere, configuration should follow the same principle:

**✓ Elegant (Protocol-7 style):**
```perl
## In init_code
<debian.cfg.prefer_debian> //= 1;
<debian.cfg.use_cpanm> //= 1;

## In function
my $prefer = $params->{prefer_debian} // <debian.cfg.prefer_debian>;
```

**✗ Inelegant (hardcoded fallbacks):**
```perl
## In init_code
<debian.cfg.prefer_debian> //= 1;

## In function - repeats default!
my $prefer = $params->{prefer_debian} // 1;  # Hardcoded!
```

### Configuration Override Examples

Users can override configuration in several ways:

#### 1. In Zenka Configuration Files

```perl
## configuration/zenki/myservice/start
debian.cfg.prefer_debian = 0    ## Prefer cpanm over debian packages
debian.cfg.auto_install = 1     ## Enable auto-install even as non-root
```

#### 2. At Runtime via IPC Commands

```perl
## In a .cmd.* module
$data{'debian'}{'cfg'}{'prefer_debian'} = 0;
```

#### 3. In Other Modules' init_code

```perl
## modules/custom.init_code (loaded before debian)
<debian.cfg.zenki_config_base> = '/custom/path/zenki';
```

### Real-World Example: debian Module

**Before refactoring (inelegant):**

```perl
## modules/debian.parent.init_code
<debian.cfg.zenki_config_base> //= '/data/projects/protocol-7/configuration/zenki';
<debian.cfg.prefer_debian>     //= 1;
## Missing: use_cpanm not in config!

## modules/debian.parent.scan_zenki_dependencies
sub scan {
    ## Redundant hardcoded fallback!
    my $base = <debian.cfg.zenki_config_base> || '/data/projects/protocol-7/configuration/zenki';
}

## modules/debian.parent.install_missing
sub install {
    my $prefer = $params->{prefer_debian} // <debian.cfg.prefer_debian>;
    my $cpanm = $params->{use_cpanm} // 1;  # Hardcoded! Not in config!
}

## modules/debian.console.install-deps
my $result = <[debian.parent.install_missing]>->({
    prefer_debian => 1,  # Hardcoded!
    use_cpanm => 1       # Hardcoded!
});
```

**After refactoring (elegant):**

```perl
## modules/debian.parent.init_code
<debian.cfg.zenki_config_base> //= '/data/projects/protocol-7/configuration/zenki';
<debian.cfg.auto_install>      //= ($UID == 0 ? 1 : 0);
<debian.cfg.prefer_debian>     //= 1;
<debian.cfg.use_cpanm>         //= 1;  ## Complete config set

## modules/debian.parent.scan_zenki_dependencies
sub scan {
    my $base = <debian.cfg.zenki_config_base>;  ## No fallback needed
}

## modules/debian.parent.install_missing
sub install {
    my $prefer = $params->{prefer_debian} // <debian.cfg.prefer_debian>;
    my $cpanm = $params->{use_cpanm} // <debian.cfg.use_cpanm>;
}

## modules/debian.console.install-deps
my $result = <[debian.parent.install_missing]>->({
    prefer_debian => <debian.cfg.prefer_debian>,
    use_cpanm => <debian.cfg.use_cpanm>
});
```

### Configuration Naming Conventions

**Namespace Structure:**
```
<module.cfg.setting_name>
```

**Examples:**
- `<debian.cfg.prefer_debian>` - Preference setting
- `<debian.cfg.zenki_config_base>` - Path configuration
- `<httpd.cfg.listen_port>` - Service parameter
- `<v7.cfg.install_bin_p7>` - Feature toggle

**Best Practices:**
- Always use `.cfg.` in the path for configuration values
- Use descriptive names: `max_retries` not `max_r`
- Group related settings under same namespace
- Use `//=` for overridable defaults
- Boolean configs: use 1/0, not true/false
- Path configs: use absolute paths as defaults

### Anti-Patterns to Avoid

**❌ Repeated Hardcoded Defaults:**
```perl
## BAD - Default repeated in multiple places
my $port = $params->{port} // 8080;  # In function A
my $port = $config->{port} // 8080;  # In function B
```

**❌ Missing Config Entries:**
```perl
## BAD - Some settings in config, others hardcoded
<service.cfg.port> //= 8080;
## But in code:
my $timeout = $params->{timeout} // 30;  # Should be in config!
```

**❌ Redundant Fallback Chains:**
```perl
## BAD - Config has default, but code repeats it
my $val = <service.cfg.value> || '/default/path';  # Already defaulted in init!
```

**✅ Correct Pattern:**
```perl
## In init_code - Define complete config
<service.cfg.port>    //= 8080;
<service.cfg.timeout> //= 30;
<service.cfg.path>    //= '/default/path';

## In functions - Reference directly
my $port = <service.cfg.port>;      # No fallback needed
my $timeout = <service.cfg.timeout>;
my $path = <service.cfg.path>;
```

---

## Zenki Dependency Resolution

### The Problem: Complex Startup Hierarchy

Protocol-7 zenki have a strict dependency chain:
```
v7 (root process manager)
 └─> cube (IPC router)
      └─> zenka (application processes: httpd, zulum, terminal, etc.)
```

**Challenges:**
- Users/LLMs may try to start zenki directly without understanding the workflow
- Manual startup is error-prone: "Did I start v7? Is cube running? Which permissions?"
- Need transparent "just works" behavior

### The Solution: Smart Launcher with Auto-Resolution

The `zenki.parent.start` system automatically resolves dependencies:

```perl
## User/LLM simply requests:
<[zenki.parent.start]>->({ zenka => 'httpd' });

## System automatically:
## 1. Checks if v7 is running → starts if needed (requires root)
## 2. Checks if cube is running → waits for v7 to start it
## 3. Checks if httpd is running → requests v7 to start it
## 4. Returns when httpd is ready
```

### Architecture Overview

**Core Modules:**

| Module | Purpose |
|--------|---------|
| `zenki.parent.init_code` | Configuration and registries |
| `zenki.parent.start` | Main entry point - smart launcher |
| `zenki.parent.resolve_dependencies` | Resolves dependency chain |
| `zenki.parent.ensure_v7` | Ensures v7 running (needs root) |
| `zenki.parent.ensure_cube` | Ensures cube running |
| `zenki.parent.ensure_zenka` | Ensures specific zenka running |
| `zenki.parent.check_running` | Process detection via ps |
| `zenki.parent.request_v7_start` | Requests v7 to start zenka |

**Console Commands:**

```perl
## Start zenka with automatic dependency resolution
zenki start httpd

## Show status of all running zenki
zenki status

## Show status of specific zenka
zenki status cube
```

### Configuration

All zenki configuration follows the elegant `%data` pattern:

```perl
## modules/zenki.parent.init_code

<zenki.cfg.v7_binary>            //= '/data/projects/protocol-7/bin/Protocol-7';
<zenki.cfg.v7_startup_timeout>   //= 10;   ## Seconds
<zenki.cfg.cube_startup_timeout> //= 5;
<zenki.cfg.zenka_startup_timeout> //= 8;
<zenki.cfg.auto_start_v7>        //= ($UID == 0 ? 1 : 0);
<zenki.cfg.cube_socket_path>     //= '/var/run/.7/UNIX';
```

**Override Example:**

```perl
## In configuration/zenki/myservice/start
zenki.cfg.v7_startup_timeout = 20   ## Longer timeout for slow systems
zenki.cfg.auto_start_v7 = 0         ## Never auto-start v7
```

### Dependency Chain Resolution

```perl
## modules/zenki.parent.resolve_dependencies

sub zenki_parent_resolve_dependencies {
    my $params = shift || {};
    my $zenka_name = $params->{zenka};

    ## Determine dependency chain
    my @chain;

    if ($zenka_name eq 'v7') {
        @chain = qw| v7 |;
    } elsif ($zenka_name eq 'cube') {
        @chain = qw| v7 cube |;
    } else {
        @chain = qw| v7 cube |;  ## All other zenki need both
    }

    ## Resolve each dependency in order
    foreach my $dep (@chain) {
        if ($dep eq 'v7') {
            $result = <[zenki.parent.ensure_v7]>;
        } elsif ($dep eq 'cube') {
            $result = <[zenki.parent.ensure_cube]>;
        } else {
            $result = <[zenki.parent.ensure_zenka]>->({ zenka => $dep });
        }

        return { success => 0, failed_at => $dep } unless $result->{success};
    }

    return { success => 1, chain => \@chain };
}
```

### Process Detection

```perl
## modules/zenki.parent.check_running

sub zenki_parent_check_running {
    my $params = shift || {};
    my $zenka_name = $params->{zenka};

    ## Use ps to check for running process
    my $ps_output = `ps aux 2>/dev/null`;
    my $pattern = qr/Protocol-7\s+$zenka_name(?:\s|$)/;

    foreach my $line (split /\n/, $ps_output) {
        if ($line =~ $pattern) {
            my @fields = split /\s+/, $line;
            my $pid = $fields[1];

            if ($pid && kill 0, $pid) {  ## Verify process exists
                return { running => 1, pid => $pid };
            }
        }
    }

    return { running => 0, zenka => $zenka_name };
}
```

### Statistics Tracking

The system tracks usage statistics in `<zenki.stats>`:

```perl
<zenki.stats> = {
    v7_starts       => 0,   ## How many times v7 was started
    cube_starts     => 0,   ## How many times cube was started
    zenka_starts    => 0,   ## How many zenki were started
    auto_resolutions => 0,  ## How many auto-resolutions performed
    failed_starts   => 0    ## How many starts failed
};
```

View with: `zenki status`

### Log Streaming Architecture

**Problem:** V7 captures zenki stdout/stderr but needs to share logs with observers

**Existing Infrastructure:**
- `v7.handler.zenka_output` - Event watcher reading zenka pipes
- `v7.handler.process_output_line` - Line-by-line processor
- `v7.init_zenka_output_patterns` - Pattern matching on output
- `$zenka_instance->{'output_buffer'}` - Buffered output

**Planned Enhancement:** Unix domain socket log streaming

```perl
## modules/v7.parent.stream_zenka_log

## Features:
## 1. Create unix socket: /var/run/.7/logs/<zenka>.<instance_id>
## 2. Stream output_buffer to all connected observers
## 3. Support multiple simultaneous observers (clone)
## 4. Support detach/reattach (like tmux/screen)
## 5. Stop v7 console pass-through when terminal zenka attached

<v7.log_streams>->{$instance_id} = {
    zenka       => $zenka_name,
    socket_path => "/var/run/.7/logs/$zenka_name.$instance_id",
    created     => time(),
    observers   => [],        ## List of connected observer IDs
    passthrough => 1          ## v7 shows logs by default
};
```

**Use Cases:**

```perl
## Human in terminal:
$ zenki start httpd
$ zenki attach-logs httpd    ## Attach to httpd log stream

## LLM observer:
<[v7.parent.stream_zenka_log]>->({
    instance_id => $id,
    zenka => 'httpd',
    observer => 'llm_session_12345'
});

## Multiple observers simultaneously (clone):
## Terminal 1: zenki attach-logs httpd
## Terminal 2: zenki attach-logs httpd
## LLM: <[v7.parent.stream_zenka_log]>->({...})
## All three see the same log stream in real-time

## Detach and reattach:
## Ctrl+D to detach, logs keep streaming
## zenki attach-logs httpd  ## Reattach later, see history

## Terminal zenka takes over:
## When terminal zenka with ANSI buffer starts:
##   - v7 stops showing its logs in v7 console
##   - Logs route only to terminal zenka's buffer
##   - Observers can attach to terminal zenka instead
```

### Error Handling

The system provides clear, actionable error messages:

```perl
## Example: Try to start zenka without root
{
    success => 0,
    error => 'v7 requires root permissions - run as root or start v7 manually',
    requires_root => 1
}

## Example: Dependency failed
{
    success => 0,
    error => "dependency 'cube' failed: cube startup timeout",
    dependency_failed => 'cube',
    failed_at => 'cube'
}

## Example: Process detection timeout
{
    success => 0,
    error => "v7 startup timeout after 10s",
    pid => 12345  ## Process was started but not responding
}
```

### Best Practices

**✓ Do:**
- Use `zenki.parent.start` for all zenka launches
- Let the system handle dependency resolution automatically
- Check return values for `success` field
- Use `zenki status` to verify running processes
- Configure timeouts based on system performance
- Track statistics for debugging

**✗ Don't:**
- Manually start v7 → cube → zenka sequence
- Assume v7 is running without checking
- Hardcode process IDs or socket paths
- Start multiple v7 instances simultaneously
- Ignore error messages about permissions
- Skip dependency resolution with `auto_resolve => 0` unless necessary

### Integration with Existing Systems

**Session IDs:**
```perl
## After zenka connects to cube, it gets a session ID
## See: modules/base.get_session_id
## See: modules/base.async.get_session_id

my ($local_sid) = keys( $data{'user'}{$usr_str}{'session'}->%* );
$data{'session'}{$local_sid}{'cube_sid'} = $cube_session_id;
```

**Output Patterns:**
```perl
## V7 already has pattern matching for zenka output
## See: modules/v7.init_zenka_output_patterns

## Format: zenka_name::regex_pattern::flags
<v7.patterns.zenka_output>->{$zenka_name}->{$pattern_re} = $code_ref;
```

**IPC Commands:**
```perl
## TODO: Replace direct fork with IPC commands to v7
## Current: fork() → exec Protocol-7 zenka_name
## Future: IPC → v7.cmd.start_zenka → v7 manages process
```

---

## String Literals and Quoting

### Word Constants (Single Words)

Use **`qw|...|`** for single-word constants. This provides:
- Better syntax highlighting in code editors
- Faster visual scanning when reading code
- Easier spotting of typos in critical values (especially in state machines)

```perl
## ✓ CORRECT
'status' => qw| error |,
'poll'    => qw| w |,
'handler' => qw| httpd.handler.acme_request |,
'repeat'  => TRUE,
'mode'    => qw| server |,

## ✗ WRONG
'status' => 'error',
'poll'    => 'w',
```

### Multi-Word Strings

Use **`qq|...|`** for strings containing spaces or special characters:

```perl
## ✓ CORRECT
'error'   => qq| domain parameter required |,
'message' => qq| Certificate request submitted for processing |,
'type'    => qq| application/json; charset=utf-8 |,

## ✗ WRONG
'error' => qw| domain parameter required |,  # This won't work - qw is word-list mode
```

### When to Use Each

| Use Case | Syntax | Example |
|----------|--------|---------|
| HTTP status values | `qw\|...\|` | `qw\|error\|`, `qw\|success\|` |
| Log levels | `qw\|...\|` | `qw\|w\|` (watch), `qw\|r\|` (read) |
| Handler names | `qw\|...\|` | `qw\|httpd.handler.acme_request\|` |
| Error messages | `qq\|...\|` | `qq\| domain parameter required \|` |
| Content-Type headers | `qq\|...\|` | `qq\| application/json; charset=utf-8 \|` |
| HTTP connection modes | `qw\|...\|` | `qw\|close\|`, `qw\|keep-alive\|` |

---

## Exception Handling

### Use `$EVAL_ERROR` Instead of `$@`

When using `eval` blocks, always use **`$EVAL_ERROR`** for better readability:

```perl
## Requires: use English; (in base.init_code)

eval {
    my $cmd_result = <[base.protocol-7.command.send.local]>->($cmd_call);
};

## ✓ CORRECT
if ( $EVAL_ERROR ) {
    <[base.logs]>->( 1, '[%d] error calling letsencrypt: %s',
        $id, $EVAL_ERROR );
}

## ✗ WRONG
if ( $@ ) {
    # $@ is less readable than $EVAL_ERROR
}
```

### Advantages of `$EVAL_ERROR`

- More explicit and readable than `$@`
- Prevents accidental confusion with other Perl special variables
- Consistent with Protocol-7 naming conventions
- Available via `use English;` (already in base.init_code)

---

## Logging and Debugging

### Log Levels

Protocol-7 uses numeric log levels:

- **Level 0**: Critical errors and startup messages
- **Level 1**: Important events and errors
- **Level 2**: General information and status updates
- **Level 3**: Debug information (detailed tracing)

```perl
<[base.logs]>->( 0, 'critical startup message' );
<[base.logs]>->( 1, '[%d] error: %s', $id, $error );
<[base.logs]>->( 2, '[%d] processing request', $id );
<[base.logs]>->( 3, '[%d] detailed debug info: %s', $id, $debug_data );
```

### Logging Style

- **Lowercase messages**: Use lowercase for log content (not `Error: ...` but `error: ...`)
- **Harmony checking**: Messages should maintain consistent tone and style
- **Structured format**: Include session/connection ID when available: `[%d]`
- **Contextual information**: Always include relevant IDs and data for traceability

```perl
## ✓ CORRECT
<[base.logs]>->( 2, '[%d] ACME POST body complete: %d bytes',
    $id, length($current_body) );

## Avoid
<[base.logs]>->( 2, '[%d] Error: ACME body failed to process' );
```

### Verbosity Configuration

Set verbosity levels in zenka configuration files for different output targets:

```perl
## In configuration/zenki/httpd/start:
system.verbosity.zenka_buffer   = 3  ## In-memory buffer
system.verbosity.zenka_logfile  = 3  ## Persistent file logging
system.verbosity.zenka_console  = 3  ## Console output
```

### Accessing Logs

- **Live buffer**: `p7 httpd.show-buffer zenka` (in-memory, shows recent entries)
- **Persistent logs**: `/var/log/protocol-7/DESKTOP-FP4OP26.httpd.zenka.log` (written to disk)
- **Both**: Use verbosity settings to control what gets logged to each target

---

## Variable Management

### Avoiding Global State Shadowing

Protocol-7's zenka system uses global state hashes. **Never shadow these with local variables:**

```perl
## ✗ WRONG - Shadows global %data hash
my $data = ...;
$session->{'http'}->{'body'} = $data;

## ✓ CORRECT - Use descriptive local names
my $reply_data = ...;
$session->{'http'}->{'body'} = $reply_data;
```

### Important Global Hashes

These are part of the zenka's permanent state and should never be shadowed:

```perl
our %code;      ## Module code references (all compiled modules)
our %data;      ## Session and runtime data
our %keys;      ## Cryptographic keys
our %colors;    ## Color definitions for terminal output
```

### Local Variable Naming

Use descriptive names that clearly indicate purpose:

```perl
## ✓ GOOD
my $current_body = $session->{'buffer'}->{'input'} // '';
my $bytes_received = length($current_body);
my $reply_data = { ... };

## ✗ AVOID
my $buf = ...;       ## Too vague
my $d = ...;         ## Unclear
my $data = ...;      ## Shadows global
```

---

## JSON Processing

### JSON Decoder Pattern

Use state-cached JSON parsers for efficiency:

```perl
my $json_string = shift;

## Handle empty input
unless ( defined $json_string && length($json_string) > 0 ) {
    <[base.logs]>->( 3, 'json.decode: empty input' );
    return {};
}

## Use cached parser
state $json;
if ( !defined $json ) {
    $json = JSON::XS->new();
    $json->convert_blessed(1);
    $json->allow_nonref(1);
    $json->canonical(1);
    $json->relaxed(1);
    $json->pretty(1);
    $json->utf8(1);
}

## Decode with error handling
my $parsed_data;
eval {
    $parsed_data = $json->decode($json_string);
};

if ( $EVAL_ERROR ) {
    <[base.logs]>->( 1, 'json.decode error: %s [input: %s]',
        $EVAL_ERROR, substr( $json_string, 0, 100 ) );
    return {};
}

return defined $parsed_data ? $parsed_data : {};
```

### Key Features

- **State variable** for parser caching (initialized once)
- **Error handling** with eval block and `$EVAL_ERROR`
- **Graceful degradation** returns empty hash instead of crashing
- **Input logging** shows first 100 chars for debugging
- **Defensive coding** checks for undefined and empty input

---

## Asynchronous I/O and Event Handling

### Variable Watchers

Protocol-7 uses variable watchers to trigger handlers when data changes. This is essential for asynchronous operations:

```perl
## From base.session.init:
$session->{'watcher'}{'input_buffer'} = <[event.add_var]>->(
    {   'var'     => \$session->{'buffer'}->{'input'},     ## Reference to variable
        'handler' => qw| base.handler.input |,
        'poll'    => qw| w |,                              ## 'w' = watch for writes
        'repeat'  => TRUE,                                 ## Retrigger on each change
        'data'    => $id,
        'desc'    => sprintf( '[%d] input buffer', $id )
    }
);
```

### Creating Custom Watchers

When a variable needs to be monitored for changes (e.g., POST body accumulation):

```perl
## Check if incomplete
if ( $bytes_received < $content_length ) {
    unless ( defined $session->{'http'}->{'body_watcher'} ) {
        ## Set up watcher to retrigger when more data arrives
        $session->{'http'}->{'body_watcher'} = <[event.add_var]>->(
            {   'var'     => \$session->{'buffer'}->{'input'},
                'handler' => qq| httpd.handler.acme_request |,
                'poll'    => qq| w |,
                'repeat'  => TRUE,
                'data'    => $id,
                'desc'    => sprintf( '[%d] body accumulation watcher', $id )
            }
        );
    }
    return 0;  ## Return control to event loop
}

## When complete, stop the watcher
if ( defined $session->{'http'}->{'body_watcher'} ) {
    $session->{'http'}->{'body_watcher'}->stop();
    delete $session->{'http'}->{'body_watcher'};
}
```

### Key Points

- **Variable references** passed as `\$variable` not variable name
- **Poll modes**:
  - `w` = watch for writes (data changes)
  - `r` = watch for reads
  - `e` = watch for exceptions
  - `rt` = read with timeout
- **Repeat**: Set to `TRUE` for handlers that should retrigger on each change
- **Return 0** to give control back to event loop before handler completes

---

## HTTP Request Handling

### POST Body Accumulation Pattern

For HTTP endpoints that receive JSON or form data, always wait for the complete body:

```perl
## 1. Get Content-Length from headers
my $content_length = $headers->{'content-length'} // 0;

## 2. Check current body size
my $current_body = $session->{'buffer'}->{'input'} // '';
my $bytes_received = length($current_body);

## 3. If incomplete, set up watcher
if ( $bytes_received < $content_length ) {
    unless ( defined $session->{'http'}->{'body_watcher'} ) {
        $session->{'http'}->{'body_watcher'} = <[event.add_var]>->(
            {   'var'     => \$session->{'buffer'}->{'input'},
                'handler' => qq| httpd.handler.process_body |,
                'poll'    => qq| w |,
                'repeat'  => TRUE,
                'data'    => $id,
                'desc'    => sprintf( '[%d] body watcher', $id )
            }
        );
    }
    return 0;  ## Return to event loop
}

## 4. Body is complete - process it
$session->{'http'}->{'body'} = $current_body;
$session->{'buffer'}->{'input'} = '';

## 5. Clean up watcher
if ( defined $session->{'http'}->{'body_watcher'} ) {
    $session->{'http'}->{'body_watcher'}->stop();
    delete $session->{'http'}->{'body_watcher'};
}
```

### HTTP Response Format

```perl
## Prepare response
my $content_type = qq| application/json; charset=utf-8 |;
my $reply_code   = 200;
my $reply_body   = <[httpd.json.encode]>->( { ... } );

## Build headers
my $reply_header = {
    'Content-Type'   => $content_type,
    'Content-Length' => length($reply_body),
    'Connection'     => $session->{'http'}->{'close'}
        ? qw| close |
        : qw| keep-alive |,
};

## Send response
$session->{'buffer'}->{'output'}
    .= <[httpd.new_header]>->( $reply_code, $reply_header );
$session->{'buffer'}->{'output'} .= $reply_body;

## Return control
return $session->{'http'}->{'close'} ? 2 : 0;
```

### HTTP Status Codes

Use standard HTTP status codes:

- **200**: OK - Request successful
- **202**: Accepted - Request accepted for asynchronous processing
- **400**: Bad Request - Invalid parameters
- **404**: Not Found - Resource doesn't exist
- **405**: Method Not Allowed - Endpoint doesn't support method
- **413**: Payload Too Large - Body exceeds size limit
- **500**: Internal Server Error - Unexpected error

---

## File Operations

### Creating Directories with Proper Permissions

Use `base.file.make_path` with explicit permissions and ownership. This is essential for pre-initialization:

```perl
## In post_init modules (running as root before privilege drop):

my $dir = '/var/cache/letsencrypt';
<[file.make_path]>->( $dir, 0700, <system.amos-zenka-user> )
    or <[base.log]>->( 1, "error: failed to create directory: $dir" );
```

### Key Points

- **Use `base.file.make_path`** instead of `mkdir`
- **Set explicit mode** (0700 for private, 0755 for shared)
- **Set ownership** to appropriate user/group
- **Run in post_init** before `[root.drop_privs]` so execution happens as root
- **Log errors** for troubleshooting

### Post-Init Pattern

Create a `post_init` module that runs after module initialization but before privilege drop:

```perl
## modules/service.base.post_init

## Create required directories with proper permissions
<[service.base.check_dirs]>;

<[base.log]>->( 2, 'Service post-initialization complete' );
0;
```

Then reference it in configuration:

```perl
## In configuration/zenki/service/start:
[root.drop_privs:<service.system.user>]
```

---

## Console Commands

Console commands provide a simple command-line interface to zenka functionality. They're simpler than `.cmd.*` commands.

### Module Naming

```
modules/service.console.command-name
```

- **Prefix**: `module.console.*`
- **No $call parameter**: Unlike `.cmd.*` commands, console commands don't receive structured call data
- **Direct output**: Use `say` to output results

### Basic Console Command Structure

```perl
## [:< ##

# name  = debian.console.install-deps
# param = [zenka=<name>|minimal]
# descr = install dependencies for zenka or minimal v7 dependencies

my $param = shift;

## Process parameter
my $zenka_name;
if (!defined $param || $param eq 'minimal') {
    ## Install minimal dependencies
    system('bash', '/path/to/install_minimal.sh');
} else {
    ## Install for specific zenka
    $zenka_name = $param;
    my $result = <[module.install_for_zenka]>->({ zenka => $zenka_name });
}

## Output results
return say "::\n: ✓ Installation complete\n::";
```

### Console Command vs .cmd Command

| Feature | `.console.*` | `.cmd.*` |
|---------|--------------|----------|
| Parameter | `shift` (simple) | `$call` hashref (structured) |
| Output | `say` directly | Return hashref with mode/data |
| Use case | Simple CLI operations | Protocol-7 IPC commands |
| Access | Listed in zenka config | Protocol-7 command routing |

### Console Command Output Format

Use Protocol-7 box formatting for consistency:

```perl
## Simple message
return say "::\n: Message here\n::";

## Multi-line output
my @output;
push @output, "::";
push @output, ": Status Report";
push @output, ":";
push @output, ": Item 1: Details";
push @output, ": Item 2: More details";
push @output, "::";
return say join("\n", @output);
```

### Registering Console Commands

Add console commands to zenka configuration's access list:

```perl
## configuration/zenki/service/start

access.cmd.usr.cube = commands heart reload \
                      install-deps check-deps list-status *
```

---

## Init Code Constraints

### Circular Dependency Avoidance

**Critical**: During `init_code` execution, functions from the same module aren't yet available via `<[...]>` notation.

```perl
## modules/debian.parent.init_code

## ✗ WRONG - Function not yet exported during init
my $result = <[debian.parent.scan_zenki_dependencies]>;

## ✓ CORRECT - Skip initial scan, perform on first command use
## Scan will happen when console commands are called
```

### Why This Happens

1. Module file is executed
2. Code is defined
3. **init_code runs** ← We are here
4. Export happens at END of init_code
5. Function becomes available via `<[...]>`

### Init Code Best Practices

```perl
## modules/service.init_code

## 1. Initialize data structures
<service.registry.items> //= {};
<service.config.enabled> //= 1;

## 2. Load external dependencies
<[base.perlmod.autoload]>->('JSON::XS');

## 3. Create list infrastructure
<list.service-items> = {
    'var' => qw| data |,
    'key' => qw| service.registry.items |,
    ...
};

<[base.list.init]>->({
    'name' => qw| service-items |,
    'key_ref' => \$data{'service'}{'registry'}{'items'},
    'max_elements' => 1024
});

## 4. Call OTHER modules' functions (OK)
<[base.log]>( 2, 'Service initialization complete' );

## 5. DON'T call own module's functions
## (They aren't exported yet!)

## 6. Always return 0
0;
```

### Workarounds for Init-Time Operations

If you need to perform operations during init:

#### Option 1: Defer to First Use

```perl
## modules/service.init_code
<service.initialized> = 0;  # Flag for first-use scan

## modules/service.cmd.list
unless ( $data{'service'}{'initialized'} ) {
    <[service.scan_data]>;  # Now function is available
    $data{'service'}{'initialized'} = 1;
}
```

#### Option 2: Use Helper Sub

Define a helper sub WITHIN init_code:

```perl
## modules/service.init_code

sub _init_helper {
    my $data = shift;
    # Helper logic here
    return $result;
}

## Use helper
my $result = _init_helper($some_data);

## DON'T export helper - it's private to init_code
0;
```

#### Option 3: Separate Initialization Module

```perl
## modules/service.init_code
<service.data> //= {};
0;

## modules/service.parent.initialize
## This can be called after init completes
## Perform initialization
<[service.parent.scan_data]>;  # Functions available now

0;
```

### Module Code Structure

All modules are compiled by the parser and made available as code references. Just return the code and result at the end:

```perl
## modules/service.process_data

my $params = shift;
# Implementation
return $result;

# Always return 0 from module
0;

#AMOS7_SIGNATURE_PLACEHOLDER
```

The parser automatically:
1. Wraps your code in a subroutine
2. Registers it in `%code` using the module filename
3. Makes it available as `<[service.process_data]>->()`

---

## Code Organization

### Module Layering Pattern

Organize modules by responsibility:

```
base.*                  ## Core system functionality
  - base.init_code      ## Shared initialization
  - base.logs           ## Logging system
  - base.file.*         ## File operations
  - base.session.*      ## Session management

httpd.*                 ## HTTP server
  - httpd.http_get      ## GET request handler
  - httpd.http_post     ## POST request handler
  - httpd.handler.*     ## Endpoint-specific handlers
  - httpd.json.*        ## JSON encoding/decoding

service.*               ## Application-specific
  - service.base.*      ## Service initialization
  - service.cmd.*       ## Service commands
  - service.handler.*   ## Request handlers
```

### Related Functionality Grouping

Group related modules together:

```perl
## Certificate management
modules/httpd.handler.acme_request       ## Dispatcher
modules/letsencrypt.request-certificate  ## Implementation
modules/letsencrypt.parent.status        ## Status checking

## JSON handling
modules/httpd.json.encode                ## Encoding
modules/httpd.json.decode                ## Decoding
```

### Loading Modules in Zenka Start Files

In `configuration/zenki/<name>/start`, the `modules.load` list uses **namespace
names**, not individual module filenames. A single namespace entry loads all
modules sharing that prefix:

```
## correct — loads all radio.* modules (radio.init_code, radio.cmd.*, etc.)
modules.load = auth net protocol io.unix radio

## wrong — do NOT list individual subroutines
modules.load = auth net protocol io.unix radio.init_code radio.cmd.start \
               radio.cmd.stop radio.cmd.listen ...
```

The namespace entry (e.g. `radio`) is the dotted prefix shared by all modules
in that zenka. Adding new modules to the namespace automatically makes them
available without changing the start file.

### Module Dependencies

Keep dependencies clear and minimal:

```perl
## Good: Focused responsibility
httpd.handler.acme_request
  → calls: <[httpd.json.encode]>
  → calls: <[base.protocol-7.command.send.local]>
  → calls: <[base.logs]>

## Avoid: Circular dependencies
Module A → Module B → Module A
```

---

## Best Practices Summary

### Do's ✓

- **Module filenames become %code keys directly**: File `modules/zenki.parent.start` → key `'zenki.parent.start'`
- **Use `<[module.name]>` to call modules**: The bracketed name matches the module filename exactly
- **Remember: Module filename dots are LITERAL keys**: `<[foo.bar]>` → `$code{'foo.bar'}->()` (NOT nested!)
- **Pass arguments with `->(...)`**: `<[function]>->({...})` or `<[function]>->($arg)`
- **Use `<config.key>` in init_code**: Parser converts dots to nesting → `$data{'config'}{'key'}`
- **Use `$data{...}` for data access in regular modules** (not `<data...>`)
- Use `qw|...|` for single-word constants (better syntax highlighting)
- Use `qq|...|` for multi-word strings and messages
- Use `$EVAL_ERROR` instead of `$@` (available via `use English`)
- Create variable watchers for asynchronous I/O operations
- Use `base.file.make_path` for directory creation with permissions
- Set up post_init modules before privilege drop for initialization
- Log with appropriate level and include session IDs
- Handle empty input gracefully, return empty objects instead of crashing
- Use state-cached parsers for efficiency (JSON, regex, etc.)
- Check Content-Length and wait for complete body before processing HTTP requests
- **Defer initialization operations** that depend on own module's functions to first use
- **Always return 0** at the end of module files (the parser handles registration automatically)

### Don'ts ✗

- **Don't try to nest module filename keys** - File `modules/zenki.parent.start` creates key `'zenki.parent.start'`, NOT nested!
- **Don't write `$code{'module'}{'name'}->()`** - Module keys are single strings with dots, not nested hashes
- **Don't use `$code{...}->()` directly** - Use `<[module.name]>` syntax instead, the parser handles it
- **Don't confuse module dots with data dots** - Function calls preserve dots literally, data init converts them to nesting!
- **Don't use `<data...>` notation in regular modules** - only works in init_code, use `$data{...}` instead
- **Don't forget data dots DO convert to nesting** - `<foo.bar>` becomes `$data{'foo'}{'bar'}`, but `<[foo.bar]>` stays as `$code{'foo.bar'}->()`!
- **Don't call own module's functions during init_code** - they aren't exported yet
- **Don't try to store `<[function]>` as a reference** - The parser only supports immediate calls
- Don't shadow global hashes (`%code`, `%data`, `%keys`, `%colors`)
- Don't use `qw|...|` for strings with spaces (use `qq|...|` instead)
- Don't use `mkdir` directly (use `base.file.make_path` instead)
- Don't assume HTTP body is complete before Content-Length bytes arrive
- Don't ignore errors in JSON decoding (log them, handle gracefully)
- Don't create files/directories before privilege drop without root context
- Don't use `$@` instead of `$EVAL_ERROR` (less readable)
- Don't hardcode log levels without considering verbosity settings
- Don't forget to clean up variable watchers when they're no longer needed
- Don't log sensitive information (passwords, keys, etc.)

---

## Further Reading

- **Function Calls**: See [Function Calls and Data Access](#function-calls-and-data-access) for critical syntax patterns
- **Init Code**: See [Init Code Constraints](#init-code-constraints) for circular dependency avoidance
- **Console Commands**: See [Console Commands](#console-commands) for simple CLI interface patterns
- **Variable Watchers**: See `modules/base.session.init` for comprehensive watcher setup
- **HTTP Handlers**: See `modules/httpd.http_post` for POST request handling patterns
- **Event Loop**: See `modules/base.event.*` for event handling system details
- **Module System**: See `modules/base.init_code` for module loading and initialization
- **Logging**: Check `/var/log/protocol-7/` for actual log output patterns
- **Configuration**: See `configuration/zenki/*/start` for zenka-specific configurations
- **Dependency Management**: See `modules/debian.*` for example of complete zenka implementation

#,,.,,,,.,.,.,,,,,...,,.,,...,.,,,..,,.,,,,,,,..,,...,...,..,,..,,,,.,,..,,.,,
#54OHH2SUANVVBPNRREY7U25UWP7BFAW4W2SMYQAUCG3WWIGE3OV6BF7DGP2RQZA4N6D3RTVGBRR74
#\\\|T2TL4A33RBOOEZZFRTTHUG2BJQU57PMQZ4W3CWK5FWCN7S4BZ56 \ / AMOS7 \ YOURUM ::
#\[7]WZWE4BPCJ4JS6KGF3BQC3KGY3DFKP2SGHT4GBUWHVPBUOQE7WKAI 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
