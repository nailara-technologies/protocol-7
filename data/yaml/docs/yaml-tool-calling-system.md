# YAML-Based Tool Calling System

**Alternative to MCP with Native Protocol-7 Integration**

## Problem Statement

MCP (Model Context Protocol) is powerful but has limitations:
- Complex JSON schemas cause model confusion and errors
- Ambiguities in tool definition and calling conventions
- Not all models handle MCP equally well
- Requires abstraction layer between model and actual network

**Solution:** Use YAML for tool definition and calling - simpler for models, native to Protocol-7.

## Architecture Overview

```
┌─────────────────────────────────────────────────────────┐
│ Model in Conversation Context                            │
│ (sees full conversation history via <[CTX:turn_N]>)      │
└──────────────┬──────────────────────────────────────────┘
               │ Generates YAML tool call
               ↓
┌─────────────────────────────────────────────────────────┐
│ Tool Call Validation Module                              │
│ - Parse YAML syntax                                      │
│ - Validate against tool schema                           │
│ - Extract tool name and parameters                       │
└──────────────┬──────────────────────────────────────────┘
               │ Validated tool call
               ↓
┌─────────────────────────────────────────────────────────┐
│ Protocol-7 Network Router                                │
│ - Route to appropriate zenka via p7 command              │
│ - Execute with full parameter passing                    │
│ - Handle async/deferred responses                        │
└──────────────┬──────────────────────────────────────────┘
               │ Command execution
               ↓
┌─────────────────────────────────────────────────────────┐
│ Zenka Network (Full Protocol-7 Access)                   │
│ - Any zenka can be called                                │
│ - Any command with any parameters                        │
│ - Async or sync operations                               │
└──────────────┬──────────────────────────────────────────┘
               │ Result/Response
               ↓
┌─────────────────────────────────────────────────────────┐
│ Conversation System Integration                          │
│ - Store result in conversation                           │
│ - Add as new turn (role: system)                         │
│ - Include call_id for traceability                       │
└──────────────┬──────────────────────────────────────────┘
               │ Result available to model
               ↓
┌─────────────────────────────────────────────────────────┐
│ Model Next Turn                                          │
│ - Read previous tool call result via <[CTX:turn_N]>     │
│ - Continue reasoning with actual data                    │
│ - May generate new tool calls or final answer            │
└─────────────────────────────────────────────────────────┘
```

## YAML Tool Call Format

### Basic Structure

```yaml
tool_call:
  id: "call_<timestamp>_<random>"
  tool: "zenka.command.subcommand"
  parameters:
    param1: value1
    param2: value2
  metadata:
    context: "vision-extraction-stage-2"
    timeout: 30
    required: true
```

### Example: Vision Analysis

```yaml
tool_call:
  id: "call_vision_001"
  tool: "llama-server-vision.analyze_image"
  parameters:
    image_path: "/data/gfx/backgrounds/test.jpg"
    prompt: "Analyze and describe the contents as JSON"
  metadata:
    timeout: 60
    required: true
```

### Example: YAML Validation

```yaml
tool_call:
  id: "call_validate_001"
  tool: "coding.yaml-validator.validate_structure"
  parameters:
    yaml_content: "<{EXTRACTED_YAML}>"
    schema: "vision-extraction-output"
  metadata:
    timeout: 10
    required: true
```

### Example: Execute Any Protocol-7 Command

```yaml
tool_call:
  id: "call_models_001"
  tool: "models.conversation.get_context"
  parameters:
    job_id: "<{JOB_ID}>"
    depth: 5
  metadata:
    context: "retrieve-conversation-history"
    required: true
```

## Tool Schema Definition

Define tools in YAML for clarity and validation:

```yaml
tools:
  llama-server-vision.analyze_image:
    description: "Analyze image and return structured analysis"
    parameters:
      image_path:
        type: string
        description: "Path to image file"
        required: true
      prompt:
        type: string
        description: "Analysis prompt for vision model"
        required: true
    returns:
      type: string
      description: "Analysis result (usually JSON or text)"

  coding.yaml-validator.validate_structure:
    description: "Validate YAML syntax and structure"
    parameters:
      yaml_content:
        type: string
        description: "YAML content to validate"
        required: true
      schema:
        type: string
        description: "Schema name to validate against"
        required: false
    returns:
      type: object
      description: "Validation result: {valid: bool, errors: [...]}"

  models.conversation.get_context:
    description: "Retrieve conversation history"
    parameters:
      job_id:
        type: string
        required: true
      depth:
        type: integer
        description: "Last N turns to retrieve"
        required: false
    returns:
      type: object
      description: "Conversation context with turn history"
```

## Integration with Conversation System

### Tool Call in Conversation

```
Turn 1 (assistant): [vision analysis output]
Turn 2 (user): "Convert to YAML"
Turn 3 (assistant):
  <yaml tool call>
Turn 4 (system): [tool result - YAML output]
Turn 5 (assistant): "The YAML is valid, extracting..."
```

### Template References

Models can reference tool results via templates:

```
Previous tool result:
<[CTX:turn_4]>

Current status:
<[PREV:validation_result]>
```

## Implementation Steps

### Phase A: Tool Call Parser
- Parse YAML tool calls from model output
- Extract tool name, parameters, metadata
- Validate against schema definitions

### Phase B: Network Router
- Route tool name to Protocol-7 zenka.command
- Pass parameters cleanly
- Handle both sync and async responses

