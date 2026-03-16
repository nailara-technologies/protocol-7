# Level 3: Debian Zenka Idle Shutdown Optimization

## Discovery: On-Demand Timeout Configuration

Protocol-7's on-demand zenka can auto-shutdown after idle time using:

```perl
[base.zenki.set_ondemand_timeout:SECONDS]
```

**Examples** from existing zenka:
- `image2html`: 420 seconds (7 minutes)
- `calc`: 4200 seconds (70 minutes)
- `mod-test`: 4200 seconds (70 minutes)
- `ffmpeg`: 42 seconds
- `geoloc`: 13 seconds
- `download`: 33 seconds

---

## Debian Zenka Profile

Current debian zenka configuration:

```perl
dependencies = cube
start.on-demand = 1    # ✓ Already on-demand! (only starts when needed)
restart.disabled = 1   # ✓ Already manual restart only
# Missing: idle timeout configuration for auto-shutdown
```

**Already Perfect for Level 3**:
- `start.on-demand = 1` - Starts only when dependency checks trigger
- `restart.disabled = 1` - Won't auto-restart if it shuts down
- Just needs: idle timeout to auto-shutdown when done

**Use Case**:
- Starts when Level 3 dependency installation needed
- Handles package installation/verification
- Shuts down automatically when done

**Perfect Match for Idle Timeout**:
- Not continuously running
- On-demand activation only
- Can shut down after operations complete
- Saves resources

---

## Recommended Configuration

Add idle timeout to debian zenka startup configuration:

```perl
# In configuration/zenki/debian/zenka-startup.v7

dependencies = cube
start.on-demand = 1
restart.disabled = 1

: zenka-init :
  [base.auth.set_zenka_key:'<{cube.key}>']
  [base.zenki.set_ondemand_timeout:445]    # ~7.4 minutes (matches Level 3 design philosophy)
```

**Why 445 seconds (~7.4 minutes)?**
- Long enough for dependency installation operations to complete
- Short enough that it doesn't waste resources
- Philosophy aligns with temporary operational zenka
- Matches the "7.42" pattern referenced in Protocol-7 design

**Alternative Timeouts**:
- `420` (7 minutes): Quick shutdown, for fast-changing envs
- `445` (7.4 minutes): Default, balanced
- `600` (10 minutes): Longer timeout for slower systems/large installs

---

## How It Works

### Timeline of Debian Zenka Lifecycle

**Idle Timeout = 445 seconds**

```
Time:       Event
────────────────────────────────────────────────────────────
T+0:        Dependency check triggered
T+0:        debian zenka starts (on-demand)
T+5:        Installation completes
T+5:        debian zenka idle begins
T+445:      If no activity since T+5, auto-shutdown
            Resources freed, process terminated
T+n:        Next dependency check (if needed)
T+n:        debian zenka starts again (fresh)
```

### Resource Impact

**Without idle timeout**:
- debian zenka runs continuously
- Consumes memory/resources 24/7
- Unnecessary for mostly-idle system

**With idle timeout (445s)**:
- debian zenka starts only when needed
- Runs for duration of dependency operation
- Auto-shuts down, resources freed
- Restarts on next dependency check
- **Result: Near-zero resource cost when not in use**

---

## Integration with Level 3

### For Always-On Zenka (with heartbeat monitoring)

When v7 detects missing dependencies in heartbeat loop:
1. v7.monitor_dependency_health detects issue
2. Calls v7.verify_and_install_zenka_dependencies
3. debian zenka auto-starts (on-demand)
4. Installs/repairs dependencies
5. Returns to v7
6. debian zenka idles...
7. After 445s idle, auto-shutdown
8. Resources freed

### For On-Demand Zenka (fork-time verification)

When on-demand zenka (e.g., calc) about to fork:
1. weather.base.fork_weather_child calls verify_and_install
2. debian zenka auto-starts (on-demand)
3. Verifies child dependencies
4. Installs any missing
5. Returns to parent
6. Parent forks child
7. debian zenka idles...
8. After 445s idle, auto-shutdown
9. Resources freed

---

## Configuration Steps

### Step 1: Locate debian zenka config

```bash
cat configuration/zenki/debian/zenka-startup.v7
```

### Step 2: Add idle timeout line

After the `restart.disabled = 1` line, add in the `zenka-init` section:

```perl
: zenka-init :
  [base.auth.set_zenka_key:'<{cube.key}>']
  [base.zenki.set_ondemand_timeout:445]
```

### Step 3: Verify configuration

```bash
grep "set_ondemand_timeout" configuration/zenki/debian/zenka-startup.v7
# Should output: [base.zenki.set_ondemand_timeout:445]
```

### Step 4: Test

- Trigger dependency installation (via Level 3)
- Verify debian zenka starts
- Verify it shuts down automatically after idle timeout
- Check resource usage (should drop after shutdown)

---

## Timeout Selection Guide

| Timeout | Seconds | Use Case |
|---------|---------|----------|
| 33s | 33 | Quick download operations |
| 42s | 42 | Fast transcoding (ffmpeg) |
| 69s | 69 | Medium operations (screenshot) |
| 420s | 7 min | Moderate installations |
| **445s** | **7.4 min** | **Recommended for debian** |
| 600s | 10 min | Large package installs |
| 4200s | 70 min | Long-running operations |

**For debian zenka**: **445 seconds** balances:
- Long enough to complete typical dependency operations
- Short enough to minimize resource waste
- Aligns with Protocol-7's numeric philosophy (7.42)

---

## Expected Behavior After Implementation

### Normal Dependency Operation
```
$ list dependency-status
zenka_name | verified | action
───────────┼──────────┼────────────────
httpd      | ✓        | [detected missing IO::AIO]
debian     | -        | [auto-starting]
httpd      | ✓        | [reinstalling...]
debian     | -        | [operation complete, idling]
           |          | [445s until shutdown...]
httpd      | ✓        | [dependency repaired ✓]
```

### Resource Timeline
```
Memory Usage:
4.5MB ─┐
       │ debian zenka running
       │ (installing dependencies)
3.0MB ─┤
       │
1.5MB ─┼───────────────────────────────
       │ (idle timeout reached)
0.5MB ─┘ (auto-shutdown)
        └──────────────────────────────
          0s     445s    900s
         start  shutdown restart
```

---

## Summary

The debian zenka is **perfect for idle timeout auto-shutdown** because:

✓ On-demand activation (started when needed)
✓ Short operational window (dependency checks/installs)
✓ No need for continuous running
✓ Saves resources with auto-shutdown
✓ Seamlessly restarts when next needed
✓ Aligns with Level 3 philosophy

**Configuration**: Add `[base.zenki.set_ondemand_timeout:445]` to debian zenka startup

**Result**: Self-managing, resource-efficient dependency system that cleans up after itself.

#,,,,,.,,,.,,,,.,,,.,,...,.,,,.,,,.,,,,,.,,.,,..,,...,...,,,,,,.,,,,,,..,,,..,
#5WPDQZ2KDFHVWPRJHJ3MNGKT6ODZPCA2L2P2YJCTPMRD5SYHE3JBZ757XGQY6XICYNX5KMBZECK7C
#\\\|AI7EQGCCGAOJZSIGN5PWFU7OSWM3ZHHYFTWQ2IXLJ5B6SH2UF75 \ / AMOS7 \ YOURUM ::
#\[7]STJ6YCUEL2JZNHLJMRSOMT3ODSNS3TNLIMRV5D25B25372R3FGDI 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
