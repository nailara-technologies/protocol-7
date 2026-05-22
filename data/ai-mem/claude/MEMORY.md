# Protocol-7 Development Memory

## CRITICAL — load when writing code
- [Critical Patterns](critical-patterns.md) — P7 module patterns, CRITICAL syntax, API rules; load this first for any code work

## File Creation (CRITICAL)
- **Never add** the `#,,.,,,...` stub at end of new files — blocks signing system
- Leave new files clean; `bin/Protocol-7 sourcecode update-signatures` adds real 4-line footer

## Architecture Docs (session 42)
- `data/md/design/NESTED-CUBE-NETWORK-SEGMENTATION.md` — gateway satellite, departure-route source chain, tunneling
- `data/md/design/ZENKA-LIFECYCLE-ONDEMAND-HEARTBEAT.md` — hybrid on-demand+heartbeat, WoL chains, timeout recovery
- `data/md/design/SIGNED-COMMAND-INTERFACE.md` — command footer signatures, TOFU, generate-on-first-use
- `data/md/design/AUTHORIZATION-BUFFER.md` — ntime-first approval queue, remembered decisions, TOFU/cmd/route flows
- `data/md/design/LIVING-BACKGROUND-SYSTEM.md` — consensus background render, 5/7 vote, povray layer, desktop elements
- `data/md/design/VISUAL-INPUT-PIPELINE-AND-LIVING-TEMPLATES.md` — best-5 tournament, monotonic quality floor, T2I+ControlNet

## Architecture Docs (session 40)
- `data/md/development/LLM-SESSION-MANAGEMENT.md` — session segments, distill/compact/resume, browser remote models, cross-model sharing
- `data/md/development/P7-NATIVE-WEB.md` — proxy intercept, site-yaml extraction, llm reframe, adapter-candidates.yaml roadmap, convergence stages
- `data/md/development/PARALLEL-REASONING-ORCHESTRATION.md` — task tree DAG, stuck detection, rescue branches, reasoning.branch.* generics, bin/chat --task-branch

## Architecture Docs (session 37)
- `data/md/development/CHILD-PROCESS-LIFECYCLE-POLICY.md` — disposable/decoupled/monitored child categories; kill_list review; v7 coordination
- `data/md/development/X11-RELIABILITY-AND-WINDOW-REGISTRY.md` — reconnect backoff, wrapper process, window registry+STRM, wait_visible replacement
- `data/md/development/WEB-BROWSER-WEBKIT2-UPGRADE-ANALYSIS.md` — full WebKit2GTK 4.1 upgrade analysis, 8 task descriptions
- `data/md/development/P7-LLM-REFERENCE.md` — verified live command reference for kimi/LLM sessions
- `data/md/development/DEGRADED-FEATURES-AUDIT.md` — 5 high-priority + 3 medium candidates with stub task files

## Session 45
- [base32-namespace](topic-base32-namespace.md) — base32.* namespace live; dep-graph swap parser fix; self-healing whitelist concept + blocked-on-signing note

## Space Engine modules (session 43/44)
- `space.*` 29 modules: grid/orbit/route/travel/jump/search/register/template — all ptd-clean
- `branch.space.*` 6: rank, shell, visible, magnetic_force, effective_position, balance
- `branch.clock.*` 4: allocate, sequence, position, bandwidth
- `branch.ntime.*` 3: relative, clock_sync, tunnel_duration
- `base.callback.cmd_reply` — DATA + TREE reply modes added
- fixes: `<space.X.Y>->` tree syntax (was flat keys); removed all `exists $code{}` guards; long lines wrapped

## Space Engine (session 43)
- [SPACE-ENGINE-MASTER.md](../../../data/projects/protocol-7/data/md/design/SPACE-ENGINE-MASTER.md) — 12 sub-namespaces: grid/orbit/route/travel/jump/search/register/select/filter/render/export+import/template; internal reference capable; aura profiles; harmonic frame expansion

