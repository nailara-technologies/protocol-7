# BMW Resumability Test Plan
# For execution by Claude Code Agent on Ubuntu 24 instance

## Phase 1: Setup Environment

```bash
# Create working directory (separate from protocol-7 repo)
mkdir -p /home/claude/work
cd /home/claude/work

# Clone BMW repository
git clone https://github.com/gray/digest-bmw.git
cd digest-bmw

# Install build dependencies
sudo apt-get update
sudo apt-get install -y build-essential libperl-dev
```

## Phase 2: Analyze Current Implementation

```bash
# Examine BMW.xs for existing state methods
grep -n "getstate\|setstate\|clone" BMW.xs

# Check BMW.pm for Perl interface
grep -n "getstate\|setstate\|clone" lib/Digest/BMW.pm

# Examine struct definition
grep -n "typedef struct\|bmw_ctx\|HashReturn" BMW.xs
```

## Phase 3: Build and Test Current Implementation

```bash
# Build the module
perl Makefile.PL
make
make test

# Test basic functionality
perl -Mblib -MDigest::BMW -e '
    my $bmw = Digest::BMW->new(384);
    $bmw->add("Hello, World!");
    print $bmw->hexdigest, "\n";
'
```

## Phase 4: Add State Serialization (if not present)

### Create patch file: `bmw-state-serialization.patch`

```c
// Add to BMW.xs after existing methods

SV*
_getstate(self)
    Digest::BMW self
  CODE:
    // Serialize internal state to SV
    RETVAL = newSVpvn((char *)self, sizeof(struct bmw_ctx));
  OUTPUT:
    RETVAL

void
_setstate(self, state_sv)
    Digest::BMW self
    SV* state_sv
  CODE:
    STRLEN len;
    char *state_data = SvPV(state_sv, len);
    if (len != sizeof(struct bmw_ctx)) {
        croak("Invalid BMW state size: got %d, expected %d",
              len, sizeof(struct bmw_ctx));
    }
    Copy(state_data, self, 1, struct bmw_ctx);

Digest::BMW
clone(self)
    Digest::BMW self
  CODE:
    Newz(0, RETVAL, 1, struct bmw_ctx);
    Copy(self, RETVAL, 1, struct bmw_ctx);
  OUTPUT:
    RETVAL
```

### Add to lib/Digest/BMW.pm:

```perl
sub getstate {
    my $self = shift;
    return $self->_getstate();
}

sub setstate {
    my $self = shift;
    my $state = shift;
    $self->_setstate($state);
}

sub clone {
    my $self = shift;
    return $self->SUPER::clone();
}
```

## Phase 5: Rebuild and Test Resumability

```bash
# Rebuild with new methods
make clean
perl Makefile.PL
make

# Test resumability
perl -Mblib -MDigest::BMW -e '
use strict;
use warnings;

my $data = "Hello, World!";
my ($chunk1, $chunk2) = (substr($data, 0, 5), substr($data, 5));

# Method 1: All at once
my $bmw1 = Digest::BMW->new(384);
$bmw1->add($data);
my $digest1 = $bmw1->hexdigest;

# Method 2: Chunked with state save/restore
my $bmw2 = Digest::BMW->new(384);
$bmw2->add($chunk1);
my $state = $bmw2->getstate;

my $bmw3 = Digest::BMW->new(384);
$bmw3->setstate($state);
$bmw3->add($chunk2);
my $digest2 = $bmw3->hexdigest;

# Verify
if ($digest1 eq $digest2) {
    print "✅ BMW is resumable! Digest: $digest1\n";
    exit 0;
} else {
    print "❌ BMW resumability failed!\n";
    print "  All-at-once: $digest1\n";
    print "  Resumed:     $digest2\n";
    exit 1;
}
'
```

## Phase 6: Performance Test

```bash
# Test with larger data
perl -Mblib -MDigest::BMW -e '
use Benchmark qw(timethese);

my $data = "x" x 1_000_000;  # 1MB of data
my $chunk_size = 4096;

timethese(100, {
    "all-at-once" => sub {
        my $bmw = Digest::BMW->new(384);
        $bmw->add($data);
        $bmw->digest;
    },
    "chunked" => sub {
        my $bmw = Digest::BMW->new(384);
        for (my $i = 0; $i < length($data); $i += $chunk_size) {
            $bmw->add(substr($data, $i, $chunk_size));
        }
        $bmw->digest;
    },
});
'
```

## Phase 7: Integration Test with Protocol-7

```bash
# Copy enhanced BMW to protocol-7 environment
cd /home/claude/workspace-transfer

# Create test script
cat > test_bmw_streaming.pl << 'EOF'
#!/usr/bin/perl
use v5.24;
use strict;
use warnings;
use lib '/home/claude/work/digest-bmw/blib/lib';
use lib '/home/claude/work/digest-bmw/blib/arch';
use Digest::BMW;
use Crypt::Misc qw(encode_b32r);

# Test streaming signature generation
my $test_file = 'bin/Protocol-7';

open my $fh, '<:raw', $test_file or die "Cannot open $test_file: $!";

my $bmw = Digest::BMW->new(384);
my $chunk_size = 4096;
my $total_bytes = 0;

while (my $bytes = read($fh, my $chunk, $chunk_size)) {
    $bmw->add($chunk);
    $total_bytes += $bytes;

    # Simulate checkpoint every 16KB
    if ($total_bytes % 16384 == 0) {
        my $checkpoint = $bmw->clone();
        say "Checkpoint at $total_bytes bytes: " .
            substr(encode_b32r($checkpoint->digest), 0, 16) . "...";
    }
}

close $fh;

my $final_digest = encode_b32r($bmw->digest);
say "\n✅ Final BMW384 checksum:";
say "   $final_digest";
say "   Total bytes: $total_bytes";
EOF

chmod +x test_bmw_streaming.pl
perl test_bmw_streaming.pl
```

## Phase 8: Document Results

```bash
# Generate report
cat > /mnt/user-data/outputs/bmw_resumability_report.md << 'EOF'
# BMW Resumability Implementation Report

## Summary
- **Existing state support**: [YES/NO]
- **Implementation added**: [YES/NO]
- **Tests passed**: [YES/NO]
- **Performance impact**: [X% overhead]

## API Changes
[Document new methods if added]

## Test Results
[Include test output]

## Integration Status
- Compatible with Protocol-7: [YES/NO]
- Streaming signatures: [WORKING/NEEDS_WORK]

## Recommendations
[Next steps]
EOF
```

## Expected Output

```
✅ BMW repository cloned
✅ Dependencies installed
✅ Current state: [with/without serialization]
✅ Patch applied (if needed)
✅ Tests passed
✅ Resumability verified
✅ Performance acceptable
✅ Protocol-7 integration successful
```

## Success Criteria

1. BMW.xs has `getstate`/`setstate`/`clone` methods
2. Resumed checksum matches all-at-once checksum
3. No memory leaks in state serialization
4. Performance overhead < 5%
5. Compatible with Protocol-7 signing workflow
