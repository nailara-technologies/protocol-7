# Job-Site-Scan Major Refactor — May 12 2026

> Extracted from MEMORY.md. See main memory for cross-references.

## Coding Zenka Event Loop Safety
- **drain_pipe**: Single `sysread` per io-watcher invocation, no `while(1)`. Cancels watcher on EOF/EBADF.
- **wait-done**: Deferred reply pattern with timeout timer. Returns `{mode => 'deferred'}`, registers in `$data{'coding'}{'deferred_replies'}`. Fast path for already-completed tasks.
- **deferred_reply**: Cancels timeout timer on task completion to prevent race.
- **Deleted**: `coding.handler.http_poll` (dead code).
- Files: `modules/coding.handler.drain_pipe`, `modules/coding.cmd.wait-done`, `modules/coding.handler.wait_done_timeout`, `modules/coding.handler.deferred_reply`

## Session 24 changes (2026-05-14)
- zenka renamed `job-site-scan` → `jobsite` (89 files, all modules, config, /etc/, /var/)
- assessment prompt switched JSON → YAML heredoc; `assess-done`/`repair-done` use
  `YAML::XS::Load` as primary parser, JSON regex kept as fallback
- per-element YAML storage: one file per job in `/var/protocol-7/jobsite/jobs/`,
  lightweight `index.yaml`; migration from `store.yaml` on first load
  new modules: `jobsite.job.read`, `jobsite.job.write`, `jobsite.job.load_all`,
  `jobsite.index.rebuild`
- `flush_on_acquisition` extracted from `kimi.handler.approval_request` →
  `kimi.flush_on_acquisition`; hashref iteration bug fixed in the process
- kimi sudo auto-decline: `kimi.handler.approval_request` rejects sudo tool calls
  with message; `kimi.wire.approval_respond` accepts optional decline reason

## Job Assessment Pipeline — New Features
- **Checksum dedup/blacklist**: AMOS7 for companies, BMW-L13 for titles/urls. Zero raw string storage.
  - `jobsite.checksum.index`: check/add/blacklist_company/persist/stats operations
  - `jobsite.cmd.blacklist-add`, `jobsite.cmd.blacklist-stats`
- **Assessment validation**: Detects `empty_reason`, `empty_summary`, `wrong_language_english`, `wrong_language_chinese`
- **Repair pipeline**: Auto-dispatches repair on first defect. Accepts if improved, marks `repair_failed` on second failure.
- **Protected stages**: `applied`/`responded`/`rejected`/`archived` survive pipeline overwrites.
- **Assertion trees**: Per-job valued tree with `suggest.{apply,delete,archive}` + 8 dimension scores parsed from model JSON.
- **Encoding fix**: `jobsite.util.fix_encoding` repairs mojibake (ISO-8859-15 first, then ISO-8859-1).
- **Ghost queue fix**: `jobsite.state.load` resets `queued`/`assessing` tasks to `idle` on restart.

## Proxy & Network Fixes
- **site-yaml.init_code**: Added `$ua->env_proxy()` to actually use `HTTP_PROXY`/`HTTPS_PROXY`. `bypass_proxy` config now works.
- **Pagination**: `site-yaml.import_max_pages` config (default 1, cap 5). StepStone uses `?page=N`.
- **Rate limiting**: Configurable delays `import_delay_search` / `import_delay_detail`.

## Fetch Queue Architecture (Async)
- **site-yaml.fetch.state**: Load/save queue + delay state from `zenka_dir/fetch-state.yaml`
- **site-yaml.fetch.backoff**: Discrete adaptive delay. ×1.5-2.0 (with jitter) on 403 error. ×0.9 after 3 consecutive successes. Clamped to min/max.
- **site-yaml.fetch.schedule**: One-shot timer manager. Fires drain callback when queue empties.
- **site-yaml.handler.fetch_tick**: Pops one URL, fetches, handles 403 (re-queue front + backoff) vs transient errors (retry ×2), persists state, reschedules.
- **site-yaml.cmd.import**: Queues job URLs instead of inline fetching. Search pages still fetched synchronously.
- **jobsite.dispatch.assessments**: Extracted assessment queuing logic.
- **jobsite.handler.fetch-drain**: Callback fired when queue drains → triggers assessments.
- **jobsite.handler.fetch-done**: Waits for queue drain before dispatching assessments.

## Prompt Improvements
- **English-first-then-German**: Step 1 analyze in English, Step 2 output German JSON.
- **Explicit candidate framing**: "Alexander Taute is a Senior Software Architect... He is NOT the job description."
- **UTF-8 guardrail**: "Use proper umlauts (ä ö ü ß) — never escape them as ae oe ue ss."
- **Shared prompt builder**: `jobsite.util.build_prompt` used by both dispatch.assessments and dispatch.repair.
- **show-prompt command**: `jobsite.cmd.show-prompt <job_id>` returns the exact prompt the model would receive.

