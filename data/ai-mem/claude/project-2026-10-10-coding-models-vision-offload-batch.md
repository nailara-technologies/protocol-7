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

**Evening 2026-10-10** [ cd24c8e4a, 9219fb10d, 187fd277d + follow-up ] : tool json decode utf8(0) [ 'Wide character' on any en-dash ], edit_file delete:true, per-call tool failure log [ reason line ], manifest skips symlinks [ restore rename had replaced the README.md symlink ] and data/catalog-corpus, batch restore skips reload of an already loaded original, stop-task finalizes in_progress without async state, protocol-7 under systemd [ teardown exit code explicit or base.str.is_failure ], wsl 24 GB + mem.max_used 98, write tools strip a copied signature block, module criteria count in code only.

**Results [ coding-35b-compare + fablevibes-dims-check ]** q3_k_m 35b : 8/9 [ one loop stop on the doc, work done ], all modules compile, ~38 t/s, min avail 9.2 GB. fablevibes : doc + edit 6/6 at 60-73 t/s ; module 0/3 from a literal \n in the edit_file schema text [ blank-line abort at round 2, reworded -> no abort ], then 0/3 compiles + wrong parser + copied signature block. fablevibes for edits \ docs, 35b for new code.

**Late evening** [ 52434950a .. 0731248a7 ] : 6VC whitespace-abort round retry ; per-request harmonic seeds [ base.prng.harmonic_seed, execution.round_seeds, batch records ] -- set in coding.async.request, the first request never passes send_request ; X33 isolated loop check [ DONE \ NOT_LOOP \ LOOP, LOOP tested live, DONE not yet seen live ] + per-task loop counter [ was global ] ; read_file shows the signature block as one marker line [ models copied it \ looped on '#::::' ] ; batch criteria whole-file again + 'code:' prefix ; YLL bin/dev/apply-colors [ kimi k2.8, reviewed -- kimi also copied a signature line ] ; WNF work modes :mode:<path>: [ coding.mode.setting, model as a :model: pin, queue grouping via the pin deferral + drain timer, tested live with a real 35b switch ]. gotcha : intake's ':word:' template stripper eats new ':tag:' markers -- exclude each one [ :model:, :mode: ].

**Gotchas** committing \ signing while a batch runs = those files reverted [ cancel + :restart: after commits, never :force: ] ; Monitor pipelines must not end in cut [ buffers : monitor silent ] ; memory files are repo tree too ; a literal \n in a tool description can make a model emit endless newlines.

**Open** todo 2AA [ ondemand request lost in idle shutdown ], OQC [ whitelist ], RC7 [ difficulty routing ], YLL [ apply-colors, kimi-ready ] ; hf-remove reply ends in literal \n ; dense floor offload not done. rule : [[no-tree-edits-while-model-batch-runs]].

#,,.,,,.,,,,.,,.,,,..,,,.,,,,,...,...,..,,,,,,..,,...,...,.,.,,.,,,..,,,.,.,,,
#7362VREYCLLB7G6CRR63RMQ6NYSR25HJCFZHW7LGJCA5KQCXAWTWMVXKSYHR5IYEPEPX7TKUBBAOC
#\\\|OHUBFETRN2S7KSJF7Y4DMQ54UPODV2MCAFXZVAJEINLCZROEFGA \ / AMOS7 \ YOURUM ::
#\[7]AA72QLIINYDYHZMZITE63GHYTLBK7NAXGL4WLPJ35BP2PLQGGCCA 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
