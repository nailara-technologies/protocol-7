# Level 3: Heartbeat Architecture Consideration

## Critical Discovery: Mixed Heartbeat Status

The Protocol-7 system has **two classes of zenka** with fundamentally different operational patterns:

- **45 zenka with continuous heartbeats** (always-on)
  - Examples: httpd, cube, weather, v7, p7-log, system
  - Run continuously or frequently checked
  - Can be monitored via v7's heartbeat loop

- **42 zenka with `heartbeat.disabled = 1`** (on-demand)
  - Examples: calc, screenshot, geoloc, image2html, download, set-up, etc.
  - Started when accessed, stopped when idle
  - Not suitable for continuous heartbeat monitoring

---

## Why This Matters for Level 3

### Initial Proposal (Before This Consideration)
"Monitor dependency health via v7 heartbeat loop"

**Problem**: Would repeatedly check on-demand zenka that aren't even running, wasting CPU and log spam.

### Revised Architecture (After This Consideration)

**For Always-On Zenka**:
```perl
# In v7 heartbeat loop, check dependencies
# Works for: httpd, cube, weather, v7, p7-log, system, etc.
# Detects system upgrades, manual uninstalls
# Continuous verification = high reliability
```

**For On-Demand Zenka**:
```perl
# Verify dependencies at fork time (before spawn)
# Works for: calc, screenshot, geoloc, image2html, etc.
# Detects missing/broken deps before startup
# No overhead on continuous heartbeat loop
# Still prevents startup failures
```

---

## Implementation Strategy: Two Paths

### Path 1: Always-On Zenka (Continuous Monitoring)

**Where**: v7 heartbeat verification loop (lines 52-61 in v7.init_code)

**Logic**:
```perl
foreach my $instance (@{<v7.zenka.instance>}) {
    my $zenka_name = $instance->{zenka_name};
    my $status = $instance->{status};

    next unless $status eq 'online' || $status eq 'extbin';

    ## IMPORTANT: Skip on-demand zenka
    next if <[v7.zenka.is_enabled]>->($zenka_name, 'heartbeat_disabled');

    ## Only monitor always-on zenka
    <[v7.monitor_dependency_health]>->($zenka_name);
}
```

**Effect**:
- Only ~45 always-on zenka checked
- System upgrades detected and repaired immediately
- Manual uninstalls caught and logged
- On-demand zenka untouched

### Path 2: On-Demand Zenka (Fork-Time Verification)

**Where**: Before fork operations in parent modules
- `weather.base.fork_weather_child`
- `image2html.base.fork_conv_child`
- `pdf.html.base.fork_conv_child`

**Logic**:
```perl
## Before spawning child
if ($UID == 0 and exists $code{'v7.verify_and_install_zenka_dependencies'}) {
    my $dep_state = <[v7.verify_and_install_zenka_dependencies]>->(
        'weather.child', 1  # verify and install
    );

    if (!$dep_state->{verified}) {
        ## Handle missing deps or return error
    }
}

## Only then fork
<weather.child.pid> = <[base.fork]>;
```

**Effect**:
- Child dependencies verified before spawn
- Missing deps installed on-demand
- Prevents startup failures
- No continuous overhead

---

## Heartbeat Status: How to Determine

Check zenka configuration:

```bash
# Always-on (no disable flags)
$ cat cfg/zenki/httpd/start.cfg
# No heartbeat.disabled line

# On-demand (explicitly disabled)
$ cat cfg/zenki/calc/start.cfg
heartbeat.disabled = 1
restart.disabled = 1
```

### Categorization

**Always-On** (no disable flags):
- cube, cube-13
- httpd, httpsd
- v7, p7-log
- weather
- system, nodes
- ... (45 total)

**On-Demand** (heartbeat.disabled = 1):
- calc, screenshot, geoloc
- image2html, download
- set-up, amos-term
- ... (42 total)

---

## Verification State Tracking

### For Always-On Zenka
```perl
<v7.dependency.verification_state> = {
    httpd => {
        last_verified => time(),
        pm_verified => 1,
        os_verified => 1,
        binary_verified => 1,
        repaired_count => 2,
        last_repair => time()
    },
    weather => {
        # ... similar ...
    }
}
```

Tracked continuously in heartbeat loop. Available for querying anytime.

