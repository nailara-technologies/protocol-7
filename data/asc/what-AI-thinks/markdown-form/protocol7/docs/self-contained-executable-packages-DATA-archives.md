# Self-Contained Executable Packages: From Code to Distribution

*Natural evolution of lazy loading + archive infrastructure (2025-11-27 vision)*

---

## The Problem Solved

Currently, to deploy Protocol-7 functionality:

**Traditional approach** (complex):
```
1. Clone protocol-7 repository
2. Run dependency installer
3. Configure zenka
4. Test
5. Deploy to remote
6. Manage updates
7. Handle permission conflicts
```

**Self-contained approach** (elegant):
```
1. Run: ./p7-custom-web-dev.pl
2. It extracts itself to ~/.p7/web-dev/
3. Loads dependencies
4. Sets permissions
5. Ready to use
```

---

## The Infrastructure Already Exists

The DATA block in `bin/Protocol-7`:

```perl
__DATA__
# Base32-encoded, xz-compressed subroutines
# Already used for inline subroutine distribution
```

This mechanism can be extended to include:
- Source code (subroutines)
- Filesystem metadata (owners, permissions, structure)
- Dependency manifests (what modules needed)
- Configuration templates
- Inline documentation

---

## Architecture: Executable Package Format

### Structure of a Self-Contained Script

```perl
#!/usr/bin/env perl
# Protocol-7 Self-Contained Package: web-dev-session-2025-11-27

use strict;
use warnings;
use Protocol7::Package;  # Extraction & installation framework

# Metadata
my %package = (
    name => 'web-dev-session',
    version => '2025-11-27',
    context => 'web development',
    zenka => [qw(httpsd letsencr workflow discover)],
    dependencies => {
        cpan => [qw(JSON::XS URI HTTP::Request)],
        debian => [qw(libssl-dev)],
    },
    filesystem => {
        'cfg/zenki/httpsd/' => { mode => 0755, owner => 'p7' },
        'cfg/zenki/letsencr/' => { mode => 0755, owner => 'p7' },
    },
);

# When executed:
Protocol7::Package->extract(\%package);
Protocol7::Package->install_dependencies(\%package);
Protocol7::Package->set_permissions(\%package);
Protocol7::Package->initialize(\%package);

__DATA__
# Base32-encoded, xz-compressed archive containing:
# - Source code for selected zenka
# - Configuration templates
# - Inline filesystem structure
# - Dependency manifests
# - Permission metadata
```

### What the DATA Block Contains

```
ARCHIVE FORMAT:
├─ Magic number: "P7PKG"
├─ Version: 1
├─ Metadata section
│  ├─ Package name
│  ├─ Version
│  ├─ Creation date
│  └─ Checksum
├─ Zenka section (xz compressed, base32 encoded)
│  ├─ zenka-name/module.pm
│  ├─ zenka-name/pm-dep/Module__Name
│  └─ zenka-name/os-dep/debian/package-name
├─ Filesystem section
│  ├─ Path: cfg/zenki/httpsd/
│  ├─ Mode: 0755
│  ├─ Owner: p7
│  └─ Group: p7
├─ Configuration templates
│  ├─ settings.yaml (template)
│  └─ environment.json (template)
└─ Signature (optional, for verification)
```

---

## Use Cases Enabled

### Case 1: Custom Session Distribution

Developer creates a custom web-dev environment:

```bash
# Extract zenka needed for web development
bin/p7-pack extract \
  --zenka httpsd \
  --zenka letsencr \
  --zenka workflow \
  --context "web-dev-session-2025-11-27" \
  --output ./web-dev.pl

# Result: Single executable script containing:
# - All three zenka source code
# - Their module dependencies
# - Configuration templates
# - Filesystem structure metadata
```

**Another developer receives it:**

```bash
./web-dev.pl --extract  # or just run it directly
→ Unpacks to ~/.p7/web-dev-session-2025-11-27/
→ Installs dependencies
→ Sets permissions
→ Ready to use

./web-dev.pl --status
→ Shows what's installed, version, dependencies
```

### Case 2: Customized Packages for Different Contexts

