# summarize-context — context summarization with model pinning

**Priority:** High
**Type:** Feature — New Tool + Zenka Command + Task Integration
**Component:** coding zenka tools, task zenka commands, valued tree

## Overview

Implement `summarize_context` as a reusable inference-backed summarization
primitive, exposed at three layers:

1. **coding tool** — model calls it mid-task to compress content
2. **zenka command** — network-accessible, any zenka can route to it
3. **task.cmd.summarize** — task zenka summarizes its own accumulated context

The key design requirement: **model pinning**. Each call can specify which
inference model to use for summarization. Larger-context models compress for
smaller fast models. Default routes to CPU backend to avoid interrupting
active GPU task inference.

## Architecture

```
summarize_context(content, focus, model, backend)
        ↓
  direct LWP inference call (like consensus_query — blocking, no state machine)
        ↓
  dense summary returned
        ↓
  stored in valued tree as weighted node (optional, if task_id provided)
```

## Layer 1: coding.tools.handler.summarize_context

New tool handler. Follow `coding.tools.handler.consensus_query` as reference
(direct LWP::UserAgent call, no async, returns string result).

**Parameters:**
```perl
my $content  = $args->{'content'}  // return 'content required';
my $focus    = $args->{'focus'}    // '';      ## optional focus directive
my $model    = $args->{'model'}    // '';      ## AMOS ID — empty = use configured default
my $backend  = $args->{'backend'}  // 'cpu';  ## cpu|gpu|auto — default cpu
my $max_len  = $args->{'max_len'}  // 800;    ## target summary token length
my $store    = $args->{'store'}    // 0;      ## 1 = store result in valued tree
my $node_id  = $args->{'node_id'} // '';      ## valued tree node to attach to
```

**Port resolution** — respect the backend parameter:
```perl
my $port = ( $backend eq 'cpu' )
    ? ( <inference.backend.cpu.port>  // 8001 )
    : ( <inference.backend.gpu.port>  // 8000 );
```

**Model in request body** — pass through to llama-server:
```perl
my $request_body = {
    model    => length($model) ? $model : undef,  ## undef = server uses loaded model
    messages => [
        { role => 'system', content => $system_prompt },
        { role => 'user',   content => $user_content  },
    ],
    max_tokens  => $max_len,
    temperature => 0.2,   ## low temp — summaries should be deterministic
    stream      => JSON::PP::false,
};
## omit model key entirely if not specified — avoids server rejection ##
delete $request_body->{'model'} unless length( $request_body->{'model'} // '' );
```

**System prompt** — compaction-style, focus-aware:
```perl
my $system_prompt =
    'you are a context compaction assistant. '
    . 'produce a dense, precise summary that preserves all load-bearing '
    . 'specifics: module names, line numbers, decisions, open questions. '
    . 'omit narrative filler. '
    . ( length($focus) ? "focus on: $focus. " : '' )
    . 'target length: 2-4 paragraphs.';

my $user_content =
    "summarize the following content:\n\n$content";
```

**Valued tree storage** (when store=1):
```perl
if ( $store and length($node_id) ) {
    <[valued.tree.register_node]>->({
        id       => $node_id . '.summary',
        weight   => 0.5,
        parents  => [ $node_id ],
        metadata => { focus => $focus, model => $model, ts => <[base.ntime.b32]> },
    });
    ## store summary text in data tree for retrieval ##
    <{ "valued.summaries.$node_id" }> = $summary_text;
}
```

**Tool definition** — add to coding.tools.definitions:
```perl
## summarize_context — model-pinned inference summarization ##
{
    name        => 'summarize_context',
    description =>
        'summarize content using a dedicated inference call. '
        . 'supports model pinning — specify a large-context model for '
        . 'compression, small fast model receives the dense result. '
        . 'routes to cpu backend by default to avoid interrupting active tasks.',
    parameters => {
        content  => { type => 'string',  description => 'text to summarize' },
        focus    => { type => 'string',  description => 'summarization focus directive [ optional ]' },
        model    => { type => 'string',  description => 'AMOS model ID to use [ empty = loaded model ]' },
        backend  => { type => 'string',  description => 'cpu|gpu|auto [ default cpu ]' },
        max_len  => { type => 'integer', description => 'target summary tokens [ default 800 ]' },
        store    => { type => 'boolean', description => 'store result in valued tree [ default false ]' },
        node_id  => { type => 'string',  description => 'valued tree node to attach summary to' },
    },
    required => ['content'],
}
```

## Layer 2: coding.cmd.summarize-context

Network command so any zenka can request summarization from the coding zenka.

