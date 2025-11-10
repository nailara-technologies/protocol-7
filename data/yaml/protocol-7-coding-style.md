# Protocol-7 Coding Style Guide

A comprehensive guide to coding conventions, best practices, and patterns for Protocol-7 module development.

## Table of Contents

1. [Module Structure](#module-structure)
2. [Function Calls and Data Access](#function-calls-and-data-access)
3. [String Literals and Quoting](#string-literals-and-quoting)
4. [Exception Handling](#exception-handling)
5. [Logging and Debugging](#logging-and-debugging)
6. [Variable Management](#variable-management)
7. [JSON Processing](#json-processing)
8. [Asynchronous I/O and Event Handling](#asynchronous-io-and-event-handling)
9. [HTTP Request Handling](#http-request-handling)
10. [File Operations](#file-operations)
11. [Console Commands](#console-commands)
12. [Init Code Constraints](#init-code-constraints)
13. [Code Organization](#code-organization)

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

**Critical**: The `<[...]>` notation returns a **code reference**, not the result of calling the function.

```perl
## ✗ WRONG - Returns code reference, doesn't call function
my $result = <[debian.parent.scan_zenki_dependencies]>;

## ✓ CORRECT - Calls function with no arguments
my $result = <[debian.parent.scan_zenki_dependencies]>();

## ✓ CORRECT - Calls function with arguments
my $result = <[debian.parent.install_missing]>->({
    zenka => $zenka_name,
    prefer_debian => 1
});
```

### Function Call Patterns

| Pattern | Use Case | Example |
|---------|----------|---------|
| `<[func]>()` | Call with no arguments | `<[base.log]>()` |
| `<[func]>->($arg)` | Call with single argument | `<[base.log]>->(2, "message")` |
| `<[func]>->({...})` | Call with hash arguments | `<[install]>->({zenka => 'v7'})` |
| `<[func]>` | Get code reference | `$code_ref = <[func]>` |

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

### Key Distinction

- **`<[...]>`** = Code reference access (for calling functions)
- **`<...>`** = Data initialization (only in init_code)
- **`$data{...}`** = Data access (in regular modules)

### Common Mistakes and Fixes

```perl
## MISTAKE 1: Missing parentheses
my $result = <[scan_function]>;  # ✗ Returns reference
my $result = <[scan_function]>(); # ✓ Calls function

## MISTAKE 2: Wrong data access in regular module
my $val = <service.data.value>;           # ✗ Won't work
my $val = $data{'service'}{'data'}{'value'}; # ✓ Correct

## MISTAKE 3: Trying to use <...> for code
<service.function>();  # ✗ Wrong - <...> is for data
<[service.function]>(); # ✓ Correct - <[...]> is for code
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
my $result = <[debian.parent.scan_zenki_dependencies]>();

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
<[base.log]>->( 2, 'Service initialization complete' );

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
unless ( <service.initialized> ) {
    <[service.scan_data]>();  # Now function is available
    <service.initialized> = 1;
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
sub service_parent_initialize {
    ## Perform initialization
    <[service.parent.scan_data]>();  # Functions available now
}
$code{'service.parent.initialize'} = \&service_parent_initialize;
0;
```

### Module Export Pattern

All modules must export their function and return 0:

```perl
## modules/service.process_data

sub service_process_data {
    my $params = shift;
    # Implementation
    return $result;
}

## Export
$code{qw| service.process_data |} = \&service_process_data;

## Always return 0 from module
0;

#AMOS7_SIGNATURE_PLACEHOLDER
```

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

- **Always add `()` when calling functions**: `<[function]>()` not `<[function]>`
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
- **Always export functions** with `$code{'module.name'} = \&function_name`
- **Always return 0** at the end of module files

### Don'ts ✗

- **Don't forget `()` when calling functions** - `<[func]>` returns reference, not result
- **Don't use `<data...>` notation in regular modules** - only works in init_code
- **Don't call own module's functions during init_code** - they aren't exported yet
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

#,,,,,,.,,,.,,..,,...,.,,,.,,,,.,,,..,,.,,.,,,.,.,...,...,,,.,.,,,.,,,.,.,,..,
#IIC5I3N6SBLS3V7ULLD6WOKXVPZA27XUDNWO4EO755E7QUEJ57KNMUIITNEIOEMHB6DFECGS4AXGS
#\\\|EVR56TJSGLGMM56DSUPXANHX56GN4SNFWNGNZBSMAYD7ATVTCTA \ / AMOS7 \ YOURUM ::
#\[7]XVR7L36YY4X5UDE4Q2D5JZGU4C6XVAZOST7PGB3K2VDLB5BRRWBQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