### For On-Demand Zenka
```perl
<v7.dependency.verification_state> = {
    calc => {
        last_verified => undef,  # Not monitored continuously
        verified_when_run => 1,  # Verified at fork time
        # ... state from last fork ...
    }
}
```

Only updated when zenka forks child or executes command.

---

## Monitoring via Lists

### List: dependency-status
Shows verification state for **always-on zenka only** (those in heartbeat loop):

```
zenka_name        | pm | os | bin | verified | repairs
─────────────────┼────┼────┼────┼──────────┼────────
httpd             | ✓  | ✓  | ✓  | ✓ OK     |       2
weather           | ✓  | ✓  | ⚠  | ⚠ BROKEN |       1
```

On-demand zenka (calc, screenshot, etc.) not shown—they're not continuously monitored.

### List: dependency-alerts
Shows anomalies from **both always-on and on-demand zenka**:

```
zenka_name  | type           | dependency  | action
────────────┼────────────────┼─────────────┼──────────────
weather     | missing_binary | convert     | alert_admin
httpd       | broken_pm      | IO::AIO     | auto_repaired
```

---

## Admin Commands

```bash
# Check always-on zenka dependencies
list dependency-status

# See all anomalies (any zenka)
list dependency-alerts

# Manually check specific zenka (any type)
v7.monitor_dependency_health weather
v7.verify_and_install_zenka_dependencies calc 1

# Query state
dump v7.dependency.verification_state
```

---

## Performance Implications

### Minimal Impact
- **Heartbeat loop**: Only checks ~45 always-on zenka (not 87 total)
- **On-demand zenka**: Checked once at fork time, not repeatedly
- **CPU**: Negligible for always-on checks (dpkg query, which, eval)
- **I/O**: Minimal (reading config directories cached)
- **Logging**: Only when issues detected

### Optimization Opportunities
- Cache last verification state for 5-10 minutes (avoid repeated checks)
- Skip verification if no system upgrades detected
- Batch binary existence checks (single `which` call for many binaries)

---

## Key Insight: Not All Zenka Are Equal

The on-demand zenka paradigm (auto-start when accessed, auto-stop when idle) is **fundamentally different** from always-on zenka.

**Trying to continuously monitor on-demand zenka** = like trying to monitor a process that only exists 5% of the time.

**Solution**: Different verification strategy for each class:
- Always-on: Continuous heartbeat monitoring (detects runtime changes)
- On-demand: Fork-time verification (prevents startup failures)

Both strategies work **because they match the operational model** of each class.

---

## Implementation Checklist

### Step 6a: For Always-On Zenka (in v7 heartbeat loop)
- [ ] Filter out zenka with `heartbeat.disabled = 1`
- [ ] Only call `v7.monitor_dependency_health` for always-on
- [ ] Log monitoring status (once per heartbeat cycle)

### Step 6b: For On-Demand Zenka (fork-time verification)
- [ ] Verify before fork in parent modules (Step 5)
- [ ] Skip heartbeat monitoring (already handled)
- [ ] Update state from fork verification

### Testing
- [ ] Always-on zenka: Verify heartbeat monitoring works
- [ ] On-demand zenka: Verify fork-time checks work
- [ ] Mixed scenario: Both classes operating together
- [ ] Performance: No CPU spike from dependency checks

---

## Summary

**Level 3 respects the architectural reality** of Protocol-7: zenka fall into two classes with different operational requirements.

- **Always-on**: Continuous dependency verification via heartbeat
- **On-demand**: Fork-time dependency verification

Result: **Self-healing dependencies without performance overhead**, appropriate for each zenka class.

#,,.,,...,,,,,...,,.,,...,..,,,,,,...,.,,,..,,..,,...,...,,,,,..,,...,...,...,
#RC3UXKC27KJ2CLPEHJQKGWL6DYHUH3P2BWRQLIBMNGVFAKR7DW4XQNXDHW44ZLWJLOJYIHD6DHVW2
#\\\|3GXJLQOGSPYGCNZHDRP5BKKIKBHW7FHWIYT6IE6JAOGWGZ752LX \ / AMOS7 \ YOURUM ::
#\[7]BDLZ56L2HKMQBCUFO3B4LIXKWBNSTKYNCETALITPJKDLUIYU66CI 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
