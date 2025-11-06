# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Protocol-7 is a Perl-based modular system with a unique architecture focused on asynchronous operations and modular components called "zenka". The current branch `dev/httpd-async-implementation` implements asynchronous HTTP server functionality with non-blocking I/O operations.

## Development Commands

### Dependencies Installation
```bash
# Install system dependencies (Debian/Ubuntu)
./bin/dependencies/install_dependencies.debian.sh

# Install minimal dependencies
./bin/dependencies/install_minimal_dependencies.debian.sh

# Install CPAN modules
./bin/dependencies/cpan_install.debian.sh
```

### Running the System
```bash
# Main Protocol-7 executable
./bin/Protocol-7 [zenka-name]

# HTTP server zenka
./bin/Protocol-7 httpd

# Alternative GUI version
./bin/protocol-7-gtk3

# System-wide p7 binary (auto-installed)
p7 <command> [args]                # Low-latency network command access

# Interactive Protocol-7 shell
./bin/nshell                       # Direct user interaction with zenka network
```

### Development Tools
```bash
# Protocol-7 development shell
./bin/nshell

# CPAN package manager
./bin/ncpan

# Version control commit tool
./bin/admin/vc_commit

# Development utilities (bin/dev/)
./bin/dev/update-version          # Version management
./bin/dev/update-amos-versions    # AMOS module versioning
./bin/dev/release-version         # Release management
./bin/dev/push-change            # Change deployment
./bin/dev/vci                    # Version control integration

# Research and analysis tools
./bin/dev/division-13-table      # Division by 13 mathematical research
./bin/dev/true-false-stats       # Truth assertion statistics
./bin/dev/elf-inline             # ELF checksum analysis
./bin/dev/bit-count              # Bit manipulation utilities
./bin/dev/comp-test              # Compression testing
```

## Architecture Overview

### Multi-Agent System (Zenki)
Protocol-7 is a **multi-agent system** where each agent is called a **zenka** (singular) or **zenki** (plural). Agents communicate with each other through message routing.

#### Key Zenki:
- **`cube`** - Message router between zenki (started first)
- **`v7`** - Zenka manager that starts and manages other zenki
- **`httpd`** - HTTP server agent

### Module System
- **Location**: All functional modules are in the `modules/` directory
- **Loading**: Modules are loaded and compiled by `bin/Protocol-7` into the `%code` hash structure
- **Naming**: Module files use dot notation (e.g., `base.init_code`, `httpd.file_transfer.init`)
- **Structure**: Modules do NOT use `sub { }` declarations - the filename itself becomes the callable subroutine
- **Invocation**: Two syntax options:
  - Standard Perl: `$code{'module.name'}->()`
  - Special syntax: `<[module.name]>->()` (parsed to Perl before compilation)

### Module File Format
```perl
## [:< ##

# name = module.name.here
# descr = Brief description of module purpose

# Implementation code starts here...
```

### Key Components

#### Base System (`modules/base.*`)
- **`base.init_code`**: Core system initialization
- **`base.event.*`**: Event loop and I/O handling
- **`base.file.*`**: File operations and utilities
- **`base.net.*`**: Network operations

#### HTTP Server (`modules/httpd.*`)
Recent async implementation includes:
- **`httpd.file_transfer.*`**: Non-blocking file transfer system
- **`httpd.benchmark.*`**: Performance metrics collection
- **`httpd.diagnostic.*`**: System diagnostic tools
- **`httpd.http_get/head/options`**: Async HTTP method handlers

#### Module Organization & Dependencies
- **Zenka-specific modules**: Each zenka has its own namespace (e.g., `cube.*`, `httpd.*`, `weather.*`)
- **Shared modules**: Generic functionality gets descriptive names for reuse across zenki
- **Module reuse**: Similar zenki can load each other's modules (e.g., `cube-13` loads `cube` modules)
- **Base modules**: Common functionality in `base.*` loaded by most zenki

#### Configuration System
- **Zenka configs**: `configuration/zenki/[module-name]/`
- **Global configs**: `configuration/` (shared-params, system settings)
- **Module loading**: Defined in zenka start files

### Zenka Configuration & Execution
Each zenka is a configured agent instance defined by:
- **Start files**: `configuration/zenki/[name]/start` - defines module loading, config, and execution flow
- **Startup configs**: `configuration/zenki/[name]/zenka-startup.v7` - runtime parameters
- **Access control**: `configuration/zenki/[name]/access.*` files for users and other zenki
- **Authentication**: `configuration/zenki/[name]/auth.*` files

#### Typical Zenka Execution Flow:
1. Load shared configuration files
2. Define `modules.load = module1 module2 ...`
3. Execute `[load_modules:<modules.load>]`
4. Execute `[init_modules]`
5. Drop privileges with `[root.drop_privs:<user>]`
6. Enter main loop with `[zenka.loop]`

#### Agent Communication & Lifecycle:
- The `cube` zenka acts as message router between all other zenki
- The `v7` zenka manages the lifecycle of connected zenki:
  - Monitors with heartbeat commands and restarts unresponsive zenki
  - Management commands: `v7.start`, `v7.stop`, `v7.restart`
- **Deployment Options**:
  - **Always-on**: Listed in `configuration/zenki/v7/start-set-up.base` (e.g., `cube`, `p7-log`, `httpd`, `system`)
  - **On-demand**: Started when first accessed, configured with `start.on-demand = 1`
  - **Unmanaged**: Zenki manually started, connects to cube but not monitored by v7
  - **Standalone**: Zenki runs independently without connecting (e.g., `keys`, `sourcecode` zenki)
