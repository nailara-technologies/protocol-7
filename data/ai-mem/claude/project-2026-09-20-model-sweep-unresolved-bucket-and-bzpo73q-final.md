---
name: project-2026-09-20-model-sweep-unresolved-bucket-and-bzpo73q-final
description: follow-up to [[project-2026-09-20-model-sweep-crash-bucket-resolved]] — resolved the 6 never-retested checksums from that session (3 more deletions, 2 correctly left alone, BZPO73Q rescued-then-later-permanently-deleted); closes the model-cleanup disk-space accounting for the whole 2026-09-17..21 window
metadata:
  type: project
---

direct continuation of [[project-2026-09-20-model-sweep-crash-bucket-resolved]],
same day (session `6e49f0ab`, 2026-09-20 16:32), resolving that session's
"never retested this session — do NOT delete or trust the old verdict either
way" bucket of 6 checksums.

**resolved this session:**
- `CNTO5UA:I3LQTMQ` (Qwen2.5 7B Instruct, **5.82GB**) — confirmed genuinely
  broken (crashed both backends), deleted.
- `ZIZEKAI:AVC2JIY` (SOLAR 10.7B Instruct v1.0 Uncensored, **5.70GB**) — same,
  confirmed broken, deleted.
- `XF2GMAI:25WM54I` (Kimiko-v2-13B, **7.33GB**) — deleted on curation
  (redundant, failed self-test), not a crash-bucket verdict.
- `EBCVWUQ:734SX4I`, `XQBLBNQ:SIZ4UDI` — correctly left untouched, both
  reassigned to different currently-wanted models.
- `BZPO73Q:F7DO47A` (Bonsai-27B, misleadingly labeled — actual file only
  ~3.5-4.4GB, a mismatched/wrong-quant download for a "27B" name) —
  **rescued from trash** this session: functional, generates correct
  answers, just impractically slow (~2.5 tok/s, `ftype=40` enum gap in
  `ik_llama.cpp` + unoptimized quant kernel). live-confirmed the mismatched
  `qwen35` jinja template override (fixed same session, see below) was an
  *additional* bottleneck on top of the inherent kernel slowness — TTFT
  85-380s -> ~38s once excluded.

**two real bugs found+fixed this session:**
1. `models.gguf.file.extract_metadata` silently skipped string-array
   elements (e.g. `general.tags`), desyncing byte-offset reads for every
   subsequent header field — root cause of `source.url` never appearing.
2. `coding.handler.fetch_model_discovery` sent `models.cmd.discover`
   (wrong name) via `send.local` instead of `models.discover` via
   `route-send` — `coding`'s startup auto-discovery had been silently
   failing on every start.

a third fix (global jinja chat-template override unconditionally applied
regardless of `general.architecture`) is its own separate memory entry:
[[project-2026-09-20-jinja-template-arch-gate]] — don't duplicate detail
here.

the `plugin.auth.unix` identity-bypass security fix also landed this
session — already the standing CRITICAL memory entry
[[project-2026-09-20-unix-auth-identity-bypass-fixed]], not duplicated here.

this session also dispatched `mcp-p7-command-async-parity.md` and
`model-batch-test-harness-isolation-and-review.md` to kimi as
**design/decision-narrowing dispatches** (the harness doc's own "resolved
spec (kimi decision-narrowing pass, 2026-09-20)" section is that dispatch's
output) — NOT implementation. Confirmed 2026-09-21: no code from either
dispatch ever landed (`git log` on `bin/mcp-server-p7` since 2026-09-19:
empty; no async path exists off `cube_command`). Real implementation of the
batch-harness doc was dispatched for the first time 2026-09-21 (kimi
session `a8a8213c-e355-4137-9036-7aabd4921740`, see the harness doc's
"SUPERSEDED 2026-09-21" concern-2 section for the checksum-native,
zero-git design the owner specified for that dispatch).

## BZPO73Q's final deletion + trash purge — 2026-09-21, undocumented until now

owner reported directly (2026-09-21, no Claude/kimi session backs this —
checked via `session_catchup` across all sessions in the 09-20 16:32..21:00
window plus a direct grep of every local session `.jsonl`, nothing found;
this was a manual action outside any AI-assisted session) that BZPO73Q was
deleted a second time (this time for good — too slow to be worth the disk
regardless of the template fix) and the models trash was subsequently
purged (`models.cmd.trash-prune`).

**owner's stated reasoning for the permanent (not just re-trashed) removal**:
~2.5 tok/s is slow enough that leaving BZPO73Q in the model registry would
keep causing errors/timeouts across every future sweep and batch-test
iteration that walks the model list, unless the harness/sweep machinery
got larger-scale timeout/budget adjustments made *specifically to
accommodate this one model*. not worth it for a single outlier — curate
the model list rather than carry infrastructure burden for it. relevant
precedent for [[MODEL-BENCHMARK-HARNESS]] / the model-batch-test-harness
work: even with a tps-relative per-model budget already designed
(`reference_tps/observed_tps`, clamped [1x,30x] — see
`model-batch-test-harness-isolation-and-review.md`'s resolved spec),
the owner's default is still "delete genuinely extreme outliers" over
"widen the harness to tolerate them" — the budget mechanism is for
legitimate speed variance across the registry, not a reason to keep a
model whose only value is passing self-test slowly.

**disk-space accounting now closes exactly**, confirming this was the only
gap: crash-bucket session recorded 105GB->208GB avail on
`/mnt/ext-xfs-data` (103GB freed). Current state (2026-09-21): 231GB avail
— a 23GB delta since that session. This session's 3 deletions
(5.82+5.70+7.33 = 18.85GB) + BZPO73Q's final removal (~4.4GB, the trashed
directory's on-disk size incl. sidecar) = ~23.25GB, matching the observed
23GB delta almost exactly. **Total model-cleanup across the whole
2026-09-17..21 window: ~126GB freed, not the ~180GB first eyeballed** — the
180GB figure was a rough estimate against the wrong baseline; 126GB is the
number that actually reconciles against `df`.

models trash (`/mnt/ext-xfs-data/models-lmstudio/.trash/`) is confirmed
empty as of 2026-09-21 — nothing pending rescue from any of the above.

#,,,.,..,,.,.,,..,,.,,.,.,,.,,.,,,..,,,,.,..,,..,,...,...,.,,,,..,,.,,,..,.,,,
#MHJ2L7J2KU26I7FK5OXUAWK2LDMRW4MS3AEF2BJDBYX4CYUEGBGQLQHHTA2QYS6PDYGDI4S2RWICI
#\\\|LBIIGM3B4U5VG5N5PK7ZU7GULVUENR7GCKRJZKSRFAMEWY7T2NM \ / AMOS7 \ YOURUM ::
#\[7]G7F7OZZRUMXWIFQU2FVEGEG2ZXF6FGTSX5BSXNBWMSLBW53V7WDA 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
