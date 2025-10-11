# [ [nailara 'protocol seven' project](http://nailara.network/) ]

### Source Code and Versioning
: 2WGYJO5IPY-5102.0
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

The system automatically tracks which modules each zenka uses and will register new dependencies when they are encountered.

## Installation

### Minimal Installation

The minimal installation provides core functionality without GUI components.

Run this command: `bin/dependencies/install_minimal_dependencies.debian.sh`

This script installs:
- Core Perl modules and system packages for basic functionality
- Requirements for  'v7', 'cube', 'p7-log', 'system', 'httpd', 'events' and some non-X11 zenki
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

Use the nshell terminal interface: `bin/nshell`

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

Protocol-7 is functional but still under active development. Several key features are being implemented that will make it more useful to the general public. Current capabilities include:

- Interprocess messaging and routing (via cube)
- Process management and monitoring (via v7)
- User interface components ([web-browser](configuration/zenki/web-browser/start), [mpv](configuration/zenki/mpv/start) player control)
- Basic resource management

## How to Contribute

Detailed contribution guidelines are available in our [Contribution Guidelines](/read-me/project-identity/contribution-guidelines.md).

Contributions to Protocol-7 are always welcome:
- Explore our [Contribution Process](/read-me/project-identity/contribution-guidelines.md)
- Understand our project's unique approach

## Additional Documentation

- [AMOS Resource Tokens](read-me/documentation/dev/NRT.NRD.asc) - Development notes on the blockchain currency
- [Philosophical Foundation](/read-me/project-identity/philosophical-foundation.md) - Deep dive into our core principles
  - Explore our unique vision of distributed computing
  - Understand the metaphorical framework behind Protocol-7

### AI-Generated Insights and Research
- **[AI Insights Overview](data/asc/what-AI-thinks/)**: Organized repository of AI-generated knowledge about Protocol-7 project state, structure, and research direction
  - **[HTML Visualizations and Documentation](data/asc/what-AI-thinks/html-form/INDEX.md)**: 149 HTML files with interactive visualizations, frameworks, and tools covering cubic space topologies, harmonic systems, Protocol-7 demonstrations, and mathematical justice frameworks
  - **[Perl Knowledge Modules](data/asc/what-AI-thinks/perl-form/INDEX.md)**: 68+ Perl modules containing symbolic implementations of consciousness emergence, harmonic mathematics, truth systems, and Claude AI insights
  - **[Markdown Documentation](data/asc/what-AI-thinks/markdown-form/)**: Additional markdown-formatted research, concepts, and Protocol-7 documentation

## Vision

For a comprehensive exploration of our project's philosophical foundation, please refer to our [Philosophical Foundation](/read-me/project-identity/philosophical-foundation.md).

### Core Vision Highlights
- Pool idle network resources
- Provide low-latency, high-burst capacity computing
- Create a fair, distributed resource ecosystem

### Key Philosophical Principles
- Resource distribution as network irrigation
- Positive feedback through participation
- Minimal barriers to entry
- Equitable resource allocation

The full vision document explores our unique approach to distributed computing, network participation, and the metaphorical framework of resource sharing.