# jobsite : manual stepstone URL submission (feed the real pipeline, not just local tracking)

## status

implemented (main feature only; the "search key list review/optimize"
section below was explicitly left untouched, as were
`jobsite.cfg.categories` / `jobsite.cfg.url.*`).
concrete repro url that triggered this request:
`https://www.stepstone.de/stellenangebote--Cyber-Security-Architect-m-w-d-Inhouse-Consulting-Villingen-Schwenningen-N-O-C-Engineering-GmbH--14110126-inline.html`
(a real posting the category scan never surfaced — see "search key list"
section below for why).

### what was built

one shared backend primitive, two callers, per the "proposed shape":

1. **`modules/site-yaml.cmd.import-url`** (new) — takes `url=<posting-url>`
   (bare url also accepted, same arg convention as `site-yaml.cmd.import`),
   validates the `stepstone.de` host + `--\d+-inline\.html` suffix pattern
   `site-yaml.stepstone.job` relies on for id extraction, refuses ids/urls
   already sitting in the fetch queue, then pushes exactly one
   `{ id, url, reply_handler: 'jobsite.job-upsert' }` entry into
   `$data{'site-yaml'}{'fetch_queue'}` — the identical shape
   `site-yaml.cmd.import`'s per-link loop builds — kicks
   `site-yaml.fetch.schedule` if no fetch timer is running, and saves queue
   state. `site-yaml.handler.fetch_tick` is reused completely unchanged:
   fetch/backoff/retry/route-to-upsert all come from the existing code.
2. **`modules/jobsite.cmd.import-url`** (new) — the p7c/console command
   (`p7c jobsite.import-url url=https://www.stepstone.de/...`). re-validates
   the url pattern server-side, then checks the two synchronous dedup
   sources before queueing: `<jobsite.job.index>` by extracted numeric id
   (answers "already known" including *where it sits* — active status, or
   `trash:<epoch>` / `deleted:<epoch>` / `blocked:<epoch>` with a rescue
   hint for trash) and `jobsite.checksum.index` 'check' on the url (catches
   the same posting under a changed listing id). only then route-sends to
   `site-yaml.import-url` and immediately replies "queued" — the fetch is
   async by design, so this is an ack, not a fetch result.
3. **`modules/jobsite.handler.import-url-reply`** (new) — receives the
   `site-yaml.import-url` reply and logs it: queue-level rejections
   (url rejected by site-yaml, already in fetch queue) land at log level 0
   in the jobsite buffer, success at level 1. this is the visible endpoint
   for the outcome class the caller already ack'd on.
4. **UI wiring — design fork: thin dedicated web command, NOT an
   `add_url` branch in `jobsite.sync.apply_reverse`.** reasons:
   - the reverse channel's entry shape is hard-bound to an *existing*
     vax-int job id in two places: `plugin.web.jobs.reverse.queue` refuses
     entries with an empty id, and `apply_reverse` skips entries whose id
     doesn't decode — both *before* any action dispatch. a "no id yet"
     submission would mean weakening that guard in two existing modules
     whose delete/stage staleness machinery is built around it.
   - the reverse channel is poll-based and one-way: entries only reach
     jobsite on the next sync flush and the browser gets no verdict back,
     which can't satisfy "user-visible result per outcome" or an immediate
     "queued" ack.
   - an exact precedent already exists: `/jobs-trash-rescue` → httpd
     web-relay → `jobsite.rescue-http`. the new
     **`modules/jobsite.cmd.import-url-http`** mirrors it: parses the plain
     POST body, delegates to `jobsite.cmd.import-url` (so validation,
     dedup and queueing exist exactly once, shared with the CLI path), and
     wraps the result as strm+json `{ok, message}` — the web-relay reply
     handler 502s on true/false replies, which is why the `-http` face
     exists at all (same reasoning documented in `jobsite.cmd.rescue-http`).
   - new httpd route: `POST /jobs-import-url → web-relay
     [command:jobsite.import-url-http]`.
