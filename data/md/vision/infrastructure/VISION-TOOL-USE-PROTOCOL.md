# Vision: Tool-Use Protocol — Model-Zenka Dispatch Layer

**Status**: Design complete — immediate implementation target
**Target**: coding zenka task processor + file/shell tool zenki
**Builds on**: coding.handler.process-queued-task, base.file.*, data zenka FUSE mount

---

## The Missing Link

The coding zenka can receive a prompt, run inference, and return a result.
The data zenka can mount the codebase as a filesystem. The models zenka
can maintain conversation context. The base.file.* modules can read, write,
and search files.

What is missing is the **dispatch layer** that lets the model's output
trigger zenka operations and inject their results back into context — the
tool-use loop that makes the model an active participant in the network
rather than a prompt-response endpoint.

---

## Protocol Design

### Tool Call Format

Model output is scanned for tool calls in a simple, unambiguous format:

```
<tool>read_file</tool>
<args>src/coding.init_code</args>
```

Or multi-argument:

```
<tool>search_code</tool>
<args>pattern=spawn_with_deps glob=src/coding.*</args>
```

The format is intentionally minimal — easy for any model to produce,
easy to parse with a single regex, no XML nesting required.

### Dispatch in coding.handler.process-queued-task

The task processor already handles model output. Adding tool dispatch:

```perl
## scan model output chunk for tool calls
while ( $output =~ /<tool>(\w+)<\/tool>\s*<args>(.*?)<\/args>/sg ) {
    my ( $tool, $args ) = ( $1, $2 );

    ## dispatch to registered tool zenka
    my $result = <[coding.tool.dispatch]>->( $tool, $args );

    ## inject result back into context before continuing inference
    <[coding.context.inject_tool_result]>->( $tool, $args, $result );
}
```

The injection happens **before** the next inference token is generated —
the model sees the tool result as if it were part of the conversation,
allowing it to reason about the result and make further tool calls.

---

## Tool Zenki — Implementation Order

### Tier 1: File Access (Immediate)

These are thin wrappers over existing `base.file.*` infrastructure:

**`tool.files.read`**
```
input:  path (relative to repo root or absolute)
output: file content as text, with line numbers
error:  file not found, permission denied
```
Implementation: `<[file.read_file]>->($path)` — already exists.

**`tool.files.write`**
```
input:  path, content
output: confirmation + line count
error:  path invalid, disk full
```
Implementation: `<[file.write_file]>->($path, \$content)` — already exists.

**`tool.files.edit`**
```
input:  path, old_string, new_string
output: confirmation + line changed
error:  old_string not found (uniqueness check), file not found
```
Implementation: read → substitute → write, with uniqueness validation.

**`tool.files.search`**
```
input:  pattern (regex), glob (file filter, optional)
output: matching lines with file:line_number format
error:  invalid regex
```
Implementation: wrapper over system grep/rg against the FUSE-mounted
source tree, or native Perl regex over file list.

**`tool.files.glob`**
```
input:  pattern (glob expression)
output: matching file paths, sorted by modification time
error:  invalid pattern
```
Implementation: Perl `glob()` against repo root.

### Tier 2: Shell Access (Near-term)

**`tool.shell.exec`**
```
input:  command string
output: stdout + stderr, exit code
constraints: sandboxed — no network, no writes outside repo
```

The sandbox is not optional — exec must be constrained to prevent
accidental or adversarial side effects. Implementation via restricted
execution environment with explicit allowlist.

**`tool.shell.git`**
```
input:  git subcommand + args (status, diff, log, show)
output: git output as text
constraints: read-only git operations only (no push, reset, force)
```

Separate from exec to enforce the read-only constraint clearly.

### Tier 3: Network/Zenka Access (Medium-term)

**`tool.zenka.command`**
```
input:  zenka.command args
output: command reply
constraints: access control via cube routing — same rules as any zenka
```

This tier gives the model access to the full Protocol-7 network — it can
query any zenka it has access to, read data zenka sub-trees, invoke
service commands. At this point the model is a full network participant,
not just a codebase accessor.

---

## Context Injection

Tool results are injected into the inference context as a structured block:

```
[tool_result: read_file src/coding.init_code]
─────────────────────────────────────────────────
     1  ## [:< ##
     2  # name  = coding.init_code
     3  # descr = initialize coding zenka state...
    ...
   140  <[base.logs]>->( 1, ': initialized .:' );
─────────────────────────────────────────────────
[end tool_result]
```

