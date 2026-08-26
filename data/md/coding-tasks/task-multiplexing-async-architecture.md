# Task Multiplexing and Async Processing Architecture

## Current State Analysis

### Jobqueue Flow (Current)
```
task_enqueue()
  ↓
jobqueue.add_job(object_id=server_dep) → 'depending' queue
  ↓
[dependency resolved: server ready]
  ↓
jobqueue.move_job() → 'queued' queue
  ↓
jobqueue counter watcher dispatches
  ↓
jobqueue.move_job() → 'running' queue
  ↓
coding.task.execute() → BLOCKING inference loop
  ↓
jobqueue.move_job() → 'completed'/'error'
```

### Problems with Current Architecture

1. **Blocking Inference Loop**: `process-queued-task` blocks during HTTP calls (300s timeout)
2. **No True Concurrency**: Only one task can run at a time per backend (GPU/CPU)
3. **Event Loop Starvation**: While inference runs, no other events processed
4. **Resource Underutilization**: GPU idle during I/O, context switching, etc.

## Proposed Architecture

### Design Goals

1. **Non-blocking Inference**: Use async HTTP or deferred replies
2. **Task Multiplexing**: Multiple tasks in "running" state, batched GPU execution
3. **Resource Awareness**: Respect VRAM limits, queue appropriately
4. **Backward Compatibility**: Existing task flow continues to work
5. **Hierarchical Tasks**: Parent tasks with subtasks/agents, delegation patterns
6. **Logical Dependencies**: Tasks depend on others, automatic queue management
7. **Model Pinning**: Tasks bound to specific models with implicit switching

### Use Cases

#### 1. Parent Task with Subtasks/Agents

**Scenario**: A complex refactoring task spawns specialized agents:
- Parent: "Refactor database layer"
- Subtask 1 (Agent A): "Analyze current schema" → read-only analysis
- Subtask 2 (Agent B): "Design new schema" → depends on Subtask 1
- Subtask 3 (Agent C): "Migrate data" → depends on Subtask 2
- Parent: "Verify migration" → depends on all subtasks

**Implementation**:
```perl
# Parent task spawns subtasks via delegation
<coding.task.subtasks>->{$parent_task_id} = [
    { task_id => 'task-A', type => 'analysis', agent => 'schema-analyzer' },
    { task_id => 'task-B', type => 'design',   agent => 'schema-designer', deps => ['task-A'] },
    { task_id => 'task-C', type => 'migration', agent => 'data-migrator', deps => ['task-B'] },
];

# Subtasks use parent's context but don't write code directly
# Instead report findings to parent for integration
```

**Key Features**:
- Subtasks share parent context (read-only)
- Subtask results feed back to parent
- Parent coordinates, doesn't duplicate work
- Agents can be specialized models (different model per agent)

#### 2. Logical Task Dependencies

**Scenario**: Documentation task depends on API changes being complete first.

**Implementation**:
```perl
# Task B depends on Task A
my $task_b = {
    id => 'task-doc-update',
    type => 'documentation',
    description => 'Update API docs',
    dependencies => {
        logical => ['task-api-changes'],  # Wait for task-id
        files   => ['src/new_api.pm'], # Or file existence
    },
};

# Task stays in 'depending' queue until:
# - All logical task deps complete (status=completed)
# - AND/OR file deps exist
```

**Queue Flow**:
```
task_enqueue(task-B with logical deps)
  ↓
jobqueue.add_job() → 'depending' queue
  ↓
jobqueue.check_dependencies()
  ↓
[logical deps NOT resolved] → stay in 'depending'
  ↓
[task-A completes] → triggers dep check
  ↓
[all deps resolved] → move to 'queued'
```

#### 3. Model Pinning with Implicit Switching

**Scenario**: Tasks require specific models (reasoning vs creative vs code).

