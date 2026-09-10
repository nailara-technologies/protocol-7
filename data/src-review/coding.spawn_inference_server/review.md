---
module: coding.spawn_inference_server
generated_at: 2026-09-09T23:20:24
generator: llm
status: llm-generated, NOT hand-verified -- generated draft, not documentation fact
model: Qwen3.8-9B-heretic-uncensored.i1-Q4_K_M.gguf
model_amos_id: OFSQC4I:QDBKEXY
model_endpoint: http://127.0.0.1:8000/v1/chat/completions [ ik_llama.cpp llama-server, local ]
prompt_version: src-review-v1
source_sha1: 1232979248078e63d6117cbb49d55cbec52ab05d
source_lines: 796
dep_graph_callers: 6
dep_graph_caveat: static literal calls only; conditional/dynamic dispatch invisible to the graph
usage_prompt_tokens: 4198
usage_completion_tokens: 1104
---

# review: coding.spawn_inference_server

## Purpose
Spawns a llama-server backend (CPU or GPU) asynchronously, managing lifecycle by killing old processes, cleaning up stale pid files, and performing VRAM safety checks before launching.

## Interface
Takes a `$params` hashref with keys: `backend` (default: `cpu`), `port` (default: 8000), `binary`, `threads` (default: 8), `gpu_layers` (default: 33), `model_path`, `mmproj_path`, `amos_id`. Returns a hashref with `success` (boolean) and `error` (string) on failure.

## Role & dependencies
Central spawn coordinator for inference backends. Notable callees: `<coding.awaiting_resources>`, `<coding.spawning_in_progress>`, `<coding.inference_servers>`, `<coding.watcher_pair>`, `<coding.lib_path>`, `<coding.cfg.vram_safety_mb>`, `<coding.cfg.partial_offload_enable>`, `<coding.cfg.partial_offload_min_layers>`, `<coding.helper.calculate_partial_gpu_layers>`. Heavily relies on `<[base.logs]>` for logging.

## Observations
- **Truncation risk**: Source cuts off mid-calculation at the VRAM check (`$partial = <[coding.helper.calculate_partial_gpu_layers]>->(...`), making the partial offload logic incomplete.
- **Race condition**: The 30s cooldown via `sleep(0.0013)` is described as yielding to the event loop, but the actual cooldown enforcement appears to be in `<coding.awaiting_resources>`. The short sleep's purpose is unclear.
- **Process group kill**: Uses `kill('KILL', -$old_pid)` to kill the entire process group, which is correct for llama-server's forked workers.
- **Orphan cleanup**: Scans pid files with glob and kills orphans, but this is O(n) per spawn and could be a performance concern under high churn.
- **Port conflict detection**: Uses `fuser` with stderr redirection to avoid leaking its header output to zenka's terminal.
- **Zombie handling**: Checks `/proc/$pid/stat` for 'Z' state to skip defunct processes.

## Confidence
Unclear on the exact purpose of `sleep(0.0013)` — it's described as yielding to the event loop but the 30s cooldown is enforced elsewhere. Also unclear whether the partial offload calculation logic is complete given the truncation.

---

## deterministic check outputs [ verbatim ground truth ]

### module_convention_check

```
<!-- no violations found in 1 files [ max_line=78 max_descr=55 ] -->
```

### validate_module

```
Validation PASSED for 'coding.spawn_inference_server'
No issues found.
```

#,,..,,..,,,,,,,,,...,,,,,.,.,.,.,,.,,,,,,,..,..,,...,...,..,,...,,,.,...,,..,
#LPN5INTZRNBRTKP2VM55P6KCDOSGPB62NJ6ST6DHCJOVN5DAMGTZK3TJEMUGMBS6GVWSE2IYVOY6C
#\\\|NTAE2CSPF4R7RN7LZMIMJPXU3VOGZ3LFF4WCLB4U4OSSRM2CUYJ \ / AMOS7 \ YOURUM ::
#\[7]ENHQ6KVZBYEHZXB2RGZUHNRHBDFSSYNJSLOY4DGCOIWF2BYKTUBI 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