The format is consistent and parseable — both by the model for reasoning
and by the compaction system for wave-1 treatment (tool results that have
been acted upon and are no longer needed can be compacted to a single line).

### Multi-Turn Tool Use

The model can make sequential tool calls, each building on previous results:

```
turn 1: model reads src/coding.init_code
turn 2: model reads src/coding.handler.spawn_with_deps (found reference in turn 1)
turn 3: model edits src/coding.handler.spawn_with_deps
turn 4: model runs tool.shell.git to verify the diff
turn 5: model reports: "change implemented, diff looks correct"
```

This is identical to how Claude Code operates today. The Protocol-7
implementation is not reimplementing a concept — it is providing the
same capability natively, without the Node.js process, without the
API relay, with full integration into the zenki network.

---

## Tool Registration

Tools are registered in the coding zenka's startup:

```perl
## in coding.init_code
<coding.tools.registry> = {
    'read_file'  => 'tool.files.read',
    'write_file' => 'tool.files.write',
    'edit_file'  => 'tool.files.edit',
    'search'     => 'tool.files.search',
    'glob'       => 'tool.files.glob',
    'shell'      => 'tool.shell.exec',
    'git'        => 'tool.shell.git',
};
```

Registration is a hash — adding a new tool is a single line. The dispatch
function looks up the tool name, routes to the registered zenka command,
returns the result. No hardcoded tool handling.

---

## Safety Model

### Principle: Minimum Necessary Access

The model has access to exactly the tools registered in the coding zenka's
active session. Different session types can have different tool sets:

```
read-only session:   read_file, search, glob, git
development session: + write_file, edit_file, shell (sandboxed)
network session:     + zenka.command (access-controlled)
```

The access control is not enforced by the tool dispatch layer — it is
enforced by the cube routing system, which already handles access control
for all zenki. The tool zenki are just zenki. They inherit the same
security model as everything else in the network.

### Audit Trail

Every tool call is logged with:
- session identity (who called it)
- tool name and arguments
- timestamp and coordinate
- result hash (for integrity)

The log lives in the data zenka sub-tree for the session. It is part of
the route record — the session's actions are as much part of its identity
as its reasoning.

---

## Why This Completes the Development Environment

With file access and shell tools implemented, the model can:

- Read any file in the codebase
- Edit files with exact string replacement (same as Claude Code's Edit tool)
- Search for patterns across modules
- Run tests and see results
- Query git history and diffs
- Write new modules

This is the complete capability set of a coding assistant. The Protocol-7
implementation adds:

- **Persistence**: the session and its context survive connection drops
- **Identity**: the model accumulates expertise rather than resetting
- **Integration**: tool results flow into the compaction system, the topology,
  the litter coordination layer
- **Efficiency**: no Node.js overhead, no API relay, runs on pri.v7.ax directly

The shell is not being replaced by something worse or even equivalent.
It is being replaced by something that does everything it does and also
participates in the network as a full citizen.

---

## Implementation Checklist

- [ ] `coding.tool.dispatch` module — registry lookup + zenka command routing
- [ ] `coding.context.inject_tool_result` module — format + insert into context
- [ ] `tool.files.read` — wrapper over base.file.*
- [ ] `tool.files.write` — wrapper over base.file.*
- [ ] `tool.files.edit` — read + substitute + write with uniqueness check
- [ ] `tool.files.search` — regex search over source tree
- [ ] `tool.files.glob` — glob pattern matching
- [ ] `tool.shell.git` — read-only git operations
- [ ] Tool call parser in `coding.handler.process-queued-task`
- [ ] Tool registration in `coding.init_code`

### Related Documents
- `data/md/vision/infrastructure/VISION-P7-DEVELOPMENT-ENVIRONMENT.md` — context
- `data/md/vision/habitat/VISION-CONTEXT-COMPACTION.md` — tool results in compaction
- `data/md/vision/habitat/VISION-SESSION-IDENTITY.md` — audit trail and route record

#,,,.,,,.,...,.,,,.,,,...,.,,,,.,,...,...,.,.,..,,...,...,...,.,.,,.,,...,,,.,
#CV7DOAF4RPEORPL2RNWXMZIVMMOTAN6MUQM5UWCZBG7IIRSF5FTZIZX56D5H77774FRGJTEVTCBBC
#\\\|DBEI6R2AB6KDR2TK7GICKDGCDO7HG4BJJ26J2I4MO6LUVRJUG7L \ / AMOS7 \ YOURUM ::
#\[7]4A557TR3S56IEBYUHI53YT3OGV3GW624Y6KH3SBUDG3I3XRN26AQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
