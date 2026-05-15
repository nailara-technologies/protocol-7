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
