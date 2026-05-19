# Protocol-7 Development Memory

## CRITICAL — load when writing code
- [Critical Patterns](critical-patterns.md) — P7 module patterns, CRITICAL syntax, API rules; load this first for any code work

## File Creation (CRITICAL)
- **Never add** the `#,,.,,,...` stub at end of new files — blocks signing system
- Leave new files clean; `bin/Protocol-7 sourcecode update-signatures` adds real 4-line footer

## Active Topics
- [plugin-web-jobs](topic-plugin-web-jobs.md) — delta sync WORKING (session 34): ntime persisted, chunked push, last_modified stamps; open: ?since=N browser delta, remote deploy
- [clients-http](topic-clients-http.md) — clients.http.* + clients.https.* async namespaces; kimi-web parallel dispatch fixed; see completed session 33
- [reasoning-chain-repository](topic-reasoning-chain-repository.md) — planned for native model; dedup-based self-improvement; small model naive insight + large model validation = ground truth
- [reasoning-namespace](topic-reasoning-namespace.md) — `reasoning.*` generic namespace (harmonically TRUE); summarizing node narration tree, threshold-triggered action, narrate+self-delegate pulse; task zenka first consumer
- [job-pipeline](topic-job-pipeline.md) — WORKING (session 22): jobs.vhost live, German reason+summary, retry on timeout
- [task-coordination](topic-task-coordination.md) — task zenka as coordinator; current state, dispatch flow, roadmap
- [coding-state-machine](topic-coding-state-machine.md) — coding.state namespace, watcher-based backend lock, persist/restore lifecycle
- [kimi-zenka-state-machine](topic-kimi-zenka-state-machine.md) — COMPLETE (session 23); open: flush_on_acquisition extraction, approval warning
- [chat-script](topic-chat-script.md) — bin/chat COMPLETE (session 23); open: kimi state machine, coding zenka dispatch, phase 2 channels zenka
- [stream-transport-layer](topic-stream-transport-layer.md) — STRM stack complete; open: formal open-0 sentinel, transport.register, webcam/log-tail
- [radio-relay-zenka](topic-radio-relay-zenka.md) — radio COMPLETE; phase 5 (buffer-fill curve) next
- [vhost-install](topic-vhost-install.md) — space.v7.ax live; open items remain
- [cursor-model](topic-cursor-model.md) — true cursor from hyperspace plane density; next: remove wireframe cube, queue glow task
- [iris-spoke-labels](topic-iris-spoke-labels.md) — 63-ring spoke sequence: A-Z · dot-fold · Z-A · 9-0 · BASE32/binary bottom; protocol=visual vision
- [stream-framing-protocol](topic-stream-framing-protocol.md) — 3+1 bit frame, separator inversion on 000, expanding assertion window, dot=0 comma=1
- [orbital-cycle-clock](topic-orbital-cycle-clock.md) — angle_bits as generic mapping canvas; velocity multipliers; network cycle clock; 45 compatible feature combinations
- [self-optimizing-code](topic-self-optimizing-code.md) — prior impl as spec+test generator+fallback; benchmark as reviewer; autonomous performance optimization paradigm
- [space-dimensions](topic-space-dimensions.md) — 5D coordinate geometry (arc×floor×plane×scale×timing), helix descent, separator cubes, seamless loops, ~10^14 address space
- [vortex-intake](topic-vortex-intake.md) — vortex mode as event horizon interpreter; spiral as color tube; correlated approximations; cube space transition masks
- [kitten-hologram-filter](topic-kitten-hologram-filter.md) — litter entropy as cryptographic resource filter; blue hologram at cube face event horizon

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
- [field-capability-emergence](topic-field-capability-emergence.md) — protocol vs external management; feature completeness + complementary behavior → native network capability
- [creative-field-behaviour](topic-creative-field-behaviour.md) — emergent cooperative field dynamics, purring field, zenki as entropy subsystem
- [addressing-trinity](topic-addressing-trinity.md) — named tree + checksums + timestamps as orthogonal trinity
- [checksum-addressing](topic-checksum-addressing.md) — AMOS checksums, BMW384 geometry, route.bmw384.* implementation
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
- **httpd architecture**: httpd is a thin proxy — never load plugin.web.* in httpd. all cross-zenka data goes through web zenka via route-send SIZE. blocking reply-wait in httpd crashes sessions.
- **P7 cross-zenka data**: use route-send + SIZE reply handler pattern (like radio relay). file system access between zenki is forbidden by design (different users). SHM or route-send for cross-zenka data.
- **ntime comparison**: `encode_b32r` is reverse-byte-order — NOT lexicographically sortable. Never use `gt`/`lt` string comparison on ntime B32 values. Always use `<[base.ntime_BASE32_to_numerical]>` for numerical comparison. Diagnose with `p7c localtime <ntime_b32>`.
- **repeating timers**: need after + interval + repeat:TRUE (not just repeat with a value)
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

