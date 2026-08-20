# Link-Upgrade Client Encryption Testing Plan

**Date**: 2025-11-27
**Status**: Testing procedure documentation and step-by-step guide
**Target**: nshell client with PROTOCOL_7_LINK_UPGRADE=yes

---

## Pre-Testing Verification Checklist

### ✅ nshell Implementation

- [x] Line 165-182: Link-upgrade negotiation block added
- [x] Line 212: Encryption state passed to shell_loop()
- [x] Line 397: shell_loop() accepts encryption_state parameter
- [x] Line 456-460: Command encryption wrapper added
- [x] Line 402: Encryption state passed to stdout_fork()
- [x] Line 505-516: stdout_fork() decrypts responses
- [x] Line 621-696: negotiate_link_upgrade() function implemented
- [x] Line 698-716: encrypt_message() function implemented
- [x] Line 718-739: decrypt_message() function implemented

**Test**: Quick syntax verification
```bash
cd /home/user/protocol-7
perl -e 'my %h = (enabled => 0); print "OK\n"'  # Basic Perl check
```

### ✅ Helper Script

- [x] `/home/user/protocol-7/bin/p7-link-upgrade-helper.pl` created
- [x] File is executable (755 permissions)
- [x] gen-ephemeral operation tested successfully

**Test**: Verify helper is accessible
```bash
cd /home/user/protocol-7
./bin/p7-link-upgrade-helper.pl gen-ephemeral 2>&1 | wc -l  # Should output 2 lines
```

### ✅ test-link-upgrade Zenka

- [x] Configuration file exists at `cfg/zenki/test-link-upgrade/start`
- [x] crypt.C25519 module is loaded
- [x] link-upgrade command is enabled
- [x] Automatic user key creation enabled

---

## Testing Environment Setup

### Step 1: Initialize Protocol-7 Test Environment

```bash
cd /home/user/protocol-7

# Check Protocol-7 status
./bin/Protocol-7 -version

# List available zenkasi
./bin/Protocol-7 list

# Check if test-link-upgrade zenka is available
./bin/Protocol-7 test-link-upgrade heart 2>&1 | head -10
```

### Step 2: Start test-link-upgrade Zenka (if needed)

The zenka should start automatically, but if not:

```bash
cd /home/user/protocol-7

# Option A: Start via Protocol-7 system
./bin/Protocol-7 test-link-upgrade &

# Option B: Check system logs for zenka status
tail -f /var/log/protocol7/*.log 2>/dev/null | grep -i "link-upgrade"

# Option C: Verify socket exists
ls -la /var/run/.7/UNIX/ 2>/dev/null | grep -i "test\|link"
```

### Step 3: Verify nshell is Ready

```bash
cd /home/user/protocol-7

# Check nshell can be run
./bin/nshell --help 2>&1 | head -5

# Or just try to run it (it will prompt for input if successful)
timeout 2 ./bin/nshell 2>&1 | head -10
```

---

## Test Scenario 1: nshell Without Encryption (Baseline)

**Purpose**: Establish baseline behavior without encryption

**Commands**:
```bash
cd /home/user/protocol-7

# Connect to test-link-upgrade zenka
echo "echo 'Hello from plaintext nshell'" | ./bin/nshell

# Or interactively:
./bin/nshell
# At prompt, type: echo 'Hello test'
# Expected: Server echoes back the command output
# Ctrl+D or type [quit] to exit
```

**Expected Output**:
```
 :: authentication successful ::
[prompt] nshell [ 127.0.0.1 : 13042 ]
 nshell [ 127.0.0.1 : 13042 ]::[?]::, echo 'Hello test'
TRUE success
Hello test
 nshell [ 127.0.0.1 : 13042 ]::[?]::,
```

**Verification**:
- [ ] Connection successful
- [ ] Command executed correctly
- [ ] Response received without errors
- [ ] No encryption-related errors

---

## Test Scenario 2: nshell With Encryption Enabled

**Purpose**: Test link-upgrade encryption negotiation and message encryption/decryption

**Commands**:
```bash
cd /home/user/protocol-7

# Set encryption environment variable
export PROTOCOL_7_LINK_UPGRADE=yes

# Connect to test-link-upgrade zenka
echo "echo 'Hello from encrypted nshell'" | ./bin/nshell

# Or interactively:
./bin/nshell
# At prompt, type: echo 'Hello encrypted test'
# Expected: Same output as plaintext test
```

**Expected Output**:
```
 :: authentication successful ::
 :: link-upgrade encryption enabled ::
[prompt] nshell [ 127.0.0.1 : 13042 ]
 nshell [ 127.0.0.1 : 13042 ]::[?]::, echo 'Hello encrypted test'
TRUE success
Hello encrypted test
 nshell [ 127.0.0.1 : 13042 ]::[?]::,
```

