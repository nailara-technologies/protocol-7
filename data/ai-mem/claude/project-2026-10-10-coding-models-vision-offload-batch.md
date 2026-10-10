---
name: coding-models-vision-offload-batch-2026-10-10
description: 2026-10-09/10 session : coding image tools, gpu offload planner [ exact kv, moe experts ], model-batch harness repaired, tool groups, model comparison results + open items
metadata:
  type: project
---

**Landed [ commits 2026-10-09/10, f8b041b7c .. ed31591e3 ]**
- coding images : view_image, analyze_image [ child task, optional switch=true -> vision model and back ], :image-embed: / :image-attach: prompt tag ; image_ref expanded per request in coding.async.request
- read_file : binary/image refusal, default offset was TRUE [ 5 ] -> 1
- fetch-files : reply_id fix, resume after cdn resets, 16 MiB http/2 window [ ~10x ], hf-status, hf-remove [ purge own downloads, no sudo ], base.chmod_child.start/request [ shared, fetch-files uses it ; coding/ncode still own copies ]
- spawn planner : gpu_layers 999 [ -ngl 999 incl. output layer ], exact kv from gguf [ models.gguf.file.extract_attention, hybrid qwen35 = every 4th layer ], kv_cache_type auto [ f16 ; q8_0 only if f16 + moe offload misses the floor -- q8_0 cuts prompt ~10x on this build ], moe --n-cpu-moe by binary search, floor no longer forced over exact kv, reasoning budget 8192, cpu_ram_overhead_mb 4096, check_resource_fit counts ram, switch reap poll [ SIGCHLD unreliable : competing waitpid(-1) ]
- tools : core set + load_tools groups [ coding.tools.groups ], base ~13k -> ~3.8k tokens
- model batch : baseline pack [ chunked, 0.2 s budget ], blobs raw, undef errors [ 'return warn' gave 1 ], chmod-child revert/restore, score.task [ criteria on written files, re:, compile check ], repeat: N, :restart:, per-task log lines
- models : names from -GGUF repo dir, garbage names [ Hf Download, Ours ], switch-model re-fetches stale cache

**Results [ coding-14b-compare, 3 runs ]** fablevibes 14b-a3b [ 72T4WFI:TK55OIY ] 9/9, ~50 t/s, vision ; OFSQC4I label edit 0/3 compiles. dense security 14b : 17k ctx, useless. fable5 9b deleted, heretic-distill 9b purged.

**In flight** 35b-a3b distill [ empero-ai ] : IQ4_XS UQPANRQ:JGOV2GY works [ 23/41 expert layers in ram, 52k ctx, 29-34 t/s ] but loading pushes memory pressure critical ; Q3_K_M UWEPZFQ:TG3Q7PA being tested -> keep the better, hf-remove the other. then batch coding-35b-compare. user decides default model [ fablevibes candidate ].

**Open** todo 2AA [ ondemand request lost in idle shutdown ], OQC [ whitelist ], RC7 [ difficulty routing ], YLL [ apply-colors, kimi-ready ] ; hf-remove reply ends in literal \n ; dense floor offload not done. rule : [[no-tree-edits-while-model-batch-runs]].

#,,.,,..,,..,,.,.,,..,,.,,,,.,...,,..,,,,,,.,,..,,...,...,...,..,,,.,,,..,.,.,
#RHWNXSQUY3WDFCC7FTTGOZEYW3Y4VOB3GOENJJ2YZNRDEC6EUHJHUCI4SHE6IEGTR74RFAOYQJF6O
#\\\|FFOKFTXBUU7BSUWIL55OR37MKVXQBUSELXXDYUYH5L3X67NKIIE \ / AMOS7 \ YOURUM ::
#\[7]JXAH3EKSLDM5LJPRQQ3S2GUTRMDLFP3WKP25J4QWVXRRKNJJDIAY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
