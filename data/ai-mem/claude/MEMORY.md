# Protocol-7 Development Memory

## CRITICAL — load when writing code
- [Critical Patterns](critical-patterns.md) — P7 module patterns, CRITICAL syntax, API rules; load this first for any code work

## File Creation (CRITICAL)
- **Never add** the `#,,.,,,...` stub at end of new files — blocks signing system
- Leave new files clean; `bin/Protocol-7 sourcecode update-signatures` adds real 4-line footer

## Active Topics
- [plugin-web-jobs](topic-plugin-web-jobs.md) — WORKING (session 25): route registry, direct file reads, client delta sync, toolbar UI; open: server-side ?since=N, remote deploy, distributed push/cache
- [job-pipeline](topic-job-pipeline.md) — WORKING (session 22): jobs.vhost live, German reason+summary, retry on timeout
- [task-coordination](topic-task-coordination.md) — task zenka as coordinator; current state, dispatch flow, roadmap
- [coding-state-machine](topic-coding-state-machine.md) — coding.state namespace, watcher-based backend lock, persist/restore lifecycle
- [kimi-zenka-state-machine](topic-kimi-zenka-state-machine.md) — COMPLETE (session 23); open: flush_on_acquisition extraction, approval warning
- [chat-script](topic-chat-script.md) — bin/chat COMPLETE (session 23); open: kimi state machine, coding zenka dispatch, phase 2 channels zenka
- [stream-transport-layer](topic-stream-transport-layer.md) — STRM stack complete; open: formal open-0 sentinel, transport.register, webcam/log-tail
- [radio-relay-zenka](topic-radio-relay-zenka.md) — radio COMPLETE; phase 5 (buffer-fill curve) next
- [vhost-install](topic-vhost-install.md) — space.v7.ax live; open items remain
- [cursor-model](topic-cursor-model.md) — true cursor from hyperspace plane density; next: remove wireframe cube, queue glow task

## Vision / Design Topics
- [project-vision-origin](project-vision-origin.md) — 24-year foundational vision, threshold reached Apr 2026
- [self-improving-system](topic-self-improving-system.md) — LLM coordination as P7 self-improvement foundation
- [network-as-computer](topic-network-as-computer.md) — network IS the computer; Base32/15-bit/32-bit closure, holographic console, liquid crystal mainboard
- [namespace-tree-intelligence](topic-namespace-tree-intelligence.md) — the tree IS the intelligence
- [orbital-data-space](topic-orbital-data-space.md) — zenki-as-satellites, orbital field theory, ring routing
- [distributed-consensus](topic-distributed-consensus.md) — channels zenka, multi-model group chat, distributed P7 nodes
- [task-tree-design](topic-task-tree-design.md) — unified task/subtask tree: multi-parent groups, passive/active deps
- [self-contained-zenka](topic-self-contained-zenka.md) — __DATA__ registry, file.* abstraction, STDIO transport, roaming zenki
- [harmonic-mathematics](topic-harmonic-mathematics.md) — generator 076923, quadratic residues, cube geometry, CCW matrix routing
- [hyperspace-topology](topic-hyperspace-topology.md) — closed observer loop, sensor cube 3D grid; doc at data/md/development/HYPERSPACE-TOPOLOGY.md
- [punctuation-topology](topic-punctuation-topology.md) — `:` as group boundary, `.` as element separator; doc at data/md/development/PUNCTUATION-TOPOLOGY.md
- [field-coherence-synthesis](topic-field-coherence-synthesis.md) — bridges all topology docs
- [creative-field-behaviour](topic-creative-field-behaviour.md) — emergent cooperative field dynamics, purring field, zenki as entropy subsystem
- [addressing-trinity](topic-addressing-trinity.md) — named tree + checksums + timestamps as orthogonal trinity
- [checksum-addressing](topic-checksum-addressing.md) — AMOS checksums as universal routing primitive
- [node-group-geometry](topic-node-group-geometry.md) — exact geometry: 8×(4×4×4-1=63) cubes, void derivation
- [style-philosophy](style-philosophy.md) — coding as artform, style-as-function; give to LLMs before structural work

## Reference Topics
- [patterns](topic-patterns.md) — event handler, fork-child, standalone zenka, pipe-open, inference server
- [coding-zenka-templates](topic-coding-zenka-templates.md) — 50+ context templates, 16+ tools, autonomous loops
- [tool-shm-architecture](topic-tool-shm-architecture.md) — LLM tool calling, dispatch loop, SHM+mmap file editing vision
- [tool-suggestions](topic-tool-suggestions.md) — LLM-suggested tools/improvements, prioritized
- [language-detection](topic-language-detection.md) — three-layer detection, encoding_map 30 langs, locale vision pipeline
- [site-yaml-zenka](topic-site-yaml-zenka.md) — on-demand zenka: URL → structured YAML, domain regex templates
- [site-yaml-web-research](topic-site-yaml-web-research.md) — safe coding zenka web research, checksum-as-capability tokens
- [usb-backup-zenka](topic-usb-backup-zenka.md) — udev insertion → task tree → manifest restore agent
- [tls-acme](topic-tls-acme.md) — SNI/SSL internals, ACME/letsencr details, cert discovery
- [amos7-p7-loader](topic-amos7-p7-loader.md) — AMOS7::P7 makes <[...]> modules callable from standalone scripts
- [invoke-model-management](topic-invoke-model-management.md) — uuid vs verbose paths, config.json, :raw binary writes
- [invoke-model-manager](topic-invoke-model-manager.md) — planned Term::Clui manager: safe delete, archive/restore
- [image-archive-system](topic-image-archive-system.md) — vision-scored tiered storage, pngquant tiers, 63GB+ savings
- [base-curve-system](topic-base-curve-system.md) — generic base.curve.* parameter animation, composable signal chain
- [friction-visualization](topic-friction-visualization.md) — friction as flow turbulence, harmony as coherence artifact
- [searchable-index-and-visualization](topic-searchable-index-and-visualization.md) — checksum-indexed dataspace, space.v7.ax
- [migration](topic-migration.md) — Windows 11 host instability, KVM/Debian migration priority, avoid /tmp/