5. **UI panel** (`data/web-root/vhosts/jobs.vhost/index.html`) — a second
   row inside the existing `[ + manuell ]` panel, below a divider: one url
   input + `importieren` button (Enter key also submits). `addManual()` and
   the pure-local tracking fields are untouched. client-side validation
   fast-fails on non-matching urls before any network call using the same
   regex as the server; the server re-validates regardless. feedback is
   honest about asynchronicity: success shows the server's "queued …
   [ async fetch ]" message via `notify()`, i.e. "submitted, check back",
   not a faked synchronous result; the job then arrives through the normal
   pipeline (`status: 'new'` → assessment → review/trash placement) and
   shows up on a regular poll.

### three outcomes, as required

- **(a) fetch/parse succeeds** → queued exactly like a scan hit;
  `jobsite.job-upsert` receives the fetched record via the existing
  `fetch_tick` route-send, lands as `status: 'new'`, indistinguishable from
  a scan-discovered job downstream.
- **(b) well-formed url, page doesn't resolve to a JobPosting**
  (404/410/expired/markup change) → the reused `fetch_tick` logs
  `gone`/`drop` at error-visible levels in the site-yaml buffer (no silent
  no-op), and the submission ack tells the caller the fetch is async so
  there is no fake success. synchronous pre-fetch existence checks were
  deliberately NOT added: the task's own open-questions section says the
  manual path must go through the fetch_queue/backoff machinery rather
  than fetching in-request.
- **(c) url already known** → answered synchronously by
  `jobsite.cmd.import-url` before anything is queued: job-index hit
  reports the current location (e.g. `already known: 14110126 sits in
  trash:V7XXXXX [ use jobsite.rescue to restore ]`), url-checksum hit
  reports the decided-job match; site-yaml additionally refuses
  double-queueing of an id/url already in flight. nothing is silently
  re-processed.

### files touched

- new: `modules/site-yaml.cmd.import-url`, `modules/jobsite.cmd.import-url`,
  `modules/jobsite.cmd.import-url-http`,
  `modules/jobsite.handler.import-url-reply`
- `cfg/zenki/jobsite/start` — `import-url` added to
  `access.cmd.usr.cube` (only change there; `jobsite.cfg.*` untouched)
- `cfg/zenki/site-yaml/start` — `import-url` added to
  `access.cmd.usr.cube` (symmetric with existing `import`)
- `cfg/zenki/cube/access.zenki` — `site-yaml.import-url` added to
  `access.cmd.usr.jobsite`, `jobsite.import-url-http` added to
  `access.cmd.usr.httpd`
- `cfg/zenki/httpd/routes` — `POST /jobs-import-url` route
- `cfg/zenki/site-yaml/subroutines.load-early`,
  `cfg/zenki/jobsite/subroutines.load-early` — new modules added
  next to their siblings (compile-timing whitelist; regenerable with
  `bin/dev/gen-sub-whitelist`)
- `data/web-root/vhosts/jobs.vhost/index.html` — import row in the
  `[ + manuell ]` panel, `JOBS_IMPORT_URL` const, `submitImportUrl()`
  (debounced, same WebKit double-click guard as the trash panel)

### verification

- all four new modules pass `perl -c` after `<[...]>`/`<var>` syntax
  expansion (same transform `bin/Protocol-7` applies at load time).
- the url regex was exercised against the concrete repro url (extracts
  `14110126`), a query-string variant, a bare-host http variant
  (accepted), and negatives: a category search url, `evilstepstone.de`,
  `stepstone.de.evil.com`, non-numeric id — all correctly rejected. the
  JS mirror regex was run through node with the same cases, same verdicts.
- the edited page's `<script>` block passes `node --check`.
- not run end-to-end: requires a live zenka network (site-yaml + jobsite
  + httpd + cube) — restart the affected zenki and test with
  `p7c jobsite.import-url url=<repro-url>`; expected: immediate "queued"
  ack, `jss.import-url [14110126]: import-url queued: …` at level 1, then
  the job appearing as `new`/assessed via the normal pipeline.

### notes / follow-ups for the human

- **signatures**: the four new module files carry placeholder AMOS7
  footers (structure copied verbatim, signatures not valid), and the five
  edited config files' signatures are now stale. run
  `bin/Protocol-7 sourcecode update-signatures` before committing — needs
  the private key, not done here.