**Implementation**:
```perl
# Task specifies model preference
task => {
    id => 'task-code-review',
    model => {
        preferred => 'YZX4A3B:CODE',     # Specific model
        fallback  => 'gpu',               # Or backend type
        requirements => {
            context_length => 128000,
            tool_calling   => TRUE,
        }
    }
};

# Implicit model switching:
# 1. Task arrives, check if current model matches
# 2. If not, queue for model switch
# 3. Switch model (restart server with new model)
# 4. Execute task
# 5. Next task may trigger switch back
```

**Model Router Logic**:
```perl
<[coding.routing.model_switch]>->($task) {
    my $current_model = <inference.current.model_id>;
    my $required_model = $task->{'model'}->{'preferred'};

    if ($current_model ne $required_model) {
        # Queue model switch as dependency
        my $switch_dep = <[coding.model.queue_switch]>($required_model);
        <[dependency.add]>->($task->{'object_id'}, $switch_dep);
        return 'depending';  # Task waits for model
    }

    return 'ready';  # Current model OK
}
```

**Optimization**: Batch same-model tasks to minimize switches.

**Context Templates with Model Pinning**:

Context templates already exist for task classification. They should be extended with model hints:

```yaml
# context.yaml or data/yaml/context-templates/
template:
  name: code-review
  pattern: "code.?review|review.?code"
  model:
    preferred: "YZX4A3B:CODE"  # Code-optimized model
    temperature: 0.2            # Conservative
  tools:
    - read_file
    - search_code
    # No write tools - read-only review

template:
  name: creative-writing
  pattern: "creative|story|narrative"
  model:
    preferred: "YZX4A3B:CREATIVE"
    temperature: 0.9
  # ...
```

When a task is classified:
1. Match template by pattern
2. Extract model preference from template
3. Apply as implicit `model_pin`
4. Task waits in `depending` if model switch needed

---

### Key Components

#### 1. Async Inference Module

New module: `coding.handler.async_inference`

```perl
# Instead of blocking HTTP call:
my $response = $ua->post(...);  # BLOCKS for 300s max

# Use AnyEvent HTTP or deferred callback:
<[coding.async_inference.request]>->(
    task_id      => $task_id,
    messages     => \@messages,
    callback     => 'coding.handler.inference_complete',
);
# Returns immediately, event loop continues
```

#### 2. Task State Machine Extension

Current states: `pending → in_progress → completed/failed`

New states for multiplexing:
- `waiting_gpu`: Task ready but GPU busy (queued at GPU level)
- `batched`: Task batched with others for concurrent execution
- `inferencing`: Active GPU inference
- `post_processing`: Handling results, tool calls

#### 3. GPU Resource Manager

New module: `coding.gpu.resource_manager`

```perl
# Track GPU state
<coding.gpu.active_tasks>    = [];  # Tasks currently on GPU
<coding.gpu.vram_used>       = 0;   # Tracked VRAM usage
<coding.gpu.max_concurrent>  = 2;   # Based on VRAM/model size

# Batch compatible tasks (same model, compatible contexts)
<[coding.gpu.schedule_batch]>->(@waiting_tasks);
```

#### 4. Dependency Chain Extensions

Extend existing dependency system:

```perl
# New dependency types for task multiplexing
<dependency.setup>->('gpu_slot_available', { callback => ... });
<dependency.setup>->('vram_available', { callback => ... });
<dependency.setup>->('task_priority', { callback => ... });
```

### Implementation Phases

#### Phase 1: Deferred Reply Foundation

Modify `coding.handler.process-queued-task`:
1. At inference loop start, return `{ mode => 'deferred', ... }`
2. Set up callback for when inference completes
3. Store task state in `<coding.async.task_state>`
4. Process next event loop iteration

#### Phase 2: Non-blocking HTTP with Streaming

Options:
1. **AnyEvent::HTTP**: Integrate with existing event loop
2. **Coro + AnyEvent**: Cooperative threading
3. **Separate Process**: Fork inference worker, communicate via socket

