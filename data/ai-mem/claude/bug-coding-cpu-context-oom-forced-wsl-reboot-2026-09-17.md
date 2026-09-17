---
name: bug-coding-cpu-context-oom-forced-wsl-reboot-2026-09-17
description: resuming the cpu model-sweep (right after fixing the ABI-skew segfault, same session) triggered a genuine kernel OOM-kill of llama-server-cpu at 15.3GB RSS that forced a full WSL reboot -- calculate_safe_context's CPU RAM math is unsafe at large auto-expanded context sizes, same failure class as the 2026-08-29 GPU incident
metadata:
  type: project
---

Caused directly by me resuming `coding.model-sweep-resume cpu :force:` right after
landing [[bug-coding-cpu-binary-abi-skew-root-cause-2026-09-17]] the same session.
The sweep switched to model `32TNYFY:ZKQQR2Q`, auto-expanded context to 144993
(RAM math: `RAM=13822 MB : model 3949 MB ... safety=2347 MB : calc : 200353 |
clamped : 144993 [maximum]`), and within ~seconds the kernel OOM-killer killed
`llama-server-cp` (pid 60089) at **anon-rss:15294012kB (14.9GB)** on a ~15GB-total
host. User had to reboot WSL entirely (`journalctl -b -1` confirms genuine
`oom-kill:...task=llama-server-cp` at 15:15:39, `systemd[1]: init.scope: The
kernel OOM killer killed some processes in this unit.` -- distinct from but same
underlying-cause family as [[feedback-wsl-oom-full-vm-crash-2026-08-29]]'s
finding 1).

**Root cause: `coding.helper.calculate_safe_context`'s CPU branch undersizes
actual memory use at large context.** Worked backward from the numbers: at
context=144993, model=3949MB, kv_bytes_per_token=28KB (7B-class tier, this
model's size falls 3-7GB), predicted usage was model(3949) + KV(~3965MB) +
unused safety headroom(2347MB) ≈ 10.3GB against 13.8GB available -- looked
safe by the formula's own accounting. Actual RSS reached 14.9GB, ~4.6GB over
prediction. The formula only reserves a flat 30%-of-remaining safety margin
(capped 512-4096MB) for "compute buffers, temporary allocations, generation
headroom" -- this does NOT scale with context size, but llama.cpp/ik_llama.cpp's
actual compute-graph buffers DO grow with context, especially at the ~145k
extreme end. The per-token KV byte-size table (`src/coding.helper.calculate_safe_context:44-56`)
is also just an architecture-class heuristic, not measured per-model.

**Compounding factor**: `coding.cfg.context_max` (144993) is a single global
ceiling applied identically to both GPU and CPU backends
(`src/coding.helper.calculate_safe_context:21`, `$MAX_CONTEXT = <coding.cfg.context_max> // 131072`
used in both the CPU and GPU branches) -- tuned for GPU where the ceiling matters
because VRAM is genuinely scarce; on CPU the same ceiling lets the RAM-based
calc (which came out to 200353, i.e. the RAM math itself thought it had even
MORE headroom than the config ceiling) push right up against a value that
turned out to be unsafe by a wide margin once real compute-buffer growth is
counted.

**FIXED same session, two-layer defense, both landed + syntax-checked +
live-verified.** `src/coding.helper.calculate_safe_context`: (1) the flat
capped safety margin (was max 4096MB) is now supplemented by an explicit
context-scaling compute-buffer term, `compute_bytes_per_token =
kv_bytes_per_token * (1 + cpu_compute_buffer_multiplier)` (default 6x,
NOT a fitted constant -- see below); (2) a decoupled hard backstop
(`cpu_compute_buffer_hard_multiplier`, default 15x) caps the process's
own predicted footprint at a flat fraction of TOTAL system ram
(`cpu_ram_hard_fraction`, default 0.5), using its OWN separate multiplier
specifically so an error in the soft model's rate doesn't rescale straight
through the hard ceiling too (verified by hand: routing the hard budget
through the SAME soft rate would still land ~74-99% of total ram if that
rate turns out 2-3x too optimistic).

**Second bug found only by testing the first fix live**:
`src/coding.spawn_inference_server`'s context selection let the zenka's
global `inference.model.context_length` config (42500, GPU-tuned) override
the RAM-safety calc *upward* whenever the auto-calc came out lower --
"large model: use configured floor even if above safe auto-calc" reduces to
"ignore the RAM-safety calc" for CPU. This re-triggered the SAME near-OOM
pattern (a Claudette-7B spawn hit 12.6GB RSS at MemAvailable dropping to
low single-digit GB before I could react) even with `calculate_safe_context`
already fixed, because the fixed value was simply discarded. Fixed by adding
a `$backend eq 'cpu'` branch that treats the RAM-safety ceiling as a genuine
ceiling instead of a floor for CPU specifically (GPU branch untouched --
VRAM headroom is more predictable there, no incident on that side).

**Live-verified end to end**: after both fixes + `coding.reload`, switching
to the same model that produced 9.6GB@ctx=42500 under the still-broken
override now produces `-c 9207`, stabilizes at ~5.2GB RSS, MemAvailable
holds steady ~12.8GB (85% free), server reaches healthy
(`slots_processing:1`) and serves a request. Confirmed via direct `/proc/
<pid>/status` RSS polling + `/health` endpoint, not just log inspection.

**Real residual risk, be honest about it**: the two live incidents this
session gave wildly different soft-model errors (~1.8x vs ~4x+, second one
still climbing when killed) -- the per-token compute-buffer cost is NOT a
stable constant the way `kv_bytes_per_token` is. The 6x/15x multipliers are
wide-margin stopgaps sized against those two points, not measured values.
The hard `mem_total`-fraction backstop is the real safety net while this
stays uncertain -- do not raise `cpu_ram_hard_fraction` above ~0.5 without
new data, and do not trust the soft multiplier alone. A cleaner long-term
fix would read ik_llama.cpp's actual buffer-allocation source instead of
black-box curve-fitting from crash reports, or add a true runtime RSS
watchdog (kill + backoff on threshold) as defense-in-depth beyond static
pre-flight estimation -- neither attempted this session.

**Process note on the incident response itself**: my own safety-monitor
`kill -9` silently failed against the child (owned by the `protocol-7`
unix user, not `taeki`) during the retest -- `sudo` also failed
non-interactively (no tty/askpass). The only working kill path all session
was the zenka's OWN privileged path, triggered indirectly via
`coding.switch-model` (kills the old backend process before spawning the
new one). A future safety script for this class of process needs to use
that path, or run as the right user, not a bare external `kill`.

#,,.,,.,.,,..,.,.,,..,,..,,,,,,,.,,,.,.,.,..,,.,.,...,...,,..,...,.,.,,.,,.,.,
#5WXHSY3XAZ37P7PFRQ4GY6YKX4XOU7GWDETRN63LNQAVJENGB7QTEBFSOKUQ24XT7XCBNX4IP5DJA
#\\\|II3BQ22VMAORY5WOMNUVJ2XUMTZ6EEAFBK24ICPODF5JNQL5SRR \ / AMOS7 \ YOURUM ::
#\[7]VYYVO4N6D5XARJL6O6BZTZSZWPTFOSHT4DUKUAHFN3VEURC4I4DQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
