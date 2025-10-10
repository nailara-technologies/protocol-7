
# [ [nailara 'protocol seven' project](http://nailara.network/) ]

### [ source code version : 2WGYJO5IPY-5102.0 ]

### this is the public domain [license](license)d 'base' branch
---
## current [release](https://github.com/nailara-technologies/protocol-7/tags) version \\\\// [AMOS7-v2.79.7](https://github.com/nailara-technologies/protocol-7/releases/tag/AMOS7-v2.79.7)
---

## Introduction

Protocol-7 is a multi-agent system framework written in Perl. It implements a harmonically designed network of cooperating agents (called "zenki") that can communicate with each other through a standardized message protocol. The framework enables the creation of distributed applications spanning from simple automation tasks to complex workload distribution systems.

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

Resources in Protocol-7 (especially in the [data/gfx/backgrounds/](data/gfx/backgrounds/) directory) use cryptographic hash filenames of various lengths, transitioning towards a standardized format of base-32 encoded Blue Midnight Wish checksums. This naming scheme is strategic - these filenames will later serve as addressable routes in a cubic space topology, aligning with the system's harmonic design principles.

## Current Status

Protocol-7 is functional but still under active development. Several key features are being implemented that will make it more useful to the general public. Current capabilities include:

- Interprocess messaging and routing (via cube)
- Process management and monitoring (via v7)
- User interface components ([web-browser](configuration/zenki/web-browser/start), [mpv](configuration/zenki/mpv/start) player control)
- Basic resource management

## How to Contribute

Contributions to Protocol-7 are always welcome =) :

0. Familiarize yourself with the codebase structure
1. Contact Taeki to discuss potential contributions

## Additional Documentation

- [AMOS Resource Tokens](read-me/documentation/dev/NRT.NRD.asc) - Development notes on the blockchain currency
- [Philosophical Foundation](read-me/documentation/meditation.by_T_chai.asc) - Underlying principles

## Vision

The ultimate project goal is to pool existing idle resources present in today's networks and offer them back to its users with low latency and a lot of burst capacity, much like a supercomputer would, but based on advanced peer to peer technology. It would be a global marketplace that values and utilizes resources in realtime based on what is required the most at any given time and in which workloads exist that are interesting to users and operate autonomously on their behalf.

After the network is saturated with what it needs to maintain a stable topology, a kind of overflow becomes available that is then distributed equally to the individual users. Not only can this even generate a form of basic income each user would receive but also support content creators based on the interests of their audience as a whole.

One can imagine this like the flow of water irrigating farm land where each field of interest receives enough water to grow all kinds of plants and compensate for time and effort invested into creativity.

Taking part will be as simple as connecting a hard disk to the network, acquiring resources using crypto currencies or creating and sharing something that is of interest to others.

The overflow principle also makes it possible to maintain public resource pools available to those who are just joining or had nothing to offer yet, so that there are no barriers to the global community for who can profit from the practical wealth that exists in the so far not utilized idle capacity.

It will easily prove our possibilities to be limitless. It is all a matter of algorithms and protocols. Hardware and connectivity we already have.

