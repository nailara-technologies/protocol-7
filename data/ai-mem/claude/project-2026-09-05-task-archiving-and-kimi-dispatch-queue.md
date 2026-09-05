---
name: project-2026-09-05-task-archiving-and-kimi-dispatch-queue
description: "2026-09-05 session: archived 29 stale-but-landed task files across data/tasks/ and data/yaml/coding-tasks/, built bin/dev/task-scan-candidates, cleared a 4-item prioritized dispatch queue (3 via kimi, 1 implemented directly after kimi quota ran out) -- all 4 done and live-verified"
metadata:
  type: project
---

## why

User noticed most recent `data/tasks/` files were already implemented
but never archived. Convention for this already existed
(`data/tasks/task-archiving-with-context-templates.md`,
`data/yaml/context-templates/task-archive-audit.yaml`) but had no
lightweight tool behind it — prior archiving passes were manual,
per-session.

## what shipped

`bin/dev/task-scan-candidates [dir] [ext]` (defaults `data/tasks md`) —
shortlist tool, not a verdict. Two signals: direct `<dir>/<file>`
mentions in commit bodies (strongest — this repo's authors often write
"Implements data/tasks/x.md" literally), and stopword-filtered
filename-token matching against the full commit-subject corpus as
fallback. Both signals produced real false positives this session (a
task's own creation commit paraphrasing its title; generic 2-token
overlap with an unrelated commit; see
`[[feedback-git-log-all-false-duplication]]` for a third, hash-level
false-positive mode) — every hit still needs the matched diff and the
task's own status section read by hand before archiving.

Archived 25 tasks total across `data/tasks/completed/` and
`data/yaml/archive/completed-coding-tasks/` (the pre-existing
convention dirs) — each cross-checked against its real landing commit's
diff, not just title/filename matching. Full evidence lives in the
git commit messages for those moves, not repeated here.

Also discovered/used this session: `HANDOVER.md` at repo root is a
per-session rolling handover doc — git history confirms it gets FULLY
OVERWRITTEN each session (not accumulated); if picking this up later,
follow that convention (write a fresh one for the current session,
point at git history for older content) rather than trying to append or
preserve everything from a prior handover.

## the dispatch queue that came out of it

Built a 4-item prioritized "ready to dispatch" queue from what was
actually read closely during the archiving pass (not the whole
backlog). Outcome, in order:

1. `cred-mesh-transport-subscription-and-base32-gap.yaml` — DONE via
   kimi k3-256k. Both symptoms in the extracted task turned out to
   already be fixed (see `[[feedback-verify-bug-still-open-before-scoping-dispatch]]`
   for the process lesson from this one); the real remaining bug was a
   test-harness fixture rotating the wrong credential slot. Zero
   production files touched.
2. `research-knowledge-base-extraction.md` — DONE via kimi k2.7 (pure
   research/extraction, zero code risk by design). Outer harness
   reported a 1800s-idle timeout but the kimi process had actually
   completed underneath; recovered via `kimi_check_status` rather than
   re-dispatching — worth remembering that a "failed" dispatch
   notification isn't necessarily lost work.
3. `bin/dev/ptd`'s `-d`/`-diff` flag, then `bin/format-code`'s `-diff`
   flag (same feature, second file) via `kimi_continue` on the SAME
   kimi session rather than a fresh dispatch — cheaper and it reused
   the established pattern instead of re-deriving it. Real naming
   collision caught before dispatch: `format-code` already used `-d`
   for `-data-sugar`, so the second flag had to be long-form `-diff`
   only.
4. `models-discover-cleanup.yaml` — kimi quota ran out (~99% used) mid-
   session, so implemented directly instead of dispatching. Audit
   (the task's own step 1) found its `affected_zenki` list was stale
   (`image-quality` unrelated, confused with `vision-batch`) and that
   the two commands being consolidated away had ZERO real callers
   anywhere -- given that, removed them outright rather than
   deprecating (user's direct call once the zero-callsite audit was
   in). New `models.discover.scan_all_paths` helper factors out the
   scan-loop duplication the task described. Live-verified via
   on-demand start with the new code: list + filter modes exercised
   against the real 114-model registry, old removed command confirmed
   gone, `coding.cmd.clear-registry` (separate, correctly-untouched
   command) still working. `:re-scan:` also confirmed live afterward
   (by the user) via `coding.clear-registry :re-fetch:`'s downstream
   chain -- saved 114 models back, exact match, no data loss. Plain
   `:clear:` alone remains untested.

## kimi-dispatch-workflow.yaml gaps found and fixed at the template level

Kimi needed live correction twice during dispatch 1: didn't know `v7`
was renamed `v7-zenki` (2026-08-31/09-02), and wasn't given the
`/dev/shm/.7/STDOUT/<socket-id>` live-console tap path (a trick already
documented in `[[feedback-kimi-v7-console-hint]]` that should have been
checked before writing the task). Both are now baked into
`data/yaml/context-templates/kimi-dispatch-workflow.yaml` itself, so
every future dispatch using that template gets them automatically
instead of needing a hand-added note per task file.

## one more tooling gotcha, found implementing item 4 directly

`bin/dev/gen-sub-whitelist` with no target argument does a full-repo
regen, not just the zenka you're touching -- see
`[[feedback-gen-sub-whitelist-no-arg-full-repo-regen]]`. Caught mid-run
and reverted the unrelated churn it left in 4 other zenki's whitelists
before it finished.

## verification discipline used throughout

Every kimi result was independently re-checked before being accepted as
done — re-ran the actual test suite by hand, checked cited commits via
`git show`, checked cited source lines directly, confirmed `git status`
showed no unexpected file changes. This caught nothing wrong this
session (kimi's work held up every time), but the discipline is the
point, not the specific outcome — see
`[[feedback-verify-bug-still-open-before-scoping-dispatch]]` for the one
place *my own* pre-dispatch verification was incomplete rather than
kimi's.

#,,..,..,,,,,,...,,,.,.,.,,,.,.,.,.,.,,.,,...,..,,...,.,.,.,.,.,.,..,,,..,.,.,
#CJCO7AYQL6RK7BBEBFB2XHC2MTFLPMLD6VT2PGJ633IGOSHLG7U6WRLZLBUL5HSW4IJMC7MUVRCKK
#\\\|VMZCRFOPTCRXPU2VRDN4B7XPR3I56PUFH2ELUDAZRCFZPVBS32A \ / AMOS7 \ YOURUM ::
#\[7]2ULN7YVUHL4CLIIL2TR6A76DJX5TARFWLHKQMX756MQJTITDDOCA 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
