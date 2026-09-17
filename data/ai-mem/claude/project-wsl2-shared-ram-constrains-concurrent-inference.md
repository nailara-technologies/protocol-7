---
name: project-wsl2-shared-ram-constrains-concurrent-inference
description: this host runs under WSL2, so the ~16GB /proc/meminfo total is WSL2's own carved-out share of host RAM, not the full machine -- running two concurrent multi-GB model loads (e.g. gpu + cpu model-sweeps at once) is real resource contention here, not a theoretical concern; a full Linux migration is planned to remove this ceiling
metadata:
  type: project
---

2026-09-17, confirmed by the user directly: `/proc/meminfo`'s `MemTotal`
(~16GB on this host) is WSL2's own allotted portion of the real host
machine's RAM, further split from whatever Windows/the host OS reserves
-- not the actual full physical RAM available. Surfaced while diagnosing
a real crash storm ([[project-fetch-huggingface-checksum-verify]]'s
sibling thread, the model-status sweep work): running the gpu and cpu
model-sweeps concurrently caused repeated segfaults (exit=11, not
OOM-kill -- no `dmesg`/`journalctl` OOM events) across multiple
otherwise-fine models, most likely genuine memory/CPU contention rather
than any one broken model (the same small model, `5G42PRY:3SZ4PWI`,
worked cleanly once and crashed on a later attempt under load).

**Refined same session, using `powershell.mem-used`/`powershell.mem-
top-proc`** (already-built, already-committed real Windows-host memory
tools, `b215e000d`, see `data/tasks/completed/powershell-host-memory-
commands.md` -- previously unused for this purpose): checked the actual
host during the crash storm's aftermath -- host at 50.29% memory used,
`vmmemWSL` (the WSL2 VM process itself) consuming only ~7.5GB of host
RAM, well under the ~16GB `/proc/meminfo` reports inside WSL. **The host
itself has real spare headroom -- the binding constraint is specifically
WSL2's own configured memory ceiling** (likely `.wslconfig`'s `memory=`
setting, or WSL2's default ~50%-of-host cap if unset), not host-wide
exhaustion. This means raising WSL2's memory allocation is a plausible,
sooner-than-a-full-migration lever to remove this ceiling, worth trying
before assuming concurrent sweeps are permanently off the table until a
full Linux migration.

**Additional reason to sequence, independent of the crash risk**, per
the user: arbitrary concurrent resource contention also makes inference
duration/timing statistics meaningless -- directly relevant to
`MODEL-BENCHMARK-HARNESS.md`'s ttft/tokens-per-sec scoring dimension,
which needs a clean, uncontended baseline to produce comparable numbers
across models. Sequencing sweeps isn't just a stability workaround, it's
also a data-quality requirement for anything downstream that measures
timing.

**How to apply**: don't run two concurrent heavy inference workloads
(model-sweeps, benchmark runs, parallel self-tests across both backends)
on this host without accounting for the WSL2 ceiling -- sequence them
instead of parallelizing, unless/until WSL2's memory allocation is
deliberately raised (check host headroom via `p7c powershell.mem-used`
first) or the planned full-Linux migration happens. If a similar crash
storm recurs with sequential workloads too, that would be new evidence
pointing at something else (a genuine binary bug, a leaked resource from
a prior crash cycle) rather than this capacity ceiling -- don't
reflexively blame WSL2 for every future inference crash without
checking for OOM signals and sequencing first.

## second, more severe incident, same session, AFTER sequencing per above

Sequencing the sweeps (per this file's own advice) did NOT prevent a
second, worse crash: real host-level OOM, system memory hit 97%+,
forcing v7-zenki to self-terminate all 289 sub-processes, and even that
wasn't enough -- recovery needed a full `wsl --shutdown` from the
Windows side. Confirmed by the user: the crash mechanism was the OS
kernel/systemd itself starting to send SIGTERM indiscriminately once
under severe memory pressure, faster and less gracefully than `system`
zenka's own memory-watchdog could act -- not a graceful in-process kill.
**This was a single sequential gpu sweep candidate, not a concurrency
problem** -- proving incident 1's "sequence them" fix addresses a
different failure mode than this one.

**Real root cause, confirmed by the user ("not present before we
implemented partial offloading support")**: `coding.helper.
check_resource_fit`'s gpu branch had been changed (same session, since
reverted) to gate "fits" on system RAM instead of VRAM, reasoning that
partial GPU offload means a model doesn't need to fully fit VRAM. That
reasoning is correct in isolation but was unsafe in practice:
`coding.helper.calculate_safe_context`'s gpu branch has ZERO
partial-offload awareness -- it sizes the KV-cache/context window from
`total_VRAM - full_model_size`, assuming full-VRAM residency regardless
of whether the model actually got partially offloaded to cpu/ram. A
partially-offloaded model could therefore be handed a VRAM-scale
context allocation that actually lands on system RAM, on top of the
model's own already-large cpu-resident portion -- exactly the kind of
memory overcommit that didn't exist before partial offload made
"doesn't fully fit VRAM" a normal, accepted case rather than an
exclusion.

**Fix applied**: reverted `check_resource_fit`'s gpu branch back to
gating on VRAM (same `pre_filter` total-vs-free distinction from
incident 1 preserved) -- so gpu sweep/spawn candidates are restricted
again to what genuinely fits VRAM, until `calculate_safe_context` is
ALSO made partial-offload-aware (would need to know the actual offloaded
layer count/ratio, not just total VRAM vs full model size, to size
context safely across the vram/ram split). **Do not re-enable "gate on
system RAM only" for gpu without fixing calculate_safe_context's gpu
branch first** -- the two must move together, not independently.

#,,..,,,,,.,,,...,,,.,..,,,..,,.,,,,.,.,,,,,.,..,,...,...,...,..,,.,.,.,,,,.,,
#UBDPQSOOBNJ62X52MQOWFIPHKUJHCNGPI7UFVKCABPLCE2DJJLMA3AMJ33JLVPMUNNGMGBI73ENEA
#\\\|UTID653CHPKRMT6ZK3MVYTZUX64RFAA2L4HMFSJHOTZECIGOKG6 \ / AMOS7 \ YOURUM ::
#\[7]DM2OPGRBZHHXBBJTBTSISCBSWIH4D3Q5O5I3DW6NXGNMETLLS2BQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
