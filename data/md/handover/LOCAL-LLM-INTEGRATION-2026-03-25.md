# Local LLM Integration — Path to Coding Participation

> *Making 'coding' and friends actually useful for review and development*

## The Goal

Enable local LLM zenkas (like `coding`) to:
- **Review code** with meaningful feedback
- **Suggest edits** that can be applied
- **Explain modules** to other agents
- **Answer questions** about the codebase
- **Participate in delegation** workflows

## Current State

Local LLMs are running but limited:
- ✅ Can receive prompts via existing channels
- ✅ Can generate text responses
- ❌ No structured output format
- ❌ No tool use / function calling
- ❌ No codebase awareness / RAG
- ❌ No edit application mechanism
- ❌ No verification of changes

## Architecture Layers (From Surface to Core)

```
┌─────────────────────────────────────────────────────────────┐
│ Layer 5: Agent Participation                                  │
│   - Join delegation workflows                                 │
│   - Claim tasks from priority queue                           │
│   - Report results back to context zenka                      │
├─────────────────────────────────────────────────────────────┤
│ Layer 4: Edit Application                                     │
│   - Parse suggested edits from LLM output                     │
│   - Apply with validation                                     │
│   - Rollback on failure                                       │
├─────────────────────────────────────────────────────────────┤
│ Layer 3: Structured I/O                                       │
│   - JSON schema for responses                                 │
│   - Function calling interface                                │
│   - Tool definitions (read, grep, edit, test)                 │
├─────────────────────────────────────────────────────────────┤
│ Layer 2: Codebase Awareness                                   │
│   - Module index / vector search                              │
│   - Dependency graph knowledge                                │
│   - Recent changes tracking                                   │
├─────────────────────────────────────────────────────────────┤
│ Layer 1: Prompt Engineering                                   │
│   - System prompts with P7 context                            │
│   - Few-shot examples                                         │
│   - Output format constraints                                 │
└─────────────────────────────────────────────────────────────┘
```

## Self-Contained Quick Wins

These can work with minimal integration:

### 1. Module Explainer (Layer 1 + partial 2)

**What**: Local LLM reads a module and explains it.

**Implementation**:
```perl
# src/local-llm.explain-module
return sub {
    my ($module_name) = @_;

    # Read module content
    my $content = <[file.slurp]>->("src/$module_name")->$*;

    # Build prompt with P7 context
    my $prompt = _build_explain_prompt($module_name, $content);

    # Send to local LLM
    my $response = <[local-llm.send]>->({
        'zenka'   => 'coding',
        'prompt'  => $prompt,
        'timeout' => 30,
    });

    return $response;
};

sub _build_explain_prompt {
    my ($name, $content) = @_;
    return <<"PROMPT";
You are a Protocol-7 code reviewer. Explain this module:

Module: $name

```perl
$content
```

Provide:
1. One-line summary
2. Key subroutines and their purpose
3. Dependencies (what it calls)
4. Potential issues or improvements
PROMPT
}
```

**Why it works**: Single input, single output, no state management.

### 2. Simple Pattern Review (Layer 1)

**What**: Check for common P7 style violations.

**Patterns to check**:
- `qw|...|` vs `qw(...)` — should be pipes
- `$_` usage — should be `$ARG`
- AMOS signature stubs — should be clean
- `//` regex — should be `m||` or `m{}`

**Implementation**:
```perl
# src/local-llm.review-patterns
my @PATTERNS = (
    { 'name' => 'qw style', 'regex' => qr/qw\(/, 'fix' => 'use qw|...|' },
    { 'name' => 'dollar underscore', 'regex' => qr/\$_\b/, 'fix' => 'use \$ARG' },
    # ... etc
);

return sub {
    my ($file_path) = @_;
    my $content = <[file.slurp]>->($file_path)->$*;

    # Local regex pre-filter
    my @suspect_lines;
    for my $pattern (@PATTERNS) {
        while ($content =~ /$pattern->{regex}/g) {
            push @suspect_lines, {
                'line'    => _line_number($content, pos($content)),
                'pattern' => $pattern->{'name'},
                'fix'     => $pattern->{'fix'},
            };
        }
    }

    # If uncertain, ask local LLM
    if (@suspect_lines > 0 && @suspect_lines < 20) {
        return _llm_verify_issues($file_path, $content, \@suspect_lines);
    }

    return { 'issues' => \@suspect_lines };
};
```

