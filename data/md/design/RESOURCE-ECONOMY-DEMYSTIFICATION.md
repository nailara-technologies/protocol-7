## [:< ##

# resource economy — objections resolved

produced 2026-07-30 as an adversarial pass over `NRT.NRD.asc`,
`NETWORK-RESOURCE-TOKEN-ARCHITECTURE.md`, and `TASK-CUBE-CONSENSUS-ARCHITECTURE.md`,
following `data/yaml/reasoning-templates/demystification-through-correspondence.yaml`:
for each objection, find the exact standard-mechanism correspondence rather
than accepting or dismissing the vivid framing uncritically. every objection
below either (a) maps onto an already-solved, named, standard mechanism
already present elsewhere in the repo, (b) is an explicit design boundary,
not a flaw, or (c) is a genuinely open gap with a concrete pointer to close it.

this document is written to be the thing a skeptical reader would have
wanted to find on the first pass — a reusable base for the topic, not a
one-off session log.

---

## objection 1: cross-resource pricing needs a hard general-equilibrium solve

**the worry**: valuing N resource types against each other in real time
sounds like it requires solving a joint market-clearing problem across all
N simultaneously — the classic hard case (Arrow-Debreu-style equilibrium
computation, no cheap general algorithm).

**resolution — wrong problem, not a hard version of the right one**: the
token's own value is not a clearing price at all. `NRT.NRD.asc:10-12`
defines it as a running statistic — total resources connected ÷ total
accounts. that's a numeraire, and numeraires don't need to be
market-cleared; they need to be a stable common unit other things get
priced *against*, same as any real currency isn't itself "cleared" against
goods in general. cross-resource pricing (`NRT.NRD.asc:87-90`) then goes
through that single numeraire, turning an O(N²) pairwise-clearing problem
into O(N) individual prices against one reference unit — a standard
numeraire-currency correspondence, not a novel or fragile trick.

---

## objection 2: "pricing automatically balances itself" is an assertion, not a mechanism

**the worry**: `TASK-CUBE-CONSENSUS-ARCHITECTURE.md` layer 4 states pricing
is "automatic, because usage categories are already balanced against each
other by the pool structure itself" — that names a desired property without
saying what computes it.

**resolution — the curve tree is the mechanism, and it's a known algorithm
family**: `INITIATIVE-MAP.md:229-240` specifies that weight/influence is
"derived live from contextualized reference counts... not a stored
property, not assigned," composed through a tree via local
parent/sibling relationships rather than solved as a global fixed point
(`tachyon_wind_intelligence.md`'s `proportion_preserving` merge is the same
shape at the rendering layer). this corresponds exactly to hierarchical
proportional-share scheduling — weighted fair queuing / hierarchical token
buckets in networking QoS — a real, efficiently-computable, already
internet-scale-deployed algorithm family, specifically because it never
needs a global equilibrium solve: each node reconciles only with its local
neighbors, and the global proportion emerges from composed local ratios.

---

## objection 3: donated compute can't be verified without trusting the claimant

