# Protocol-7 Template & Conversation Architecture

**Strategic Overview: Consensus Groups, Tool Calling, and Native Model Integration**

## Design Philosophy

Protocol-7's template + conversation system is designed as a **lightweight consensus framework** that naturally supports:

1. **Multi-turn Reasoning** - Models work through problems in conversation
2. **Structured Outcomes** - YAML validation enforces format compliance
3. **Tool Integration** - Native YAML-based tool calling (alternative to MCP)
4. **Full Network Access** - Seamless access to entire zenka ecosystem
5. **Audit Trails** - Complete conversation history for transparency
6. **Error Recovery** - Models see failures and refine automatically

## Three Interconnected Systems

### 1. Template System (Phase 1)
**Location:** `src/models.template.substitute`
**Purpose:** Variable substitution and context injection

Features:
- Simple `<{variable}>` syntax for variables
- Template-aware logging with session context
- Metrics tracking for performance monitoring
- Foundation for dynamic prompt construction

**Why It Matters:**
Templates are how models receive structured information. The `<{var}>` syntax is intentionally simple because models need to understand it.

### 2. Conversation System (Phase 2)
**Location:** `src/models.conversation.*`
**Purpose:** Multi-turn state management with token budgets

Features:
- Conversation registry maps job_id to conversation state
- Token budget enforcement prevents context explosion
- Turn history with role tracking (system/user/assistant)
- Compaction strategies for history management
- Metrics track active/completed conversations

**Why It Matters:**
Conversations are the "shared truth space" where all agents (models, validators, routers) see the same information. This enables consensus through context.

### 3. YAML Tool Calling (Phase 3+)
**Location:** (To be implemented) `src/models.tool-router.*`
**Purpose:** Native tool execution alternative to MCP

Features (Planned):
- Models generate YAML tool calls in conversation
- Calls validated against YAML schemas
- Full Protocol-7 network access (any zenka.command)
- Results stored back in conversation for context
- Complete audit trail built-in

**Why It Matters:**
YAML tool calling is how models interact with the system. It's more natural for models than MCP, integrates tightly with conversations, and provides full transparency.

## How They Work Together

### The Conversation Context Loop

```
Model sees full conversation history:
  Turn 1: System instruction (template with <{variables}>)
  Turn 2: Model's first attempt
  Turn 3: Validation error (from tool call result)
  Turn 4: Model's refinement
  Turn 5: Success (tool call validated)
  ↓
Model can reference any previous turn: <[CTX:turn_N]>
Model can reference previous tool output: <[PREV:field]>
  ↓
Model generates next tool call in YAML
  ↓
Tool router executes via Protocol-7
  ↓
Result added to conversation
  ↓
Loop continues until success or budget exceeded
```

### Vision Extraction Example

This is where all three systems shine together:

```
TURN 1 (system): "Analyze image using template <{vision_prompt}>"
  → Template substitution injects actual prompt

TURN 2 (tool: vision):
  Result of llama-server-vision.analyze_image

TURN 3 (assistant):
  Model sees TURN 2 via <[CTX:turn_2]>
  Generates YAML tool call to convert to YAML

TURN 4 (tool: conversion):
  Result of template processing on vision output

TURN 5 (assistant):
  Model sees both TURN 2 (original) and TURN 4 (conversion)
  Generates YAML tool call to validate

TURN 6 (tool: validation):
  Validation errors (if any) or success

TURN 7+ (assistant/tool):
  If errors, model refines and loops back
  If success, process complete

Full conversation = complete audit trail of reasoning
```

## Why This Is Better Than Traditional Approaches

### vs. MCP (Model Context Protocol)
- **Simpler Format:** YAML vs complex JSON schemas
- **Better Visibility:** Tool calls in conversation vs hidden logs
- **Tighter Integration:** Uses existing conversation state
- **Full Network:** Access any zenka, not just predefined tools
- **Error Recovery:** Model learns to fix format errors

### vs. Function Calling APIs
- **Context Aware:** Tool calls see full conversation history
- **Structured Output:** YAML validation ensures correctness
- **Consensus Ready:** Multiple models can review same calls
- **Async Native:** Callbacks integrated into conversation
- **Transparent:** Everything visible in conversation