**Key Points**:
- Line 2: Should show " :: link-upgrade encryption enabled ::" message
- Output should be identical to plaintext test (encryption is transparent)
- No errors during negotiation or communication

**Verification**:
- [ ] Link-upgrade negotiation succeeds (message appears)
- [ ] Encryption key generated successfully
- [ ] Commands execute correctly with encryption enabled
- [ ] Responses decrypt properly
- [ ] Output matches plaintext baseline

---

## Test Scenario 3: Multi-Command Session with Encryption

**Purpose**: Test persistent encryption state across multiple commands

**Interactive Test**:
```bash
cd /home/user/protocol-7
export PROTOCOL_7_LINK_UPGRADE=yes

./bin/nshell
# At prompt, execute these commands in sequence:
date
whoami
pwd
echo "Line 1" && echo "Line 2"
[quit]
```

**Expected Behavior**:
- Each command is encrypted with incrementing counter
- Responses decrypt correctly despite counter increments
- Multi-line responses handled properly
- Session termination works with encryption

**Verification**:
- [ ] All commands return correct output
- [ ] Counters properly increment (each message gets new counter)
- [ ] Multi-line output handled correctly
- [ ] No cryptographic errors or warnings

---

## Test Scenario 4: Error Handling

**Purpose**: Test graceful degradation and error handling

### Test 4A: Encryption Negotiation Failure

**Setup**: Temporarily break the encryption to trigger failure

```bash
cd /home/user/protocol-7
export PROTOCOL_7_LINK_UPGRADE=yes

# Modify temporarily to cause failure (or test against old zenka)
./bin/nshell 127.0.0.1 9999  # Non-existent server
```

**Expected**:
- Connection error (not encryption error)
- Graceful exit

### Test 4B: Server Without Encryption Support

```bash
cd /home/user/protocol-7

# Connect to regular cube (not test-link-upgrade) with encryption enabled
export PROTOCOL_7_LINK_UPGRADE=yes
./bin/nshell  # Should try to negotiate but fall back
```

**Expected**:
- Negotiation fails gracefully
- Falls back to plaintext mode
- Commands still work without encryption

**Verification**:
- [ ] Errors are caught and reported
- [ ] Fallback to plaintext works
- [ ] No crashes or hangs

---

## Test Scenario 5: Performance Baseline

**Purpose**: Measure encryption overhead

**Commands**:
```bash
cd /home/user/protocol-7

# Plaintext: 10 commands, measure time
time for i in {1..10}; do echo "echo test \$i" | ./bin/nshell > /dev/null; done

# Encrypted: 10 commands, measure time
export PROTOCOL_7_LINK_UPGRADE=yes
time for i in {1..10}; do echo "echo test \$i" | ./bin/nshell > /dev/null; done
```

**Expected**: Encryption overhead should be <10% (negligible for interactive use)

**Measurement**: Calculate:
```
overhead % = ((encrypted_time - plaintext_time) / plaintext_time) * 100
```

---

## Diagnostic Commands

If tests fail, use these commands to diagnose:

### Debug nshell Directly

```bash
cd /home/user/protocol-7

# Run nshell with bash set -x to trace execution
bash -x ./bin/nshell 2>&1 | head -50

# Check if Perl modules are available
perl -e 'use Crypt::Misc; use Crypt::AuthEnc::ChaCha20Poly1305; print "Crypto modules OK\n"'

# Check if AMOS7 modules available
cd /home/user/protocol-7 && perl -I data/lib-path/pm -e 'use AMOS7; print "AMOS7 OK\n"'
```

### Debug Helper Script

```bash
cd /home/user/protocol-7

# Test gen-ephemeral
./bin/p7-link-upgrade-helper.pl gen-ephemeral 2>&1

# Test complete flow
PUBKEY="5Q54ZD26ZGRF277CGQKUZJGDQ2534YOLAXAMJTED55KNRR65EZEQ"
SECRET="3N6436DGT62VIXTV3LGWNCDZWCIY6Z5YIIS4ZU4343YDK4BDYJMQ"

# Test derive-key
./bin/p7-link-upgrade-helper.pl derive-key "$SECRET" 12345 2>&1

# Test encryption/decryption roundtrip
echo -n "Hello World" | \
  ./bin/p7-link-upgrade-helper.pl encrypt "..." 12345 1 > /tmp/encrypted.bin
hexdump -C /tmp/encrypted.bin | head -10
```

### Check Socket Communication

```bash
# Monitor unix socket traffic (requires netcat or socat)
socat -v UNIX-CONNECT:/var/run/.7/UNIX/NIW7OAQ STDIO

# Watch for socket opening/closing
lsof | grep UNIX | grep protocol-7
```

