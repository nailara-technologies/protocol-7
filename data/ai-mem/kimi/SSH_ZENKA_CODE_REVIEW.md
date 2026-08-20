# SSH Zenka Code Review (Recovered from 2021)

## Executive Summary

The SSH zenka code is functional but shows its age (originally written 2015, deleted in 2021, recovered in 2026). It has several issues ranging from style non-compliance to potential resource leaks and security concerns. The code works but needs cleanup for production use.

---

## Critical Issues (Fix Before Production)

### 1. **Missing Error Handling in ssh.handler.nailara_io**
**File:** `src/ssh.handler.nailara_io` (lines 24-28)

```perl
my $bytes = $channel->write($buffer);
if ( not defined $bytes ) {
    <[base.log]>->( 0, '<< [nailara_io] WRITE ERROR >>' );
    <[ssh.connection.stop]>->($con_id);
}
```

**Problem:** Only checks for `undef`, not for write errors where `$bytes == 0` or partial write.

**Fix:**
```perl
my $written = $channel->write($buffer);
if ( not defined $written or $written != length($buffer) ) {
    <[base.logs]>->( 0, 'nailara_io: write failed (%s/%s bytes)',
        $written // 'undef', length($buffer) );
    <[ssh.connection.stop]>->($con_id);
}
```

### 2. **Resource Leak on Partial Cleanup in ssh.connection.stop**
**File:** `src/ssh.connection.stop` (lines 16-30)

**Problem:** The cleanup sequence doesn't verify resources exist before operating on them:
- `$connection->{'io'}->{$type}->cancel` - doesn't check if watcher exists
- `$connection->{'nch'}->close` - no check if channel exists
- `print { $connection->{'sock'} } "exit\n"` - print to potentially closed socket

**Fix:** Add existence checks before all operations:
```perl
$connection->{'io'}->{$type}->cancel
    if ref($connection->{'io'}->{$type}) =~ m|Event|;
```

### 3. **Typo in Log Message - "hearbeat"**
**File:** `src/ssh.handler.heartbeat_response` (line 26)

```perl
<[base.log]>->( 0, "hearbeat reply timeout for link '$link_name'. [ $msg ]" );
```

Should be "heartbeat" (missing 't').

### 4. **Using `base.log` instead of `base.logs`**
**Multiple files:** ssh.connection.start, ssh.handler.ssh_io, etc.

**Problem:** Mixing `base.log` and `base.logs` inconsistently. The `base.logs` function handles sprintf formatting, while `base.log` requires manual interpolation.

**Example:**
```perl
# WRONG (in ssh.connection.start line 78)
<[base.log]>->( 0, ': : ssh connection error [ %s ]', <[base.str.os_err]> );

# CORRECT
<[base.logs]>->( 0, ': : ssh connection error [ %s ]', <[base.str.os_err]> );
```

### 5. **Potential Race Condition in ssh.connection.start**
**File:** `src/ssh.connection.start` (line 197)

```perl
$connection->{'io'}->{'ssh'}->now;    # quickfix!
```

The comment "quickfix!" suggests this is a workaround. Calling `->now` immediately after adding an IO watcher may cause issues if the socket isn't fully ready.

**Recommendation:** Remove this line and ensure proper event-driven handling.

---

## Protocol-7 Style Issues

### 6. **Inconsistent Comment Style**
**Multiple files**

Comments should start with lowercase and use `[ word ]` not `( word )`:

```perl
# WRONG (ssh.handler.ssh_io line 4)
# descr = reads and processes output from mpv control pipe

# CORRECT
# descr = reads and processes output from nailara protocol pipe
```

Also - the description is wrong ("mpv control pipe" should be "nailara protocol pipe").

### 7. **Using `$$call` instead of `$call`**
**Files:** ssh.cmd.profile_enable, ssh.cmd.profile_disable

```perl
my $profile_name = $$call{'args'};  # WRONG
my $profile_name = $call->{'args'}; # CORRECT
```

`$$call` dereferences a scalar reference, but `$call` is already a hashref.

