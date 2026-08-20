# Protocol-7 Hybrid Mode Startup Analysis

## Overview
Protocol-7 zenka can be started in multiple modes:
1. **By v7 (managed)** - Started as subprocess by v7 zenka, running as root initially, privilege drop expected
2. **By current user (standalone)** - Direct invocation, runs with current user privileges
3. **By root (manual)** - Manual root invocation, privilege drop expected
4. **Console-only vs Network** - Some zenka are CLI commands only, others are network daemons

## Startup Patterns Identified

### Console-Only Zenka (one-off execution)
Examples: `keys`, `sourcecode`, `configure`, `work`

Pattern:
```
[load_config_file:'shared-params']
[load_modules:<modules.load>]
[init_modules]
[base.call.console_command:<system.args>]  # Execute command, then exit
```

**Characteristics:**
- No privilege drop
- No network loop
- Exit after console command completes
- No v7 management

**Hybrid Mode Status:** ✓ Consistent
- Always runs as invoking user
- Safe for single-command execution

### Network Daemon Zenka (persistent services)
Examples: `v7`, `httpd`, `cube`, `web`, `channels`

Pattern:
```
[load_config_file:'shared-params']
[load_modules:<modules.load>]
[init_modules]
[root.drop_privs:<target_user>]  # Drop from root to safe user
[base.net.connect:'unix']         # Connect to network
[zenka.loop]                       # Stay running
```

**Characteristics:**
- Privilege drop to dedicated user
- Network connectivity
- Persistent event loop
- v7 management (heartbeat, restart)

**Hybrid Mode Status:** ✓ Consistent
- Started by v7 as root → drops privileges
- Started standalone by user → skips privilege drop (already non-root)

### Hybrid Anomaly Cases ⚠️

#### Case 1: coding zenka
**Location:** `cfg/zenki/coding/start`

**Issue:** Privilege drop is **COMMENTED OUT**
```perl
# [root.drop_privs:<system.amos-zenka-user>]
```

**Startup Scenarios:**
| Scenario | User | Behavior | Expected | Issue |
|----------|------|----------|----------|-------|
| Started by v7 | root → amos-zenka-user | Stays root | Drops to amos-zenka-user | ⚠️ RUNS AS ROOT |
| Standalone by user | current | Stays current user | Same | ✓ OK |
| Manual root start | root | Stays root | Drops to amos-zenka-user | ⚠️ RUNS AS ROOT |

**Consequences:**
- Network port binding restrictions removed (security issue)
- File operations perform with root privileges
- Access control may not work as designed
- v7 monitoring/restart may not work properly
- Other zenka may not trust coding (wrong UID)

**v7 Configuration:** See `cfg/zenki/coding/zenka-startup.v7`
```
start_mode = stdin-zenka
[base.auth.set_v7_key:<random-key>]
[v7.callback.register_ondemand]
```
- Coding IS managed by v7 (on-demand startup)
- Expects authentication via v7-provided key
- Will be started as root subprocess by v7

#### Case 2: data zenka
**Location:** `cfg/zenki/data/start`

**Issue:** Same as coding - privilege drop is **COMMENTED OUT**
```perl
# [root.drop_privs:<system.amos-zenka-user>]
```

**Status:** Same hybrid mode anomaly as coding

## User Tracking Variables

### Static System Users
- `<system.amos-zenka-user>` - Protocol-7 service user (typically "amos-zenka")
- `<system.AMOS-user>` - Desktop/session user for GUI apps
- `<dbus.privs_user>` - DBus user for DBus zenka
- `<httpd.system.user>` - HTTP server user (typically "httpd")

### Dynamic User Detection
- `<system.zenka-user.current>` - Current invoking user (special for X-11)
- `<cube.local.port>` - Port awareness (used in privilege drop context)

**Pattern:** Desktop/X11-related zenka use `<system.AMOS-user>` which requires user auto-discovery

## Consistent Startup Behavior Design

### Required for Hybrid Mode Safety:
1. **Privilege Drop Rule:**
   - If started as root with `[root.drop_privs:...]` → drop to target user
   - If started as non-root → skip (already correct user) or verify/warn
   - If no privilege drop defined → document why (security review)

2. **User Context Stability:**
   - Zenka started by v7 should have predictable final user
   - Zenka started standalone should have predictable final user
   - No scenario should result in privilege elevation
   - No scenario should result in root execution of untrusted code

3. **v7 Management Compatibility:**
   - v7-managed zenka must work when started as root subprocess
   - v7-managed zenka must handle privilege drop before network operations
   - v7 must be able to monitor/restart zenka in target user context

## Recommendations

### Immediate Fixes
1. **coding/start** - Uncomment privilege drop:
   ```perl
   [root.drop_privs:<system.amos-zenka-user>]
   ```

2. **data/start** - Uncomment privilege drop:
   ```perl
   [root.drop_privs:<system.amos-zenka-user>]
   ```

3. **Audit other zenka** - Review those using `<system.AMOS-user>` for:
   - Whether auto-discovery is needed
   - Whether user context changes between startup modes
   - Whether warnings are appropriate

### Testing Framework Needed
1. **Startup mode tests:**
   - Start as root (direct)
   - Start as v7-subprocess (managed)
   - Start as current user (standalone)

2. **Behavior verification:**
   - Verify final user (check $< and $> in Perl)
   - Verify privilege drop occurred
   - Verify network operations work with target user
   - Verify v7 can monitor/restart

3. **Consistency checks:**
   - Same zenka startup mode should always result in same user
   - No warnings or security issues for any startup mode

## Console vs Network Operations
- **Console commands:** Can execute with any user (caller's privileges)
- **Network services:** MUST run as appropriate user for security/functionality
- **Mixed zenka:** Usually split responsibility (e.g., k eys = CLI only, cube = network only)

## Current Status
- **Console-only zenka:** ✓ Hybrid mode safe
- **Network daemon zenka:** ⚠️ 2 known anomalies (coding, data)
- **Desktop/X11 zenka:** ? Requires user auto-discovery (needs testing)

#,,.,,,.,,,,.,...,.,,,..,,,..,.,.,..,,.,.,,.,,..,,...,...,,..,,..,...,..,,..,,
#U4LZRC5WOLJ2ND423SD2QMS32SXW5LXGXKTUTZEJ74FZLU4XWXRPBQLM6OQU5TA5ADTHULDLFAY42
#\\\|NNMLI3HHYUULCYET3RVHGVBDDO4WNGXZI2WZMAVCM2CQZR6ZQJA \ / AMOS7 \ YOURUM ::
#\[7]D5GL7HYDXEL52OTZJIJICABUDWAF5QPZAUKDEMOWZU7V4ARCT2DQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
