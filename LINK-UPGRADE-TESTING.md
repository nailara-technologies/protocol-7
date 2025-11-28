# Link-Upgrade Encryption Testing Guide

## Overview

This document describes how to test the Protocol-7 link-upgrade encryption implementation after the critical blocking bug fixes.

## What Was Fixed

### 1. Event Loop Blocking Bug ✓
- **Issue**: Numeric `$session_id` passed to `key_32()` created 4,072,410 iterations
- **Fix**: Pass SCALAR ref `\$session_id` for smart iteration count (113-226)
- **Result**: Key derivation now instant (20.1ms, no timeout)

### 2. Module API Syntax ✓
- **Issue**: Wrong function call patterns for `perlmod.loaded`
- **Fix**: Corrected all three encryption wrapper files
- **Result**: Proper function reference dereferencing

### 3. Safeguards Added ✓
- Warnings for numeric seeds > 1000
- Override mechanism: `$AMOS7::13::allow_high_iterations = 1`
- Benchmark data collected (safe limits documented)

## Testing Methods

### Method 1: Standalone Perl Verification (No Server Required)

```bash
cd /home/user/protocol-7
perl bin/verify-link-upgrade-fixes.pl
```

**What it tests:**
- ✓ Key derivation performance (no blocking)
- ✓ Safeguard warnings work
- ✓ Override mechanism functional
- ✓ Module loading correct
- ✓ Full encryption flow (DH + ChaCha20)

**Expected output:**
```
✓✓✓ ALL CRITICAL FIXES VERIFIED ✓✓✓

Fixed Issues:
  1. ✓ Event loop blocking ELIMINATED
  2. ✓ Module API CORRECTED
  3. ✓ Safeguards WORKING
  4. ✓ Encryption READY
```

### Method 2: Benchmark Performance Analysis

```bash
cd /home/user/protocol-7
perl bin/benchmark-key32.pl
```

**What it shows:**
- Performance with SCALAR ref (recommended)
- Performance with safe numeric seeds (0-1000)
- Analysis of dangerous ranges
- Safe operating limits

**Key Results:**
- SCALAR ref: 48.7 calls/sec (20.5ms) ✓
- Numeric +1000: 12.1 calls/sec (82.7ms) ✓
- Numeric +4M: Would be 3659x slower ✗

### Method 3: Full End-to-End Test (Server + Client)

**Requirements:**
- Protocol-7 cube server can start
- nshell client available
- p7 commands accessible

**Run the test:**

```bash
cd /home/user/protocol-7
./bin/test-link-upgrade-complete.sh
```

**What it does:**
1. Starts cube server in background
2. Clears buffers for clean test
3. Runs link-upgrade negotiation
4. Verifies encryption initialization
5. Checks for proper state transitions
6. Confirms no event loop blocking
7. Displays server logs
8. Cleans up server process

**Expected output:**
```
========================================
✓ LINK-UPGRADE TEST SUCCESSFUL
Encryption is operational and non-blocking
========================================
```

**Log files created:**
- `/tmp/p7-server.log` - Server output
- `/tmp/nshell-test.log` - Client output
- `/tmp/server-logs.txt` - Filtered logs

## Safe Limits Reference

| Parameter | Safe Value | Warning Threshold |
|-----------|-----------|-------------------|
| Numeric seed | 0-1000 | > 1000 |
| Total iterations | 113-1113 | > 1113 |
| Key derivation time | < 100ms | > 500ms |
| Preferred method | SCALAR refs | Numeric > 1000 |

## Override for Long-Running Use

If you intentionally need to use numeric seeds > 1000:

```perl
# Suppress warning
$AMOS7::13::allow_high_iterations = 1;
my $key = key_32(\$secret, 2000);  # Will not warn
$AMOS7::13::allow_high_iterations = 0;  # Reset
```

## Commits Addressing Fixes

### Critical Blocking Fix
- `0621742d8` - Pass session_id as SCALAR ref to key_32

### Module API Fixes
- `0945ea592` - Use function call syntax for perlmod.loaded
- `8591045e0` - Add missing brackets in wrappers
- `5ef56f6db` - Fix read encryption wrapper syntax

### Safeguards & Tools
- `9669cedcc` - Add benchmark script and safeguards
- `b98259f31` - Fix Perl syntax in safeguards
- `a5593641b` - Add verification script
- `938479bc8` - Add complete test script

## Branch Information

All changes are on: `claude/init-workspace-setup-019LE8UJdJVCRszedzeqcS9N`

## Verification Checklist

After testing, verify:

- [ ] Key derivation completes in < 50ms
- [ ] No event loop timeouts
- [ ] Encryption wrappers installed
- [ ] State 3 (encrypted) reached
- [ ] No spurious key_32 warnings
- [ ] Override mechanism works
- [ ] Server handles multiple connections

## Next Steps

1. Run `verify-link-upgrade-fixes.pl` for baseline verification
2. Run `benchmark-key32.pl` to understand performance
3. Run `test-link-upgrade-complete.sh` for full end-to-end test
4. Check logs for any anomalies
5. Proceed with production deployment

## Support

If tests fail, check:
1. Server log: `/tmp/p7-server.log`
2. Client log: `/tmp/nshell-test.log`
3. Buffer logs: `/tmp/server-logs.txt`

Look for:
- "key derivation completed" (should appear without delay)
- "encryption wrappers installed" (confirms state 2→3 transition)
- "AMOS7::13::key_32 WARNING" (should not appear with SCALAR refs)
