# invoke-web : change waiting jobs, reference scale per image

status : IDEA 2026-11-28 -- owner agreed to note both, nothing built.

## 1. queue-set : change parameters of waiting jobs

- 2026-11-28 : 52 images queued with the turbo lora at 8 steps, then 13 looked better. done by
  hand : backup of invokeai.db, one write transaction over session_queue rows with status
  'pending', every qwen_image_denoise and core_metadata node `steps 8 -> 13` [ 51 items, 102
  nodes, the running item left alone ]. invoke.ai reads a job only when it dequeues it.
- wanted : `invoke-web.queue-set <key>=<value> .. [ filter ]` -- keys at least steps, cfg_scale,
  seed offset, lora weight ; filter by item ids, batch, model, current value [ eg. steps=8 ].
  backup first [ named, kept n ], pending items only, a dry run that lists what changes, the
  metadata node changed together with the denoise node [ the saved image tells the truth ].
- reuse invoke-web.queue.db [ the direct db access requeue already has ].

## 2. reference images : scale as a choice per image

- the resolution of a reference is a creative control, not only a memory question :
  - full resolution : close reproduction, random defects copied precisely [ noise,
    compression artefacts ] and hard to prompt away
  - smaller : composition, shape, identity carried ; qwen invents the detail and copies fewer
    defects
  - but an organic subject [ eg. a kitten photo ] wants full resolution again : its real
    texture is the point
- so : never an automatic step. per reference `ref_scale=<f>` or `ref_max=<px>` [ long edge ],
  none = the original. the scaled copy cached by the original's checksum [ bmw, never sha ],
  the original untouched.
- side effect : less vae encode memory for large inputs [ the references of the 2026-11-27
  renders were mostly at target resolution already -- not the main cause of that slowdown,
  render-stats readGB points at page cache eviction ].

## rules for the implementer

no sha, no json internally [ invoke.ai's own session json is the external format : touch it
only inside the db step ] ; lowercase comments with [ ] brackets ; perl floor 5.32 ;
bin/format-code -r then -c ; new commands need their zenka.v7 list, gen-sub-whitelist and access
entries ; no commit, no sign, no reload ; never touch files you did not change.

#,,..,,,.,,,,,.,.,.,.,.,.,,,.,,,,,.,,,,..,...,..,,...,...,,.,,,..,.,,,,,.,...,
#OX4LILIG7FBXFDZY75K7TSJS3IOMX5QA2ZPP5RLK46E7OGHH64OLBMZAYAML6AQI4LUCYVSVORT26
#\\\|MU5VCHSB3EELMKPM67XK4I6YQBVKQOJ5GPFLCDEQT2C4P57M2HJ \ / AMOS7 \ YOURUM ::
#\[7]FU7Y3B6KNUIJC3Q323GWRHETT7GVKUCUOTCNWYKP6RUHVEPDZYCI 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