### Phase C: Result Integration
- Store results back in conversation
- Add as system turn with call_id reference
- Include metadata (execution time, status)

### Phase D: Model Prompt Engineering
- Teach models to generate YAML tool calls
- Provide examples in system prompts
- Show conversation history with tool results

### Phase E: Error Recovery
- Model sees YAML validation errors
- Can regenerate with corrected format
- Conversation shows full error trace

## Advantages Over MCP

| Aspect | MCP | YAML Tool Calling |
|--------|-----|-------------------|
| **Format Complexity** | Complex JSON schema | Simple YAML structure |
| **Model Compatibility** | Variable (model-dependent) | Excellent (all models know YAML) |
| **Network Access** | Limited to defined tools | Full Protocol-7 network access |
| **Error Visibility** | Hidden from model | Model sees validation errors in context |
| **Audit Trail** | Separate logging | Full conversation history |
| **Async Support** | Requires special handling | Native via conversation callbacks |
| **Debugging** | Tool call hidden | Visible in conversation with context |
| **Context Awareness** | Tools don't see previous attempts | Tool results in conversation for refinement |

## Example: Complete Vision Extraction Flow

```yaml
## TURN 1 - Vision Analysis (system initiates)
role: system
content: "Analyze this image"
tool_call_context: "vision-extraction-stage-1"

## TURN 2 - Vision Result (from llama-server-vision)
role: system
content: "[Raw vision output - JSON blob]"
source: "tool_call_vision_001"

## TURN 3 - Model Requests Conversion (assistant)
role: assistant
content: |
  I'll convert this to YAML format. Here's my tool call:

  tool_call:
    id: "call_yaml_convert_001"
    tool: "models.template.substitute"
    parameters:
      template: |
        Convert this to YAML:
        <{VISION_OUTPUT}>
      vars:
        VISION_OUTPUT: "<[CTX:turn_2]>"

## TURN 4 - Conversion Tool Result (system)
role: system
content: "[Converted YAML output]"
source: "tool_call_yaml_convert_001"
execution_time_ms: 150

## TURN 5 - Validation Request (assistant)
role: assistant
content: |
  Now I'll validate the YAML structure:

  tool_call:
    id: "call_validate_001"
    tool: "coding.yaml-validator.validate_structure"
    parameters:
      yaml_content: "<[CTX:turn_4]>"
      schema: "vision-extraction-output"

## TURN 6 - Validation Result (system)
role: system
content: |
  validation:
    valid: false
    errors:
      - "Missing required field: 'description'"
      - "Invalid data type for 'confidence': expected float"
source: "tool_call_validate_001"

## TURN 7 - Model Refines (assistant)
role: assistant
content: |
  I see validation errors. Let me refine the YAML:

  I need to:
  1. Add the missing 'description' field from <[CTX:turn_2]>
  2. Fix confidence as a float not string

  tool_call:
    id: "call_refine_001"
    tool: "models.template.substitute"
    parameters:
      template: |
        Fix this YAML: <{INVALID_YAML}>
        Add: description from original
        Fix confidence: must be float
      vars:
        INVALID_YAML: "<[CTX:turn_4]>"

## TURN 8 - Refined YAML (system)
role: system
content: "[Refined YAML]"
source: "tool_call_refine_001"

## TURN 9 - Revalidate (assistant)
role: assistant
content: |
  tool_call:
    id: "call_validate_002"
    tool: "coding.yaml-validator.validate_structure"
    parameters:
      yaml_content: "<[CTX:turn_8]>"

## TURN 10 - Success (system)
role: system
content: |
  validation:
    valid: true
    warnings: []
    parsed_fields: 12
    completeness: 100%
```

**Result:** Complete conversation history shows every step, every tool call, every error, and refinement. The model cooperated with validation until success.

## Why This Works Better Than Traditional Tool Calling

1. **Models Learn Better** - YAML is more natural language-like than JSON schemas
2. **Full Context** - Model sees what it requested and got back
3. **Error Recovery** - Model learns to fix format errors through conversation
4. **Transparency** - Complete audit of all decisions and tool calls
5. **Integration** - Leverages existing Protocol-7 infrastructure
6. **Flexibility** - Can call ANY zenka command, not just pre-defined tools

## Security Considerations

- Tool schema validates parameters before execution
- Only whitelisted zenka.commands allowed in production
- Conversation logged for audit trail
- Token budgets limit tool call loops

## Future Extensions

- **Tool Chaining** - Model generates multiple tool calls per turn
- **Parallel Execution** - Multiple tools called simultaneously
- **Conditional Logic** - `<{if}>` in templates for tool selection
- **Consensus** - Multiple models vote on tool call results
- **Cost Optimization** - Track token usage per tool call

#,,..,,,,,,,,,.,,,,,.,,.,,,,,,.,,,,.,,.,,,,..,..,,...,...,...,,,,,..,,,..,.,.,
#ISPHJICNGATZEFYGKTHFYZDDIP3MUDM4ZD7ON3JMBDNX7UXI6XJV7Q4GXHV365XJON5AUMY6C3A56
#\\\|TCDNHCJE5T4DKH4NRL2RASL2DIBFKWQY4PKOCRUK4KJQCA4LN3G \ / AMOS7 \ YOURUM ::
#\[7]C3E5OT6ECDUCEDIRFA3FYWLEACM7DUHL6X2FEWNSFICTXLREQGAA 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
