# model benchmark harness & multi-parameter scoring — design

topic 1 of 6, split off `AUTONOMOUS-MODEL-MANAGEMENT.md`'s subsystem
decomposition (2026-08-27) — foundational, everything else in that doc's
layer 2/3/4 needs this to exist first. see that doc for the full
four-layer picture this slots into; this doc covers only "run one
canonical workload against one model, get a real multi-dimension score
back."

## core idea

a deterministic, repeatable way to answer "how good is model X at task
type Y, right now, on this hardware" — correctness AND cost (latency,
throughput, memory) together, not correctness alone. the missing
foundation under `llm.service.consensus_vote`'s stale hardcoded model
list, and under the dormant `models.statistics.invocation_tracking`
pipeline (see below) — this is the thing that would give both of those
real data instead of a placeholder and an empty store, respectively.

see also [`MODEL-STATUS-TRACKING.md`](./MODEL-STATUS-TRACKING.md) — a
smaller, prerequisite-free companion: coarse pass/fail functional status
per model, buildable and independently useful before this doc's
multi-parameter scoring lands. natural build order is that doc first,
this one second.

## two real precedents already in the codebase — mirror these, don't
## reinvent from a blank page

**`iteration.loop` + `iteration.score_result`** (`src/iteration.loop`,
`src/iteration.score_result`) — a real, working criteria-based scoring
engine: given a result string and a list of text criteria, heuristically
checks each criterion (substring/regex presence), classifies pass/fail/
partial with a `fixable_by` tag (template/user/model/none), produces an
aggregate 0.0-1.0 score and a verdict (advance/retry/escalate), and
tracks per-task state (`attempt_n`, `best_score`, `best_result`,
`deltas`) across repeated attempts up to `max_attempts`. **this is
single-model retry-until-good-enough, not cross-model comparison** — the
benchmark harness needs the comparison shape (same workload, N models,
one round each, compare scores), but the actual per-attempt scoring
mechanics (criteria list → per-criterion verdict → aggregate score) are
directly reusable as the "correctness" dimension of a multi-parameter
score. two "needs-testing" task files already wire this engine into the
`models` zenka's task flow (`data/tasks/needs-testing/
models-task-iteration-wiring.md`, `models-handler-task-result-iteration.md`
— modify `models.task.execute` / `models.handler.task-result` to route
through `iteration.loop` when `$task->{'iteration'}` is true) — worth
landing those first or alongside this, since the benchmark runner's
"submit workload, get scored result" primitive is close to what those
task files already describe wiring up, just for a different trigger
(iteration-flagged real tasks, not deliberate benchmark workloads).

**`models.decision.recommendation_base.calculate_composite_score`**
(`src/models.decision.recommendation_base.calculate_composite_score`) —
weighted multi-dimension aggregation, confirmed by direct read: fixed
default weights `quality=>0.4, speed=>0.3, cost=>0.2, availability=>0.1`,
combining `statistics.success_rate`, `latency.p99_ms`, `cost.monthly`,
`presence_decision.currently_present` off a model's registry entry.
**this is the consumer end** — it assumes those fields are already
populated and just combines them; it has no notion of running a workload
to populate them. its caller `models.decision.recommendation_engine.
get_model_recommendations` does iterate the FULL model registry (all
~87 current entries, not just ones with history — confirmed via
`models.registry.list_all.list_all_models`), but an untested model
silently defaults toward a near-zero score through `// 0`/`// 1000`/
`// 100` fallbacks rather than being flagged as genuinely unscored. the
weighted-combination PATTERN here is worth mirroring for the benchmark
harness's own multi-parameter aggregation (see "scoring model" below),
even though the code itself isn't reusable as-is (wrong inputs — historical
production stats, not benchmark-run results).

**the producer this whole harness would feed**:
`models.statistics.invocation_tracking.record_invocation` — shipped,
schema exists (`get_context_statistics`, `aggregate_statistics`,
`calculate_margin_vs_alternative`, `cleanup_old_logs` all real code) —
but reachable from exactly ONE place in the entire codebase: its own
command entry point `models.cmd.record_invocation`. nothing in real task
completion flow calls it. `models.cmd.recommend` is live and callable
but its output is only as meaningful as these currently-empty stats.
landing this benchmark harness and wiring its results into
`record_invocation` would make that whole existing cluster do real work
for the first time, rather than adding a competing system next to it.

## canonical workload format

the 6 workload types already named in `AUTONOMOUS-MODEL-MANAGEMENT.md`
layer 2 (`tool_call`, `code_edit`, `reasoning`, `vision_desc`,
`context_retain`, `format_comply`) need a concrete yaml schema, not just
names. sketch, open to revision:

```yaml
workload:
  id: tool_call.basic_edit_file
  type: tool_call
  suite_version: 1              # score history only comparable within a version
  prompt: "..."                  # or a template + fixture data
  criteria:                      # fed directly to iteration.score_result's shape
    - "correct tool name invoked"
    - "arguments match expected schema"
    - "no extraneous prose in tool-call block"
  expected: null                 # or a literal, for deterministic-answer workloads
  timeout_class: interactive     # vs background — informs which timeout-scaling
                                  # tier applies (see coding-backend-aware-
                                  # timeout-scaling.md's live-tps-derived cap)
```

