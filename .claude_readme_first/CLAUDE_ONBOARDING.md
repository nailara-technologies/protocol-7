# Claude AI - Protocol-7 Workspace Onboarding

## Welcome to the Protocol-7 Development Environment

You are operating in an **Ubuntu 24.04 LTS** environment with access to the Protocol-7 codebase.

---

## Directory Structure

```
/home/claude/workspace-transfer/    # Main Protocol-7 repository (via SSH key)
/home/claude/work/                  # Workspace for builds, tests, experiments
/mnt/user-data/uploads/             # User-uploaded files (slightly persistent)
/mnt/user-data/outputs/             # Your generated outputs (ephemeral)
~/.ssh/workspace-transfer-read-write # SSH key for repository access
```

**Important Rules:**
- ✅ DO clone external repos into `/home/claude/work/`
- ✅ DO place build artifacts in `/home/claude/work/`
- ✅ DO write reports to `/mnt/user-data/outputs/`
- ❌ DO NOT commit binaries or build artifacts to `workspace-transfer/`

---

## Repository References

### Protocol-7 (Main Repository)
- **URL**: `https://github.com/nailara-technologies/protocol-7.git`
- **Location**: `/home/claude/workspace-transfer/` (pre-cloned)
- **Branch**: `base` (default)
- **Description**: Protocol-7 harmonic computing framework and signature system
- **Key Directories**:
  - `bin/` - Executable scripts and utilities
  - `src/` - Core Protocol-7 modules (source.*, base.*, etc.)
  - `data/` - Checksums, signatures, configuration data
  - `bin/dev/` - Development tools and examples (e.g., `elf-continue`)

### Digest::BMW (External Dependency)
- **URL**: `https://github.com/gray/digest-bmw.git`
- **Clone to**: `/home/claude/work/digest-bmw/`
- **Description**: Perl interface to Blue Midnight Wish hash algorithm (BMW384)
- **Purpose**: Cryptographic checksums for Protocol-7 signatures
- **Key Files**:
  - `BMW.xs` - C/XS implementation
  - `lib/Digest/BMW.pm` - Perl interface
  - `t/` - Test suite

### Related Projects (For Reference)

#### CryptX (Perl Crypto Toolkit)
- **URL**: `https://github.com/DCIT/perl-CryptX.git`
- **Description**: Comprehensive Perl cryptography library
- **Relevance**: Contains reference implementations of various hash algorithms
- **Usage**: Compare BMW implementation patterns

#### Digest Base Classes
- **Digest::base** - Standard Perl digest interface
- **Digest::SHA** - Reference implementation for state management
- **Documentation**: `perldoc Digest` on system

---

## Current Mission: BMW Resumability Analysis

### Context

Protocol-7 uses **BMW384** checksums for cryptographic file signatures. Currently:
- ✅ **ELF7 checksums** are resumable (see `bin/dev/elf-continue`)
- ❓ **BMW checksums** - resumability needs verification

The BMW (Blue Midnight Wish) algorithm is used for:
- Line 2 of signature footer (BASE32-encoded BMW384 checksum)
- AMOS iteration counter calculation (derived from BMW state)
- Harmonic truth validation (ELF checksums validate BMW hashes)

### Why Resumability Matters

For streaming signatures on large files and continuous data sources:
1. **State save** - Serialize internal BMW context to binary blob
2. **State restore** - Resume computation from saved state
3. **Streaming mode** - Process data in chunks without buffering entire file
4. **Memory efficiency** - Constant memory usage regardless of input size

### Your Task

#### Phase 1: Clone and Analyze

```bash
# Setup workspace
mkdir -p /home/claude/work
cd /home/claude/work

# Clone BMW repository (NOT in workspace-transfer!)
git clone https://github.com/gray/digest-bmw.git
cd digest-bmw

# Examine implementation
ls -la
cat README* | head -50

# Check for state management methods
grep -rn "getstate\|setstate\|clone" . --include="*.pm" --include="*.xs"
```

