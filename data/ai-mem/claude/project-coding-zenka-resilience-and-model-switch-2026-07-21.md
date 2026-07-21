---
name: project-coding-zenka-resilience-and-model-switch-2026-07-21
description: session landing coding-zenka timeout/backend-lock bugs, a model default switch (ZDMAPAY:AR3OCKQ), self-test resilience, and three new design docs
metadata:
  type: project
---

long session, many commits on `base`. grouped by theme, all live-verified not just
code-reviewed (repeated pattern: catch wrong self-reported "success" via actually running
the fix against a live model, not trusting the completion message — worth remembering as
methodology, see [[feedback-verify-by-live-execution]] if that gets written up separately).

## coding.ask-reply pipeline bugs (b9689d5ad, 3b9689119, e876ed5a2)
- stall-timeout watcher armed at connection setup raced the properly-scaled data-start
  grace period for large prompts — fixed to arm on first received chunk instead.
- `coding.callback.http_error` looked up `<coding.inference_servers>` by routing name
  (`single-llm`) instead of mapping to the hardware key (`gpu`/`cpu`) like
  `send_request`/`task.execute` already did — timed-out tasks hard-failed instead of
  restarting the backend.
- `modules/context.file` forced absolute paths into repo-relative resolution (stripped
  leading `/` unconditionally) — broke reading e.g. `/etc/protocol-7/jobsite/profile.txt`.
  fixed to match `list_files`'s existing absolute-path handling. **then** the live
  file-io-fix.yaml test (see below) introduced a real regression fixing this same file
  (`split /\n/` dropped trailing newlines) — caught and fixed same session
  (`split /(?<=\n)/` lookbehind, keeps newline attached).

## still-open bug found, NOT yet fixed in code
`coding.cmd.task-append` rebuilds a resumed round's backend field from
`$task->{execution}->{backend}` (hardware key, e.g. `gpu`) instead of
`$task->{analysis}->{routed_to}` (routing key, e.g. `single-llm`) — the field
`coding.async.backend_acquire`/`release` and the lock namespace actually use. any task
resumed via `task-append` whose original routing wasn't `gpu` leaks its backend lock
forever on next completion (confirmed live: a task queued 66 minutes behind a lock held
by a long-completed task). unstuck live via `coding.eval-code` calling
`backend_release` directly with the correct routing name — **the underlying task-append
bug itself was diagnosed but not patched**, worth fixing properly next time it's touched.

## access-profiles design work (31a2a652b, f6fe2e130, 096365132 unrelated to this)
formalized composable read/write path-scope + tool-capability profiles for coding-zenka
tools — see [[topic-coding-zenka-path-access-profiles]] (already indexed) and
`data/md/design/CODING-ZENKA-ACCESS-PROFILES.md`. also produced
`data/md/philosophy/TRANSLUCENT-LAYERING-SECURITY-MINDSET.md` (posture doc: layers are
translucent/judged, not walls; worst case for adversarial input = a forensic record).

## file-io-fix.yaml live model testing (multiple commits)
dispatched the same "migrate raw open() to file.* routines" task across several 9B
candidates as a real bake-off: OmniCoder (DVEAZIA:GPAKBLA) dropped newlines reconstructing
a string (misunderstood `split` LIMIT semantics); Sushi-Coder-RL (UU4JSVQ:MEHBONI) staged
the wrong variable entirely (one new line instead of the whole file) — both models
demoted/removed from `configuration/zenki/coding/start` candidate list as a result.
`file-io-fix.yaml` itself strengthened with a dedicated warning section citing both real
failures — the pattern both times was the seam between per-line-array/filehandle code and
the single-string argument `file.slurp`/`file.put` actually take.

## bin/ptd exclusion regex fix (047c5d338)
`grep { !m{^@exclude_pattern} }` interpolated an array into a regex by stringifying with
spaces, not alternation — never excluded `.md`/`.yaml`/`.yml`/`.asc` files as intended.
fixed with real alternation; also had to ensure it runs *before*
`is_perl_code()`'s content-sniffing, which matches on the `## [:< ##` module-header marker
that some `.md` design docs also use for style consistency.

## coding zenka default model switch (096365132, 047c5d338) — current live state
default is now **ZDMAPAY:AR3OCKQ (Qwopus3.5 9B v3)**, replacing IXNBXVI:U2XBEXQ. also
restored vision capability (IXNBXVI was text-only). two config values changed
specifically for this model: `inference.model.context_length` 52000→28000 and
`coding.cfg.vram_safety_max_mb` 3000→4000 — `calculate_safe_context` budgets the mmproj
*file's* static size but not the vision encoder's runtime compute buffer, which caused a
live CUDA OOM during vision warmup at the old context floor (confirmed: only 188MB free,
558MB buffer alloc failed). enabled `qwen3.5-fixed.jinja` template override — confirmed
via the model's own GGUF metadata (`general.architecture=qwen35`) that this applies to any
qwen3.5-family model, not just a "vanilla" build.

