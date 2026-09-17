---
name: project-2026-09-17-model-sweep-session
description: 2026-09-17 session state -- CPU inference binary segfault still unresolved, GPU-crash candidate list saved for review, sweep paused mid-run, both AI budgets tight going into next session
metadata:
  node_type: memory
  type: project
---

**Landed this session** (chronological, all committed, all pushed):
`c3c5c36a3` self-test cat-riddle hint, `0bcc68235` restart_count
infinite-loop fix, `907ec1540` usage credential freshness check,
`bc81c9d82` model-sweep state machine (pause/resume/cancel + circuit
breaker), `5c4a238c7` usage refresh-decision diagnostics, `e9f78a211`
kimi model-alias rename (bare `k3` now means `k3-256k`, old target is
`k3-1m`), `a0c817ab6` sweep-aware crash-restart ceiling +
restart_count model-change reset, `aefe15e08` model-sweep
task-priority coordination (`ensure_model_pinned` defers, sweep
`yielding` state), `bdbe66706` proactive credential-refresh watchdog.
See `git log` for exact order/hashes, this list is for topic recall
not a substitute for it.

**UPDATE 2026-09-17 (later session): root cause FOUND**, see
[[bug-coding-cpu-binary-abi-skew-root-cause-2026-09-17]] — not a model
file or thread-config issue at all. `llama-server-cpu` is a
609-commit-stale executable (built 2026-03-09) dynamically linked
against `libllama.so`/`libggml.so` that got rebuilt 2026-09-08 for the
GPU target only — an ABI skew, segfaulting on essentially every model.
The `-tb 8` / `n_threads_batch=-1` theory below was tested and
falsified (healthy servers log the same value). Fix is a clean
`build-cpu` rebuild + relink, not yet done. Original open note kept
below for the discriminating-test record:

the actual CPU inference binary
(`llama-server-cpu`, `ik_llama.cpp`) segfaults on spawn for the large
majority of models tested — confirmed via running the binary directly,
bypassing the zenka entirely, same result. Root cause still unknown.
Two discriminating tests identified but not yet run:
`llama-server-cuda-fa -ngl 0` on a known-crashed candidate (loads →
confirms it's specifically the cpu build, not the model files); a
direct retry with `-tb 8` (the binary's own startup line logs
`n_threads_batch=-1`, a live smell for an allocation against a
sentinel). Recompiling `ik_llama.cpp` is explicitly not off the table
per `coding-cpu-and-hybrid-offload-path.md`.

**GPU-crash candidates saved for review**: 19 checksums that crashed on
the *gpu* backend too (not just cpu) — these are NOT explained by the
cpu-binary theory (different binary, `llama-server-cuda-fa`), so
they're the actually-credible checksum-verification/deletion
candidates, unlike the ~89 cpu-only crashes which are pure infra noise.
List saved outside the repo at
`/data/backup/session-state/gpu-crash-candidates-2026-09-17.txt`
(19 lines, checksum + backend + detail). Also backed up at the same
path: full `model-status` text dump, and copies of the live
`state/model_sweep_cursor.yaml` / `state/model_status.yaml`.

**Sweep state, live, as of session end**: `coding.model-sweep-status`
shows `cpu : paused [ circuit-breaker : 3x crash_before_ready exit=11 ]
: idx=3/90 filter=re-test-failed`. Cursor is intact and resumable
(`model-sweep-resume cpu :force:`) once the cpu-binary root cause is
actually fixed — resuming it before that will just re-trip the breaker
on the same still-broken binary, no new information.

**Both AI budgets were tight at session end**: Claude ~34%/7d,
~59-90%/5h across the session (climbed through the session); Kimi
~23%/7d, ~90%/5h. Not a blocker, just context for pacing the next
session's dispatch decisions -- prefer `k3-256k`-tier (now the `k3`
default) over `k3-1m` unless genuinely needed, per the alias rename
landed this session.

**Design docs landed** (both went through an Opus review pass before
implementation, both caught real bugs in first drafts):
`data/tasks/coding-test-iteration-state-machine.md`,
`data/tasks/coding-sweep-task-priority-coordination.md`. Both fully
implemented and committed, not open work.

#,,,,,,..,...,.,.,,,,,.,,..,.,,,,.,,.,,,.,.,.,,,,,..,,...,...,.,,,,,.,.,.,.,,,

#,,.,,...,.,,,,..,.,.,,,,,,.,,,.,,,.,,,.,,,.,,..,,...,..,,...,,.,,..,,,,.,,.,,
#5D2JNXQLPC2XY55C77QQCA6ZURRILTAJ622DKF3XC5RRF54H444RCVXRQ26PK44QOB24NN67SJVSI
#\\\|LQ7BOUMQLL2LNYCMJFES3GGKGHOHF5GU2H7W3DC5O2NL54HHY5Z \ / AMOS7 \ YOURUM ::
#\[7]HGUYHPGEK4THGTPF4ABQCAAEXJREXKYUJO5FS6DKECCHI56BAADI 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
