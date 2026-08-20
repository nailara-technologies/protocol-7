# Implementation Plan: Two-Stage Vision→Text Extraction Pipeline

## Overview
Implement a state machine-based orchestrator that chains vision analysis with text extraction/structuring. Uses variable watchers on state transitions to trigger async handlers, eliminating callback complexity.

## Architecture Decision
- **Pattern**: State machine with variable watchers (like base.session.init)
- **State Variable**: `<coding.vision-parser.state>` - watches for state changes
- **Triggering**: Variable watcher fires handler when state updates
- **First Response**: Text/data only (v1), can add metadata/modes later

## Key Components to Create

### 1. New Zenka Module System: `coding.vision-parser.*`
Creates orchestration layer in coding zenka that bridges vision analysis with text extraction.

**Modules to create:**
- `coding.vision-parser.init_code` - Initialize state machine and variable watchers
- `coding.vision-parser.cmd.analyze_and_extract` - Main command entry point
- `coding.vision-parser.handler.state_transition` - Triggered by variable watcher on state changes
- `coding.vision-parser.helper.dispatch_next_stage` - Route based on current state

### 2. State Machine Definition
```
States:
  pending          → Starting state, ready to accept request
  analyzing        → Calling llama-server-vision.analyze_image
  analyzing_done   → Vision analysis complete, output available
  extracting       → Sending vision output to coding pipeline
  extracting_done  → Text extraction complete
  completed        → Final result ready for callback
  failed           → Error occurred, abort chain
```

### 3. Variable Watcher Setup (in init_code)
**Location**: `coding.vision-parser.init_code`

```perl
# Initialize state tracking
<coding.vision-parser.state> //= 'pending';
<coding.vision-parser.jobs> //= {};

# Register variable watcher on state variable
$watcher = <[event.add_var]>->(
    {
        'var'     => \<coding.vision-parser.state>,
        'poll'    => 'w',          # Watch for writes
        'handler' => 'coding.vision-parser.handler.state_transition',
        'repeat'  => TRUE,         # Keep watching
        'desc'    => 'Vision-parser state machine watcher'
    }
);
```

### 4. Main Command: analyze_and_extract
**Location**: `coding.vision-parser.cmd.analyze_and_extract`

**Parameters:**
- `image_path` - Path to image file
- `vision_prompt` - Optional custom prompt for vision model (default: "Analyze this image")
- `extraction_prompt` - Optional custom prompt for text extraction task

**Flow:**
1. Create job entry with `reply_id` saved for later callback
2. Store job state in `<coding.vision-parser.jobs>`
3. Set state to 'analyzing' (triggers variable watcher)
4. Return `{ 'mode' => 'deferred' }` immediately

**Key Data Structure:**
```perl
my $job = {
    'job_id'           => $job_id,
    'reply_id'         => $$call{'reply_id'},
    'image_path'       => $image_path,
    'vision_prompt'    => $vision_prompt,
    'extraction_prompt' => $extraction_prompt,
    'state'            => 'pending',
    'vision_result'    => undef,
    'extraction_result' => undef,
    'error'            => undef,
    'start_time'       => <[base.time]>->(3)
};
```

### 5. State Transition Handler
**Location**: `coding.vision-parser.handler.state_transition`

**Triggered on**: `<coding.vision-parser.state>` changes

**Logic:**
```perl
my $current_state = <coding.vision-parser.state>;

if ($current_state eq 'analyzing') {
    <[coding.vision-parser.helper.dispatch_next_stage]>->($job_id, 'analyzing');

} elsif ($current_state eq 'analyzing_done') {
    <[coding.vision-parser.helper.dispatch_next_stage]>->($job_id, 'extracting');

} elsif ($current_state eq 'extracting_done') {
    <[coding.vision-parser.helper.dispatch_next_stage]->($job_id, 'completed');

} elsif ($current_state eq 'completed') {
    # Send deferred response callback
    <[base.callback.cmd_reply]>->(
        $job->{'reply_id'},
        { 'mode' => 'size', 'data' => $job->{'extraction_result'} }
    );
}
```

### 6. Dispatch Helper: Stage Execution
**Location**: `coding.vision-parser.helper.dispatch_next_stage`

**Stage 1: analyzing**
- Call `llama-server-vision.analyze_image` with `vision_prompt`
- Register completion handler to detect result
- When result arrives, extract JSON, save to job, set state to 'analyzing_done'

**Stage 2: extracting**
- Format vision JSON as context for coding zenka
- Call `coding.cmd.submit` with:
  - Task type: 'text-extraction'
  - Prompt: user's `extraction_prompt` or generate default
  - Context: vision analysis JSON
- Register completion handler to detect result
- When result arrives, save to job, set state to 'extracting_done'

**Stage 3: completing**
- Format final response (text/data only for v1)
- Set state to 'completed' (triggers handler to send callback)

### 7. Completion Detection
**Challenge**: How to detect when async operations complete?

**Solution Options**:

**Option A: Direct callback from subcommands**
- Have llama-server-vision callback directly to vision-parser job
- Problem: Tight coupling, breaks modularity

**Option B: Polling timer per job**
- Register 0.5s timer for each job stage
- Poll for completion indicator (e.g., `job->{'vision_result'}` populated)
- Problem: Additional timers, polling overhead

