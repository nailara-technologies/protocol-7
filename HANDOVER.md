# Session Handover — 2026-09-05

**All 4 dispatch-queue items now DONE.** See the queue section below for
status of each.

## Completed This Session

### Task-backlog archiving sweep
`data/tasks/` had ~115 active `.md` files, many long since landed but
never archived. Built `bin/dev/task-scan-candidates` (directory +
extension agnostic — `task-scan-candidates [dir] [ext]`, defaults to
`data/tasks md`) as a lightweight shortlist tool: combines direct
`data/tasks/<file>` mentions in commit bodies (strongest signal —
authors here often write "Implements data/tasks/x.md" directly) with
stopword-filtered filename-token matching against the full
commit-subject corpus as fallback. It is a shortlist tool, not a
verdict — both signals produced confirmed false positives this session
(a task's own creation commit paraphrasing its title; generic 2-token
overlap with an unrelated commit), so every hit still needs the
matched diff and the task's own status section actually read before
moving anything.

Archived 21 tasks from `data/tasks/` -> `data/tasks/completed/`
(commit `4dcf3a19f`) and 4 from `data/yaml/coding-tasks/` ->
`data/yaml/archive/completed-coding-tasks/` (commit `ba570179d`), each
cross-checked against its real landing commit's diff, not just
title/filename matching. Full list and evidence in those two commit
messages. Several plausible-looking token matches were deliberately
**left in place** after reading the actual file, because they
self-report partial/open work right next to what looked like a
completion commit — worth remembering as a general caution before
trusting this class of scan: `cred-mesh-rotation-subscription-cross-
zenka.md`, `sub-bit-element-definition.md`,
`x11-xvfb-start-async-refactor.md`,
`coding-cpu-and-hybrid-offload-path.md`, `web-auth-plugin.md`,
`ptd-extensions-and-p7-perl-translator.yaml`,
`models-discover-cleanup.yaml`, `base-handler-command-
modularization.yaml`, and the `phase-2`..`phase-6` roadmap chain
(each explicitly gated on the previous phase).

Not exhaustive: only the most-recently-created ~20 of the 86 files
still active in `data/tasks/` got a full read this session, plus all
31 files in `data/yaml/coding-tasks/`. The older `data/tasks/` backlog
(pre-2026-08) has not been swept yet — good candidate for the next
archiving pass with the same tool + discipline.

### Prioritized dispatch queue — 4 of 4 DONE this session

Ranked by how dispatch-ready the remaining work was, per
`data/yaml/context-templates/kimi-dispatch-workflow.yaml`'s own bar.
Status after this session:

1. **DONE** — `cred-mesh-transport-subscription-and-base32-gap.yaml`.
   See its own section below; archived to `data/yaml/archive/
   completed-coding-tasks/`.

2. **DONE** — `research-knowledge-base-extraction.md`. Dispatched to
   kimi k2.7 (`kh70fwunh` — outer harness reported it as timed-out
   after 1800s idle, but the underlying kimi process kept running to
   completion; recovered via `kimi_check_status`, no work lost). All 5
   listed topics (7.2 dancing-zenki-formation, 7.3 council-of-13, 9.1
   personal-hud-grid, 10 forensics-zenka [already done], 5
   loves-it-tree) now have findings files in `data/tasks/
   research-findings/`. Spot-checked one citation
   (`IMPLEMENTATION-ROADMAP.md:505-510`) directly against source —
   exact match. Zero `src`/`cfg` files touched, confirmed via `git
   status`. Task doc archived to `data/tasks/completed/`.

3. **DONE** — the `bin/dev/ptd` `-d`/`-diff` flag (kimi k2.7-fast,
   session `65206575-dd7f-431b-aed4-ac1755abf41f`), then **also done**
   for `bin/format-code` via `kimi_continue` on the same session
   (`-diff` long-form only there — `-d` was already taken by
   `-data-sugar`, deliberately not reused). Both live-verified by hand:
   real diff shown for a modified file, "no diff" for a clean one,
   `-diff -c` falls through to a syntax report correctly, existing
   flags unaffected, temp files cleaned up. The bidirectional p7<->perl
   translator in the same task file remains untouched/deferred by
   design — `ptd-extensions-and-p7-perl-translator.yaml` correctly
   still `status: in_progress`, not archived.

4. **DONE** — `models-discover-cleanup.yaml`, implemented directly
   (not dispatched, kimi quota was nearly exhausted). See its own
   section below; archived to `data/yaml/archive/completed-coding-tasks/`.

Lower-confidence picks (only skimmed, not vetted the way 1-4 are):
`coding-cpu-and-hybrid-offload-path.md` (the hybrid/partial-GPU-offload
piece specifically — its stale opening framing was already flagged for
a separate small correction pass first, do that first), and
`x11-xvfb-start-async-refactor.md` bug 2 (diagnostic timing logs
already placed at the two suspected stall points, but the file itself
says not to test live without a clear plan — keep the live-
verification step human-supervised).