```bash
# Security researcher package
bin/p7-pack create \
  --include-zenka crypto,keys,discover \
  --name "security-research" \
  --output ./security-toolkit.pl

# Web developer package
bin/p7-pack create \
  --include-zenka httpsd,letsencr,workflow,discover \
  --name "web-dev-toolkit" \
  --output ./web-dev-toolkit.pl

# Data scientist package
bin/p7-pack create \
  --include-zenka data,calc,discover \
  --name "data-science-toolkit" \
  --output ./data-toolkit.pl

# Each is a single ~2-3MB self-contained executable
```

### Case 3: Safe Script Management

Scripts can be:
- **Signed**: Include cryptographic signature
- **Verified**: Check before extraction
- **Versioned**: Multiple versions coexist
- **Updated**: New versions replace old, keep data
- **Audited**: Log what was extracted where

```bash
./web-dev.pl --verify
→ Checks signature against trusted keys
→ Validates archive integrity
→ Reports: "Valid, created 2025-11-27, signed by maintainer"

./web-dev.pl --extract --prefix /opt/p7/
→ Extract to custom location
→ Verify permissions will be set correctly
→ Set ownership, permissions
```

### Case 4: Convenience Interfaces

The script becomes an installer, manager, and interface:

```bash
./web-dev.pl --status
→ Show what's installed, versions, last updated

./web-dev.pl --update
→ Check for newer version
→ Download if available
→ Extract updates
→ Reload services

./web-dev.pl --shell
→ Drop into environment with PATH set
→ All zenka available
→ Exit returns to normal shell

./web-dev.pl --run <command>
→ Run command in package context
→ Load all dependencies
→ Clean up after

./web-dev.pl --uninstall
→ Remove package files
→ Preserve user data
→ Clean up filesystem
```

---

## Implementation Framework

### Protocol7::Package Module

```perl
package Protocol7::Package;

sub extract {
    my ($class, $pkg) = @_;
    # 1. Decompress DATA block
    # 2. Parse archive
    # 3. Extract files to target location
    # 4. Return manifest
}

sub install_dependencies {
    my ($class, $pkg) = @_;
    # 1. Parse dependency manifest
    # 2. Call bin/p7-deps install <profile>
    # 3. Return installation report
}

sub set_permissions {
    my ($class, $pkg) = @_;
    # 1. Read filesystem metadata
    # 2. Set owners/modes on extracted files
    # 3. Verify permissions
}

sub initialize {
    my ($class, $pkg) = @_;
    # 1. Source configuration templates
    # 2. Initialize environment
    # 3. Test connectivity
    # 4. Report ready/errors
}

sub verify {
    my ($class, $script_path) = @_;
    # 1. Check magic number
    # 2. Verify signature (if present)
    # 3. Check archive integrity
    # 4. Return verification result
}

sub sign {
    my ($class, $script_path, $key) = @_;
    # 1. Read script
    # 2. Extract archive
    # 3. Compute signature
    # 4. Embed signature
    # 5. Recompress
}
```

### bin/p7-pack Command

```bash
bin/p7-pack create [OPTIONS]
  --include-zenka <zenka1,zenka2,...>
  --name <package-name>
  --output <filename>
  --sign <key> (optional)
  --version <version> (auto: date)
  --context <description>

bin/p7-pack extract <script.pl>
  --verify (check signature)
  --prefix <location> (default: ~/.p7/)
  --list (show what would be extracted)

bin/p7-pack inspect <script.pl>
  (Show package metadata, zenka, dependencies, version)
```

---

## Why This Works So Well

### Integration with Existing Infrastructure

1. **Lazy Loading**: Package contains only what's needed for context
2. **Intent-Driven Profiles**: Package created from session profile
3. **Dependency Tracking**: Manifest derived from actual usage
4. **Filesystem Metadata**: Already tracked in zenka configurations
5. **Signing/Verification**: Reuses existing AMOS7 signature infrastructure

### Distribution Benefits

- **Portability**: Works on any system with Perl installed
- **Self-Contained**: No git clone, no setup scripts
- **Version Control**: Package is a versioned unit
- **Safe**: Can verify before extracting
- **Minimal**: Only needed code included
- **Updatable**: New versions can replace old

