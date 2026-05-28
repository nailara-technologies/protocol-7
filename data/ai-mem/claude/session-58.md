---
name: session-58
description: "2026-05-28 — inference server crash fixes, llama-server rebuild (CUDA 12.9 / v4547), dist-upgrade, repo root cleanup, coding prompt context fix"
metadata: 
  node_type: memory
  type: project
  originSessionId: 06c9f83d-9e58-4010-8157-f4713569c55c
---

## inference server crash fixes (3 bugs)

**Bug 1** — `coding.handler.inference_server_sigchld`: `'params'` → `'data'` in
`event.add_timer` call. `base.event.add_timer` only forwards `data` key, not
`params`. Restart timer was firing but callback died immediately.

**Bug 2** — `coding.spawn_inference_server`: added `'model_path' => $model_path`
to server info hash. `inference_crash_restart` couldn't find it → "no model_path"
failure on restart attempt.

**Bug 3** (100% CPU) — `coding.handler.monitor_inference_startup` crash path was
calling `cancel_watcher.backend_monitor` (the ready-path helper) after closing
one fd. This installed drain watchers on dead server's closed pipes → event loop
spin. Fixed: crash path now cancels both startup watchers directly via
`<coding.watcher_pair>` without installing drain watchers.

## llama-server rebuild

- new binary: `llama-server-cuda-fa-12.9.0` version 4547 (`3bf7e836c`)
- build script: `bin/build-scripts/llama-cpp/build-llama-server-cuda-flashattn.sh`
  updated `CUDA_VERSION` 12.5.0 → 12.9.0
- Gemma model loading crash (exit=6, `free(): invalid pointer`) fixed by new upstream
  (`src/graphs/build_gemma4.cpp` + `src/llama-load-tensors.cpp` changes in new commits)
- model load time: 3.25s for 4B model (significant improvement)
- old binary `llama-server-cuda-fa-12.5.0` removed; Docker build cache pruned (7.5GB)

## system fixes

- dist-upgrade: 1457 packages updated
- `nvidia-kernel-dkms` + `linux-kernel-dkms` removed (WSL2 doesn't need DKMS)
- CUDA apt repo SHA1 key rejected by sqv (Debian 14): workaround via
  `/etc/apt/apt.conf.d/99-use-gpgv` setting `APT::Key::gpgvcommand "/usr/bin/gpgv"`
  (sqv is now a hard dep of apt in Debian 14, cannot remove)

## coding prompt context fix

`coding.prompt.assemble` now injects task context into prompt:
```perl
my $task_context = $task->{'context'} // $task->{'request'}->{'context'} // '';
if ( length $task_context ) { $raw_prompt .= "\n\n" . $task_context; }
```
**key**: context is stored at `$task->{'context'}` (top-level), NOT
`$task->{'request'}->{'context'}`. task.cmd.create stores it directly.

## reasoning namespace

- added `reasoning` to `modules.load` in `configuration/zenki/coding/start`
- `reasoning.threshold.fire` → renamed to `reasoning.threshold.crossed`
  (harmonically TRUE, self-describing); call sites in `reasoning.tree.insert` updated
- `reasoning.threshold.crossed` is a stub — extend when threshold events need
  downstream effects

## repo root cleanup

- `local/`, `var/index/`, `var/inference-cache/`, `var/nameserv/`, `var/sys-deps/`
  moved to `/data/removed/` (untracked runtime/cpanm dirs that crept into repo root)
- `.gitignore` updated to exclude them
- task file: `data/tasks/repo-root-cleanup-var-local-batches.md` — documents decisions
  needed for tracked files: `var/httpd/skins/default.tmpl`, `var/httpd/static/`,
  `batches/test_vision_batch.yaml`
- `web.assets.load_registry` uses `$project_root/var/httpd/static/` — needs update
  to absolute path before `var/` can be fully removed

## open items

- tool calls regression: model thinking 44KB but not calling tools; investigate
  whether new binary Jinja template behavior changed
- context fix not yet tested (wrong path just corrected, needs retry after reload)
- repo root tracked files still need decisions (see task file)
- staged changes not yet committed

## design doc

`data/md/design/NETWORK-BUILD-SYSTEM.md` — 6-layer network build system:
build.zenka → build graph → network distribution → 5/7 consensus → LLM audit
intake → minimal OS end state. layer 1 buildable now.

#,,.,,.,.,.,.,,.,,,,,,.,,,..,,...,,.,,,..,,,.,..,,...,...,...,.,,,...,,,.,,,.,
#4AMSV5KRRBETQ3IMZQQI3E2ARFXO3BZRPVYADGTKUUQC2JFMZWVANJAVJQF5AE6VCZQWXEKK5ZQ2O
#\\\|QIHNAUMCUYN7SLDXHEYMSNYKIWPQWQVUWD4LJD7BJO3TU34KAVZ \ / AMOS7 \ YOURUM ::
#\[7]H5ONS4SUKZHMJ7F6NCLX7OR24FVDKPLSVTKS54ELYOKGFQYAD6BQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
