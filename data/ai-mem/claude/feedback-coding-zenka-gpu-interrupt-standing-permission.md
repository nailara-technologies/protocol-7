---
name: feedback-coding-zenka-gpu-interrupt-standing-permission
description: user has given standing permission to stop/restart/modify the coding zenka's live GPU inference server at any time, no need to schedule or ask first
metadata:
  type: feedback
---

2026-09-10, session resuming from `HANDOVER.md`'s loadable-memory/LoRA
thread ([[topic-kimi-dispatch-infra-hardening]] session context):
`data/tasks/coding-lora-p7-idioms.md` hazard 2 explicitly says stopping/
reducing the live coding zenka's GPU inference server for a training run
"is a real operational interruption ... not something to do silently ...
schedule an explicit maintenance window with the user ... don't assume
... without asking first." Asked directly; the user's answer: **"yes, you
can safely stop or modify the coding zenka at any time, that is no
problem."**

**Why:** removes a repeated per-task confirmation gate specifically for
this one zenka's GPU server (`llama-server-cuda-fa`, port 8000, ~12GB
VRAM). Not a blanket statement about all zenki or all destructive ops —
scoped to the coding zenka's inference process specifically, in the
context of maintenance/training work that needs the GPU.

**How to apply:** future sessions doing GPU-touching work on the coding
zenka (LoRA training, control-vector experiments, benchmark runs) can
stop/restart/reconfigure its `llama-server-cuda-fa` process directly
without pausing to ask first or schedule a window — still worth a
one-line heads-up when doing it (transparency, not permission-seeking),
and still restore it to normal unmodified startup afterward per the
existing task-file convention (see `coding-lora-p7-idioms.md` scope item
8, "restore state"). Does not extend to other zenki or to destructive
non-GPU actions (deleting files, force-push, etc.) — those still follow
the normal confirm-first default.

## related

[[topic-kimi-dispatch-infra-hardening]]

#,,.,,,,.,,.,,...,..,,..,,..,,,.,,,,,,,,,,.,.,..,,...,...,,.,,..,,.,.,,,.,,..,
#KXAB7FELTX4OX4LM5TTPEZL3MEPJZVKAR4TK7Y5XW4UN73BEJ7YPGLJR53UTU3CW3BBPOPFNA65VE
#\\\|DPIMJRUOMWKFNNCTKTICC5GVMBTRRICNKWF6QONZPUNIME7476G \ / AMOS7 \ YOURUM ::
#\[7]5LMWKWMZOVCE7OUBBRBHCJQNHZRVQARYGGUHAWMADODVGCW56GCY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
