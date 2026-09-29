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

## the idea [ agreed direction, not built ]

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
  still open : the line of a ui cancel [ collect with `invoke-web.log` ]
- what invoke.ai does with an in-progress item at startup after a crash :
  status `canceled`, `failed`, or still `in_progress` \ picked up again ? if
  it resumes the same item itself, nothing must be retried
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

#,,,.,...,...,,,.,,.,,,,.,..,,.,,,.,.,.,.,...,..,,...,...,...,,,.,..,,.,,,.,.,
#3MY5VFCJIP3JARROJBXIALLWDAKOPLMCZTKY7CDQAS5PBOA4TWXUXR7EHNCV4MYTYDNQBNJAMW5YA
#\\\|CH6FMJRPOWUMD5Y62DOEYXRUPHKWMR4A42Y7IOFTO27HPAQJWEY \ / AMOS7 \ YOURUM ::
#\[7]4Z6BJACNBHYQ56ZBDPQQVHVZJTBBG4UDAWFA3G53DPPD3N2LMMBI 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
