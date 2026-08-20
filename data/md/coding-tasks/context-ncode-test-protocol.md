# Context and Ncode Zenki - Integration Test Protocol

## Overview

This document provides a test protocol for verifying the context zenka (context management layer) and ncode module (self-refining regex transformation engine) functionality.

## Prerequisites

- Protocol-7 system running with cube zenka online
- `PROTOCOL_7_UNIX_PATH` environment variable set to the cube socket path
- Context zenka running (see step 1 for startup)

## Step 1: Zenka Lifecycle

### 1.1 Verify Context Zenka Status

```bash
export PROTOCOL_7_UNIX_PATH=/var/run/.7/UNIX/NIW7OAQ
p7c v7.list zenki | grep context
```

**Expected:** Context zenka shown as `online`

**If not running:**
```bash
p7c v7.start context
```

### 1.2 List Available Commands

```bash
p7c context.commands
```

**Expected:** List of commands including:
- Standard zenka commands (heart, name, commands, etc.)
- Context-specific commands (ai-review-*, channels-since, etc.)
- Ncode commands (transform, tool_list)
- Review commands (review)

### 1.3 Verify No Compile Errors

```bash
p7c "context.show-buffer compile-errors"
```

**Expected:** `no such buffer` or empty buffer

**Current Status:** Warnings present in:
- `ncode.regex.assess` - precedence issues with control flow operators
- `ncode.cmd.tool_list` - variable masking warning
- `ncode.cmd.transform` - variable masking warning
- `context.cmd.review` - variable masking warning

These are non-fatal warnings but should be cleaned up.

## Step 2: Ncode Pattern Loading

### 2.1 Verify Pattern Data Key

After init, the `ncode.patterns` data key should be populated:

```bash
# Patterns loaded from data/yaml/ncode-patterns/*.yaml
# Check with tool_list command
```

### 2.2 Test Tool List Command

```bash
p7c context.tool_list
```

**Expected:** JSON structure with 5 tools defined:
1. `transform` - apply refinement waves to code
2. `regex.list` - show current patterns with stats
3. `regex.test` - test a pattern against sample input
4. `regex.suggest` - ask model to propose new patterns from diff
5. `coverage.report` - show style rule regex coverage

**Current Issue:** Returns `HASH(0x...)` - output formatting needs fixing.

## Step 3: Ncode Transform (Regex-Only)

### 3.1 Scan Mode

```bash
# Send code snippet with known style issues
code_snippet='sub test { my $_ = shift; return 1; }'
p7c context.transform "mode=scan" "input=$code_snippet"
```

**Expected:** List of flagged items including:
- `dollar-underscore-to-arg` - suggest `$ARG` instead of `$_`
- `return-one-to-true` - suggest `return TRUE` instead of `return 1`

**Current Issue:** Arguments not parsed correctly. Module expects `$call->{'param'}` but p7c sends `$call->{'args'}`.

### 3.2 Apply Mode

```bash
p7c context.transform "mode=apply" "input=$code_snippet"
```

**Expected:** Transformed code with `$ARG` instead of `$_` and `return TRUE` instead of `return 1`.

**Note:** The ncode.cmd.transform module needs to be updated to also check `$call->{'args'}` for compatibility with p7c command routing.

## Step 4: Context Review Pipeline

### 4.1 Review Plan Creation

```bash
p7c context.review "context.*"
```

**Expected:** Creates review plan and returns plan summary with:
- Number of files matched
- Number of pages
- Result directory path

**Current Issue:** Returns `no files matched`. The glob pattern resolution may have issues with the working directory.

### 4.2 Review with LLM

```bash
p7c context.review "pattern" "type" "llm_cmd=kimi.ask-reply"
```

**Expected:** Deferred mode returned, async dispatch to kimi zenka.

### 4.3 Verify Result Directory

```bash
ls data/review/style/
```

**Expected:** Contains:
- `SUMMARY.md` - overview of findings
- Per-module `.review.md` files

## Step 5: Inter-Zenka Routing

### 5.1 Route via Cube

Test that other zenki can route commands to context:

```bash
# From any zenka, test routing
p7c context.heart
p7c context.commands
```

**Expected:** Commands execute successfully.

### 5.2 Context Routes to Others

Test context routing commands to other zenki (via delegate):

```bash
# This happens internally via context.delegate.dispatch
# routing to kimi.ask-reply, task.*, etc.
```

## Known Limitations

1. **ncode has no dedicated zenka config** - loads inside context zenka
2. **gen-sub-whitelist ncode fails** - expected, not a standalone zenka
3. **base.memory-sync.* modules** - don't exist (fallback to local works)
4. **Command argument parsing** - ncode.cmd.* modules need to check both `param` and `args`
5. **tool_list output format** - returns hash reference instead of formatted output
6. **review file globbing** - may have working directory issues

## Automated Test Ideas (Future)

1. **Timer-based test runner** in context zenka
   - Periodic self-tests
   - Health check commands

2. **Pattern round-trip test**
   - Load → Apply → Assess → Expand → Save → Reload → Verify

3. **Review pipeline dry-run**
   - Mock LLM responses
   - Verify result structure without actual AI calls

4. **Dependency graph validation**
   - Test `context.module.dep_graph` with known module sets
   - Verify topological ordering

5. **Channel pub/sub test**
   - Subscribe to context channels
   - Verify data updates propagate correctly

## Test Checklist Summary

| Test | Status | Notes |
|------|--------|-------|
| v7.start context | ✅ | Working |
| context.heart | ✅ | Working |
| context.commands | ✅ | Working |
| context.tool_list | ⚠️ | Returns hashref, needs formatting |
| context.transform | ⚠️ | Arg parsing issue |
| context.review | ⚠️ | File globbing issue |
| show-buffer compile-errors | ✅ | No fatal errors |
| Inter-zenka routing | ✅ | Working |

## Fixes Required

1. **ncode.cmd.tool_list** - Fix output formatting to return proper string
2. **ncode.cmd.transform** - Add `$call->{'args'}` fallback for input
3. **context.cmd.review** - Add `$call->{'args'}` fallback for pattern
4. **ncode.regex.assess** - Fix precedence warnings
5. **All cmd modules** - Fix variable masking warnings

## Cube Access Configuration

Ensure `cfg/zenki/cube/access.zenki` contains:

```
access.cmd.usr.context = * *.*
```

This allows other zenki to route commands to the context zenka.

#,,,.,,,.,,,.,..,,,.,,,,,,...,.,,,,,.,..,,,,.,..,,...,...,.,.,,..,,.,,.,,,,,.,
#WKULBCCBB2NGCLXOCN2PRH4B7ZQDPJQL5634M7OHQCWU5EUBGCG43CUBHH5O5GKBAYXT4KKGFSUT4
#\\\|ETJYFZPHGLADL3D2XFWVX5TKDOPYFX7AQAZW56ZZ5LIDRARUIKE \ / AMOS7 \ YOURUM ::
#\[7]ELDHJQYFJ5FBK4TMKIRZYLJ73LYPRB6VVPTNUGSI6GT54BWNCUAA 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
