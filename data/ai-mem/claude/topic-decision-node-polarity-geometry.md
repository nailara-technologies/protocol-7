---
name: decision-node-polarity-geometry
description: seed — generic decision node with escalation/repelling polarities, stacked multi-layer, geometrically the 5-of-7 principle; not yet formalized
metadata:
  type: project
  originSessionId: b06671d8-4694-4f41-bf24-4268123a0ca0
---

## origin

Surfaced 2026-07-11 from a concrete trigger: a jobsite assessment got
gendered wrong ("eine starke Kandidatin" for a male candidate) — a single
noisy inference call. User's generalization: instead of one inference,
adaptively fan out to N inferences (N scaling with a confidence/score
signal), from slightly-varied prompt perspectives, then a merge pass that
cleans outliers into one inclusive answer. Wanted for jobsite assessment
quality first, but explicitly framed as generically useful (e.g. high-
quality summaries too).

Existing infra to build on rather than start fresh: `llm.service.
consensus_vote` / `models.conversation.consensus_vote` (harmonic-
certainty encoding already implemented), `coding.self_test`'s
`result_constraint` structural-check concept for validating one answer.

## the generalization (not yet formalized)

User's own words: this "ultimately leads to a generic decision node
object that [has] escalation and repelling polarities. and those [get]
used multi-layered." Geometrically identified as **the 5-of-7 principle**
— explicitly the same structure as [[topic-reference-bubble]]'s "5 ground
zenki [process/vote/dedup]" formation (setup `01` → 5 ground zenki → `10`
collector), which that memory already ties to `llm.service.
consensus_vote` as its concrete instance. So: this session's "decision
node with escalation/repelling polarities" is very likely the same
primitive as the reference bubble's 5-ground-zenki vote/dedup layer,
looked at from the consensus-quality angle instead of the routing/
transport angle — not confirmed identical, but the user drew the
connection explicitly and unprompted.

Also invoked as a second geometric analogy: "the 27 subcube implosion
device geometry as the inverse 3D plus in cubic space" — a 3×3×3 = 27
subcube structure, described as an *inverse* of the existing 3D-plus
cubic-space geometry. This is distinct from [[topic-node-group-geometry]]
(8 × 63 = 504 subcubes, 4×4×4 void, 2×2×2 cube arrangement) — a different
count (27 vs 504) and a different cube size (3×3×3 vs 4×4×4 minus corner).
Not yet reconciled with that geometry; may be a smaller-scale/nested
variant, may be unrelated. User was explicit: **not yet able to bring
this fully into mental focus clear enough to formalize the node
elements** — this is a genuine open thread, not a design ready to build.

## status

Pure seed capture, no formalization attempted here per user's own
statement that the node elements aren't yet clear. Do not attempt to
prematurely formalize this into a concrete data structure next session —
surface the connection to [[topic-reference-bubble]] and
[[topic-dedup-tree-unifying-mechanism]] and let the user drive whether/
how to continue converging it.

## related

[[topic-reference-bubble]] · [[topic-dedup-tree-unifying-mechanism]] · [[project-layer-matrix-convergence]] · [[topic-node-group-geometry]] · [[topic-harmonic-mathematics]]

#,,,,,.,,,,..,,.,,.,.,,..,,,.,,.,,.,.,,,,,,..,..,,...,...,...,,,.,,.,,...,,,.,
#EBSIDQMFJ7EGNV45PFH45QQHW55FZESRI5H2ZCSFUJVVPZ3KS2T34EDI4TJEZCWJNORDJ27WS63PE
#\\\|CACBKTQ4FUESNA7GLWQOIVS4JDKPY752W7FSKRGRLAYVG5NMPUO \ / AMOS7 \ YOURUM ::
#\[7]BLT7473YFRKNTUHIEBRQBFINZD664RPPOS4WT5DJP37ADJRSAOCI 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
