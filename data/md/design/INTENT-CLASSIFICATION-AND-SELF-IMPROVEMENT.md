## [:< ##

# intent classification and self-improvement

## the closed-world property

the reason this system can be simple, safe, and self-improving without
external infrastructure is that the knowledge domain is fully closed and
enumerable:

- every valid command exists in the running zenka or it cannot be called
- every documentation path is a known file or it is not present
- every zenka is in the registry or it does not exist
- every local context adjustment had to be loaded to be active — if it
  works, it is readable

nothing can be locally relevant without already being locally present.
the intent classifier cannot hallucinate a destination that does not exist
because non-existing destinations have no representation in the tree.

this closed-world property is inherited automatically by the regex context
tree: the tree is always a faithful projection of current implementation
state, because it is derived from it.


## trigger: the `help` signal

`help` is not implemented as a command. any attempt to call it is a
behavioral signal — statistically, users who type `help` are unfamiliar
with the system. the signal is passive: no command is defined, so no
command fires. instead the session is flagged as `new-user-pattern` and
routed to the intent classification pipeline.

other signals that set the same flag:
- `?`, `man`, `info`, `commands`, unknown-command with no close match
- a sequence of failed commands within the first N interactions
- explicit: a connected zenka broadcasting `new-user` for a session it
  manages

the flag is session-scoped, stored in the branch.session DAG, and
readable by any zenka the user routes to during that session.


## tier 1 — regex context tree

always-on, zero-latency, zero-cost. the tree is a YAML-defined structure
of pattern → intent mappings, compiled to a set of pre-built regexes at
zenka startup.

```yaml
## data/yaml/intent-tree/cube.yaml  (one file per zenka namespace)

nodes:
  - pattern: "list|show|what.*running|who.*connected"
    intent:  orientation.list-sessions
    doc:     "use: list sessions / list users"
    next:    []

  - pattern: "weather|temp|forecast"
    intent:  route.weather
    doc:     "weather zenka: weather.desc / weather.location"
    next:    []

  - pattern: "start|launch|run|spawn"
    intent:  action.start
    doc:     "v7.start <zenka-name>"
    next:
      - pattern: "what.*available|which.*zenki|options"
        intent:  orientation.list-available
        doc:     "use: list zenki"
```

the tree is positionally aware: each zenka namespace has its own tree
file. the active tree is the one for the zenka the user is currently
connected to, composed with a shared generic orientation layer.

tree evaluation:
1. match input against current node's pattern set
2. if match: return doc + intent, descend to next level for follow-up
3. if no match: return to parent, widen search
4. if no match at root: escalate to tier 2

the tree format doubles as executable documentation — it is both the
classifier and the authoritative description of what the system responds
to. updating documentation and updating the classifier are the same act.


## tier 2 — llm clarification agent

activates when tier 1 hits genuine ambiguity or an unrecognized pattern.
the agent is an on-demand zenka, spawned only when deeper thinking is
available (coding zenka or equivalent LLM backend reachable).

preload context:
- the tier 1 partial match (what the tree recognized before escalating)
- the generic orientation template (what p7 is, how it is structured)
- the current zenka's contextualized documentation template
- the new-user flag and any prior interactions in this session

the agent can:
- ask the user 2–3 targeted clarifying questions
- resolve intent from the answers
- spawn a further interactive agent or control surface for the resolved
  intent
- hand the user off directly into the right zenka and starting command

the LLM agent does not replace tier 1 — it reports back what it resolved
and whether the tier 1 match was wrong, missing, or ambiguous. this
report is the raw material for the self-improvement cycle.


## tier 2 → tier 1 feedback: the improvement cycle

every new-user session where tier 2 was activated produces a feedback
record:

```yaml
session:    <ntime_b32>
zenka:      cube
input:      "how do i see what's running"
t1_match:   null                        ## tier 1 found no match
t2_intent:  orientation.list-sessions
t2_doc:     "use: list sessions"
outcome:    success                     ## user reached their goal
proposed_pattern: "see.*running|what.*running|what is.*up"
```

these records accumulate in the session log. no analysis happens
immediately — the interaction is just captured and stored.


## deferred background analysis

analysis is deferred to idle time, which may be days or weeks after the
interaction. this is a feature: a pattern seen once is noise; the same
gap appearing across multiple sessions or nodes is signal.

