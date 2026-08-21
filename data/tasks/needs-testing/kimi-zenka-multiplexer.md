## [:< ##

# name  = task: kimi-web zenka — STRM-based dispatch, task queue, sudo auto-decline
# descr = replace single-reply dispatch with persistent STRM channels; add task
#         queue for sequential multi-task dispatch; auto-decline sudo prompts

## kimi memory

if in doubt about P7 patterns, coding style, or project context — read first:
```bash
cat data/ai-mem/kimi/MEMORY.md
cat data/ai-mem/kimi/coding-style.md
cat data/ai-mem/kimi/topic-zenki-creation-guide.md
```

## IMPORTANT: run this via kimi-cli directly, not via the kimi-web zenka

this task modifies the kimi-web zenka itself. using kimi-web to implement
kimi-web would create a moving-target problem. use a kimi-cli session directly.

## context

the kimi-web zenka has a working HTTP agent architecture:
- `kimi-web.bridge.ensure_local_agent` — spawns/reuses local kimi-cli agent
- `kimi-web.cmd.dispatch` — sends prompt to agent, single reply
- `kimi-web.cmd.dispatch_parallel` — multiple agents simultaneously
- `kimi-web.cmd.spawn_agent` / `terminate_agent` — lifecycle management
- `kimi-web.handler.agent_health_check` — polling agent status
- `kimi-web.internal.http_post_async` / `http_post_sync` — HTTP transport

**current problems:**

1. **no STRM channel** — `cmd.dispatch` returns a single reply when the task
   completes. there is no way to receive progress updates, approval requests,
   or sudo prompts incrementally. the caller blocks or polls.

2. **sudo blocks** — when kimi-cli surfaces a sudo prompt through its HTTP API,
   there is no handler for it. the session blocks until timeout.

3. **no task queue** — only one task can be tracked at a time. dispatching a
   second task while the first is running loses track of the first.

4. **approval requests** — tool approval requests from kimi-cli are not
   consistently auto-approved for safe operations (ReadFile, BashCommand with
   safe commands, WriteFile to src/).

## signatures note

do not add signature stubs. do not run `bin/Protocol-7 sourcecode update-signatures`.
do not add or modify subroutine whitelists — these are managed separately.

---

## what to read first

```bash
## full kimi-web module set
cat src/kimi-web.cmd.dispatch
cat src/kimi-web.cmd.dispatch_parallel
cat src/kimi-web.bridge.ensure_local_agent
cat src/kimi-web.internal.http_post_async
cat src/kimi-web.internal.http_post_sync
cat src/kimi-web.handler.batch_result
cat src/kimi-web.handler.agent_health_check
cat src/kimi-web.init_code
cat cfg/zenki/kimi-web/start.cfg

## STRM pattern reference
cat src/base.stream.open
cat src/base.stream.push
cat src/base.stream.close
cat src/radio.cmd.listen      ## example of unbounded STRM in a command

## task queue pattern reference
cat src/coding.handler.process-queued-task
```

---

## architecture: STRM-based dispatch

### current flow
```
caller → kimi-web.cmd.dispatch → HTTP POST to agent → wait → single reply
```

### new flow
```
caller → kimi-web.cmd.dispatch_stream → STRM open (unbounded)
                                              ↓
                    kimi-web polls agent HTTP API for events
                                              ↓ STRM packets pushed as events arrive:
                    { type: progress,  data: "reading file X" }
                    { type: approval,  tool: ReadFile, path: "...", id: "req-1" }
                    { type: sudo,      prompt: "password for taeki:" }
                    { type: result,    data: "module written" }
                    { type: complete,  status: done, summary: "..." }
                                              ↓
                                         STRM close
```

---

## new module: kimi-web.cmd.dispatch_stream

opens a STRM reply channel, dispatches to agent, pushes events as they arrive.