- **deviation from the task text**: the task floated wiring the UI through
  `jobsite.sync.apply_reverse` as `action: 'add_url'`; the dedicated
  `/jobs-import-url` endpoint was chosen instead (reasons above). this
  affects only UI-side wiring, not the shared backend primitive — both
  callers end at the same `jobsite.cmd.import-url`.
- **rate limiting**: unchanged from the task's answer — the manual path
  goes through the same fetch_queue/backoff machinery (fetch_tick
  untouched), and site-yaml's queue dedup refuses exact double
  submissions; no additional abuse guard was added (single-user tool,
  same trust level as the existing `/jobs-trash-rescue` endpoint).

## the gap

the `[ + manuell ]` panel (`data/web-root/vhosts/jobs.vhost/index.html`,
`addManual()` around line 1969) only ever writes a purely client-side,
`localStorage`-backed tracking entry (`source: 'manual'`,
`stage: 'to_apply'`, `score: null`) — it never talks to the server at all.
that's fine for "I already know I'm applying here, just track it," but
there is currently **no way to hand jobsite a specific posting URL and have
it go through the real pipeline** (checksum dedup, `status: 'new'`, LLM
assessment, threshold scoring, review/trash placement) the way a
category-scan-discovered job does.

## what already exists and can be reused

the single-URL-fetch primitive already exists and does not need to be
built: `site-yaml.stepstone.job($url)` (`modules/site-yaml.stepstone.job`)
fetches one stepstone job page, extracts the JSON-LD `JobPosting` block,
and returns a fully-populated job hash (title/company/city/description/
salary estimate/etc) — this is the same extraction a normal category scan
uses per-listing, it's just never been invoked with a caller-supplied URL
outside of the search → link-list → per-link fetch chain.

the full plumbing for "fetch one URL, hand the result to
`jobsite.job-upsert`" also already exists in `site-yaml.handler.fetch_tick`
(`modules/site-yaml.handler.fetch_tick`): it dequeues one
`{ id, url, reply_handler }` entry from `$data{'site-yaml'}{'fetch_queue'}`,
calls `site-yaml.stepstone.job`, and on success routes the resulting job
hash to `reply_handler` via `route-send` — currently always
`jobsite.job-upsert` (the only entry in `site-yaml.cmd.import`'s
allow-list). a manual single-URL add just needs to seed **one** entry into
that same queue directly, skipping the `site-yaml.stepstone.search`
listing-page step entirely (`site-yaml.cmd.import` currently always starts
from a search URL — see `modules/site-yaml.cmd.import` lines 106-181,
the per-link queueing block at lines 131-168 is the part that needs a
direct-URL equivalent).

once an entry lands in `jobs/new/` via `jobsite.job-upsert` with a genuine
`status: 'new'`, it is *already* indistinguishable from a scan-discovered
job to everything downstream (`jobsite.dispatch.assessments`, the
checksum/blacklist index, threshold scoring) — no changes needed there.

there is also already an extensible browser → jobsite reverse-action
channel: `jobsite.sync.apply_reverse` (`modules/jobsite.sync.apply_reverse`)
dispatches on an `action` field (currently `delete` / `blacklist` /
`reassess`) arriving through the existing `jobs-sync` reverse-push path.
adding `action: 'add_url'` there (rather than inventing a brand new HTTP
endpoint alongside `web.cmd.jobs-sync` / `web.cmd.jobs-data`) may be the
lowest-friction way to wire the UI call through — worth checking during
implementation whether that reverse channel's existing shape (single
`entry` per action, applied against an existing job id) fits a
"submit a brand new url, no existing id yet" case cleanly, or whether a
small dedicated command is actually simpler. not decided here.

## proposed shape

**build one shared backend primitive, wire two callers into it** — there is
currently no CLI/p7c-level "import this one job" command either (the
existing `site-yaml.cmd.import` is search-url-only, see above), so rather
than building the UI's reverse-sync action and a hypothetical future CLI
command as separate implementations, build the core direct-URL import once
and expose it both ways from day one:

