# Protocol-7 Test Scripts

This directory contains test scripts and test utilities for Protocol-7 development and validation.

## Test Scripts Overview

### Network & Protocol Tests

**test-acme-mock-server.sh** (1220 bytes)
- Tests ACME (Let's Encrypt) mock server functionality
- Used for letsencr integration testing
- Validates certificate request/response flows

**test-backpressure** (4366 bytes)
- Tests socket buffer backpressure handling
- Validates behavior when write buffers fill up
- Ensures graceful degradation under load

**test-httpd-abort-bug** (4151 bytes)
- Tests httpd abort handling in specific edge case
- Reproduction case for HTTP daemon bug
- Validates daemon doesn't crash on abort

**test-httpd-abort-simple** (3130 bytes)
- Simple httpd abort test case
- Basic validation of error handling
- Used for debugging abort behavior

**test-httpd-blocking** (3979 bytes)
- Tests httpd behavior under blocking conditions
- Validates non-blocking socket handling
- Ensures responsiveness under load

**test-httpd-spinning** (4082 bytes)
- Tests for CPU spinning issues in httpd
- Validates event loop efficiency
- Detects busy-wait problems

### Oscillation & Synchronization Tests

**test-oscillation-sequence** (2711 bytes)
- Tests sequence-based oscillation behavior
- Validates state transitions are correct
- Used for synchronization validation

**test-oscillation-simple** (1656 bytes)
- Simple oscillation test case
- Basic state transition validation
- Debugging tool for oscillation issues

### Data Structure & Algorithm Tests

**test-13.sh** (753 bytes)
- Tests Division 13 (AMOS7 cryptographic foundation)
- Validates bit operations and calculations
- Ensures crypto algorithms work correctly

**test-13.bits** (2787 bytes)
- Division 13 test data and bit patterns
- Reference data for crypto tests
- Used by test-13.sh for validation

**test-elf-overflow** (2176 bytes)
- Tests ELF (binary format) overflow handling
- Validates buffer overflow protection
- Used for security testing

**test-forced-abort** (4507 bytes)
- Forces various abort conditions
- Tests error recovery mechanisms
- Validates graceful shutdown

### Documentation & Import Tests

**blue-doc-import-test.pl** (10785 bytes)
- Tests documentation import from external sources
- Validates doc parsing and integration
- Used for doc generation pipeline

**address_test.TORUM.LAYA.0000.asc** (939 bytes)
- Test data: Address validation test case
- Sample address record for validation
- Used by address/routing tests

**comp-test** (8839 bytes)
- Comprehensive protocol component tests
- Tests multiple subsystems together
- Integration test suite

## Directory Structure

```
bin/dev/tests/
├── acme/                   # ACME protocol tests
├── checksum/              # Checksum/ELF tests
├── compression/           # Compression algorithm tests
├── crypto/                # Cryptography/address tests
├── data/                  # Data import/format tests
├── encryption/            # Encryption module tests
├── httpd/                 # HTTP daemon tests
├── io/                    # I/O and backpressure tests
├── link-upgrade/          # Link-upgrade negotiation tests
├── math/                  # Mathematical/Division-13 tests
├── ml/                    # ML/AI inference tests (Whisper, etc.)
├── network/               # Network connectivity tests
├── timing/                # Oscillation/timing tests
└── workflow/              # Workflow/integration tests
```

## Running Tests

### Run All Tests

```bash
cd /home/user/protocol-7/bin/dev/tests
for dir in */; do
    echo "Running tests in $dir"
    for test in "$dir"test-*; do
        [ -x "$test" ] && echo "Running: $test" && "$test" || echo "FAILED: $test"
    done
done
```

### Run Specific Category

```bash
cd /home/user/protocol-7/bin/dev/tests/httpd
for test in test-*; do
    ./$test || echo "FAILED: $test"
done
```

### Run Specific Test

```bash
cd /home/user/protocol-7/bin/dev/tests/httpd
./test-httpd-blocking
```

### Run with Debugging

```bash
cd /home/user/protocol-7/bin/dev/tests/math
bash -x test-13.sh
perl -d ../data/blue-doc-import-test.pl
```

## Test Categories

| Category | Tests | Purpose |
|----------|-------|---------|
| Network | acme-mock, backpressure, httpd-* | Socket/HTTP protocol validation |
| Sync | oscillation-* | State management & synchronization |
| Crypto | test-13 | Cryptographic operations (AMOS7 Div 13) |
| Security | elf-overflow, forced-abort | Error handling & resource limits |
| Integration | comp-test, blue-doc-import | Multi-component interaction |

## Adding New Tests

When adding new test scripts:

1. Place in appropriate subdirectory under `bin/dev/tests/`:
   - `acme/` - ACME protocol tests
   - `checksum/` - Checksum/ELF tests
   - `compression/` - Compression algorithm tests
   - `crypto/` - Cryptography/address tests
   - `data/` - Data import/format tests
   - `encryption/` - Encryption module tests
   - `httpd/` - HTTP daemon tests
   - `io/` - I/O and backpressure tests
   - `link-upgrade/` - Link-upgrade negotiation tests
   - `math/` - Mathematical operation tests
   - `ml/` - ML/AI inference tests
   - `network/` - Network connectivity tests
   - `timing/` - Oscillation/timing tests
   - `workflow/` - Workflow/integration tests
2. Follow naming convention: `test-<feature>` or `test-<component>-<scenario>`
3. Make script executable: `chmod +x test-<name>`
4. Add brief description to this README
5. Document test purpose, inputs, and expected outputs
6. Commit with message: `test: Add <test-name> for <feature>`

## Test Infrastructure

### Common Test Patterns

**Bash script**:
```bash
#!/bin/bash
# Test description
set -e  # Exit on error

# Setup
# ... test code ...

# Validation
# ... verify results ...

echo "Test passed"
```

**Perl script**:
```perl
#!/usr/bin/env perl
use strict;
use warnings;

# Test code
# ... validation ...

print "Test passed\n";
```

## Link-Upgrade Testing

For link-upgrade client encryption testing, see:
- `../../../LINK_UPGRADE_TESTING_PLAN.md` - Comprehensive testing procedure
- `../../../bin/nshell` - Client to test
- `../../../bin/p7-link-upgrade-helper.pl` - Helper for crypto operations

To test nshell encryption:
```bash
cd /home/user/protocol-7
export PROTOCOL_7_LINK_UPGRADE=yes
./bin/nshell
# Type: echo 'test' and verify output
```

## Continuous Integration

These tests can be integrated into CI/CD pipelines:

```bash
# Run test suite organized by category
FAILED=0
for dir in ./bin/dev/tests/*/; do
    echo "Running tests in $(basename "$dir")..."
    for test in "$dir"test-*; do
        [ -x "$test" ] || continue
        echo "  - $(basename "$test")..."
        if ! "$test"; then
            echo "    FAILED!"
            FAILED=$((FAILED + 1))
        fi
    done
done

# Check results
if [ $FAILED -eq 0 ]; then
    echo "All tests passed ✓"
    exit 0
else
    echo "Tests failed: $FAILED"
    exit 1
fi
```

## Troubleshooting

### Test Fails with "Command not found"

Ensure you're in the correct directory and scripts are executable:
```bash
cd /home/user/protocol-7/bin/dev/tests
find . -name "test-*" -type f ! -executable | head -10
# Should show no output if all tests are executable
chmod +x */test-*  # Fix any non-executable scripts
```

### Test Hangs or Stalls

Some tests may require specific Protocol-7 state. Ensure:
- Protocol-7 daemon is running
- Required modules are loaded
- Socket paths exist (`/var/run/.7/UNIX/`)

### Test Data Issues

Check that test data files are present:
```bash
ls -la math/test-13.bits
ls -la crypto/address_test.TORUM.LAYA.0000.asc
```

## Test Coverage

Current test coverage includes:
- ✅ Division 13 cryptographic operations
- ✅ HTTP daemon functionality
- ✅ Socket/network handling
- ✅ State synchronization
- ✅ Error recovery
- ⏳ Link-upgrade encryption (in progress)

## Related Documentation

- Protocol-7 Architecture: `/home/user/protocol-7/docs/`
- AMOS7 Module System: `/home/user/protocol-7/modules/`
- Link-Upgrade Testing: `/home/user/protocol-7/LINK_UPGRADE_TESTING_PLAN.md`
- Crypto Functions: `/home/user/protocol-7/bin/p7-link-upgrade-helper.pl`

