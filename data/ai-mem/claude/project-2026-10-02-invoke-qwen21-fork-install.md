---
name: project-2026-10-02-invoke-qwen21-fork-install
description: qwen-image 2.1 runs in a SECOND invoke.ai install [ krakotay fork, own env \ root \ db ], invoke-web switches installs [ e5a74ce95 ] ; local UI patch in the fork clone, fork skips LoRAs for 2.1, shared images dir, main upgraded 6.9.0 -> 6.14.2
metadata:
  type: project
---

**2026-10-01 \ 02** : no released invoke.ai supports qwen-image 2.1 [ maintainer :
"v7", issue #9594 ]. main install upgraded 6.9.0 -> 6.14.2 [ torch 2.7.1+cu126
pinned ; backup `~/.invokeai/backup-pre-6.14.2-20261001-2252/` ].

**the fork install** : krakotay/InvokeAI branch `qwen-image-2.1` [ 6.14.1-post1 ],
clone `~/src/InvokeAI-qwen21`, conda env `invokeai-qwen21`, root `~/.invokeai-qwen21`
[ own db + models dir -- never share them : fork db version older than main's,
main can't parse `qwen_image_2_1` records, startup orphan-registration scans
models_dir ]. `outputs/images` -> the same ext-disk images dir as main [ uuid
names ; galleries stay separate -- records are per db ]. installed : UC Q4_K_M
gguf [ variant qwen_image_2_1 ], 2.1 vae, qwen3vl_8b_int8_convrot encoder
[ bf16 encoder 17.5 GB > 15 GB RAM ].

**invoke-web** [ e5a74ce95 ] : `invoke-web.variants.<name>.env \ root \ descr` in
zenka.v7 ; `p7c invoke-web.variant [name]`, `start <name>` ; per-install state
via `invoke-web.state_name`. both installs share port 4707 -> the browser keeps
ONE ui state [ canvas, ref images ] across them : stale refs from the other
install give `Image record not found`.

**local fork patches -- SECURED 2026-10-02** : clone branch `p7-local` [ 3
commits on fork commit c518116 ], exported to
`data/patches/invokeai-qwen21/000{1,2,3}-*.patch` [ 0003 : BF16 tensors of
the GGUF stayed GGMLTensor -> 'Operation changed the dtype of GGMLTensor'
in txt_in.text_norm ; unquantized F32 \ F16 \ BF16 now plain tensors ] [ git am clean on c518116,
verified ], full rebuild : `bin/scripts/invoke-ai/build-qwen21-fork`
[ `--ui` = web ui only ]. a fork update : rebase p7-local, re-export,
bump BASE in the script. the history of the patches : `Prompts.tsx` showed the ref image list only for variant
`edit`, while buildQwenImageGraph also feeds refs to `qwen_image_2_1` ->
condition widened, dist rebuilt [ `pnpm exec vite build`, NOT `pnpm build` :
its nested pnpm is not on PATH ] and copied into the env's
site-packages/invokeai/frontend/web/dist [ old : dist.pre-refimg-fix ].
`RefImageList.tsx` : cap 10 ref images for qwen_image_2_1 [ model card ;
the graph builder passes all enabled refs ], 5 for the rest, shown as
rows of 5 at the fixed h={16} [ flexWrap overlaid the panels below ].
eslint import-sort FAILS the vite build : `pnpm exec eslint --fix <files>`
first, and gate the dist copy on the build's exit code [ a failed build
leaves the OLD local dist, `cp -a` then silently installs it ].
`qwen_image.py` [ env site-packages AND clone ] : 2.1 config inference read
mlp_ratio only from the fused Comfy `img_mlp.gate_up` key -> KeyError on the
abenzerps GGUF [ diffusers layout gate_layer + proj ; all 297 keys match the
model exactly, checked with init_empty_weights ] -> falls back to gate_layer.
fork invokeai.yaml [ low-vram guide, backup .pre-lowvram-20261002 ] :
max_cache_vram_gb 5, max_cache_ram_gb 11, pytorch_cuda_alloc_conf
"backend:cudaMallocAsync", device_working_mem_gb 5 -- without the vram cap
encoder [ 6 GB ] + transformer [ 4.4 GB ] sat in vram together and the
driver spilled to shared memory [ see the degradation note ]. ui state is
shared with the main install : the first 2.1 renders inherited cfg 34 + 5
refs + 72 steps from SDXL settings [ 2.1 wants cfg ~4 ].
the int8 convrot encoder needs the `qwen-int8` extra : comfy-kitchen
0.2.35 installed in the env.

**open** : the fork's graph builder skips `addQwenImageLoRAs` for 2.1 -> NO
LoRA applies to 2.1 there yet. old SDXL \ FLUX LoRAs never carry over
[ different architecture ] -- two-pass img2img via the main install instead.
offered, not done : importing main's image records [ 49441 ] + boards into
the fork db so the old gallery works there.

#,,.,,,,.,,.,,,.,,,,.,..,,,,.,..,,,..,.,,,...,..,,...,...,,.,,,,,,,..,,,.,,.,,
#HRV7PARD4FWOORKVYN32RDBGPVOHJE5BBGJGAVWTDRSAQ7M56RMW7JZQEF3YM3L7JTP5UK4ZFBGUS
#\\\|PSRANVMVH7URDGIBVLAWBUFLYVDKOBVJGUUS32JNTZFFHI2NFHG \ / AMOS7 \ YOURUM ::
#\[7]FOZEDXPAA6QOKDOQBLNRLBBG5WR5SAIDNCX7VORDDACJITWMZEDI 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
