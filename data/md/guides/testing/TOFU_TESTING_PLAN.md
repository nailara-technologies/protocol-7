# TOFU Authentication Testing Plan

## Phase 6: Local TOFU Flow Validation

### Test Environment
- Local Protocol-7 instance (source)
- Simulated remote server on different port/context
- Testing auth-keypair + TOFU key pinning

### Phase 6.1: First-Use TOFU Key Pinning
**Objective:** Verify that first connection to remote server pins public key

Steps:
1. Clear any existing remote keys: `keys.console.list` should show no [hostkey] entries
2. Connect via p-7-r to localhost (simulated remote):
   - `p-7-r localhost:47 list sessions`
3. Verify TOFU pinning:
   - User should see TOFU prompt (or auto-pin if non-TTY)
   - Key should be stored in ~/.n/user-keys/remote.localhost_171.public
   - `keys.console.list` should now show [hostkey] for localhost:47

Success Criteria:
- ✓ Remote key file created with NTIME_B32:PUBKEY_B32 format
- ✓ Key appears in console.list with [hostkey] marker
- ✓ Command executes after pinning

### Phase 6.2: Key Validation (Second Connection)
**Objective:** Verify that subsequent connections validate against pinned key

Steps:
1. Connect again to same server:
   - `p-7-r localhost:47 v7.available_zenki`
2. Verify validation:
   - No TOFU prompt (key already pinned)
   - "remote key validated" message logged
   - Command executes successfully

Success Criteria:
- ✓ No re-pinning happens
- ✓ Key comparison succeeds
- ✓ Connection proceeds to auth-keypair

### Phase 6.3: MITM Detection (Key Mismatch)
**Objective:** Verify that changed key is detected and rejected

Steps:
1. Manually corrupt the pinned key file:
   - Edit ~/.n/user-keys/remote.localhost_171.public
   - Change first character of pubkey to different value
2. Attempt connection:
   - `p-7-r localhost:47 list sessions`
3. Verify MITM detection:
   - "SECURITY: remote key mismatch" warning
   - Connection refused
   - No command execution

Success Criteria:
- ✓ Mismatch detected immediately
- ✓ Security warning logged
- ✓ Connection refused

### Phase 6.4: Auth-Keypair Authentication
**Objective:** Verify end-to-end remote authentication flow

Steps:
1. Successful first-use TOFU pinning complete
2. Key validated on second connection
3. auth-keypair method selected (p-7-r auto-selects this)
4. Link-upgrade encryption negotiated
5. Remote command executes

Success Criteria:
- ✓ TOFU → Link-upgrade → Auth-keypair chain works
- ✓ Remote commands execute with proper credentials
- ✓ No MITM during handshake

## Phase 7: Production Server Key Exchange

Once Phase 6 validates locally:

1. Get public keys from 3 production servers
2. Pre-pin keys before connecting
3. Test remote access to each server
4. Verify commands execute remotely

## Testing Checklist

- [ ] Phase 6.1: First-use TOFU pinning works
- [ ] Phase 6.2: Key validation succeeds on reconnect
- [ ] Phase 6.3: MITM detection rejects mismatched keys
- [ ] Phase 6.4: End-to-end auth-keypair flow works
- [ ] Phase 7: Production servers accessible with TOFU
- [ ] Phase 8: Remote commands execute on all 3 servers
- [ ] Phase 9: Document TOFU procedures for team

## Notes

- Use `p7c v7.reload` to reload modules after changes
- Check logs: `p7c system.log.tail:100`
- Monitor: `p7c list sessions` for active connections
- Key location: `~/.n/user-keys/remote.*.public`

#,,,.,,..,.,.,,,.,,,,,.,,,,..,,.,,,,.,...,,..,..,,...,...,.,.,.,,,,,.,,,.,,,.,
#MBI3CVSXAUVEIVFVSDSQRUDSGH7SYKUKYG6C7LNICXFK56JSN7KK3F5K3VRCVY3TANCFLCZ7ELNAY
#\\\|IYWUFOYV65XB5G3IBDZ3K2SB2S27QXUUAZ46HCA75JHHIWOEQ3X \ / AMOS7 \ YOURUM ::
#\[7]OA4D4F4NASZJURSPIZBHYAIW6IYGWT3EOMQRSVZHUGM4S2L6QADI 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
