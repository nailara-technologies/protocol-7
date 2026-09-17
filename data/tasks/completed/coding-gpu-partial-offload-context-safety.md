## [:< ##

# name  = task: make calculate_safe_context's gpu branch partial-offload-aware
# descr = a model that doesn't fully reside in VRAM can be handed a VRAM-scale
#         context allocation anyway, landing the overflow in system RAM on
#         top of the model's own already-large cpu-resident portion --
#         confirmed root cause of a real host-crashing OOM kill, recurred
#         at least twice across two sessions

## severity -- read this section first

this is NOT a routine cleanup task. getting this wrong in a way that looks
plausible but is still unsafe reproduces the exact failure this task exists
to fix: a kernel OOM-kill that can force `wsl --shutdown` to recover
(confirmed to happen, twice, in [[project-wsl2-shared-ram-constrains-concurrent-inference]]'s
incidents 2-3, and again 2026-09-17 later the same day as that memory file
-- `journalctl -b -1` showed `llama-server-cu` killed at 14.98GB RSS,
essentially the entire host, immediately preceded by mem% readings
climbing 81% -> 87% -> 91% in the system zenka's own accelerated-poll log).
**do not verify this by letting a real spawn run to see what happens** --
verify by dry-run arithmetic against the real historical incident numbers
first (see "verification" below), the same discipline used earlier this
session for the analogous CPU-side fix
([[bug-coding-cpu-context-oom-forced-wsl-reboot-2026-09-17]]) -- only
attempt a bounded live test, with an external safety-kill watching real
RSS, once the dry-run math checks out.

## the actual bug, exact location

`coding.helper.calculate_safe_context`'s gpu branch
(`src/coding.helper.calculate_safe_context`, the `if ($backend eq 'gpu')`
section past the cpu branch's `return` -- read the whole file, both
branches, before touching anything) computes:

```
$remaining_mb = $total_mb - $model_size_mb - $mmproj_size_mb - $cuda_overhead_mb;
```

-- `$total_mb` is total VRAM. This assumes the ENTIRE model resides in
VRAM. It has zero awareness that a model can be partially offloaded
(some layers on GPU, the rest on CPU/system RAM) -- a real, deliberately
built, already-shipped feature (see below), not a hypothetical.

## the data already exists, just isn't threaded through

`coding.spawn_inference_server` (`src/coding.spawn_inference_server:293-393`)
calls `coding.helper.calculate_partial_gpu_layers`
(`src/coding.helper.calculate_partial_gpu_layers`, read this whole file too
-- it's short) BEFORE calling `calculate_safe_context`, whenever the full
model doesn't fit VRAM. That helper already computes and returns:
- `layer_count` -- the model's TRUE total layer count (via
  `models.gguf.file.extract_layer_count`)
- `computed_layers` -- how many layers actually got offloaded to GPU
- `per_layer_mb` -- average VRAM cost per layer (a first-order
  approximation, per that file's own comment -- embedding/lm-head tensors
  aren't offloadable layers but are folded into the same total, so this is
  "good enough to pick a conservative -ngl, not exact")

By the time `calculate_safe_context` is called
(`coding.spawn_inference_server:388-393`), `$gpu_layers` already reflects
whatever ACTUALLY got used (possibly reduced from the configured default) --
but `calculate_safe_context`'s call passes only `model_path`, `mmproj_path`,
`backend`. None of the offload-ratio information reaches it. This is
primarily a **wiring gap**, not a from-scratch design problem -- the hard
part is the math once the ratio is available (see below), not obtaining it.

**Subtlety, do not assume `$gpu_layers == $configured_gpu_layers` means
full offload**: the default (`coding.spawn_inference_server:40`,
`$gpu_layers = $params->{'gpu_layers'} // 33`) is a generic constant, NOT
derived from any specific model's real layer count. A model with MORE than
33 layers would still be a genuine partial offload even when the
`calculate_partial_gpu_layers` reduction branch never fires (because
`-ngl 33` never exceeded VRAM in the first place, so the "doesn't fit"
branch at `spawn_inference_server:299` was never entered at all). The
correct offload-fraction check is `$gpu_layers` vs the model's real
`layer_count` -- extracted fresh via
`models.gguf.file.extract_layer_count` when the partial-offload branch
didn't run (the model still needs this comparison even on the "happy"
path), not "did the reduction branch fire."

## the actual fix -- design decision, not just wiring

`calculate_safe_context` needs `gpu_layers` and `layer_count` passed in
(new params on the existing `{model_path, mmproj_path, backend}` call
shape). With the real offload fraction `$gpu_layers / $layer_count`
known, the gpu branch's budget needs to be split, not computed as if the
whole model were VRAM-resident:
- the GPU-resident fraction of the model's weights consumes VRAM (roughly
  `$model_size_mb * $gpu_layers / $layer_count`, matching
  `calculate_partial_gpu_layers`'s own per-layer approximation -- reuse
  that same approximation, don't invent a different one)
- the CPU-resident remainder consumes SYSTEM RAM, exactly like the cpu
  branch already budgets for (mirror the cpu branch's own reasoning --
  `os_overhead_mb`, the compute-buffer multiplier, the hard
  total-ram-fraction backstop -- all landed earlier this session, same
  file, read that whole branch as the pattern to reuse for this
  now-relevant RAM-side risk, not just the vram side)
