# invoke : detect missing models at render time, fetch them automatically

planning brief [ 2026-09-29 ]. built 806f0e2ca + 70c76b819 -- not yet run
live [ `p7c invoke-web.fetch-missing <model>` ]. read `CLAUDE.md` first.

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
- invoke-web reads invoke.ai's output line by line since 138396484
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

## resolution : built [ 2026-09-29 ]

- `src/invoke-web.model.source` : model name -> invoke.ai db record[s]
  through the shared `<[invoke-web.queue.db]>` handle [ read-only
  selects only ] ; returns `{ name, found, records => [ .. ] }` with
  per-record `key` [ db id — graphs keying still the open question ],
  `type`, `base`, `format`, absolute expected `path` under
  `<external.models.invokeai.path>` [ bare-uuid and dir paths are
  diffusers directories ], `source`, `source_type`, `hash`,
  `fetchable` and a short `reason` ; the fetchable mapping mirrors
  invoke-model-recover's `get_download_url` : `hf_repo_id` and `url`
  = TRUE, `path` and anything else = FALSE
- `src/invoke-web.cmd.model-source` : `p7c invoke-web.model-source
  <name>` prints the record[s] ; unknown name -> false reply ;
  registered in `cfg/zenki/invoke-web/zenka.v7` access.cmd.usr.cube
  next to queue-front [ whitelist regenerated ]
- source_type distribution over all 312 records : `path` 274,
  `url` 18, `hf_repo_id` 20. of the 117 missing : `path` 80,
  `url` 18, `hf_repo_id` 19 — only 37 missing models are fetchable
  from db metadata ; 80 are local-path sources with no recorded
  origin, including today's two render failures
  [ perfection-cinematic-ilxl-v20-sdxl, realistic-improved-mix-v10-sdxl
  ] — a render failing on one of those cannot be resolved from the
  db alone [ needs external source lookup or backup restore ]
- duplicate names exist [ 15 names, e.g. sdxl-vae-fp16-fix : one
  local-path record + one hf_repo_id record ] — the module returns
  all records, each marked `name_collision`
- quirk found while verifying : invoke-model-recover --dry-run
  reports directory-style diffusers models with relative dir paths
  [ e.g. sdxl/main/perfection-realistic-ilxl-v32-sdxl, present on
  disk ] as MISSING — its get_filename fallback appends
  .safetensors, and the uuid-dir special case only covers bare-uuid
  paths

## trigger + fetch : built [ 2026-09-29, second round ]

- `src/invoke-web.autofetch` : called from the model_render branch of
  `invoke-web.parse_output_line` [ the second complaint ]. resolves via
  `<[invoke-web.model.source]>`, picks the first fetchable single-file
  record [ diffusers trees skipped -- not one download ], derives
  repo+file ONLY from the recorded source [ `hf_repo_id` with a
  `::file` suffix, or a huggingface `/resolve/` url ; bare repos and
  non-hf urls are report-only, never guessed ], then dispatches
  `fetch-files.hf-download` through `<[protocol-7.route-send]>` with a
  deferred reply handler -- never blocks the event loop. state lives in
  `<invoke-web.missing_at_render>->{<name>}->{fetch}` [ persisted by
  `invoke-web.missing.save` ] : seen | ask | fetching | done | failed |
  unfetchable. a lost reply is caught by a watchdog timer
  [ `invoke-web.handler.fetch_watchdog`, timeout cfg ] ; a zenka
  restart mid-download self-heals on the next trigger [ staged file
  size vs db size, a fresh dispatch truncates a partial ]
- the download lands in a staging dir [ `<invoke-web.autofetch.staging>`
  // `<external.models.invokeai.path>/.autofetch` -- fetch-files runs
  as the amos zenka user and cannot write the model subdirs ; the
  models root is world-writable and on the same filesystem ]
- `src/invoke-web.handler.fetch_reply` : on a verified download
  [ fetch-files checks the lfs sha256 before replying TRUE ] calls
  `src/invoke-web.fetch_finalize` : rename the staged file to the db
  path [ repo file name can differ from the db file name ] and run
  `<[invoke-web.requeue_missing]>->(<name>)` -- the failed items are
  retried, the record is deleted
- `src/invoke-web.cmd.fetch-missing` : `p7c invoke-web.fetch-missing
  <name>` forces a fetch [ the ask-mode confirmation ] ; no arg lists
  the recorded fetch states ; registered in zenka.v7 access.cmd.usr.cube
- policy [ zenka.v7, all default-safe ] : `invoke-web.autofetch.mode`
  = off | ask | on [ default off until tested ],
  `invoke-web.autofetch.max_gb` per-model size limit [ 0 = none ],
  `invoke-web.autofetch.timeout` watchdog [ 7200 ]
- startup 'Missing model file' lines now also collect
  `<invoke-web.missing_list>->{<name>}` = { path, first_seen } [ the
  counter is kept for cmd.status ]
- not built : diffusers tree fetch, github \ non-hf url fetch, repo
  file resolution for bare hf_repo_id sources [ needs a hf api repo
  listing -- fetch-files hf-list filters .gguf only ], the proactive
  pending-queue intersection, invoke.ai rescan api call after finalize

## open questions

- how graphs reference models [ key vs name ] and how to read them from
  pending queue items
- invoke.ai's rescan \ install api for a file placed by us vs letting
  invoke.ai download it itself [ its own install api may be simpler for hf
  sources -- but fetch-files gives lan-first + our hash checks ]
- fetch-files job interface : what invoke-web sends, how completion is
  reported back [ callback \ event ]

#,,..,,,,,...,,..,,,,,,,.,...,.,,,,,,,...,.,.,..,,...,...,...,..,,,..,,,.,.,.,
#AISUUQKTJ2W2ZHFFX7AHKMNHRPP6KBA4BK5KMAEV4WZDIB5FHQDLGZE3XOPZ6GLKHPKYINYO6R4UI
#\\\|7HO43ZYCTLWW7EKEPTSV7LMGN7JATPJY6JFCBQL5SPIFDAFZM22 \ / AMOS7 \ YOURUM ::
#\[7]LLBTVVYZYQRCT7JHALJGJ5RBKW34PSJVNBXSLJ3QZLDQH6YRE6CI 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
