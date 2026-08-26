# Remove Redundant JSON Registry System

## Current State
Two registry systems exist:
1. **JSON** (`models.registry.load.load_registry`, `save.save_registry`, `base.get_registry`)
2. **YAML** (`models.storage.yaml_load`, `yaml_save`)

Both now use flat format: `{ <id> => {...} }`

## Files to Remove/Consolidate
- `src/models.registry.load.load_registry`
- `src/models.registry.save.save_registry`
- `src/models.registry.base.get_registry`
- `src/models.registry.base.save_registry_internal`
- `src/models.registry.empty.create_empty_registry`

## Callers to Update
- `src/models.registry.get_entry.get_model_entry` - use `<models.registry>`
- `src/models.registry.list_all.list_all_models` - use `<models.registry>`
- `src/models.registry.update_entry.update_model_entry` - use `yaml_save`

## Migration Path — COMPLETED
1. ~~Ensure YAML registry has all data from JSON~~ (JSON never actually read after init)
2. ✅ Updated callers to use `<models.registry>` directly
3. ✅ Removed JSON modules (7 files deleted)
4. ✅ Updated `base.list.subroutines`

## Note
JSON path: `/var/protocol-7/models/registry.json`
YAML path: `var/zenka/models/registry/models.yaml`

---

## Related Consolidation: Model Query Reply Format

### Problem
Two model lookup commands return different formats:

| Command | Format | Fields |
|---------|--------|--------|
| `models.cmd.get_path_by_amos` | Plaintext | path, model_id, name, quantization |
| `models.cmd.get_model_path` | JSON | full metadata including mmproj, is_vision |

### Required Changes

#### 1. Unified YAML Reply Format
Both commands should use `YAML::XS::Dump` for consistency:

```perl
use YAML::XS;
my $yaml = YAML::XS::Dump($result);
return { 'mode' => 'size', 'data' => $yaml };
```

Standard response fields:
```yaml
model_id: "MBZAAII:ZRCGL5Q"
name: "Qwen Qwen3.5 9B"
file_path: "/path/to/model.gguf"
mmproj_path: "/path/to/mmproj.gguf"  # empty string if not vision
is_vision: 1
quantization: "Q6_K"
context_size: 8192
batch_size: 512
```

#### 2. Vision Model Support
The `mmproj_path` field is **required** for vision models to load in llama-server, even for text-only inference.

When `is_vision: 1`, the spawning logic must:
```bash
llama-server -m /path/to/model.gguf --mmproj /path/to/mmproj.gguf
```

#### 3. Registry Fallback Consistency
Both commands should use the same lookup chain:
1. Check aliases
2. Check definitions
3. Fallback to `<models.registry>` (discovered registry)

Currently `get_model_path` has this fallback, `get_path_by_amos` does not.

### Zenka Impact

**coding zenka**: Uses `resolve_model_path` → needs mmproj awareness for vision models
**lm-vision zenka**: Also needs unified model switching with mmproj support

Config vs spawn mismatch observed:
- Config: `O6A7F7Q:CQGT4CA`
- Actual spawn: `MBZAAII:ZRCGL5Q`

This suggests the model ID resolution and spawn logic are using different data sources.

### Affected Zenki (All Need Consistency)

| Zenka | Model Commands | Current Issues |
|-------|---------------|----------------|
| `coding` | `switch-model`, `resolve_model_path` | Uses different lookup than models zenka |
| `lm-vision` | model switching for vision tasks | May not handle mmproj correctly |
| `vision-batch` | batch vision processing | **Most outdated** — needs significant refactoring |

**vision-batch zenka** is the oldest implementation and likely needs:
- Complete model resolution rewrite to use shared routines
- mmproj support for vision model loading
- Update to latest registry format
- Potential child/parent communication updates
- May serve as test case for shared routine design

### Recommended: Shared Routines

Create generic model resolution routines to reduce redundancy:

```
src/models.resolve.with_mmproj      # unified lookup with mmproj handling
src/models.resolve.by_amos_id       # by composite checksum ID
src/models.registry.clear_and_refetch # [:re-fetch:] implementation
```

All three zenki can then load these shared routines instead of duplicating logic.

### Files to Update
- `src/models.cmd.get_path_by_amos` — convert to YAML, add registry fallback
- `src/models.cmd.get_model_path` — convert to YAML
- `src/models.resolve.*` — NEW shared resolution routines
- `src/coding.resolve_model_path` — use shared routines
- `src/coding.handler.spawn_with_deps` — pass --mmproj flag when needed
- `src/lm-vision.*` — use shared routines
- `src/vision-batch.*` — use shared routines

### Registry Management Commands

All model-using zenki should support:

```bash
zenka.clear-registry              # clear local cache
zenka.clear-registry [:re-fetch:] # clear and re-fetch from models zenka
```

**Note:** Use `[:re-fetch:]` (not `[:re-scan:]`) to distinguish between:
- `re-fetch`: query models zenka for current registry data
- `re-scan`: re-scan filesystem for new GGUF files (expensive)

### Implementation Status — COMPLETED
- ✅ `models.resolve.entry` — new unified lookup (aliases → definitions → registry)
- ✅ `models.cmd.get_path_by_amos` — uses `resolve.entry`, returns YAML
- ✅ `models.cmd.get_model_path` — uses `resolve.entry`, returns YAML
- ✅ `coding.handler.model_path_reply` — parses YAML, stores mmproj_path + is_vision
- ✅ `coding.handler.spawn_path_reply` — parses YAML, passes mmproj_path to spawn
- ✅ `coding.handler.spawn_with_deps` — passes mmproj_path from cached metadata
- ✅ `coding.spawn_inference_server` — adds `--mmproj` flag when mmproj_path given
- ✅ `lm-vision.fetch_model_config` — parses YAML instead of JSON

### Testing Checklist
- [ ] Both commands return YAML
- [ ] Vision models return mmproj_path
- [ ] Coding zenka can load Qwen Qwen3.5 9B (vision model) with mmproj
- [ ] Non-vision models have empty mmproj_path
- [ ] Config model ID matches spawned model ID

#,,..,...,..,,...,..,,..,,...,,,.,,.,,,.,,,,,,..,,...,...,.,.,...,,,,,.,,,.,.,
#DAVVS34U7PKAHCKYTOHDCSMIHX6FDDSH7EOBLFT6BJSIL53TUSXBLFJEYHHVOXK74TKIU2SLTAUN6
#\\\|U4Q3N57IO3ARH25QUNFELGD76DH2MP45J4N52NLK5NVUPSC6ZFO \ / AMOS7 \ YOURUM ::
#\[7]73IWDPXO2YYSMPSL3SLDBWRKAK3E73TMSHKUZXUXMZ2FCXZVSICQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
