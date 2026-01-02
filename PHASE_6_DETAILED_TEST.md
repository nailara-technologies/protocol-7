# Phase 6: TOFU First-Use Key Pinning - Detailed Test Procedure

## Prerequisites Check

✓ p-7-r binary compiled and functional
✓ p7c binary working for local commands
✓ TOFU validation modules implemented:
  - crypt.C25519.store_remote_key
  - crypt.C25519.get_remote_key
  - crypt.C25519.validate_remote_key_checksum
  - nshell.tofu_validate_pubkey
✓ Remote key storage directory: ~/.n/user-keys/
✓ Key display: keys.console.list with [hostkey] marker

## Test Scenario: localhost Self-Connection

Since we need a working remote server to test against, we'll use the local Protocol-7 instance in a test mode:

### Setup
```bash
# Terminal 1: Start monitoring
p7c system.log.tail:50

# Terminal 2: Prepare test
export PROTOCOL_7_LINK_UPGRADE=yes  # Enable encryption

# Get local cube info
p7c list sessions
p7c v7.cfg.p7r_bin_path  # Verify p-7-r location
```

### Test Steps

#### Step 1: Verify Clean State
```bash
# Check no remote keys exist yet
p7c keys.console.list
# Should show zero [hostkey] entries

# Verify directory is ready
ls -la ~/.n/user-keys/
# Should exist but no remote.*.public files
```

#### Step 2: Attempt First Connection (Simulated Remote)
```bash
# This would trigger TOFU for first time
p-7-r localhost list sessions

# Expected behavior:
# 1. Connect to localhost on port 42 (default)
# 2. Receive server's Ed25519 public key
# 3. Trigger TOFU validation (no pinned key yet)
# 4. Auto-pin or prompt user (depending on TTY)
# 5. Proceed to auth-keypair authentication
# 6. Execute command
```

#### Step 3: Verify Key Pinning
```bash
# Check key file created
ls -la ~/.n/user-keys/remote.localhost_*.public

# Expected format: NTIME_B32:PUBKEY_B32
cat ~/.n/user-keys/remote.localhost_42.public

# Verify in console
p7c keys.console.list
# Should now show [hostkey] entry for localhost:42
```

#### Step 4: Test Validation (Reconnect)
```bash
# Second connection should validate, not re-pin
p-7-r localhost v7.available_zenki

# Expected:
# - No TOFU prompt (key already pinned)
# - Log shows "remote key validated"
# - Command executes successfully
```

#### Step 5: MITM Detection (Optional)
```bash
# Corrupt the pinned key to simulate MITM
# Edit ~/.n/user-keys/remote.localhost_42.public
# Change first character of pubkey to 'Z' instead of current value

# Try to connect
p-7-r localhost list sessions

# Expected:
# - SECURITY WARNING about key mismatch
# - Connection refused
# - No command execution
```

## Success Criteria for Phase 6

- [x] p-7-r compiled with optional hostname[:port] syntax
- [x] TOFU modules all implemented
- [ ] First connection successfully pins remote key
- [ ] Key stored in ~/.n/user-keys/remote.HOSTNAME_PORT.public
- [ ] Key appears in keys.console.list with [hostkey] marker
- [ ] Second connection validates against pinned key
- [ ] Auth-keypair authentication succeeds over link-upgrade
- [ ] MITM detection rejects mismatched keys
- [ ] All logs show expected security messages

## Moving to Phase 7

Once Phase 6 succeeds:
1. Document the TOFU flow for production deployment
2. Prepare 3 production servers for key exchange
3. Pre-pin production server keys before first connection
4. Test remote access from localhost to production servers

## Key Files for Testing

- p-7-r binary: `/usr/local/bin/p-7-r`
- p7c binary: `/usr/local/bin/p7c`
- Remote key storage: `~/.n/user-keys/remote.*.public`
- TOFU modules: `modules/crypt.C25519.*`
- Validation logic: `modules/nshell.tofu_validate_pubkey`

## Debugging

If tests fail, check:
```bash
# View recent logs
p7c system.log.tail:100

# Check auth-keypair support
p7c select auth-keypair
# Should respond with "TRUE continue"

# Verify link-upgrade
export PROTOCOL_7_LINK_UPGRADE=yes
p7c v7.cfg.bin_p7r_has_symlink

# List all modules
p7c base.list.subroutines | grep -E "(tofu|remote|keypair)"
```
