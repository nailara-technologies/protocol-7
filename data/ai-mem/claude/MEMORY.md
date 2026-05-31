# Protocol-7 Development Memory

## CRITICAL — load when writing code
- [Critical Patterns](critical-patterns.md) — P7 module patterns, CRITICAL syntax, API rules; load this first for any code work
- [Deferred Init Pattern](feedback-deferred-init.md) — push onto system.callbacks.initialized, NOT event.add_var, to defer post-verification work
- [Timer Module Args](feedback-timer-module-args.md) — timer-called modules get event object as $ARG[0]; use `@ARG > 1` not `@_ ? shift` for extra params

## File Creation (CRITICAL)
- **Never add** the `#,,.,,,...` stub at end of new files — blocks signing system
- Leave new files clean; `bin/Protocol-7 sourcecode update-signatures` adds real 4-line footer

## Recent Sessions
- [session-67](session-67.md) — jobsite dedup false positive fix; status-dir layout (kimi); checksum store rewrite to filesystem dirs; job.read utf8 fix; checksum expansion in progress
- [session-66](session-66.md) — delta sync /jobs.json (3 bugs); UI polish (title, buttons, hover, slider); sort NaN fix; inline sub extraction; double-plugin-load fix in base.cmd.reload
- [session-65](session-65.md) — data recovery: Mojibake fix committed; 312 garbage files deleted; backup restored; 127 files chmod 644; 294 repair_failed jobs reset; scan running
- [session-64](session-64.md) — encoding Mojibake ROOT CAUSE: utf8 flag on $body from route path; fix: utf8::decode in httpd.route.handler.web-relay; all 3 fixes committed (stage, %data key, encoding)
- [session-63](session-63.md) — STRM had_local_consumer fix WORKING; review tab stage sync bug FIXED (stage added to @pipeline_fields); web cache %data flat dotted key; encoding Mojibake source unclear
- [session-62](session-62.md) — httpd web-relay STRM refactor: SIZE→STRM, bytes::length fix, flush_shutdown wrong (route closes), phantom !TERM! from cancel_route
- [session-61](session-61.md) — umlaut conditional utf8 encode, model_output buffer gap for no_tools tasks
- [session-60](session-60.md) — jobsite pipeline: YAML parsing, B32 newline transport, model→9B, state_machine no_tools fix
- [session-59](session-59.md) — tool calls verified working, session-58 committed [cfc07a3f7]
- [session-58](session-58.md) — inference crash fixes (3 bugs), llama v4547, CUDA 12.9, reasoning namespace wired
- [session-57](session-57.md) — JHash cube v4, prev_chk_packed perf, graphical storage design; rings 5-7 still slow — fix: lift `<index.level>->{$D+1}` ref outside inner loop in `index.tick.persist-cube`
- [session-56](session-56.md) — `<index.terminal>`, schema v3 cube, v7 restart race fix, lazy rank
- [session-55](session-55.md) — index exact-match display, em-dash removal codebase-wide, corpus versioning

## Architecture Docs
- session 42: `data/md/design/` — NESTED-CUBE-SEGMENTATION, ZENKA-LIFECYCLE, SIGNED-CMD, AUTHORIZATION-BUFFER, LIVING-BACKGROUND, VISUAL-INPUT-PIPELINE
- session 40: `data/md/development/` — LLM-SESSION-MANAGEMENT, P7-NATIVE-WEB, PARALLEL-REASONING-ORCHESTRATION
- session 37: `data/md/development/` — CHILD-PROCESS-LIFECYCLE, P7-LLM-REFERENCE, DEGRADED-FEATURES-AUDIT

## Space Engine (session 43/44)
- `space.*` 29 modules + `branch.space/clock/ntime` 13 modules; `base.callback.cmd_reply` DATA+TREE modes added
- [SPACE-ENGINE-MASTER.md](../../../data/projects/protocol-7/data/md/design/SPACE-ENGINE-MASTER.md) — 12 sub-namespaces; internal reference capable; aura profiles
- ncode mask pattern: `data..space.X.Y...` matches `$data{'space.X.Y'}{` — use `ncode -ai-friendly -confirm replace`
- `bin/amos-matrix` — AMOS checksums as 5×7 dot matrices; -V -flip-h -flip-v -inv flags

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

## Branch Namespace
- [topic-branch-namespace](topic-branch-namespace.md) — 58 modules: branch.field/calc.fraction/cluster/session + tree.sort.trunk/route.page; Z.Y.X coords; rollover dual semantics; mask/canvas; holographic devices

