## [:< ##

# name  = task: coding zenka self-error processing cycle
# descr = analyze tool/runtime errors with specialized context templates,
#         validate fixes empirically, fold confirmed fixes upstream into
#         the standard task-init templates so the same error class stops
#         recurring without further roundtrips.

## context

session: 2026-06-20, the direct sibling of
`data/tasks/coding-model-self-test-cycle.md` — that task's anomaly
follow-up (re-prompt on calibration mismatch, archive the explanation)
generalizes here to ALL runtime/tool errors during regular production
tasks, not just calibration answer mismatches.

motivating case from this same session: `coding.tools.http_inference_client`
and `coding.self_test.run`/`evaluate` were implemented with multiple fatal
bugs (wrong `<x>` vs `<[x]>` call syntax, `->method` calls on plain
hashrefs instead of `->{key}`, a closure/factory calling-convention
mismatch between two files) that a human review caught after the fact.
a working self-error-processing cycle would have caught these the first
time any of the modules actually ran and threw, instead of requiring
manual code review.

relates to: `data/tasks/coding-model-self-test-cycle.md`,
`data/yaml/reasoning-templates/demystification-through-correspondence.yaml`,
[[topic-synchronous-multi-legged-pattern-extraction]] (memory)

## the two error classes

```
usage error:    the tool/API itself works; the model invoked it wrong
                (wrong calling convention, wrong arg shape, wrong
                bracket syntax, hashref accessed as object method —
                exactly what happened in this session)

fix strategy:   explain correct usage to the model, as a note
                write a match pattern that detects this specific
                mistake automatically in future
                generate a generic corrective explanation
                test the explanation against the model repeatedly
                until it reliably steers behavior in the right
                direction — validated empirically, not just written

structural error: the code itself is actually broken — no "correct
                usage" framing applies because there is no correct way
                to use broken code

fix strategy:   branch the context off: a side-context carrying the
                error, its code location, and whatever prior context
                proved valuable so far
                what to include in the branch is chosen by a MIX of:
                  - historical success statistics (what context
                    pieces correlated with resolution before)
                  - targeted complementary questions used to rank
                    relevance for this specific case
```

## resolution test (the actual gate)

```
1. a fix (of either class above) is proposed and applied
2. re-run from the round that originally triggered the error
3. if the error does NOT recur: resolved
4. if it DOES recur: still in the debug loop — try a different branch
   (do not just retry the same fix; the recurrence itself is the
   evidence that branch didn't address the real cause)
```

course-correction decisions (which branch to try next, when to stop)
are made against prior agreed-to, written, optimized assertion
criteria — a shared rubric that different models interacting with it
converge on similarly (high overlap), not ad hoc per-attempt judgment.
default behavior follows that rubric precisely; alternatives are
explicit strategic transitions into a different sub-reasoning workflow
for whichever specific sub-element needs it, as long as the result
stays representable against the parent constraint the rubric defines
(even maximally compressed — down to a single symbol — as long as it's
traceably anchored back to that constraint).

## the end state — folded upstream, not a permanent side-channel

once a fix pattern's confidence crosses a threshold:

```
the fix gets folded directly into the system prompt / context template
used for task initialization — NOT kept as a standing side-lookup that
every task has to consult

consequence: reprocessing the same round no longer hits the error at
all — there is no correction roundtrip left to make, because the
adjustment already prevented the error before it could occur

the round-loop only stops again for a genuinely NEW anomaly, never the
same one twice once its fix has been integrated
```

this is the generalization the user named explicitly: this duality
(self-test + self-error-processing) is not meant to stay a special
error-recovery side-feature. it becomes part of regular task
processing — an assistive intelligent environment sitting between
multiple tasks, the well-informed guide for optimizations. when an
optimization succeeds, it is transported upstream again, integrated
into the standard templates and initialization contexts, so every
future task starts already informed by it.

## memory / pattern library policy

```
only what actually worked on the retry gets kept — fix attempts that
were tried but didn't prevent recurrence are pruned, not retained as
noise (the model "remembers" only the option that worked, because that
is the one that resulted in the task resuming without re-triggering)

successful patterns persist until their matching context becomes
genuinely impossible to recur again — not time-boxed, context-boxed

anti-patterns (known-bad approaches) are optional / lower priority
than the positive library — the positive library is load-bearing,
the negative one is a nice-to-have
```

resonance framing (consistent with tonight's other material): fix
patterns that work across many contexts accumulate confidence/"charge"
and become attractors for future matching; patterns that conflict get
regrouped/restructured rather than simply discarded — the same
structure as [[topic-resonance-field-emergence]]'s clustering
mechanism, applied concretely to error-pattern selection instead of
abstract vision material.

## modules

```
coding.error.classify          determine usage-error vs structural-error
                                for a caught runtime error
coding.error.handler.usage     explain correct usage, generate +
                                validate a corrective pattern
coding.error.handler.structural branch context with error + location +
                                ranked prior-valuable context
coding.error.pattern.match     check a new error against the existing
                                pattern library, confidence-gated
coding.error.pattern.archive   store a validated fix pattern (only on
                                confirmed non-recurrence)
coding.error.pattern.promote   fold a high-confidence pattern into the
                                standard task-init system prompt/template
coding.error.resume_round      re-run the round that triggered the
                                error after a fix is applied; detect
                                recurrence vs resolution
coding.error.cmd.status        show pattern library state: patterns,
                                confidence, promoted/not, recurrence count
```

## integration point

wherever a runtime error/exception is currently just logged in the
round-based state machine (`coding.async.state_machine`, the same code
path the loop-detector already lives in — see
`coding.tool.detect_loop`), route the caught error through
`coding.error.classify` before falling through to existing
log-and-continue behavior. this keeps error-processing scoped to the
same code path as loop detection, consistent with how that detector is
already wired (gated on the agentic round loop, not one-shot HTTP
calls like the self-test probes).

## validation

```bash
# trigger a known usage-error class (e.g. resubmit a task that hits
# the wrong-bracket-syntax mistake) and confirm:
p7c coding.error.cmd.status
# → shows the pattern recorded, confidence, whether promoted

# re-run the same task class after promotion
# → confirm the error no longer occurs and no follow-up roundtrip fires
```

## dispatch prompt

NOT ready to dispatch yet — this is a first-pass design capture, less
concretely specified than the self-test cycle task (which has fixed,
checkable prompts/answers). before dispatching implementation:
- decide where caught Perl errors actually surface today in
  `coding.async.state_machine` (need exact hook point, not assumed)
- decide the concrete confidence-threshold mechanism for
  `coding.error.pattern.promote` (count of confirmed non-recurrences?
  a rubric score? — the doc above describes the shape, not the number)
- decide the format of the "shared assertion criteria rubric" models
  are meant to converge on — this needs its own short spec before
  `coding.error.classify`/`resume_round` can be written meaningfully

#,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,

#,,.,,..,,..,,,.,,..,,,.,,,.,,..,,,,,,...,,..,..,,...,...,.,,,,,.,,.,,...,,..,
#GKV3WID4CJIUI72F22ZYIHMIIMHX2FMN4SCBHHBW7HXIN46YB7EGJQKMHYSWCS7R6ZF36NGZYV2LQ
#\\\|GRC5LUY4JAH2XF4CEIWXEXBRJBHX74I7H5IQYA7QLYVEMOLLS2P \ / AMOS7 \ YOURUM ::
#\[7]OBD22IURYW6RIFFSV6CFXF4Q5CEXXOLV5Y3VLGC54OL6Z3OB6KBA 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