## HTML UI Updates
- **New filters**: `löschen` (delete-suggested), `fehler` (repair_failed)
- **Assertion badges**: `bewerben` (green), `löschen` (red), `archiv` (gray)
- **Repair badges**: `repariert`, `fehler`
- **Dimension grid**: Expandable with color-coded scores
- **CSV export**: 11 new assertion columns
- **Print table**: Apply/delete checkmarks + dimension list

## Export Script Updates
- `bin/dev/export-jobs-json`: Surfaces `assertions`, `repair_applied`, `repair_failed`. Maps `blocked` → `skipped`.

## Commits
- `ac1fc96a6`: jobsite rename+refactor pipeline + coding zenka event loop safety + proxy config fix
- `2f4ede445`: export script + HTML UI assertion support
- `b9467a894`: proxy env fix, pagination, rate-limiting delays, encoding repair, ghost queue fix
- `3b0dd9e40`: fetch queue with adaptive backoff + clean logging

#,,,,,.,,,,..,,.,,..,,..,,,..,,,.,..,,,,,,,.,,..,,...,...,...,,,.,..,,,..,..,,
#ABCCSMRSQX4O3JLDN6JMEXGBEGAFGHRZMWHFASKTEGMCQSP5P5T36EB2M3LBJOTLEPBVV2K6PFN3A
#\\\|UQSCQY6XWEATRUGR77VNSTOVDFMBHNVETSTUHXWFL2A5RFUQPKJ \ / AMOS7 \ YOURUM ::
#\[7]4PUPQDJFVXQP7RPFKDTWCWC47A4MMVFEF2NXAMAFJ435EVYDKGAQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
## June 2026 site-yaml / jobsite boundary refactor

Re-established clean separation: `site-yaml` is generic, `jobsite` owns job semantics.

- New `modules/jobsite.cmd.job-upsert`: receives JSON job records from `site-yaml`, checks `<jobsite.job.index>`, writes/updates per-job YAML, replies `new`/`updated`/`exists`.
- `modules/site-yaml.cmd.import` is now generic: parses `url=<u> handler=<h> skip=<ids> full=<0|1>` from a single-line args string. Search results are queued as detail fetches; caller-supplied IDs are skipped.
- `modules/site-yaml.handler.fetch_tick` JSON-encodes each fetched record and route-sends it to the configured `reply_handler`.
- `modules/jobsite.stage.fetch` builds `skip_ids` from the authoritative `<jobsite.job.index>` (active/blocked/deleted/trash), sends one import per category, and polls the site-yaml fetch queue until drained.
- Deleted `site-yaml.jobs.{upsert,init_code,save}`, `site-yaml.cmd.{list-jobs,set-status}`; added `jobsite.cmd.set-status`.
- Updated `base.list.subroutines`, `configuration/zenki/*/start`, source placeholders, and `cube/access.zenki` for the swapped command names.
- Added `jobsite.job-upsert` to `access.cmd.usr.cube` in `configuration/zenki/jobsite/start` so route-sends from `site-yaml` are accepted.

### Drain-detection race fix (commit `c27c6cf23`)
The previous `fetch_queue_nonempty` guard only worked if the first queue-depth reply was non-zero. If the poll fired before imports populated the queue, the guard stayed false and the scan never left `scanning` even after the queue drained.

- `jobsite.stage.fetch` now resets `<jobsite.fetch_saw_queue> = FALSE`.
- `jobsite.handler.fetch-done` sets `<jobsite.fetch_saw_queue> = TRUE` whenever it reports queued items, *before* starting the poll timer.
- `jobsite.handler.queue-depth-reply` drains on the first zero-depth reply once `fetch_saw_queue` is true, and added debug logging to `queue-poll` / `queue-depth-reply`.

Verified: new jobsite instance cycled through `scanning` → `assessing` → `idle` cleanly after the fix.

#,,..,..,,,,,,,..,,..,...,.,.,,..,,,,,,.,,.,.,..,,...,..,,,,.,..,,,.,,,,,,,.,,
#Z3Z5OVT5WZH2K6U66XGSWFEAAV24ZKFSNPH67EC7E23TQHNDUU2ZOTZCV5Z7PY25ELKZLQYCEX5C4
#\\\|5ZN2XTRS77WM45W6QTUUHMHPMOZUYCTIMYMCGFNAHAHOMMUA2DW \ / AMOS7 \ YOURUM ::
#\[7]YUAXIYX67E4P4IRUUSGGLXXZOCT2DJJI7H7DUPGWCJ57ZVADDABI 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
## July 2026 pre-fetch field-block design

To avoid fetching detail pages for reposted/deleted jobs, a generic pre-fetch blocking mechanism was added:

- `jobsite.stage.fetch` writes `/var/protocol-7/jobsite/block-list.txt` with lines like `id:<L13>`, `url:<L13>`, `title:<L13>` for every known job.
- `site-yaml.cmd.import` accepts a `block_file=<path>` argument, reads the entries into a hash, and skips any search-result candidate whose `id`, `url`, `title`, `company`, or `city` field matches a blocked checksum.
- `modules/site-yaml.util.field-checksum` is a static helper that computes `<[chk-sum.bmw.L13-str]>` directly on raw strings (no extra base32 encoding).
- `site-yaml.cmd.import` restricts `handler=` to an allow-list (`jobsite.job-upsert`) to prevent routing fetched records to arbitrary subroutines.

