---
name: bug-coding-cpu-binary-abi-skew-root-cause-2026-09-17
description: root cause FOUND for the coding-zenka CPU inference segfault that was "unknown" at end of 2026-09-17 model-sweep session -- llama-server-cpu is a 609-commit-stale executable dynamically linked against libllama.so/libggml.so rebuilt 6 months later; not a model-file or thread-config issue
metadata:
  type: project
---

Root cause of the CPU-backend segfault left open in
[[project-2026-09-17-model-sweep-session]] and first surfaced in
[[topic-coding-cpu-spawn-day-2026-08-26]]: **`llama-server-cpu` is a
stale binary running against shared libraries it was never linked
against** -- an ABI skew, not a model-file, thread-config, or
zenka-side bug.

**Evidence chain** (`/data/source/ik_llama.cpp`, external checkout, not
project-tracked):
1. `$CHILD_ERROR` in `coding.handler.inference_server_sigchld` is the
   raw Perl wait status (unshifted) -- `exit=11` there means killed by
   **signal 11 (SIGSEGV)**, confirmed genuine, not a swallowed
   error-exit path.
2. Direct repro (`llama-server-cpu -m Qwythos-9B-v2-MTP-Q6_K.gguf ...`,
   the known-crashed / gpu-functional discriminating candidate
   `2HZQLFQ:LOYSD4A`) segfaults (exit 139) immediately after printing
   the `system info` startup line, before model loading starts.
3. Discriminating test: the SAME model loads and serves fine via
   `llama-server-cuda-fa -ngl 0` (CPU-only compute, GPU-family binary,
   `LD_LIBRARY_PATH=/data/source/ik_llama.cpp` set to match what
   `coding.spawn_inference_server:606-607` sets for the zenka) --
   `exit=124` (timeout, i.e. still healthy/serving). This rules out the
   model file and rules out CPU compute itself being unsupported.
4. Falsified the old `-tb 8` / `n_threads_batch=-1` theory from
   [[project-2026-09-17-model-sweep-session]]: the healthy GPU run
   above logs the identical `n_threads_batch=-1` startup line -- it's
   llama.cpp's documented "inherit from n_threads" sentinel, printed on
   every healthy server, not a live smell. Don't re-test `-tb`.
5. **The actual finding**: `llama-server-cpu` (sha256
   `d316eab5...`, identical to `build-cpu/bin/llama-server`) is dated
   **2026-03-09**. `build-cpu/src/libllama.so` and
   `build-cpu/ggml/src/libggml.so` -- the libraries it dynamically
   links against at runtime -- are dated **2026-09-08**, the same day
   `build-cpu/CMakeCache.txt` was reconfigured (04:17). The GPU binary
   `llama-server-cuda-fa` and its own top-level `.so`s were ALSO
   rebuilt that day, ~2.5h earlier (01:45), and stayed in sync --only
   the CPU target's executable link step was skipped or failed during
   that Sep-8 rebuild, leaving a **609-commit-stale executable**
   (`542988773`..`fe215a8cc` in `ik_llama.cpp` upstream, spanning
   qwen4exp/MTP self-speculative decoding, DFlash, SWA-compression, and
   whatever ABI/struct changes those carried) linked at runtime against
   current libraries. Segfaults on any incompatible symbol/struct-layout
   difference the loader resolves -- consistent with crashing for "the
   large majority of models tested" (89/90 in the sweep) rather than
   being model-specific: it's not really 89 broken models, it's one
   broken binary hit 89 times.

**No CPU build recipe exists** (`cfg/zenki/build/recipes/` only has
`ik_llama-cuda.yaml`) -- `build-cpu/` was configured ad hoc, cmake
reconfigured but the server target apparently never fully relinked.
Fix is to rebuild `build-cpu` clean (or at minimum force-relink the
`llama-server` target) and copy the fresh binary over the stale
top-level `llama-server-cpu`, verifying sha256 changes and a direct
repro run succeeds, before resuming
`coding.model-sweep-resume cpu :force:`. The 19 GPU-crash candidates
in `/data/backup/session-state/gpu-crash-candidates-2026-09-17.txt`
are unaffected by this finding -- different binary, still open, and per
prior advisor note possibly unsupported-architecture rather than
corrupt files, don't retro-tag them as deletion candidates without
separate review.

#,,,,,...,..,,,..,,,,,..,,,..,...,...,,,.,,..,.,.,...,...,,,.,..,,.,.,,..,..,,
#YJUPIQ46UYMMGHR3PSFLNZFEY7WJ6YDZFWLJGGFGQSDQB6X3KR25Q6VXUKOJCBQHH2AHHBZJF52VE
#\\\|475TT4WDGX2H6UIIV2GLIC6X5QNVTXUYTM36KZC3LEZJ27MVYI6 \ / AMOS7 \ YOURUM ::
#\[7]VZMH5ZBVVIMEPIBVTFJRAPDW4CSDPZX3AIRKOQR345FOTHHRQ4CI 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
