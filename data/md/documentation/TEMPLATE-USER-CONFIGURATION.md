# Protocol-7 Template-Based User Configuration System

## Overview

Protocol-7 uses a **template-based configuration system** to make authentication and authorization files **user-agnostic**. This allows administrators to change their system username without editing multiple configuration files.

## Why Templates Exist

### Problem
Without templates, every configuration file contains hardcoded usernames:
```
# Old way (hardcoded)
auth.setup.usr.unix-taeki = :unix:root,:unix:taeki
auth.setup.usr.taeki      = :unix:root :unix:taeki
access.cmd.usr.unix-taeki = ** ..*..**
```

**Problem**: If the admin changes from `taeki` to `newname`, ALL these files need editing. This creates:
- Large git diffs for a simple user change
- Risk of missing a hardcoded reference
- Configuration management complexity

### Solution: Template Variables

```
# New way (template-based)
auth.setup.usr.unix-<admin-user> = :unix:<system.admin-user>,:unix:root
auth.setup.usr.<admin-user>      = :unix:<system.admin-user>,:unix:root
access.cmd.usr.unix-<admin-user> = ** ..*..**
```

**Single source of truth** in `cfg/system-user-map`:
```
system.admin-user  =  taeki   # Change here, everything updates!
```

## How Templates Work

### Two-Level Expansion

**Level 1: Configuration Parse Time** (`base.parser.config`)
- When zenka loads configuration files
- **Both keys AND values** are expanded
- Templates like `<admin-user>` and `<system.admin-user>` are replaced with actual values

**Level 2: Runtime Authentication** (`plugin.auth.unix`)
- If someone manually authenticates with template syntax
- Expands templates at auth time for robustness
- Ensures manual auth attempts work with templates

### Template Syntax

#### System Variables (with dot notation)
```
<system.admin-user>    → Expands to $data{'system'}{'admin-user'} value
<system.AMOS-user>     → Expands to $data{'system'}{'AMOS-user'} value
```

#### Special User Templates (single word)
```
<admin-user>      → Mapped to <system.admin-user> (via base.access.special-user-map)
<unix-admin>      → Creates unix-prefixed version of admin-user (unix-taeki)
<AMOS-user>       → Mapped to <system.AMOS-user>
<unix-AMOS-user>  → Creates unix-prefixed version
```

### Configuration File Examples

#### `cfg/system-user-map` (source of truth)
```
system.admin-user       =  taeki
system.AMOS-user        =  protocol-7
```

#### `cfg/zenki/cube/auth.users` (uses templates)
```
# Taeki admin user setup
auth.setup.usr.unix-<admin-user> = :unix:root,<system.admin-user>
auth.setup.usr.<admin-user>      = :unix:root,<system.admin-user>

# Alternative expanded at parse-time to:
# auth.setup.usr.unix-admin-user = :unix:root,taeki
# auth.setup.usr.admin-user      = :unix:root,taeki
```

#### `cfg/zenki/cube/access.users` (uses templates)
```
access.cmd.usr.unix-<admin-user> = ** ..*..**
```

## Benefits of Template-Based Configuration

### 1. User-Agnostic Configuration
- Change admin user once in `system-user-map`
- All files automatically reference the new user
- No search-and-replace across multiple files

### 2. Minimal Git Diffs
- Changing admin from `taeki` to `alice`:
  - **Old way**: Diffs show changes in 10+ configuration files
  - **New way**: Diff shows change in `system-user-map` only
  ```
  -system.admin-user = taeki
  +system.admin-user = alice
  ```

### 3. Centralized Administration
- Single location to manage system users
- Clear mapping between logical roles (admin) and actual unix users (taeki)
- Easy to audit who has what access

### 4. Security via Separation
- `<admin-user>` for shell interaction (`./bin/nshell`)
- `<unix-admin-user>` for CLI access (`p7` command with unix socket)
- Different authentication contexts, possible different permissions
- Can terminate all CLI sessions without affecting shell sessions

## Implementation Details

### Template Expansion in Config Parser

**File**: `src/base.parser.config` (lines 115-124)

When parsing a config line like:
```
auth.setup.usr.unix-<admin-user> = :unix:<system.admin-user>,:unix:root
```

The parser:
1. **Expands key** `unix-<admin-user>` → `unix-admin-user`
   - Calls `base.access.special-user-map` with template
   - Replaces template with expanded value

2. **Expands value** `:unix:<system.admin-user>` → `:unix:taeki`
   - Replaces `<system.admin-user>` with the actual value from `$data{'system'}`

3. **Stores result** `auth.setup.usr.unix-admin-user = :unix:taeki,:unix:root`

### Template Expansion at Runtime

**File**: `src/plugin.auth.unix` (lines 43-52)

When user authenticates via nshell/p7:
```
auth <admin-user>
```

The handler:
1. Detects template brackets `<...>`
2. Calls `base.access.special-user-map` to expand
3. Uses expanded name for config lookup
4. Provides robustness if admin uses template in manual auth

### Special User Map

**File**: `src/base.access.special-user-map`

Maps template names to actual values:
```perl
my $user_map = {
    qw| <admin-user> | => <system.admin-user>,
    qw| <unix-admin> | => sprintf('unix-%s', <system.admin-user>),
    ...
};
```

## Practical Example: Admin User Change

### Scenario
Team member `taeki` leaves, replaced by `alice`.