Recommended: Option 1 (AnyEvent::HTTP) with streaming
- Integrates with existing event loop
- Supports chunked response handling
- Can write to buffer incrementally

**Critical Requirement**: HTTP response must be STREAMED

Current blocking approach:
```perl
# BLOCKS until full response received
my $response = $ua->post($url, Content => $body);
$response_text = $response->content;  # All at once
```

Async streaming approach:
```perl
# Returns immediately, callback per chunk
<[coding.async.http.request]>->(
    url      => $url,
    body     => $body,
    on_header => sub { ... },           # Response started
    on_body   => sub {                 # Called per chunk
        my ($chunk, $is_complete) = @_;
        <[coding.buffer.model_output]>->($chunk, ...);
        return TRUE;  # Continue receiving
    },
    on_complete => sub {               # All done
        my ($full_response) = @_;
        <[coding.async.inference_done]>->($task_id, $full_response);
    },
);
```

This allows:
- Model output buffer updates in real-time
- Event loop processes other tasks between chunks
- Stop requests can be handled mid-inference
- Timeout handling per chunk (detect stalled inference)

#### Phase 3: Task Batching

When multiple tasks waiting:
1. Group by model (must use same model for batching)
2. Check total context length fits in VRAM
3. Batch inference request
4. Distribute results to respective task callbacks

#### Phase 4: Priority & Preemption

1. High-priority tasks can preempt low-priority
2. Checkpoint tasks for resume (context compaction)
3. Timeout handling for stuck inference

### Module Inventory

#### Existing Modules to Modify

| Module | Changes |
|--------|---------|
| `coding.handler.process-queued-task` | Add deferred mode, state persistence |
| `coding.task.execute` | Support async completion callback |
| `coding.task.enqueue` | Add batching hints, priority metadata |
| `coding.init_dependencies` | Add GPU resource dependencies |

#### New Modules Required

| Module | Purpose |
|--------|---------|
| `coding.handler.async_inference` | Non-blocking inference requests |
| `coding.handler.inference_complete` | Callback for finished inference |
| `coding.handler.inference_chunk` | Per-chunk response handling |
| `coding.gpu.resource_manager` | VRAM tracking, batch scheduling |
| `coding.task.state_manager` | Persist/restore task state |
| `coding.task.hierarchy` | Parent/subtask management |
| `coding.task.logical_deps` | Dependency resolution |
| `coding.routing.model_switch` | Model switching logic |
| `coding.routing.template_match` | Auto-detect context template |
| `coding.async.http_client` | AnyEvent-based HTTP client |
| `coding.async.http_chunk_handler` | Stream chunks to buffer |
| `coding.agent.coordinator` | Parent task coordination |
| `coding.agent.delegate` | Subtask delegation |

### Data Structures

