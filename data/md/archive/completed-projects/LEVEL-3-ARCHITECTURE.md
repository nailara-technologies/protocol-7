# Level 3: Dynamic Dependency Verification & Auto-Installation Architecture

## Overview

Building on Level 2's safe subprocess handling, Level 3 implements **dynamic, continuous dependency verification** that detects and repairs broken/missing dependencies at runtime—not just at startup. This addresses the reality that system upgrades, user manual uninstalls, and package conflicts can break dependencies after initial installation.

**Core Principle**: Dependencies are **dynamic and change at runtime**. The system must continuously verify and repair them on-demand, not assume one-time installation solves everything.

---

## Current State Analysis

### What Already Exists (Don't Duplicate)

The codebase has **mature, production-ready dependency infrastructure**:

1. **base.dependency.*** (10 modules)
   - Graph-based dependency tracking
   - Callback-driven validation
   - Chain operations (add, del, validate)
   - Status checking via `dependency.ok`
   - Ready to use directly

2. **v7.zenka dependency system** (4 modules)
   - Orchestrates zenka dependencies
   - Reads from config, builds chains
   - Safe dependency object creation
   - Callback-based validation

3. **debian.parent.scan_zenka_dependencies** (Production)
   - Scans `pm-dep/` and `os-dep/debian/` directories
   - Creates registries with statistics
   - Callback-driven registration
   - **Missing**: `os-dep/binary/` scanning

4. **Session/Workflow auto-install logic**
   - session.parent.check_and_resolve_deps (smart)
   - workflow.check_dependencies (flexible)
   - Already handles minimal vs all deps
   - Already has fallback decision logic

### What Needs to be Built (Gap Analysis)

1. **Binary Dependency Scanning**
   - Extend `debian.parent.scan_zenka_dependencies`
   - Scan `os-dep/binary/` directories
   - Register via callback pattern

2. **Verification & Repair Orchestrator**
   - `v7.verify_and_install_zenka_dependencies` (NEW)
   - Leverages existing debian infrastructure
   - Detects missing/broken dependencies
   - Installs on-demand if needed

