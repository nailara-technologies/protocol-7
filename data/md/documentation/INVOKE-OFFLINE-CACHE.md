# Invoke.ai Offline Cache Setup

## Problem

Invoke.ai fetches model configs from huggingface.io on every rendering iteration.
When internet is down (or remote server crashes), local rendering fails.

## Solution

Pre-download all HuggingFace dependencies to local cache.

---

## ⚠️ CRITICAL: Separate Directories

**DO NOT use your Invoke.ai model directory as the cache!**

Invoke.ai stores **single-file .safetensors models** (your custom models, LoRAs).
This script stores **HuggingFace diffusers format** (config files, tokenizers).

**If you mix them:** Deleting via web interface may wipe everything!

**Correct setup:**
- Invoke.ai models: `/mnt/ext-xfs-data/models-invoke/` (your 382GB models)
- HuggingFace cache: `/var/cache/invoke-ai/huggingface` (2GB config files)

## Quick Start

```bash
## 1. Check what's cached (default: /var/cache/invoke-ai/huggingface)
bin/scripts/invoke-ai/invoke-model-prefetch -check

## 2. Download all models
bin/scripts/invoke-ai/invoke-model-prefetch -download

## 3. Verify
bin/scripts/invoke-ai/invoke-model-prefetch -check
```

---

## Usage

### List Available Models

```bash
bin/scripts/invoke-ai/invoke-model-prefetch -list
```

Output:
```
Available models:
============================================================
  cute-style           Cute style LoRA [optional]
    Repo: invoke-ai/loRA-cute-style
  sd-1.5               Stable Diffusion 1.5
    Repo: runwayml/stable-diffusion-v1-5
  sd-2.1               Stable Diffusion 2.1
    Repo: stabilityai/stable-diffusion-2-1
  sd-xl-base           Stable Diffusion XL Base 1.0
    Repo: stabilityai/stable-diffusion-xl-base-1.0
```

### Check Cache Status

```bash
bin/scripts/invoke-ai/invoke-model-prefetch -check
```

Output:
```
Checking model cache in: /var/cache/invoke-ai/models
============================================================

[sd-xl-base] Stable Diffusion XL Base 1.0
  Location: /var/cache/invoke-ai/models/sd-xl-base
  ✓ model_index.json                               (2.3 KB)
  ✓ scheduler/scheduler_config.json                (345 B)
  ✗ text_encoder/config.json                       MISSING
  ...
  Status: ✗ 3 files missing

Run with --download to fetch missing files.
```

### Download Specific Models

```bash
## Just the basics
bin/scripts/invoke-ai/invoke-model-prefetch -download sd-xl-base sd-1.5

## Custom cache location
bin/scripts/invoke-ai/invoke-model-prefetch -download -cache-dir /mnt/bigdisk/invoke-cache
```

---

## Configuration

### Environment Variable

```bash
export INVOKE_CACHE_DIR=/mnt/bigdisk/invoke-cache
bin/scripts/invoke-ai/invoke-model-prefetch -download
```

### Invoke.ai Configuration

Edit `invokeai.yaml`:

```yaml
## Use local cache for HuggingFace models
hf_cache_dir: /var/cache/invoke-ai/models

## Or set environment in systemd service
environment:
  - HF_HOME=/var/cache/invoke-ai/models
  - TRANSFORMERS_CACHE=/var/cache/invoke-ai/models
  - HF_DATASETS_CACHE=/var/cache/invoke-ai/models
  - TORCH_HOME=/var/cache/invoke-ai/torch
```

### Systemd Auto-Update

Create `/etc/systemd/system/invoke-model-prefetch.timer`:

```ini
[Unit]
Description=Update Invoke.ai model cache weekly

[Timer]
OnCalendar=weekly
Persistent=true

[Install]
WantedBy=timers.target
```

Create `/etc/systemd/system/invoke-model-prefetch.service`:

```ini
[Unit]
Description=Prefetch Invoke.ai models from HuggingFace
After=network-online.target
Wants=network-online.target

[Service]
Type=oneshot
ExecStart=/usr/local/protocol-7/bin/scripts/invoke-ai/invoke-model-prefetch -download
StandardOutput=journal
StandardError=journal
```

Enable:
```bash
systemctl daemon-reload
systemctl enable invoke-model-prefetch.timer
systemctl start invoke-model-prefetch.timer
```

---

## Integration with Protocol-7

### Pre-flight Check

Add to models zenka init or before batch generation:

```perl
## In models.init_code or before invoke task
my $check = system('bin/scripts/invoke-ai/invoke-model-prefetch --check');
if ($check != 0) {
    <[base.log]>->(1, "Invoke cache incomplete, some models may fail offline");
}
```

### Automatic Download Trigger

```perl
## Download missing models before batch
<[base.log]>->(2, "Pre-fetching Invoke.ai model dependencies...");
system('bin/scripts/invoke-ai/invoke-model-prefetch --download sd-xl-base');
```

---

## Cache Structure

```
/var/cache/invoke-ai/models/
├── sd-xl-base/
│   ├── model_index.json
│   ├── scheduler/
│   │   └── scheduler_config.json
│   ├── text_encoder/
│   │   ├── config.json
│   │   └── model.safetensors
│   ├── tokenizer/
│   │   ├── merges.txt
│   │   └── vocab.json
│   ├── unet/
│   │   ├── config.json
│   │   └── diffusion_pytorch_model.safetensors
│   └── vae/
│       ├── config.json
│       └── diffusion_pytorch_model.safetensors
├── sd-1.5/
│   └── ...
└── cute-style/
    └── ...
```

---

## Troubleshooting

### HuggingFace Rate Limiting

If you hit rate limits:
```bash
## Add authentication (increases limits)
export HF_TOKEN=your_huggingface_token
bin/scripts/invoke-ai/invoke-model-prefetch -download
```

### Partial Downloads

Clear and retry:
```bash
rm -rf /var/cache/invoke-ai/models/sd-xl-base
bin/scripts/invoke-ai/invoke-model-prefetch -download sd-xl-base
```

### Disk Space

Check cache size:
```bash
du -sh /var/cache/invoke-ai/models/*
```

Typical sizes:
- SD 1.5: ~4 GB
- SD XL: ~7 GB
- SD 2.1: ~5 GB

---

## Summary

| Command | Purpose |
|---------|---------|
| `-check` | Verify cache completeness |
| `-download` | Fetch missing files |
| `-list` | Show available models |
| `-cache-dir PATH` | Custom location |
| `-verbose` | Detailed output |

**Offline rendering workflow:**
1. Run `invoke-model-prefetch -download` while online
2. Verify with `-check`
3. Internet can go down - rendering continues! 🎨

---

#,,,.,,..,,,.,...,,,,,...,.,,,,,,,,,.,...,..,,.,.,...,...,...,,,,,.,.,.,.,...,
#6PWHBHK3LUUJMEXAEFKETCFTI2IHBXBBEVF5PGPO5QCCZRK34WNL6UNURHEEIDOWXSIWO263EBW6U
#\\\|VM6T7BP3S35NQRYHMMUNDUDCYCF2FNCKQWNZJJ62BDJF62SXGB3 \ / AMOS7 \ YOURUM ::
#\[7]E4EDBY4N2LTT3AKDGPC7IEEEGIF5FTVBCIUKR7LS55TIJ4SE2GDY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