```perl
# Task state persistence (for resume after defer)
<coding.async.task_state>->{$task_id} = {
    messages         => \@messages,
    tool_round       => $tool_round,
    response_text    => $response_text,
    context_snapshot => $compacted_context,
    callback_watcher => $watcher_ref,  # For cancellation
};

# GPU batch state
<coding.gpu.batch_state> = {
    tasks         => [@task_ids],
    combined_msgs => \@batched_messages,
    start_time    => $time,
    watcher       => $timeout_watcher,
};

# HTTP streaming state
<coding.async.http_state>->{$task_id} = {
    handle          => $ae_http_handle,    # AnyEvent handle
    buffer          => '',                  # Partial content buffer
    last_chunk_time => $time,               # For timeout detection
    bytes_received  => 0,
    content_length  => $expected_len,       # From header
    stop_requested  => FALSE,               # Check mid-stream
};

# Task hierarchy (parent/subtasks)
<coding.task.hierarchy>->{$parent_task_id} = {
    subtasks   => [@subtask_ids],
    agent_type => 'coordinator',
    context_share => TRUE,                  # Subtasks see parent context
};

<coding.task.parent>->{$subtask_id} = $parent_task_id;

# Logical dependencies
<coding.task.logical_deps>->{$task_id} = {
    task_deps  => [@prerequisite_task_ids],
    file_deps  => [@required_file_paths],
    custom_deps=> [{ type => 'test_pass', params => {} }],
};

# Model pinning (also for context templates)
<coding.task.model_pin>->{$task_id} = {
    model_id      => 'YZX4A3B:XXXXXXX',
    backend       => 'gpu',
    switch_policy => 'immediate',  # 'immediate', 'batch_end', 'lazy'
};

# Context template model binding
<context.template.model> = {
    'code-review' => {
        model       => 'YZX4A3B:CODE',
        description => 'Code review optimized model',
    },
    'creative-writing' => {
        model       => 'YZX4A3B:CREATIVE',
        temperature => 0.9,
    },
    'architecture-design' => {
        model       => 'YZX4A3B:REASONING',
        context_mul => 2.0,  # 2x context window
    },
};

# Auto-detect template from task description
<[coding.routing.template_match]>->($task_desc) {
    # Returns template name based on keywords/patterns
}

# Model switch queue
<coding.model.switch_queue> = [
    { model_id => 'A', tasks => [@task_ids] },
    { model_id => 'B', tasks => [@task_ids] },
];
<coding.model.current> = 'A';
<coding.model.switch_in_progress> = FALSE;
```

### Migration Strategy

#### Phase 1: Foundation (Week 1-2)
1. Keep existing blocking path as fallback
2. Implement deferred reply mechanism
3. Add `async => 1` flag to task enqueue
4. Test with single task, single model

#### Phase 2: Async HTTP (Week 3-4)
1. Implement streaming HTTP client
2. Real-time buffer updates
3. Mid-inference stop support
4. Test stop-task during inference

#### Phase 3: Model Switching (Week 5-6)
1. Implement `coding.routing.model_switch`
2. Queue-based model switching
3. Context template model hints
4. Test task with different models

#### Phase 4: Task Hierarchy (Week 7-8)
1. Parent/subtask data structures
2. Delegation mechanism
3. Context sharing
4. Test parent with 2-3 subtasks

#### Phase 5: Logical Dependencies (Week 9-10)
1. Dependency graph resolution
2. File-based dependencies
3. Task-to-task dependencies
4. Test chained tasks

#### Phase 6: Full Multiplexing (Week 11-12)
1. GPU batching
2. Multiple concurrent tasks
3. Resource limits enforcement
4. Performance benchmarking

#### Phase 7: Cleanup (Week 13)
1. Remove blocking path
2. Documentation
3. Integration tests
4. Production deploy

**Fallback at any phase**: Revert to blocking path via config flag.

### Risks & Mitigations

| Risk | Mitigation |
|------|------------|
| Event loop complexity | Extensive testing, fallback mode |
| VRAM exhaustion | Conservative batch limits, monitoring |
| Task starvation | Priority queues, preemption |
| State corruption | Checkpoints, idempotent operations |

## Next Steps

1. Review this architecture with user
2. Implement Phase 1 (deferred reply foundation)
3. Test single-task async flow
4. Implement Phase 2 (non-blocking HTTP)
5. Benchmark vs blocking implementation

#,,,.,,,,,.,,,.,,,,,,,,..,..,,,..,...,,.,,..,,..,,...,...,...,.,.,,.,,,.,,...,
#WUTEVDKI5HG4J2NIA324UYPZMYCRKLX5PVZCMEBY4HO566MSWAQ42BTMGTRRH4MBU4ZN7CELI6W3G
#\\\|RKJDLNXDV4OZ7CN6YKH2PFWEVOORESUWQ6PCY2DPCA2BETXDI6W \ / AMOS7 \ YOURUM ::
#\[7]HD3WM4M3B7DHTVROUNFJNVSZ5VXRY6Z2QIQ5JSEIFPLX6LR7CCBQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