### 3. Test Generator (Layer 1)

**What**: Generate test stubs for modules.

**Prompt template**:
```
Given this Protocol-7 module, generate test cases:

```perl
{module_content}
```

Output format:
TEST: <test_name>
INPUT: <input_data>
EXPECTED: <expected_output>
```

**Parse response** and create `src/test.{module_name}`.

### 4. Documentation Sync Checker (Layer 2)

**What**: Check if HANDOVER.md matches actual module list.

**Implementation**:
```perl
# Compare data{'files'}{modules} vs HANDOVER.md module lists
# Report discrepancies
# Local LLM can suggest which is correct
```

## Medium Integration (Requires Layer 3)

### 5. Tool-Using Reviewer

**Structured function calling**:
```json
{
  "tools": [
    {
      "name": "read_file",
      "description": "Read a file's content",
      "parameters": {
        "path": {"type": "string"}
      }
    },
    {
      "name": "grep_codebase",
      "description": "Search for pattern",
      "parameters": {
        "pattern": {"type": "string"},
        "path": {"type": "string"}
      }
    },
    {
      "name": "suggest_edit",
      "description": "Propose an edit",
      "parameters": {
        "file": {"type": "string"},
        "old_string": {"type": "string"},
        "new_string": {"type": "string"}
      }
    }
  ]
}
```

**Loop**:
1. Send prompt + available tools
2. LLM responds with tool call
3. Execute tool, return result
4. Repeat until "done"

**Challenge**: Local LLMs may not support native function calling. Need prompt-based simulation:

```
If you want to read a file, output:
TOOL_CALL: read_file
PARAMS: {"path": "src/pager.init-code"}

You will receive the result and can continue.
```

### 6. Dependency-Aware Review

**Prerequisites**: `context.module.dep_graph`

**Flow**:
1. Module A is modified
2. Find all modules that depend on A (reverse deps)
3. Local LLM reviews impact on each dependent
4. Report breaking changes

## Deep Integration (Layers 4-5)

### 7. Edit Application System

**The hard part**: LLMs are bad at exact string matching.

**Strategy A: Line-based**
```json
{
  "edit_type": "replace_lines",
  "file": "src/foo",
  "start_line": 42,
  "end_line": 45,
  "new_content": "..."
}
```

**Strategy B: Diff-based**
```
--- old
+++ new
@@ -42,5 +42,5 @@
- old line
+ new line
```

**Strategy C: Checksum-based** (P7-native)
```json
{
  "replace_checksum": "bmw-L13:ABC123...",
  "with_checksum": "bmw-L13:DEF456..."
}
```

**Validation**:
- Parse edit
- Verify old content matches
- Apply to temp file
- Run syntax check (perl -c)
- Run tests
- Commit or rollback

### 8. Delegation Participant

**Join the context zenka delegation flow**:

```perl
# src/local-llm.delegate-handler

# Register as available executor
$data{'local-llm'}{'capabilities'} = {
    'coding' => {
        'can_review'     => 1,
        'can_explain'    => 1,
        'can_test_gen'   => 1,
        'max_tokens'     => 8192,
        'preferred_tasks'=> ['review', 'explain'],
    },
};

# Listen for delegation requests
return sub {
    my ($task) = @_;

    return 0 unless $task->{'type'} =~ /review|explain/;
    return 0 unless $task->{'est_tokens'} < 8192;

    # Claim task
    my $result = _process_task($task);

    # Return in context format
    return {
        'mode' => 'true',
        'data' => $result,
    };
};
```

## Practical Implementation Roadmap

### Phase 1: Read-Only Participation (This Week)

1. **Module explainer** — `local-llm.explain-module`
2. **Pattern reviewer** — `local-llm.review-patterns`
3. **Doc sync checker** — `local-llm.check-handover`

**All are**: Single input, single output, no side effects, safe to experiment.

### Phase 2: Structured Output (Next)

1. **JSON response parser** — `local-llm.parse-response`
2. **Tool call simulator** — `local-llm.tool-loop`
3. **Dependency reviewer** — `local-llm.review-impact`

### Phase 3: Edit Application (Later)

