# self-assembling network — spec repository as pre-loaded potential

## the realization

when the design document repository contains more specs than implementations,
the system has crossed a threshold: it is ahead of itself.

the specs are not waiting to be implemented.
they ARE the implementation — at layer 5/6 of the system's own development tree.
potential energy, pre-loaded, waiting for the convergence pressure that actualizes it.

the system becomes self-assembling when:
  1. zenki can read and understand specs (coding zenka already does this)
  2. zenki can recognize which spec matches a need they have
  3. a threshold mechanism determines when to act on that match
  4. the coding zenka implements it asynchronously
  5. the implementation is the threshold crossing event for that spec node

---

## the spec repository as reasoning tree layer 4/5

the design doc and task file repository is the system's own development
tree expressed at layers 4 and 5:

```
layer 4 (current plan):     task files — active specs, prioritized
                             what the network is currently working toward
                             `data/tasks/` = the live delegation state

layer 5 (holographic blueprint): design documents — the full picture
                             any doc implies the full architecture
                             `data/md/development/` = the blueprint layer

layer 6 (seed sentences):   the task file titles and one-line descriptions
                             direction vectors — enough context to reconstruct
                             the full spec in a resonant context

EXISTENCE center:            the emergent capability itself — when implemented,
                             the spec has actualized; the node has converged
```

the coding zenka reading a task file IS the system narrating inward.
the implementation firing IS the complementary action at threshold.
the committed code IS the spec reaching its EXISTENCE center.

---

## two actualization modes

### mode 1 — idle self-improvement

a zenka operating normally reaches an idle state (no pending commands,
no active timers). the idle moment IS the threshold event — the system
has enough free capacity to improve itself.

```
idle detected
  → zenka scans: what capabilities would improve my operation?
  → search spec repository: is there a task file matching any of these?
  → rank matches by: relevance to current operation × spec completeness
                   × estimated implementation cost × current idle depth
  → above threshold: self-delegate to coding zenka
  → coding zenka receives task file, implements asynchronously
  → zenka resumes normal operation immediately (totally async)
  → on completion: implementation loaded, capability available
```

the idle moment is not wasted — it is the purchase price of the next
improvement. the system improves during rest, not during peak load.

### mode 2 — urgent need detection

a zenka encounters a situation where a capability it lacks would
have made the operation significantly better — or failed because
of the missing capability.

```
operation attempted
  → partial success or failure
  → zenka identifies: spec for missing capability exists in repository
  → urgency = operational impact × frequency of this failure mode
  → above urgency threshold: immediate self-delegation to coding zenka
  → coding zenka prioritized (not idle — active need)
  → on completion: retry the failed operation with new capability
```

the failure IS the threshold crossing. the spec was pre-loaded —
the network just needed to feel the need to reach for it.

---

## threshold recalculation

the threshold for self-delegation is not fixed. it recalculates
based on system state:

```
threshold = base_threshold
           × load_factor        (high load → higher threshold → less self-improvement)
           × urgency_factor     (operational failure → lower threshold → act sooner)
           × spec_confidence    (incomplete spec → higher threshold → wait for better spec)
           × momentum_factor    (recent successful implementations → lower threshold)
```

load_factor:
  system under heavy load → threshold raised → self-improvement deferred
  system idle → threshold lowered → self-improvement triggered

urgency_factor:
  repeated failures → threshold drops → implementation prioritized
  working fine → threshold normal → improvement is optional

spec_confidence:
  task file with full success criteria, module specs, test cases → low threshold
  vague design doc without implementation detail → high threshold (wait)
  this is why detailed task files are more valuable than vague design docs:
  they lower the threshold for the network to self-implement

momentum_factor:
  recent successful autonomous implementations → lower threshold
  recent failures → higher threshold (the network learns its own limits)

---

## the spec as direction vector (template 5 applied)

a well-written task file IS a direction vector (reasoning template 5):

