# Remove Redundant JSON Registry System

## Current State
Two registry systems exist:
1. **JSON** (`models.registry.load.load_registry`, `save.save_registry`, `base.get_registry`)
2. **YAML** (`models.storage.yaml_load`, `yaml_save`)

Both now use flat format: `{ <id> => {...} }`

## Files to Remove/Consolidate
- `modules/models.registry.load.load_registry`
- `modules/models.registry.save.save_registry`
- `modules/models.registry.base.get_registry`
- `modules/models.registry.base.save_registry_internal`
- `modules/models.registry.empty.create_empty_registry`

## Callers to Update
- `modules/models.registry.get_entry.get_model_entry` - use `<models.registry>`
- `modules/models.registry.list_all.list_all_models` - use `<models.registry>`
- `modules/models.registry.update_entry.update_model_entry` - use `yaml_save`

## Migration Path
1. Ensure YAML registry has all data from JSON
2. Update callers to use `<models.registry>` directly
3. Remove JSON modules
4. Update `base.list.subroutines`

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

### Files to Update
- `modules/models.cmd.get_path_by_amos` — convert to YAML, add registry fallback
- `modules/models.cmd.get_model_path` — convert to YAML
- `modules/coding.resolve_model_path` — handle mmproj for vision models
- `modules/coding.handler.spawn_with_deps` — pass --mmproj flag when needed
- `modules/lm-vision.*` — ensure consistent model switching

### Testing Checklist
- [ ] Both commands return YAML
- [ ] Vision models return mmproj_path
- [ ] Coding zenka can load Qwen Qwen3.5 9B (vision model) with mmproj
- [ ] Non-vision models have empty mmproj_path
- [ ] Config model ID matches spawned model ID

#,,..,,..,,.,,...,...,.,,,,.,,...,,.,,...,..,,..,,...,...,...,,,,,,.,,..,,,,.,
#PZ3OZRGEPP4KKRNPQZ7YYJ5ZUBHVRGGK23NFW4FM3NPYZCAG3F6Z7626CFOMMM4UP44TADWOXWEXQ
#\\\|5AP3X3FVAFTLL5MZNJSJOJRCJDEGYDYI7VYRZQYGSIKGKFHEWQ3 \ / AMOS7 \ YOURUM ::
#\[7]MZUHWSILJTEK2E5R3O6QRHLJ2SMSVRKUZ5D72XYCLQZWDBW2B6AA 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
