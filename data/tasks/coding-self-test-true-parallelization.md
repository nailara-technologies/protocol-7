## [:< ##

# name  = task: make gpu/cpu self-test genuinely parallel (not just waited)
# descr = full audit done and safe to proceed -- implementation not yet
#         done, one broken partial edit was found and reverted for safety.

## context

`data/tasks/coding-self-test-parallel-backend-gap.md` (option 1, landed
2026-08-26) made a backend losing the single-flight guard race WAIT
(var-watcher wake, safety-net timeout) instead of being silently
dropped. That's correct and stays. But it's still fully sequential: only
one backend's self-test runs at a time, whichever wins the race for
`<coding.self_test_probe_in_flight>`.

found live the same day: since CPU is ~7-8x slower than GPU (see
`coding-backend-aware-timeout-scaling.md`), if CPU happens to win the
race, GPU -- which would otherwise be usable in seconds -- sits blocked
behind CPU's slow self-test cycle for up to the ~1700s safety-net
ceiling. a fast backend's availability is held hostage by race-order
luck. this is "option 2" from the original task file, deferred at the
time pending an audit of whether the probe state machine assumes
single-flight elsewhere.

## audit verdict (2026-08-26, complete, trust this -- don't re-audit)

**no genuinely unsafe cross-backend shared state exists.** the per-
backend HTTP lock (`coding.async.backend_acquire`/`.backend_release`,
keyed by `$backend` in `<coding.state.backend>`) already correctly
partitions the actual HTTP layer in `coding.self_test.async_probe` and
`coding.self_test.handler.poll_probe`. probe state itself is
`$probe_id`-keyed (unique per call via `base.gen_id`), never shared
across concurrent probes. `<coding.self_test_probe_in_flight>` is the
ONLY thing forcing cross-backend serialization -- it's not load-bearing
for correctness, only for the (now unnecessary) assumption that self-
tests must be single-flight.

two follow-up verifications were also resolved, both clean:
- `file.zenka_dir.load`/`.write` (used by `coding.self_test.archive`'s
  YAML stats read-modify-write) are **synchronous** -- `load` calls
  `file.slurp` directly, `write` uses plain `open`/`print`/`close`/
  `rename`, no event-loop yield between them. the archive's ntime-
  collision concern (two backends testing the same model_id in the same
  ntime tick landing in the same `<coding.self_test>->{$ntime}{$model_id}`
  node) is therefore not a real race -- Perl's single-threaded event loop
  means one archive call runs to completion before the next starts. this
  was already independently confirmed non-blocking for correctness too
  (no decision code reads the archive tree, only display/history
  commands do).
- `coding.self_test.multiplier` (called from `poll_probe` ~line 477) has
  **no genuine collision risk** -- its model_id-keyed writes are either
  array-push (naturally convergent) or flat-overwrite where the later
  writer's value is the more-accurate one anyway.

## what implementation actually requires (none of this is done yet)

1. **the guard becomes a hash**, keyed by backend id, not a scalar --
   touch points: `coding.self_test.run` (~line 63 check, ~line 163 set
   -- BOTH must change together, see the broken-partial-edit warning
   below), `coding.self_test.handler.poll_probe` (~line 526 clear).

2. **`coding.handler.verify_inference_startup:49`** -- a fourth reader
   of the guard not caught in the original scoping, found only via a
   full-codebase grep (`grep -rn self_test_probe_in_flight src/`) --
   ALWAYS do this grep fresh before touching this guard again, don't
   trust any historical touch-point list including this one. confirmed
   `$backend` is already in scope at that call site; needs
   `<coding.self_test_probe_in_flight>->{$backend}` instead of the bare
   scalar check.

3. **`coding.helper.trigger_backend_self_test:242`**: `//= FALSE` must
   become `//= {}` once the guard is a hash (FALSE is `0`, a non-
   reference scalar -- dereferencing it as a hashref dies under strict
   refs).

