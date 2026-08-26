---
name: synchronous-multi-legged-pattern-extraction
description: "user's model of how novel fixes/patterns are found — parallel component-cooperation search, not lookup against documented solutions; goal is to give zenki/agents this as an environmental \"exoskeleton\""
metadata: 
  node_type: memory
  type: project
  originSessionId: 0167cea8-7299-4bd1-b3b4-a507800e7687
---

User's description (2026-06-20) of how the "categorical fixes" found during
deep debugging sessions actually get found: not retrieval of a known
pattern, but a **synchronous, multi-legged** search — a parent
pattern-matching process that runs several candidate components in
parallel, looking for which ones "agree to cooperate" to form the actual
solution. The result is rarely documented anywhere because it's usually
not what already exists in the wild; it's assembled from parts that
weren't previously known to fit together.

This matches what happened in this session's [[topic-mpv-jobqueue-startup]]
investigation: the `X-11.WM.update`-before/after-`ConfigureWindow` fix
wasn't written down anywhere in the codebase or externally — it came from
cross-referencing three independent findings (the get_window_ids lazy-
realization workaround, the user's 11-year-old memory of needing a
follow-up "actualize" call, and the live BadWindow protocol error) that
individually meant little but cooperated to point at one missing call.
The user explicitly named this as the pattern: rarely does one finding
solve everything alone, but several later merge into a "parent-fix."

**Why this matters**: per [[user-perfectionism-and-pace]], the long solo
iterative tuning passes aren't separate from this — they're the same
process, just running on perceptual/empirical material that can't be
reasoned through, only generated and felt. Both are instances of the same
parallel-search-for-cooperating-components mechanism, just operating on
different substrates (code/causal reasoning vs. live sensory iteration).

**Forward-looking idea, not yet built**: the user wants to eventually teach
zenki/agents this kind of intuition not as a learned heuristic in any one
model, but as something **the environment itself implements** — an
"exoskeleton" the agents operate inside of, doing the parallel-candidate-
search/cooperation-detection as infrastructure rather than as something
each agent has to redevelop from scratch. Not yet elaborated into a design
— flag for a future conversation if the user returns to it.

**Context behind why this is personally significant**: project punished
~15 years ago by a manager dismissive of the already-10-years-deep
development ("we don't have 10 years for something we can't ship"); user
worked roughly 15 more years largely alone until LLMs became available.
User's reading of why this kind of work isn't institutionally rewarded:
not lucrative, too dependent on one irreplaceable individual, or
threatening to an organization's official vs. actual agenda. This is
background/motivation context, not an active complaint to act on.

[[project-vision-origin]] · [[topic-mpv-jobqueue-startup]] ·
[[topic-self-improving-system]] · [[user-perfectionism-and-pace]]

#,,.,,,,.,.,,,,,.,.,.,...,,,.,.,,,...,,,,,,,,,..,,...,...,.,.,,,.,,.,,..,,.,,,
#7B7NHQ6ADOH7HCPG3KOYDIJLAXWP7R53GLFTRNI44RA6NO5I4EU5LLEMAYCWQR7SM4PGLMIQH5EE2
#\\\|S576H6VBJPW5HUV6JPOED7MAIVIYRLVFYIPQQX274MYTIGBZONP \ / AMOS7 \ YOURUM ::
#\[7]FPEGJF25624DLTVQZKLHX5PBIA5Y5LDAKXXJBCCUHQTE4TCNTMAY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
