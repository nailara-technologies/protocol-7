# Vision: Protocol-7 as Native Development Environment

**Status**: Transition in progress — foundations complete, shell replacement actionable
**Immediate**: SSH zenka as bridge to pri.v7.ax offload
**Near-term**: Native P7 tool-use protocol replaces shell dependency
**Long-term**: Shell concept dissolves into zenki network entirely

---

## The Current Situation

Claude Code and similar tools (Kimi shell, GitHub Copilot) share a structural problem:
they are **processes running on the developer's machine**, holding context in local RAM,
consuming CPU on every token, and depending on stable outbound connections to remote
APIs. The developer's hardware becomes the bottleneck for the intelligence working on
their behalf.

On a Windows host with residential proxy this means: memory pressure from idle LLM
backends, CPU spikes before timeouts, connection resets interrupting sessions mid-thought.
The tool that is supposed to reduce friction introduces its own category of friction.

The gap between what these tools cost to run and what Protocol-7 already has built
is thinner than it appears.

---

## What Protocol-7 Already Provides

### The Interaction Layer
- **nshell**: interactive terminal with full history, search, Ctrl+O cycle, session state
- **ncode**: code viewing and editing with syntax awareness, LLM workflow integration
- **p7 binary**: low-latency system-wide command access without a running shell process

### The Intelligence Layer
- **models zenka**: chat, memory system (`[:memory:CHECKSUM]` expansion), local + remote models
- **coding zenka**: async inference, task queue, model switching, dependency-based spawning
- **`models.chat`**: works identically with local llama-server or remote API models

### The Data Layer
- **data zenka**: 97 modules, FUSE mount, SHM zero-copy, holographic topology
- **P7REF**: network-transparent references, full Perl type semantics across the wire
- **SHM channels**: ring buffer IPC at memory speed between zenki

### The Infrastructure Layer
- **SSH zenka**: remote shell access, auto-user-creation, race condition fixed (Feb 2026)
- **v7 zenka**: lifecycle management, on-demand startup, heartbeat monitoring
- **cube**: message routing, access control, session management

---

## The Missing Piece: Tool-Use Protocol

Claude Code works because the model can emit a structured tool request, have it
executed, and receive the result back inline within the same context. The coding
zenka's `ask-reply` deferred pattern is already structurally close:

```
model emits:   <tool_call> read_file path/to/file.pm </tool_call>
coding zenka:  parse → dispatch to files zenka → receive result
inject:        result flows back into model context as tool_response
```

What is needed:
1. A **tool-call parsing convention** in the coding zenka's task processor
2. **Tool endpoint zenki** — file read/write/search/execute as network commands
3. **Result injection** back into the active inference context

The data zenka's FUSE mount already makes the codebase a mountable hash sub-tree.
Reading a file is already `data.get path.to.file` returning a SCALAR ref. The
tool-use protocol is a thin dispatch layer over infrastructure that exists.

---

## The Transition Path

### Stage 1: SSH Zenka as Bridge (Immediate)

The SSH zenka (recovered and improved by Kimi, Feb 2026) provides remote shell
access to `pri.v7.ax` as a native zenka — not an external dependency but a
first-class network citizen. This enables:

- Heavy work (API calls, inference, context buffers) on pri.v7.ax (11GB RAM,
  datacenter uplink)
- Local session becomes a thin nshell connection — minimal memory, minimal CPU
- Connection drops on the local side no longer lose session state — it lives on
  the server
- The developer's machine becomes a display terminal, not a compute node

SSH zenka is the bridge, not the destination. It provides the offload now while
native P7 links are built. When those links mature, the SSH zenka becomes
optional rather than essential — replaceable from within the network.

### Stage 2: Tool-Use Protocol (Near-term)

Implement the tool-call dispatch layer in the coding zenka:

```perl
## coding.handler.process-queued-task detects tool calls in model output
if ( $output =~ /<tool_call>\s*(\w+)\s+(.*?)\s*<\/tool_call>/s ) {
    my ( $tool, $args ) = ( $1, $2 );
    ## dispatch to registered tool zenka
    ## inject result back into context
}
```