4. **the var-watcher redesign is the trickiest part, get this right**:
   `event.add_var`'s `poll=>'w'` fires when the WATCHED SCALAR ITSELF is
   reassigned -- not when a hash key inside what it points to is
   mutated. a single watcher on the guard hash's own top-level scalar
   slot will never fire again once the guard becomes a hash (confirmed
   via first-principles Perl semantics, this was caught by audit before
   any code was written). the fix: register ONE WATCHER PER BACKEND,
   each holding `\$data{'coding'}{'self_test_probe_in_flight'}{$backend}`
   -- a real scalar reference into one specific hash value slot, writes
   through which (`<coding.self_test_probe_in_flight>->{$backend} = X`)
   DO fire that watcher. this is exactly
   `jobqueue.event.register_job_queues`'s own pattern: one `event.
   add_var` watcher PER QUEUE NAME (`\$counters->{$queue_name}`), never
   one shared watcher over the whole counter hash. mirror it exactly,
   including its cancel-if-still-active-before-reregistering guard,
   tracked per-backend (`<coding.watcher.self_test_guard>->{$backend}`,
   not one scalar slot).

   `coding.helper.self_test_guard_watcher`'s body should get SIMPLER
   under this redesign, not more complex: it currently loops over every
   backend in `<coding.self_test_retry_pending>` on a single firing,
   because one shared watcher had to coalesce multiple backends' wakes
   into one event. with per-backend watchers, each watcher instance only
   ever needs to check its OWN backend's guard slot and pending state.
   rewrite the handler body accordingly rather than preserving the
   multi-backend-per-firing loop.

5. **update `bin/test-scripts/test-coding-self-test-retry.pl`** to match
   -- per-backend hash guard in the stub `%data`, per-backend watcher
   stubs, and new scenarios proving genuine concurrency (both backends'
   `coding.self_test.run` calls succeed with `mode=>'deferred'`
   simultaneously, both `on_done` callbacks can be in flight at once,
   completing independently with correct per-backend state).

## known-broken partial edit, already reverted -- do NOT reapply as-is

a 2026-08-26 implementation attempt ran out of budget after editing
ONLY the check side (`coding.self_test.run` line ~63, wrapped in
`(<coding.self_test_probe_in_flight> // {})->{$backend}`) without also
updating the set side (line ~163 still did
`<coding.self_test_probe_in_flight> = TRUE`, a plain scalar). this is a
genuine crash bug if left in place: after the first self-test starts,
the guard becomes the scalar `TRUE` (5), and the very next contention
check dereferences `5->{$backend}`, dying under strict refs. found and
reverted via `git checkout -- src/coding.self_test.run` before commit,
so it never shipped. when implementing for real, change the check AND
the set (AND the clear in `poll_probe`) in the same pass, verify with
the standalone test harness before considering it done -- don't let
these three touch points drift out of sync again.

## do NOT touch (unrelated fixes from the same day)

`coding.spawn_inference_server`, `coding.helper.calculate_safe_context`,
`coding.init_code`, `coding.init_dependencies`, `base.dependency.ok`,
`coding.resolve.object.model_path`, `coding.resolve_model_path`,
`coding.callback.object.model_path`.

## validation

`bin/dev/ptd -c` on every changed file. full pass of
`bin/test-scripts/test-coding-self-test-retry.pl` after the rewrite,
plus the existing suite from the same day
(`test-coding-cpu-spawn-path.pl`, `test-coding-model-path-resolve.pl`,
`test-coding-cpu-ram-context-clamp.pl`, `test-coding-cpu-ld-library-
path.pl`, `test-coding-model-path-deps-wired.pl`, `test-dependency-
resolve-hook.pl`, `test-coding-gpu-foreign-process-check.pl`) to confirm
nothing else regressed. live verification only after standalone tests
pass, and only by the user directly -- never restart/reload the live
coding zenka as part of implementing this.

not urgent in the sense of "broken today" -- the sequential wait-based
fix already landed and works correctly, just not optimally. this is a
real usability improvement, not a bug fix.

#,,,.,,.,,...,,..,..,,,,.,,,,,...,...,,,.,,..,..,,...,..,,..,,,..,,,,,,,,,,..,
#JDIWEBJUZBPDXPMC3XXGODFC4AK74F7PAVEUODGZXIBM4SFO7KGGMGUZ4CF4ZGQTB4FP7N7KCWD62
#\\\|LBGN26VWPCH5BYFAEDZYEUADTCFN7GKLCCD33LL4VUFBJGGZ6OO \ / AMOS7 \ YOURUM ::
#\[7]PSZL5MKP5P5I5SCQNMK56ZJJ36ANXVRX54GW5HTH3OCJLKUVHODQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
