# Phase 4: YAML Tool Calling Implementation Plan

**Native tool execution alternative to MCP, integrated with conversation system**

## Overview

Phase 4 implements the bridge between models (generating YAML tool calls) and the Protocol-7 network (executing them). This is the key component that makes models truly interactive with the zenka ecosystem.

## Architecture

```
Model (in Conversation)
    ↓
Generates YAML: tool_call: { tool: "zenka.command", parameters: {...} }
    ↓
Tool Call Validator (YAML syntax + schema check)
    ↓
Network Router (p7 zenka.command execution)
    ↓
Zenka Network (executes and returns result)
    ↓
Result Handler (stores in conversation as new turn)
    ↓
Model (sees result in <[CTX:turn_N]>)
```

## Implementation Phases

### Phase 4A: Tool Call Parser & Validator

**Module:** `models.tool-call.parser`

**Input:** Model output containing YAML tool call block
**Output:** Parsed tool call or validation error

```yaml
tool_call:
  id: "call_001"
  tool: "llama-server-vision.analyze_image"
  parameters:
    image_path: "/path/to/image"
    prompt: "describe"
```

**Implementation:**

```perl
## models.tool-call.parser
my $model_output = shift;

## Extract YAML tool call block from output
if ( $model_output =~ /^tool_call:\n(.*?)^(?:$|[^\s])/ms ) {
    my $yaml_block = "tool_call:\n$1";

    ## Parse YAML
    my $tool_call = eval { JSON::PP->new->parse_yaml($yaml_block) };

    if ($@) {
        return {
            'success' => FALSE,
            'error'   => "Invalid YAML: $@"
        };
    }

    ## Validate required fields
    return {
        'success'   => FALSE,
        'error'     => 'Missing tool field'
    } unless $tool_call->{tool};

    return {
        'success'    => TRUE,
        'tool_call'  => $tool_call,
        'remainder'  => $remainder
    };
} else {
    return {
        'success' => FALSE,
        'error'   => 'No tool call found in output'
    };
}
```

**Tests:**
- Valid YAML parsing
- Invalid YAML error handling
- Missing required fields detection
- Extra text before/after tool call block

### Phase 4B: Tool Schema Registry

**Module:** `models.tool-schema`

**Purpose:** Define and validate tool definitions

**Schema Format:**

```yaml
tools:
  llama-server-vision.analyze_image:
    description: "Analyze image and return structured analysis"
    category: "vision"
    network_accessible: true
    parameters:
      image_path:
        type: string
        required: true
        description: "Path to image file"
      prompt:
        type: string
        required: true
        description: "Analysis prompt"
    returns:
      type: string
      description: "Analysis result"
    timeout_seconds: 60

  models.conversation.get_context:
    description: "Retrieve conversation history"
    category: "conversation"
    network_accessible: true
    parameters:
      job_id:
        type: string
        required: true
      depth:
        type: integer
        required: false
    returns:
      type: object
```

**Implementation:**

```perl
## models.tool-schema
my $params = shift;
my $cmd = $params->{cmd} // 'list';

if ( $cmd eq 'get' ) {
    my $tool_name = $params->{tool};
    return <models.tool_schemas>->{$tool_name} // {
        'error' => "Tool not found: $tool_name"
    };
} elsif ( $cmd eq 'validate' ) {
    my $tool_call = $params->{tool_call};
    my $schema = <models.tool_schemas>->{$tool_call->{tool}};

    unless ($schema) {
        return { 'error' => "No schema for: $tool_call->{tool}" };
    }

    ## Validate parameters against schema
    foreach my $param_name (keys %{$schema->{parameters}}) {
        my $param_def = $schema->{parameters}->{$param_name};
        if ( $param_def->{required}
             && !exists $tool_call->{parameters}->{$param_name} ) {
            return {
                'error' => "Missing required parameter: $param_name"
            };
        }
    }

    return { 'success' => TRUE };
} elsif ( $cmd eq 'list' ) {
    return {
        'tools' => [ keys %{<models.tool_schemas>} ]
    };
}
```

**Storage:** Load tool schemas from `data/yaml/tool-schemas.yaml` during init

### Phase 4C: Network Router

**Module:** `models.tool-router`

**Purpose:** Execute tool calls via Protocol-7 network

**Input:** Validated tool call
**Output:** Tool result or error

```perl
## models.tool-router
my $tool_call = shift;

my $tool_name = $tool_call->{tool};
my $parameters = $tool_call->{parameters};

## Map tool name to p7 command
my $command = $tool_name;  ## Direct mapping for now

## Execute via Protocol-7 network
my $result = <[base.protocol-7.command.send.local]>->(
    {   'command'   => $command,
        'call_args' => { 'param' => $parameters }
    }
);

if ($result) {
    return {
        'success' => TRUE,
        'result'  => $result,
        'tool_id' => $tool_call->{id},
        'tool'    => $tool_name
    };
} else {
    return {
        'success' => FALSE,
        'error'   => "Execution failed for $tool_name",
        'tool_id' => $tool_call->{id}
    };
}
```

**Features:**
- Direct p7 command execution
- Parameter passing
- Result capture
- Error handling
- Timeout management
- Async support (deferred callbacks)

### Phase 4D: Result Integration with Conversation

**Module:** `models.tool-result.handler`

**Purpose:** Store tool results back in conversation

```perl
## models.tool-result.handler
my $tool_call = shift;
my $result = shift;
my $job_id = shift;

## Add tool result as new turn in conversation
my $turn_result = <[models.conversation.add_turn]>->(
    {   'job_id'   => $job_id,
        'role'     => 'system',
        'content'  => sprintf(
            "Tool call %s result:\n%s",
            $tool_call->{id},
            $result
        ),
        'metadata' => {
            'tool_id'     => $tool_call->{id},
            'tool_name'   => $tool_call->{tool},
            'source'      => 'tool_call'
        }
    }
);

return $turn_result;
```