### 8. **Incorrect POD/Description in ssh.handler.ssh_io**
**File:** `src/ssh.handler.ssh_io` (line 4)

```perl
# descr = reads and processes output from mpv control pipe
```

This is copy-paste from mpv zenka! Should be:
```perl
# descr = reads and processes SSH channel output for Protocol-7 tunnel
```

### 9. **Missing `return` on die in ssh.connection.start**
**File:** `src/ssh.connection.start`

After `die`, the code continues with `goto error`. While not technically wrong, it's inconsistent with Protocol-7 error handling patterns.

---

## Performance & Optimization Issues

### 10. **Inefficient Buffer Handling in ssh.handler.ssh_io**
**File:** `src/ssh.handler.ssh_io` (lines 29-36)

```perl
my $buffer;
my $bytes = $channel->read( $buffer, 4096 );
if ( defined $bytes and $bytes ) {
    $connection->{'buffer'} .= $buffer;
    $event->now;
}
```

**Problems:**
1. `$event->now` is called even if buffer hasn't changed
2. No check for `$bytes == 0` (EOF vs error)

**Optimized version:**
```perl
my $buffer;
my $bytes = $channel->read( $buffer, 4096 );
if ( $bytes ) {
    $connection->{'buffer'} .= $buffer;
    $event->now;
} elsif ( defined $bytes ) {
    # $bytes == 0 means EOF
    <[base.logs]>->( 1, 'ssh channel EOF for %s', $link_name );
} else {
    # $bytes undef means error
    <[base.logs]>->( 0, 'ssh channel read error: %s', $! );
    <[ssh.connection.stop]>->($con_id);
}
```

### 11. **No Connection Limit in ssh.enable_profile**
**File:** `src/ssh.enable_profile` (lines 13-15)

```perl
foreach my $link_name ( keys %{$profile_data} ) {
    <[ssh.connection.start]>->( $profile_name, $link_name );
}
```

**Problem:** Starts ALL links simultaneously. With many links, this could exhaust file descriptors or memory.

**Recommendation:** Add rate limiting or concurrent connection limit.

### 12. **Inefficient Heartbeat Cleanup**
**File:** `src/ssh.connection.stop` (lines 39-44)

```perl
if ( exists <ssh.heartbeat_request>->{$con_id} ) {
    map { delete <ssh.heartbeat_request>->{$con_id}->{$ARG} }
        keys %{ <ssh.heartbeat_request>->{$con_id} };
    delete <ssh.heartbeat_request>->{$con_id}
        if !keys %{ <ssh.heartbeat_request>->{$con_id} };
    delete <ssh.heartbeat_request> if !keys %{<ssh.heartbeat_request>};
}
```

**Simpler:**
```perl
delete <ssh.heartbeat_request>->{$con_id}
    if exists <ssh.heartbeat_request>;
```

### 13. **Magic Numbers Not Configurable**
**Multiple files**

Hardcoded values that should be configurable:
- `4.7` seconds heartbeat delay (ssh.connection.start line 199)
- `1.2` seconds initial heartbeat delay (line 201)
- `0.5` seconds initial retry delay (line 215)
- `30` seconds max retry delay (line 216)

These have comments like `# LLL: --> config..,` indicating they were meant to be moved to config.

---

## Security Concerns

### 14. **SSH Key File Permissions Not Validated**
**File:** `src/ssh.connection.start` (lines 132-143)

The code checks if key files are readable but doesn't validate permissions (e.g., private key should be 0600).

**Recommendation:**
```perl
my $mode = (stat($key_file))[2] & 07777;
if ( $mode & 0077 ) {
    <[base.logs]>->( 0, 'SSH key %s has insecure permissions %04o',
        $key_file, $mode );
}
```

### 15. **Password in Memory**
**File:** `src/ssh.handler.ssh_io` (line 44)

```perl
$channel->write("auth $remote_user $remote_pass\n");
```

The password is sent over the channel. While encrypted by SSH, it would be better to use public-key auth only for Protocol-7 links.

