# Models Path Configuration

## Centralized Path Management

All model storage paths are now defined in **one location**: `cfg/external-inference-models`

This file is included in zenka startup after `shared-params` and provides consistent paths across all zenki (models, lm-vision, coding, etc.).

## Configuration File

**Location:** `cfg/external-inference-models`

**Included in:** Models zenka (and other zenki that need model paths)

**Loaded via:** `[load_config_file:'external-inference-models']`

## Current Configuration

```
## Storage Paths
external.models.lmstudio.path = /mnt/ext-xfs-data/models-lmstudio
external.models.invokeai.path = /mnt/ext-xfs-data/models-invoke
external.models.ollama.path = /usr/share/ollama/.ollama/models
external.models.local.path = /data/models

## Cache Paths
external.models.huggingface.cache = /var/cache/invoke-ai/huggingface
external.models.lmstudio.cache = ~/.cache/lm-studio
external.models.download.temp = /tmp/model-downloads

## Server Endpoints
external.models.lmstudio.url = http://127.0.0.1:1234
external.models.ollama.url = http://127.0.0.1:11434
external.models.invokeai.url = http://127.0.0.1:9090
```

## Usage in Modules

### Direct Variable Access

```perl
## Access the configured paths
my $lmstudio_dir = <external.models.lmstudio.path>;
my $invoke_dir = <external.models.invokeai.path>;
my $hf_cache = <external.models.huggingface.cache>;
my $lmstudio_url = <external.models.lmstudio.url>;
```

### With Environment Override

```perl
## Allow environment variable to override
my $path = $ENV{'MODELS_LMSTUDIO_DIR'} // <external.models.lmstudio.path>;
```

## Standard Directory Structure

```
/mnt/ext-xfs-data/
├── models-lmstudio/          # external.models.lmstudio.path
│   ├── mradermacher/
│   ├── TheBloke/
│   └── ...
├── models-invoke/            # external.models.invokeai.path
│   └── [UUID-based folders]
└── backup/
    ├── invoke-ai/
    └── lmstudio/

/var/cache/
└── invoke-ai/
    └── huggingface/          # external.models.huggingface.cache
```

## Adding to Other Zenki

To use these paths in other zenki (lm-vision, coding, etc.):

```perl
## In cfg/zenki/YOUR_ZENKA/start
#include <shared-params>
#include <external-inference-models>

## Now all external.models.* variables are available
```

## Migration from Hardcoded Paths

### Before (inconsistent)
```perl
# In various modules - WRONG
my $dir = '/mnt/ext-xfs-data/models-lmstudio';  # hardcoded
my $dir = '/data/lmstudio-models';               # wrong path
<models.path.lmstudio>                           # old variable
```

### After (centralized)
```perl
# All modules use - CORRECT
my $dir = <external.models.lmstudio.path>;
```

## Fixed Modules

| Module | Previous | Now Uses |
|--------|----------|----------|
| `models.init_code` | Hardcoded paths | Verifies `<external.models.*>` |
| `models.local_discover` | Hardcoded | `<external.models.lmstudio.path>` |
| `models.registry.populate_from_discovery` | Hardcoded | `<external.models.lmstudio.path>` |
| `models.storage.init` | `/data/lmstudio-models` | `<external.models.lmstudio.path>` |
| `models.storage.tier_management` | `/data/lmstudio-models` | `<external.models.lmstudio.path>` |

## Environment Variable Overrides

Set before starting zenka to override defaults:

```bash
export MODELS_LMSTUDIO_DIR=/mnt/bigdisk/lmstudio
export MODELS_INVOKE_DIR=/opt/invokeai-models
export HF_CACHE_DIR=/var/cache/huggingface

./bin/v7 -r models
```

## Customization

To permanently change a path, edit:
```
cfg/external-inference-models
```

And modify the value at the top of the file. All zenki will pick up the change on next start.

---

#,,,.,..,,.,.,.,.,,..,..,,.,.,.,,,,,.,.,,,..,,.,.,...,...,,.,,,,,,,,.,.,.,,.,,
#SNA7VJY3JGYW7RASEYKDFEOFDZY46WM2VWHIQMNCM5RA2WNVACKXILL7SMJW2PAEGIBQ46E2XJQQ6
#\\\|2RBXTQPOOKDIUQHIYB5PVNBZ7CSGIKPTJY465EIKESNODJOQSDQ \ / AMOS7 \ YOURUM ::
#\[7]EDYNMKXKJYESIKLIRN7RA4NWMEOPLIS3BDMLZKP6COG6D2GBR4CA 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
