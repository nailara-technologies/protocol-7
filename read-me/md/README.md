
::: SOURCE-CODE VERSION :: 32I4J2U3DA-10431.0 :::

# [ [nailara 'protocol seven' network](http://protocol-7.network/) ]

### Source Code and Versioning

- Detailed version information: [Source Code Versions](/read-me/project-identity/source-code-versions.md)
- Current source code version tracking available in dedicated documentation

### Licensing

- [Licensing Details](/read-me/project-identity/licensing-details.md)
- This is the public domain licensed 'base' branch

---
## Release Information

- Detailed release history: [Release Versions](/read-me/project-identity/release-versions.md)
- Current [release](https://github.com/nailara-technologies/protocol-7/tags) version \\\\// [AMOS7-v6.48.9](https://github.com/nailara-technologies/protocol-7/releases/tag/AMOS7-v6.48.9)
---

## 🌐 Topology Research Visualization

**Interactive Hyperspace Field Visualization** -

[ experience Protocol-7's cubic space topology 'in-flight' ]

[![Hyperspace Field Demo](data/asc/what-AI-thinks/html-form/visualizations/cubic-space/remote/screen.0.png)](https://visual.v7.ax/)

### **[https://visual.v7.ax/](https://visual.v7.ax/)**

[click the screenshot above to launch the interactive visualization]

Features real-time 3D navigation, dynamic neighbor layers, psychedelic hue rotation, and adaptive rendering. Showcases the harmonic computing principles of cubic space topology with critically damped inertia physics [prior version] and multi-axis grid-aligned navigation. Bilingual interface [English/German].

---

## Introduction

Protocol-7 is a multi-agent system framework written in Perl. It implements a harmonically designed network of cooperating agents (called "zenki") that can communicate with each other through a standardized message protocol. The system is designed to provide a flexible and extensible platform for building distributed applications, with a focus on harmonic computing principles.

## Directory Structure

- **[bin/](bin/)**: Executables and utilities including the [Protocol-7](bin/Protocol-7) interpreter
- **[cfg/](cfg/)**: Zenki configuration files and system settings
- **[src/](src/)**: Core functionality modules loaded by zenki at runtime
- **[data/](data/)**: Resources, assets, libraries and supporting files
- **[read-me/](read-me/)**: Additional documentation and license information

## Dependencies

Protocol-7 uses a sophisticated dependency tracking system to manage Perl module requirements:

- **Core Dependencies**: Perl 5.32.0 or newer [ the `use v5.32.0` line of [bin/Protocol-7](bin/Protocol-7) ]
- **Perl Modules**: Required modules are declared per zenka in `cfg/zenki/<zenka>/deps/` [ `p-mod/` Perl modules, `os/deb/` Debian packages ] and mapped to packages in [src/base.known_dependencies](src/base.known_dependencies)
- **Package Management**: Dependencies can be resolved from Debian packages or CPAN as specified in the dependency mappings
- **Dependency Manager**: [bin/p7-deps](bin/p7-deps) provides comprehensive dependency analysis and installation

The system automatically tracks which modules each zenka uses and will register new dependencies when they are encountered.

### Dependency Management with bin/p7-deps

`bin/p7-deps` installs and checks dependencies by profile
[ `.deps/profiles.yaml` ] and from what the zenki declare
[ `cfg/zenki/<zenka>/deps/` ] :

- `bin/p7-deps list` -- the profiles and what they hold
- `bin/p7-deps install [<profile>..]` -- install profiles [ default : minimal ]
- `bin/p7-deps check <profile>..` \ `status` -- read-only checks [ exit 1 : missing ]
- `bin/p7-deps zenka-modules [zenka]` \ `zenka-packages [zenka]` \ `validate` --
  the per-zenka declarations
- `bin/p7-deps detect-hw [ -write <name> ]` -- firmware \ hardware packages
  from the kernel log, saved as a `hw-<name>` profile
- `bin/p7-deps host-power [mode]` -- keep a host awake [ sleep targets
  masked ] or managed-suspending
- `bin/p7-deps help` -- the full option list

each module resolves Debian package first, then a build from the sources
the tree carries [ `data/lib-path/pm-src/`, e.g. `Digest::BMW` ], then
CPAN [ `src/base.known_dependencies` holds the mapping ].

### Automatic Installation at Zenka Start

A host can let protocol-7 install missing dependencies itself, per host and
off by default. One command enables it [ root ]:

```
bin/p7-deps enable-auto-install
```

or at install time:

```
bin/p7-install -auto-install-deps
```

Both merge the opt-in line into the host overlay
`/etc/protocol-7/host-config/v7-zenki.cfg` [ other host settings are
never touched ; `disable-auto-install` turns it off again ]:

```
v7-zenki.cfg.auto_install_deps = yes
```

- **every start form** is covered : v7-zenki's managed starts [ autostart,
  on-demand, restart ] and a standalone `bin/Protocol-7 <zenka>` as root.
  the install window is bounded to start-up [ init ] -- no running event
  loop ever installs on its own
- **at a managed zenka start** v7-zenki checks the zenka's declared
  dependencies first ; missing ones are installed and the zenka starts once
  they are present
- **modules needed while code loads** [ `Digest::BMW`, the C25519 crypto,
  `Inline::C`, the xz reader for the inline subroutines ] are installed at
  the point they are missing ; until then the host runs **degraded but
  operational** -- pure-perl fallbacks, the `xzcat` pipe, one notice line
  instead of an error
- **installs run as root** in one serialized queue [ the debian zenka's
  root apt child, forked before privileges are dropped ] ; package names
  are re-validated there, never passed through a shell. their output goes
  through the zenka log, styled like everything else
- **a failed install** starts the zenka anyway [ degraded, logged with the
  real reason ] and is retried after `v7-zenki.cfg.sys_deps.retry_after`
  [ 3600 s ] ; an install that never answers counts as failed after
  `v7-zenki.cfg.sys_deps.install_timeout` [ 1800 s ]
- exempt from the check : `cube p7-log debian os-pkg`
  [ `v7-zenki.cfg.sys_deps.exempt` ]

## Installation

### One command : bin/p7-install

On a Debian host, `bin/p7-install` takes a bare system to a running
service [ as root ] :

```bash
bin/p7-install -enable -start                      # minimal profile
bin/p7-install -profile extended -enable -start
bin/p7-install -profiles                           # the profiles to choose from
bin/p7-install -dry-run                            # what it would do
```

1. **base packages** -- perl, build tools, git, ca-certificates, libcrypt-dev
2. **checkout** -- clone \ fast-forward `/usr/local/protocol-7`
3. **dependencies** -- `bin/p7-deps install <profile>` [ the profile is
   recorded ; a later run without `-profile` uses it ]
4. **auto-install opt-in** -- reported, set with `-auto-install-deps`
5. **service unit** -- unit, install link, `Protocol-7` \ `nshell` symlinks
6. **boot start \ service** -- only with `-enable` \ `-start`

every step looks first and acts only on what is missing : a second run
changes nothing. the service is never restarted. `-options` lists every
option.

### Profiles

- `minimal` -- everything a bare `bin/Protocol-7 cube` needs : the core
  modules, the boot crypto [ `Digest::BMW`, `Crypt::Curve25519`,
  `Crypt::Ed25519`, CryptX ], `Inline::C` + gcc, the xz reader
- `basic-remote-server` -- a headless server [ minimal, runtime, network,
  cryptography, tools, zenka-common, graphics-matrix, vault ]
- `extended` -- the complete system : basic-remote-server plus
  `X11-Desktop`, `ai-models` and `coding`

`bin/p7-deps list` shows them all, with their package counts.

### Starting the System

To start Protocol-7 with the v7-zenki management zenka, run: `bin/Protocol-7 v7-zenki`

Alternatively, to use systemd, set the service up once as root, then start it:

```bash
bin/p7-deps install-service   # unit, /usr/local/protocol-7 link, launcher symlinks
bin/p7-deps enable-service    # systemctl enable
systemctl start Protocol-7
```

- `bin/p7-deps check-service`: read-only check of unit, links and unit state
  [ exit 1 when a part differs ]
- `bin/p7-deps disable-service`: systemctl disable
- none of the service commands starts, stops or restarts the service ; a
  changed unit takes effect at the next restart. v7-zenki logs a unit that
  differs from the repository's, it never replaces it

### Interacting with the System

Three primary methods for interacting with the Protocol-7 network:

1. **nshell Zenka Terminal Interface** (Recommended) ✅ Fully Refactored
   ```bash
   p7-nshell
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
   - **Ctrl+O cycle**: Execute and advance through history sequence (cycling two entries)
   - Strips protocol reply strings for cleaner output (similar to p7c and p-7-r)
   - ✅ All navigation features fully tested and production-ready
   - **Live coding-zenka session integration**: split-screen mode, `Tab` toggles between
     the coding-session view and normal Protocol-7 mode; auto-subscribes to a task and
     streams its output live
   - **Round-based rewind/redo**: `Esc` (after first aborting) steps back one round,
     `F1`/`Shift+Esc` redo forward, `round-regen` forks a fresh-inference retry from any
     point, `restream` resyncs the view manually

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
   - Automatically compiled and installed during v7-zenki startup
   - Connects directly to the Protocol-7 network
   - Uses current Unix user for authentication
   - Installed at: `/usr/local/bin/p7c`

   **p-7-r** (protocol-7 remote):
   ```bash
   p-7-r [-v] [-strict] <hostname[:port]> <command> [args]
   ```
   - Remote command execution over network [ default port 42 ]
   - Automatically compiled and installed during v7-zenki startup
   - Authenticates with the caller's key [ auth-keypair, `~/.n/user-keys/` ] ;
     the server has to authorize it first [ see *Authorizing a Remote User* ]
   - The server proves its identity : its host-root is pinned on first
     contact in `~/.n/remote-keys/servers/<host>_<port>.public`, a different
     host-root later is refused. `-strict` refuses an unpinned server
   - Installed at: `/usr/local/bin/p-7-r`

   **Short forms** [ symlinks kept by v7-zenki ]:
   ```bash
   :: <command> [args]            # = p7c, local
   ::: <alias> <command> [args]   # = p-7-r through 'ssh -W'
   ```
   - `<alias>` is a `Host` of the caller's `~/.ssh/config` [ no dots ] with a
     `HostName` ; the link is `ssh -W 127.0.0.1:42 <alias>`, so a server
     only needs to expose ssh. a dotted word is never a host here : a
     slipped `::: zenka.cmd` fails before any lookup
     ```
     Host node-local
         HostName host.example.local
         User root
     ```
     then `::: node-local list sessions`, `::: node-local v7-zenki.list zenki`

   **Authorizing a Remote User** [ on the server, once per user ]:
   ```bash
   USER=protocol-7 p7-keys add-incoming <user> <public key | file | -> cube
   ```
   - writes the user's public key [ e.g. a copied `<user>.base.public` ] to
     the zenka user's `incoming/` and authorizes it for `cube` in one call
   - cube watches its authorized keys [ inotify ] and re-reads them within a
     second -- no reload, no restart ; revoking with `p7-keys
     drop-authorized cube:<user>` applies the same way
   - run as root, `p7-keys` works on root's own registry unless `USER`
     names the zenka user [ it prints a note then ] ; every directory it
     creates or finds root-owned is handed to the zenka user, so a repeated
     call also repairs a root-made registry
   - related : `p7-keys incoming`, `list-authorized`, `authorize
     cube:<user>`, `re-pin cube:<user> <new key>` [ a rotated user key ]

   ### Common Commands

   - `p7c list sessions`: Display active network sessions
     ```
      : usid :.  : protocol :.  : type :.  : mode :.  : uname :.  : since :.
     ---------------------------------------------------------------------------
       3495297    protocol-7      unix      server       ---        16h 58'38"
       7310444    protocol-7     ip.tcp     server       ---        16h 58'38"
       5771202    protocol-7      unix      client    v7-zenki      16h 58'38"
       7091700    protocol-7      unix      client     system       16h 58'36"
       9079727    protocol-7      unix      client     p7-log       16h 58'35"
       ...
     ```

   - `p7c commands`: List available commands for the current zenka

     - Returns a flat list of every command the zenka accepts, each with a
       one-line description and its argument form — session handling, network
       time, log buffers, routing overrides, cryptographic utilities and so on

   ### Command Routing Mechanism

   - Local Context Commands:
     * `p7c commands`: Commands for the currently connected zenka (local cube)
     * `p7c <zenka>.commands`: Commands for specific zenki
     * Recursive routing possible: `p7c weather.child.commands`

   ### Zenka-Specific Command Discovery

   - `p7c v7-zenki.list`: Lists specific to the v7-zenki management zenka
     ```
      : list name :.    : description :.
     ------------------------------------------------------------------------------
       dependency         current zenka dependency status
        heartbeat         heartbeat latency per instance [ cube : v7 round trip ]
        available         available zenki \ descriptions
         subnames         'subnames' of registered zenki [ when available ]
         sessions         registered \ connected sessions
         children         PIDs of zenki and their children
          buffers         [log] ring buffers in use
           manual         zenki marked as 'manually stopped'
            zenki         currently running \ managed zenka instances
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

3. **Zenka Alias Symlinks**

   On startup, v7-zenki installs a `p7-<zenka>` symlink to
   [bin/Protocol-7](bin/Protocol-7) for every zenka that carries console
   commands — `p7-keys`, `p7-nshell`, `p7-work`, `p7-sourcecode` and so on.
   Invoking the symlink starts that zenka directly, so `p7-nshell` is
   equivalent to `bin/Protocol-7 nshell`.

   - Symlink directory: `v7-zenki.cfg.zenka_symlink_dir` [ `/usr/local/bin` ]
   - Installation toggle: `v7-zenki.cfg.install_zenka_symlinks`
   - The earlier `v7.<zenka>` symlink form is deprecated: `bin/Protocol-7`
     still recognizes it, but new installations get the `p7-` prefix only

## Keys and Secrets

### p7-keys : Curve25519 Identity and Trust

`p7-keys` [ the keys zenka, `p7-keys commands` lists everything, `p7-keys
describe <command>` explains one ] manages the C25519 keys of the calling
user [ `~/.n/user-keys/` ] and what a host trusts :

- **own keys** : `create [-U] [name]` [ `-U` : the `base` user key ], `list`,
  `enc-key` \ `dec-key` \ `change-passwd`, `rename`, `duplicate`,
  `split-keypair`, `get-encoded-key`, seed-phrase \ passphrase keys
  [ `gen-pwd-keyfile`, `get-sp-pub-key` ]
- **backups** : a key file is backed up before p7-keys changes it [ `list-backups`,
  `restore-backup`, `prune-backups` ] ; `keys-backup-archive` \
  `decrypt-archive` move a whole key set encrypted ; removals are
  reversible [ `removed`, `undo-remove` ]
- **remote clients** [ who may log in to a zenka ] : `add-incoming`,
  `authorize`, `drop-authorized`, `re-pin`, `incoming`, `list-authorized`
  [ see *Authorizing a Remote User* ]
- **host trust chain** : an owner root certifies host-roots [
  `certify-host`, `accept-owner` ] ; `owner-pin` trusts every host an
  owner certifies, `distrust` refuses a key anywhere in a chain

### p7-vault : Personal Vault

[bin/p7-vault](bin/p7-vault) keeps logins, notes, contacts and files
encrypted in `~/.n/vault` [ `P7_VAULT_DIR`, `-d` ]. It is standalone on
purpose : perl, CryptX and Term::ReadKey, nothing from a running
Protocol-7 -- it works on any Linux machine, a Protocol-7 host or not,
and on one whose backend is not set up or not running. a copy of the
script, its `AMOS7/` modules and
[data/md/design/VAULT-FORMAT.md](data/md/design/VAULT-FORMAT.md) next to a
backup opens every vault.

```bash
p7-vault init                 # create, with passphrase + recovery code
p7-vault                      # interactive : unlock once, then commands
p7-vault copy <filter>        # password to the clipboard, cleared after 45 s
p7-vault commands [keyword]   # every command
```

- **encryption** : a cascade of Twofish and ChaCha20-Poly1305 on every
  layer, keys from argon2id + hkdf-blake2b -- a break of one cipher alone
  reveals nothing [ details in VAULT-FORMAT.md ]
- **entries** : `add` \ `edit` \ `show` [ secrets masked, `-r` reveals ] \
  `get` [ raw, for pipes ] \ `list` \ `notes` ; every change is a new
  version [ `history`, `restore` ] -- `rm` too
- **files** : `import` [ one blob per content ; `-a` a whole directory as
  one archive ; `-u` updates : changes become new versions ] and `export`
- **sync** : `sync <host>[:<dir>] | <path>` merges entries and blobs with
  other hosts or an external drive -- never overwrites, never deletes
- **untrusted copies** : `archive <file>` writes one file for a public
  place [ entry count and edit times hidden ], opened with the recovery
  code [ or passphrase + any key file, `-f` ]
- secrets are only typed at a prompt, never taken from argv ; the shell
  locks itself after 78 minutes without input

## Key Concepts

- **Zenki**: Autonomous agents that perform specific functions
- **Cube**: A message routing zenka that enables inter-zenka communication
- **Protocol-7**: The interpreter that loads and runs zenki
- **Harmonic Computing**: The design principle ensuring system coherence through mathematical harmony

## System Architecture

The Protocol-7 system consists of interconnected zenki (agents) that communicate through a standardized message protocol:

1. The [v7-zenki](cfg/zenki/v7-zenki/zenka.v7) zenka manages the lifecycle of other zenki
2. The [cube](cfg/zenki/cube/zenka.v7) zenka routes messages between other zenki
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

Protocol-7 is a production-active multi-agent system with working HTTPS servers, autonomous LLM-driven self-improvement, live web services, and a growing ecosystem of specialized zenki. Core infrastructure is stable; active development is converging on distributed coordination, self-hosting AI inference, and the full cubic-space topology vision.

### Established Infrastructure

- **Interprocess Communication**: Message routing via cube zenka with Unix domain and TCP socket support
- **Process Management**: Lifecycle management and monitoring via the v7-zenki zenka with automatic zenka startup, monitoring, and restart capabilities
- **Interactive Interfaces**:
  - nshell zenka with buffered non-blocking I/O and full UTF-8 support
  - p7c (protocol-7 command) and p-7-r (protocol-7 remote) binaries for direct command access
- **User Interface Components**: Web-browser automation, mpv media player control, desktop integration
- **Cryptographic Infrastructure**: Curve25519 key management, multiple checksum algorithms (AMOS, BMW, ELF, JHA)

### Recent Developments

- **Clean Bare-Host Install** [ 2026-10-28 ] : for the first time a fresh Debian host goes from nothing to a running, boot-enabled service with one command [ `bin/p7-install` ], and its zenki install what they miss on their own while staying operational in the meantime -- wanted for 25 years, now clean through the whole chain [ base packages, profile, auto-install, service ].
- **Autonomous Coding Zenka**: A fully operational LLM orchestration agent that can read, edit, and improve its own Protocol-7 source code. Runs local inference servers asynchronously (non-blocking spawn with < 100ms init), maintains a tool-calling loop (50+ task templates, XML tool-call parsing, context compaction), and coordinates with external frontier models (Claude, Kimi) for complex multi-session tasks.
- **Self-Modifying Infrastructure**: The coding zenka completed numerous autonomous extraction and refactoring tasks — inline sub extraction across 30+ modules, style enforcement, cross-namespace wiring — all applied via direct file write tools without human intervention.
- **Multi-Model Consensus**: Local voting infrastructure exists (`llm.service.consensus_vote`, cubic-topology harmonic certainty aggregation, mock-response fallback if llama-cli isn't installed), but its model list is a stale hardcoded placeholder (Qwen2.5-7B, Mathstral-7B, Aya-23-8B) that predates the current model registry and isn't wired to it — see [`AUTONOMOUS-MODEL-MANAGEMENT.md`](./data/md/design/AUTONOMOUS-MODEL-MANAGEMENT.md) for the autonomous discovery/benchmarking/consensus system meant to replace it. Separately, a dedicated kimi zenka dispatches to external frontier models (Claude, Kimi) for tasks exceeding local model capability — that's task delegation to a single stronger model, not (yet) folded into the voting mechanism itself.
- **Async HTTP Server**: Full non-blocking HTTP/HTTPS implementation with Range request support, TLS via ACME/Let's Encrypt, SNI-based vhost routing, and event-driven file transfer. Live at `space.v7.ax` and `pri.v7.ax`.
- **Stream Transport Layer (STRM)**: Binary streaming protocol for large files, audio relay, and unbounded streams. Includes cancel propagation, gap-fill pacing, and a working internet radio relay zenka with MPV playback and offline resilience.
- **Web Template Pipeline**: Server-side template rendering with plugin commands, content-type negotiation, and inline CSS/JS for offline-viewable pages.
- **Graphics Matrix**: Spatial node visualization with cursor tracking, glow gradients, channel routing, and a live hyperspace field demo at [visual.v7.ax](https://visual.v7.ax/).
- **Job Pipeline**: Automated job-site scanning, scoring, and reporting with German-language LLM summaries, retry logic, and a live web frontend.

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
  - **[HTML Visualizations and Documentation](data/asc/what-AI-thinks/html-form/INDEX.md)**: 220+ HTML files with interactive visualizations, frameworks, and tools covering cubic space topologies, harmonic systems, Protocol-7 demonstrations, and mathematical justice frameworks
  - **[Perl Knowledge Modules](data/asc/what-AI-thinks/perl-form/INDEX.md)**: 110+ Perl modules containing symbolic implementations of consciousness emergence, harmonic mathematics, truth systems, and Claude AI insights
  - **[Markdown Documentation](data/asc/what-AI-thinks/markdown-form/)**: Additional markdown-formatted research, concepts, and Protocol-7 documentation

## Vision

For a comprehensive exploration of the project's philosophical context, please refer to [Philosophical Foundation](/read-me/project-identity/philosophical-foundation.md).

### The Orbital Field Model

Protocol-7 models its network topology as an **orbital field**: zenki (agents) orbit a shared work-and-memory ring, rotating freely while routes between them remain stable along the ring. This separation — freely moving agents, static routing geometry — means zenki can migrate, restart, or move between physical nodes without disrupting in-flight messages. Data flows electrically along the ring; agents intercept what belongs to them by orbital proximity, not by fixed address.

The cubic space grid sits outside the ring as a coordinate system for addressing and routing decisions. Every resource, agent, and message has a position in this 3D space derived from its checksum — deterministic, collision-resistant, and human-readable through Base32 encoding. Shortest-path routing through the cube is a geometric property of the address, not a lookup.

### Harmonic Computing Principles

Protocol-7's design is grounded in mathematical harmony: routing decisions, resource allocation, and even cryptographic checksums share the same underlying generator (division by 13, the 076923 cycle). This creates coherence at all levels — protocol, topology, and code — so that system behavior at scale is predictable from the structure of a single message.

### The Overflow Principle

The network is self-saturating: once topology stability is maintained, surplus compute, bandwidth, and storage become available as **overflow**. This overflow is distributed proportionally to participants, creating a positive feedback loop where contribution earns capacity. Statistical averages (total network disk / number of users) set resource values without per-account lookups, preserving anonymity throughout.

### Self-Improving AI Infrastructure

A long-horizon goal of the project is a network that improves itself: zenki coordinating LLM inference locally and via frontier APIs, autonomously proposing and applying changes to the codebase, reaching consensus across models before committing. The coding zenka represents the first working layer of this — a single agent that already edits its own source. The next layer is multi-node consensus across a distributed P7 network running diverse models.

The full vision document explores Protocol-7's unique approach to distributed computing, network participation, and the metaphorical framework of resource sharing.

```

#,,..,..,,.,,,.,.,..,,,.,,,,,,..,,.,.,,.,,...,..,,...,..,,.,,,...,.,,,,.,,.,.,
#6E5YUKUAGPLJS4OBQWF6VNLRGWRMP4RQSQ663R4GRDPMXMRTDRFK2AFQ2K6JV6ULAQCNBKTSWSAKI
#\\\|M62FH4NXKSXW3HQJP7VVSY5KITV4NYBYELXHVWLHVQZ4PLNURJU \ / AMOS7 \ YOURUM ::
#\[7]QESWGZDVGJT3GCCRZAQ4WUAGUK4Y6FBARTEMYHDY23IMYOAX2MBY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