**Option C: State-triggered reply from deferred commands**
- When llama-server-vision completes, instead of callback to user, callback to vision-parser
- vision-parser job updates, triggers state change
- State watcher fires handler
- Problem: Requires modifying vision zenka to support this routing

**Recommended: Option B (Polling) for v1**
- Simple, isolated, doesn't require changes to other zenki
- Low overhead (0.5s interval)
- Can refactor to callback chaining in v2

### 8. Integration Flow Diagram

```
User command: analyze_and_extract /image.png "analyze" "extract this"
                                    ↓
                        cmd.analyze_and_extract
                        - Save job, reply_id
                        - Set state='analyzing'
                        - Return deferred
                                    ↓
                    Variable watcher triggers (state write)
                                    ↓
                    handler.state_transition
                    - Check state='analyzing'
                    - Call helper.dispatch_next_stage
                                    ↓
                    STAGE 1: Vision Analysis
                    - Call llama-server-vision.analyze_image
                    - Register 0.5s polling timer
                    - Timer detects vision_result populated
                    - Update job['vision_result'] = JSON
                    - Set state='analyzing_done'
                                    ↓
                    Variable watcher triggers again
                                    ↓
                    handler.state_transition
                    - Check state='analyzing_done'
                    - Call helper.dispatch_next_stage
                                    ↓
                    STAGE 2: Text Extraction
                    - Format vision JSON as context
                    - Call coding.cmd.submit with context
                    - Register 0.5s polling timer
                    - Timer detects extraction_result populated
                    - Update job['extraction_result'] = text
                    - Set state='extracting_done'
                                    ↓
                    Variable watcher triggers again
                                    ↓
                    handler.state_transition
                    - Check state='extracting_done'
                    - Set state='completed'
                                    ↓
                    Variable watcher triggers one final time
                                    ↓
                    handler.state_transition
                    - Check state='completed'
                    - Call base.callback.cmd_reply with extraction_result
                                    ↓
                        Final response sent to user
```

## Implementation Steps

### Step 1: Initialize New Module System
- Create `coding.vision-parser.init_code`
- Initialize state machine infrastructure
- Register variable watcher
- Create jobs tracking hash

### Step 2: Create Main Command
- Create `coding.vision-parser.cmd.analyze_and_extract`
- Implement parameter parsing
- Implement job creation and storage
- Implement deferred response return

### Step 3: Create State Transition Handler
- Create `coding.vision-parser.handler.state_transition`
- Implement state checking logic
- Route to dispatch helper based on state

### Step 4: Create Dispatch Helper
- Create `coding.vision-parser.helper.dispatch_next_stage`
- Implement Stage 1: Vision analysis execution
- Implement Stage 2: Text extraction execution
- Implement polling timers for completion detection
- Implement result extraction and job update logic

### Step 5: Create Polling Timer Handlers
- Create `coding.vision-parser.handler.check_vision_completion`
- Create `coding.vision-parser.handler.check_extraction_completion`
- Implement result extraction from outputs
- Implement state transition triggers

### Step 6: Testing & Validation
- Test single image with both stages
- Verify state transitions occur correctly
- Verify variable watcher fires properly
- Verify final callback delivers correct response
- Test error handling (missing image, vision failure, extraction failure)

## Files to Create
```
modules/coding.vision-parser.init_code
modules/coding.vision-parser.cmd.analyze_and_extract
modules/coding.vision-parser.handler.state_transition
modules/coding.vision-parser.handler.check_vision_completion
modules/coding.vision-parser.handler.check_extraction_completion
modules/coding.vision-parser.helper.dispatch_next_stage
```

## Files to Potentially Modify
```
modules/coding.cmd.submit - May need to support optional routing back to vision-parser
cfg/zenki/coding/start - Load new vision-parser modules
```

## Success Criteria
- ✅ Command accepts image path and optional prompts
- ✅ Returns deferred immediately (non-blocking)
- ✅ State machine progresses through all stages
- ✅ Variable watchers trigger correctly on state changes
- ✅ Vision analysis completes and result captured
- ✅ Text extraction submitted to coding pipeline
- ✅ Final response delivered via callback with extracted text
- ✅ Error handling aborts chain gracefully
- ✅ No CPU spikes or blocking operations

## Future Enhancements (v2+)
- Add response metadata mode (vision_json + extracted_text + timing)
- Dynamic prompt templates for extraction
- Support multiple vision models via fallback
- Batch processing multiple images
- Caching of vision analysis results
- Direct callback chaining to avoid polling

#,,.,,,.,,,,,,,,,,,..,...,.,.,...,,..,.,,,...,..,,...,...,,,.,,..,,,,,.,.,,,.,
#BP2HBQOCG4DYTOJKHDK3SVA3K2BAN544KBGG6P3YMTZALET4QCX7YZG526CN52J5TV3T6HJSVWBCG
#\\\|DVND63PEHEXPXD3FU2YXO4MTKFY5LU5IFVANZYZKLJ2KG6BWFOG \ / AMOS7 \ YOURUM ::
#\[7]5FVL6KWABJVUUY2IF7WPDHVUN6Y6I6UOS5DOQS4EC4LINRMAT6AY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
