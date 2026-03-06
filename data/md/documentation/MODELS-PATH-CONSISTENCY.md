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
## modules/models.config.paths ##
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

#,,..,...,.,,,..,,.,,,,..,,.,,.,,,..,,...,,,.,.,.,...,...,..,,.,,,,.,,,,,,,.,,
#5LB5DATWRWBTKICQX7AJ2LZ5ERLEO33P4H6OL4ZGAW7ERJQQ2X4FKE5HKG7HQ3TG7HZGCXVWE2BQA
#\\\|AWL7IM2UXCNIH4GBZ2E6LP4ZGIQHZ5ZJ6FAIWBFYEG4VDK6LLWM \ / AMOS7 \ YOURUM ::
#\[7]4FX6LAE4AGZVQCKL6HDQNKULLIEEN5TBPNT2YE5BSHZRULLRYECY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