1. **new command**: `jobsite.cmd.import-url` (mirrors the existing
   `jobsite.cmd.*` naming/orchestration convention — `jobsite.stage.fetch`
   already `route-send`s into `site-yaml.import` for the category-scan
   case, this is the same shape for a single URL). validates the url
   pattern (`--\d+-inline\.html` suffix + `stepstone.de` host, same check
   `site-yaml.stepstone.job` already relies on for id extraction), then
   `route-send`s to a new **`site-yaml` command** — e.g.
   `site-yaml.cmd.import-url` — that seeds exactly one
   `{ id, url, reply_handler: 'jobsite.job-upsert' }` entry directly into
   `$data{'site-yaml'}{'fetch_queue'}` (same shape `site-yaml.cmd.import`'s
   per-link loop builds at lines 131-168, just skipping the
   `stepstone.search` listing step entirely) and kicks
   `site-yaml.fetch.schedule` if not already running. reuses
   `site-yaml.handler.fetch_tick`'s existing fetch/backoff/retry/upsert
   handling completely unchanged.
   add `import-url` (or whatever it ends up named) to
   `cfg/zenki/jobsite/start`'s `access.cmd.usr.cube` list so
   it's `p7c`-invokable directly, independent of the UI ever landing —
   useful on its own for one-off manual imports from a terminal.
2. **UI caller**: the `[ + manuell ]` panel's new URL-submission area (see
   below) does client-side validation for fast-fail UX, then goes through
   the browser → `jobs-sync` reverse-action channel
   (`jobsite.sync.apply_reverse`, new `action: 'add_url'` branch) which
   itself just calls `jobsite.cmd.import-url` — no separate logic path.
   still need to check whether `apply_reverse`'s current per-existing-job-id
   entry shape needs adjusting for a "no id yet" submission, or whether a
   thin dedicated web-facing command is simpler than forcing it through
   that channel; either way it ends up calling the same
   `jobsite.cmd.import-url` underneath.
3. **CLI caller**: `p7c jobsite.import-url url=https://www.stepstone.de/...`
   — same command, no UI involved. worth having on its own merits (this
   session's whole trigger was "I found one manually, no way to feed it
   in" — the CLI path alone already closes that gap, the UI panel is the
   friendlier version of the same thing).
4. **UI panel**: second area inside (or directly below) `[ + manuell ]` —
   a single URL input + submit button, separate from the existing
   title/company/city/url/score/reason fields (those stay as pure local
   tracking; this is a distinct "discover a real posting" action).