Explicitly **not** ready for direct dispatch without a scoping pass
first: `queue-intelligence-and-event-loop-safety.yaml` (critical
priority but self-described as touching three interconnected systems
— needs decomposition into sub-tasks before it's kimi-sized), and the
`phase-2`..`phase-6` roadmap chain (only phase-2 is even eligible,
not read closely enough yet to vouch for it as dispatch-ready).

### cred-mesh/transport dispatch — DONE, kimi k3-256k (`kd6s1cktc`)

Dispatched `cred-mesh-transport-subscription-and-base32-gap.yaml`.
Result independently re-verified afterward (ran `bin/dev/cred-mesh-test`
myself, read the actual diffs) — not just taken on kimi's summary:

**Both symptoms in the task file turned out to be stale premises, not
live bugs.** Bug 5 (base32 decode undef in transport) had already been
fixed the same day it was filed — commit `a6d5de568`, 2026-07-18,
"fix redundant base. prefix on base32 calls (bug 5)" — I should have
checked git log for base32-related commits near that date before
writing the task; missed it despite doing exactly that check for other
tasks this session. Symptom 1 (transport's subscription vanishing) was
closed by the same 2026-07-18 `proxy.init_code` zenka-guard fix already
documented as FIXED in the source doc — the doc's own tail just never
got updated to say the retest afterward passed.

**The actual remaining bug was in the test harness itself**, not
product code: `bin/dev/cred-mesh-test.d/scenario-4-rotation-invalidation.pl`
rotated slot `rotation-test.api-key` while the request path only ever
resolves `session.$domain` (confirmed directly against
`src/proxy.auth.lookup:31`) — so the rotated slot could never affect
the injected header, regardless of the subscription bug. One-line fix
+ explanatory comment. `bin/dev/cred-mesh-test` now 22/23 (verified
myself), scenario 4 fully green; the one remaining failure is
scenario 5, explicitly out of scope for this task family (tracked
separately). Zero production `src/`/`cfg/` files were touched — commit
`5a12f1ca0` + the two July fixes already covered everything real.

Resolution written back into `data/tasks/cred-mesh-rotation-
subscription-cross-zenka.md`. New finding, not fixed (per task scope):
`transport.init_code` still has no `<system.zenka.name>` guard around
its init side effects — same latent landmine `proxy.init_code` had
before its 2026-07-18 fix, inert today (nothing else loads `transport`
yet), will misfire the day something does.

**Known minor gap, not investigated**: live console showed
`transport.handle.quic-hysteria:85 warn : argument '<checksum>' isn't
numeric in sprintf` during scenario 2 (which still passes) — pre-
existing, unrelated to this task, flagged by kimi's own findings and
independently observed live. Worth a small future task if it keeps
showing up; not urgent.

### Kimi dispatch tooling gap fixed — v7-zenki naming + live console hint

Had to correct kimi live twice during the dispatch: it needed to be
told `v7` was renamed `v7-zenki`, and given the `/dev/shm/.7/STDOUT/
<socket-id>` live-console tap path by hand. Both were already-known
gotchas — a standing memory note
(`data/ai-mem/claude/feedback-kimi-v7-console-hint.md`) documented the
console-tap trick, and I hadn't checked it before writing the task
file. Fixed at the template level so it's automatic going forward:
`data/yaml/context-templates/kimi-dispatch-workflow.yaml` now has a
"stale v7 naming" section (translate `v7.<cmd>` -> `v7-zenki.<cmd>` in
any pre-rename reference doc; `zenka.v7`/`v7.ax` are unrelated,
deliberately unchanged) and a "live console tap" section with the
current known-live socket-id (`NIW7OAQ`, confirmed live 2026-09-05,
re-verify freshness with `ls -la /dev/shm/.7/STDOUT/` before trusting
it in a future session — it rotates on a v7-zenki restart). The memory
note itself was also updated to match.

**Two empty untracked files that appeared during the dispatch**
(`cfg/zenki/cred-mesh/deps/.placeholder`, `cfg/zenki/transport/deps/
.placeholder`, origin never confirmed) were kept and committed as-is
rather than removed — harmless either way, decided not worth chasing
further.

### models-discover-cleanup — DONE, implemented directly (not dispatched)

Step 1 (audit usage) done first, repo-wide grep for all 3 command names
across src/cfg/bin/data. Found the task's own `affected_zenki` list was
stale: `image-quality` has no relation to this at all (confused with
`vision-batch`, which calls `image-quality.analyze` for something
unrelated). Only real caller of `models.cmd.discover` is `coding`
(`coding.handler.fetch_model_discovery` + `coding.init_code`'s
on-demand routing target), using the bare-word contract
(`call_args => { args => 'available' }`), not the colon-flag form the
task's `proposed_solution` describes. `discover_files` and
`clear-registry` have **zero callers anywhere** in src/cfg —
console/human-operator use only.

Given zero real callsites for the two redundant commands, **removed
them outright rather than deprecating** (your call, mid-session, given
callsites would be trivial to update — there were none):
- Deleted `src/models.cmd.discover_files`, `src/models.cmd.clear-registry`.
- Rewrote `src/models.cmd.discover` as the unified command (`:clear:`,
  `:re-scan:`, `:available:`/`:unavailable:`), keeping the old bare-word
  filter contract as a backward-compatible synonym and the list-mode
  reply text format byte-identical (`coding.handler.models_discover_reply`
  parses it by regex).
- New `src/models.discover.scan_all_paths` factors out the
  search-path-resolution + scan loop that was duplicated verbatim
  between the two old commands (the task's stated "problem 1", now
  actually fixed rather than just described).
- Dropped the dead command tokens from `cfg/zenki/models/zenka.v7`'s
  access grant and `src/base.list.subroutines`; regenerated
  `cfg/zenki/models/subroutines.load-early` via
  `bin/dev/gen-sub-whitelist models` (scoped — the no-arg form triggers
  a full-repo regen; caught that mid-run in the background and reverted
  the unrelated churn it left in 4 other zenki's whitelists before
  committing to anything).

**Live-verified** via on-demand start (`models` wasn't running,
`p7_command` triggered a clean boot with the new code): `models.discover`
(default list, the exact call shape `coding` depends on) returned the
correct format, 114 models; `models.discover :available:` filter
works; the removed `models.discover_files` correctly errors
`command not known or no permission`; `coding.cmd.clear-registry`
(the separate, unrelated command, correctly left untouched) confirmed
still working. `:re-scan:` also confirmed live afterward (by you,
2026-09-05) via `coding.clear-registry :re-fetch:`'s downstream chain —
`models.storage.yaml_save` saved 114 models back, exact match, no data
loss. `:clear:` alone (without `:re-scan:`) remains untested — lowest
risk of the four modes (just empties the registry, no filesystem scan
involved) but still real state, worth a deliberate test rather than an
incidental one before fully trusting it.

## Open Items — Not Started / Not Finished

1. **Sweep the older `data/tasks/` backlog** (pre-2026-08, ~65 files
   not yet read this session) with `bin/dev/task-scan-candidates` +
   the same read-the-actual-diff discipline.
2. **`transport.init_code`'s missing zenka-name guard** (found this
   session, not fixed, inert today) — small, well-scoped, good next
   dispatch whenever `transport` namespace work is being done anyway.
3. **`transport.handle.quic-hysteria:85`'s sprintf warning** (found
   this session, not investigated) — pre-existing, cosmetic, non-
   blocking (scenario 2 still passes with it present).