Tool zenki to implement (in order of impact):
1. `files.read` / `files.write` / `files.edit` — codebase access
2. `files.search` — grep/glob over mounted source tree
3. `shell.exec` — sandboxed command execution
4. `git.status` / `git.diff` / `git.log` — version control queries

Each is a thin zenka over existing base.file.* and system zenka infrastructure.

### Stage 3: Context as Data Zenka Sub-tree (Near-term)

Move conversation context from in-memory array to a named data zenka sub-tree:

```
data.ai.session.<identity>.context.*
  ├── messages[]          ← conversation history
  ├── tool_results[]      ← injected tool outputs
  ├── compaction_level    ← current wave depth
  └── route_signature     ← accumulated coordinate path
```

This gives context:
- **Persistence** across connection drops (lives in data zenka, not local process)
- **SHM access** for zero-copy reading by the inference server
- **Compaction** via the wave system (see VISION-NOMADIC-ZENKI-HABITAT.md)
- **Network access** — any authorized zenka can contribute to or read the context

### Stage 4: Native P7 Links Replace SSH (Long-term)

As the P7REF group system matures, the SSH zenka's role narrows:
- Remote file access → data zenka FUSE mount over P7REF
- Remote command execution → zenka dispatch via cube routing
- Remote shell → nshell connecting to remote cube directly

SSH remains available for interoperability with non-P7 systems. Within the
Protocol-7 network, the native links are faster, cryptographically stronger
(AMOS integrity rather than SSH key management), and composable with the
rest of the zenki infrastructure.

---

## The Bandwidth Argument

P7REF + compression for a synchronized codebase means:
- The remote already has the current source tree (AMOS-verified, signed)
- Tool requests carry path references, not file contents
- Results carry delta changes, not full rewrites
- Context carries route signatures and coordinates, not raw history

The effective bandwidth for active development work drops by an order of
magnitude compared to shipping full file contents and conversation history
on every round-trip. The synchronous nature of the codebase is a feature:
it means "send me file X" costs a reference, not a transfer.

---

## Homogeneous Addressability

Once the development environment is a P7REF intent group on pri.v7.ax:

```
any device + nshell → same session state
                     → same tool endpoints
                     → same model access
                     → same codebase mount
```

The future Linux host, a phone via nshell, a colleague's machine — all address
the same intent group by the same name. The topology of where compute lives
becomes a configuration detail, not an architectural constraint.

The developer's relationship with their own infrastructure inverts: `pri.v7.ax`
is not a server you deploy *to*, it is the address of your working environment
that you connect *from* wherever you happen to be.

---

## Immediate Next Steps

1. **Verify SSH zenka on pri.v7.ax** — test nshell → SSH zenka → remote shell path
2. **Move coding session context to data zenka sub-tree** — persistence across drops
3. **Tool-call parser** in coding.handler.process-queued-task — file read/write first
4. **Register file tool zenki** — thin wrappers over base.file.* infrastructure
5. **Compaction wave 1** — light compaction of models.chat resolved exchanges

### Related Documents
- `data/md/vision/habitat/VISION-NOMADIC-ZENKI-HABITAT.md` — session identity and litters
- `data/md/data-zenka/DATA_ZENKA_SHM_MOUNTING.md` — SHM mounting implementation
- `data/md/documentation/ASYNC-SPAWNING-INFRASTRUCTURE-STATUS.md` — coding zenka status
- `data/md/CONCEPT-CUBIC-HYPERSPACE-DESKTOP.md` — long-term desktop vision

#,,..,,..,.,.,.,,,...,,..,...,..,,.,.,.,,,.,.,..,,...,...,.,.,...,,,.,...,.,.,
#DLFSO5DO7O3WAIDT3YQ535VROFQXHHLKA3BZGZJ4SCFENX7WWOSOZJZCX2HDXKNV6O3YBDBYIMHKM
#\\\|ZK2MHTGJ4RYAMFN5GXW57HIKC2ZH5ZMRRUDQL2ERXKD3VMN5GFQ \ / AMOS7 \ YOURUM ::
#\[7]IFNQBVZPAIYZMGT3BJFEOMWDOV627KQLR3D7HUVVOBB23TRBVADI 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