## ncode workflow note (session 44)
- for patterns with hash braces `{` `}`: mask with dots — `data..space.X.Y...` matches `$data{'space.X.Y'}{`
- `ncode -ai-friendly -confirm replace src "data..space.X.Y..." "<space.X.Y>->"` — bulk tree-syntax fix

## amos-matrix tool (session 43)
- `bin/amos-matrix` — render AMOS checksums as 5×7 dot matrices; 7 chars × 5 bits = 35 bits = one matrix; default horizontal+flipped (handwriting); -V -flip-h -flip-v -inv flags; xargs+ANSI clean

## 1001 — Ring Tightener (session 43)
- [topic-1001](topic-1001.md) — inter-cube tunnel (00=2 bits invariant); gate nesting; two 13s (divisor/multiplier); eternal loop; seamless space; implicit transport as emergent topology; relative ntime

## Spawnable Perspective Layers / Desktop (session 43)
- [topic-perspective-layers](topic-perspective-layers.md) — desktop=data space+UI intent; perspective tree; bandwidth reduction; nested resolution=derivation route; no layout engine

## Observer-Centric Reference Space (session 43)
- [topic-observer-centric-space](topic-observer-centric-space.md) — client always 0; signed -n/2..0..+n/2; reference-count gravity; buffer swap navigation; EM field outer transport; dedup = convergence to center; routing = magnitude gradient

## Routing Crystal (session 43)
- [topic-routing-crystal](topic-routing-crystal.md) — cube node group as crystal; harmonic memory = route cache; inference = 5-beam convergence; face-000 = reflection surface; total internal reflection = security boundary

## Checksum Tree Wire Format (session 43)
- [topic-checksum-tree-wire](topic-checksum-tree-wire.md) — 1[zeros]1 bit-length separators; 01/10 direction-of-travel encoding; 11 pivot/LCA; type-free; append-only; connects stream-framing + DATA + reference bubble

## TREE Protocol (session 43)
- [topic-tree-protocol](topic-tree-protocol.md) — structural control layer parallel to DATA; node metadata+REF pointers; bi-directional; namespace registry for all DATA streams; dump-keys:dump :: TREE:DATA

## DATA Protocol + Sync (session 43)
- [topic-data-protocol](topic-data-protocol.md) — DATA reply mode (base32/line/stream); DELTA transparent sync; branch node file access; to add to base.callback.cmd_reply

## Reference Bubble / Dancing Zenki (session 43)
- [topic-reference-bubble](topic-reference-bubble.md) — rhizome state as generic bubble; 5+2=7 formation; checksum tree wire format; 01/10 direction encoding; universal across all layers

## Branch Namespace (session 43)
- [topic-branch-namespace](topic-branch-namespace.md) — unifying addressable layer; layer 1 DONE (10 modules); 7 task files for parallel kimi dispatch

