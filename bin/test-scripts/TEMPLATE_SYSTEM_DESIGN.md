# Unified Template & Conversation System Design

## Problem
Both httpd (HTML templates) and models zenka (conversation prompts) need:
- Variable substitution `[VAR]`
- Nested content injection `[COMPONENT]`
- Context management (history, compaction)
- Dynamic variable lookup
- Safe IPC transmission

## Existing Pattern (httpd)
Current HTML template syntax:
```html
[VARIABLE_NAME]       - Simple substitution
[TXT:key]            - Text lookup from namespace
[MAIN_CONTENT]       - Content/component injection
```

Mechanism:
- Template stored with base32r encoding for IPC safety
- Meta variables passed as JSON
- Recursive processing in separate zenka (web)
- Template caching via checksum

## Proposed Unified System

### 1. Template Syntax (HTML & Prompts)

```
[VARIABLE]           - Direct variable substitution
[NS:key]            - Namespace lookup (TXT:, META:, CONTEXT:, etc.)
[MODULE:arg]        - Execute module and inject result
[INCLUDE:path]      - Include another template file
{{EXPRESSION}}      - Conditional or computed expressions (future)
```

### 2. Namespace Types

**For HTML templates:**
- `[TXT:key]` - Localization/static text strings
- `[META:var]` - Session metadata
- `[DATA:key]` - Dynamic data from request/session

**For Prompts:**
- `[CTX:turn_N]` - Historical context turn N
- `[META:job_id]` - Job/conversation metadata
- `[PREV:field]` - Previous response field
- `[TEMPLATE:name]` - Sub-template/prompt fragment

### 3. Core Infrastructure

**Generic modules (models/template.*):**
```perl
models.template.substitute($template, $vars)
  - Simple variable replacement
  - Handles [VAR], [NS:key] syntax

models.template.process($template, $context, $depth)
  - Recursive processing
  - Handles [MODULE:arg], [INCLUDE:path]
  - Depth limit to prevent infinite recursion
  - Compacts old context if too large

models.template.cache_get($template_hash)
  - Get cached processed template

models.template.cache_set($template_hash, $result, $ttl)
  - Cache with TTL and context compaction
```

**Conversation-specific (models/conversation.*):**
```perl
models.conversation.create($job_id, $template_name)
  - Initialize conversation with template
  - Allocate history buffer (token-limited)

models.conversation.add_turn($job_id, $role, $content)
  - Append message to history
  - Auto-compact if over token limit

models.conversation.get_context($job_id, $depth, $compact_strategy)
  - Retrieve conversation context
  - Apply compaction (summarize, drop old turns, token-sample)

models.conversation.clear($job_id)
  - Free conversation memory
```

### 4. Compaction Strategies

When token budget exceeded:
- **drop_oldest**: Remove oldest turns beyond depth window
- **summarize**: Ask LLM to summarize turns 1-N into brief summary
- **extract_critical**: Keep only turns with errors/gaps
- **token_sample**: Keep first N, drop middle, keep last N

### 5. Vision Extraction Use Case

```
Conversation.create("vision_job_1", "vision_analysis")
├─ Template: "Analyze image and respond with JSON"
│  Variables: [IMAGE_PATH], [JSON_SCHEMA]
│
├─ Turn 1: Vision model
│   Input: "Analyze: [IMAGE_PATH], respond with: [JSON_SCHEMA]"
│   Output: (malformed JSON)
│
├─ Turn 2: Extraction LLM
│   Input: "Convert to YAML: [PREV:output]"
│   Output: (YAML)
│
├─ Turn 3: Validation
│   Check YAML structure
│   ├─ If valid: Done ✓
│   └─ If missing fields: Continue
│
├─ Turn 4: Vision clarification (context included)
│   Input: "Your output was: [CTX:turn_1]
│            Extracted: [CTX:turn_2]
│            Missing: [MISSING_FIELDS]
│            Please clarify..."
│   Output: (refined analysis)
│
└─ Loop until valid & complete
```

### 6. Memory/Compaction Example

```
Token budget: 4096
Initial context: [Turn 1: 512] + [Turn 2: 800] + [Turn 3: 400] + [Turn 4: 600]
Total: 2312 tokens

Turn 5 attempt: would be 2312 + 1000 = 3312 (OK, within budget)
Turn 6 attempt: would be 3312 + 1200 = 4512 (OVER!)

Action: Summarize turns 1-2 into 300 tokens
Result: [Summary: 300] + [Turn 3: 400] + [Turn 4: 600] + [Turn 5: 1000] + [Turn 6: 1200]
Total: 3500 (OK!)
```

### 7. Benefits

- **Unified**: Works for HTML templates AND conversation prompts
- **Modular**: Components can be tested independently
- **Reusable**: Prompts and HTML templates share infrastructure
- **Efficient**: Template caching, smart compaction
- **Safe**: Base32r encoding for IPC, depth limits, token budgets
- **Observable**: Detailed logging at each stage
- **Extensible**: Easy to add new namespaces, modules, strategies

## Implementation Phases

**Phase 1**: Core template substitution (`models.template.substitute`)
**Phase 2**: Conversation management (`models.conversation.*`)
**Phase 3**: Vision extraction integration with iterative retries
**Phase 4**: Optimize based on real usage patterns

## Current Time Investment

This design work ensures:
- No rework during vision-parser integration
- Both HTML and prompts benefit equally
- Conversation state properly managed
- Handles context explosion gracefully
- Models work with their own previous outputs

#,,,,,.,.,,.,,,,,,,,.,,.,,.,.,...,,.,,,.,,..,,..,,...,...,..,,,.,,.,,,.,.,...,
#OPCXUCX3YFPEESXNPSPD3CESAZQ2CXNQCELUNCUABZQ44T5A4A5WJAMZI5T66D6DJDP75BBD7ZTFK
#\\\|35EJHKLXV23LZ64KI33CT3XWQ2T3EXJB5TL526IRZMPAOWBZEL7 \ / AMOS7 \ YOURUM ::
#\[7]BV6ECKQUBKO27I4JDEEGCKMLCEQOIVPTFLYURGYIA3PEHK6OQOCI 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