`company`/`city` blocking requires `site-yaml.stepstone.search` to extract those fields from the search-result HTML; it currently only returns `id`, `url`, and `title_hint`.

This keeps `site-yaml` generic — it only knows about field checksums, not jobs — while moving all dedup context into the block file produced by `jobsite`.
## Long-term direction: data zenka / SHM blocklist sharing

The current file-based `block_file=` approach is a local-only intermediate step. The right long-term home for cross-zenka block/skip lists is the existing `data` zenka, which already provides shared-memory mounts and cross-host sync capabilities.

Goals once integrated:

- `jobsite` publishes the blocklist as a named SHM mount or data key (e.g. `jobsite.block-list`).
- `site-yaml` mounts or reads that blocklist directly from shared memory, with no local file copy and no per-candidate cross-zenka calls.
- The same mechanism can be reused for other consumers: podcast episode tracking, video channel monitoring, etc.
- This removes the shared-filesystem assumption and makes `site-yaml` deployable on a remote host with a faster/more stable connection than the consumer zenki.

The field-block format (`<field>:<L13-chksum>` per line) stays the same; only the transport changes from local file to data-zenka SHM.
Block-list file conventions:
- Path: `/var/protocol-7/jobsite/block-list` (no `.txt` extension).
- Entries use uppercase field keys: `ID:<L13>`, `URL:<L13>`, `TITLE:<L13>`.
- `site-yaml.cmd.import` normalizes keys to lowercase when reading, so callers can use any case.

#,,..,.,,,,,,,...,,..,...,,.,,,,,,,,.,,..,...,..,,...,...,..,,.,,,,,.,,.,,,,,,
#HHEWXDSSNGY4HS6GFJV7ZD2T6GKH242WSPNEZDYHCYHIO42PONVRHCU4L6OGIAYLA5ZPDFVOVI3LK
#\\\|7KQTT4M55N6XZHG7UJDTOPYJ42S23SV4CUOIW4DYUXEVLGI2GTU \ / AMOS7 \ YOURUM ::
#\[7]H5GJVJM3XOWFGD32YANXS3HWZTVDIQWSWNLGQTFYE3EFGRDDQOCQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
Block-list entries are now prefixed with the current V7 network epoch:
- Format: `<EPOCH>:<FIELD>:<L13>` (e.g. `V7L36RQ:ID:24EYSX33KTVEK`).
- The epoch string is the stripped `base.ntime.epoch_timestamp` value (7 characters, without the 4 harmonization bits).
- `site-yaml.cmd.import` parses both epoch-prefixed and legacy two-part lines.
- This allows future TTL-based cleanup of stale block-list entries to keep the file bounded.

#,,,,,,,.,...,.,.,...,,,.,,.,,,..,,,.,.,,,,,,,..,,...,...,..,,..,,...,,..,...,
#ZMNCJ47QTZI42BFKMEDOKWPFK3XTG7RM3YEUEEZXVHXLLYTPH52GEH42ETPLOLOYNTNQHJHIHS6AU
#\\\|BKU2VZG2ROTGCGZHAKXFRYGD74FGSTNAHWW4J5SMANJMLQYHVDN \ / AMOS7 \ YOURUM ::
#\[7]5CXLWAFUYVPQS67DEN3PMAVEKQFJUVZTTPKKZN2JNK6NIDC6L4AQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::

Source-id extraction for `ID:` blocking:
- `jobsite.stage.fetch` and `bin/jobsite-generate-blocklist` now derive the posting/source id for each job.
- Prefer a numeric `id` field when it looks like an external posting id (>1,000,000).
- Otherwise extract the numeric id from the URL slug (`--<id>-inline.html`).
- The `ID:` blocklist entry checksums this source id, so it matches `$link->{'id'}` from `site-yaml.stepstone.search`.
- The `skip=` argument passed to `site-yaml.import` is now also built from source ids.
- `bin/jobsite-generate-blocklist` accepts multiple job roots, making it easy to seed the blocklist from a backup directory (e.g. old `assessed/` jobs that predate `blocked`/`deleted` states).

#,,,.,,..,,,,,,.,,,.,,,,,,,.,,,,.,,..,..,,,.,,..,,...,...,,,.,,,,,.,.,..,,,.,,
#ZE4ILOG4XZBHVKBYZI5ZGVEFUUGOV3MJPI7W25IVI4DQHQ4V6HBH6TNKI623ZGBEDHLA7ZUJCZA5M
#\\\|UWCAVN3NXV566M67AB3222R3RNKFP5F7JBAJ43NNIEMDPDF6K4H \ / AMOS7 \ YOURUM ::
#\[7]EQFY3GBFMXCN6LXKO7MJU6GDUNGZNSXQH54X4GYEYUWE4Q2KJ4CY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
