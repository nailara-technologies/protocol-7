---
name: topic-dynamic-context-prep-vs-model-size
description: "user's thesis — front-loaded/dynamic context prep (gotchas, patterns, templates) converts model-size/token-spend into precision more cheaply than raw compute"
metadata: 
  node_type: memory
  type: vision
  originSessionId: e523a9e4-c458-47e5-b27c-c60766dd51a9
  modified: 2026-07-19T00:43:11.933Z
---

**Correction (same day, user pushback):** the reading below overstated how much of the scratchpad-rescue
quality traced to human hints. User's actual point: those hints (chmod-child pattern, `File::stat`
gotcha, context templates) were *minor* — K3's underlying reasoning quality is categorically different
from K2.7/below, not merely well-steered. The "stream of self-corrections that is just determined
enough" pattern is specifically what K2.7-and-below *thinking traces* look like when read directly; K3
does not exhibit that pattern anymore. See [[project-kimi-k2.7-vs-k3-tier-economics]] for the pricing
data point that goes with this (K3 ≈3.75x output / >3x input price of K2.7) — the premium reflects a
real capability-tier jump, confirmed by direct inspection of reasoning traces, not just a hunch from
output quality. Treat the paragraph below as a real-but-secondary lever, not the primary explanation for
this specific case.

Observed 2026-07-19 on the coding-zenka scratchpad-rescue task ([[topic-scratchpad-rescue-coding-zenka-task]]):
K3 delivered high-quality, self-correcting work, but a share of that quality traced back to
targeted human-supplied context mid-task — the chmod-child ownership pattern (it was about to give
files direct `protocol-7` ownership, which would have worked, but the existing chmod-child mechanism
was the established convention), the `File::stat` overloads-`stat()` gotcha (non-obvious, would have
cost real investigation to find alone), and some directly-relevant context templates that cut
investigation cost. (Per the correction above: minor issues, not the main story.)

**The thesis**: most of a task's token/investigation cost is *discovery cost* — finding conventions,
gotchas, and prior art that already exist somewhere in the repo/history. A better **dynamic context
preparation system** (assembling the relevant prior-art/gotchas/templates *before* inference starts,
scoped to the task) should recover much of that cost regardless of model size — the same mechanism that
lets a well-briefed smaller model reach equally functional/precise results as a larger one working cold.
This reframes "higher-impact tasks need higher token budget" into "higher-impact tasks need better
context prep" — token spend and model size are not the actual lever.

**How to apply:** when scoping tasks for coding-zenka/K3/other models (including task files like
[[topic-scratchpad-rescue-coding-zenka-task]]), front-load verified findings, established
conventions/patterns to reuse, and known gotchas into the brief itself — this is the same principle
already partially built as the coding-zenka's context-template system
([[coding-zenka-templates]] / `data/yaml/context-templates/`), but the thesis here is broader: worth
treating "how much discovery cost did the task file save" as a first-class metric when writing task
specs, not just correctness of the final ask.

#,,,,,,.,,,.,,,..,,.,,.,,,...,.,,,,,,,,,.,,,,,..,,...,..,,.,.,...,,.,,,,,,.,.,
#G2RATNOKHNKDOW4DMDEALBWEMRG4KEBR7VLBVEEXFRB6VUWBSTYGODGFHDTF52E3AGIFZ5YM3JCNU
#\\\|AQQR7E22FDRWVWUHQJR7UKH4DZROY44EQYKYT36E24ULNPPSZSR \ / AMOS7 \ YOURUM ::
#\[7]5DW2BDMNKJR7SD2RPOMP4OZC5SCG2KG4HEATS43W356I5HZHHKCY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