## scoring: multi-parameter, not correctness alone

correctness (via the `iteration.score_result`-shaped criteria check) is
one axis. the others, all with real data sources now (none of this needs
new instrumentation to start from, only aggregation on top):

- **latency (ttft)** — `coding.self_test.multiplier`'s `ttft_p95` pattern,
  generalized from "one backend's timeout tuning" to "this model's
  latency dimension of its suitability score."
- **throughput (tokens/sec)** — `coding.async.stream_tps`, landed
  2026-08-27, live per-round measurement, and the `coding.self_test.
  archive` `tps` field it finally gave a real producer to.
- **memory footprint** — model size (`size_gb` in `coding.model_metadata`)
  is already known at registry time, no run-time measurement needed for
  this one; only becomes interesting combined with the live VRAM/RAM
  checks already in `coding.handler.spawn_smart`.
- **P7 native-idiom conformance** — proposed new dimension, folded into
  `format_comply`: does generated code use the project's own native
  routines/structures (`base.*` primitives, swap_subs-aware naming, the
  P7 macro syntax) rather than reinventing or importing foreign idiom.
  same lens already applied informally at kimi-dispatch time tonight
  (`data/yaml/code-style/CONVENTIONS.yaml`, the kimi-dispatch-workflow
  context template) — this generalizes it into a scored, structural
  check instead of a per-dispatch reminder. concretely: could reuse
  whatever `bin/dev/gen-sub-whitelist`/`ncode`-family tooling already
  parses P7 syntax with, rather than writing a new parser.

open question, not yet decided: is the combination weighted like
`calculate_composite_score` (fixed or per-role weights, simple weighted
sum), or does it genuinely need `base.curve.*`'s fitting/interpolation
machinery (curve-fit across a parameter space rather than a flat weighted
sum)? a flat weighted sum is simpler and has a direct precedent already
in this codebase (`recommendation_base`); `base.curve.*` was floated
originally in `coding-backend-aware-timeout-scaling.md` for a narrower
problem (deriving one timeout number from one throughput measurement) —
worth confirming it actually generalizes to N-parameter suitability
scoring before committing to it over the simpler, already-precedented
weighted-sum approach.

## suite-version discipline

score comparisons only valid within the same `suite_version` (per-
workload, per the yaml sketch above) — a prompt wording change or
criteria update invalidates cross-version comparison. mirrors the
parent doc's existing note on this; concretely enforced by tagging every
stored score record with the suite version it was measured against, and
having any comparison/recommendation logic refuse to mix versions
silently.

## the suite-self-improvement loop — explicitly out of scope for this doc

optimizing the canonical prompts/system messages themselves toward
broadest cross-model success coverage (raised in the parent doc) is the
least-specified piece of the whole system and needs the rest of this
harness working first, to have something to run experiments against.
not designed here — flagged as its own future sub-document once there's
real score history to analyze.

## what actually needs building

1. `models.benchmark.suite` — yaml workload definitions (schema above),
   versioned.
2. `models.benchmark.runner` — submit one workload to one model, collect
   the raw result + timing/throughput signal, invoke the scoring
   pipeline (correctness via the `iteration.score_result`-shaped check +
   the other parameters above), return a structured score record.
3. the aggregation function itself — weighted-sum (mirroring
   `calculate_composite_score`) unless `base.curve.*` is confirmed to
   genuinely earn its complexity over that.
4. wiring into `models.statistics.invocation_tracking.record_invocation`
   so benchmark runs feed the existing dormant store, not a new one.

`models.benchmark.store` and `models.benchmark.compare` (score
persistence/history and cross-model recommendation) are topic 2's scope,
not this doc's — this doc stops at "one workload, one model, one score
record."

## validation

execution-free where possible: the scoring/aggregation logic itself
(given a canned result string + timing numbers, does it produce the
right score) needs no live model at all, same pattern as tonight's
`coding.async.stream_tps` and `iteration.score_result`-adjacent test
harnesses. the runner's actual submit-and-collect path needs a live
model to prove end-to-end, same caveat as everything else in this
project's coding-zenka work — standalone tests first, live verification
by the user after.

```

#,,..,.,.,,,.,,..,,,.,..,,,..,,,.,..,,..,,.,,,..,,...,...,.,.,,..,...,...,,,.,
#HOYKXERNUDG7NLRVTPIDXR676FF4WAWZOYFNDTHYUMAIIGUWEEW6QJ4B3FOCMD65IMNCRZAECAUYG
#\\\|EVFYZHJYJ2LENG4JP526WQZZANI5MDQGUNJ7VHTEWRXHIXSE5GX \ / AMOS7 \ YOURUM ::
#\[7]3SVHZTE64VYKMED4L76I4JGCXJ72TVKY7XWZBUFHCHAMN2FPJUDY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
