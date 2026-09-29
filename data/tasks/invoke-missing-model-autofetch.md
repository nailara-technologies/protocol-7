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

## open questions

- the error line \ status of an item failing on a missing model
- how graphs reference models [ key vs name ] and how to read them from
  pending queue items
- invoke.ai's rescan \ install api for a file placed by us vs letting
  invoke.ai download it itself [ its own install api may be simpler for hf
  sources -- but fetch-files gives lan-first + our hash checks ]
- fetch-files job interface : what invoke-web sends, how completion is
  reported back [ callback \ event ]
- does the second complaint name the model the same way as the startup
  line [ name vs key vs path ] -- the match between the two must be exact

#,,.,,.,,,...,..,,,.,,...,.,,,,,,,...,,.,,,.,,..,,...,...,,..,,,,,.,.,,,,,,.,,
#LCBG6BBEZVPMVLRBTRTVHVXLFKTIVK2NYBTXMYENOAIHNLW4ZGAA6ARQTBCHYMC4HDI5H7LI2RD5G
#\\\|YT6N4K4V2BCA2CI4PVPNV2URTTMTUX3OEANXB5KNNWWYBQ2J56C \ / AMOS7 \ YOURUM ::
#\[7]PBEXINNMEBC3AIT3SXK5F4TVA7WXPLQUTHRXQ54DY6XKAQFGSECQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