---

## Success Criteria

### Phase 1: Baseline Verification ✅
- [x] nshell compiles without syntax errors
- [x] Helper script runs and generates keys
- [x] test-link-upgrade zenka is accessible

### Phase 2: Plaintext Testing (Pre-requisite for encryption)
- [ ] nshell connects to test-link-upgrade zenka
- [ ] Commands execute correctly without encryption
- [ ] Multi-command sessions work
- [ ] [quit] command exits cleanly

### Phase 3: Encryption Testing (Main objective)
- [ ] Link-upgrade negotiation succeeds
- [ ] " :: link-upgrade encryption enabled ::" message appears
- [ ] Commands execute correctly with encryption
- [ ] Output matches plaintext baseline
- [ ] Responses decrypt properly
- [ ] Multi-command sessions maintain encryption state

### Phase 4: Robustness Testing (Polish)
- [ ] Error handling works (degradation on negotiation failure)
- [ ] Performance overhead is minimal (<10%)
- [ ] Handles edge cases (empty responses, large output, etc.)
- [ ] Proper cleanup on exit

---

## Troubleshooting Matrix

| Symptom | Possible Cause | Resolution |
|---------|----------------|-----------|
| "Can't locate Crypt::Misc" | Missing Perl module | Run: `p7-deps install development` |
| "Can't use undefined value" | Encryption state not passed | Check shell_loop() parameter passing |
| "link-upgrade negotiation failed" | Server doesn't support encryption | Ensure using test-link-upgrade zenka |
| Timeout/Hang | Socket reading blocked | Check socket is properly created |
| Garbage output | Decryption failed | Verify auth tags, counters, session ID |
| Memory leak | Not freeing encryption_state | Check resource cleanup in decrypt |

---

## Logging and Monitoring

### Enable Verbose Output

```bash
cd /home/user/protocol-7

# Run nshell with Perl debugging
perl -d:Trace ./bin/nshell 2>&1 | head -100

# Monitor system for socket activity
watch -n 0.1 'lsof -c nshell' 2>/dev/null

# Check Protocol-7 daemon logs
tail -f /var/log/protocol7/test-link-upgrade.log 2>/dev/null
```

### Capture Network Traffic

```bash
# Use strace to see all system calls
strace -e trace=write,read,sendto,recvfrom ./bin/nshell 2>&1 | grep -A5 "link-upgrade"

# Dump socket buffer (requires tcpdump privilege)
tcpdump -i unix 'unix port /var/run/.7/UNIX/NIW7OAQ' 2>/dev/null
```

---

## Documentation of Results

After running tests, document:

1. **Test Date/Time**
2. **Environment**:
   - Protocol-7 version
   - Perl version
   - Kernel version
   - System load
3. **Test Results**: Pass/Fail for each scenario
4. **Performance Metrics**: Encryption overhead %
5. **Issues Encountered**: Any errors or unexpected behavior
6. **Improvements**: Changes needed for production

---

## Next Steps After Testing

### If Tests Pass ✅
1. Document results in TEST_RESULTS.md
2. Integrate p7.c encryption (see P7C_LINK_UPGRADE_INTEGRATION.md)
3. Deploy to remote server (final task)
4. Verify low-latency encrypted access works

### If Tests Fail ❌
1. Document specific failures in LINK_UPGRADE_TESTING_RESULTS.md
2. Use diagnostic commands to identify root cause
3. Modify code based on findings
4. Re-run failing tests
5. Update LINK_UPGRADE_DEPENDENCY_ISSUES.md if new issues found

---

## Estimated Testing Time

| Phase | Estimated Time |
|-------|-----------------|
| Environment setup | 15-30 min |
| Baseline plaintext test | 5 min |
| Encryption test | 5 min |
| Multi-command session | 5 min |
| Error handling | 10 min |
| Performance measurement | 10 min |
| Documentation | 10-15 min |
| **Total** | **1-2 hours** |

---

## Testing Completed By

- Date: [To be filled after testing]
- Tester: [To be filled after testing]
- Results: [To be filled after testing]

#,,..,,..,,,,,...,...,,,.,,.,,...,,.,,...,,,,,.,.,...,...,...,,..,.,,,...,,..,
#ZJFBJIC2NNDB36MZYYMPTDDLCVVDCDN2PT2TMXPVM65DQ5MUAAG5IXUZG6DIHB5UCOB4TPKXBWBIC
#\\\|YB6T6FFBU4MQ3GYJIQOYCY5U57SZA4QU5DVWEJQHAYJK235ZL6S \ / AMOS7 \ YOURUM ::
#\[7]SLVZHXLFNGEKMAPJE4VJWM4OHQ3LAHZLEENLGTBVZH3QJLHMEOCA 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
