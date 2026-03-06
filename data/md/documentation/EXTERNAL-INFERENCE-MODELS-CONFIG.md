# External Inference Models Configuration

## Overview

Centralized configuration for external AI model inference systems.
Shared across all zenki (models, lm-vision, coding, etc.)

## Configuration File

**Location:** `configuration/external-inference-models`

**Included:** After `shared-params` in all zenki that need model paths

## Defined Paths

### Storage Paths

| Variable | Default | Purpose |
|----------|---------|---------|
| `<external.models.lmstudio.path>` | `/mnt/ext-xfs-data/models-lmstudio` | LM Studio GGUF models |
| `<external.models.invokeai.path>` | `/mnt/ext-xfs-data/models-invoke` | Invoke.ai models |
| `<external.models.ollama.path>` | `/usr/share/ollama/.ollama/models` | Ollama models |
| `<external.models.local.path>` | `/data/models` | Generic local models |

### Cache Paths

| Variable | Default | Purpose |
|----------|---------|---------|
| `<external.models.huggingface.cache>` | `/var/cache/invoke-ai/huggingface` | HF configs/tokenizers |
| `<external.models.lmstudio.cache>` | `~/.cache/lm-studio` | LM Studio cache |
| `<external.models.download.temp>` | `/tmp/model-downloads` | Temporary downloads |

### Server Endpoints

| Variable | Default | Purpose |
|----------|---------|---------|
| `<external.models.lmstudio.url>` | `http://127.0.0.1:1234` | LM Studio server |
| `<external.models.ollama.url>` | `http://127.0.0.1:11434` | Ollama server |
| `<external.models.invokeai.url>` | `http://127.0.0.1:9090` | Invoke.ai server |

## Usage in Zenki

### Direct Variable Access

```perl
## In any module after configuration is loaded
my $lmstudio_dir = <external.models.lmstudio.path>;
my $invoke_url = <external.models.invokeai.url>;
my $hf_cache = <external.models.huggingface.cache>;
```

### Accessing with Fallback

```perl
## Get path with environment variable override
my $path = $ENV{'MODELS_LMSTUDIO_DIR'} // <external.models.lmstudio.path>;
```

### Environment Variable Override

```bash
## Override before starting zenka
export MODELS_LMSTUDIO_DIR=/mnt/bigdisk/lmstudio
export MODELS_INVOKE_DIR=/opt/invokeai-models
export HF_CACHE_DIR=/var/cache/huggingface

## Then start zenka
./bin/v7 -r models
```

## Integration in Zenka Start Files

### For Models Zenka

```perl
## In configuration/zenki/models/start
#include <shared-params>
#include <external-inference-models>

## Now all external.* variables are available
```

### For Other Zenki

```perl
## In configuration/zenki/coding/start (or lm-vision, etc.)
#include <shared-params>
#include <external-inference-models>

## Access paths directly
my $model_dir = <external.models.lmstudio.path>;
```

## Path Verification

On load, the configuration verifies paths exist:

```
[external-models] external.models.lmstudio.path: /mnt/ext-xfs-data/models-lmstudio
[external-models] WARNING: external.models.invokeai.path does not exist: /mnt/ext-xfs-data/models-invoke
```

Warnings (level 1) are logged for missing paths - zenka continues but notifies.

## Default Models Reference

Quick reference for commonly used models:

```perl
## LM Studio chat model
<external.models.lmstudio.default_chat>
# -> mradermacher/Huihui-Qwen3-Coder-30B-A3B-Instruct-abliterated-i1-GGUF

## Embedding model
<external.models.lmstudio.default_embedding>
# -> nomic-ai/nomic-embed-text-v1.5-GGUF

## Invoke.ai image model
<external.models.invokeai.default_model>
# -> stable-diffusion-xl-base-1.0
```

## Migration from Hardcoded Paths

### Before (inconsistent)
```perl
# In various modules:
my $dir = '/mnt/ext-xfs-data/models-lmstudio';  # hardcoded
my $dir = '/data/lmstudio-models';               # wrong path
```

### After (centralized)
```perl
# All modules use:
my $dir = <external.models.lmstudio.path>;
```

## Customization

To permanently change a path, edit:
```
configuration/external-inference-models
```

And modify the default value at the top of the file.

---

#,,.,,.,,,..,,,.,,.,,,..,,,..,...,,,.,,,,,,,.,.,.,...,.,,,.,,,,.,,.,.,.,.,.,.,
#JYYUG2JUNE7SCRTMDITLDHESTNEKGC63WCF33QW7JJ6TEX4GDOBVTDKGMM7VNKIGRR3CXUVZWZC2Q
#\\\|TNNMZH4R362D3D6PQAYSAUEMWZFMDQ4TVQVKYW7D2WVDE5Z4ZNY \ / AMOS7 \ YOURUM ::
#\[7]U6YDCG5ML7YSXFB4XH4I5SUR6OKTAA3UUJ2UQMDYODHXTAWPB4CY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
