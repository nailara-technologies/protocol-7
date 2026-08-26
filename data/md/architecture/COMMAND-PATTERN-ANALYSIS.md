# Protocol-7 Command Patterns: Console vs Network

## Overview

Protocol-7 has two types of commands:
- **`.console.*`** - CLI commands (one-off execution, user-facing output)
- **`.cmd.*`** - Network commands (persistent zenka, structured responses)

Both can coexist in the same zenka for hybrid mode operation.

## Key Differences

### Parameter Passing

#### Console Commands
```perl
# Takes raw string from command line
my $command_params = shift // '';
$command_params =~ s,^ *| *$,,;  # trim whitespace

# Custom parsing needed for each command
my ($name, $file) = split m|\s+|, $command_params, 2;
foreach my $param_str ( split m|\s+|, $command_params ) {
    if ($param_str eq '-plain') { $file_plain = TRUE }
}
```

**Characteristics:**
- Parameters are whitespace-separated strings
- Manual parsing for flags, options, arguments
- No formal parameter structure
- Command line friendly (user types: `keys gen-file-seed-key mykey /path/seed.bin -plain`)

#### Network Commands
```perl
# Takes hash reference with named parameters
my $params = shift || {};
my $domain = $params->{domain} || $params->{host};

# Or array of arguments in $$call{'args'}
my $task_id = length( $$call{'args'} ) ? $$call{'args'} : undef;
```

**Characteristics:**
- Parameters are named hash keys
- Formal structure: `{ domain => 'example.com', revoke_cert => 1 }`
- Called via network routing: `httpd.cmd.del-vhost domain=example.com revoke_cert=1`
- Programmatic interface (system-to-system communication)

### Return Values

#### Console Commands
```perl
# Returns: scalar TRUE/FALSE (status), or plain text output (printed to stdout)
say "Output line 1";
say "Output line 2";
return;

# Or explicit exit
<[base.exit]>->(qw| 0110 |, 'Error message', 0);

# Direct print
print "\n  << Generated key successfully >>\n\n";
return TRUE;
```

**Characteristics:**
- Output via `say`/`print` (human-readable)
- Return value for exit status
- Color codes, formatting for terminal display
- Examples:
  - `keys.console.gen-file-seed-key` - prints "Generated key" with details
  - `sourcecode.console.test-sign-and-verify` - detailed line-by-line output

#### Network Commands
```perl
# Returns: structured hash with 'mode' and 'data' keys
return {
    'mode' => qw| true |,
    'data' => 'User name and session'
};

# Error response:
return {
    'success'  => FALSE,
    'error'    => 'domain parameter required',
    'usage'    => 'httpd.del-vhost domain=example.com [revoke_cert=1]'
};

# Complex response with actions:
return {
    success => TRUE,
    domain  => $domain,
    actions => ['certificate_revoked', 'symlink_removed', 'content_removed']
};
```

**Characteristics:**
- Structured response: `{ mode => 'true'|'false'|'size', data => ... }`
- No direct printing (data is serialized/returned)
- Computer-readable (JSON/YAML compatible)
- Success/error indicators via hash keys
- Optional logging via `<[base.log]>->(level, message)`

### Execution Context

#### Console Commands
```perl
# Called from: [base.call.console_command:<command> <args>]
# Execution: Synchronous, one-shot
# Environment: Direct access to terminal, user interaction
# Lifecycle: Load module → execute → exit

# Can do blocking operations:
my $password = AMOS7::TERM::read_password_repeated('prompt');  # User prompt
<[base.exit]>->(qw| 0110 |);  # Exit when done
```

**Use Cases:**
- Key generation (requires password input)
- Configuration verification (needs user confirmation)
- Setup/maintenance tasks
- Manual operations

#### Network Commands
```perl
# Called from: Network routing (zenka.cmd.command)
# Execution: Async-safe, quick return expected
# Environment: No terminal access, no user interaction
# Lifecycle: Running in persistent zenka, responds to requests

# Cannot do blocking operations:
# - No password prompts
# - No user interaction
# - Must return quickly
# - Works with timeouts

# Calls other commands (delegation):
my $revoke_result = <[letsencr.cmd.revoke]>->(
    { domain => $domain, reason => 5 }
);
```

**Use Cases:**
- Status queries
- Configuration changes
- Delegation to other services
- Structured data responses

## Real Example Comparison

### Task: Encrypt a key file

#### Console Approach (keys.console.gen-file-seed-key)
```
User runs: ./bin/Protocol-7 keys gen-file-seed-key mykey /path/to/seed.bin

Module execution:
1. Parse parameters (mykey = key name, /path/to/seed.bin = file path)
2. Ask user for encryption password (BLOCKING)
   > "key encryption password: "
3. Ask for seed password (BLOCKING)
   > "additional file seed password: "
4. Generate entropy from file
5. Print progress/results:
   ":: [ created key 'mykey' SHA256:abc...def in '/home/user/.protocol-7/keys' ]"
6. Return TRUE (exit code 0)
```

**Why console:**
- User must provide sensitive passwords interactively
- Multi-step confirmation process
- Detailed human-readable output
- One-time operation (not persistent service)

