---
name: project-2026-09-29-invoke-images-session-handover
description: handover of the 2026-09-29 session [ ntime fix, invoke-web rebuilt, image.analyze + image index, many briefs ] -- what runs, what is open, where the briefs are
metadata:
  type: project
---

**running when the session ended [ 2026-09-29 ~13:00 ]** :
- image index job in invoke-web [ `p7c invoke-web.index status` ] :
  ~49215 invoke.ai images, ~0.2s each, resumable [ `index start` skips the
  indexed ones ]. index : /var/protocol-7/invoke-web/state/image-index.db,
  lazy backup /mnt/ext-xfs-data/p7-images/image-index.db. final log line
  `image index done : ..`. 25 early `failed` = missing files counted
  before the missing-handling fix -> a re-run records them as missing
- invoke.ai rendering the queue [ ~66 pending ], interactive mode on
  [ new ui items first ], drain after 4620s idle [ not while indexing ]

**built today** [ commits cae127ef0 .. a8756f568 ] :
- `p7_ntime` : harmonic step-back on the RETURNED value, no sleeps
  [ fixed the 70ms cube reply stalls ] ; b32 : harmony on the encoded value
- v7 -> v7-zenki reference sweep [ memory, docs, tasks ] ; v7 sig_chld
  fallback by process id [ phantom 'online' instances ]
- invoke-web rebuilt : see [[reference-invoke-web-run-user-and-invokeai-facts]]
  [ run user, output parsing, queue control, sessions, drain, memory guard,
  async api, requeue from the queue db, render outcome check incl. silent
  failures via the result image ]
- models : live db path, snapshot as root via runuser, `$ARG[0]` fix
- `image.analyze.file` [ shared layer : 1x1..3x3 tiles, hsv, luma,
  entropy, flags, png text ] ; graphics-matrix color_sample fixed with it
- image index [ BMW-L13 of content as key, prompts hash-only ]

**open, with briefs in data/tasks/** :
- render tests still due : memory guard waiting case, drain after idle
- `coding-invoke-awareness.md` : coding waits for invoke.ai via dependency
  object [ present invoke-web -> status -> notify_offline ]
- `v7-zenki-keep-children-on-crash.md` : keep + reattach children on a
  crash restart [ invoke.ai, X-11 ] -- output pipe \ SIGPIPE problem first
- `invoke-missing-model-autofetch.md` : trigger = 2nd complaint ; 37 of 117
  missing fetchable from db metadata, 80 local-only [ hash lookup \ backup ]
- `invoke-web-queue-sessions.md` [ park built ; cold resume via the task
  zenka's gpu cooldown ], `invoke-web-interrupted-item-requeue.md`,
  `invoke-web-startup-memory-guard.md`
- `images-elfdb-feature-collection.md` + `images-elfdb-landscape-survey.md`
  : planning base for the new zenki, see [[project-images-elfdb-planning-base]]
- next index steps : use the data [ color wheel from hue \ sat, duplicates,
  model \ lora graph ] ; index new renders at `render done`

**Why:** the session reached ~940k tokens ; compaction and cache expiry
would lose the thread.
**How to apply:** start from here when invoke-web, the image index, or
images \ elfdb come up ; check `index status` first.

#,,.,,.,.,..,,..,,..,,,,,,,..,,..,..,,,,,,..,,..,,...,...,..,,..,,,,.,..,,...,
#HE2I2P5IDGAU7QUQMRMEDJKWVUUYQDYBQETSODS347SOYZXNUKLLX442CIDF267HG6OW2NOSEPWOA
#\\\|NJSMA2UZSFDBFZO3H4TUMQV44UXTZHIGWZKGBJ7KZ5LQOBYBFTY \ / AMOS7 \ YOURUM ::
#\[7]ZDAZBIX6N6BFC7T3ETOOL4KQGTGQZM37LIQVJ7GX3RW27SQ4XYCI 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
