# jobsite : manual stepstone URL submission (feed the real pipeline, not just local tracking)

## status

not started — captured from conversation, scoped from code inspection.
concrete repro url that triggered this request:
`https://www.stepstone.de/stellenangebote--Cyber-Security-Architect-m-w-d-Inhouse-Consulting-Villingen-Schwenningen-N-O-C-Engineering-GmbH--14110126-inline.html`
(a real posting the category scan never surfaced — see "search key list"
section below for why).

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
   `configuration/zenki/jobsite/start`'s `access.cmd.usr.cube` list so
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

separately requested: review `configuration/zenki/jobsite/start`'s
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

#,,.,,,.,,.,.,,,,,.,,,.,.,,,,,.,.,...,,,.,.,,,.,.,...,...,...,.,,,,,.,,,.,.,.,
#JFOJORPPW77I6PRAX3R23D57D3NNECPQCPPZDPXME7DI4WR5S6WZQY2FLVHGDTEG2UNCIMNHAKZYS
#\\\|WTUR5LK4PSNKKZJ3CNYF5QPJQRPTXUCDKUOJ4HKKERXVEMNSSFM \ / AMOS7 \ YOURUM ::
#\[7]MTLAEY4IJCSLBDUCCKSJQ3F235PABMDB444AK4QDN65ZXXFDU2DY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