the analysis zenka (on-demand, idle-triggered):

1. reads the accumulated feedback records above a threshold count
2. groups by: zenka + gap type (no match / wrong match / ambiguous)
3. for each group, asks an LLM: "what regex pattern would have caught
   these inputs? does it conflict with any existing branch?"
4. produces a candidate tree patch in the existing YAML format
5. validates the patch against the historical session corpus —
   every past misfired session is a regression test the patch must pass
6. submits the patch to consensus vote (existing 5/7 pattern)
7. on consensus: merges patch into the live tree YAML and reloads

the time deference means statistical weight accumulates naturally before
any patch is proposed. rare interaction types take longer to refine —
which is exactly right, since they have less evidence.


## network sharing and distributed refinement

validated patches are broadcast to connected nodes as standard data
updates. receiving nodes:

- check each pattern entry against their own command registry
- entries referencing commands or paths not present locally: silently
  skipped — the closed-world property makes this safe by construction
- entries that apply locally: merged into the local tree with the same
  consensus gate before going live

the effect: a node that has never seen a particular user intent pattern
receives a refined branch for it before encountering one, because a peer
node already did. intelligence diffuses ahead of need.

the sharing protocol carries natural latency (processing + broadcast +
local consensus). this is not a weakness — it is the statistical filter
that ensures only well-evidenced patterns propagate. a pattern observed
on one node once does not propagate. the same pattern appearing across
multiple nodes over time does.


## `overview` command

the surface entry point for oriented users and new users alike.
positionally aware: returns where you are right now.

output includes:
- which zenka you are connected to
- its live state (commands available, active sessions, key config)
- reachable neighboring zenki from this position
- one-line description of each reachable command

`overview` is genuinely useful to experienced users (orientation after
cold reconnect) and to the intent pipeline (gives a new-user enough
context to ask a better second question).

`describe <cmd>` is the depth layer — `overview` shows the map,
`describe` explains one location on it.

`help` → silently routes to `overview` + sets new-user flag.


## `describe` command (planned)

per-command depth. args: command name or partial match.
returns: purpose, params, example invocation, related commands.
source: the same YAML intent tree and module headers — no separate
documentation format needed.


## self-improvement as emergent property

no dedicated training infrastructure is required. the system improves
through:

- normal usage generating flagged sessions
- idle processing time that every connected node already has
- the existing consensus vote mechanism as quality gate
- the existing network data sharing as distribution

the corpus of past flagged interactions becomes a permanent regression
suite. the system accumulates evidence of its own past confusion and
cannot un-learn it. each improvement cycle makes the next cycle's
baseline higher.

the closed knowledge domain ensures the improvement has no escape hatch
into hallucination: every proposed pattern is validated against an
enumerable target set before it can affect any user interaction.


## implementation layers (five-cluster)

```
1  task       data/tasks/intent-classification-*.md
2  template   data/yaml/reasoning-templates/intent-tree-analysis.yaml
3  design     this document
4  intent     (to be written: the why/direction layer)
5  address    (derived: branch.cluster.address of this cluster)
 + gate       the +1 closing node
```

## files referenced

```
data/yaml/intent-tree/                    ## per-zenka tree yamls (to create)
data/yaml/intent-tree/_generic.yaml       ## shared orientation layer
data/yaml/reasoning-templates/intent-tree-analysis.yaml
data/yaml/cluster-registry/intent-classification.yaml
modules/intent.*                          ## classifier zenka modules (to create)
```

#,,,.,.,,,..,,,.,,..,,,.,,.,,,,,.,.,,,...,.,,,..,,...,..,,..,,.,.,..,,,..,,,,,
#4PCB3NWYB3AUFDVOB5VY6II2XHXCQBXKL2UUFDTRW3TXLDYMTGSRLQMUUBWOXE4WUAA6KWRJHGWQY
#\\\|WKAA6VVL6XLGWE3SQHQ4CIT2XDU7Q5AILASHX4APJHXOL5N2COE \ / AMOS7 \ YOURUM ::
#\[7]M4VPS5D35K3JBK6FKPLMWA2KYU6RCCEHFSRLFAN2FAO6MPGSVIDA 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