**the worry**: donated disk space is trivially verifiable (checksum matches
or it doesn't); an arbitrary donated compute workload's *correctness* isn't
verifiable that cheaply — a node could claim credit for work it never did.

**resolution — BFT quorum over redundant execution**:
`TASK-CUBE-CONSENSUS-ARCHITECTURE.md` layer 2 specifies exactly the standard
answer — n=7 quorum, 5-of-7 acceptance threshold (tolerates f=2
faulty/dishonest participants per the standard BFT bound n ≥ 3f+1). a bad
result is excluded from the accepted round and the submitter's own pending
work stalls as the consequence ("why sabotage achieves nothing" — layer 2).
redundant execution plus Byzantine agreement is the established
verifiable-computation approach; compute and storage end up with different
verification *paths* (quorum vs. direct hash), not different verification
*guarantees*.

---

## objection 4: privacy-preserving relay compensation is a known-hard problem (see: Tor)

**the worry**: a relay node that can't see who it's routing for or what the
content is can't be fairly compensated without either breaking privacy or
trusting an unverifiable claim — the reason Tor relay operators donate for
free rather than being paid.

**resolution — already a concrete instance, not a stated goal**:
`data/ai-mem/claude/topic-latency-algorithmic-authority-entropy-toll.md`
describes nodes ≥1 hop away that "cannot know who it's routing for or what
the content is" (the "fifth bit" sub-stream transfer case) yet "can fully
and safely perform the transport workload throughout, and earns resource
credits from the network... payment for correctly performed opaque
transport work." this is a genuinely solved instance of the exact problem
Tor's incentive model never closed.

---

## objection 5 (open by design, not a gap): external-currency bridging imports exposure

**the worry**: if AMOS resource tokens can be traded against external
blockchain currencies, the network's internal "always balances" property
doesn't extend past that boundary — outside market volatility enters at
the trade point.

**status — correctly described as a boundary, not something the design
claims to eliminate**: `NRT.NRD.asc:98-100` states external currencies "can
also be traded against AMOS RESSOURCE TOKENS which enables the free flow of
resources in and out of the... network" — an intentional bridge. internally,
everything stays denominated and self-consistent in the network's own
terms; at the exact point it trades against an external chain, it's exposed
to that chain's conditions, the same way any bridge between a closed and an
open system is. this is accurately scoped in the source document already —
nothing to resolve here beyond keeping the distinction visible: closed and
self-consistent internally, open and exposed only at the explicit edge.

---

## open item (not resolved, concrete and task-worthy): `loves_it` scoring is not yet discriminating in `lm-vision.handler.http_analyze`

unlike the objections above, this one surfaced by reading the actual
implementation, not the design docs, and it's a real gap rather than a
misunderstanding.

`modules/lm-vision.handler.http_analyze:30-53` computes a `loves_it` score
from three modes, intended to approximate the harmonic-truth framing
(mode 4 / 7 / 13) used elsewhere in the codebase (see
`modules/amos-term.plugin-decoder.elf_match`):

```
mode4  = length($elf_result) > 0          # true for ~any successful checksum call
mode7  = length($amos_result) >= 7        # true for ~any real hash (far longer than 7 chars)
mode13 = [02759] appears in first 13 chars of $amos_result
         # ~5 of ~30 alphabet symbols, 13 draws → true ~91% of the time even at random
```

all three conditions are true for nearly any input that successfully
reaches a checksum call at all, so `$loves_score` lands at or near the max
(13) almost universally, `$loves_it` (`== 13`) fires close to always, and
the 1.13x priority bonus (`priority_weight *= 1.13 if $loves_it`) applies to
nearly everything passing through this handler. as implemented, the score
reflects "did the checksum pipeline succeed," not "does the network know
this is wanted" — a different signal than the `loves-it` mechanism
described in `NETWORK-RESOURCE-TOKEN-ARCHITECTURE.md` (routed
preference/donation weight) and `IMPLEMENTATION-ROADMAP.md:450-452`
("pool per loves-it group... sized by contribution + loves-it weight").

**closing direction**: replace or augment the checksum-validity proxy with
an actual preference-weight input — the requester's declared or derived
loves-it weight for this content class / pool, sourced from the pool
structure the roadmap already specifies, rather than deriving the score
purely from properties of the file being analyzed.

---

## reference connections

- NRT numeraire definition: `read-me/documentation/dev/NRT.NRD.asc`
- neutral substrate / loves-it framing: `data/md/design/NETWORK-RESOURCE-TOKEN-ARCHITECTURE.md`
- BFT quorum + pool pricing: `data/md/design/TASK-CUBE-CONSENSUS-ARCHITECTURE.md`
- curve tree / live-derived influence: `data/md/INITIATIVE-MAP.md:222-245`
- opaque relay compensation: [[latency-algorithmic-authority-entropy-toll]]
- loves-it tree: [[namespace-tree-intelligence]]
- roadmap pool-sizing item: `data/md/development/IMPLEMENTATION-ROADMAP.md:450-452`
- method used throughout: `data/yaml/reasoning-templates/demystification-through-correspondence.yaml`
- concrete gap found in code: `modules/lm-vision.handler.http_analyze:19-58`

#,,.,,,.,,.,,,,,,,.,,,,.,,.,.,.,,,...,.,.,,..,..,,...,...,.,,,,.,,..,,..,,.,.,
#7NRKLDFTVBWHVZ3SZGOPZZCY3YVNZ7MMWGAPZFPZPENMSKAYQ3G764JG75VFN72M3YN2AIUIEBFQI
#\\\|KTMV7SKV4OZFU632KDCYBGHCWJRMBWAOE5UMKKFVENSIBDBYVNK \ / AMOS7 \ YOURUM ::
#\[7]PNCDE5HPRCBNLMGPQK4JQ2C25ON45ZVSOHEEDO6YCF6JKGT5SMBY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
