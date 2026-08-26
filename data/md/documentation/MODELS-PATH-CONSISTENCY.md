# Models Path Consistency Fix

## Current Inconsistencies Found

| Module | Current Path | Status |
|--------|--------------|--------|
| `models.chat.invoke_model` | references `lmstudio` backend | OK (uses registry) |
| `models.cmd.test_discover` | `/mnt/ext-xfs-data/models-lmstudio` | ✅ Correct |
| `models.local_discover` | `/mnt/ext-xfs-data/models-lmstudio` | ✅ Correct |
| `models.registry.populate_from_discovery` | `/mnt/ext-xfs-data/models-lmstudio` | ✅ Correct |
| `models.storage.init` | `/data/lmstudio-models` | ❌ WRONG |
| `models.storage.tier_management` | `/data/lmstudio-models` | ❌ WRONG |

## Standard Paths (Documented)

```yaml
# Standard Protocol-7 model storage paths
models:
  lmstudio: /mnt/ext-xfs-data/models-lmstudio      # 286GB of GGUF models
  invokeai: /mnt/ext-xfs-data/models-invoke        # For new Invoke.ai install
  huggingface_cache: /var/cache/invoke-ai/huggingface  # Configs only
```

## Required Fixes

### 1. Fix storage.init
```perl
# OLD (wrong):
'lmstudio-models' => '/data/lmstudio-models',

# NEW (correct):
'lmstudio-models' => '/mnt/ext-xfs-data/models-lmstudio',
```

### 2. Fix tier_management
```perl
# OLD (wrong):
'lmstudio-models' => '/data/lmstudio-models',

# NEW (correct):
'lmstudio-models' => '/mnt/ext-xfs-data/models-lmstudio',
```

## Future-Proof Solution

Create a configuration module:

```perl
## src/models.config.paths ##
<models.paths.lmstudio> = $ENV{'MODELS_LMSTUDIO_DIR'}
    // '/mnt/ext-xfs-data/models-lmstudio';

<models.paths.invokeai> = $ENV{'MODELS_INVOKE_DIR'}
    // '/mnt/ext-xfs-data/models-invoke';
```

Then use `<models.paths.lmstudio>` everywhere instead of hardcoding.

## Action Items

- [ ] Fix `models.storage.init` path
- [ ] Fix `models.storage.tier_management` path
- [ ] Create `models.config.paths` central configuration
- [ ] Audit all modules for hardcoded paths
- [ ] Add environment variable override support

---

#,,,,,...,...,..,,,,.,,,,,,.,,,,,,.,,,,.,,..,,.,.,...,..,,.,.,.,.,,..,..,,.,,,
#I6BL7ZWV6DG2BOY5US2JJI3KH5I6H7XBNF6TFIEZUMU67UTGPERSF44SWTQSCRKFGPI7X2TLOQ3K2
#\\\|WZKDSGWEIF2ZC43OXEO7X6ASUZS7LUH2BNCWBSW2ZMAOU2XS4DR \ / AMOS7 \ YOURUM ::
#\[7]YWLF3E4OXF66UTFRUBFESX3K2MDZ5AULYKDFNWETTTGRFLCZ3WDA 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
