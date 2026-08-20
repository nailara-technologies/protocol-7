# Coding Zenka Complete-Analysis Feature

## Overview

The `coding.complete-analysis` command provides automatic resumption for code generation tasks that produce incomplete responses. It orchestrates a multi-turn workflow that continues generating code until natural completion is detected, without requiring user intervention.

## Architecture

### Core Components

1. **coding.cmd.complete-analysis** - Command entry point
   - Parses task description
   - Enqueues task for execution
   - Sets up meta-job tracking structure
   - Registers variable watcher for continuation detection
   - Returns deferred to allow async processing

2. **coding.handler.process-queued-task** - Task execution
   - Triggered by timer event after deferred reply
   - Dequeues pending task
   - Executes task via inference or routing
   - Calls task.complete when finished

3. **coding.task.complete** - Task completion handler
   - Updates task status to completed
   - Stores result in task execution fields
   - Moves task from pending to completed list
   - Triggers on-task-complete event

4. **coding.event.on_task_complete** - Completion event handler
   - Detects if response is complete or incomplete
   - Evaluates completion heuristics (punctuation, response length)
   - Sets continue_analysis flag if continuation needed
   - Triggers variable watcher for async continuation

5. **coding.handler.check-completion-chain** - Continuation handler
   - Variable watcher handler triggered by continue_analysis flag
   - Clears flag immediately
   - Checks if max resumes exceeded
   - If incomplete and resumptions available: spawns continuation task
   - Returns accumulated or final result

6. **coding.cmd.resume-analysis** - Manual resumption
   - Allows manual continuation of stalled analysis
   - Validates meta-job exists and has resumes remaining
   - Triggers continuation via variable watcher
   - Returns deferred while processing continues

## Workflow

```
User Command
    |
    v
complete-analysis parse & validate
    |
    v
Enqueue task for execution
    |
    v
Create meta-job tracking structure
    |
    v
Register variable watcher for continue_analysis flag
    |
    v
Return DEFERRED to client
    |
    +-- (async path, doesn't block client)
    |
    v
Timer event after 100ms delay
    |
    v
process-queued-task handler executes
    |
    v
Task runs via inference
    |
    v
task.complete marks finished
    |
    v
on-task-complete event handler
    |
    v
Evaluate completion
    |
    +--[COMPLETE]--> Return final result via reply_id
    |
    +--[INCOMPLETE & RESUMES AVAILABLE]
        |
        v
        Set continue_analysis = TRUE
        |
        v
        Variable watcher triggers immediately
        |
        v
        check-completion-chain handler spawns continuation task
        |
        v
        Continuation task passes previous output as context
        |
        v
        Task runs again...
```

## Completion Detection

The system uses conservative heuristics to detect response completion:

- **Ends with punctuation**: `.`, `!`, `?` at end of response
- **Very short response**: < 100 characters (likely complete)
- **Explicit termination**: User-provided end marker

If response doesn't meet completion criteria, and resume_count < max_resumes, the system automatically continues generation.

## Configuration

Via `cfg/zenki/coding/start`:

```perl
## Auto-resume limits
coding.complete_analysis.max_resumes = 5        # Maximum continuation attempts
coding.complete_analysis.timeout = 120          # Seconds before auto-timeout

## Completion detection
coding.complete_analysis.min_length = 100       # Minimum chars for short response
coding.complete_analysis.punctuation = [".","!","?"]  # Completion markers
```

## Usage Examples

### Basic Usage

```bash
# Start complete-analysis for code generation
p7c coding.complete-analysis "write a hello world function in Perl"

# Returns immediately with reply_id
# Command processes asynchronously
# Results sent back via deferred reply mechanism
```

### Manual Resumption

```bash
# If analysis stalls, manually trigger continuation
p7c coding.resume-analysis <meta_job_id>

# Shows available meta-jobs
p7c coding.list complete-analysis-jobs
```

### Monitoring Progress

```bash
# Check meta-job status
p7c coding.dump coding.complete_analysis_jobs

# View accumulated results
p7c coding.dump coding.complete_analysis_jobs.<meta_id>.accumulated
```

## API Response Format

### Deferred Reply (Immediate)

```perl
{
    'mode' => 'deferred'
}
```

### Final Result (Later via reply_id)

For single-line responses (no internal newlines):
```perl
{
    'mode' => 'true',
    'data' => 'single line response'
}
```

