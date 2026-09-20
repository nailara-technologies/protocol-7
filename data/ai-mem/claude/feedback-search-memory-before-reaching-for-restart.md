---
name: feedback-search-memory-before-reaching-for-restart
description: before doing a v7-zenki.restart to apply a config/access.cmd.usr change, search memory / try <zenka>.reload config first -- a prior session already solved this exact class of problem
metadata:
  type: feedback
---

Reached for `v7-zenki.restart models` then `v7-zenki.restart coding` (2026-09-20) to
apply new `access.cmd.usr.cube` command grants and a `modules.load` addition, reasoning
from first principles that a `zenka.v7` script line only runs once at boot. Both
restarts worked, but were unnecessary: [[reference-ntime-x4200-and-cube-cross-zenka-access]]
(kimi memory, 2026-09-15) already documented that `<zenka>.reload config` applies an
`access.cmd.usr` change live, no restart needed -- the exact fact I re-derived the hard
way five days later by reading `base.cmd.reload`'s own source from scratch.

**Why this matters**: a restart is not free here -- it drops in-flight state (an
active model-sweep candidate, an in-progress self-test, whatever else the zenka was
mid-doing), and on `coding` specifically it re-spawns both inference servers, costing
real load time. `reload config` (+ `reload source` if a newly-listed module namespace
also needs compiling in) gets the same result with none of that disruption.

**How to apply**: before restarting a zenka to apply a `zenka.v7`-level config/access
change, grep `data/ai-mem/claude/` (and `data/ai-mem/kimi/`) for "reload config",
"access.cmd.usr", or "restart" first -- this exact problem shape (new command grant not
taking effect) has almost certainly been hit and solved before. Try `<zenka>.reload
config` before `v7-zenki.restart <zenka>`.

#,,,.,.,,,...,...,,,.,.,,,,,.,.,.,,,,,,,,,,,,,..,,...,.,,,.,.,...,...,,,,,.,.,
#SMRU35ZS6W2IZ6CRGIPBU54WOFX3TE3L6CFWP3QG7VS62VNXJWJXTZ757USDBLOR3VEE553ABHBTQ
#\\\|J3QDFAKL4MAU2DXLVG3GW33H4R637JYTD7TNXDAH27JSHTSZPY7 \ / AMOS7 \ YOURUM ::
#\[7]GIH6MTAMMABWLYPT7EZPR2UN55Z4FHGAYLD5Q57S7EF6LJTARUBQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
