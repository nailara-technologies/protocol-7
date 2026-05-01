# Session Handover — 2026-05-01

## Task: Rebuild ik_llama.cpp (llama-server-cuda-fa)

### Why
The current llama-server binary is from 2025-12. After months of upstream fixes:
- Better VRAM management (silent KV allocation failures currently cause server hangs)
- Flash attention improvements for long contexts
- Possible better CUDA memory reporting (would improve calculate_safe_context accuracy)

### Context from current sessions
The coding zenka uses `llama-server-cuda-fa` (ik_llama.cpp fork with flash attention):
- Binary: `/data/source/ik_llama.cpp/llama-server-cuda-fa`
- Source: `/data/source/ik_llama.cpp/` (git repo)
- CPU binary: `/data/source/ik_llama.cpp/llama-server-cpu`

Current empirical limits on RTX 3060 12GB with 4B Huihui Qwen3.5 Q8_0 + mmproj:
- 110007 tokens context: works
- 130007 tokens: fails silently (KV allocation failure → server hangs)
- `calculate_safe_context` estimates too generously; actual CUDA overhead ~3000-3500MB not 1256MB
- After rebuild, test at 120K-128K to see if upstream fixes improve the ceiling

### Build scripts / docs
- Main build script: `bin/build-scripts/llama-cpp/build-llama-server-cuda-flashattn.sh`
- Flash attn build doc: `data/md/documentation/LLAMA-SERVER-BUILD-FLASHATTN.md`
- Previous build instructions (Dec 2025): `data/yaml/build-instructions/ik_llama.cpp-cuda-debian-wsl2.yaml`
- Dual strategy doc: `data/yaml/build-instructions/ik_llama_dual_strategy_2025-12-05.yaml`
- Test scripts: `bin/dev/tests/ml/test-llama-server-gpu.sh`

### Steps
1. `cd /data/source/ik_llama.cpp && git pull`
2. Check if CMakeLists or build flags changed
3. Build: `cmake -B build -DLLAMA_CUDA=ON -DLLAMA_CURL=OFF ... && cmake --build build --target llama-server -j$(nproc)`
   (or use the build script if it's still correct)
4. Verify binary runs: `./llama-server-cuda-fa --version`
5. Test with: `p7c coding.switch-model <amos-id>` and submit a simple task
6. If 110K ceiling moved up, update `coding.cfg.context_max` in `configuration/zenki/coding/start`

### After rebuild
- Test context sizes: 110K (known good), then 120K, 128K
- Check if `calculate_safe_context` CUDA overhead constant needs updating
  (`modules/coding.helper.calculate_safe_context` line ~90: `my $cuda_overhead_mb = 1256`)
- The empirical overhead with current binary is ~3000-3500MB; new binary may differ