**Result in Conversation:**

```yaml
Turn N-1 (assistant):
  tool_call:
    id: "call_001"
    tool: "llama-server-vision.analyze_image"
    parameters: {...}

Turn N (system):
  source: tool_call_call_001
  result: "[vision analysis output]"
```

## Implementation Sequence

### Week 1: Parser & Schema
- [ ] `models.tool-call.parser` - Parse and validate YAML
- [ ] `models.tool-schema` - Define and manage tool schemas
- [ ] Tool schema file: `data/yaml/tool-schemas.yaml`
- [ ] Unit tests for parser and validator
- [ ] Test with sample tool calls

### Week 2: Router & Integration
- [ ] `models.tool-router` - Execute tool calls via p7
- [ ] `models.tool-result.handler` - Store results in conversation
- [ ] Error handling and timeout management
- [ ] Integration tests (parser → router → result)
- [ ] Test with actual zenka commands

### Week 3: Model Integration
- [ ] Update vision-parser to extract tool calls
- [ ] Handle multiple tool calls per turn
- [ ] Error recovery (model sees validation errors)
- [ ] Test complete vision → tool call → result flow
- [ ] Performance profiling

### Week 4: Polish & Documentation
- [ ] Comprehensive test suite
- [ ] Integration with existing conversation system
- [ ] Performance optimization
- [ ] Complete documentation
- [ ] Examples and patterns for model prompts

## Testing Strategy

### Unit Tests
```perl
## Test parser with valid YAML
## Test parser with invalid YAML
## Test schema validation
## Test router with different tool types
## Test result handler with conversation
```

### Integration Tests
```
Vision job
  → Generates tool call (parser)
  → Validates schema (validator)
  → Routes to zenka (router)
  → Captures result (handler)
  → Stores in conversation (add_turn)
  → Model sees result (get_context)
```

### End-to-End Test
```
Complete vision extraction flow:
  1. Vision analysis → tool result
  2. YAML translation → tool result
  3. Validation check → tool result
  4. Refinement (if needed) → tool result
  5. Final output in conversation
```

## Success Criteria

- [ ] Parser handles valid/invalid YAML correctly
- [ ] Schema validation prevents invalid tool calls
- [ ] Router executes p7 commands successfully
- [ ] Results stored in conversation as turns
- [ ] Model can reference results via `<[CTX:turn_N]>`
- [ ] Error messages visible to models for learning
- [ ] Async operations work with callbacks
- [ ] Token budget tracking per tool call
- [ ] Complete audit trail in conversation

## Example: Vision Extraction with Tool Calling

```
TURN 1 (system instruction with template):
  "Analyze this image: <{image_path}>"

MODEL TURN 2 (generates tool call):
  tool_call:
    id: "call_vision_001"
    tool: "llama-server-vision.analyze_image"
    parameters:
      image_path: "<{image_path}>"
      prompt: "Analyze and describe as JSON"

TURN 3 (system - tool result):
  source: tool_call_vision_001
  result: "[vision analysis JSON]"

MODEL TURN 4 (references result and requests conversion):
  I see the vision analysis. Now I'll convert it to YAML:

  tool_call:
    id: "call_convert_001"
    tool: "models.template.substitute"
    parameters:
      template: "Convert to YAML: <{VISION}>"
      vars:
        VISION: "<[CTX:turn_3]>"

TURN 5 (system - conversion result):
  source: tool_call_convert_001
  result: "[YAML output]"

MODEL TURN 6 (validates with tool call):
  tool_call:
    id: "call_validate_001"
    tool: "models.yaml-validator.validate"
    parameters:
      yaml_content: "<[CTX:turn_5]>"

TURN 7 (system - validation result):
  source: tool_call_validate_001
  result: "valid: true"

MODEL TURN 8 (final answer):
  The extraction is complete and valid.
```

Complete conversation shows:
- Every tool called
- Every parameter passed
- Every result returned
- Every error encountered
- Complete refinement process

## Metrics to Track

- Tool calls generated per job
- Success rate (valid/invalid calls)
- Router execution time
- Result storage time
- Tool timeout frequency
- Most-used tools
- Error categories

## Future Extensions

- **Tool Chaining:** Multiple tools per turn
- **Parallel Execution:** Run multiple tools simultaneously
- **Conditional Logic:** `<{if tool_success}> ... <{else}> ...`
- **Cost Tracking:** Token cost per tool call
- **Caching:** Cache tool results for repeated calls
- **Voting:** Multiple models call same tool, consensus on result

## Rollback Plan

- Keep parser/validator/router modular
- Can disable tool calling at conversation level
- Fall back to manual template processing
- Conversation system independent of tool calling

## Notes

- Tool calling is optional enhancement
- Vision extraction works without it (manual prompting)
- Incremental implementation possible
- Full benefits when models generate YAML well

#,,.,,...,,,.,,,,,,,,,,,,,.,,,.,,,,,,,.,.,.,,,..,,...,...,,..,.,.,..,,.,.,..,,
#DGDDO45BA7RAMHMNFKD77P6OOTZBFW5H7UIWHICT64A7SQYDJU4XB7VL3WXHB7WPP4WWPCXZXEIMU
#\\\|432YVELAKD5H6DMPO7MHGNSAJW4VE4UJWLLEPGOITUN2QHTJECT \ / AMOS7 \ YOURUM ::
#\[7]K2XDUONXZFZ4I242GBO6ZRIBLMQED7GHDHZQNNCGH7WW4JM2RMDI 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
