# invoke-web : change waiting jobs, reference scale per image

status : IMPLEMENTED 2026-11-28 -- copied db + stubbed api verified, not live run.

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

## findings [ kimi ]

- installed fork read-only investigation [ python 3.11 env `invokeai-qwen21`, package root
  `/home/taeki/miniconda3/envs/invokeai-qwen21/lib/python3.11/site-packages/invokeai` ] :
  - `app/invocations/fields.py:251-254` : `ImageField` is exactly `{ image_name }`.
  - `app/invocations/qwen_image_text_encoder.py:128-131` : the text node takes
    `reference_images: list[ImageField]` ; `:175-176` passes each `image_name` to
    `context.images.get_pil`.
  - `app/invocations/qwen_image_image_to_latents.py:41-58` : the VAE node takes `image` plus
    optional `width` / `height` ; `:142-161` reads `self.image.image_name`, resizes only when
    both dimensions are positive, then snaps to the model grid.
  - references ARE resized internally in the text/vision path :
    `qwen_image_text_encoder.py:143-168` is the resize, `:172-185` applies 1024x1024 pixels
    for qwen-image 2.1 and 512x512 for older qwen-image. this is separate from the VAE path.
  - older qwen-image also clamps VAE reference latents to 1024x1024 pixels in latent space :
    `qwen_image_denoise.py:232-261`, used at `:423-439`.
  - qwen-image 2.1 does NOT use that clamp : `:661-674` loads and concatenates every reference
    latent at its supplied size, and `:713-715` joins them to the target tokens at every step.
    therefore the queued i2l width / height must shrink with the uploaded image ; replacing only
    `image_name` would resize the small copy back up and lose the latency benefit.
  - upload route : `app/api/routers/images.py:87-117` accepts multipart `file` at
    `POST /api/v1/images/upload`, with `image_category` and `is_intermediate` query parameters ;
    `:185-203` creates a new image and returns its DTO [ including the new `image_name` ].
- entry point chosen : a pending-job rewrite command, not an automatic queue-time option.
  `invoke-web.ref-scale <id ..> [ refs=<n,..|image_name|all> ] <ref_scale=f|ref_max=px>
  [ :dry-run: ]`. repeat with another `refs=<n>` for a different scale on another reference.
  no invocation means the original. this fits queued workflows and shares queue-set's safety
  model.
- ref-scale uses the already-loaded `Imager`, BMW-L13 of the original content, and a persistent
  text upload map under `state/ref-scale` [ override : `invoke-web.ref_scale.cache_dir` ]. the
  original file is never written. the new upload replaces all matching reference `image_name`
  fields, their metadata dimensions, and the connected `qwen_image_i2l` dimensions. dry-run does
  no cache writes, uploads, backups, or db writes.
- queue-set syntax : `invoke-web.queue-set steps=13 items=3033,3034 where steps=8
  [ :dry-run: ]`. assignments : `steps`, `cfg_scale`, `lora_weight`, `seed_offset` [ signed,
  modulo 2^32 ]. selectors : `items`, exact `batch`, substring `model` and `lora`. `where`
  filters current `steps`, `cfg_scale`, `lora_weight`, or `seed`.
- both commands select and update `status = 'pending'` only, create a named sqlite-api backup,
  retain 13 per operation by default [ `invoke-web.queue_backup_keep` ], and commit every changed
  item in one transaction. an item that leaves pending before update rolls the transaction back.
  steps / cfg / seed update denoise and core_metadata together ; lora weight updates the loader
  and core_metadata together.
- verification : 30 checks passed against sqlite-api copies under `var/tmp-kimi`, real Imager
  output, and stubbed uploads [ including the real multipart request builder with fake LWP ].
  covered dry-run, filters, running-item exclusion, backup contents, denoise / metadata parity,
  lora parity, seed offset, reference dimensions, original preservation, persistent BMW cache
  reuse, and uncapped originals. `bin/format-code -r` then `-c` passed for all six new src files.
  no live invokeai.db write, state-changing api call, reload, restart, sign, or commit was done.

## findings ref-transform [ kimi ]

- added `invoke-web.ref-transform` with per-reference clockwise rotation, horizontal / vertical
  flip, and optional scaling. operations always run rotate, flip, scale ; dry-run reports every
  reference's dimensions and ordered operations. item selection, reference selection, pending-only
  transaction backups, rollback, and explicit `:resume:` reuse the existing queue path.
- `invoke-web.ref.scale` is now a compatibility wrapper around `invoke-web.ref.transform` ; its
  options, scale cache tags, result fields, and command output are unchanged. checksum, original
  file reads, cache, upload map, and user-category upload exist only in the shared helper. operation
  suffixes follow the original BMW checksum [ eg. `-r90-fh-m384` ] and originals are never written.
- graph rules : v7 swaps only image names ; fork qwen-image 2.1 retains i2l dimensions except for
  swapping width / height on 90 and 270 degree turns ; older qwen-image follows transformed image
  dimensions. non-qwen models are refused.
- 34 checks passed against copied v7 and fork sqlite databases under `var/tmp-kimi`, a real small
  Imager image, persistent cache reuse, and stubbed uploads / resume. covered combined operations,
  dry-run output, scale compatibility, all three graph rules, model and option refusals, named
  backups, original byte preservation, and cache reuse. no live invokeai.db write, real api
  mutation, reload, restart, sign, or commit was done.

## findings prompt-replace [ kimi ]

- added literal positive / negative prompt replacement with end-only selectors, optional quotes,
  deletion, qwen text encoder + core_metadata parity, and shortened per-item dry-run output.
- shared pending selection and one-transaction backup / write / rollback now serve queue-set,
  ref-scale, and prompt-replace ; queue-set's lora behavior and existing replies are preserved.
- ref-scale's level 1 log now reports items, references, and backup. whitelist regenerated.
- 24 checks passed on sqlite-api copies under `var/tmp-kimi` ; `bin/format-code -r` then `-c`
  passed for all seven changed src files. no live db / api mutation, reload, sign, or commit.

#,,..,.,.,..,,.,.,.,.,,,.,.,,,,,.,..,,,,.,,.,,..,,...,...,..,,.,,,...,.,.,,..,
#57X24TAVIZYXMXV25M7KTZNA56EEOVNVHMRG2O7HW6KV4EBNKGJCKHIHJCQ77BUCGVBBZ7XYRMFTA
#\\\|PKWRHGJURTRE4IXRWWGWF3PDHDRRTJKVHHRG4ZKQIFT345WPWRB \ / AMOS7 \ YOURUM ::
#\[7]C4EYOSF4OS5IP53HJGOZNZEFMRTWRTOUPYL2OCLDTPJO2IZHGODI 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