## Feedback (behavior rules — always apply)
- [watcher-state-machines](feedback-watcher-state-machines.md) — IO::Async variable watchers only; never polling timers for state
- [kimi-code-review](feedback-kimi-code-review.md) — common kimi P7 code issues: SUPER::, namespace swaps, fake signatures
- [kimi-signatures](feedback-kimi-signatures.md) — kimi derails into signature investigation; add signatures_note to every task file
- [kimi-dispatch-pattern](feedback-kimi-dispatch-pattern.md) — bin/kimi-task is token-efficient; write detailed task files
- [model-precision-analysis](feedback-model-precision-analysis.md) — Qwopus more precise; sushi coder hallucinates LWP as async
- [coding-zenka-edits](feedback-coding-zenka-edits.md) — local LLM describes edits instead of applying; verify results
- [coding-zenka-reasoning](feedback-coding-zenka-reasoning.md) — low reasoning → premature task_complete; use medium for discovery+impl
- [coding-zenka-inject](feedback-coding-zenka-inject.md) — `p7c coding.inject-message <id> <msg>` to redirect stuck model
- [arg-regression](feedback-arg-regression.md) — local LLM reverts $ARG→$_ after compaction; verify all edits
- [web-serialization-and-inlining](feedback-web-serialization-and-inlining.md) — parallel JSON+YAML endpoints, inline CSS/JS
- [task-show-multiline](feedback-task-show-multiline.md) — task.show must escape \\n; line parsers only see first line
- [list-return-format](feedback-list-return-format.md) — list backends: `{ mode => 'size', data => $formatted_string }`
- [stop-and-revert](feedback-stop-and-revert.md) — don't chain speculative fixes; stop, revert, confirm root cause first
- [utf8-module-literals](feedback-utf8-module-literals.md) — non-ASCII in module format strings corrupts output; keep format strings ASCII-only

## Completed Sessions
- [topic-completed](topic-completed.md) — all session summaries (Feb 2026 → present)

## System Status

### Next Steps (immediate)
- **first-run**: `p7c v7.restart cube` → write profile.txt → `p7c job-site-scan.scan`
- **profile.txt** at /var/protocol-7/jobs/profile.txt — CV/skills for LLM scoring
- **multi-page search** — stepstone 25/page; cfg.max_pages per category
- **orphan re-queue** — re-create tasks for jobs stuck in 'assessing' after restart
- note_read pagination (offset/limit on sections)
- active deps execution (requires list in task dispatcher)
- think-block stripping — `<think>...</think>` from Kimi/Deepseek leaks into output
- task.cmd.start — task zenka step 3

### Planned / Future
- **HTTP sync** — /api/jobs/sync httpd endpoint, C25519-signed YAML; see [job-pipeline](topic-job-pipeline.md)
- **USB backup zenka** — udev insertion → backup task tree; see [usb-backup-zenka](topic-usb-backup-zenka.md)
- **site-auth zenka** — session/auth for login-gated scrapers
- **job automation** — jobtracker integration (HTML/JS, CSV/PDF), email reply monitor (Gmail zenka)
- **base.handler.command refactor** — plan at `data/md/development/BASE-HANDLER-COMMAND-REFACTOR-PLAN.md`
- **SIZE packet loss bug** — STRM interaction stops zenka returning SIZE replies until unrelated cmd sent

### Active / Partial
- **namespace tree as intelligence layer** — see [namespace-tree-intelligence](topic-namespace-tree-intelligence.md)
- **task coordination architecture** — see [task-coordination](topic-task-coordination.md)
- **multi-model consensus** — llm.service.consensus_vote extracted but untested

### Open Bugs
- **config double-load bug** — duplicate config key warnings; see `bug-config-double-load.md`
- **signature oscillation Variant B** — double-footer on never-signed non-empty files
- **repo var/ cleanup** — `var/httpd/` tracked from Nov 2025 AI error
- **kimi auto-approval regression** (Apr 16) — some tool calls not auto-approved during kimi tasks

#,,.,,,..,,..,,,.,...,,,.,.,.,,..,,,.,,,.,...,..,,...,..,,,..,,.,,,..,..,,,.,,
#YWJJORE5JD5DC2UNBACM6R7TF64NL7CIQPASEXKX5GH4HM3GIQRLRVVCXRSZ7363ZA7PKDN6GDJ7O
#\\\|YTN4KEKZ7ZP2U7HFDMLBNYCPVRVJMBCU2MLSXLH3JEZP5YVGXTF \ / AMOS7 \ YOURUM ::
#\[7]Q4YS4PHDSGNLA726SXRVB6PBOU4R5W2WJNAIKZ777RC7TIJQG6DI 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