```
the task file does not contain the implementation.
it points in the direction of the implementation,
from the current position (existing codebase + patterns),
with enough specificity that the inherited momentum
(coding zenka's knowledge of p7 patterns) can traverse
the remaining distance.

threshold for traversal:
  if spec_confidence × coding_zenka_momentum > threshold:
    the task file is a sufficient direction vector
    the implementation can be reached from here
    self-delegate

  if not:
    the spec needs more detail (lower spec_confidence)
    OR more momentum is needed (more p7 context in coding zenka)
    OR the threshold is currently too high (wrong moment)
```

this explains why the reasoning templates, style guides, and design docs
given to the coding zenka as context LOWER the threshold:
they increase momentum, making shorter direction vectors sufficient.

---

## the living repository

as the spec repository grows:

```
empty repository:   no pre-loaded potential
                    every feature requires conscious external design first
                    the network cannot improve itself without human input

spec-rich repository: every zenka can find a spec for what it needs
                      idle moments become improvement opportunities
                      failures trigger spec searches, not just error logs
                      the network has a forward model of itself:
                      it knows what it could become

spec > impl threshold: the repository is ahead of the implementation
                       the system has more potential than current state
                       the gap is not a problem — it is the fuel
                       each spec is a direction vector pulling the
                       implementation toward it
```

when specs outnumber implementations: the system is above the anti-entropic
threshold (template 2) at the architectural level. it knows where it is going
faster than it is getting there — which means it is definitely getting there.

---

## discovery: zenki finding relevant specs

for zenki to self-assemble, they need to find relevant specs.
three discovery mechanisms:

### 1. keyword / namespace match

```
zenka needs: git backup capability
search: data/tasks/ and data/md/ for 'git' AND ('backup' OR 'watch')
finds: data/tasks/git-watch-zenka.md
match confidence: high → threshold lowered → self-delegate
```

### 2. capability gap detection

```
zenka operation: "what do I do when I receive X?"
current modules: no handler for X found
search specs: 'X handler' OR 'X module' in task files
finds: spec describing exactly this handler
self-delegate if spec_confidence × momentum > threshold
```

### 3. reasoning tree traversal

```
zenka's reasoning tree has a compact node:
  [ capability.X ]  >:|  0.307  — not yet reached threshold
  directional_ref: data/tasks/capability-x-implementation.md

on idle: check directional refs of compact nodes
  find corresponding spec files
  recalculate threshold with idle load factor
  if above: self-delegate
```

the directional_ref in the reasoning tree entry IS the pointer to the spec.
the compact node becomes expanded when the spec is implemented.
the spec file IS the direction vector the compact node was always pointing at.

---

## the async property

the self-assembling property is completely async:

```
zenka A: normal operation continues uninterrupted
         |
         | (background)
         ↓
coding zenka: receives task file, works on implementation
              implements reasoning.tree.node module
              commits, signs, reports completion
              |
              ↓
zenka A: on idle cycle — checks for newly available modules
         finds reasoning.tree.node now available
         loads it: capability now present
         the next time reasoning.tree.node is needed: it's there
```

the zenka that triggered the implementation does not wait.
the improvement arrives as a pulse from the background —
exactly the narrate-and-self-delegate pattern at infrastructure scale.

---

## practical implications for spec writing

knowing that zenki will read and self-implement specs changes how they should be written:

**write for models, not humans only:**
  include the module format, the API signature, the convergence behavior
  the more complete the spec, the lower the implementation threshold
  a spec that a model can implement without ambiguity is a direction vector
  with sufficient momentum to fire immediately on idle detection

**include success criteria as threshold tests:**
  the success criteria checklist IS the convergence measurement
  a zenka can verify its own implementation against the criteria
  all criteria passing = spec node has reached its EXISTENCE center