```perl
## [:< ##

# name  = kimi-web.cmd.dispatch_stream
# descr = dispatch to kimi-web agent with persistent STRM event channel
# param = { agent_id, prompt, timeout, fresh }

my $call = shift;
my $args = $call->{'args'} // {};

## ensure agent available
my $agent = <[kimi-web.bridge.ensure_local_agent]>;
return { 'mode' => 'false', 'data' => 'no agent available' }
    unless defined $agent;

## open unbounded STRM reply channel
my $stream_handle = <[base.stream.open]>->({
    'sid'    => $call->{'session_id'},
    'cmd_id' => $call->{'cmd_id'},
    'type'   => 'STRM',
    'total'  => undef,   ## unbounded
});
return { 'mode' => 'false', 'data' => 'stream open failed' }
    unless defined $stream_handle;

## store stream handle for event push
my $task_id = <[base.gen_id]>->( <kimi-web.task.registry> //= {} );
<kimi-web.task.registry>->{$task_id} = {
    'handle'   => $stream_handle,
    'agent'    => $agent,
    'prompt'   => $args->{'prompt'},
    'started'  => <[base.time]>->(3),
    'timeout'  => $args->{'timeout'} // 300,
};

## dispatch prompt to agent HTTP API
<[kimi-web.internal.http_post_async]>->({
    'url'      => $agent->{'url'} . '/dispatch',
    'body'     => { prompt => $args->{'prompt'}, fresh => $args->{'fresh'} // 0 },
    'handler'  => 'kimi-web.handler.stream_event',
    'task_id'  => $task_id,
});

## return deferred — STRM delivers events as they arrive
return { 'mode' => 'deferred' };
```

---

## new module: kimi-web.handler.stream_event

receives HTTP response chunks from agent, classifies them, pushes STRM packets.

```perl
# name = kimi-web.handler.stream_event

my $event   = shift;   ## HTTP response data from agent
my $task_id = shift;

my $task   = <kimi-web.task.registry>->{$task_id};
my $handle = $task->{'handle'};

## classify event type from agent response
my $type = $event->{'type'} // 'progress';
my $data = $event->{'data'} // '';

## auto-handle sudo prompts
if ( $type eq 'sudo' or $data =~ m|password for|i ) {
    <[base.log]>->( 1, 'kimi-web: auto-declining sudo prompt' );
    <[kimi-web.internal.http_post_async]>->({
        'url'  => $task->{'agent'}{'url'} . '/respond',
        'body' => { response => '' },   ## empty = decline
    });
    <[base.stream.push]>->( $handle,
        encode_json({ type => 'sudo_declined', data => $data }) . "\n"
    );
    return;
}

## auto-approve safe tool calls
if ( $type eq 'approval' ) {
    my $tool = $event->{'tool'} // '';
    my $auto = <[kimi-web.is_auto_approvable]>->( $event );
    if ($auto) {
        <[kimi-web.internal.http_post_async]>->({
            'url'  => $task->{'agent'}{'url'} . '/approve',
            'body' => { request_id => $event->{'id'}, approved => 1 },
        });
        <[base.stream.push]>->( $handle,
            encode_json({ type => 'auto_approved', tool => $tool }) . "\n"
        );
        return;
    }
    ## non-auto-approvable: push to caller for human decision
}

## push event to STRM caller
<[base.stream.push]>->( $handle,
    encode_json({ type => $type, data => $data }) . "\n"
);

## close stream on completion
if ( $type eq 'complete' or $type eq 'error' ) {
    <[base.stream.close]>->($handle);
    delete <kimi-web.task.registry>->{$task_id};
    <[kimi-web.process_queue]>;   ## start next queued task if any
}
```

---

## new module: kimi-web.is_auto_approvable

returns TRUE for tool calls that are always safe to approve:

