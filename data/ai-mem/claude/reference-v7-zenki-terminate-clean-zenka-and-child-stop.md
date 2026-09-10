---
name: reference-v7-zenki-terminate-clean-zenka-and-child-stop
description: "to cleanly stop a zenka AND its spawned child process (e.g. coding's GPU inference server) for a maintenance window, use v7-zenki.terminate <name> / v7-zenki.start <name> -- not a manual data-flag hack plus a direct kill on the child pid."
metadata: 
  node_type: memory
  type: reference
  originSessionId: 25027270-dc9c-4fde-a219-c4e76981a4cf
  modified: 2026-09-09T21:35:02.345Z
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

**simpler alternative for the common case (2026-09-09)**: if the actual
goal is just "restart this zenka" (e.g. to pick up a fresh `init_code`
run after an edit), don't manually sequence `terminate` + `start` --
`v7-zenki.restart <zenka>` (`src/v7-zenki.zenka.cmd.restart`) is a real,
current single command that does both together, plus a `:twin:` prefix
for zero-downtime handover that the manual sequence can't give you.
Found this after a Kimi dispatch got stuck hunting for a working restart
command (its own memory still said the pre-rename `v7.restart`, a stale
prefix, not a wrong concept) and I'd given it the two-step version
without checking whether a direct one already existed -- check for the
obvious single command before reaching for a manual multi-step sequence.
The two-step `terminate`+`start` is still the right answer specifically
when you need the manual-stop side effect (disabling auto-restart,
e.g. for a maintenance window), not as the default way to "just restart."

## related

[[feedback-mcp-server-p7-kimi-dispatch-nonblocking]]

#,,..,,,,,..,,,,,,.,.,.,,,,..,...,,,,,,,.,.,,,..,,...,...,...,,.,,...,,.,,,,.,
#BFGVKUCHRQET4OHIWZW7JE45WSZHIE5TSGQFOHAIGCVSQVDQOSLHA3GNYF4WTBL5JK7MCIFGXHFNS
#\\\|HJFYOHW5PIGHNIV2WV3NTVDK5AXVRSMRBP4KJNWQ2SZP3THPVKI \ / AMOS7 \ YOURUM ::
#\[7]O44T34HWXJ7JAXF7NVK555RPKWUKSCJ2YEJCMNDWAEDWGTCGBKDY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