1. **Edit validator** — `local-llm.validate-edit`
2. **Temp file runner** — `local-llm.dry-run`
3. **Safe applier** — `local-llm.apply-edit`

### Phase 4: Full Participation (Future)

1. **Delegation registration** — hook into `context.delegate.*`
2. **Priority queue awareness** — read from `models.task.*`
3. **Self-improvement loop** — feedback on review quality

## Technical Requirements for Local LLMs

### Model Capabilities Needed

| Feature | Minimum | Preferred |
|---------|---------|-----------|
| Context window | 8K | 32K+ |
| Code understanding | Basic | Can trace dependencies |
| JSON following | Sometimes | Reliable |
| Instruction following | Moderate | High |
| Speed | 10 tok/s | 50+ tok/s |

### Infrastructure Needed

1. **Fast model loading** — keep `coding` warm
2. **Prompt caching** — reuse system prompts
3. **Response streaming** — for long reviews
4. **Timeout handling** — kill hanging requests
5. **Resource limits** — prevent OOM

### Integration Points

```
┌─────────────────────────────────────────┐
│ Existing: context.delegate.*              │
│   ↓                                      │
├─────────────────────────────────────────┤
│ New: local-llm.delegate-bridge           │
│   - Check local LLM availability         │
│   - Route appropriate tasks              │
│   ↓                                      │
├─────────────────────────────────────────┤
│ New: local-llm.api.client                │
│   - HTTP/Unix socket to llama.cpp        │
│   - Handle streaming                     │
│   - Retry logic                          │
│   ↓                                      │
├─────────────────────────────────────────┤
│ Existing: llama.cpp / ollama             │
│   - Actually runs the model              │
└─────────────────────────────────────────┘
```

## Early Functionality Demo Ideas

### Demo 1: "Explain This"
```bash
# User asks
explain-module pager.filter.division-13-harmonic

# System does
1. Read module content
2. Send to local LLM with prompt
3. Return formatted explanation
```

### Demo 2: "Quick Review"
```bash
# User asks
quick-review src/pager.init-code

# System does
1. Regex pre-filter for common issues
2. Send to local LLM with context
3. Return: [PASS] or list of issues
```

### Demo 3: "Find Similar"
```bash
# User asks
find-similar src/pager.buffer.virtual

# System does
1. Extract keywords/signatures
2. Query module index
3. Ask local LLM: "Which of these are conceptually similar?"
4. Return ranked list
```

## Risks and Mitigations

| Risk | Mitigation |
|------|-----------|
| Hallucinated edits | Require checksum validation |
| Slow responses | Async processing, timeouts |
| Wrong context | Include P7 style guide in prompt |
| Token overflow | Chunking, summarization |
| Inconsistent output | Structured JSON schemas |
| Resource exhaustion | Queue limits, priority system |

## What You Can Do Now (2% Tokens)

With remaining tokens, implement **Phase 1**:

1. `local-llm.explain-module` — 3 modules, simple I/O
2. `local-llm.review-patterns` — regex + LLM verification
3. `command.local-llm` — CLI interface

These work standalone and prove the concept.

## For Claude

When you review this, consider:

1. **Which phase makes sense first?** I lean toward Phase 1 (read-only)
2. **Is tool-calling worth it?** Or stick to structured JSON?
3. **How to integrate with existing delegation?** Hook into `models.task.delegate_bridge`?
4. **What P7-specific context do local LLMs need?** I started a list in the prompt examples.

The goal isn't to replace kimi/claude — it's to have `coding` handle the 80% of reviews that are pattern-based, freeing up cloud tokens for complex architectural work.

---

*Local models are getting good enough. Let's make them useful. — Kimi*

#,,,.,...,,.,,,,,,,,.,...,.,.,,.,,,..,,..,,,.,..,,...,...,.,.,,..,...,...,.,.,
#2QEC6S5HDLOZP7T6SLFY3VYGLR65GH6XX7OWUA473ZQCULUM363WTTKUA4PPBL2WKCF2KKDQLAXDO
#\\\|5YUUUG4RD2BPURASD6CNXZEFJTWMA6JF5UHJNVXJVX3FAY4CAZ4 \ / AMOS7 \ YOURUM ::
#\[7]U7NXKCHQB4OF7EE6BEU63LKEUSPA5SMMU3ZBTCPPDFWNUK4J5YAI 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