## Active Topics
- [plugin-web-jobs](topic-plugin-web-jobs.md) — delta sync WORKING (session 34): ntime persisted, chunked push, last_modified stamps; open: ?since=N browser delta, remote deploy
- [clients-http](topic-clients-http.md) — clients.http.* + clients.https.* async namespaces; kimi-web parallel dispatch fixed; see completed session 33
- [reasoning-chain-repository](topic-reasoning-chain-repository.md) — planned for native model; dedup-based self-improvement; small model naive insight + large model validation = ground truth
- [reasoning-namespace](topic-reasoning-namespace.md) — `reasoning.*` namespace (harmonically TRUE); 21 templates: 1-9 vortex set, 10-14 materialization/NI/alignment/routing/omega-gate, 15-16 living-commitment/introspection, 17-20 implosion/freed-model/arrived-by-being/semantic-triangle, 21 physics-as-calculator
- [job-pipeline](topic-job-pipeline.md) — WORKING (session 22): jobs.vhost live, German reason+summary, retry on timeout
- [task-coordination](topic-task-coordination.md) — task zenka as coordinator; current state, dispatch flow, roadmap
- [coding-state-machine](topic-coding-state-machine.md) — coding.state namespace, watcher-based backend lock, persist/restore lifecycle
- [kimi-zenka-state-machine](topic-kimi-zenka-state-machine.md) — improvements ongoing; backend reconnect behavior still open; see `needs-testing/kimi-zenka-multiplexer.md` + `needs-testing/kimi-web-session-cache-access.md`
- [chat-script](topic-chat-script.md) — bin/chat COMPLETE (session 23); open: kimi state machine, coding zenka dispatch, phase 2 channels zenka
- [stream-transport-layer](topic-stream-transport-layer.md) — STRM stack complete; open: formal open-0 sentinel, transport.register, webcam/log-tail
- [stream-reply-modes](topic-stream-reply-modes.md) — 4 reply modes: bounded scalar (done), unbounded live (done), scalar-ref (planned), filehandle (planned); design constraints for scalar-ref optimization
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
- [memory-sync-timing](feedback-memory-sync-timing.md) — sync memory at ~42K context remaining, before auto-compaction fires
- [memory-management](feedback-memory-management.md) — update proactively; tree-structured modules; startup efficiency; strategic maintenance
- [claude-dispatch-strategy](feedback-claude-dispatch-strategy.md) — use claude_dispatch to offload kimi orchestration; keeps parent context lean; parallel dispatch pattern
- **coding_summarize** live (55a4a68df) — free 9B summarization; auto-summarize=TRUE default on claude/kimi dispatch; rolling-window sized from coding.context-size (32K→108K chars); file= param reads directly (zero context tokens)
- **session_catchup** MCP tool — list recent claude+kimi sessions or summarize one by UUID; use at session start to catch up; `session_catchup(limit=8)` to list, add session_id+instruction to summarize
- **store_summary_focus** MCP tool — prime next kimi/claude dispatch auto_summarize with a specific focus; one-shot, clears after use; call before dispatch when you know exactly what you need from the result
- **claude_continue** live (1adbf83d2) — resume claude sessions same as kimi_continue
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
- [arg-calling-convention](feedback-arg-calling-convention.md) — modules using $ARG must use `@_ ? shift : $ARG` when called with explicit args; $_ not set by Perl sub call
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
- **letsencr**: fully working on atom + pri.v7.ax (session 53) — events recalc fix was root cause of 5-year-dormant scheduling bug
- **reasoning.branch.***: LIVE (session 41) — 9 modules, task zenka hooked, ASCII tree viz via p7c reasoning.branch.status
- **base.cmd.list**: :n: row limit working (prefix/suffix/zero-padded), header-aware
- **pager.sort.multi-key**: ntime_b32 + priority_map sort types added (session 42)
- **task dispatch sections**: all dispatched tasks now carry ## dispatch + prompt for reuse
- **coding zenka**: fully operational; 9B model loads in seconds (new ik_llama.cpp); no urgent issues

#,,,,,,,,,,..,.,.,..,,,,.,,,,,,,,,...,,,.,,..,..,,...,...,..,,,..,,,.,...,.,,,
#AGXUYOY7NF6XKV2SNBNESLRSWYOMRKK5ONJN74RWKDAGYZPOVVVPMKF52XQXGOEQTZFYUNELTGI7E
#\\\|O4H52TGTAWLEHXGJNJ27DIS4WAM6OHLS4NLSMY5NAWIZZJFLVYF \ / AMOS7 \ YOURUM ::
#\[7]YWV6NNPGTCVVRGCZWJ3Z6W5J6XI4D6YWHHDZ53GG5DBKSNEIOQBA 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