5. three outcomes `jobsite.cmd.import-url` needs to handle distinctly
   (applies to both callers, not just the UI):
   - fetch/parse succeeds → queued exactly like a scan hit → normal
     `job-upsert` → dedup/assess pipeline.
   - url is well-formed but the page doesn't resolve to a `JobPosting`
     (404/410/expired listing, or stepstone changed markup) → visible
     failure reply, not a silent no-op.
   - url is already known (checksum/id dedup hits an existing job,
     possibly in trash/deleted) → say so instead of silently
     re-processing or silently doing nothing; consider surfacing where it
     currently sits (e.g. "already in trash, use rescue" vs "already in
     review").
6. feedback path is inherently async either way, given the reused
   `fetch_queue`/`fetch_tick` machinery (backoff, retry, rate-limit
   handling all live there) — `p7c` gets an immediate "queued" ack, not a
   synchronous fetch result; the UI panel should show "submitted, check
   back" rather than faking a synchronous result too.

## search key list review/optimize (secondary, smaller task)

separately requested: review `cfg/zenki/jobsite/start`'s
`jobsite.cfg.categories` / `jobsite.cfg.url.*` list (currently
`linux-sysadmin linux-developer devops platform-engineer security-engineer
ki-infrastruktur backend-architect`, each mapped to one stepstone category
search url).

concrete evidence of a real gap: the triggering posting for this task,
"Cyber Security Architect (m/w/d)," was never surfaced by the existing
`security-engineer` category
(`stepstone.de/jobs/security-engineer/in-deutschland`) — stepstone's own
category/keyword matching apparently doesn't treat "security architect"
titles as equivalent to "security engineer" ones, so a plausible fit for
the candidate profile silently never entered the pipeline at all. this is
exactly the kind of gap a manual-URL-submission feature (above) works
around case-by-case, but the category list itself should also be checked
for other title-family gaps (e.g. "architect" vs "engineer" vs
"administrator" variants across the other six categories, not just
security).

scope for this half: read `data/jobsite` profile/context used to build the
assessment prompt (`jobsite.cfg.profile_file`,
`modules/jobsite.util.build_prompt`) to understand what role families the
candidate actually targets, then propose additions/renames to
`jobsite.cfg.categories`/`jobsite.cfg.url.*` — this needs the user's
judgment on which title variants are worth a dedicated search url
(stepstone's own search relevance per category url is opaque from outside,
so this is necessarily somewhat exploratory/iterative, not a one-shot
fix).

### second axis, same review pass: location-scoped search entries

separately raised (2026-07-28, folded in here rather than a new task —
same config file, same profile read, one coherent pass instead of two):
the jobcenter specifically asked about local-area applications, and the
current category list is entirely nationwide (every
`jobsite.cfg.url.*` entry ends `/in-deutschland`). worth adding a handful
of location-pinned variants for the highest-priority roles (assuming
stepstone's url scheme supports swapping the location segment the way
`in-deutschland` implies, e.g. `in-stuttgart` — not yet verified against
a live fetch).

the justification isn't page-cap truncation (`site-yaml.import_max_pages`,
capped at 5) — on any *regular* re-scan the existing `skip_ids`/block-file
dedup makes `site-yaml.cmd.import`'s early-break-on-all-duplicates logic
stop well short of that cap, so page count isn't the bottleneck once a
category has run a few times. the real justification is search
*relevance*: a small local company's posting competes for ranking against
the entire nationwide candidate pool in a broad role query and can rank
arbitrarily low there regardless of page count, while the same posting is
a top-page result in a location-scoped query simply because the pool is
smaller. location-pinned entries give local postings a search context
where they actually surface, rather than depending on stepstone's
nationwide ranking to happen to favor them.

start with a handful of location-pinned entries for the highest-priority
roles (not a full category × location cross-product — that multiplies
scan volume and rate-limit pressure for comparatively little marginal
gain over pinning just the roles that matter most locally). the existing
`remote-flexibility` assessment dimension already scores remote-friendly
matches, so this is purely about *discovery* (getting local postings into
the pipeline at all), not scoring — the reassess/scoring side already
handles the local-vs-remote judgment once a posting is found.

## open questions

- exact shape of the UI → `jobsite.cmd.import-url` call: through
  `apply_reverse`'s existing `action` channel (needs its current
  per-existing-job-id entry shape checked against a "no id yet"
  submission) or a thin dedicated web command — either way it calls the
  same shared `jobsite.cmd.import-url` underneath, so this only affects
  UI-side wiring, not the backend primitive itself.
- rate limiting / abuse guard on the manual endpoint: currently
  `site-yaml.cmd.import`'s search-based flow is naturally rate-limited by
  page counts and `site-yaml.fetch.backoff`; a manual single-URL path
  bypasses the search step but should still go through the same
  `fetch_queue`/backoff machinery rather than fetching synchronously
  in-request, both for consistency and to avoid hammering stepstone from
  a UI action.
- how many additional stepstone category urls are actually worth adding
  vs. leaning more on manual submission for one-off finds — not obviously
  one or the other, likely both.

#,,,.,,,.,,.,,.,,,,.,,,.,,,,,,,.,,.,.,.,,,,..,.,.,...,..,,...,.,.,,,.,,,.,...,
#4CSDAHIO2X64P2L4I6CWIUY6XUUQUX37Q3CVKG455Q7COQWHXGGOII7FFFZKSTARESTKQL4RQAJ26
#\\\|3ESHVV4VCH3AF5S7CN5L7KUEERC5AF3HJ24M3FCCL7TBSOSOMBR \ / AMOS7 \ YOURUM ::
#\[7]6DTA4KJJLOYGYAUNLMS65UITM4VVJHGW623ZGJCLJCDNAMPHFQAY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