- the KV cache / context window itself is a SINGLE allocation regardless
  of offload split (llama.cpp keeps KV cache together) -- decide, and
  state explicitly in the code comment, which pool (VRAM or RAM, or the
  tighter of the two) actually constrains it in the partial-offload case,
  don't just silently pick one without reasoning about which is correct
- full offload (`$gpu_layers >= $layer_count`) must reduce to exactly the
  EXISTING gpu-branch behavior, unchanged -- this is the overwhelmingly
  common case (most models fit fully), a regression here would be a much
  worse outcome than the bug being fixed. write a check confirming this
  reduction is exact, not just "close enough"

## explicitly out of scope

- the cpu branch's own math (context-scaling compute term, hard
  total-ram-fraction backstop) -- already fixed, already committed, DONE.
  read it as the pattern to mirror for the new RAM-side risk in the gpu
  branch, don't modify it.
- `check_resource_fit`'s existing VRAM-only pre-filter gating (the revert
  from the prior incident, see
  [[project-wsl2-shared-ram-constrains-concurrent-inference]]) -- stays
  as-is, this task doesn't touch it. it's a coarser candidate-list filter,
  not the fine-grained spawn-time safety math this task fixes.
- `coding.helper.calculate_partial_gpu_layers` itself -- read it, reuse
  its per-layer approximation and its `extract_layer_count` call, don't
  modify its own logic.
- `coding.model_sweep.handler.cooldown_resume`, `get_children`,
  `pid_alive`, `gone_child`, the model-sweep `:restart:` keyword, or
  anything else committed earlier this session -- all separately
  landed and working, don't re-investigate.

## verification -- dry-run FIRST, live test only if the dry-run checks out

1. write a standalone perl arithmetic check (mirror the dry-run approach
   used for the cpu fix earlier this session -- `perl -e` against real
   numbers, not a live spawn) using the actual historical incident
   numbers: the 2026-09-17 incident killed `llama-server-cu` at
   **14.98GB RSS** on this host (~15GB total physical RAM under WSL2, see
   [[project-wsl2-shared-ram-constrains-concurrent-inference]] for the
   WSL2-ceiling context). Confirm the new formula, applied to whatever
   partial-offload scenario is the best reconstructable approximation of
   that incident (check `state/model_status.yaml` /
   `/data/backup/session-state/` for candidates active around that
   incident if useful), would have produced a context size whose predicted
   total footprint (GPU-resident weights + CPU-resident weights + KV +
   overhead) stays safely under a reasonable ceiling -- do this BEFORE any
   live test.
2. only once the dry-run is convincing: a bounded live test, with an
   external safety mechanism actively watching real RSS via
   `/proc/<pid>/status` and killing the spawned process (via the coding
   zenka's own privileged switch-model/kill path, NOT a bare external
   `kill -9` -- that failed silently earlier this session against a
   `protocol-7`-owned process owned by a different unix user) if it
   crosses a hard safety ceiling well before host-critical, same
   methodology as the cpu fix's own live verification.
3. confirm the full-offload case (no partial offload triggered) produces
   IDENTICAL context sizing to before this change -- this is the
   regression-risk case that matters most.
4. `bin/format-code -c` on every touched file.
5. leave the tree uncommitted, report back with the dry-run numbers
   explicitly (not just "verified"), what was live-tested and how, and
   flag clearly if live-testing wasn't attempted and why.

if anything about the actual partial-offload mechanics turns out
different from what's described here once you're reading the real code
(the file:line pointers above were correct at the time of writing but
re-read the live files, don't trust line numbers blindly), stop and
report the discrepancy -- do not improvise a different safety design
silently, given what's at stake if it's wrong.

## status [ 2026-09-17 ] — DONE, live-verified, committed `fde150737`

kimi (k3) landed the full design correctly on the first pass: budget
split by offload fraction (reusing the existing per-layer
approximation), VRAM math also fixed to subtract only the gpu-resident
share (a secondary bug beyond what was asked), RAM-side budget
mirroring the CPU branch's full safety stack, tighter-of-two-pools
resolution, and the same floor-vs-ceiling fix extended to partial-
offload GPU. Dry-run matched the live spawn exactly (ctx=8079,
33/48 layers on gpu). Kimi's own dispatch ran out of its step budget
right before the highest-value check (a real inference request to
force actual KV/compute allocation, the exact test that exposed the
original bug) -- completed that step directly afterward: RSS moved 4MB
across a real ~4500-word-prompt request (4411->4415MB), no memory
pressure. Full-offload case confirmed unchanged (params default to 0).

#,,..,,.,,.,.,.,,,.,,,.,.,,..,,,.,.,,,,,,,,.,,.,.,...,..,,.,.,,.,,.,.,..,,..,,
#QQ53VG4Y56M5WN53KAA6ZBFL4I2N3GMJ3ONFUFCMM7PBJ4SV4ITB5DBBVSHLISSSZUWGQ6PN7IFO4
#\\\|PU37VWRJ4N5WHZHLL5H56QK36TVYKPI4AGTNLHHOE7TEGEW7NXB \ / AMOS7 \ YOURUM ::
#\[7]AP3EE5DWIZGSKQY6OIARW4ZVDD5B4MGPSSMBNBKMYZEWTBN77QCI 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