### Development Benefits

- **No implementation overhead**: Uses existing DATA block format
- **Flexible packaging**: Combine any zenka into package
- **Convenient deployment**: Single file instead of repository
- **Easy sharing**: Email a script, share via HTTP
- **Natural evolution**: Emerges from lazy loading + intent tracking

---

## Example Workflow

### Session 1: Web Development Work

```bash
# Developer works on web features
bin/p7-deps analyze-sessions --intent-driven
→ Detected: httpsd, letsencr, workflow, discover used

# Create package from this session
bin/p7-pack create \
  --from-session recent \
  --name "web-dev-session-2025-11-27" \
  --output ./my-web-dev.pl \
  --sign ~/.p7/keys/my-key

# Share it
scp ./my-web-dev.pl colleague@remote.host:
```

### Session 2: Colleague Uses Package

```bash
# Receive and inspect
./my-web-dev.pl --inspect
→ Shows: httpsd, letsencr, workflow, discover
→ Shows: 42 CPAN modules, 2 Debian packages
→ Shows: Signed by Alice on 2025-11-27

# Verify (check signature)
./my-web-dev.pl --verify
→ Valid signature from trusted key

# Extract and use
./my-web-dev.pl --extract
→ Unpacks to ~/.p7/web-dev-session-2025-11-27/
→ Installs dependencies
→ Sets permissions
→ Ready to use

# Or run in isolated context
./my-web-dev.pl --shell
→ $ cd my-project && ./script.pl
→ (All zenka available in this environment)
→ $ exit
→ (Back to normal shell)
```

### Session 3: Package Evolution

```bash
# Someone improves the package
bin/p7-pack create \
  --from-previous my-web-dev.pl \
  --add-zenka analytics \
  --remove-zenka discover \
  --version "2025-11-28" \
  --sign ~/.p7/keys/my-key

# Can be shared, versioned, evolved
# Old versions still available
# Users choose which to use
```

---

## Connection to Larger Architecture

### The Full Stack

```
Lazy Loading (Layer 4)
    ↓
Subroutine-level tracking
    ↓
Per-context extraction
    ↓
Self-contained package
    ↓
Single executable file
    ↓
Safe distribution/deployment
```

### Distribution Model

```
Traditional:
  repo → dependencies → install → configure → use

Protocol-7 Package:
  single file → verify → extract → use
  (dependencies, configuration all included)
```

### Scaling Implication

Can distribute Protocol-7 capabilities as:
- Single files (executable packages)
- Easy to share, version, verify
- No complex setup required
- Works on constrained hardware (lazy-loaded)
- Safe (signed and verified)
- Composable (create new packages from existing ones)

---

## Status & Timeline

**Foundation Ready** ✅
- DATA block format exists in bin/Protocol-7
- Base32/xz compression already used
- Filesystem metadata tracking available
- Signing infrastructure exists (AMOS7)

**Implementation Phases**

Phase 1: Protocol7::Package module (1-2 sessions)
- Extract/verify functions
- Permission setting
- Dependency installation

Phase 2: bin/p7-pack command (1-2 sessions)
- Create packages from sessions
- Inspect packages
- Sign/verify packages

Phase 3: Package management (ongoing)
- Version control of packages
- Distribution infrastructure
- Registry/discovery system
- Update checking

---

## The Elegant Part

This emerges naturally from previous layers:

1. **Lazy loading** made packages lean
2. **Intent-driven tracking** made package creation automatic
3. **Filesystem metadata** made permissions portable
4. **Signing infrastructure** made distribution safe
5. **DATA block format** made packaging straightforward

No architectural redesign needed. Just extend existing patterns.

**Result**: Users can receive a single executable file, run it, and have a complete, working Protocol-7 environment ready for their context.

The complexity is hidden. The simplicity is visible.

---

**Vision Status**: Ready for implementation
**Integration Points**: Protocol7::Package module, bin/p7-pack command, existing DATA block infrastructure
**Impact**: Transforms Protocol-7 from repository-based to file-based distribution
**Scalability**: Enables Protocol-7 to reach users who can't clone repositories or run complex setup scripts