3. **Dynamic Health Monitoring**
   - `v7.monitor_dependency_health` (NEW, periodic)
   - Detects system upgrades, manual uninstalls
   - Auto-repairs what's fixable
   - Alerts for binary deps (can't auto-install)

4. **Parent-Child Zenka Integration**
   - Insert verification before fork operations
   - Prevents child startup failures
   - Tracks child dependency state

---

## Architecture: Three Dependency Types

### 1. PM Dependencies (Perl Modules)
- **Location**: `cfg/zenki/{zenka}/pm-dep/`
- **Format**: Empty marker files, `Module__Name` (underscores = `::``)
- **Validation**: `eval { Module::Load::load() }`
- **Installation**: Via `cpanm` (Level 2 infrastructure)

### 2. OS Dependencies (Debian Packages)
- **Location**: `cfg/zenki/{zenka}/os-dep/debian/`
- **Format**: Empty marker files, package names (e.g., `libimage-magick-perl`)
- **Validation**: `dpkg -l | grep`
- **Installation**: Via `apt-get install`

### 3. Binary Dependencies (Executables)
- **Location**: `cfg/zenki/{zenka}/os-dep/binary/`
- **Format**: Empty marker files, executable names (e.g., `git`, `convert`, `cpanm`)
- **Validation**: `which` or `File::Which::which()`
- **Installation**: **Cannot auto-install custom binaries—must alert admin**

---

## Implementation Plan

### Step 1: Extend Binary Dependency Scanning

**Module to modify**: `debian.parent.scan_zenka_dependencies`

Add binary scanning after OS dep scanning (around line 95):

```perl
## Scan Binary dependencies (NEW)
if ( -d $bin_dep_path ) {
    opendir( my $bin_dh, $bin_dep_path ) or next;
    @bin_deps = grep { $_ !~ /^\./ && -f "$bin_dep_path/$_" } readdir($bin_dh);
    closedir($bin_dh);

    ## Register each binary dependency
    foreach my $bin_name (@bin_deps) {
        <[debian.parent.callback.register_binary_dependency]>->(
            $bin_name, $zenka
        );
    }
}
```

Create callback module: `debian.parent.callback.register_binary_dependency`
- Simple registration pattern (mirrors existing PM/OS callbacks)
- Registers in `$data{'debian'}{'binary_deps'}{'registry'}`
- Creates by_name and by_zenka lookups

**Output**: Binary dependencies scannable and registerable

---

### Step 2: Create Unified Verification Function

**NEW Module**: `debian.parent.verify_dependency_state`

**Purpose**: Check if a specific dependency is currently available

**Interface**:
```perl
<[debian.parent.verify_dependency_state]>->(
    $type,           # 'pm' | 'os' | 'binary'
    $dependency_name,
    $zenka_name      # Optional, for error context
)
```

**Implementation per type**:

```perl
# PM Module: Try to load
eval { Module::Load::load($module_name) };
return {
    available => length($EVAL_ERROR) == 0,
    error => $EVAL_ERROR
};

# OS Package: Query dpkg
system("dpkg -l | grep " . quotemeta($pkg) . " > /dev/null 2>&1");
return { available => $? == 0 };

# Binary: Use which or File::Which
my $path = which($binary_name);
return { available => defined $path, path => $path };
```

**Returns**: `{available => 0/1, error => $string, path => $string}`

---

### Step 3: Create Comprehensive Verification & Repair Orchestrator

**NEW Module**: `v7.verify_and_install_zenka_dependencies`

**Purpose**: Check all three dependency types for a zenka, optionally install

**Interface**:
```perl
<[v7.verify_and_install_zenka_dependencies]>->(
    $zenka_name,
    $install_if_missing  # 0 = check only, 1 = check and install
)
```

**Logic**:
1. Read expected dependencies from config directories
   - PM: scan `pm-dep/`
   - OS: scan `os-dep/debian/` + `os-dep/binary/`
   - Child: if parent forks children, also scan child config dirs

2. Verify current state via `debian.parent.verify_dependency_state`
   - Loop through each expected dependency
   - Check availability

3. Calculate results
   - `missing` = expected but not found
   - `broken` = found but can't load (PM only)
   - `available` = verified working

4. If `$install_if_missing`:
   - **PM modules**: Call `<[base.perlmod.install]>` (Level 2!)
   - **OS packages**: Call `<[debian.parent.ensure_zenka_dependencies]>`
   - **Binary**: Log warning, add to `missing_binary` list (can't auto-install)

5. Return comprehensive state:
```perl
{
    verified => 1/0,         # All deps satisfied?
    missing_pm => [...],      # Not installed
    missing_os => [...],
    missing_binary => [...],  # Requires admin action
    broken_pm => [...],       # Was installed, can't load now
    installed_now => [...]    # Just installed this call
    warnings => [...]         # Binary deps need admin
}
```

**Tracking**: Store in `<v7.dependency.verification_state->{$zenka_name}>`

---

### Step 4: Create Periodic Health Monitor

**NEW Module**: `v7.monitor_dependency_health`

**Purpose**: Run during v7's heartbeat loop to detect anomalies

**Interface**:
```perl
<[v7.monitor_dependency_health]>->($zenka_name)
```

**Logic**:
1. Call `verify_and_install_zenka_dependencies` with `$install_if_missing = 1`
2. Compare to last known state
3. Detect anomalies:
   - **Missing now**: Was working, now isn't → system upgrade
   - **Broken now**: User manual uninstall detected
   - **Recently repaired**: Installation auto-fixed the issue

4. Track in anomaly log:
```perl
<v7.dependency.anomalies> = [
    {
        zenka => 'weather',
        type => 'missing_binary',
        dependency => 'convert',
        first_detected => time(),
        action => 'alert_admin'  # Can't auto-fix
    },
    {
        zenka => 'httpd',
        type => 'pm_broken',
        dependency => 'IO::AIO',
        first_detected => time(),
        repaired => time(),
        action => 'auto_repaired'
    }
]
```

5. Log appropriately:
   - Missing binary → Level 0 (error, admin attention)
   - Auto-repaired → Level 2 (info, monitoring)
   - First detected anomaly → Level 1 (warning)

---

### Step 5: Integrate into Parent Fork Operations

**Modules to modify**:
- `weather.base.fork_weather_child`
- `image2html.base.fork_conv_child`
- `pdf.html.base.fork_conv_child`
- Any other parent that forks children

**Insert before fork** (around line 24 in weather example):

```perl
## Verify child's dependencies before spawning
if ($UID == 0 and exists $code{'v7.verify_and_install_zenka_dependencies'}) {
    <[base.log]>->(2, 'verifying child dependencies...');

    my $dep_state = <[v7.verify_and_install_zenka_dependencies]>->(
        'weather.child', 1  # verify and install if missing
    );

    if (!$dep_state->{verified}) {
        if (@{$dep_state->{missing_binary}}) {
            <[base.log]>->(0, 'ERROR: missing binary dependencies: %s',
                          join(', ', @{$dep_state->{missing_binary}}));
            return { error => 'missing_binary_dependencies' };
        } else {
            <[base.log]>->(1, 'WARNING: some dependencies missing - attempting workaround');
        }
    }
}

<weather.child.pid> = <[base.fork]>;  # Original fork call
```

---

### Step 6: Integrate Monitoring (Conditional on Heartbeat Status)

**Important Note**: Not all zenka have heartbeats enabled. ~42 zenka have `heartbeat.disabled = 1`. Monitoring strategy must handle both always-on and on-demand zenka.

**For Always-On Zenka (with heartbeats)**:

Modify `v7.init_code`, lines 52-61 (instance verification section):

```perl
## Monitor dependency health during instance verification (always-on zenka only)
if ($UID == 0 and exists $code{'v7.monitor_dependency_health'}) {
    foreach my $instance (@{<v7.zenka.instance>}) {
        my $zenka_name = $instance->{zenka_name};
        my $status = $instance->{status};

        next unless $status eq 'online' || $status eq 'extbin';

        ## Skip zenka with disabled heartbeats (on-demand)
        next if <[v7.zenka.is_enabled]>->($zenka_name, 'heartbeat_disabled');

        <[v7.monitor_dependency_health]>->($zenka_name);
    }
}
```

**For On-Demand Zenka (heartbeat disabled)**:

Verification happens at two points:

1. **Before child fork** (already covered in Step 5):
   - Guarantees child has required deps before spawning
   - Works for: weather.child, image2html.child, pdf.child, etc.

2. **On-demand access** (Optional enhancement):
   - Could verify dependencies when command is executed
   - Useful if deps change between on-demand zenka starts
   - Integration point: In zenka command handler or pre-execution hook

**Rationale**:
- Always-on zenka: Can be monitored continuously via heartbeat loop
- On-demand zenka: Verify at startup/fork time, minimal overhead
- Both: Before-fork verification prevents startup failures

---

## Monitoring & Lists

### List 1: Dependency Verification Status

```yaml
# In v7.init_code, create list structure:
list.dependency-status:
  var: data
  key: v7.dependency.verification_state
  descr: 'Zenka dependency verification status'
  mask: 'zenka_name missing_pm:pm missing_os:os missing_binary:bin verified:ok'
  align:
    zenka_name: left+2
    verified: center-2
    missing_pm: right-3
    missing_os: right-3
    missing_binary: right-4
```

### List 2: Anomalies & Alerts

```yaml
# Dependency anomalies requiring attention:
list.dependency-alerts:
  var: data
  key: v7.dependency.anomalies
  descr: 'Dependency anomalies (missing, broken, manual uninstalls)'
  mask: 'zenka_name type:issue dependency first_detected:detected action'
  align:
    zenka_name: left+2
    type: left
    dependency: left+1
    action: center-1
  filters:
    first_detected: v7.parser.dependency_timestamp
```

---

## Privilege Management

### As Root (UID == 0)
- Full verification capabilities
- Auto-install PM modules via `cpanm`
- Auto-install OS packages via `apt-get`
- Auto-repair broken dependencies

### As Unprivileged User
- Full verification capabilities
- Cannot install packages
- Can skip install, return state to caller
- Child zenka tracks missing deps for later repair
- Logs warning for admin visibility

---

## State Tracking & Anomaly Detection

Comprehensive state stored in `<v7.dependency.verification_state>`:

```perl
{
    last_verified => time(),

    zenka_states => {
        'weather' => {
            pm_verified => 1,
            os_verified => 1,
            binary_verified => 0,  # Missing 'convert'
            missing_pm => [],
            missing_os => [],
            missing_binary => ['convert'],
            repaired_count => 2,
            last_repair => time()
        },
        'httpd' => {
            pm_verified => 1,
            os_verified => 1,
            binary_verified => 1,
            missing_pm => [],
            missing_os => [],
            missing_binary => [],
            repaired_count => 0
        }
    },

    anomalies => [
        {
            zenka => 'weather',
            type => 'missing_binary',
            dependency => 'convert',
            first_detected => time(),
            detected_count => 3,
            action => 'alert_admin'
        },
        {
            zenka => 'httpd',
            type => 'pm_broken',
            dependency => 'IO::AIO',
            first_detected => 1699000000,
            repaired => time(),
            repaired_count => 1,
            action => 'auto_repaired'
        }
    ]
}
```

---

## Implementation Roadmap

| Step | Module | Purpose | Priority | Depends On |
|------|--------|---------|----------|-----------|
| 1 | debian.parent.scan_zenka_dependencies (extend) | Scan binary deps | HIGH | None |
| 1 | debian.parent.callback.register_binary_dependency (new) | Register binaries | HIGH | Step 1 |
| 2 | debian.parent.verify_dependency_state (new) | Verify any dep type | HIGH | Step 1 |
| 3 | v7.verify_and_install_zenka_dependencies (new) | Comprehensive orchestrator | HIGH | Step 2 |
| 4 | v7.monitor_dependency_health (new) | Periodic monitoring | MEDIUM | Step 3 |
| 5 | Parent fork modules (extend) | Insert verify before fork | MEDIUM | Step 3 |
| 6 | v7.init_code (modify) | Integrate monitoring | MEDIUM | Step 4 |
| 7 | Lists (create) | Monitoring UI | LOW | Step 3+ |

---

## Testing Strategy

1. **Normal startup** - All deps present
2. **System upgrade** - Removes PM modules or packages
3. **User manual uninstall** - Binary removed from PATH
4. **Repair verification** - Auto-fixes detected correctly
5. **Anomaly tracking** - Anomalies recorded with timestamps
6. **Unprivileged** - Verification works, no install attempts
7. **Parent-child** - Child verifies before fork succeeds

---

## Key Design Decisions

1. **Reuse existing infrastructure**: Don't duplicate base.dependency.*, debian.parent.*, session.parent.* logic
2. **Three dependency types**: PM, OS, binary—each with different validation/installation
3. **Dynamic, not static**: Continuous verification, not one-time install
4. **Binary deps can't auto-install**: Alert admin, don't block
5. **Callback-driven**: Use existing callback pattern for extensibility
6. **Leverage Level 2**: Use `base.perlmod.install` for PM modules
7. **Parent-child safety**: Verify before fork, prevent startup failures
8. **Audit trail**: Track what was repaired when, for troubleshooting

---

## Summary

**Level 3 is NOT about replacing the existing dependency system**—it's about **adding runtime verification and repair on top of existing infrastructure**.

The existing `base.dependency.*`, `v7.zenka.*`, and `debian.parent.*` systems are mature and production-ready. Level 3 adds:

1. **Binary dependency scanning** (extend existing scanner)
2. **Unified verification function** (check any dep type)
3. **Verification + repair orchestrator** (uses existing installers)
4. **Periodic health monitoring** (detect runtime changes)
5. **Parent-child integration** (prevent startup failures)
6. **State tracking & anomaly detection** (visibility)

Result: **Self-healing dependency system that catches and repairs issues continuously, not just at startup.**

#,,..,.,.,..,,,,.,,,.,.,,,..,,,.,,.,,,,,.,.,.,..,,...,...,,..,,.,,,..,,,.,,.,,
#Q46J2RFQTKFULKEYBMRNNT5EEOFFOXQHIYKDPFVOARX7SJMPDMYGYJJV4NECUQRPSR2NUZRO2PQL2
#\\\|YTMMW4O5HT2ECPDGPFNLTE3AIY5NLLMEOVNQEQMKKW4KF7Y5WNP \ / AMOS7 \ YOURUM ::
#\[7]4PKSHTYXFJWJSQF2UBT547H4LW4R6AW5WZ2IAFDTVBIQD45W36CI 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
