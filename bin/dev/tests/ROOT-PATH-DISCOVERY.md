# Protocol-7 Root Path Discovery

This directory provides utility functions to robustly find the Protocol-7 project root directory, regardless of where test scripts are located in the repository.

## Problem

Test scripts scattered across different directories need to find the project root. Previous approaches used hardcoded relative paths like `../..` or absolute paths like `/home/user/protocol-7`, which break when scripts are moved or deployed to different systems.

## Solution

Two utility modules provide automatic, robust root path detection:

- **Bash**: `find-protocol-7-root.sh`
- **Perl**: `FindProtocol7Root.pm`

Both search in order:
1. `PROTOCOL_7_ROOT` environment variable (fastest)
2. Walk up from script location looking for project markers
3. Fallback heuristics for standard locations
4. Error with helpful diagnostic message

## Usage Examples

### Bash Scripts

**Before:**
```bash
#!/bin/bash
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
P7_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

if [ ! -f "$P7_ROOT/bin/nshell" ]; then
    echo "Error: Could not find Protocol-7 root directory"
    exit 1
fi
```

**After:**
```bash
#!/bin/bash
# Source the root finder (adjust path based on script location)
source "$(dirname "$0")/find-protocol-7-root.sh"

P7_ROOT=$(find_protocol_7_root) || exit 1
```

**For nested scripts (e.g., `bin/dev/tests/link-upgrade/test-foo.sh`):**
```bash
#!/bin/bash
# Works even from nested directories!
source "$(dirname "$0")/../find-protocol-7-root.sh"

P7_ROOT=$(find_protocol_7_root) || exit 1
cd "$P7_ROOT"
```

### Perl Scripts

**Before:**
```perl
#!/usr/bin/env perl
use strict;
use warnings;
use Cwd qw(abs_path);
# No proper root finding
```

**After:**
```perl
#!/usr/bin/env perl
use strict;
use warnings;
use lib "$(dirname $0)";
use FindProtocol7Root qw(find_protocol_7_root);

my $root = find_protocol_7_root(verbose => 1)
    or die "Could not find Protocol-7 root";

chdir $root or die "Cannot chdir to $root: $!";
```

## Environment Variable Override

For testing or non-standard deployments, users can set:

```bash
export PROTOCOL_7_ROOT=/custom/location
./bin/dev/tests/link-upgrade/test-foo.sh
```

This is the fastest path as it skips directory walking entirely.

## How It Finds the Root

### Project Markers

The utilities look for combinations of these markers:

- `.git/` - Git repository root
- `modules/` - Protocol-7 module directory
- `bin/nshell` - Protocol-7 interactive shell
- `configuration/` - Protocol-7 configuration directory

Finding multiple markers prevents false positives (e.g., misidentifying a different git repo inside the project).

### Search Strategy

1. **Start**: From the calling script's directory
2. **Walk up**: Move to parent directory, check for markers
3. **Limit**: Stop after 10-15 levels (safety against infinite loops)
4. **Success**: Return first directory matching marker criteria
5. **Fallback**: Try standard relative paths if walk fails
6. **Error**: Exit with helpful error message if still not found

### Performance

- **With env var**: 1 stat() call (fastest)
- **First directory match**: 2-4 stat() calls
- **Worst case**: ~50 stat() calls (rare, with deep directory walk)

Most real-world scenarios resolve in 2-6 directory checks.

## Integration Guide

### Moving Test Scripts to bin/dev/tests

When moving test scripts, update path source:

```bash
# From bin/test-foo.sh
source "$(dirname "$0")/find-protocol-7-root.sh"  # WRONG - file moved!

# Change to:
source "$(dirname "$0")/../find-protocol-7-root.sh"  # bin/test-foo.sh
source "$(dirname "$0")/find-protocol-7-root.sh"     # bin/dev/tests/test-foo.sh
source "$(dirname "$0")/../find-protocol-7-root.sh"  # bin/dev/tests/category/test-foo.sh
```

Or use this pattern to work from any depth:

```bash
# Find utilities relative to test directory
TEST_UTILS_DIR="$(dirname "$0")"
while [ ! -f "$TEST_UTILS_DIR/find-protocol-7-root.sh" ]; do
    TEST_UTILS_DIR="$(dirname "$TEST_UTILS_DIR")"
    [ "$TEST_UTILS_DIR" = "/" ] && break
done

source "$TEST_UTILS_DIR/find-protocol-7-root.sh"
P7_ROOT=$(find_protocol_7_root) || exit 1
```

### Creating New Test Scripts

New test scripts should:

1. Source the root finder at the top
2. Call `find_protocol_7_root()` to get the root
3. Change to root if needed: `cd "$(find_protocol_7_root)"`
4. Remove any hardcoded paths or `..` sequences

Example template:

```bash
#!/bin/bash
# New test script - works from any location
set -e

# Find utilities (this pattern works from any depth)
TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
while [ ! -f "$TEST_DIR/find-protocol-7-root.sh" ] && [ "$TEST_DIR" != "/" ]; do
    TEST_DIR="$(dirname "$TEST_DIR")"
done

source "$TEST_DIR/find-protocol-7-root.sh"
P7_ROOT=$(find_protocol_7_root) || exit 1

cd "$P7_ROOT"

# Now test can use paths relative to project root
# ./bin/nshell works from any location!
```

## Troubleshooting

### "Could not find Protocol-7 root"

**Solution 1**: Set environment variable
```bash
export PROTOCOL_7_ROOT=/path/to/protocol-7
./test-script.sh
```

**Solution 2**: Check script path
```bash
# Verify script is within the repository
pwd
echo $0
```

**Solution 3**: Verify markers exist
```bash
ls modules/
ls bin/nshell
ls configuration/
```

### Script still uses hardcoded paths

Search for patterns to update:
```bash
grep -r "cd \.\." bin/dev/tests/
grep -r "/home/user/protocol-7" bin/dev/tests/
grep -r "SCRIPT_DIR/\.\." bin/dev/tests/
```

## Testing

Test the root finder:

```bash
# Test from different locations
bash -c 'source bin/dev/tests/find-protocol-7-root.sh; find_protocol_7_root'
cd /var/tmp && bash -c 'source /data/projects/protocol-7/bin/dev/tests/find-protocol-7-root.sh; find_protocol_7_root'

# Test Perl version
perl -I bin/dev/tests -e 'use FindProtocol7Root qw(find_protocol_7_root); print find_protocol_7_root(verbose => 1)'
```

Expected output: `/data/projects/protocol-7` (or your actual root)

## Related Files

- `find-protocol-7-root.sh` - Bash implementation
- `FindProtocol7Root.pm` - Perl implementation
- `bin/test-*.sh` - Test scripts to migrate
- `bin/dev/tests/` - Test script home directory