**iris visualization** (dispatch to kimi one by one):
- **iris alpha-density v2**: data/tasks/iris-alpha-density-mode-v2.md — filter-safe, dispatch next
- **iris ring ledger**: data/tasks/iris-ring-ledger-mode.md — 3+1 octal counters, separator flash
- **iris route-commitment**: data/tasks/iris-route-commitment.md — future arcs bright/past dim
- **iris dimension-rotator**: data/tasks/iris-dimension-rotator.md — H/V view toggle
- **iris cascade-warning**: data/tasks/iris-cascade-warning.md — pre-flash amber warning
- **iris separator-pulse**: data/tasks/iris-separator-pulse.md — routing infrastructure visible
- **iris temporal**: data/tasks/iris-temporal-mode.md — radial=time, git blame as orbital map
- **iris boundary**: data/tasks/iris-boundary-mode.md — stained glass event horizons
- **iris negotiation-window**: data/tasks/iris-negotiation-window.md — floor budget urgency

**iris oscilloscope**: route-send SIZE relay to index — verify working after httpd+index+zulum restart

**infrastructure**:
- **:::: litter row**: data/tasks/litter-row-encoding.md — 15-bit zenka bitmap in footer
- **iris 63-ring labels**: DONE ✓ namespace63 mode with . at ring 27
- **iris logo overlay**: DONE ✓ nailara at darksun
- **plugin.web.* migration**: DONE ✓ web zenka owns all plugin.web.*
- **jobsite BMW384 dedup**: dispatch bmw384-arc-grouping-filter.md to kimi
- **route.bmw384 find-route testing**: register nodes, verify-coordinate

**roadmap topics** (see IMPLEMENTATION-ROADMAP.md):
- **sub-bit element definition**: data/tasks/sub-bit-element-definition.md
- **generic content layer**: 4b.6 improvement-directed history, git supersession path
- **flexible offset mapping**: 4.7 angle_bits as φ_offset + seed per ring
- **orbital velocity signatures**: 4.8 per-ring speed multipliers, TRUE/FALSE CCW/CW lanes
- **network cycle clock**: 4.9 logically mapping orbital timebase

**jobs pipeline**:
- **profile.txt**: /var/protocol-7/jobs/profile.txt — CV/skills for LLM scoring
- **multi-page search**: stepstone 25/page; cfg.max_pages per category
- **orphan re-queue**: re-create tasks stuck in 'assessing' after restart
- note_read pagination (offset/limit on sections)
- active deps execution (requires list in task dispatcher)
- think-block stripping — `<think>...</think>` from Kimi/Deepseek leaks into output
- task.cmd.start — task zenka step 3
- **model selection for assessment**: Glitter 4B good for scoring, but repair tasks
  may need heavier model — `preferred_model` param on task.create needed
- **site-yaml 403 backoff**: currently fixed at 10s; should scale with consecutive count
- **sync ?since=N browser delta**: browser JS still sends full fetch, server-side
  filtering not yet implemented (needs last_modified in index.yaml per entry)

**shm pipeline** (next major infra):
- task file: data/tasks/shm-streaming-payload-pipeline.md
- replaces chunked sync with single authenticated streaming POST
- ntime:bytes:lines:BMW384 header, C25519 sig, Twofish per-zenka encryption
- progressive validation gates — reject at cheapest gate first
- two-layer replay protection (time window + per-sender ntime watermark)
- dispatch to kimi when clients.http.* is proven stable

**model self-selection**:
- task file: data/tasks/coding-model-selection-template.md
- model selects backend via subtask dispatch with preferred_model + mandatory reason
- reason field as confusion filter AND forensics audit trail
- reason quality heuristics → eventually feeds benchmarking classifier

### BMW384 Iris — Future Directions
- **animated**: auto-refresh as modules are signed, live topology monitor
- **interactive**: click node → highlight color-radius neighbors, show routing candidates
- **route arcs**: find-route result drawn as arc across wheel, color-coded by resonance
- **namespace layers**: separate rings per namespace (base.*, kimi.*, jobsite.*) — layer boundaries visible
- **favicon/header**: 26-ring iris at thumbnail scale as live system-state favicon

### Planned / Future
- **SHM streaming pipeline** — see data/tasks/shm-streaming-payload-pipeline.md; replaces chunked sync with single auth POST; dispatch to kimi after clients.http.* stable
- **model self-selection** — see data/tasks/coding-model-selection-template.md; subtask-based routing with mandatory reason field
- **sourcecode normalize-endline-state** — see data/tasks/sourcecode-normalize-endline-paths.md; path normalization config + new command; dispatch to kimi
- **privacy credentials** — see data/md/design/PRIVACY-PRESERVING-IDENTITY-CREDENTIALS.md; signature-as-identity, no username/key stored, upgrade modes
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
- [signature endline restoration](bug-signature-endline-restoration.md) — stale encoded delta applied after edit changes last content line → concatenated footer; fix in restore_payload_endline_state sanity check
- **repo var/ cleanup** — `var/httpd/` tracked from Nov 2025 AI error
- **kimi auto-approval regression** (Apr 16) — some tool calls not auto-approved during kimi tasks

#,,,.,..,,...,,,.,..,,,,,,,..,,,,,,.,,,..,.,.,..,,...,...,.,.,..,,...,,,,,.,.,
#HS3JBAPJRZ6YEKAWHHA4Q76OO3OI44C5GQ3K3KFYXJXITQJHZTCVK4VBNKMD74JZ7HUHWGFNRIII6
#\\\|PXU27Z63Z3DK2ODVHMF6TPAIDFY2GX6446PK3FN6H2EXD45K67X \ / AMOS7 \ YOURUM ::
#\[7]M5RNWQEOB5463ZFNDONFSTNKAX3FWBPBRCT6STZ7UX7A3HUTP4CQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
