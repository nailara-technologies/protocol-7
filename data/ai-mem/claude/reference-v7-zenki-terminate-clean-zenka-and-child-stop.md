---
name: reference-v7-zenki-terminate-clean-zenka-and-child-stop
description: "to cleanly stop a zenka AND its spawned child process (e.g. coding's GPU inference server) for a maintenance window, use v7-zenki.terminate <name> / v7-zenki.start <name> -- not a manual data-flag hack plus a direct kill on the child pid."
metadata: 
  node_type: memory
  type: reference
  originSessionId: 25027270-dc9c-4fde-a219-c4e76981a4cf
  modified: 2026-09-09T01:25:53.740Z
---

found 2026-09-09 while reviewing a Kimi dispatch that needed to free the
coding zenka's GPU (stop its spawned `llama-server` child for a LoRA
training window). Kimi improvised: set `<coding.draining> = TRUE` (a
home-grown flag coding's sigchld handler checks to skip its own crash-
auto-restart logic), then `kill('KILL', -$pgid)` on the inference server's
process group directly via eval-code, then later manually re-spawned it
via `<[coding.spawn_inference_server]>->({...})`. It worked, but it was
reinventing a wheel that already exists at the zenka-lifecycle level.

**the actually-clean way**: `v7-zenki.terminate <zenka-name>` (renamed
from `v7.stop` in `a315a0e5a`, then `v7`->`v7-zenki` identity rename in
`23a0e8d53`) sends a graceful SIGTERM to the zenka's own process
(`v7-zenki.zenka.instance.stop` -> `v7-zenki.terminate_process`, with a
timeout-based SIGKILL escalation only if it doesn't exit cleanly). A
SIGTERM'd zenka runs its own `<zenka-name>.end_code` on the way out --
for `coding`, `src/coding.end_code` already does `kill('KILL', -$pid)` on
its spawned inference-server child as part of normal shutdown. So
`v7-zenki.terminate coding` takes down the whole zenka AND its GPU server
in one native command, with no need for any manual crash-restart-
suppression flag -- that flag only matters when the zenka stays alive and
its child unexpectedly dies, which is a different scenario. Bring it back
with `v7-zenki.start <zenka-name>` (`src/v7-zenki.zenka.cmd.start`), which
re-triggers the zenka's own `init_code` and its normal deferred spawn
logic -- no manual respawn call needed either.

**caveat**: `v7-zenki.terminate` marks the zenka as manually-stopped and
removes it from `v7-zenki.start_setup.globals.zenki.enabled` -- it is a
deliberate disable, not a "pause", so `v7-zenki.start` afterward is
required and not automatic. fine for a short, explicit maintenance
window; don't reach for it if you actually just want the crash-restart
suppressed while otherwise leaving the zenka alone (that IS what
`<zenka>.draining`-style flags, where they exist, are for).

## related

[[feedback-mcp-server-p7-kimi-dispatch-nonblocking]]

#,,,.,..,,..,,,,,,,.,,,..,,.,,,,.,,,,,,,,,,,.,..,,...,...,.,,,,.,,,.,,,.,,.,.,
#2W2NDAKPFVZ7U2CBG3VRI4HEBECFFRWYIR325Z42KZRKEHXXPKIRJRYXT2SBDO7HMGOCOCDQ3VCR2
#\\\|SSEYBDXEAWLW4K2THIVB355MBPFGPA266OPCSB4USKKVWYCON63 \ / AMOS7 \ YOURUM ::
#\[7]E6EU7PPHY4HVL2ZI7RO475H2SRPK4IEK4GSU3LB77XMP6ALQCWAI 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
