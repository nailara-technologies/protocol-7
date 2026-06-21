## 2026-06-21: MCP session_catchup fixes + coding self-test verification

### MCP / session_catchup improvements

- Bumped MCP tool timeout to 600 s in `~/.kimi-code/mcp.json` and `data/json/claude/.mcp.json`.
- Raised `bin/mcp-server-p7` internal alarm to 590 s.
- Made rolling-window summarizer context-aware: queries `coding.safe-context-size` for the VRAM-safe calculated context size and caps chunk + rolling-summary sizes so large sessions no longer overflow the local 9B model.
- Added new command `coding.safe-context-size` returning the calculated context length (as opposed to the configured override `coding.context-size`).
- Optimized `session_catchup`: direct file lookup by full UUID or prefix instead of scanning every session file.
- Added `tail_chars` parameter to `session_catchup`; sessions > 600 KB are auto-truncated to the last 400 KB so summarization finishes inside the MCP timeout.

### Coding zenka self-test verification

- Verified the tiered escalation pipeline end-to-end on live models.
- `p7c coding.self-test-run` on currently loaded `IXNBXVI:U2XBEXQ` → 2/2 passed.
- `p7c coding.self-test-run DVEAZIA:GPAKBLA` → switch-test-restore cycle completed, 2/2 passed.
- **Tier-1 retry confirmed working**: DVEAZIA answered the cat/mouse riddle with an 85-word verbose response; first reformat failed with `over_word_limit:85>2`, the stricter second hint fired, and the answer was reformatted to `cat` without leaking the expected answer.
- Final status shows both models PASS with updated multipliers:
  - `IXNBXVI:U2XBEXQ` — multiplier 27.425
  - `DVEAZIA:GPAKBLA` — multiplier 41.013

### Files involved

- `bin/mcp-server-p7`
- `modules/coding.cmd.safe-context-size`
- `modules/coding.spawn_inference_server`
- `modules/coding.self_test.run`
- `modules/coding.self_test.evaluate`
- `modules/coding.self_test.check_constraint`
- `modules/coding.self_test.apply_tier2`
- `modules/coding.self_test.tier2_judge`
- `modules/coding.self_test.cmd.self-test-run`
- `modules/coding.self_test.handler.poll_switch`
- `modules/coding.tools.http_inference_client`

### Commands for future reference

```bash
p7c coding.self-test-run                # test currently loaded model
p7c coding.self-test-run <MODEL_ID>     # switch-test-restore against another model
p7c coding.self-test-status             # view archived results
```

#,,,,,,,,,.,,,.,.,,,,,.,,,...,,..,..,,,.,,.,,,..,,...,..,,.,,,,,,,,,.,,,,,,,.,
#QULFMRLKOA76PCQRFHRBE4X3ILVVBDJHG4T7KVS7YK2X63NGX67NDPOKZUD6CQZMDRLBYKPYHUTNC
#\\\|3UGETHNA3TLAYQI6BBJP2MTOFCQ6LBLLCTG6FCB6MKQDDW4FDQN \ / AMOS7 \ YOURUM ::
#\[7]WO2W6WFR6IDELCEKTUGL7HTF4YARO2HF66JEXJIIOQN2ZTIJR6BQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
