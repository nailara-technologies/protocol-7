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

#,,..,,,.,,,.,,..,,,.,,..,,,.,,..,,,.,.,,,.,.,.,.,...,...,,..,.,.,..,,.,.,.,.,
#5ZRXI5IW4TDCZOCGUUYWVUM63NNDA37R3IFAUT7O6L7Z62UWVA2TFKFZ3X45F7HII5FTAZIPPNUI6
#\\\|4BJGB57BMAC6DBBO6ZBVZMP6NZR4IUBIS7DXEMSEF2QULJEVHWD \ / AMOS7 \ YOURUM ::
#\[7]M7J64P2VVVTRW2NW4F62TU76HU2O7A33H5HVTJ5FDYD6S6YCDGCI 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
