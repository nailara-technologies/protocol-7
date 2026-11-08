---
name: invokeai-model-install-quirks
description: invoke.ai [ qwen21 fork ] model installs : downloader ignores the env proxy, paused local installs cannot resume, a failed remote install loses its small files, encoders are found BY NAME, ComfyUI-prefixed qwen LoRAs need a rekey ; fetch-files completes \ replaces big downloads
metadata:
  type: reference
---

learned 2026-11-08 while moving the legacy models into the qwen21 install. see [[reference-invoke-web-run-user-and-invokeai-facts]].

**proxy** : the model downloader is a GUARDED session [ ssrf policy, `invokeai/app/util/ssrf.py` ] that IGNORES `http[s]_proxy` [ log : "Ambient HTTP proxy settings are ignored for guarded downloads" ] -- only `download_proxy` \ env `INVOKEAI_DOWNLOAD_PROXY` counts. invoke-web.proxy sets both [ url in host-config/invoke-web.cfg, never the repo ]. a socks url needs pysocks + socksio in the conda env [ invoke-web warns at start, todo QZE ]. check : `ss -tnp` of the invokeai pid -> only the socks endpoint, no direct :443.

**install queue** :
- in-place registration of existing files : `POST /api/v2/models/install?inplace=true&source=<urlencoded path>` body `{}` ; a folder copy : `inplace=false`. `POST /api/v2/models/i/<key>/reidentify` re-probes an entry ; `PATCH /api/v2/models/i/<key>` `{"name":..}` renames ; `DELETE /api/v2/models/install/<id>` cancels a job
- PAUSE + RESUME of a LOCAL install fails [ resume treats it as remote : "No files associated with <path>" ] and leaves the job 'waiting' forever ; such stuck jobs also blanked the ui model list until a browser reload. cancel + resubmit instead
- a remote multi-file install that breaks mid-stream [ IncompleteRead ~4 GB into a 5 GB unet, twice ] is cancelled ; a retry may queue only the failed file -> an 'unknown' model with just unet/. complete it : fetch the missing files [ HF tree api `?recursive=true` lists size \ oid \ lfs ] and reidentify. big models : fetch everything with fetch-files [ resume + sha256 vs HF ] into a world-readable staging dir, then a local install
- fetch-files.hf-download `{"repo","file":"<FULL repo path>","dest"}` writes `<dest>/<file>` [ subdirs must exist and be writable by protocol-7 ; its own dirs are 0750 ]. hf-list shows .gguf only. small git files : curl via the proxy, verify with `git hash-object` == tree oid

**ip adapters** : checkpoint adapters find their CLIP vision encoder BY NAME [ `CLIP_VISION_MODEL_MAP` ] : ViT-H = `IP Adapter SD1.5 Image Encoder` [ SD1 + SDXL ViT-H adapters ], ViT-G = `IP Adapter SDXL Image Encoder`, ViT-L = `clip-vit-large-patch14`. registering an encoder by its resolved path names it after the uuid folder -> rename it, or invoke tries a download.

**qwen-image LoRAs** : accepted key forms `transformer_blocks.` \ `transformer.transformer_blocks.` \ kohya `lora_unet_transformer_blocks_`. ai-toolkit ComfyUI exports with `diffusion_model.` [ Anything2RealCharacters, outpaint-v2 ] land in 'unknown' : rewrite the header keys `diffusion_model.` -> `transformer.` [ data bytes unchanged, header padded to 8 ] and install the copy.

**bad files** : `FLUX Redux.safetensors` [ legacy disk ] has a stray 0x00 before its json header -- newer safetensors rejects it ; flux1-redux-dev is fine.

#,,..,.,,,,,.,.,.,.,,,,.,,..,,..,,...,,,.,..,,..,,...,...,.,,,..,,,.,,,,.,...,
#6MVWMRTT3L7VQFTAP42GVHUP7WZUMI2LXJR5Z5WX6EXEFSBLSURACGMYGFFK3H6KGECXLI77P3FVU
#\\\|JIHPOON4C5S2FDKX6F3BSJKTRK6VUQUHLNO5OG4VK34LFCOXRLJ \ / AMOS7 \ YOURUM ::
#\[7]42CYN3GMVWZVO4H6YPR36YBMFDLEROCL3LGGDXJ7J6I3QDGLDWAY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