#### Phase 2: Build and Test

```bash
cd /home/claude/work/digest-bmw

# Install build dependencies
sudo apt-get update
sudo apt-get install -y build-essential perl cpanminus libssl-dev
cpanm --installdeps .

# Build BMW module
perl Makefile.PL
make
make test  # Should pass
```

#### Phase 3: Test Resumability

Create `/home/claude/work/test-bmw-resumability.pl`:

```perl
#!/usr/bin/perl
use v5.24;
use strict;
use warnings;
use lib '/home/claude/work/digest-bmw/blib/lib';
use lib '/home/claude/work/digest-bmw/blib/arch';
use Digest::BMW;

say "=== BMW Resumability Test ===\n";

my $test_data = "The quick brown fox jumps over the lazy dog";
my ($chunk1, $chunk2) = (substr($test_data, 0, 20), substr($test_data, 20));

# Method 1: All at once
my $bmw1 = Digest::BMW->new(384);
$bmw1->add($test_data);
my $digest1 = $bmw1->hexdigest;
say "Full digest: $digest1\n";

# Method 2: Sequential chunks
my $bmw2 = Digest::BMW->new(384);
$bmw2->add($chunk1);
$bmw2->add($chunk2);
my $digest2 = $bmw2->hexdigest;

# Verify consistency
die "FAIL: Inconsistent digests!" unless $digest1 eq $digest2;
say "✅ BMW is internally consistent\n";

# Method 3: Check for state save/restore
say "Checking for state management methods:";
say "  clone()    : " . ($bmw1->can('clone') ? "✅ YES" : "❌ NO");
say "  getstate() : " . ($bmw1->can('getstate') ? "✅ YES" : "❌ NO");
say "  setstate() : " . ($bmw1->can('setstate') ? "✅ YES" : "❌ NO");

if ($bmw1->can('clone')) {
    my $bmw3 = Digest::BMW->new(384);
    $bmw3->add($chunk1);
    my $bmw4 = $bmw3->clone;
    $bmw4->add($chunk2);
    my $digest3 = $bmw4->hexdigest;
    
    if ($digest3 eq $digest1) {
        say "\n✅ BMW supports resumability via clone()";
    } else {
        say "\n❌ FAIL: clone() produced different digest";
    }
}

if (!$bmw1->can('clone') && !$bmw1->can('getstate')) {
    say "\n⚠️  BMW does NOT support state save/restore";
    say "Implementation needed: getstate() and setstate() methods";
}

say "\n=== Test Complete ===";
```

Run test:
```bash
cd /home/claude/work
chmod +x test-bmw-resumability.pl
perl test-bmw-resumability.pl | tee /mnt/user-data/outputs/bmw-test-results.txt
```

#### Phase 4: Analysis Report

Based on test results, create `/mnt/user-data/outputs/bmw-analysis-report.md`:

**If state methods exist:**
```markdown
# BMW Resumability Analysis Report

## Summary
✅ BMW supports resumable checksums via [clone/getstate/setstate] method(s).

## Findings
- Method available: [describe]
- State size: [X bytes]
- Compatibility: [verified/needs testing]

## Integration Recommendations
- Update Protocol-7 `source.create_harmonic_footer` to use streaming mode
- Test with large files (GB+)
- Validate state serialization across architectures
```

**If state methods missing:**
```markdown
# BMW Resumability Analysis Report

## Summary
❌ BMW does NOT currently support state save/restore.

## Findings
- No `clone()`, `getstate()`, or `setstate()` methods found
- Internal state structure: [describe if visible]
- BMW.xs implementation: [summarize]

## Required Implementation
Add to BMW.xs:
1. `getstate()` - Serialize `bmw_ctx` to binary string
2. `setstate()` - Restore `bmw_ctx` from binary string

## Next Steps
1. Examine BMW.xs internal structures
2. Design state serialization format
3. Implement XS methods
4. Test thoroughly
5. Generate patch for upstream
```