```perl
# name = kimi-web.is_auto_approvable

my $event = shift;
my $tool  = $event->{'tool'} // '';
my $path  = $event->{'path'} // $event->{'args'} // '';

## always approve file reads
return TRUE if $tool eq 'ReadFile';
return TRUE if $tool eq 'ListDirectory';

## approve writes only to safe paths
if ( $tool eq 'WriteFile' ) {
    return TRUE if $path =~ m|^src/|;
    return TRUE if $path =~ m|^cfg/zenki/|;
    return TRUE if $path =~ m|^data/(tasks|md|yaml)/|;
}

## approve safe bash commands
if ( $tool eq 'BashCommand' ) {
    return TRUE if $path =~ m|^(grep|cat|ls|find|wc|head|tail|perl -c)|;
    return TRUE if $path =~ m|^(git (log|diff|show|status))|;
    return TRUE if $path =~ m|^(p7c? \w)|;
}

return FALSE;
```

---

## task queue

### kimi-web.cmd.enqueue

adds a task to the queue, starts processing if idle:

```perl
# name = kimi-web.cmd.enqueue

my $call = shift;
my $task = {
    'id'      => <[base.gen_id]>->( <kimi-web.task.queue> //= [] ),
    'args'    => $call->{'args'},
    'sid'     => $call->{'session_id'},
    'cmd_id'  => $call->{'cmd_id'},
    'queued'  => <[base.time]>->(3),
};
push @{<kimi-web.task.queue>}, $task;
<[kimi-web.process_queue]>;
return { 'mode' => 'true', 'data' => "queued: $task->{id}" };
```

### kimi-web.process_queue

```perl
# name = kimi-web.process_queue

return if scalar keys %{<kimi-web.task.registry> // {}} > 0;   ## busy
return unless @{<kimi-web.task.queue> // []};

my $next = shift @{<kimi-web.task.queue>};
<[kimi-web.cmd.dispatch_stream]>->({ 'args' => $next->{'args'},
    'session_id' => $next->{'sid'}, 'cmd_id' => $next->{'cmd_id'} });
```

---

## test sequence

```bash
## dispatch with STRM and watch events
p7c kimi-web.cmd.dispatch_stream '{
  "prompt": "cat src/X-11.init_code",
  "fresh": 1
}'
## expected: STRM opens, progress packets arrive, complete closes stream

## test sudo auto-decline
## (trigger by dispatching something that would prompt for sudo)
## expected: STRM packet { type: sudo_declined }, session continues

## test queue
p7c kimi-web.cmd.enqueue '{ "prompt": "task 1" }'
p7c kimi-web.cmd.enqueue '{ "prompt": "task 2" }'
## expected: task 1 gets STRM, task 2 waits; after task 1 complete, task 2 starts
```

## success criteria

- [ ] `kimi-web.cmd.dispatch_stream` opens unbounded STRM
- [ ] STRM packets arrive for progress, approval, sudo, result, complete
- [ ] sudo prompts auto-declined without blocking
- [ ] safe tool calls (ReadFile, safe BashCommand) auto-approved
- [ ] unsafe tool calls pushed to caller as STRM packet for human decision
- [ ] STRM closes on task complete or error
- [ ] `kimi-web.cmd.enqueue` queues tasks
- [ ] `kimi-web.process_queue` starts next task after STRM closes
- [ ] no signature stubs added, no whitelist changes

#,,..,,,,,.,.,,,.,,..,..,,..,,,..,,..,,,,,,,.,..,,...,...,...,..,,,.,,...,.,.,
#HNELS5RCHCL4PYMDKVZQWPXR4BQYGYTAPSI7IEV5YBOCK4YIC7TADLGARRBRTKKJSGC7LCXBE2F7W
#\\\|XU2V7ZBU2LVSHO4IWVTAOM47EVJJVVPQ5FPPDACHW3OGSLFWLGF \ / AMOS7 \ YOURUM ::
#\[7]ZH6BH5GTOCBO2RMKA46BIIWJMQQV2ZGLKFN5QNYB2XBYIW5RVQCA 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
