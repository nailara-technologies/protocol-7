# invoke : detect missing models at render time, fetch them automatically

planning brief [ 2026-09-29 ]. not built. read `CLAUDE.md` first.

the concrete trigger for layer 4 [ on-demand model lifecycle ] of
`data/md/design/AUTONOMOUS-MODEL-MANAGEMENT.md` [ subsystem #5 ] : states
present \ zeroed \ missing \ quarantine and "auto-fetch" are sketched there,
the trigger and the path from detection to download are not.

## situation

- invoke.ai's db lists 312 models, 117 of their files are missing [ lost on
  disk ; startup logs one `Missing model file: <name> at <path>` line each ]
- manual recovery exists : `bin/scripts/invoke-ai/invoke-model-recover`
  [ --dry-run \ --download \ --type ; db metadata -> download ],
  `invoke-model-prefetch`, `invoke-model-backup`, `invoke-symlink-repair`
- the fetch-files zenka downloads from huggingface with hash verification
  and a lan check [ `src/fetch.file.huggingface.*` ] -- the intended home of
  the download part [ user, 2026-09-29 ]
- invoke-web reads invoke.ai's output line by line since 0dfb27c8b
  [ `invoke-web.parse_output_line`, pattern table in init_code ] and counts
  the missing models [ `<invoke-web.missing_models>` ]

## detection [ the trigger rule, decided 2026-09-29 ]

1. startup : invoke.ai complains once per missing file -- COLLECT only
   [ `<invoke-web.missing_models>` becomes a list : name, path, first seen ],
   no action
2. TRIGGER = a SECOND complaint about a model already on that list : that is
   almost certainly a render attempt referencing it. only then resolve and
   fetch [ per policy below ]. this also answers "which of the 117 are worth
   fetching" : exactly those something actually asks for
3. still collect the exact line of that second complaint and the item status
   it goes with [ unknown yet : pattern to add once seen ] -- it ties the
   fetch to the failed item for the re-queue [ see tie-in ]
4. later, optional : proactive -- pending queue items -> the model keys
   their graphs use [ queue api ] -> intersect with the list -> fetch before
   the item runs

## resolution

model key -> invoke.ai db record [ `source`, `source_type` : hf repo \ url \
local ] -- the same mapping invoke-model-recover uses [ reuse it, don't
duplicate ] -> a fetch-files job [ hf download, hash check, lan-first ] ->
place the file where the db record expects it -> have invoke.ai rescan
[ api : find the endpoint ; `/openapi.json` on port 4707 ].
`source_type` local \ no source : cannot be fetched -> report only.

## policy [ zenka.v7 flags ]

- `auto_download = off | ask | on` [ ask : a notification \ command to
  confirm, e.g. `invoke-web.fetch-missing <name>` ]
- size limit per model and in total, disk pressure check before fetching
- the `:keep:` flag and lru zeroing from the design doc [ later, #5 ]

## tie-in : re-queueing

an item that failed on a missing model is identified by invoke-web itself
[ render-time detection ] -- after the fetch it can be retried safely via
`retry_items_by_id`, without the manual-cancel ambiguity described in
`data/tasks/invoke-web-interrupted-item-requeue.md`. build both on the same
item record.

## observed [ 2026-09-29, items 15755 \ 15756 moved to the front with
## `invoke-web.queue-front` ]

- second complaint :
  `::ERROR --> Error while invoking session <session>, invocation <id>
  [ sdxl_compel_prompt ]: Files for model '<name>' not found at <abs path>`
  -- the SAME model name as the startup `Missing model file: <name> at
  <path relative to the model root>` line : match on the name
- item status via api : `failed`, `error_type` FileNotFoundError,
  `error_message` = the same text -- unambiguous, never a manual cancel
  [ those are `canceled` ] : safe to retry after the fetch
- the item fails within ~0.1s [ at the prompt node, before any model load ]
- recorded since then : pattern `model_render` ->
  `<invoke-web.missing_at_render>->{<name>}` = path, item, session, time

## open questions

- how graphs reference models [ key vs name ] and how to read them from
  pending queue items
- invoke.ai's rescan \ install api for a file placed by us vs letting
  invoke.ai download it itself [ its own install api may be simpler for hf
  sources -- but fetch-files gives lan-first + our hash checks ]
- fetch-files job interface : what invoke-web sends, how completion is
  reported back [ callback \ event ]

#,,..,,.,,...,,,,,,.,,,..,,,.,,.,,.,.,,.,,,,.,..,,...,...,.,.,,,.,..,,.,,,.,,,
#NBARGKKTOCUCVJOO2VHCTHXGELSG7RTLJ4L6US7HKR567IDQOQJ44YG23DEOKIKVVNDDW5QZMUTEU
#\\\|D465KTQZHS7GAQIXXKMQTQDCZGOE4YKZDZN5MMQNMAUJUR7SIAI \ / AMOS7 \ YOURUM ::
#\[7]IGBAJ44CFTNGV44LNNFSNRQBORWWY5GMK7NKMXI2DAC3NUTRKKAQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