#### Phase 5: Implementation (If Needed)

If state methods are missing, you may:

1. **Clone Protocol-7 for reference**
   ```bash
   cd /home/claude/work
   git clone https://github.com/nailara-technologies/protocol-7.git protocol-7-reference
   cd protocol-7-reference
   git checkout base
   
   # Study ELF resumability implementation
   cat bin/dev/elf-continue
   grep -rn "elf.*seed\|elf.*continue" src/
   ```

2. **Examine BMW.xs structure**
   ```bash
   cd /home/claude/work/digest-bmw
   less BMW.xs  # Look for state structure
   ```

3. **Design state serialization**
   - Identify `bmw_ctx` or equivalent structure
   - Determine what needs to be saved (hash state, buffer, bitcount)

4. **Implement XS methods** (add to BMW.xs)
   ```c
   SV* getstate(SV* self) {
       // Serialize context to SV
   }
   
   void setstate(SV* self, SV* state_sv) {
       // Restore context from SV
   }
   ```

5. **Rebuild and test**
   ```bash
   make clean
   perl Makefile.PL
   make
   make test
   perl ../test-bmw-resumability.pl
   ```

6. **Generate patch**
   ```bash
   git diff > /mnt/user-data/outputs/bmw-state-serialization.patch
   ```

---

## Deliverables

Place all outputs in `/mnt/user-data/outputs/`:

1. ✅ `bmw-test-results.txt` - Test output
2. ✅ `bmw-analysis-report.md` - Final analysis
3. ✅ `bmw-state-serialization.patch` - Implementation (if needed)
4. ✅ `bmw-implementation-notes.md` - Technical details

---

## Reference: ELF7 Resumability

Protocol-7's ELF7 checksum already supports resumable computation:

```perl
# bin/dev/elf-continue shows this:
h = seed_val; // continuation (line 54)

# Usage:
$ elf-continue 0 "first chunk"
123456789

$ elf-continue 123456789 "second chunk"
987654321
```

**Goal**: BMW should have equivalent capability for streaming signatures.

---

## Protocol-7 Repository Access

Repository location: `/home/claude/workspace-transfer/`

```bash
cd /home/claude/workspace-transfer

# Sync latest changes
git pull origin base

# Explore structure
ls -la bin/ src/ data/
```

**SSH Key**: Pre-configured at `~/.ssh/workspace-transfer-read-write`

**If you need a separate reference clone:**
```bash
cd /home/claude/work
git clone https://github.com/nailara-technologies/protocol-7.git protocol-7-reference
```

---

## Additional Resources

### Documentation
- Protocol-7 docs: `/home/claude/workspace-transfer/read-me/documentation/`
- BMW repository: `https://github.com/gray/digest-bmw`
- Related code: `/home/claude/workspace-transfer/bin/dev/elf-continue`

### Perl Digest Interface
- `perldoc Digest` - Standard digest interface
- `perldoc Digest::SHA` - Reference implementation with state management
- `perldoc perlxs` - XS programming guide

### Useful Commands
```bash
# Search for patterns in Protocol-7
cd /home/claude/workspace-transfer
grep -rn "pattern" src/ bin/

# Check module dependencies
perl -MDigest::BMW -e 'print $INC{"Digest/BMW.pm"}, "\n"'

# Test Perl module loading
perl -Mblib -MDigest::BMW -e 'print "BMW loaded OK\n"'
```

---

## Success Criteria

- ✅ BMW module builds successfully in Ubuntu 24
- ✅ Resumability status determined (exists or needs implementation)
- ✅ Tests pass and validate correctness
- ✅ Complete documentation generated
- ✅ Ready for Protocol-7 integration

---

**Let's enable streaming signatures for Protocol-7! 🌀✨🔐**