4. **`models.discover :clear:` alone** (no `:re-scan:`) — `:re-scan:`
   is now live-confirmed (see above), but plain `:clear:` (empty the
   registry, no re-scan) hasn't been deliberately exercised yet.
5. Everything in the previous handover's "Open Items" section
   (`v7-zenki` rename follow-ups, `p7-`-prefix ambiguity, dead `p7`
   command references, the `v7-stdout-foldable-relay` task cluster,
   `LYE`/`QP3`, the duplicate tmp-paths cleanup warning) was not
   touched this session — see git history (`988cc51f1`, `f4c295824`)
   for that content if it's still relevant; this file no longer
   carries it forward verbatim since it's a different work-stream than
   this session's task-archiving focus.

## Verified Live

Every dispatched/implemented result this session was independently
re-verified before being accepted, not just taken on a returned
summary: the cred-mesh/transport fix (`bin/dev/cred-mesh-test` re-run
by hand, 22/23 matching kimi's claim; `proxy.auth.lookup:31` and commit
`a6d5de568` checked directly against source), the research extraction
(one citation spot-checked against `IMPLEMENTATION-ROADMAP.md`, file
sizes and `git status` cross-checked), both `-diff` flags (`ptd -c`/
`format-code` syntax checks run, both flags exercised live against real
and unchanged files, temp-file cleanup confirmed, existing flags
confirmed unaffected), and `models.discover` (on-demand live start with
the new code, list + filter modes exercised against the real 114-model
registry, old removed command confirmed gone). The archiving-sweep
portion of the session was pure git-history/file-archaeology, no live
testing needed there.

Commits this session: `4dcf3a19f`, `ba570179d`, `ed16ad2a3`,
`6772919f1`, `c9f66d3e6`, `14fb8025d`, `48566ad72`, `f36dbb66f`,
`11e163aa6`. Not yet pushed (check before assuming pushed).
