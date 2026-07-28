# jobsite : job.write leaves orphaned files behind on stale-index status transitions

## status

not started — root-caused from two independent live repros in one
session (2026-07-28), not yet fixed. a partial, single-call-site
workaround for the same root cause already exists
(`jobsite.dispatch.assessments`' blocked-job branch) but the general
problem in `jobsite.job.write` itself remains open.

## root cause

`jobsite.job.write` (`modules/jobsite.job.write`, ~line 47) derives the
*old* file path to rename-away from purely by reading
`<jobsite.job.index>->{$job_id}` — the in-memory status index — and
computing where that status implies the file should currently live. If
that computed path doesn't exist on disk (`-f $old_abs_path` is false),
the rename step is silently skipped and a *fresh* file is written at the
new location instead. Whatever file is *actually* sitting on disk at the
job's real prior location — if the index was stale relative to the
filesystem at that moment — is never touched again: orphaned permanently,
invisible to `<jobsite.job.index>` (which now only remembers the new
location), and never cleaned up by `jobsite.store.prune` either (prune
also trusts the index to enumerate what exists).

`jobsite.dispatch.assessments` already has a hand-rolled workaround for
one specific instance of this (the blocked-job branch, ~line 65): a
comment there already names the general problem precisely —
"job.write's rename-based cleanup trusts jobsite.job.index for the old
path, which can already point elsewhere... leaves this copy orphaned,
re-detected... forever without ever being removed" — and works around it
by unlinking a *known-correct* path directly instead of trusting the
index-derived guess. That fix is narrow (only covers the one call site
that already knows a job was *just* loaded from `new/`) and doesn't
address `job.write` itself, which every other status transition in the
codebase goes through.

## two independent live repros, same session

1. **`WB2NK`** (Compliance Solutions GmbH / DevOps Engineer, job id
   `13989040`) — after the `jobsite.handler.repair-done` `status='assessed'`
   dead-end fix landed and the job was reset/reassessed, a stray empty-ish
   duplicate was left behind at `jobs/assessed/WB2NK.yaml` even after the
   job's real, current copy correctly existed at `jobs/rejected/WB2NK.yaml`.
   Manually removed (required the user — the file is `protocol-7`-owned).
2. **`ZKP5U`** (Amprion GmbH / Linux & Kubernetes Infrastructure Engineer,
   job id `14327754`) — after the same reset-and-reassess cycle (repair
   pass ran, job eventually landed in `review`, user moved it to `skipped`
   then deleted it), a stray snapshot survives at
   `jobs/trash/V7L36RI/ZKP5U.yxz.B32` — `status: trash`, `score: '7'`, but
   `title`/`company`/`url`/`description` fields entirely *absent* (not
   just empty strings — the keys themselves are missing). The rich
   assertions/score_reason text in that stale snapshot reads as a
   plausible-sounding assessment produced from the candidate profile alone
   (no real job content available at that point in the sequence) — an LLM
   filling in something coherent-sounding from mostly-empty input, which
   is its own minor side-finding worth remembering separately if it
   recurs (a job assessed with missing title/company/description should
   arguably be caught before dispatch, not silently produce a
   plausible-but-groundless score).

both repros followed the same shape: a job going through a *rapid,
multi-step status sequence* (reset → new → assess/repair → trash/review
→ user action) in a single session, which is exactly the condition under
which an index-vs-filesystem staleness window is most likely to open up.

## proposed fix (not implemented, needs a decision)

`job.write`'s rename step needs to stop trusting a single index-derived
guess as the *only* source of truth for "where is this job's file right
now." two shapes worth considering, not mutually exclusive:

- **defensive scan**: before writing, glob for `$enc_id.*` (or
  `$enc_id.yaml` / `$enc_id.yxz.B32`) across all known status directories
  (`new/ review/ trash/*/ deleted/*/ blocked/*/ applied/ apply/ rejected/
  skipped/ interviewed/ archived/`) rather than relying solely on the
  index's claimed status to compute one candidate path. any match found
  that isn't the new target path gets removed/renamed, closing the gap
  regardless of how the index got stale.
- **fix index staleness at the source** instead of working around it at
  read time: audit every code path that moves a job file without going
  through `job.write` itself (`jobsite.store.prune`'s trash→deleted
  phase, `jobsite.job.rescue`, `jobsite.cmd.reset`) to confirm each one
  keeps `<jobsite.job.index>` and the filesystem in lockstep — a single
  path that updates one without the other is enough to explain both
  repros.

## open questions

- how common is this outside of manual reset/reassess sessions like
  today's — does the *normal*, unassisted assess→repair→final-status
  pipeline (no manual `jobsite.reset` involved) also hit this, or does it
  specifically need the kind of rapid multi-transition sequence a manual
  reset triggers? worth checking whether any stray files exist from
  jobs that were never manually reset this session.
- should `jobsite.store.prune` (which already walks the trash directory
  tree) opportunistically flag/report orphaned files it finds that don't
  match any current index entry, as a lightweight ongoing detector,
  independent of whichever write-time fix above gets chosen?
- the LLM-assesses-with-empty-input side-finding from the `ZKP5U` repro:
  should `jobsite.dispatch.next`/`build_prompt` refuse to dispatch (or at
  least flag) a job with no title/company/description rather than
  producing a plausible-looking but groundless score? separate from the
  orphaned-file bug itself, but discovered via the same incident.

#,,..,,,,,,,.,...,,,,,,.,,,.,,...,,..,,,.,...,.,.,...,...,.,.,,.,,,,.,,.,,,.,,
#MVSJP6T5HK4ZKGMMGOCDHFJY2XYGFNYNBPYMREIWFOR7CYJCUSIJYIKRSDHGFI7AKINSIYFIIFWQM
#\\\|UXMNUS3QPPQR36L2Z7DLXHDQ3LH7BTGLUFXE2AFYI4PMDEX3LWW \ / AMOS7 \ YOURUM ::
#\[7]57EUR5ITOSF37QXPBL4MMIKT7YJJI5QV4QL23BU2Y2TAHU4AOIBA 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