#### Network Approach (would need to exist)
```
Hypothetical: p7 keys.cmd.gen-seed-key name=mykey seed_file=/path/to/seed.bin

Module execution:
1. Parse parameters from hash
2. Validate parameters
3. Generate entropy (offline, no user interaction)
4. Return structured response:
   {
       success => TRUE,
       key_name => 'mykey',
       key_path => '/home/user/.protocol-7/keys/mykey',
       fingerprint => 'SHA256:abc...def'
   }
```

**Why cmd (if it existed):**
- Automated key generation in scripts
- Integration with configuration management
- No user interaction needed
- Structured response for parsing

## Parent/Child Communication Pattern

Parent and child processes both use `.cmd.` pattern for inter-process communication:

### Parent Command (simple query)
```perl
# weather.parent.cmd.location
return { 'mode' => qw| true |, 'data' => $city_str }
```

### Child Command (heavy lifting)
```perl
# weather.child.cmd.request-data - called by parent
my ($status_code, $json_data) =
    <[weather.child.query_api]>->("$q_str?$params");

# Handles large data via freeze() serialization
return {
    'mode' => qw| size |,
    'data' => freeze($json_data) . "\n"
};
```

**Pattern:**
- Parent receives network request
- Parent routes to child for heavy work
- Child returns structured data
- Parent packages for network response

## Dual-Mode Zenka Example

### Same zenka, two interfaces:
```
coding zenka:
- coding.console.* - would be one-off CLI commands (if they existed)
- coding.cmd.*     - network commands (status, submit, budget)
```

### Routing:
```
Direct CLI:     ./bin/Protocol-7 coding submit <task description>
Network:        p7 coding.cmd.submit task_desc="description"
Via v7:         coding.cmd.submit routed through v7 zenka
```

## Testing Command Examples

### 1. Simple Status Query
**Module:** `base.cmd.whoami` (7 lines)
- **Input:** Implicit (session context)
- **Output:** User + session ID
- **Use:** Verify identity

### 2. Parameter-Based Query
**Module:** `coding.cmd.status` (89 lines)
- **Input:** Optional task_id parameter
- **Output:** Queue stats or task details
- **Use:** Monitor task progress

### 3. Multi-Step Operation
**Module:** `httpd.cmd.del-vhost` (159 lines)
- **Input:** domain, revoke_cert, keep_content flags
- **Output:** Actions list, errors
- **Use:** Virtual host lifecycle
- **Complexity:** 6 steps, error handling, delegation

### 4. Blocking User Interaction
**Module:** `keys.console.gen-file-seed-key` (108 lines)
- **Input:** key_name, file_path, -plain, -U flags
- **Interaction:** Password prompts (BLOCKING)
- **Output:** Human-readable creation confirmation
- **Use:** Manual key generation

### 5. File Processing
**Module:** `sourcecode.console.test-sign-and-verify` (148 lines)
- **Input:** File pattern
- **Processing:** Create key, sign files, verify (loops)
- **Output:** Detailed progress and results
- **Use:** Manual testing/verification

### 6. Child Process API
**Module:** `weather.child.cmd.request-data` (112 lines)
- **Input:** station_id, type (current|hours|days)
- **Processing:** API query, data transformation
- **Output:** Frozen JSON for parent
- **Use:** Heavy lifting in child process

## Hybrid Mode Challenges

### Issue 1: Parameter Format Mismatch
```perl
# Console expects: "value1 value2 -flag"
# Cmd expects: { key => 'value1', flag => 1 }
# Solution: Parse both formats or keep separate commands
```

### Issue 2: Blocking Operations
```perl
# Console can do: AMOS7::TERM::read_password()
# Cmd cannot do: Would block entire zenka
# Solution: Pre-validate in cmd, password handling in console only
```

### Issue 3: Output Format
```perl
# Console prints: "Key created: abc123"
# Cmd returns: { success => TRUE, key_id => 'abc123' }
# Solution: Different command implementations
```

## Recommendations

1. **Keep separation of concerns:**
   - `.console.*` for interactive operations
   - `.cmd.*` for programmatic operations

2. **Reuse implementation where possible:**
   - Common logic in shared modules
   - Wrappers in console/cmd for format conversion
   - Example: `coding.budget.track_tokens` (shared) used by `coding.cmd.status`

3. **Document parameter format:**
   - Console: "key <name> <filepath> [-plain] [-U]"
   - Cmd: "{ name => ..., filepath => ..., plain => boolean }"

4. **Error handling strategy:**
   - Console: print to stdout + exit code
   - Cmd: return { success => FALSE, error => message }

5. **Testing framework:**
   - Test console with manual invocation
   - Test cmd with network routing simulation
   - Test hybrid with both invocation methods

#,,..,.,,,,,.,,,.,..,,,,,,.,.,,.,,,,.,,..,.,.,..,,...,...,..,,,.,,...,...,...,
#XG4SGISSGLJATXNUM7SHGPPEUBXJQA2N4TYRWACXORCDZEUAK7AJCJ2RCB2ZA32HOT732OFYKST3S
#\\\|KDPPYQ5YDGALULFWPFKTKHPG7LCLWWNEAR23BY6GH2L2OTBSF2I \ / AMOS7 \ YOURUM ::
#\[7]3G7GDSGU77QPKQLRCXRO5SHSM7S5RUFH3GD66D74GTIYMEE2LACA 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