## self-test resilience (047c5d338)
`coding.self_test.run`'s HTTP client was one-shot with no retry (unlike the main task
pipeline) — added one retry on 5xx/connection-failure. separately,
`coding.self_test.run`'s result was previously discarded entirely by its caller
(`coding.handler.monitor_inference_startup`) — nothing reacted to failure. added: a tier1
failure on the "cat test" (prompt_id 2) now triggers a bounded restart-for-fresh-seed
(`seed=0` already derives a new harmonic seed from ntime+fortuna per spawn, so a plain
restart suffices — no seed-forcing code needed), capped via
`coding.cfg.self_test_seed_retry_max` (default 2). **two bugs found live-testing this same
new logic, both fixed same session**: the retry counter's storage key
(`<coding.self_test.seed_retry_count>`) collided with `<coding.self_test>`'s existing use
as the epoch-keyed self-test archive, breaking `self-test-status`'s numeric epoch
comparison (moved to a separate top-level key); and the restart never actually fired
because `spawn_servers_deferred` only spawns what isn't already running — fixed by setting
`status = restart_needed` + clearing the cached pid first, mirroring `http_error`'s already-
working restart path. final live-verified sequence: 5xx → retry → still fails → cat-test
restart scheduled → fresh spawn → self-test re-runs → 2/2 passed clean.

## new design docs, one marked blocker-level
- `data/md/design/ASCII-BUDGET-SLOT-CONVENTION.md` — names the resource-agnostic
  fixed-width-bracket-as-state-register principle; three independent pre-existing
  implementations found (`bin/ptd show_progress`, `ascii.frame.bar`/`slot.select`,
  `coding.cmd.round-progress`).
- `data/tasks/task-zenka-cold-queue-gpu-cooldown-trigger.md` — task zenka should gate
  deferred background work (summary-of-summary processing) on the GPU actually having
  cooled, using the same live temp feed coding already subscribes to, not a guessed
  debounce timer. **note**: the motivating anecdote (kimi_dispatch summaries seeming slow)
  turned out to be a misread of normal rolling-context display, and the "task zenka
  immediately proceeds into follow-on work" premise doesn't match the code — there is NO
  summary-of-summary consumer anywhere yet (`integrated => FALSE` is written, never read).
  design still stands on its own merits, motivation section rewritten accordingly. Opus
  planning pass produced a full phased implementation plan in the same file.
- `data/md/design/SUGGESTION-INTEGRATION-QUEUE.md` — **marked required/blocker-level by
  user**, not aspirational, for the ncode workflow and every coding-zenka-based workflow
  (and a future forensics zenka). core principle: "nothing is ever lost, only not approved
  yet" — queue manages atomic inputs, not sources (adding a producer means "something
  writes cards," never a new integration path). generalizes the existing
  `/var/protocol-7/coding/staged/*` mechanism cross-zenka. approval is a gate role, not
  necessarily a person — future-eligible to be filled by reliable zenki/model-consensus
  groups, and this is safe specifically because accepting-into-the-queue was never
  contingent on restricting sources (visibility isn't risk) — automating the gate only
  changes who can move a card past it, never what's safe to accept.

## also found, not yet acted on
`coding.learning.record_outcome` (persists to
`/var/protocol-7/coding/learning/outcomes.json`) has zero call sites anywhere; the
command-surface version `coding.learning.track_success` is entirely placeholder (every
function returns hardcoded fake data). neither schema has a `model_id` field, only
`service` (routing destination) — can't distinguish which model produced an outcome on
the same backend slot over time. relevant if/when model-comparison-statistics work
(discussed, not built) picks up.

#,,.,,,..,,..,,.,,.,,,.,.,,,,,..,,..,,,,,,.,,,..,,...,..,,,.,,...,,,.,,,,,,..,
#5MEL7PFC6TDPUIQAD6OPHP3FGC4YIBAPM6UNOPIBJ5PUCNKHCE7IMNLFKZZUJNGFCSFJVFM53KUDE
#\\\|A3ARGUDZFEUVDMMS2EFSJVLXNA6P6AAIEBVXZL54USNP3VHNDDW \ / AMOS7 \ YOURUM ::
#\[7]2QOOYYKXAOZNJHIKTRVFXAQHPMYM4XZFLWZQGBRYEIGVJJ6TWYAI 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
