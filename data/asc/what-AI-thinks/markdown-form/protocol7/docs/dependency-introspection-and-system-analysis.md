# Dependency Introspection and System Analysis Tools

*Insights from restoring lost functionality in bin/p7-deps (2025-11-27)*

---

## What Was Recovered

During a refactoring from commit 3129bedd1, valuable introspection and styling functionality was
lost from `bin/p7-deps`. This document describes what was recovered and why it matters.

### Lost During Refactoring

The transition from monolithic `base.known_dependencies` format to profile-based YAML management
removed these valuable tools:
- **Styling functions** - Colorful, consistent visual output (the "psychedelic styling")
- **Introspection functions** - Tools to understand module/package dependencies
- **Validation commands** - Commands to audit zenka declarations

### Recovered Functionality

**Styling Layer**:
- `print_header()` - Formatted section headers with Nailara branding colors
- `print_section()` - Subsection headers with bright blue coloring
- `print_status()` - Status indicators with ✓/❌/⚠ symbols
- `print_error()` - Formatted error messages with orange emphasis

**Introspection Layer**:
- `get_zenki_pm_deps()` - Scan zenka configurations for CPAN module dependencies
- `get_zenki_os_deps()` - Scan zenka configurations for OS-level dependencies

**Commands**:
- `bin/p7-deps zenka-modules` - Map CPAN modules to zenka that declare them
- `bin/p7-deps zenka-packages` - Map OS packages to zenka that declare them
- `bin/p7-deps validate` - Validate all zenka dependency declarations

---

## Why This Matters

### System Understanding

The introspection commands provide critical insight into the system topology:

```
bin/p7-deps validate
→ Found 40 zenka with declared dependencies
→ 117 CPAN modules, 8 Debian packages, 25 binary requirements
→ Detailed breakdown of which zenka depend on what
```

This enables:
1. **Understanding distribution** - See which zenka are tightly coupled vs. independent
2. **Identifying modules** - Know which zenka use which CPAN modules
3. **Dependency mapping** - Visualize the dependency graph at the zenka level
4. **Validation** - Ensure declarations match actual requirements

### Code Quality Analysis

The detailed mapping enables several quality analysis tasks:

**Finding Over-Declaration**
- Which zenka declare dependencies they don't actually use?
- Command: `zenka-modules` sorted by zenka to see what each declares

**Finding Orphaned Dependencies**
- Which zenka are the only users of a dependency?
- Could that dependency be moved, shared, or made optional?

**Understanding Coupling**
- Which zenka share many dependencies (high coupling)?
- Which zenka are mostly independent?
- This reveals natural clustering for refactoring

**Optimization Opportunities**
- Which modules are used by many zenka? (candidate for framework layer)
- Which modules are only used by one zenka? (candidate for specialization)

### Aesthetic and Coherence

The styling functions weren't just visual decoration:

**Consistent Visual Language**
- Nailara branding colors throughout output
- Consistent formatting makes output professional and navigable
- Users learn to recognize status, sections, and errors visually

**Practical Visual Feedback**
- Color-coded status (green=ok, orange=error, purple=section)
- Makes scanning large output much faster
- Matches the "psychedelic aesthetic" that Protocol-7 embraces

**Integration with Topology**
- The cubic topology is strongly visual
- Consistent visual language in tools reinforces that the system thinks geometrically
- When everything looks good, it feels right

---

## Current System Data

Running `bin/p7-deps validate` reveals the current dependency landscape:

### Zenka Dependency Distribution

**High Dependency Zenka** (5+ dependencies):
- zulum (19 CPAN modules + binaries) - Core cryptography and utilities
- workspace-transfer (15 modules + packages) - External integration
- stochencam (13 CPAN modules) - Media processing
- web-browser (9 CPAN modules) - Web integration
- workflow (7 CPAN modules) - Task management
- v7 (6 CPAN + packages + binaries) - Master process manager
- httpsd (6 CPAN modules) - HTTPS server

**Mid-Dependency Zenka** (2-4 dependencies):
- X-11, discover, power, ticker, universal, letsencr, keys, etc.

**Minimal Zenka** (1 dependency):
- acquire, calc, data, fs, image2html, index, melt, mpv, notify, openbox, etc.

### Dependency Types

**CPAN Modules by Category**:
- Cryptography: Crypt::* (Ed25519, Curve25519, ChaCha20Poly1305, RSA, X509, etc.)
- Async/IO: Event, IO::*, AnyEvent
- Web: URI, HTTP::*, LWP::*
- Graphics: Cairo, Image::EXIF, X11::*
- Data: JSON::XS, YAML, Config::Hosts

