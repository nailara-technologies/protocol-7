# invoke-web : re-queue render items interrupted by a restart or a crash

brief [ 2026-09-29 ]. read `CLAUDE.md` [ module syntax, style ] first.
context : the invoke-web rework of 2026-09-29 [ run user, line-wise output
parsing, `pause` \ `resume` \ `queue`, `start_paused` ].

## the problem

- invoke.ai resumes its queue on every start and runs the first item BEFORE
  its api accepts a pause [ `Executing queue item ..` ~50s before
  `Invoke running on ..` ] -- `start_paused` can only pause after that item
- an item interrupted by a stop, an idle shutdown, an invoke.ai crash or a
  WSL OOM shutdown ends up canceled \ failed and has to be re-queued by hand
- invoke.ai does not record WHY an item was canceled : a restart and a manual
  cancel in the web ui look the same afterwards. re-queueing every canceled
  item would bring back items the user canceled on purpose
- the user must not have to think about this -- but a wrongly identified item
  must never be re-queued

## the idea [ built : d759cb86d 31473dcf3 6ecd10ee9 ad19d2f76 ]

record the interruption where only invoke-web can see it : at the START of an
item, not at stop time -- so a crash or an OOM that takes the zenka down too is
covered [ the record is already on disk ].

1. `invoke-web.parse_output_line` sees `Executing queue item <id>, session
   <uuid>` -> write `state/current-item` [ item id, session id, batch id if
   known, ntime ] immediately
2. the item ends normally [ completion line ] -> clear the record
3. the item is canceled while the zenka runs [ ui cancel shows up in the
   output ] -> clear the record : a deliberate cancel is never re-queued
4. at the next `ready` : a record still present = interrupted. verify via
   `GET /api/v1/queue/default/i/<id>` : same session id, status not
   `completed`. then `PUT /api/v1/queue/default/retry_items_by_id` [ exists
   in invoke.ai 6.9, see `/openapi.json` ], clear the record, log it
5. automatic behind a zenka.v7 flag [ e.g. `invoke-web.requeue_interrupted =
   yes` ] plus a manual `invoke-web.requeue-interrupted` command

NOT allowed : canceling a running item to re-queue it [ the user : the queue
would lose it ]. only items invoke.ai itself already ended are retried.

## open questions [ check against invoke.ai before building ]

- completion : FOUND [ 2026-09-29 ] -- `::INFO --> Graph stats: <session>`
  carries the same session id as `Executing queue item <id>, session
  <session>` [ pattern `item_done`, sets `<invoke-web.render>->{done}` ].
  CORRECTION [ same day, item 15757 ] : graph stats also come for a FAILED
  item [ 0.038s, ram +0.000G ] -- it marks the END of an item, not success.
  the parser now sets `<invoke-web.render>->{failed}` on an error \
  model_render line of the running session, and a memory based sanity
  check [ no image decode node -- l2i -- ran with vram in use ; not the time,
  it depends on the hardware ] marks `suspicious` ; the record for requeue must use the
  outcome, never the bare graph stats line
  NEXT STAGE [ user, same day ] : a failure can also happen in the VAE decode
  after an uneventful diffusion. with an error line [ e.g. oom ] it is
  covered ; SILENT ones are not -- the classic sdxl vae fp16 NaN case gives
  a black \ garbled image with a normal looking graph stats table [ fittingly
  `sdxl-vae-fp16-fix` is on the missing list ]. needs a look at the RESULT
  image : 1x1 color near black, luminance histogram fully clipped, entropy
  near 0 or far off the normal range, implausibly small file size [ result
  path via api \ the images table for the item's session ]. this is the
  lightweight analysis layer of images-elfdb-feature-collection.md --
  build it once, use it here first
  still open : the line of a ui cancel [ collect with `invoke-web.log` ]
- ANSWERED [ 2026-09-29, a real crash : invoke-web killed by v7 mid-render ]
  : at startup invoke.ai sets the interrupted item to `canceled` with an
  EMPTY `error_type` -- indistinguishable from a manual ui cancel. it does
  not pick it up again. so the record written at item start is the only
  way to tell them apart [ as planned above ]
- does `retry_items_by_id` create a new item [ new id ] or reuse it -- the
  record must not match the retried copy on the next start
- does the item record carry a reason field [ error_type \ error_message ]
  that tells a startup cleanup apart from a user cancel -- would be a
  second, independent check
- several items in progress at once [ one queue, normally one item ] -- the
  record should be a list to be safe

## related, found the same day [ separate fix ]

`models.storage.adapter.invoke.export`, `.resolve`, `.repair` read
`$data{'models'}{'external.models.invokeai.path'}` -- a key that is never
set : `load_config_file` nests dotted names, the value lives at
`<external.models.invokeai.path>`. they ran on their fallbacks.

FIXED [ 2026-09-29, kimi dispatch, reviewed ] : all three now read
`<external.models.invokeai.path>`, fallback kept. the fallback
[ `/mnt/ext-xfs-data/models-invoke` ] equals the configured value, so no
path changes on this machine -- `repair` included. the config now takes
effect should the two ever differ.

verified live [ 2026-09-29 ] : `bin/format-code -c` on all three [ syntax
valid ] ; `models.reload` did NOT pick the edit up [ `p7c models.adapter-resolve`
kept returning empty ] -- `p7c v7-zenki.restart models` did. afterwards,
as uid 777 via `models.eval-code` : root visible, uuid subdirs visible ;
`p7c models.adapter-resolve invoke <name>` returns paths under
`/mnt/ext-xfs-data/models-invoke` ; `p7c models.adapter-export invoke`
wrote a complete 302-model yaml [ to its `/tmp` default -- the output_path
arg did not pass through ]. `repair` NOT run live [ per task rules ] --
code-read only : symlinks via `symlink()` + `File::Path::make_path` under
`<root>/<base>/<type>/<name>`, existing links skipped, `:dry-run:` flag
maps to dry_run [ no writes in that mode ]. surprise found while verifying
[ pre-existing, out of scope ] : modules read `$ARG`, which in live command
flows lags one call behind -- `resolve` can see the previous call's record.
export's per-record `on_disk` numbers are affected by that ; the config-key
fix itself is correct [ proven with a correctly-populated `$ARG` ].

#,,,.,..,,,.,,,.,,,.,,.,,,.,,,,.,,..,,,,.,..,,..,,...,...,,.,,...,,,,,,.,,,.,,
#QOOT5QI4YEWHMEZGC6ENKAA7KNYWX3LG5SZMHXQ7OABA4RMK6SILU6QRJTGMAL3QOOOX633GOEBRC
#\\\|EK7XNBEUNKVHQK5USPRF5KNNCLWMCKOCP5HHOWACZDDLWRPL7I6 \ / AMOS7 \ YOURUM ::
#\[7]WEY4PE3P4VBUBWX66GBEGKRHIZFICJBEKGO47FQ5ZF7LPK2FZKDY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