**File:** `src/coding.cmd.summarize-context`

```perl
## parse args: content [focus=...] [model=AMOS:ID] [backend=cpu|gpu] ##
my $args_str = $call->{'args'} // '';

## multiline mode: content in call->{'data'}, options in args ##
my $content = $call->{'data'} // $args_str;
my $focus   = '';
my $model   = '';
my $backend = 'cpu';

if ( $args_str =~ s|focus=([^\s]+)|| )   { $focus   = $1 }
if ( $args_str =~ s|model=(\S+:\S+)|| )  { $model   = $1 }
if ( $args_str =~ s|backend=(cpu|gpu)|| ) { $backend = $1 }
```

**Add to coding zenka start:**
- Add `summarize-context` to the access cmd list
- Add to `cube/access.zenki` for zenki that need it (task, models)

## Layer 3: task.cmd.summarize

Task zenka command that summarizes a task's accumulated notes/context and
stores the result in the valued tree.

**File:** `src/task.cmd.summarize`

```perl
## usage: p7c task.summarize <task_id> [focus=<topic>] [model=<AMOS:ID>] ##
my ( $task_id, @opts ) = split m{\s+}, ( $call->{'args'} // '' );
return { mode => 'false', data => 'task_id required' } unless length $task_id;

my $focus = '';
my $model = '';
for my $opt (@opts) {
    $focus = $1 if $opt =~ m{^focus=(.+)};
    $model = $1 if $opt =~ m{^model=(.+)};
}

## gather task context: description + recent notes + result so far ##
my $task = <task.queue>->{$task_id}
    // return { mode => 'false', data => "task not found: $task_id" };

## route to coding zenka for actual summarization inference ##
<[protocol-7.route-send]>->(
    {   command   => 'coding.summarize-context',
        call_args => {
            data => $context_text,
            args => join( ' ',
                length($focus) ? "focus=$focus" : (),
                length($model) ? "model=$model" : (),
            ),
        },
        reply => {
            handler => 'task.handler.summarize-reply',
            params  => { task_id => $task_id },
        },
    }
);
return { mode => 'deferred' };
```

**Reply handler:** `src/task.handler.summarize-reply`
- Receives summary from coding zenka
- Stores in `<task.queue>->{$task_id}{'summary'}` 
- Calls `valued.tree.record_outcome` with summary as outcome text
- Returns summary to original caller

## Config additions (coding zenka start)

```
## default model for summarization [ empty = use loaded task model ] ##
## set to a large-context model AMOS ID for high-quality compression ##
coding.cfg.summarize_model   =           ## e.g. WZIZD6Y:2BIZKWY for 9B reasoner
coding.cfg.summarize_backend = cpu       ## cpu = background, gpu = foreground
```

## Acceptance Criteria

- `p7c coding.call-tool summarize_context '{"content":"...","focus":"watcher patterns"}'` returns summary
- `p7c coding.summarize-context "content" focus=watcher-patterns` works via network
- `p7c task.summarize <task_id>` summarizes task notes and stores in valued tree
- model pinning: specifying `model=WZIZD6Y:2BIZKWY` routes to that model in request
- backend routing: `backend=cpu` uses port 8001, `backend=gpu` uses port 8000
- valued tree: when `store=1`, summary node appears in `p7c task.valued-list`
- default behavior (no model specified): uses loaded model, no switch triggered

## Notes

- signatures_note: leave signing to the system, no stub lines
- follow consensus_query.pm for the LWP pattern exactly
- the `model` field in llama-server request body is informational — it does not
  trigger a server-side model switch. actual model switching remains a separate
  operation (coding.cmd.switch-model). the model param here is for future
  distributed routing where different nodes serve different models.
- for true multi-model pipeline: configure CPU backend with large-context model
  at startup. GPU runs fast task model. summarize_context routes to CPU by default.
  no switching needed — two backends, two models, running simultaneously.

#,,,.,,,,,,.,,.,.,.,.,.,.,,,,,.,.,.,,,,..,,..,..,,...,...,.,.,.,,,...,.,.,,.,,
#QRZYDXGOKLJ7EQ32D3UZS6HHFV6IC5I6NP7FURYJTR5CYT346B7QMCLHBMFMQQMZV22GWRAV7TKJY
#\\\|4F3ZQW2RSMFK4F23A4UPP6BCLA7NR6NYBALXZK5K7IZS2PU77C5 \ / AMOS7 \ YOURUM ::
#\[7]RIXFYAKXKTBCVVY7FWOF47YO4GCFBMNU4V3N6GIX3HGA4L6BNYBQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
