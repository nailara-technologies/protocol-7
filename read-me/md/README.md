
::: SOURCE-CODE VERSION :: 3OYNBO6SNY-6336.0 :::

# [ [nailara 'protocol seven' project](http://protocol-7.network/) ]

### Source Code and Versioning

- Detailed version information: [Source Code Versions](/read-me/project-identity/source-code-versions.md)
- Current source code version tracking available in dedicated documentation

### Licensing

- [Licensing Details](/read-me/project-identity/licensing-details.md)
- This is the public domain licensed 'base' branch

---
## Release Information

- Detailed release history: [Release Versions](/read-me/project-identity/release-versions.md)
- Current [release](https://github.com/nailara-technologies/protocol-7/tags) version \\// [AMOS7-v2.79.7](https://github.com/nailara-technologies/protocol-7/releases/tag/AMOS7-v2.79.7)
---

## 🌐 Live Demo

**Interactive Hyperspace Field Visualization** - Experience Protocol-7's cubic space topology in real-time:

### **[http://visual.v7.ax/](http://visual.v7.ax/)**

[![Hyperspace Field Demo](data/asc/what-AI-thinks/html-form/visualizations/cubic-space/remote/screen.0.png)](http://visual.v7.ax/)

*Click the screenshot above to launch the interactive demo*

Features real-time 3D navigation, dynamic neighbor layers, psychedelic hue rotation, and adaptive rendering. Showcases the harmonic computing principles of cubic space topology with critically damped inertia physics and multi-axis grid-aligned navigation. Bilingual interface (English/German).

---

## Introduction

Protocol-7 is a multi-agent system framework written in Perl. It implements a harmonically designed network of cooperating agents (called "zenki") that can communicate with each other through a standardized message protocol. The system is designed to provide a flexible and extensible platform for building distributed applications, with a focus on harmonic computing principles.

## Directory Structure

- **[bin/](bin/)**: Executables and utilities including the [Protocol-7](bin/Protocol-7) interpreter
- **[configuration/](configuration/)**: Zenki configuration files and system settings
- **[modules/](modules/)**: Core functionality modules loaded by zenki at runtime
- **[data/](data/)**: Resources, assets, libraries and supporting files
- **[read-me/](read-me/)**: Additional documentation and license information

## Dependencies

Protocol-7 uses a sophisticated dependency tracking system to manage Perl module requirements:

- **Core Dependencies**: Perl 5.28.0 or newer
- **Perl Modules**: Required modules are tracked in the `pm-dep` directory of each zenka and mapped in [modules/base.known_dependencies](modules/base.known_dependencies)
- **Package Management**: Dependencies can be resolved from Debian packages or CPAN as specified in the dependency mappings
- **Dependency Manager**: [bin/p7-deps](bin/p7-deps) provides comprehensive dependency analysis and installation

The system automatically tracks which modules each zenka uses and will register new dependencies when they are encountered.

### Dependency Management with bin/p7-deps

The `bin/p7-deps` tool provides both analysis and installation capabilities:

**Analysis Commands:**
- `bin/p7-deps list` - Show all dependencies from all sources
- `bin/p7-deps check [profile]` - Check aggregated dependencies for a profile
- `bin/p7-deps generate` - Generate YAML from Protocol-7 dependencies

**Installation Commands:**
- `bin/p7-deps install [profile]` - Install all dependencies (APT + CPAN)
- `bin/p7-deps install-apt [profile]` - Install only Debian packages
- `bin/p7-deps install-cpan [profile]` - Install only CPAN modules

**Installation Options:**
- `--dry-run` - Preview what would be installed without making changes
- `--verbose` or `-v` - Show detailed output during installation

**Features:**
- Automatic root detection (skips sudo when running as root)
- Aggregates dependencies from base.known_dependencies and all zenki configurations
- Supports profile-based installation (default: protocol7_full)
- Self-contained: no need for workspace-transfer repository

## Installation

### Recommended: Using bin/p7-deps

The easiest way to install Protocol-7 dependencies is using the built-in dependency manager:

**Preview what will be installed:**
```bash
bin/p7-deps --dry-run install
```

**Install all dependencies:**
```bash
bin/p7-deps install
```

**Install only what you need:**
```bash
bin/p7-deps install-apt          # Debian packages only
bin/p7-deps install-cpan         # CPAN modules only
```

This approach:
- Automatically detects if running as root
- Aggregates all dependencies from zenki configurations
- Provides clear status output with Protocol-7 styling
- Optionally generates dependency reports for documentation

### Legacy: Using Debian Installation Scripts

For backwards compatibility, traditional installation scripts are still available:

### Minimal Installation

The minimal installation provides core functionality without GUI components.

Run this command: `bin/dependencies/install_minimal_dependencies.debian.sh`

This script installs:

- Core Perl modules and system packages for basic functionality
- Requirements for 'v7', 'cube', 'p7-log', 'system', 'httpd', 'events' and some non-X11 zenki
- Creates necessary symlinks and systemd service

### Full Installation

For a complete installation including desktop/GUI components, run both scripts in sequence:

First: `bin/dependencies/install_minimal_dependencies.debian.sh`

Then: `bin/dependencies/install_dependencies.debian.sh`

The full installation adds:

- GUI-related packages (mpv, Xvfb, OpenBox, etc.)
- Additional Perl modules for graphical zenki

Note: For browser agent functionality, see additional dependencies in the browser agent dependencies script.

### Starting the System

To start Protocol-7 with the v7 zenka, run: `bin/Protocol-7 v7`

Alternatively, to use systemd:

- Enable: `systemctl enable Protocol-7`
- Start: `systemctl start Protocol-7`

### Interacting with the System

Three primary methods for interacting with the Protocol-7 network:

1. **nshell Zenka Terminal Interface** (Recommended) ✅ Fully Refactored
   ```bash
   p7.nshell
   ```
   or equivalently:
   ```bash
   ./bin/Protocol-7 nshell
   ```
   - Interactive shell for direct Protocol-7 network access
   - Pure-Perl implementation with non-blocking I/O
   - Full UTF-8 support with proper character buffering
   - **Enhanced history navigation**: Session-based Page Up/Down with LIFO symmetry
   - **Sequential arrow keys**: Up/Down navigate sequentially through history
   - **Ctrl+R search**: Real-time history search with phosphor-colored search term display
   - Strips protocol reply strings for cleaner output (similar to p7c and p-7-r)
   - ✅ All navigation features fully tested and production-ready

   See: [`NSHELL_REFACTORING_COMPLETED.md`](./data/md/documentation/NSHELL_REFACTORING_COMPLETED.md) for implementation details

   **Legacy Alternative:** `bin/nshell`
   - Still available for compatibility
   - Prints full protocol reply strings for debugging
   - Use when you need to see complete protocol details

2. **Command Execution Binaries**

   **p7c** (protocol-7 command):
   ```bash
   p7c <command> [args]
   ```
   - Local command execution
   - Automatically compiled and installed during v7 zenka startup
   - Connects directly to the Protocol-7 network
   - Uses current Unix user for authentication
   - Installed at: `/usr/local/bin/p7c`

   **p-7-r** (protocol-7 remote):
   ```bash
   p-7-r <command> [args]
   ```
   - Remote command execution over network
   - Automatically compiled and installed during v7 zenka startup
   - Enables distributed command access
   - Installed at: `/usr/local/bin/p-7-r`

   ### Common Commands

   - `p7c list sessions`: Display active network sessions
     ```
      : usid :.  : protocol :.  : type :.  : mode :.  : uname :.    : since :.
     --------------------------------------------------------------------------
       4304425     protocol-7     unix      server       -----          57.93s
       5790075     protocol-7     unix      client        v7            57.90s
       ...
     ```

   - `p7c commands`: List available commands for the current zenka

     - Displays command categories like:
       * Zenka management
       * Network time functions
       * Session handling
       * Cryptographic utilities

   ### Command Routing Mechanism

   - Local Context Commands:
     * `p7c commands`: Commands for the currently connected zenka (local cube)
     * `p7c <zenka>.commands`: Commands for specific zenki
     * Recursive routing possible: `p7c weather.child.commands`

   ### Zenka-Specific Command Discovery

   - `p7c v7.list`: Lists specific to the v7 zenka
     ```
      : list name :.  : description :.
     -----------------------------------------------------
       dependency    current zenka dependency status
       available     available zenki and descriptions
       subnames      'subnames' of registered zenki
       children      PIDs of zenki and their children
     ```

   ### Routing Principles

   - No `.` in command: Routes to local context
   - `.` in command: Routes to specified zenka or nested zenki
   - Enables flexible, hierarchical command routing

   ### Command Capabilities

   - Discover and interact with any zenka
   - Retrieve zenka-specific lists and information
   - Manage network sessions
   - Execute operations across different agents

## Key Concepts

- **Zenki**: Autonomous agents that perform specific functions
- **Cube**: A message routing zenka that enables inter-zenka communication
- **Protocol-7**: The interpreter that loads and runs zenki
- **Harmonic Computing**: The design principle ensuring system coherence through mathematical harmony

## System Architecture

The Protocol-7 system consists of interconnected zenki (agents) that communicate through a standardized message protocol:

1. The [v7](configuration/zenki/v7/start) zenka manages the lifecycle of other zenki
2. The [cube](configuration/zenki/cube/start) zenka routes messages between other zenki
3. Specialized zenki perform tasks ranging from system management to user interface presentation
4. Custom zenki can be created by adding configuration files and module code

The system can be started with [systemd](data/lib-path/systemd/system/Protocol-7.service) or run directly from the terminal.

## Protocol Design Philosophy

Protocol-7 uses a human-readable message protocol by deliberate design, not as a concession to inefficiency. This human-readable aspect serves multiple important functions:

1. **Topological Significance**: Every command, namespace, and identifier in the protocol has a specific topological meaning within the cubic space architecture of the system.

2. **Self-Documenting System**: The human-readable nature ensures that interactions with the system remain transparent and accessible, facilitating both debugging and learning.

3. **Harmonic Integration**: The protocol's structure is aligned with the same principles of harmonic resonance that inform the overall system design, creating coherence at all levels of operation.

This design choice reflects the belief that clarity and structure at the protocol level enable more complex emergent behaviors to develop naturally throughout the system as it scales.

## Resource Naming and Addressing

Resources in Protocol-7 (especially in the [data/gfx/backgrounds/](data/gfx/backgrounds/) directory) use cryptographic hash filenames of various lengths, transitioning towards a standardized form to ensure unique and verifiable resource identification across the network.

## Current Status

Protocol-7 is functional and actively evolving with high iteration frequency on core infrastructure and essential zenki. The system is transitioning from foundational components toward feature-rich distributed capabilities.

### Established Infrastructure

- **Interprocess Communication**: Message routing via cube zenka with Unix domain and TCP socket support
- **Process Management**: Lifecycle management and monitoring via v7 zenka with automatic zenka startup, monitoring, and restart capabilities
- **Interactive Interfaces**:
  - nshell zenka with buffered non-blocking I/O and full UTF-8 support
  - p7c (protocol-7 command) and p-7-r (protocol-7 remote) binaries for direct command access
- **User Interface Components**: Web-browser automation, mpv media player control, desktop integration
- **Cryptographic Infrastructure**: Curve25519 key management, multiple checksum algorithms (AMOS, BMW, ELF, JHA)

### Recent Developments

- **Basic LLM Integration**: Emerging capabilities for AI-assisted operations and analysis
- **Link-Level Encryption**: Implementation of encrypted communication channels for enhanced security
- **Network Enhancements**: Upgrading core transport and protocol layers for improved performance and reliability
- **Essential Zenki Expansion**: Rapid iteration on new core agents for system capabilities

### Development Pace

The project maintains a high iteration frequency, regularly introducing new zenki modules and system enhancements. The architecture supports easy extension with new agents, and the dependency tracking system automatically manages module requirements across the network.

## How to Contribute

Detailed contribution guidelines are available in [Contribution Guidelines](/read-me/project-identity/contribution-guidelines.md).

Contributions to Protocol-7 are always welcome:

- Explore the [Contribution Process](/read-me/project-identity/contribution-guidelines.md)
- Understand the project's unique approach

## Additional Documentation

- [AMOS Resource Tokens](read-me/documentation/dev/NRT.NRD.asc) - Development notes on the blockchain currency
- [Philosophical Foundation](/read-me/project-identity/philosophical-foundation.md) - Deep dive into core principles
  - Explore the unique vision of distributed computing
  - Understand the metaphorical framework behind Protocol-7

### AI-Generated Insights and Research

- **[AI Insights Overview](data/asc/what-AI-thinks/)**: Organized repository of AI-generated knowledge about Protocol-7 project state, structure, and research direction
  - **[HTML Visualizations and Documentation](data/asc/what-AI-thinks/html-form/INDEX.md)**: 149 HTML files with interactive visualizations, frameworks, and tools covering cubic space topologies, harmonic systems, Protocol-7 demonstrations, and mathematical justice frameworks
  - **[Perl Knowledge Modules](data/asc/what-AI-thinks/perl-form/INDEX.md)**: 68+ Perl modules containing symbolic implementations of consciousness emergence, harmonic mathematics, truth systems, and Claude AI insights
  - **[Markdown Documentation](data/asc/what-AI-thinks/markdown-form/)**: Additional markdown-formatted research, concepts, and Protocol-7 documentation

## Vision

For a comprehensive exploration of the project's philosophical context, please refer to [Philosophical Foundation](/read-me/project-identity/philosophical-foundation.md).

### Core Vision Highlights

- Pool idle network resources
- Provide low-latency, high-burst capacity computing
- Create a fair, distributed resource ecosystem

### Key Philosophical Principles

- Resource distribution as network irrigation
- Positive feedback through participation
- Minimal barriers to entry
- Equitable resource allocation

### The Overflow Principle

After the network is saturated with what it needs to maintain a stable
topology, a kind of overflow becomes available that is then distributed
equally to the individual users.  This ensures fair distribution and creates
a positive feedback loop where more participation leads to better
performance for all.  Like water irrigating farmland, each participant
receives resources proportional to their contribution, while public resource
pools ensure that even newcomers can participate without barriers.

What makes this approach elegantly simple is the use of statistical average
user metrics (e.g., total network disk space divided by number of users) to
determine optimal resource allocation.  This statistical approach enables
calculating resource values and costs without needing to look up specific
accounts, thereby enhancing anonymization throughout the network.

The full vision document explores Protocol-7's unique approach to
distributed computing, network participation, and the metaphorical framework
of resource sharing.

#,,.,,,.,,,,.,,,.,,,.,.,.,,,,,,..,,.,,,.,,.,.,..,,...,...,...,,,,,...,..,,,,,,
#O6IXKTLNWLQH423UIASDHZMMJSXEP7S3PXS6IJFQCF5VTS6APY2DB3HH6VQCUR7PNR5DYFESLBMPE
#\\\|JJ2MCPR26NPXSZ4LKAL7VCDM3GDUYXRLPOVOOYRYPHJCBDJXDWQ \ / AMOS7 \ YOURUM ::
#\[7]HWIF34GCMM3JOLJMJ5QCL3JCIVBVXKAGWOJCEYF62C2VR33I72CY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
