---
name: flag-full-rerun-cost-before-redispatch
description: before redispatching a costly job after a crash/fix, explicitly check and state whether it resumes or restarts from scratch
metadata:
  type: feedback
---

when a multi-hour (or otherwise costly) job dies and you fix the root cause and
redispatch it, explicitly check whether the job can resume from partial state
or must restart from zero -- and say which, out loud, BEFORE redispatching,
not after the user notices it's back at step 0.

**Why:** 2026-09-11, lora training died at the very last step (114/114) on an
EACCES writing the final adapter -- the permission bug was real and got fixed
correctly, but the redispatch silently restarted from step 0 because
`train_lora.py` never checkpoints mid-run (only writes `output_dir` once, at
the end). The user's actual multi-hour loss was the missing checkpointing, not
the permission bug per se -- but I only surfaced that fact to advisor
internally and filed it as an "optional future fix," never said it to the
user before hitting spawn again. They found out by watching step counters
reset and were understandably upset.

**How to apply:** after any crash-and-fix-and-redispatch of a long-running
job, before calling spawn: check for checkpoint/resume support in the actual
job (not just "does the bug look fixed"). State plainly in the same message
where you announce the redispatch: "this resumes from X" or "this restarts
from zero, costing another ~N hours, because Y." Let the user decide whether
to redispatch with that cost in view, rather than finding out after the fact.

#,,,.,...,..,,,,,,,.,,,,.,,,.,,..,..,,,,.,,,,,..,,...,...,...,...,..,,.,,,.,.,
#CKTRMXCACWXYF4HUPASFSL7GCTZJEHUAN4SYT5DTFY3MZK6CBPMHL7NPVSH77YONHWVACTMMA2TF2
#\\\|Q2FL3W6B2HBV57XH3DHZNXPVWKNLUTBFNUKRCU5DAKV6DRR4RG4 \ / AMOS7 \ YOURUM ::
#\[7]VKAEKFYS3FOZCTCRL4U7YN6WLUTDPO6HSIWRKPL24JG5Q3APWGBQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
