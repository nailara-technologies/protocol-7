# rewind-stack — per-task file diff capture, BMW content addressing, read-only flag

**Priority:** High
**Type:** Feature — Task Infrastructure
**Component:** coding.tools.dispatch, coding.tools.rewind.*, task record

## Overview

Capture before/after file state for every write tool call, keyed by BMW-L13
content hash. Stored in the task record as a rewind stack. Enables:

1. **Fine-grained rewind** — roll back to exact file state before any tool call
2. **Model comparison** — diffs are ground truth for evaluation benchmarks
3. **Content deduplication** — same file state across tasks shares one blob
4. **Distributed compatibility** — BMW hash is already a P7 routing address

## Design Principles

**Atomicity**: capture happens synchronously inside `coding.tools.dispatch`
between tool execution and result return. The task cannot advance to the next
round before the diff is recorded — this is guaranteed by the dispatch
structure (synchronous within the async state machine).

**Content addressing**: BMW-L13 hash identifies each unique file state.
Two files in the same state share one stored blob. Stack entries reference
hashes only — content lives in a separate store.

**Null state**: file did not exist = hash 'null'. Rewind of a write_new_file
with before_hash='null' means unlink the file.

## Implementation

### coding.tools.dispatch — intercept write tools

Write tools to intercept (path extractable from args for all):
```
write_new_file   → args.path
edit_file        → args.path
replace_in_file  → args.path
delete_lines     → args.path
insert_line      → args.path
replace_line     → args.path
file_rename      → args.source (before) + args.target (after)
remove_file      → args.path
```

Add to dispatch, wrapping the tool execution:

```perl
## capture file state before and after write tool calls ##
my @write_tools = qw|
    write_new_file edit_file replace_in_file
    delete_lines insert_line replace_line
    file_rename remove_file
|;

my ( $before_hash, $after_hash, $capture_path );

if ( grep { $_ eq $name } @write_tools ) {
    $capture_path = $abs_path // catfile( <system.root_path>,
        $args->{'path'} // $args->{'source'} // '' );

    if ( length($capture_path) and -f $capture_path ) {
        my $before = <[file.slurp]>->($capture_path)->$*;
        $before_hash = <[base.chk-sum.bmw-l13]>->($before);
        ## store content once by hash — dedup across tasks ##
        <coding.rewind.store>->{$before_hash} //= $before;
    } else {
        $before_hash = 'null';    ## file did not exist ##
    }
}

## ... existing dispatch execution ... ##

if ( defined $before_hash ) {
    if ( length($capture_path) and -f $capture_path ) {
        my $after = <[file.slurp]>->($capture_path)->$*;
        $after_hash = <[base.chk-sum.bmw-l13]>->($after);
        <coding.rewind.store>->{$after_hash} //= $after;
    } else {
        $after_hash = 'null';     ## file was deleted ##
    }

    ## only record if something actually changed ##
    if ( $before_hash ne $after_hash ) {
        my $task_id = <coding.task.active_id> // '';
        if ( length $task_id and defined <coding.task.queue>->{$task_id} ) {
            push <coding.task.queue>->{$task_id}{'rewind_stack'}->@*, {
                round       => $tool_round,
                tool        => $name,
                path        => $capture_path,
                before_hash => $before_hash,
                after_hash  => $after_hash,
            };
        }
    }
}
```

### coding.tools.rewind.apply — restore file to state N

New module: `modules/coding.tools.rewind.apply`

```perl
# name  = coding.tools.rewind.apply
# descr = rewind task files to state before round N

my ( $task_id, $target_round ) = @ARG;

my $task = <coding.task.queue>->{$task_id}
    // return { ok => 0, error => "task not found" };

my $stack = $task->{'rewind_stack'} // [];
return { ok => 1, rewound => 0 } unless @$stack;

my $rewound = 0;
## iterate from newest to oldest, stop at target_round ##
for my $entry ( reverse @$stack ) {
    last if $entry->{'round'} < $target_round;

    my $path        = $entry->{'path'};
    my $before_hash = $entry->{'before_hash'};

    if ( $before_hash eq 'null' ) {
        ## file was created by this tool call — remove it ##
        unlink $path if -f $path;
    } else {
        my $content = <coding.rewind.store>->{$before_hash};
        if ( defined $content ) {
            <[file.write]>->( $path, \$content, qw| :encoding(UTF-8) | );
        }
    }
    $rewound++;
}

## trim stack to before target_round ##
$task->{'rewind_stack'}
    = [ grep { $_->{'round'} < $target_round } @$stack ];

return { ok => 1, rewound => $rewound };
```

### coding.cmd.rewind — network command

New module: `modules/coding.cmd.rewind`

```perl
## usage: p7c coding.rewind <task_id> [round=N] ##
## default: rewind to before last write tool call ##
my $args_str  = $call->{'args'} // '';
my ($task_id) = $args_str =~ m{^([A-Z0-9]{7})};
my ($round)   = $args_str =~ m{round=(\d+)};

return { mode => 'false', data => 'task_id required' }
    unless defined $task_id and length $task_id;

my $stack = <coding.task.queue>->{$task_id}{'rewind_stack'} // [];
$round //= $stack->[-1]{'round'} // 0;    ## default: undo last write ##

my $result = <[coding.tools.rewind.apply]>->( $task_id, $round );

return {
    mode => $result->{'ok'} ? 'size' : 'false',
    data => $result->{'ok'}
        ? sprintf( "rewound %d file change(s) to before round %d",
            $result->{'rewound'}, $round )
        : $result->{'error'},
};
```

