# Testing Guide: Template & Conversation System

## Overview
This guide covers testing the unified template markup and conversation management system (Phases 1-3).

## System Components Being Tested

### Phase 1: Template Substitution
- `models.template.substitute` - Variable replacement with `<{variable}>` syntax
- Handles undefined variables gracefully
- Tracks metrics: substitutions, elapsed time

### Phase 2: Conversation Management
- `models.conversation.create` - Initialize conversations with token budgets
- `models.conversation.add_turn` - Add multi-turn messages
- `models.conversation.get_context` - Retrieve conversation history
- `models.conversation.compact` - Compress history with various strategies

### Phase 3: Vision-Parser Integration
- Vision jobs create conversations for multi-turn tracking
- Job states linked to conversation states
- Foundation for iterative extraction workflow

## Running Tests

### Option 1: Run All Tests
```bash
cd /data/projects/protocol-7
perl bin/test-scripts/run-all-tests.pl
```

### Option 2: Run Individual Tests
```bash
# Test conversation system
perl bin/test-scripts/test-conversation-system.pl

# Test template substitution
perl bin/test-scripts/test-template-substitution.pl

# Test vision-parser integration
perl bin/test-scripts/test-vision-conversation.pl
```

## Test Coverage

### test-conversation-system.pl
Tests the complete conversation lifecycle:
1. Create conversation with token budget
2. Add turn (message to conversation)
3. Retrieve context (full history)
4. List active conversations
5. Check metrics (active/completed counts)
6. Clear conversation (cleanup)

**Expected Results:**
- All create/add/get operations should succeed
- Metrics should track conversation count
- Clear should remove conversation from registry

### test-template-substitution.pl
Tests variable substitution in templates:
1. Simple substitution (replace `<{var}>` with value)
2. Undefined variable handling (preserve undefined vars)
3. Multiple occurrences (same variable used multiple times)
4. Metrics tracking (substitution counts)
5. Empty template validation (error handling)

**Expected Results:**
- Variables substituted correctly
- Undefined vars preserved in output
- Multiple occurrences all replaced
- Proper error messages for invalid inputs

### test-vision-conversation.pl
Tests vision-parser + conversation integration:
1. Queue vision analysis (async operation)
2. Check conversation initialization
3. Verify conversation metrics
4. Check vision-parser job registry
5. Validate deferred callback mechanism

**Expected Results:**
- Vision analysis queued successfully
- Conversation created alongside job
- Job and conversation registries both updated
- Deferred callback architecture verified

## Expected Behavior

### Synchronous Operations
- Conversation CRUD operations complete immediately
- Returns success/error status
- Metrics updated in real-time

### Asynchronous Operations
- Vision analysis returns `deferred` response
- Handler processes result in background
- Conversation turns added via handler
- Final result returned via callback

## Monitoring

### Check Protocol-7 Logs
```bash
# Tail main v7 log
tail -f /var/log/protocol-7/v7.log

# Check models zenka logs
tail -f /var/log/protocol-7/models.log

# Check vision-parser activity
tail -f /var/log/protocol-7/coding-vision-parser.log
```

### Query System Status
```bash
# Check v7 health
p7 v7.status

# Check models conversation count
p7 models conversation status

# Check vision-parser jobs
p7 coding.vision-parser.cmd.status
```

## Troubleshooting

### "Conversation not found" Error
- Ensure job_id is valid
- Check that `models.conversations` registry is initialized
- Verify v7 zenka is running

### Template substitution returns empty
- Check that variables exist in hash
- Verify template syntax: `<{variable_name}>`
- Allow alphanumeric, dash, underscore, dot in names

### Vision analysis hangs
- Check if llama-server-vision zenka is running
- Verify image file exists and is readable
- Check mount namespace (must inherit host mounts)

### Tests fail with "module not found"
- Ensure all Phase 1-3 modules are committed
- Run: `git log --oneline -n 5` to verify commits
- Restart v7: `p7 v7.restart models`

## Success Criteria

✓ All conversation operations complete without errors
✓ Template substitution correctly handles variables
✓ Vision jobs initialize conversations
✓ Metrics track conversation lifecycle
✓ Deferred callback architecture works
✓ No errors in protocol-7 logs

## Next Steps After Testing

1. **Phase 4: Extraction LLM Integration**
   - Queue JSON→YAML translation
   - Use conversation context in prompts

2. **Phase 5: YAML Validation**
   - Parse YAML syntax in Perl
   - Identify missing/malformed fields
   - Generate validation error messages

3. **Phase 6: Iterative Refinement**
   - Model self-correction with `<[CTX:turn_N]>`
   - Re-query vision if critical fields missing
   - Loop until valid & complete

4. **Phase 7: Production Deployment**
   - Test with various image types
   - Benchmark token usage
   - Monitor compaction strategies
   - Fine-tune token budgets

## Notes

- Tests are non-destructive (create test_* entries)
- Async operations may complete in background
- Check logs for detailed execution trace
- Metrics reset on v7 restart (expected behavior)
- Full end-to-end vision test pending extraction LLM

#,,.,,,.,,.,,,.,,,,,.,,,.,,..,,.,,,,,,,.,,,.,,..,,...,...,..,,...,..,,.,.,.,,,
#ROFR2YZCWFFSR7L2TKWD5IRESVYUVRFP3EV2KE36QDQVJTQKNKVFHRXFBPTPUVAUWDWFMI3S4CO5Y
#\\\|LPRYFJIWLW4IYU2FASDDAHA76IGA3GF4262CGJ4TKU2E7EONVYR \ / AMOS7 \ YOURUM ::
#\[7]TUXL6XXIC5RJQLSQSPJ24KWCAYR2ILS2NBBUJUGE5SYDGFCTBSDA 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
