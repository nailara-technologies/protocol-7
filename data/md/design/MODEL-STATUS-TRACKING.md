# model functional status tracking + sweep iterator — design

closely related to `MODEL-BENCHMARK-HARNESS.md` (topic 1 of
`AUTONOMOUS-MODEL-MANAGEMENT.md`'s decomposition) but smaller and more
tractable — this doesn't need the multi-parameter scoring system to
exist first. it's the coarse gate that would run *before* anyone bothers
with expensive multi-parameter benchmarking: does this model even start,
does it pass a basic self-test, at all. genuinely buildable now,
independently useful even before topic 1 lands — `llm.service.
consensus_vote`'s candidate pool could filter on `functional` status
alone as a stepping stone before real scoring exists.

## part 1 — status table

### states

```
untested             default -- no entry yet, nothing has ever tried this model
functional           full self-test pass (3/3, same bar as coding.self_test)
inference-failures   server came up, self-test ran, did not fully pass
startup-failure      server itself never came up
```

a fifth state, `resource-insufficient` -- `spawn_smart` can return early
because a model doesn't fit in available VRAM/RAM on THIS host right
now, a different failure class from a genuinely broken model (crashes,
hangs, produces garbage). folding it into `startup-failure` would make a
perfectly good model read as permanently broken. resolved below (see
"keyed per (model, backend), not per model alone") rather than left open
-- once status is backend-scoped, this state is not just useful but
necessary: it's the natural value for a model that fits fine on one
backend but not another. checked live via `harmony resource-insufficient`
alongside the other four before finalizing.

### keyed per (model, backend), not per model alone

resolved 2026-08-27, following directly from the sweep iterator's
independent-cursors decision below: a model's status is NOT one value.
`functional` on gpu doesn't imply anything about cpu -- different binary
code paths, different quantization/threading behavior, and (the
concrete trigger for this) a model can be a clean fit for one backend's
memory budget and not the other's. every state above is scoped to a
`(checksum, backend)` pair. a model can simultaneously be `functional`
on gpu and `resource-insufficient` (or simply `untested`, if the sweep's
pre-filter -- see below -- never even attempted it) on cpu.

### where this needs to live

**not** the in-memory `coding.self_test` archive
(`coding.self_test.archive`'s own comment is explicit: "does not survive
a zenka restart"). "remembers status" implies durability across
restarts, so this needs its own small persisted store, keyed by
`(amos checksum, backend)` -- a yaml file under `data/yaml/` or the
zenka runtime data convention under `/var/protocol-7/coding/` (matching
how other coding-zenka runtime state already persists). not a new
database, not folded into `coding.model_metadata` (that's the
discovery-side registry cache, mixing "what is this model" with "how has
it performed" is the same category error layer 2's benchmark scores
avoid by having their own store rather than living on the registry entry
directly).

### write sites (concrete, all real code paths that already exist)

1. `coding.self_test.handler.poll_probe`'s completion/record phase --
   `functional` if all prompts passed, `inference-failures` otherwise
   (the `2/3 passed`, `1/2 passed`-via-watchdog-abort shapes seen live
   tonight both land here).
2. `coding.handler.verify_inference_startup`'s retry-exhaustion path
   (`restart_count >= 5`) -- `startup-failure`. needs to resolve which
   model was being attempted at that moment
   (`<inference.backend.$backend.model_id>`).
3. `coding.handler.spawn_smart`'s early-return-on-insufficient-resources
   path -- `resource-insufficient`, scoped to the backend the attempt
   was made on.

## part 2 — async sweep iterator

once the status table exists, the natural next piece: an async
iterator that walks the model registry (`models.registry.*`, ~87
current entries) and drives self-test cycles for whichever models a
filter selects, recording results into the table above as it goes.

### filter modes

```
default            untested only
:re-test-failed:   also include startup-failure / inference-failures
:re-test-success:  also include functional (periodic revalidation --
                    a binary upgrade, driver update, or model file
                    change could flip a previously-good result)
```

modes combine (`:re-test-failed: :re-test-success:` == full sweep of
the entire registry, ignoring current status). single-colon
`:keyword:` is the real, consistently-used P7 network-command parameter
convention (`:sigs:`, `:stage:`, `:load:`, `:any:` — confirmed live
grep, exclusively single-colon in every real example in the codebase,
zero double-colon usage anywhere) — not the `--flag` unix-cli style,
which doesn't belong in a network-command context and already has a
known offender needing a later fix (`--yes` in `keys.backup.remove` /
`keys.console.prune-backups`). fixed here before it became a second one.

### this needs JEG's fix, already landed tonight

the sweep iterator is exactly the kind of caller that would drive
`switch-model` in a tight loop, one model after another. before
tonight's JEG fix (`src/coding.handler.spawn_smart`, cancel any in-
flight self-test before a force-kill respawn), a sweep like this would
have reliably left zombie guards between every single model in the
loop -- this wasn't a theoretical risk, it's precisely the failure mode
the sweep would have hit on its very first iteration. the sweep is a
genuine consumer of that fix, not just incidentally related to it.

### resolved: independent, potentially non-overlapping candidate lists per backend

decided 2026-08-27, and the reason it's non-overlapping rather than just
non-synchronized: gpu and cpu don't necessarily even WANT to attempt the
same models. `coding.model_metadata`'s `size_gb` against each backend's
typical available VRAM/RAM is a known, cheap, pre-flight signal --
gpu's candidate list can exclude anything that's a predictable
`resource-insufficient` on gpu before ever attempting a spawn, and
independently for cpu. this means gpu testing model N while cpu tests
an entirely unrelated model M isn't just parallelism for throughput
(though it is roughly double, same motivation as before) -- it also
avoids wasting a spawn attempt (and the real time/VRAM-thrash cost of
one) on a combination already known to fail the resource check, which a
single shared cursor walking one list in lockstep would not naturally
avoid. this is the direct payoff of the per-(model,-backend) status
keying above: each backend's sweep only needs to track ITS OWN cursor
against ITS OWN filtered candidate list, no cross-backend coordination
needed to avoid double-claiming since there's no shared list to
double-claim from.

### open design questions

- **resumability**: at ~87 models, and given self-test rounds can
  legitimately run long (the whole point of tonight's liveness-aware
  timeout work), a full `:re-test-failed: :re-test-success:` sweep could
  take a very long time. this should be a checkpointed, interruptible
  state machine (same shape as `poll_probe`/`poll_switch` -- an async
  iterator over a persisted cursor position, not a single blocking
  call), not an atomic all-or-nothing run. now per-backend: two
  independent persisted cursors, not one.
- **deliberately user-triggered, not automatic**: two separate reasons,
  not just one. cost is the defensive one -- repeatedly switching models
  means repeatedly loading multi-gigabyte files and cycling processes,
  real time and disk-I/O, so this shouldn't fire on a timer or on every
  registry change without real confidence in the safety/cost profile
  from manual runs first. but `:re-test-success:` specifically exists
  FOR user-triggering, not despite it: its actual purpose is giving the
  user a deliberate "regenerate assessments now" action after a change
  that can invalidate a previously-`functional` result without touching
  the model files themselves at all -- recompiling the inference server
  binary (`ik_llama.cpp`, already flagged as "not off the table" in
  `coding-cpu-and-hybrid-offload-path.md`), a driver update, a config
  change to threading/context defaults. the status table has no way to
  know any of that happened on its own; the user does, and this is the
  command for "I just changed something upstream of every model, go
  recheck." `:re-test-failed:` has the mirror-image case, specifically
  for `resource-insufficient`: some unrelated process was holding VRAM
  or RAM at test time, the recorded status is a false negative against
  the model itself, the user kills that process and wants to retry
  exactly the failures that might have been transient contention rather
  than genuine breakage -- without re-running everything that already
  passed. this should be a command a user runs
  (`p7c coding.model-sweep` or similar), not automatic.

## relation to other docs

- prerequisite-free relative to `MODEL-BENCHMARK-HARNESS.md` -- can be
  built and deliver value before that lands, though it's a natural
  on-ramp INTO it (the sweep's per-model self-test result is a coarser
  version of what a benchmark workload run would produce).
- feeds `llm.service.consensus_vote`'s stale-model-list problem directly
  and immediately: even before multi-parameter scoring exists, filtering
  its candidate pool to `status == 'functional'` on the backend it would
  actually run on is strictly better than today's three hardcoded,
  nonexistent model names.

```

#,,.,,,,.,,.,,,..,,,.,..,,,.,,.,,,,.,,.,.,,,,,..,,...,..,,...,..,,...,.,.,.,,,
#QF33OY256ME5ABC6A42LLXFN6UTDQZL6NJZ64TPQIGMOIKKB2P7T65CJ25KEPGO2XNHRD4JJEYKYS
#\\\|4HNIKOXCTWDDE65I7JAAR5CV7XYMLS6VICPGMK3I6EZG4O7ENXB \ / AMOS7 \ YOURUM ::
#\[7]LHM5LRMVLXN2QR357TCMPTL4O2IIBCDONFYHNEJI2LULRWYQGCBA 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
