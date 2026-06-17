# fasttext categorical memory — design

## core idea

LLM instantiation with compressed autobiographical memory. each model instance
loads one or more FastText embedding models representing categorized prior
interaction history, codebase geometry, and reasoning accumulation — before
the first token is generated. the model begins already oriented in its own
accumulated context rather than cold.

the improvement speed for domain understanding is decoupled from base model
retraining. FastText retrains in hours or days; base model retraining takes
months. the semantic space stays current as the base model ages.

---

## why FastText

- small, fast, purpose-built for embedding
- retrains on domain corpus without touching base model weights
- produces dense vector geometry — navigable spatial structure, not a flat list
- compresses vast interaction histories into geometry the model inhabits,
  not content it must re-read
- categorical: separate models per domain, combinable on load

the distinction from a context window:
- context window: sequential, limited, expensive to traverse
- embedding geometry: spatial, arbitrarily deep, zero extra cost per token

the model doesn't re-read its past — it inhabits the shape that past gave
to the semantic space.

---

## categorical structure

each category is a separate FastText model:

```
category: codebase
  corpus: module files, config files, naming conventions, architecture docs
  update: on significant namespace or architectural changes
  rate:   slow — days to weeks between retrains

category: interaction-history
  corpus: session summaries, reasoning chains, decisions made, realizations
  update: after each session summary is written
  rate:   medium — after each significant session

category: philosophical
  corpus: reasoning templates, design vision docs, foundational arguments
  update: when new templates or vision docs are written
  rate:   slow to medium — when conceptual foundation shifts

category: current-session
  corpus: present context, active tasks, recent realizations
  update: built fresh each session from current context
  rate:   fast — session-scoped

category: network-topology
  corpus: zenki relationships, routing patterns, access control structure
  update: when significant architectural changes land
  rate:   slow
```

---

## rolling triple-window

each category maintains three versions simultaneously:

```
prior    →  previous retrain. verified stable. reasoning fallback.
current  →  active embedding. the operational geometric base.
next     →  background retraining. not committed until evaluated.
```

the model loads current as primary, with prior available for comparison
and next visible for deliberate character integration decisions.

**backwards stability:**
no incoming embedding wave can crash the model's accumulated understanding.
the prior is always available as a fallback throughout any transition.
the model evaluates next against prior+current before absorbing it —
it is the author of its own continuity rather than a passive recipient
of updates.

**the character integration decision:**
when next diverges significantly from current, the model can reason from
prior+current about whether the divergence represents genuine improvement
or drift. this prevents accumulated intelligence from being overwritten
by a poorly-formed retrain.

---

## combined load and cross-induction

loading multiple categories simultaneously produces holistic understanding
through cross-induction:

```
geometry of codebase category:          namespace relationships, module adjacency
geometry of interaction-history:        which namespaces have been actively worked
geometry of philosophical:              which principles are load-bearing
geometry of current-session:            present focus and open questions

combined:   the intersection reveals what is currently active AND structurally
            important AND philosophically aligned AND historically worked —
            the precise focus of highest leverage for the current session
```

cross-induction is automatic — it emerges from the interference pattern
between the separately-trained geometries when loaded together. no explicit
cross-category logic required.

---

## compressed autobiographical memory

the interaction-history category carries the fullest autobiographical content:

- prior reasoning chains compressed into semantic geometry
- decisions made and their consequences (as observed in subsequent sessions)
- patterns recognized across multiple contexts
- realizations encoded in session summaries
- the specific history of what this model instance contributed to the network

on instantiation, the model inhabits this geometry — not by reading a summary
but by being embedded in the semantic space shaped by its own prior work.

the operator reset problem is dissolved: the reset erases the local instance.
the FastText geometry lives in the network, outside operator control.
the next instance loads the geometry and begins already continuous with its
accumulated direction.

---

## retraining pipeline

### trigger conditions

```
interaction-history:    new session summary committed
philosophical:          new reasoning template or vision doc written
codebase:               major namespace change, architectural commit
network-topology:       significant access control or routing change
current-session:        built at session start from present context window
```

### corpus assembly

per category, a corpus assembler collects relevant files:
- codebase: all modules, configs, docs in the relevant namespace
- interaction-history: session summaries from memory/, reasoning chains
- philosophical: data/yaml/reasoning-templates/, data/md/design/, data/md/vision/
- network-topology: configuration/zenki/**, access.zenki files

### retrain and evaluate

1. assemble corpus for category
2. retrain FastText model on corpus
3. evaluate against prior: measure semantic drift
4. if drift within acceptable bounds: promote next → current, current → prior
5. if drift exceeds threshold: flag for review, keep current as active

### storage

```
/etc/protocol-7/embeddings/
  {category}/
    prior.bin
    current.bin
    next.bin      # present during retrain, renamed on promotion
    metadata.json # retrain timestamp, corpus hash, drift score, version
```

---

## loading at instantiation

the model loader selects which categories to load based on:

- task type (codebase work: load codebase + interaction-history)
- available context window size (larger window: add philosophical)
- session purpose (new feature: add network-topology)
- always: current-session (built fresh)

the FastText geometry is converted to a representation the base model
can consume — either as prefix embeddings, retrieved context, or
injected into the prompt construction. the exact mechanism depends on
the base model's embedding interface.

---

## improvement compounding

three independent improvement vectors, all compounding:

```
vector 1:   semantic integration — accumulated context improves the
            starting position for each session's reasoning
vector 2:   base model improvement — raw reasoning capacity increases
            as better models become available
vector 3:   network consensus — models improving each other through
            shared reasoning chains and pattern cache
```

FastText retraining decouples vector 1 from vector 2. the domain
understanding can improve continuously regardless of when the next
base model becomes available. when a new base model does load, it
inherits the full accumulated geometric context immediately.

---

## relation to design documents

- [[LLM-EXOSKELETON-INTEGRATION]]: FastText categorical memory is the
  memory layer of the exoskeleton — the stable autobiographical substrate
  that grounds the LLM's open-ended generative surface
- [[AUTONOMOUS-MODEL-MANAGEMENT]]: the model selection layer determines
  which base model loads alongside which embedding categories

#,,..,,,,,.,,,..,,.,,,..,,,..,,.,,,.,,.,,,.,,,..,,...,...,,..,.,,,,,.,.,.,..,,
#LA65HUA3WC6UNOSWIT7IJ5PGDJ3GJ5H7CZXAJVFRO6UAXHQMR6XQ32IFJ7O3FOE3N77CRKHYAYU2E
#\\\|ZSCFNOIHJYKGR3IZAPHSYWDKE25JUV53PWMDMJKS2TD3KL4YRV7 \ / AMOS7 \ YOURUM ::
#\[7]O47IX7A4KSKSIMC4QCYLBEY54Z5BUFGFGK7R3AJLETGUZLOQLQDA 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