**OS Packages**:
- X11 tooling (Xephyr, Xnest, Xorg, Xvfb, hsetroot, etc.)
- Development tools (gcc, libc6-dev, git, perl, cpanm)
- System utilities (modprobe, rmmod, shred, udevadm)
- Media tools (ffmpeg, ffprobe, melt, mpv)

**Binary Requirements**:
- X servers and utilities (Xnest, nxagent, hsetroot)
- Media tools (ffmpeg, ffprobe, melt, mpv)
- System commands (modprobe, rmmod, udevadm, unbuffer)
- UI tools (notify-send, openbox, Xephyr)

---

## Usage Examples

### Explore Module Dependencies

```bash
# Show all modules sorted by name (module → zenka)
bin/p7-deps zenka-modules

# Show all modules sorted by zenka (zenka → modules)
bin/p7-deps zenka-modules zenka

# Find which modules workflow zenka uses
bin/p7-deps zenka-modules | grep workflow
```

### Explore Package Dependencies

```bash
# Show all OS packages by name
bin/p7-deps zenka-packages

# Show all OS packages grouped by zenka
bin/p7-deps zenka-packages zenka

# Find which zenka need X11
bin/p7-deps zenka-packages | grep Xorg
```

### Validate System

```bash
# Full validation report
bin/p7-deps validate

# Count total dependencies
bin/p7-deps validate | grep "Total"

# See dependency breakdown by zenka
bin/p7-deps validate | tail -50
```

---

## Implications for Future Development

### Code Refactoring

When refactoring zenka:
1. Use `zenka-modules <zenka>` to see what it needs
2. If modules are shared with many other zenka, they belong in shared framework
3. If modules are unique, they're safe to optimize or refactor
4. Check if declared dependencies match actual usage

### Adding New Zenka

When creating a new zenka:
1. Use `zenka-modules zenka` to see the distribution of module usage
2. Position it close to zenka with high overlap
3. Create pm-dep/ and os-dep/ directories with needed modules
4. Run `validate` to confirm declarations
5. These become part of the system's self-documentation

### Dependency Optimization

When optimizing dependencies:
1. Run `zenka-modules` to find modules used by many zenka (candidates for framework)
2. Run `zenka-packages` to find packages used by few zenka (candidates for specialization)
3. Use introspection to validate that refactoring didn't break dependencies
4. The system documents itself through its introspection

### Learning System Architecture

For new developers understanding Protocol-7:
1. Start with `zenka-modules zenka` to see which zenka share which modules
2. This reveals natural clustering and coupling
3. Understand why the system is structured this way (module overlap)
4. See how dependencies drive topology

---

## The Lesson: Don't Lose Tools in Refactoring

This recovery demonstrates an important principle:

**Refactoring the implementation shouldn't remove the interfaces.**

When we moved from `base.known_dependencies` to `profiles.yaml`:
- ❌ The old introspection tools were lost
- ✅ The new system worked, but became opaque
- ✅ Recovering introspection tools restored transparency

The right approach:
1. Refactor the backend (how we store/manage deps)
2. Keep or rebuild the interfaces (how we understand deps)
3. Tools that understand the system are as important as tools that manage it

---

## Files and Commands

**Tool Location**: `/home/user/protocol-7/bin/p7-deps`

**Key Functions**:
- `get_zenki_pm_deps()`: Lines 520-547
- `get_zenki_os_deps()`: Lines 549-587
- `print_header()`, `print_section()`, `print_status()`, `print_error()`: Lines 591-612
- `show_zenka_modules()`: Lines 386-425
- `show_zenka_packages()`: Lines 427-468
- `validate_zenka_declarations()`: Lines 470-516

**Zenka Configuration Locations**:
- CPAN modules: `configuration/zenki/<zenka>/pm-dep/`
- Debian packages: `configuration/zenki/<zenka>/os-dep/debian/`
- Binary requirements: `configuration/zenki/<zenka>/os-dep/binary/`

**Commands**:
```bash
bin/p7-deps zenka-modules [module|zenka]      # Show module dependencies
bin/p7-deps zenka-packages [package|zenka]    # Show package dependencies
bin/p7-deps validate                          # Validate all declarations
bin/p7-deps list                              # List profiles
bin/p7-deps check <profile>                   # Check profile status
bin/p7-deps install <profile>                 # Install profile
bin/p7-deps help                              # Show help
```

---

**Recovered**: 2025-11-27
**Commit**: 0cd20db98 "feat: Restore styling and introspection functionality to bin/p7-deps"
**Status**: Fully functional with comprehensive introspection capabilities restored

This recovery ensures that the dependency management system isn't just practical, but also
provides the deep system understanding that enables good design decisions.
