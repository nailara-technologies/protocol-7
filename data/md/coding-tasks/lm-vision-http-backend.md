
 .:[  lm-vision : HTTP backend primary, CLI fallback, LOVES_IT allocation  ]:.

## Status

**COMPLETED**: HTTP backend implemented and operational  
**ACTIVE**: CLI downgrade to fallback, LOVES_IT resource allocation integration  

The Mar 2026 rebuild (version 4266, `344688ce5`) with vision support via `/v1/chat/completions` is working. The HTTP path through `llama-server-cuda-fa` is now the primary backend.

---

## Current State

### HTTP Backend (PRIMARY)
- Routes through `llama-server-cuda-fa` via `/v1/chat/completions`
- Managed by coding zenka (lifecycle, monitoring, restart)
- Base64-encoded images with OpenAI-compatible API
- Status checked via `<coding.inference_servers>->{'gpu'}->{'status'}`

### CLI Backend (FALLBACK)
- `llama-mtmd-cli-cuda-fa` via `IPC::Open3`
- Used when HTTP server unavailable or `lm-vision.backend = cli` forced
- Preserved as stable fallback (was carefully debugged)

---

## Remaining Work: LOVES_IT Resource Allocation

Integrate 13-based harmonic weighting for GPU cycle allocation:

```
lm-vision.request → loves_it check → weighted GPU allocation
                        ↓
                   modes 4,7,13
                        ↓
              score 0-13 (loves_it=13)
                        ↓
           HTTP backend with priority
```

### New Module: `lm-vision.handler.http_analyze_loves`

```perl
## HTTP analyze with LOVES_IT resource weighting

my $result = <[lm-vision.handler.http_analyze_loves]>->({
    'image'       => $image_path,
    'prompt'      => $prompt,
    'model'       => $model,
    'requester'   => $zenka_id,
    'amos_tokens' => $token_balance,  # For resource weighting
});

## Internally:
## 1. Calculate loves_it score (modes 4,7,13 on request hash)
## 2. Weight HTTP request priority by score/13
## 3. Add 13% throughput bonus for loves_it (13)
## 4. POST to llama-server with priority header
## 5. Return response with allocation metadata
```

### Integration Points

| Component | Change | Module |
|-----------|--------|--------|
| Backend selection | Keep HTTP primary, CLI fallback | `lm-vision.cmd.analyze_image` |
| Resource weighting | Add loves_it scoring | NEW: `lm-vision.handler.http_analyze_loves` |
| Token integration | Read AMOS balance, weight request | `resource.gpu.loves_allocator` |
| Priority headers | Send loves_it score to server | HTTP POST headers |

---

## LOVES_IT Scoring for Vision Requests

```perl
## Calculate loves_it for vision workload
my $workload_hash = <[chk-sum.bmw.filesum]>->(256, $image);

my $mode4  = <[amos7.elf.check]>->($workload_hash, 4);   # Data truth
my $mode7  = <[amos7.elf.check]>->($workload_hash, 7);   # Love-truth
my $mode13 = <[amos7.elf.check]>->($workload_hash, 13);  # Cosmic

my $loves_score = ($mode4 ? 4 : 0) + ($mode7 ? 7 : 0) + ($mode13 ? 2 : 0);
# Maximum: 13 (loves_it!)
```

### Allocation Tiers

| Score | Label | GPU Priority | Throughput |
|-------|-------|--------------|------------|
| 13 | loves_it | Highest | +13% bonus |
| 11 | warm | High | 100% |
| 7 | heart | Medium | 75% |
| 4 | like | Low | 50% |
| 0 | void | Lowest | 25% |

---

## HTTP API with Priority Headers

```perl
POST http://localhost:8000/v1/chat/completions
Content-Type: application/json
X-Loves-It-Score: 13
X-AMOS-Tokens: 1000
X-Priority-Weight: 1.13

{
  "model": "Qwen3.5-9B-Vision",
  "messages": [ ... ],
  "max_tokens": 4096
}
```

---

## Implementation Steps

### Phase 1: LOVES_IT Module (This Session)
1. [ ] Create `lm-vision.handler.http_analyze_loves`
2. [ ] Integrate `resource.gpu.loves_allocator` scoring
3. [ ] Add priority headers to HTTP POST
4. [ ] Test with vision model (Qwen3.5-9B)

### Phase 2: Downgrade CLI (This Session)
1. [ ] Update `lm-vision.cmd.analyze_image` backend selection
2. [ ] Ensure CLI path still works as fallback
3. [ ] Document `lm-vision.backend = cli` override

### Phase 3: Integration Test
1. [ ] Test loves_it 13 → +13% throughput
2. [ ] Test loves_it 0 → minimal allocation
3. [ ] Test CLI fallback when server down
4. [ ] Verify AMOS token reading from NRT.NRD

### Phase 4: Documentation
1. [ ] Update `lm-vision` zenka documentation
2. [ ] Document LOVES_IT resource allocation
3. [ ] Note CLI binary rebuild as low priority

---

## Files to Modify

```
modules/lm-vision.cmd.analyze_image           ## Backend selection
NEW: modules/lm-vision.handler.http_analyze_loves  ## HTTP + loves_it
modules/resource.gpu.loves_allocator          ## Scoring function
configuration/zenki/lm-vision/start           ## Add module load
```

---

## CLI Binary Note

The `llama-mtmd-cli-cuda-fa` binary (CLI fallback) was not rebuilt in Mar 2026. It still works but is not at parity with HTTP backend features. Rebuild is **low priority** since HTTP is primary and stable.

```
/data/source/ik_llama.cpp/llama-mtmd-cli-cuda-fa   ## legacy, functional
```

---

## Success Criteria

- [ ] HTTP backend serves 90%+ of vision requests
- [ ] loves_it 13 requests get measurable throughput boost
- [ ] CLI fallback works when server unavailable
- [ ] No regression in vision analysis accuracy

#,,,.,,,,,,..,.,,,.,,,,,.,,,.,,,.,,,,,.,.,,..,..,,...,...,.,.,,,.,.,,,,..,,.,,

---

**Integrated Task**: HTTP backend (complete) + CLI fallback (downgrade) + LOVES_IT allocation (new)  
**Session Target**: Implement Phase 1 & 2  

#,,.,,,,,,.,.,,,,,.,.,,.,,,..,.,.,..,,...,,,.,.,.,...,...,,,,,,,.,,.,,...,,,,,
#JMXAPJN2XFG34E3U4MARSMBNUXFC3CMR44454GZAZ67MN5ZRVIS27K72GUJUQYFP37E7SF3TKV7HC
#\\\|6TMGMMQGR2EXQCNWFMZJQPCIAMLEXM6FVDBPK4222H7OSGUKO6Y \ / AMOS7 \ YOURUM ::
#\[7]TBHQ2WZKP6YAIKL2NVJ5G2ZHUTWKYWDVBGIRAL3G5RFRVGRIUADA 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