### Old System (No Templates)
```bash
# Search and replace across files
find configuration -name "*.users" -o -name "*.zenki" \
  | xargs sed -i 's/taeki/alice/g'

# Review 50+ file changes
git diff

# Risk: Might have missed one, might have replaced wrong taeki
```

### New System (With Templates)
```bash
# Single change
echo "system.admin-user = alice" > cfg/system-user-map

# Review minimal diff
git diff cfg/system-user-map

# list sessions shows alice, unix-alice automatically
# All auth.users files unchanged
```

## Unix Domain Socket Authentication Pattern

Templates enable a sophisticated authentication pattern:

```
User taeki runs: p7 whoami
  ↓
Protocol-7 binary detects 'unix-' context
  ↓
Authenticates as `unix-taeki` (unix domain socket)
  ↓
Config has: auth.setup.usr.unix-<admin-user> = :unix:<system.admin-user>
  ↓
Parser expanded this to: auth.setup.usr.unix-admin-user = :unix:taeki
  ↓
Authentication succeeds
  ↓
list sessions shows: taeki, unix-taeki (both visible as separate sessions)

Same user can run: ./bin/nshell -u taeki
  ↓
Authenticates as `taeki` (interactive shell)
  ↓
Different session context, possibly different permissions
```

## Related Modules

- **`base.parser.config`**: Parses and expands templates at startup
- **`base.access.special-user-map`**: Maps template names to actual values
- **`plugin.auth.unix`**: Handles runtime template expansion for authentication
- **`src/base.session.check_remaining`**: Session state tracking with templates

## Files Using Templates

- `cfg/zenki/cube/auth.users` - User authentication setup
- `cfg/zenki/cube/auth.zenki` - Zenka authentication
- `cfg/zenki/cube/access.users` - User access permissions
- `cfg/zenki/cube/access.zenki` - Zenka access permissions
- Other zenka configs that reference admin users

## Parser Implementation & Fixes (November 2025)

### Critical Regex Pattern Fix

**Issue**: The parser regex patterns contained escaped angle brackets that prevented template matching:
```perl
# BROKEN (lines 116, 129 before fix):
while ( $_name =~ m|(?<!')\<([\w_-]+)>(?!')| ) {   # \< breaks pattern
while ( $_value =~ m|(?<!')\<([\w_-]+(\.[\w_-]+)+)>(?!')| ) {
```

**Root Cause**: The backslash `\` before `<` was escaping the angle bracket, making the regex unable to match template syntax like `<admin-user>`.

**Solution**: Remove the unnecessary escaping:
```perl
# FIXED (commit 7c21c839c):
while ( $_name =~ m|(?<!')<([\w_-]+)>(?!')| ) {    # Correct pattern
while ( $_value =~ m|(?<!')<([\w_-]+(\.[\w_-]+)+)>(?!')| ) {
```

**Why this works**: In Perl regex, angle brackets `<>` have no special meaning and don't require escaping. The pattern now correctly matches template syntax.

### Successful Testing Results (November 14, 2025)

Authentication testing with live cube zenka confirmed all template expansions working:

```bash
# Test environment
export PROTOCOL_7_UNIX_PATH="/var/run/.7/UNIX/NIW7OAQ"
cd /home/user/protocol-7

# Test results
$ ./bin/p7 whoami
unix-root 7792712

$ USER=kitten ./bin/p7 whoami
unix-kitten 2307702

$ USER=taeki ./bin/p7 whoami
unix-taeki 5314413  ✓ NOW WORKING WITH TEMPLATES!
```

### Configuration Updates

Template syntax in `cfg/zenki/cube/auth.users` (lines 8-9):
```perl
## [ taeki + unix-taeki setup - TEMPLATE-BASED ]
auth.setup.usr.<admin-user> = :unix:<unix-admin>,:unix:<admin-user>
auth.setup.usr.<unix-admin>  = :unix:<unix-admin>,:unix:<admin-user>
```

These now correctly expand via the fixed parser to:
```perl
auth.setup.usr.admin-user = :unix:unix-taeki,:unix:taeki
auth.setup.usr.unix-admin  = :unix:unix-taeki,:unix:taeki
```

### Related Commits

- `7c21c839c`: fix: Remove escaped angle brackets in regex patterns for template expansion
- `6332d1062`: fix: Template-based user configuration and base parser refinements
- `043981267`: fix: Use consistent template syntax for taeki/unix-taeki authentication
- `51b86963a`: fix: Correct invalid template name <unix-admin-user> to <unix-admin>

## Future Enhancements

- Template versioning (different admin levels: `<admin-user>`, `<super-admin>`)
- Conditional expansion based on context (X11 vs headless)
- Template validation at startup
- Template dependency analysis (detect unused templates)
- Enhanced error reporting for unrecognized templates

#,,,.,...,..,,,,.,,,.,..,,,..,,,,,..,,,,,,,,.,..,,...,.,,,.,,,,..,,.,,,,.,.,.,
#6TVF25GODMR6UJYWHFB66IK2EI6REVQYWCJ7XQ6TD4XUWWL2DFIGMGIFU5LLFNZ56UMTJUF4DQZXA
#\\\|OROZO3BCQAYTIVK6ZB765RHULMWUQSQ5WKQXAEMFB4N5QYD5Q3D \ / AMOS7 \ YOURUM ::
#\[7]OR3LYCRDMRZ3Y4UXVAJQ2FMUMJHYJIHN55SCHJNQM4XAVLFX4SDY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