### Init and config

In `coding.init_code` or `coding.task.execute`:
```perl
<coding.rewind.store> //= {};   ## BMW hash → content blob ##
```

Add `rewind` to coding zenka access.cmd.usr.cube list.

## Content Store Lifecycle

- `<coding.rewind.store>` lives in memory for the session
- At task completion, persist with task buffers (same xz lifecycle)
- Cross-task deduplication: if two tasks modify the same file to the same
  state, they share one blob in the store
- BMW-L13 is compact (13 base32 chars) and already loaded in coding zenka
- Future: `coding.rewind.store` becomes a distributed content store keyed
  by BMW hash — "restore state BMW:XXXXXXX" routes to any node holding it

## Feature 2: :read-only: Task Flag

Implement in the same dispatch intercept. A task with `read_only: 1` in its
flags blocks write tools for protected paths, while permitting writes to an
explicit allowlist.

### Task flags (stored in task record at creation time)

Parse from description prefix — extends the existing `:model:`, `:review:` pattern:
```
:local: :read-only: investigate modules/coding.handler.process-queued-task
:local: :read-only: :write=data/yaml/tool-hints/staged/: review ...
```

`task.cmd.create` parses these from the description and stores in `task->{'flags'}`:
```perl
$flags->{'read_only'}     = 1  if $description =~ s/:read-only:\s*//i;
($flags->{'write_allowed'}) = $description =~ s/:write=([^:]+):\s*//i;
## write_allowed is colon-separated list of permitted path prefixes ##
```

Default allowlist when read-only (always permitted regardless of :write=):
- `/var/protocol-7/coding/notes/`  — note tools (note_write etc.)
- `/var/protocol-7/coding/tree/`   — tree_write
- `data/scratch/<task_id>/`        — task-local scratch space (auto-created)

### Enforcement in coding.tools.dispatch

Add after path resolution, before tool execution:
```perl
if ( grep { $_ eq $name } @write_tools ) {
    my $task_id  = <coding.task.active_id> // '';
    my $flags    = <coding.task.queue>->{$task_id}{'flags'} // {};

    if ( $flags->{'read_only'} ) {
        my @always_ok = (
            '/var/protocol-7/coding/notes/',
            '/var/protocol-7/coding/tree/',
            <system.root_path> . "/data/scratch/$task_id/",
        );
        my @extra = split m{:}, ( $flags->{'write_allowed'} // '' );
        my @allowed = ( @always_ok, map { <system.root_path> . "/$_" } @extra );

        my $permitted = grep { index( $capture_path, $_ ) == 0 } @allowed;
        return "error: write blocked [ read-only task ] path: $capture_path\n"
            . "permitted prefixes: " . join( ', ', @allowed )
            unless $permitted;
    }
}
```

### Scratch directory

Auto-create `data/scratch/<task_id>/` when task starts if read_only flag set.
Clean up after task completes (or keep for review — configurable).
Read-only tasks produce no rewind_stack entries (nothing to undo by definition).

### Acceptance Criteria (Feature 2)

- `:read-only:` in task description → write tools blocked for protected paths
- note_write, tree_write always permitted in read-only tasks
- `:write=data/yaml/tool-hints/staged/:` grants additional path prefix
- scratch dir auto-created, auto-cleaned after completion
- `p7c task.show <id>` displays flags including read_only status
- read-only tasks produce empty rewind_stack (no overhead)

## Acceptance Criteria (Feature 1 — rewind stack)

- `p7c coding.rewind <task_id>` restores file(s) to state before last write
- `p7c coding.rewind <task_id> round=7` restores all changes from round 7+
- `p7c coding.show-buffer` includes rewind_stack length in task info
- write_new_file with before=null: rewind removes the file
- remove_file: rewind restores the file from store
- file_rename: rewind restores both source and target paths
- no-op if before_hash == after_hash (content unchanged)
- store deduplicates: same content → same BMW hash → one stored blob

## Notes

- signatures_note: leave signing to the system, no stub lines
- BMW-L13: use `<[base.chk-sum.bmw-l13]>` (already loaded in coding zenka)
  verify availability: `p7c coding.call-tool list_modules '{"namespace":"base.chk-sum"}'`
- the rewind_stack grows linearly with write tool calls — typical tasks
  touch 5-20 files across 10-50 rounds, stack stays small
- rewind.apply uses direct file.write bypassing chmod child since it
  restores to a known-good previous state (already existed with right perms)

#,,,.,,,.,...,,.,,,,.,.,,,...,.,.,...,,,.,,..,..,,...,...,,,.,,,,,,.,,,,,,.,.,
#KACYXJU4WEGDDCUCEBZVVRB2YYVE3TRCWTXGGS3IYWTKIPJHZNHSZOV33U42EIVUQQR66UBGXBBPO
#\\\|U5MVW6TRJLWEAQCTLCJF3U3T3QBZR5DE3J2DMS6ONCXT77KNM7H \ / AMOS7 \ YOURUM ::
#\[7]HYI2SPW7BSXSB2ECMD6335UVCBBPWWLEGRNENGEIUGKV4RPIFAAQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