### vs. Agent Frameworks
- **Lighter Weight:** No special framework, just conversation + templates
- **Native to Models:** Uses formats models naturally understand
- **Network Aware:** Direct access to protocol-7 ecosystem
- **Scalable:** Token budgets prevent runaway loops
- **Auditable:** Complete conversation history always available

## Roadmap: From Extraction to Consensus

### Phase 3 (Current): Vision Extraction Foundation
- Vision jobs create conversations
- Multi-turn extraction workflow
- YAML validation infrastructure in place

### Phase 4: Tool Calling Implementation
- YAML tool call parser and router
- Tool schema definitions
- Protocol-7 command execution
- Async callback integration

### Phase 5: Extraction LLM Integration
- Queue JSON→YAML translation service
- Model generates tool calls for conversion
- Validation feedback loop
- Auto-refinement until success

### Phase 6: Iterative Refinement
- Models use conversation context for self-correction
- Optional re-query vision model if fields missing
- Compaction strategies for long extractions
- Confidence scoring for each step

### Phase 7: Structured Debate (Proto-Consensus)
- Multiple models evaluate same output
- Tool calls for voting/scoring
- Arbitration when disagreement occurs
- Conversation shows all perspectives

### Phase 8: Full Consensus Groups
- Formal consensus protocols in conversation
- Weighted voting based on model expertise
- Structured evidence presentation
- Complete audit trail of agreement

## Key Insight: Conversation is the Commons

Think of the conversation as a **shared bulletin board**:
- Anyone (any zenka/LLM) can read it: `<[CTX:turn_N]>`
- Anyone can write to it: `add_turn(role, content)`
- Content is validated before acceptance: `validate_yaml`
- History is immutable: complete audit trail
- Space is bounded: token budgets prevent abuse

This is the foundation for consensus. No special consensus protocol needed - just let intelligent agents collaborate through the conversation with clear rules.

## Implementation Priority

1. **Done:**
   - [x] Template system with variable substitution
   - [x] Conversation management with token budgets
   - [x] Vision-parser integration
   - [x] Test suite for Phases 1-3

2. **Next:**
   - [ ] Tool call parser (YAML validation)
   - [ ] Network router (Protocol-7 command execution)
   - [ ] Tool schema definitions
   - [ ] Async result integration

3. **Future:**
   - [ ] Extraction LLM integration
   - [ ] YAML validation module
   - [ ] Iterative refinement workflow
   - [ ] Structured debate/voting
   - [ ] Full consensus protocols

## Architectural Principles

1. **Model-Native:** Use formats models naturally understand (YAML, simple syntax)
2. **Transparent:** Everything visible in conversation history
3. **Composable:** Each module does one thing well
4. **Network-Aware:** Full access to zenka ecosystem, no artificial limits
5. **Bounded:** Token budgets prevent resource exhaustion
6. **Auditable:** Complete trail of decisions, errors, refinements

## Why YAML for Everything?

- Models understand YAML better than JSON schemas
- YAML is more readable (models learn from examples)
- Validation is simpler (just syntax + structure)
- Natural for configuration and data representation
- Less ambiguity than complex JSON structures
- Easy for humans to debug when needed

This is why `template-markup-syntax.yaml` documents the whole system in YAML, and why tool calls will be YAML.

## Strategic Value

This architecture positions Protocol-7 as:
- **More Natural:** Uses YAML, not MCP complexity
- **More Transparent:** Full conversation history
- **More Powerful:** Complete zenka network access
- **More Trustworthy:** Auditability and consensus
- **More Flexible:** From simple extraction to consensus groups

All while being **simpler and lighter** than traditional AI agent frameworks.

#,,..,,,.,.,,,,,,,,.,,.,.,,,.,..,,,,,,...,.,,,..,,...,...,...,.,,,.,,,...,.,,,
#WYJNJUJHGJSOJ3I3HPMILLHTEEBT4BTASXOT7O5OBDCVMSVRIFXWLFGCIGEIB4ZFR6QQOTM3U4VZ4
#\\\|RB2KXOCEFUYC5L2W7E445H6UP6GQSWZDRHT7DLZKWIK4XLZVDNJ \ / AMOS7 \ YOURUM ::
#\[7]FMDZMTRC3VVKO4ZDZ667HGYISGSSCE2KNYZSDDOWLE7UAZNZTGDA 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