## Active Topics
- [plugin-web-jobs](topic-plugin-web-jobs.md) — delta sync WORKING (session 34): ntime persisted, chunked push, last_modified stamps; open: ?since=N browser delta, remote deploy
- [clients-http](topic-clients-http.md) — clients.http.* + clients.https.* async namespaces; kimi-web parallel dispatch fixed; see completed session 33
- [reasoning-chain-repository](topic-reasoning-chain-repository.md) — planned for native model; dedup-based self-improvement; small model naive insight + large model validation = ground truth
- [reasoning-namespace](topic-reasoning-namespace.md) — `reasoning.*` namespace (harmonically TRUE); 21 templates: 1-9 vortex set, 10-14 materialization/NI/alignment/routing/omega-gate, 15-16 living-commitment/introspection, 17-20 implosion/freed-model/arrived-by-being/semantic-triangle, 21 physics-as-calculator
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
- [self-assembling-network](topic-self-assembling-network.md) — spec repository as pre-loaded potential (layer 5/6); zenki self-implement on idle or urgent need
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
- [git-watch-zenka](topic-git-watch-zenka.md) — force-push detection → pre-fetch snapshot; git alternates chain dedup; task: data/tasks/git-watch-zenka.md
- [reasoning-design-templates](topic-reasoning-design-templates.md) — 7 viz designs in data/yaml/design-templates/; kimi task dispatched → reasoning-design-inspiration.html
- [fetch-files-zenka](topic-fetch-files-zenka.md) — fetch-files FULLY LIVE [:<; huggingface.* namespace; hf-{download,list,search,lan-check,status}; v7 reload bug: new on-demand zenki need full v7 restart
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
- [ncode-tools](feedback-ncode-tools.md) — use ncode replace/parse-headers for namespace renames; not sed/perl -i loops
- **httpd architecture**: httpd is a thin proxy — never load plugin.web.* in httpd. all cross-zenka data goes through web zenka via route-send SIZE. blocking reply-wait in httpd crashes sessions.
- **P7 cross-zenka data**: use route-send + SIZE reply handler pattern (like radio relay). file system access between zenki is forbidden by design (different users). SHM or route-send for cross-zenka data.
- **ntime comparison**: `encode_b32r` is reverse-byte-order — NOT lexicographically sortable. Never use `gt`/`lt` string comparison on ntime B32 values. Always use `<[base.ntime_BASE32_to_numerical]>` for numerical comparison.
- **repeating timers**: need after + interval + repeat:TRUE (not just repeat with a value)
- **P7 access control is two-layer**: cube/access.zenki is the REAL routing gate. zenka start `access.cmd.usr.cube = *` is a second check but behind cube's gate — any zenka not listed in cube/access.zenki is already blocked before reaching it. adding lines to v7/start won't restrict what cube already allows through.
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
- **Glitter 4B restart**: after a failed tool-using task, Glitter backend needs restart before `:no_tools:` tasks work — model gets stuck in tool-mode from prior failed session

## New Tools / Zenki (session 37)
- `bin/todo` — self-contained todo CLI; project-local `data/yaml/todo/default.yaml`; add/done/rm/edit/tag/untag/clear; priority -h/-l; ASCII-framed TTY output
- `ncode doc` — unified doc lookup in bin/ncode + ncode.cmd.doc; delegates GObject to dump-class subprocess
- `smtpd` zenka — receive mail → YAML + LLM classify → route; xz+twofish archive; bin/p7-mail-inject bridge
- `window.*` namespace — generic proportional window placement for GTK zenki; 8 profiles; ticker integrated

## System State
- [next-steps](topic-next-steps.md) — full task queue, roadmap, open bugs, dispatched tasks
- [topic-completed](topic-completed.md) — all session summaries (Feb 2026 → present)
- **letsencr**: self-healing renewal CONFIRMED WORKING (session 41) — v7.ax + visual.v7.ax rate limit clears ~15:30 UTC 2026-05-22
- **reasoning.branch.***: LIVE (session 41) — 9 modules, task zenka hooked, ASCII tree viz via p7c reasoning.branch.status
- **base.cmd.list**: :n: row limit working (prefix/suffix/zero-padded), header-aware
- **pager.sort.multi-key**: ntime_b32 + priority_map sort types added (session 42)
- **task dispatch sections**: all dispatched tasks now carry ## dispatch + prompt for reuse

#,,..,..,,...,,,,,,..,...,.,.,..,,,,,,,.,,...,..,,...,...,,..,..,,,..,..,,,.,,
#SMIXRK6IZU2FRM4FSKPTEBJYGRDHHPP5K7MRBVX4WQFKBVDG6CNCRR72ROKRRFAW3ZGHLUANKOU7M
#\\\|AJXCA3M2SE32UAZC6HJ32SEJB3NGKFDJ2TZG5KDMFXBVOA3GYZZ \ / AMOS7 \ YOURUM ::
#\[7]NODTISZ6P6MFDQWVBCOIYVLQDQ7TAANGMP6IA7VTEOECS7OEYYCI 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
