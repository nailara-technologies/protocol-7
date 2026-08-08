---
name: vision-consensus-vote-as-curve-decision
description: redesign llm.service.consensus_vote's discrete winner-selection as a composed continuous certainty curve with magnetic clustering, instead of patching its two selection bugs in place
metadata:
  type: vision
---

**Context**: while checking whether `profile.txt`'s "multi-model consensus"
claim was an exaggeration (it partly was — the live coding-zenka path,
`coding.tools.handler.consensus_query`, is single-model multi-perspective
prompting with LLM-synthesized agreement reading, not algorithmic voting),
found that the separate module that DOES do real multi-model voting,
`llm.service.consensus_vote`, has two real bugs in its "pick best answer"
logic: the selection loop always compares against `distances[0]` instead
of each candidate's own distance, and the per-model
`distance_from_consensus` lookup does `grep { $_->{model} eq $_->{model} }`
— a self-comparison, always true, so it silently returns whichever entry
comes first regardless of model. Doc `CODING-ZENKA-PHASE1-IMPLEMENTATION.md`
marks this module "✅ Complete," which doesn't match what's actually there.

**Reframe (this is the point of the note)**: these aren't just
implementation bugs to patch — they're symptoms of the code attempting a
discrete "pick the single closest-to-center answer" branch, which is
exactly the anti-pattern [[topic-implicit-perspective-navigation]] already
argues against for a different domain (camera/perspective navigation):
*"curves/thresholds ARE the decision, not a separate layer bolted on top."*
That note's **magnetic-clustering** principle applies directly here:
several closely-scoring points are not ambiguity to force a single winner
from — they form their own local layer. Applied to consensus voting: if
several models cluster tightly, that's a high-confidence cluster to act
on (not "pick the closest one and discard the fact the others agreed");
an isolated outlier answer is low-confidence and should push toward
escalation, not get discarded silently by whichever bug happens to fire.

**Reusable mechanism already built**: [[topic-base-curve-system]]'s
`base.curve.compose` (`product`/`sum` combination of independently
registered curves, generic, zenka-agnostic, already used by mpv/radio
relay for exactly "combine several signals into one continuously-driven
output") is a literal fit for producing consensus_vote's certainty value
as a composed curve over per-model agreement distances, rather than a
discrete `if distance < threshold` branch. Clustering would fall out of
proximity in the same way the nav design describes, not a separately
coded clustering step.

**Status**: vision-only, explicitly deferred — user chose to record the
connection rather than scope implementation now. Not a bug-fix task (the
two bugs above are real and would need fixing either way if anyone patches
this module conventionally), but the recommended path is redesign-around-
the-bugs, not patch-in-place, given the reframe above.

#,,,,,,,,,...,..,,.,,,,,.,..,,,,.,.,.,,,,,...,..,,...,...,.,,,,,,,.,,,.,,,.,,,
#NOTPLFZYP7MCPCJVKDTNGI4S7VMHQSGDBWHMNQYSZ2D5LVJXBIFHATGTDQQMZHNHO2A2MO4YFIDVY
#\\\|APNOPLL2TLYLNWFVZY744WMRQ3AKK7SHJIZAQVHUYA37WNLFWJZ \ / AMOS7 \ YOURUM ::
#\[7]I6RT3BRDY7DEUN3VPRSG4K2LZW4MRZOA6WZTNENLONAGQUIXZOBQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
