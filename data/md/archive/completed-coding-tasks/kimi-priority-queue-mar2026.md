
 .:[  kimi priority queue — mar 2026, ~11h remaining  ]:.

## Context

Kimi has ~30% weekly credits, ~11 hours. Multiline command work is in
progress (devmod). This list orders remaining tasks by: unblocked state,
implementation readiness, and systemic value. Stop at any tier boundary
if credits run low — each tier is independent.

---

## Tier 1 : Complete In-Progress [ ~2h ]

### 1.1 Multiline command — finish and test
`data/md/coding-tasks/add-multiline-command-support-to-clients.md`

- Finish `src/devmod.cmd.receive-multiline`
- Add socat test script: `bin/dev/test-multiline-socat`
- Verify round-trip: multiline input → correct dispatch → reply
- Document any edge cases found during testing

---

## Tier 2 : Stub Initialization [ ~4h — high systemic value ]

### 2.1 @INDEXCUBE Phase 1 — identity anchor on startup
`data/md/coding-tasks/indexcube-routing-stack.md` → Phase 1

- Add `base.p7ref.self` module: constructs `TYPE:CHKSUM7:ADDR_B32`
  from zenka identity key (ADDR_B32 = amos7_chksum(pubkey)[0..5])
- In `base.init_code` or shared init: `push @INDEXCUBE, <[base.p7ref.self]>->()`
- Verify with `list zenki` showing cube coordinate per zenka
- This is the minimal useful state — everything else builds on it

### 2.2 zulum Phase 1 — 13 entropy streams
`data/md/coding-tasks/zulum-cube13-decoder-integration.md` → Phase 1

- Implement `src/zulum` inner loop (port from `bin/dev/division-13-table`)
- Initialize 13 streams from gen×1..gen×13 seeds
- Expose `stream-attach` to connect a consumer
- Verify stream output against `bin/dev/gen-div` expected values

### 2.3 decoder Phase 1 — level-5 base32 stream handler
`data/md/coding-tasks/decoder-zenka-stream-protocol.md` → Phase 1

- Implement `src/decoder.zenka` level-5 accumulator
- Accept base32 stream from zulum via `stream-attach`
- `show-buffer 5` displays current accumulated value
- `buffer-erase-level 5` clears on clean 5-bit boundary
- Verify with known zulum output: decoded values match `asc-enc` results

---

## Tier 3 : models.chat Fine-Tuning [ ~2h ]

### 3.1 Verify finish_reason propagation
`src/models.handler.llm_response` already captures finish_reason —
confirm it reaches `coding.handler.check-completion-chain` correctly
for all active backends (local llama-server, any remote endpoints).

### 3.2 Multi-model chat Phase 1 — inline file expansion
`data/md/coding-tasks/multi-model-design-chat.md` → Phase 1

- Add `[::file:: 'path']` expansion to nshell or as `models.expand_refs`
- `[::code:: 'path']` variant with line numbers
- `[::tail:: 'path' N]` for last N lines
- Test: reference a coding task doc inline, verify model receives content
- This single feature would already make design sessions significantly better

---

## Tier 4 : If Credits Remain [ ~2h ]

### 4.1 base.indexcube push/pop primitives
`data/md/coding-tasks/indexcube-routing-stack.md` → Phase 2

```
base.indexcube.push    ## sign and push P7REF
base.indexcube.pop     ## pop and verify signature
base.indexcube.here    ## return $stack[-1]
base.indexcube.depth   ## scalar @INDEXCUBE
```

### 4.2 lm-vision HTTP backend — Phase 1
`data/md/coding-tasks/lm-vision-http-backend.md` → Phase 1

- `src/lm-vision.handler.http_analyze`: base64-encode image, POST
  to llama-server `/v1/chat/completions`, return response text (LWP blocking)
- Backend selection in `lm-vision.cmd.analyze_image`: check
  `<coding.inference_servers>->{'gpu'}->{'status'} eq 'ready'`
- Test with a vision model, verify CLI fallback still works

### 4.3 cube-13 jump routing — Phase 2 of zulum integration
- Implement jump table in `src/cube-13`
- Commands: `jump true`, `jump reverse`, `jump next`
- Wire to zulum streams, notify decoder of stream change with boundary marker

---

## Do Not Attempt This Session

These need more design, live system testing, or are lower urgency:

- `fix-list-alignment-offset-truncation.md` — needs before/after captures
  on live system with real data before applying `$table_width -= 2` fix
- `zenka-key-identity-infrastructure.md` — large, needs key infrastructure
- `cube-coordinate-network-topology.md` — design reference, no code yet
- `invoke-ai-model-storage-management.md` — invoke.ai zero/missing test first
- `remove-redundant-json-registry.md` — needs careful registry audit

---

## Notes for Kimi

- Sign all new files with `bin/Protocol-7 sourcecode update-signatures`
  before committing — the pre-commit hook will reject unsigned files
- @INDEXCUBE and @colors are global arrays in `bin/Protocol-7` lines 13-14,
  already declared, waiting for population
- The zulum → decoder stream uses the same `stream-attach` interface on both
  ends — protocol-compatible without new command machinery
- `bin/dev/gen-div` is the reference oracle for verifying zulum output:
  same cycle positions, same operator results, known TRUE/FALSE mapping
- For multiline: the socat test script is the fastest path to verification
  without needing a full client session

#,,.,,,..,,,.,,,.,,,.,,..,,,.,,,,.,.,,,,.,,,.,,..,,.,,,.,..,.,,,,.,..,,...,..

#,,..,,,.,...,.,.,.,.,...,...,...,..,,,..,,,.,..,,...,...,,,.,,..,.,.,..,,,,.,
#Z2MX6IL4FFIUTTJIVE42DNYGI5FS34E5V6VZV6SNARIBXMILSRIDTXNWSYNLHBE5DRCY23KBV2GE2
#\\\|YTLEGHLFBP64QQKBPCECUJGODQK7YX3YADHCN6YGJ3NZX55TIQQ \ / AMOS7 \ YOURUM ::
#\[7]F3CWNXRGQZXHN4L3REVZLBXQPZPVTOLXNPSZ7Z5BTRLADPVUGQBQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
