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

**update 2026-09-12**: this permission is now largely automated rather than
exercised by hand each time. `coding.lora_train_spawn` stops the live gpu
inference server itself (SIGTERM, then SIGKILL after ~6s) before spawning
training, instead of refusing and requiring a manual `kill(15,-pid)` via
`coding.eval-code`. Doing it by hand twice in the same session raced against
`coding.handler.inference_server_sigchld`'s crash-detector, which "healed"
the deliberate stop with a fresh respawn that fought training for VRAM —
fixed by adding a `<coding.lora_training_in_progress>` guard there and in
`inference_crash_restart`, the same pattern already used for `<coding.
draining>`. The standing permission itself still stands; there's just much
less reason to invoke it manually now.

## related

[[topic-kimi-dispatch-infra-hardening]]

#,,,,,,,.,..,,..,,,..,..,,,..,...,,..,,,.,..,,..,,...,...,...,,,.,..,,,..,,,,,
#YM63YS6L62BL3J2KWCNP4NBAFBZTH5ETOGQERCDISITEQ7YQL3A5DM4OM3LE2JQLUP6574HOWYUGK
#\\\|FL7QBG7GKZ7PEARWF2OPW74OODM2P6VUSM24PC3VLJHYRLXM54O \ / AMOS7 \ YOURUM ::
#\[7]ZGVC2CYJSBBR63FAOIB2SWQUZ7EFVEY4NMRQOXQLBPAJA4CCDKCA 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