**Recommendation:** Document that this is for initial handshake only, and consider key-based auth.

---

## Minor Issues

### 16. **Inconsistent Variable Naming**
**File:** `src/ssh.connection.start`

- `$ssh_keyfile` vs `$ssh_privkey` (same thing, different names)
- `$nch` for channel (unclear abbreviation)

### 17. **Commented Debug Code**
**File:** `src/ssh.handler.heartbeat_response` (line 38)

```perl
#   print "[$link_name] link latency : ${latency}ms\n";
```

Remove or convert to proper logging.

### 18. **Unused Variables**
**File:** `src/ssh.init_code` (line 20)

```perl
# LLL: table alignment currently broken
```

This comment suggests known broken functionality. Either fix or document as limitation.

### 19. **Inconsistent Return Values**
**File:** `src/ssh.connection.start`

- Returns `1` on success (line 209)
- Returns `0` on error (via `goto error` at line 230)

But `ssh.connection.stop` doesn't check these return values.

### 20. **Access Pattern Comment Outdated**
**File:** `cfg/zenki/ssh/start` (line 8)

```
access.cmd.usr.cube = ... #<-FIX
```

The `#<-FIX` comment suggests this was a temporary configuration. Verify if this is still needed.

---

## Recommendations Summary

### High Priority (Fix Immediately)
1. Fix typo: "hearbeat" → "heartbeat"
2. Replace `$$call` with `$call` in cmd modules
3. Fix `base.log` → `base.logs` throughout
4. Add error handling for partial writes in nailara_io

### Medium Priority (Fix Soon)
5. Fix description in ssh.handler.ssh_io ("mpv" → "nailara")
6. Add resource existence checks in connection.stop
7. Move magic numbers to configuration
8. Add connection rate limiting

### Low Priority (Nice to Have)
9. Add SSH key permission validation
10. Clean up commented debug code
11. Simplify heartbeat cleanup
12. Standardize variable naming

---

## Overall Assessment

**Code Quality:** C+ (functional but rough edges)
**Security:** B- (no major vulnerabilities, but missing hardening)
**Protocol-7 Compliance:** C (many style violations)
**Maintainability:** C+ (inconsistent patterns, magic numbers)

The code works for basic SSH tunneling but needs cleanup before production use. The most critical issues are the typo, the `$$call` bug, and the missing error handling in nailara_io.

---

## Post-Review Update (February 2026)

### Fixes Applied (Commit fddefc448)

**Date:** February 2026
**Milestone:** Commit 6500 since 2012 (~500 commits in 2026 alone!)

All critical and high-priority issues have been addressed:

1. ✅ Fixed typo: "hearbeat" → "heartbeat"
2. ✅ Fixed `$$call` → `$call` (cmd modules)
3. ✅ Fixed `base.log` → `base.logs` for formatted messages
4. ✅ Fixed descriptions ("mpv" → "protocol-7/nailara")
5. ✅ Improved error handling in nailara_io (write checks)
6. ✅ Improved buffer handling in ssh_io (EOF/error detection)
7. ✅ Simplified heartbeat cleanup code
8. ✅ Added watcher existence checks

### Result

The SSH zenka now starts cleanly and maintains its robust connection recovery behavior that was refined over years of laptop sleep/wake cycle testing. The fixes bring the 11-year-old codebase into better alignment with modern Protocol-7 conventions.

#,,.,,,,.,,.,,,,,,.,.,...,,..,,.,,,..,,,,,...,.,.,...,...,.,.,.,,,.,.,...,.,.,
#FOUPEV6NYICAMIE4ITLFCB2NGANJN2W2WNYJFFTJ4HT3DOBF6CYDJ6FVNSN4HZRL5K7NXXBIB6GV2
#\\\|EO6LKJH2Q5XLPKT54RNEPFC5UGTFGVL4XLH4UX26QYY4O7HEIWW \ / AMOS7 \ YOURUM ::
#\[7]YIXYDS252M3IKIGV43E7Z26DXVSH3DRDETVIZTEXHATK63BLTEDQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