For multi-line responses:
```perl
{
    'mode' => 'size',
    'data' => "multi\nline\nresponse\n"
}
```

### Errors

```perl
{
    'mode' => 'false',
    'data' => 'error message describing what went wrong'
}
```

## Integration Points

### With Inference System

The complete-analysis system integrates with the coding zenka's inference backends:

- Routes to single-LLM for simple code generation
- Routes to consensus-voting for complex reasoning
- Uses appropriate timeout based on task complexity
- Falls back to CPU if GPU times out

### With Event System

Uses Protocol-7 event system for non-blocking operation:

- Timer events for deferred task execution (100ms delay)
- Variable watcher events for continuation detection
- Proper event cancellation on completion or timeout

### With Reply System

Integrates with Protocol-7's deferred reply mechanism:

- Stores reply_id in meta-job
- Sends results back to original client
- Handles client disconnection gracefully

## Limitations & Future Improvements

### Current Limitations

1. Inference execution currently simulated (not real LLM calls)
2. Response length detection is basic heuristic
3. No caching of intermediate results
4. Max resumes hardcoded to 5

### Planned Improvements

1. Real inference execution via HTTP to llama-server
2. More sophisticated completion detection (syntax, semantic completeness)
3. Result caching between resumes
4. Configurable completion strategies per task type
5. Learning from past completion patterns
6. Concurrent task execution queue

## Debugging

### Check buffer for execution flow

```bash
p7c coding.show-buffer zenka | grep "complete-analysis\|process-queued\|on-task-complete"
```

### Inspect meta-job details

```bash
p7c coding.dump coding.complete_analysis_jobs
```

### Monitor task queue status

```bash
p7c coding.status
```

### View task execution details

```bash
p7c coding.dump coding.task.queue.<task_id>
```

## Related Commands

- `coding.submit` - Single-turn task submission (without auto-resume)
- `coding.analyze_and_extract` - Vision-based analysis with auto-resume
- `coding.status` - Check queue and budget status
- `coding.resume-analysis` - Manually trigger continuation

## Implementation Files

- `src/coding.cmd.complete-analysis` - Command entry point
- `src/coding.handler.process-queued-task` - Task executor
- `src/coding.task.complete` - Completion marker
- `src/coding.event.on_task_complete` - Completion detector
- `src/coding.handler.check-completion-chain` - Continuation orchestrator
- `src/coding.cmd.resume-analysis` - Manual resumption
- `cfg/zenki/coding/start` - Configuration

## Current Status

### ✓ Implemented & Tested
- Event-driven continuation detection via variable watchers
- Meta-job tracking and state management
- Automatic task execution via timer events
- Completion event handler integration
- Multi-turn task resumption orchestration
- Deferred reply mechanism for async processing
- Clean parameter validation
- Comprehensive logging throughout workflow

### ✓ Inference Binary Built
- Built `llama-server-cuda-fa` with Flash Attention support via Docker
- Binary successfully loads quantized models without flash_attn errors
- Confirmed GPU acceleration working (model loaded to CUDA0: 4168.09 MiB)

### Current Configuration
- **Model**: Gemma 3 Glitter 4B (2.21 GB) - fast, good coherence, low memory
- **Binary**: llama-server-cuda-fa (with flash attention support)
- **GPU Acceleration**: Full offload (33 GPU layers) on RTX 3060
- **CPU Fallback**: Enabled with 8 threads

### ✓ System Ready
All infrastructure in place:
- Auto-resume mechanism (event-driven variable watchers)
- Inference server binary with flash attention
- Proper configuration for model loading
- Ready for real code generation testing and execution

---

**Created**: 2025-01-17
**Implementation**: Event-driven variable watcher approach (user-specified design)
**Architecture**: Async task execution with automatic continuation detection

#,,..,...,,,,,.,,,,,,,,.,,..,,,..,..,,..,,.,,,..,,...,...,...,,..,.,,,,.,,,,,,
#M2Q6XDO4DSMOUARU64UKXVPLRSEDSNUJDZ5OHQVYNCYZJRIZWJRY653MEIK73P33LEUKS6ZCAM6OC
#\\\|I2WCIARE772VWFWYNWJ6OU33HKYWPVXARHTOB3ER2NQ7IJVD2BK \ / AMOS7 \ YOURUM ::
#\[7]MD36KTDXKV4FAX2YEWV2OQSCVZ6WLUNPJ6FH6FRWGHAKN6IDYWCA 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
