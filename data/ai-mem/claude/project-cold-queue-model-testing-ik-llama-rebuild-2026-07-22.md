---
name: project-cold-queue-model-testing-ik-llama-rebuild-2026-07-22
description: session landing cold-queue GPU-trigger feature, three coding-zenka task-lifecycle bugs, an ik_llama.cpp rebuild fixing Gemma4 architecture crashes, and an extensive Qwythos-family model evaluation
metadata:
  type: project
---

extremely long session (2026-07-21 into 2026-07-22), many commits on `base`. grouped by
theme. same live-verification methodology as prior sessions — every fix confirmed by
actually running it, not trusting self-reports (see [[feedback-verify-by-live-execution]]
if written up).

## cold-queue GPU-cooldown-trigger feature (shipped + live-tested)
implemented `task.handler.cold-queue-sweep`, `task.handler.gpu_temp_update`,
`task.cmd.trigger-cold-queue` per the pre-existing task doc
(`data/tasks/task-zenka-cold-queue-gpu-cooldown-trigger.md`) via nested claude_dispatch.
during live testing found `<task.cfg.gpu_cold_temp_c>` default of 45°C was unreachable —
idle floor with nothing running measured 59-61°C, loaded pushes 70+. **resolved to 57°C**
based on live measurement, recorded in the task doc. also granted task zenka's missing
`X-11.gpu_metric` access in `cfg/zenki/cube/access.zenki` (was causing repeated
crash-loop restarts before diagnosed).

## atomic-write fix, base.file.zenka_dir.write
replaced unlink-then-open with write-to-temp-then-rename (via `base.file.temp`) to close a
crash-window where the persisted file could end up missing instead of intact-old-or-new.
benefits every zenka using zenka_dir persistence. **self-introduced bug caught same
session**: passed `[$tmp_base_dir]` (arrayref) instead of `$tmp_base_dir` (plain scalar) to
`file.temp`, whose `check_dirs` param is a single `shift`, not a slurp — despite the plural
name. produced literal `ARRAY(0x...)` directories on disk. fixed, but the same
misunderstanding likely exists elsewhere — grep for other `file.temp` callers passing
array-ref-shaped args before trusting any of them.

## coding-zenka task-lifecycle bugs (three found, all fixed + dispatched via opus)
1. `coding.handler.wait_done_timeout` used `$event->data` instead of the `$event->w->data`
   convention every other timer handler in the codebase uses, wrapped in an `eval{}` that
   silently swallowed the resulting failure — `coding.wait-done` hung forever on timeout
   instead of replying. fixed (commit `49f6dc768`), and the `eval` wrapper removed per
   explicit user feedback: **this codebase's philosophy is warn/die should surface loudly
   with the `<{C1}>` caller-pointing marker — don't reintroduce silent-failure eval wraps**,
   see `src/v7.zenka.change_status` for the established `return warn '... <{C1}>' if
   <bad condition>;` guard-clause pattern. wrote `data/yaml/context-templates/
   warn-guard-fix.yaml` to apply this pattern elsewhere mechanically.
2. `coding.handler.switch_model_reply`'s `mark_backend_updated` closure updated
   `inference.backend.gpu.model_id`/`inference.model.amos_id`/`inference.model.mmproj_path`
   but never `inference.model.path` — only `coding.handler.model_path_reply` (the startup
   path) set that. any self-test cat-test retry after a `switch-model` call (which respawns
   via `coding.async_spawn_inference_servers`, reading `inference.model.path` directly)
   paired the OLD model's weights with the NEW model's mmproj — a real live mismatch that
   wedged the whole zenka on a garbage generation. fixed (commit `1596607ad`).