- **On-demand Management**:
  - Automatic startup when commands are routed to them
  - Optional idle timeout with `[base.zenki.set_ondemand_timeout:seconds]`
  - Example: `calc` zenka (4200s timeout), `image2html` zenka (420s timeout)
  - Usually have `restart.disabled = 1` and `heartbeat.disabled = 1`
- **Transport**: Unix domain sockets or TCP sockets (functionally equivalent after authentication)
- **Access Control**: `configuration/zenki/cube/access.zenki` defines which zenki can access which commands/zenki

#### Message Routing Syntax:
- **Direct cube commands**: `list users`, `list sessions` (no dots)
- **Route to other zenki**: `zenka.command` (dot notation)
  - Example: `weather.desc` → routes to weather zenka's desc command
  - Example: `weather.location` → gets weather zenka's configured location
- **Session Management**: Cube maintains table of connected zenki accessible via `list` commands

### Data Structures & Isolation
- **Per-zenka isolation**: Each zenka has its own `%data`, `%code`, and `%keys` hash instances
- **Potential shared memory**: Future implementations may share sub-branches of `%data` hash
- **Inheritance**: Zenki forked from partially initialized parents can inherit data structures
- **Constants**: `TRUE => 5`, `FALSE => 0`, `UNKNOWN => 2`

#### Child Zenka (Forking)
- **Purpose**: Handle blocking operations without blocking main zenka
- **Implementation**: Parent zenka forks child processes for specific tasks
- **Network access**: Children connect to parent and remain network-accessible
- **Routing**: Nested access possible (e.g., `weather.child.command`)
- **Unlimited nesting**: No implemented limit on child depth for network accessibility
- **Example**: Weather zenka uses `[weather.base.fork_weather_child]` for non-blocking operations

### AMOS7 Module System
- **Location**: `data/lib-path/pm/AMOS7/` - Project-internal Perl modules
- **Purpose**: Provides unique functionality not found elsewhere, usable by both zenki and standalone scripts
- **Main module**: `AMOS7.pm` - Core functionality and exports
- **Key components**:
  - `AMOS7::Assert::Truth` - Harmonic truth calculation based on division by 13
  - `AMOS7::CHKSUM::*` - Specialized checksum implementations
  - `AMOS7::13::*` - Compression and cipher functionality
  - `AMOS7::Protocol::P7` - Protocol-7 specific implementations
- **Standalone usage**: Can be used by regular Perl scripts with local lib path setup
  - Example: `bin/is-true` uses `AMOS7::Assert::Truth` for harmonic truth calculation
  - Example: `bin/amos-chksum` implements Protocol-7 checksum algorithms standalone
- **Local modules**: `data/lib-path/pm/` also contains copies of essential external modules for early availability or modifications
- **Lib path setup**: Standalone scripts use `BEGIN` block to add `data/lib-path/pm` to `@INC`

### Cryptographic System
- **Keys**: `modules/crypt.C25519.*` - Curve25519 implementation
- **Checksums**: `modules/base.chk-sum.*` - Multiple checksum algorithms (AMOS, BMW, ELF, JHA)
- **User keys**: Stored in `modules/USR.[username].*` files
- **AMOS7 crypto**: Additional cryptographic functions in `AMOS7::CHKSUM::*` and `AMOS7::Twofish`

## Current Development Focus

The active `dev/httpd-async-implementation` branch is implementing:
- Non-blocking file operations for HTTP server
- Event-based I/O handling
- Performance benchmarking system
- HTTP Range request support
- Timeout handling mechanisms

All core async components are implemented per `IMPLEMENTATION-CHECKLIST.md`.

### System Integration - P7 Binary
- **Source**: `bin/c_src/p7.c` - C implementation for low-latency network access
- **Auto-installation**: Compiled and installed to system path when v7 zenka starts
- **Configuration**:
  - `v7.cfg.install_bin_p7 = yes` - Enable auto-installation
  - `v7.cfg.p7_bin_path = '/usr/local/bin/p7'` - Installation path
  - `v7.cfg.bin_p7_static = yes` - Static binary compilation
- **Purpose**: Provides system-wide access to Protocol-7 network commands without requiring network code in calling scripts
- **Usage**: `p7 <command> [args]` - Routes commands through Unix socket to cube zenka
- **Environment**: Uses `PROTOCOL_7_UNIX_PATH` and `PROTOCOL_7_BIN_P7_USER` environment variables

### Interactive Shell - nshell
- **Source**: `bin/nshell` - Perl-based interactive shell for Protocol-7 network
- **Purpose**: Direct user interaction with zenka network through shell loop
- **Features**:
  - Interactive command prompt for zenka communication
  - Authentication handling and session management
  - Direct access to all zenka commands (`weather.desc`, `list users`, etc.)
- **Usage**: Run `./bin/nshell` for interactive Protocol-7 session
- **Complement to p7**: While `p7` is for scripting, `nshell` is for interactive exploration and administration

## Important Notes

- This system uses a custom module loading mechanism - standard Perl module practices don't apply
- All modules are UTF-8 by default
- The system includes extensive cryptographic verification (signatures at end of files)
- Each module file contains AMOS7 data signatures for integrity verification
- Dependencies are managed through custom scripts rather than standard package managers
- The p7 binary provides low-latency system-wide access to the zenka network
