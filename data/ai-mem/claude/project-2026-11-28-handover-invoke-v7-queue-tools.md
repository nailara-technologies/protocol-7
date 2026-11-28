---
name: session-handover-invoke-v7-queue-tools
description: 2026-11-28 handover -- invoke.ai v7 beta 3 live as variant v7 [ merged gallery, gguf encoder, lora works ], queue tools queue-set \ ref-scale \ prompt-replace, n7fs place oom still open, stall grace live on all hosts
metadata:
  type: project
---

state is in git [ base ; last pushed f29d24e211-era ; later commits local until the next push ].
continues [[session-handover-hotspot-keepalive-drills]] [ 2026-11-27 ].

## landed since the 2026-11-27 handover

- release AMOS7-v6.91.4 deployed to the four servers [ yourum zulum delta atom ] ; atom's
  v7-zenki had been busy-polling [ evidence /var/protocol-7/v7-zenki-spin-2026-11-27/ ],
  restarted. Filesys::Statvfs : tracked marker + debian mapping + one-notice fallback,
  apt-installed everywhere [ auto-install worked on yourum + zulum ]
- e0636913ab heartbeat stall grace [ a late timer reads input first, one grace per silence ]
  -- deployed to all four servers. base set-up global heartbeat 19 s, 27 s for events X-11
  task discover system, invoke-web 47 s
- 390d5d6bed n7fs place drops committed dirty shards [ kimi ] -- NOT the cause : the oom
  is a WORKER spike [ 1.8 -> 11.3 GB in < 4 min, see below ]
- invoke-web queue tools [ 2f0af23c30, 1c2b1f2fa4 ] : `queue-set` [ steps cfg_scale
  lora_weight seed_offset ], `ref-scale` [ per model : qwen 2.1 swaps the image only ],
  `prompt-replace <old> :. <new>` [ follows the string node into encoder + metadata ] ;
  selectors items= last= * batch= model= lora= ; tags :dry-run: :resume: :neg: ; shared
  invoke-web.queue.select \ queue.write ; backups hold only the PENDING rows [ a whole-db
  backup of v7's 629 MB db blocked the loop past the heartbeat ]
- invoke.ai v7.0.0-beta.3 [ upstream, not on pypi ] : env invokeai-v7 [ py 3.12, torch
  2.7.1+cu126 ], source ~/src/invokeai-v7 [ webv2 built with `pnpm exec vite build`, the
  plain build runs slow ui tests that time out here ], root ~/.invokeai-v7 : merged db
  [ 55,566 images from ~/.invokeai + ~/.invokeai-qwen21, both originals untouched ],
  outputs/images -> the shared folder on the external disk, models/ = 240 links into both
  old roots, 208 model entries [ dup by hash, stale dropped ]. 5b641fd066 variant v7.
  config : host 127.0.0.1, multiuser false [ owner : no account now ], image_index_enabled
  false, keep_ram_copy_of_weights true, partial loading, ram cache 12, vram 5.5, working 4.5
- v7 models : qwen 2.1 mains re-registered in place [ base qwen-image-2-1 ], encoder
  Qwen3VL-8B-Instruct-Q4_K_M.gguf [ 5 GB, curl -C - download, the installer broke at 2.8 GB ]
  + vision tower mmproj F16 ; vae + 2.1 loras PATCHed to base qwen-image-2-1 [ never
  delete a v7 model entry : it deletes the file, here links into the fork's dir ]
- 3f30524e52 patch : qwen 2.1 and flux.2 read up to 10 references
  [ data/patches/invokeai-v7/ ; ~2 GiB prefix cache per reference per cfg branch ]
- the turbo lora IS wired into v7 jobs [ qwen_image_2_1_lora_collection_loader ] -- the fork
  never applied it [ the cause of "13 steps behaved like no lora" ]

## findings that change the picture

- qwen 2.1 [ fork and v7 ] : every reference costs ~4096 tokens [ encoder sizes it to
  ~1 MP ] -- smaller references are NO speed-up, only softer [ shrunk i2l dims = shape
  mismatch, 2026-11-28 ]. fewer references is the only lever
- the fork expanded the int8 encoder to bf16 [ ~16 GB ] -> cpu encoding at 101 %. v7 keeps
  the gguf encoder quantized
- slow renders 2026-11-27 : readGB 10-14 per image [ keep_ram_copy false re-read weights
  from disk ] ; v7 cold start 152 s/step, warm run pending at handover time
- windows froze \ firefox crashed : wsl page cache [ ~20 GB ] counts against windows ;
  `sync; echo 1 > /proc/sys/vm/drop_caches` frees it ; .wslconfig memory 20GB +
  autoMemoryReclaim=dropcache considered [ needs wsl --shutdown ]

## open

- n7fs place on azurum : a WORKER child spikes to 11.3 GB and is oom-killed -- likely one
  large node read whole ; find the node, give kimi a 4-8 GB single-file reproduction.
  yourum + zulum still miss tier A nodes [ drills fail : address not in sealed map ]
- the hugging face token was printed into the 2026-11-28 transcript [ invokeai.yaml ] :
  owner to renew ; v7's yaml has no token yet
- ref-scale \ prompt-replace node names for v7 [ qwen21_ref_img_*, qwen_image_2_1_i2l,
  qwen_image_2_1_model_loader ] ; queue-set already matches /denoise/
- lease guard : renewals stopped once while invoke-web ran normally [ cause unknown ]
- task note sections open : data/tasks/deploy-deps-and-atom-spin.md 1 3 5 6 7 8 9
- pull-git started on the plain zenka path once on zulum [ no cause found ] ; n7fs exit
  codes [ missing vault = rc 0 ] ; drill \ place notices carry no user \ dry_run
- v7 multiuser : an account later, invoke-web then needs api auth

#,,,,,.,,,,,,,,,,,.,,,..,,.,,,.,.,...,,,,,.,,,..,,...,...,...,,,,,,.,,,,.,..,,
#6LH4M2YPE3K4BJICPL7D7TSAEYBI6SXVASSNOK426BWBH2UK5RSCWGT6FOLAZ3J6YAC3WFQL77DII
#\\\|MCK2VFJXKUJSUS4ZLJ3RO6WSA7WCKWTI4L445FOHLX4YJJ2ZQUO \ / AMOS7 \ YOURUM ::
#\[7]DIBEMEDJHMSLWRCVIOP6FBJIR2JJQJQDTN6QSDAOYH4WIAIGTOCA 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