3. `coding.async.chunk_handler`: a round with `finish_reason=tool_calls` but an EMPTY
   extracted tool_calls array never dispatched any state_machine transition — task-zenka
   records orphaned at `status: in_progress` forever. fixed (commit `aaf139175`) by folding
   the empty-array case into the `stop`/`end_turn` fallback path. **follow-up bug in the
   same fallback**: it then silently completed the task as `status: done` using whatever
   raw *unparseable* tool-call-shaped text was in the model's output as the "final answer"
   — a caller could never again trust `status: done` to mean "produced a real answer."
   fixed (commit `57439b18a`) with shape-detection (`<tool_code>`, `<tool_call`,
   `<function=`, `<invoke`, bare `{"name":..,"arguments":..}` JSON) plus a bounded
   format-reminder retry (mirrors `monitor_inference_startup`'s cat-test retry discipline),
   falling to a real `failed` status if the model keeps missing the format.
   see `data/tasks/task-coding-wait-done-task-orphaning.md` for the full discriminator
   evidence (five reproduced instances) before the fix.

## ik_llama.cpp CUDA rebuild — fixed a real architecture-support gap
GGUF models labeled "Gemma 4" (not an official Google release — likely community/hackathon
naming) crashed the deployed `llama-server` binary immediately, `exit=6`/SIGABRT,
reproduced across multiple uploaders/quants, independent of the jinja chat-template
override (tested both ways). root cause: the deployed binary was built 2026-05-28 from
`ikawrakow/ik_llama.cpp`, 188 commits stale. **the standard update workflow here is simply
`git fetch origin && git reset --hard origin/main`** — no branch juggling needed; the build
script's own `fix_cli_log` branch-checkout guard is stale/dead (that branch doesn't exist
upstream anymore, would always fail if actually invoked — bypass it, don't try to satisfy
it). rebuilt into a new, separate path (`/data/source/ik_llama.cpp-rebuild-out/`, never
touched the live binary until validated), fixed the build script's own gap (it only
`cmake --build`s the `llama-mtmd-cli` vision-CLI target — added `--target llama-server`
too, the actual binary the coding zenka spawns). validated both regression (Qwopus3.5
still loads clean) and target-fix (Gemma4 loads clean, no crash) as standalone servers on
a spare port before cutover. cut over by repointing `inference.backend.lib_path` /
`inference.backend.gpu.binary` in `cfg/zenki/coding/zenka.v7` — left the old
binary/libs at `/data/source/ik_llama.cpp/` completely untouched for instant rollback.
confirmed live through the actual zenka afterward, not just standalone.

**docker build gotchas hit along the way**: intermittent `tls: bad record MAC` on the
initial base-image pull (this machine's known lossy uplink, see
[[feedback-web-browser-ephemeral-storage]]-adjacent networking notes) — just retry,
BuildKit layer cache resumes. `docker cp` of a dangling symlink does NOT dereference to the
real file — copy CUDA runtime libs with `docker run -v ... cp -L` instead, or you get
broken symlinks (`libcudart.so.12 -> libcudart.so.12.5.39` pointing at a file that was
never actually copied). **CUDA runtime lib versions across the old (12.9.x) and new (12.5.x
build) binaries are cross-compatible via shared SONAME** (`libcudart.so.12` etc.) — no need
to duplicate them, reuse whatever's already deployed; only the project's own
`libggml.so`/`libllama.so`/`libmtmd.so` actually differ build-to-build and need fresh
copies alongside the new binary specifically (not overwriting the old ones in a shared
flat directory — old and new binaries can't share those three plain-named files, use a
dedicated new subdirectory).