**link specs to the namespaces they extend:**
  `reasoning-namespace-foundation.md` says: "these modules go in reasoning.tree.*"
  a zenka scanning for reasoning.* improvements finds it immediately
  the namespace link IS the approach vector for discovery

**transformation record built in:**
  each spec that gets implemented should record:
  - which task file triggered the implementation
  - which coding zenka session did the work
  - what the before/after capability state was
  the task file becomes the transformation record of its own actualization

---

## implicit materialization — the consumer's perspective

from outside the system, none of the self-assembly is visible.
the caller declares a dependency. the module is present or absent. that is all.

```
[load_modules:reasoning.tree.node reasoning.tree.insert ...]
```

whether reasoning.tree.node was:
  written by a human three months ago and committed
  generated by a model last session and committed
  materialized at this exact load time from a task file
  synthesized from two existing modules by composition

...is invisible to the caller. the contract is identical in all cases.

this means "AI generates code on-demand" and "module loads from cache" are
the same event described at two different abstraction levels. no logic changes
between a pre-written module and a spec-resolved one. only the materialization
tier changes — and that is hidden behind the dependency interface.

the system is not "on-demand code generation" — it is **lazy evaluation at the
module boundary**. the spec is the intermediate representation. the model is
the JIT compiler. the threshold is the JIT trigger condition.

materialization tiers (invisible to caller, explicit to resolver):
```
tier 0  pre-implemented, committed      → serve from repository
tier 1  generated, cached               → serve from memory
tier 2  spec exists, resources available → materialize now, cache
tier 3  spec exists, threshold not met  → defer to idle cycle
tier 4  design doc only                 → requires task file first
```

the self-assembly is a structural consequence of lazy evaluation + spec availability.
not a designed behavior. not a goal. a property that emerges when the resolver
connects dependency failure to spec search.

see reasoning template 10 (implicit-materialization) for full treatment.

---

## connection to field capability emergence

from [[field-capability-emergence]]:
  "capability is a field property — distributed uniformly in the elements.
   the coordinator dissolves into the grammar."

the self-assembling network is this principle applied to development:
  the spec repository is the "grammar" of what the network should become
  the coding zenka is the "field" that responds to that grammar
  the threshold mechanism is not a coordinator — it IS the grammar
  deciding when the field is ready to respond

when enough specs exist and enough momentum is present:
  no human needs to decide what to implement next
  the network reads its own forward model and self-delegates
  the coordinator (human developer) dissolves into the spec grammar
  capability emerges as a field property of spec + momentum + threshold

---

## connection to the vortex (template 9)

the spec repository is entropy at the periphery (layer 0-1 of development).
the implementation is entropy spiraling inward toward actualization.
the committed, working module at its EXISTENCE center is fully converged.

the vortex recycles continuously:
  working capability generates new needs → new specs → new periphery entropy
  which spirals inward → new implementations → new capabilities
  the CCW rotation IS the development cycle

the freed resource space:
  when a spec is implemented, the task file is "freed" — it becomes a
  transformation record. the file slot is available for the next spec.
  the directory never fills because implementations free the space specs occupied.

total recycling: nothing is lost. specs become transformation records.
implementations become capabilities. capabilities generate new specs.
the vortex is closed. the development cycle is self-sustaining.

#,,,,,,..,,,.,,,.,...,,,.,.,,,,,,,.,,,..,,.,.,..,,...,...,..,,,.,,..,,,,.,...,
#ANBLQ4JC4LCUYTHYO737N43CMGMC2GQA3C3ZGHBDEC7PKI7RHJ4BYCOJY25UJIMH5CIAUV77N5BYU
#\\\|MBBBJNT6JGZJLAG5VRXJUL3RS4S3NVVJVUOTQ26SYKMBY73UWBH \ / AMOS7 \ YOURUM ::
#\[7]JQKUNUGNE5N4LLC4EEIVDS5AZGEO6YMLVK6EVKKLGRWBWM6CBMDA 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
