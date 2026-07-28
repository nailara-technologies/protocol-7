# jobsite : job.write leaves orphaned files behind on stale-index status transitions

## status

implemented (2026-07-28) — defensive-scan fix in `jobsite.job.write`,
unsigned/uncommitted (signing requires the human's private key).

what was built: after the existing index-derived `$old_abs_path`
computation (~line 60 in the edited file) and before the rename-based
transition, job.write now globs for the job's `$enc_id` across all
status dirs — one-level `$jobs_root/*/$enc_id.yaml` for the plain
statuses, two-level `$jobs_root/*/*/$enc_id.yaml` and
`$jobs_root/*/*/$enc_id.yxz.B32` for the epoch-bucketed
blocked/deleted/trash dirs (glob covers their varying epoch subdir
names). any match that is neither the new target `$abs_path` nor the
index-derived `$old_abs_path` (which the existing rename logic already
handles — never double-processed) is treated as an orphan: logged at
base.logs level 1 with job_id + stray path, then plain-unlinked (trash
`.yxz.B32` strays are also just unlinked — untracked duplicates don't
go through the trash retention pipeline). the whole scan is wrapped in
eval; a glob error logs at level 0 and skips the scan, an unlink
failure logs at level 0 and skips that file — the write itself is
never aborted by scan problems.

design choice worth noting: instead of hardcoding the enumerated
status list, the one-level glob uses `$jobs_root/*/` directly. the
enumerated list in this file omitted `assessed/` — the exact dir of
the WB2NK stray — plus other live statuses found in the codebase
(`responded`, `to_apply`). a wildcard can never drift stale relative
to `$job->{'status'}` (which job.write writes verbatim as the dir
name) and `jobs/` contains nothing but status dirs, so it is both
simpler and strictly more defensive.

verification: `bin/format-code -c -n` (P7 `<[...]>` syntax translation
+ real `perl -c`) reports syntax valid; all lines <= 78 chars (awk
check + `vc-changed-files -exc-len` clean). a standalone perl harness
replicating the scan block verbatim was run against a fabricated
jobs/ tree reproducing both live repro shapes: (1) WB2NK shape —
strays in `assessed/` and `new/` removed, index-derived old path in
`rejected/` and unrelated jobs' files untouched; (2) ZKP5U shape —
old-epoch `trash/V7L36RI/*.yxz.B32` stray removed while the new-epoch
target file and an empty-index (`$old_abs_path` eq '') case were
handled safely. NOT tested against live job data (would require
running the jobsite zenka against production state — out of scope);
the AMOS7 data-signature footer is left in place but now stale, as
expected for an unsigned edit.

still open / out of scope (unchanged): the call-site audit option
(`store.prune`, `job.rescue`, `cmd.reset`), the prune-side orphan
detector idea, and the LLM-assesses-with-empty-input side-finding.

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

#,,,,,,,.,,.,,,.,,,.,,.,,,..,,,.,,,,,,,..,..,,.,.,...,...,.,,,,..,.,,,...,.,.,
#24AB7YH76BIQ7WW7JVGNZWJ4EUS5SFIXFPTDVJX4D5AGJYYUKC3EZG2R26UVA6VTACUL3HUSRQWO4
#\\\|EFIFBW6WZZT5XA4WS5NCJXIU7JXBKQRWQGIWG6CUHQEDVOORD4E \ / AMOS7 \ YOURUM ::
#\[7]WKITTOXNYBUAKAZAPCUMCJO2RAPIL2IEIZICKWLXFMDVKQOL7OAI 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