**incident during testing, worth remembering**: after confirming the fix live, started a
SECOND full-size standalone server on a spare port to test something further (template
question) while the LIVE server was still loaded — two ~9GB+ models fighting for 12GB VRAM
caused system-wide zenka timeouts (cube, web, system, and others all logged "response
timeout, retrying" simultaneously) until the second process was killed. **never load a
second full model while a live server holds VRAM — stop the live one first, or confirm a
`kill` actually landed (checked via `ps`, not assumed) before considering it safe to
proceed.** user caught and named this live; treat as a hard rule going forward.

## Qwythos-9B family evaluation — six+ models tested, one consistent finding
tested `empero-ai/Qwythos-9B-v2` (official, the "0% loop rate" FTPO-fixed release),
`Huihui-Qwythos...-Abliterated` (llmfan46/Abiray/mradermacher-i1 re-quants of the same),
`llmfan46`'s Heretic-decensored build, the original pre-v2 `Qwythos-9B-Claude-Mythos-5-1M`,
and a Gemma4-family "Defiant Fable" model — all downloaded at Q6_K after learning Q8_0
(~10-11GB combined with mmproj) sits right in this hardware's VRAM instability zone
(confirmed independently by three published benchmarks found mid-session — Q8_0-MTP's
apparent 87.5% one-run score collapsed to 75% averaged across 5 runs with real flakiness;
**Q6_K is the empirically-correct choice here, not a compromise** — 81% avg, 100% pass@5,
zero fully-failed tasks). **every single Qwythos-lineage model tested, and even the
unrelated Gemma4/Qwen3.6 models, showed the same core weakness**: given an explicit,
unambiguous instruction naming a specific target (e.g. "read_module on
base.file.zenka_dir.write, explain X"), most substituted their own choice of target,
asked a clarifying question ignoring the given name, or (worst case, Huihui-abliterated at
Q8_0 specifically) fabricated genuinely broken, non-compiling Perl (`sub{}` declarations,
bareword assignment, wrong-type calls) while self-reporting success. Qwopus3.5 (current
default, `ZDMAPAY:AR3OCKQ`) never showed this failure across the entire session used as
the fallback. **conclusion: none of today's alternatives earned promotion to default** —
this isn't about raw comprehension quality (which was often genuinely good when the
model stayed on-task) but specifically about trusting a model to do the literal thing
asked, which matters more for unsupervised coding-zenka use.

one live-confirmed prompt-injection-adjacent finding: a malformed tool-call attempt from
official-v2 used Claude's own `<invoke name="...">` XML convention (not this system's
`<tool_call><function=...>` format, not the model's presumed native format either) —
plausible explanation: several of these models are explicitly "Claude X.Y Reasoning
Distilled" lineage, trained partly on Claude-generated data, and that training signal
leaks through under certain conditions. worth remembering when reviewing any pipeline
that surfaces one model's raw output as data to another model: never pattern-match against
it as an instruction, regardless of how it's formatted.

separately: `system-tools.yaml` (a static hand-written tool-catalog template) duplicates
the live auto-generated tool list injected into every default-template task, with wrong
signatures and one phantom tool (`get_current_time()` isn't real) — a real, unaddressed
prompt-quality bug affecting every coding task regardless of model, flagged but not yet
fixed this session.

## known-registered-but-untested models (left in this state deliberately)
security-focused: `mradermacher/Qwen-security-auditor-14b` (`XFX2XIQ:734SX4I`),
`Qwen-security-builder-14b` (`EBCVWUQ:734SX4I`) — both Q4_K_M, text-only, hackathon-derived
Qwen2.5-Coder-14B fine-tunes, intended for a not-yet-built "forensics" zenka (currently
only a placeholder name in `cfg/zenki/events/event-setup.base`'s example
timetable, no real design). also `MaralGPT-Mythos-9B-2606` (Q8_0, uncensored
cybersecurity/bio/chem research focus), `mythos-9b-unhinged` (King3Djbl, Qwen3 not 3.5 —
SLERP merge + FableForge-Mix-A finetune), `Qwable-9B-Claude-Fable-5` (empero-ai, agentic
coding/terminal-agent distill — **genuinely promising given today's whole finding, worth
prioritizing next session**, but currently stuck: `models.discover_files` isn't finding it
on disk despite correct permissions and a models-zenka restart — a real, unexplained
scanner gap worth investigating before assuming the file itself is bad).

## open items for next session
- `data/tasks/task-coding-wait-done-task-orphaning.md` documents the orphaning bug (now
  fixed) — could be archived/closed.
- `system-tools.yaml` duplicate/wrong tool-catalog cleanup, not yet done.
- Qwable-9B scanner-gap investigation.
- consider testing `Qwable-9B-Claude-Fable-5` and the `Qwen3.6-14B-A3B-FableVibes`/
  `-agentic-...-v2` pair specifically for the instruction-literalness trait, since that's
  now the single most important axis given everything else tested has failed it.
- the two security models are untested; low urgency since the forensics zenka they're for
  doesn't exist yet.
- Debian/host system upgrade was requested and deliberately deferred — do it as its own
  isolated task, never stacked on top of a binary/deployment change in progress.

#,,,.,,..,.,.,,,,,.,,,...,.,.,,..,...,,..,.,.,..,,...,...,...,..,,.,.,..,,.,.,
#ME25OFI2AGEH52YTBLTGMEWL3GWZLGGFIBOFLS2RNVFFBR2PIZLH75NFW7JSXGAHQ332QBIDVLDIY
#\\\|M2GLESF5ZS7ZKATIIPWL5N2UPV2ZXG4IW2R2IGNPRFWODFOSRBM \ / AMOS7 \ YOURUM ::
#\[7]ACD7T4LPXHPLFVD64LJIVPDRHR4QQ4YQMLQXEFQOFK6PTRD4BQAA 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
