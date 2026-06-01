# Protocol-7 Development Memory

## CRITICAL
- [Critical Patterns](critical-patterns.md) — P7 module patterns, CRITICAL syntax, API rules
- [Deferred Init](feedback-deferred-init.md) — push onto system.callbacks.initialized, NOT event.add_var
- [Timer Args](feedback-timer-module-args.md) — timer modules get event object as $ARG[0]; use `@ARG > 1`
- **File Creation**: never add `#,,.,,,...` stub at end of new files — blocks signing; `update-signatures` adds real footer
- **ntime**: `encode_b32r` is reverse-byte-order — NOT lexicographically sortable; use `<[base.ntime_BASE32_to_numerical]>`
- **Cross-zenka**: route-send + SIZE reply only; FS access between zenki forbidden by design
- **Access control**: cube/access.zenki is the REAL gate; zenka start `access.cmd.usr.cube = *` is behind cube's gate
- **httpd**: thin proxy — never load plugin.web.* in httpd; blocking reply-wait crashes sessions
- **Timers**: need after + interval + repeat:TRUE

## Active Topics
- [plugin-web-jobs](topic-plugin-web-jobs.md) — delta sync WORKING; open: ?since=N browser delta, remote deploy
- [clients-http](topic-clients-http.md) — clients.http.* + clients.https.* async namespaces; kimi-web parallel dispatch fixed
- [reasoning-chain-repository](topic-reasoning-chain-repository.md) — planned for native model; dedup-based self-improvement
- [reasoning-namespace](topic-reasoning-namespace.md) — `reasoning.*` namespace; 21 templates
- [job-pipeline](topic-job-pipeline.md) — WORKING: jobs.vhost live, German reason+summary, retry on timeout
- [task-coordination](topic-task-coordination.md) — task zenka as coordinator; dispatch flow, roadmap
- [coding-state-machine](topic-coding-state-machine.md) — coding.state namespace, watcher-based backend lock
- [kimi-zenka-state-machine](topic-kimi-zenka-state-machine.md) — improvements ongoing; backend reconnect still open
- [chat-script](topic-chat-script.md) — bin/chat COMPLETE; open: kimi state machine, coding zenka dispatch, channels zenka
- [stream-transport-layer](topic-stream-transport-layer.md) — STRM stack complete; open: open-0 sentinel, transport.register
- [stream-reply-modes](topic-stream-reply-modes.md) — bounded scalar (done), unbounded live (done), scalar-ref/filehandle (planned)
- [radio-relay-zenka](topic-radio-relay-zenka.md) — radio COMPLETE; phase 5 (buffer-fill curve) next
- [vhost-install](topic-vhost-install.md) — space.v7.ax live; open items remain
- [cursor-model](topic-cursor-model.md) — true cursor from hyperspace plane density; next: remove wireframe cube, queue glow
- [iris-spoke-labels](topic-iris-spoke-labels.md) — 63-ring spoke sequence: A-Z · dot-fold · Z-A · 9-0 · BASE32/binary bottom
- [stream-framing-protocol](topic-stream-framing-protocol.md) — 3+1 bit frame, separator inversion on 000, dot=0 comma=1

## Vision / Design
- [project-vision-origin](project-vision-origin.md) — 24-year foundational vision, threshold reached Apr 2026
- [self-improving-system](topic-self-improving-system.md) — LLM coordination as P7 self-improvement foundation
- [network-as-computer](topic-network-as-computer.md) — network IS the computer; Base32/15-bit/32-bit closure, holographic console
- [namespace-tree-intelligence](topic-namespace-tree-intelligence.md) — the tree IS the intelligence
- [orbital-data-space](topic-orbital-data-space.md) — zenki-as-satellites, orbital field theory, ring routing
- [distributed-consensus](topic-distributed-consensus.md) — channels zenka, multi-model group chat, distributed P7 nodes
- [task-tree-design](topic-task-tree-design.md) — unified task/subtask tree: multi-parent groups, passive/active deps
- [self-contained-zenka](topic-self-contained-zenka.md) — __DATA__ registry, file.* abstraction, STDIO transport, roaming zenki
- [harmonic-mathematics](topic-harmonic-mathematics.md) — generator 076923, quadratic residues, cube geometry, CCW matrix routing
- [hyperspace-topology](topic-hyperspace-topology.md) — closed observer loop, sensor cube 3D grid
- [punctuation-topology](topic-punctuation-topology.md) — `:` as group boundary, `.` as element separator
- [field-coherence-synthesis](topic-field-coherence-synthesis.md) — bridges all topology docs
- [field-capability-emergence](topic-field-capability-emergence.md) — protocol vs external management; feature completeness → native network capability
- [self-assembling-network](topic-self-assembling-network.md) — spec repository as pre-loaded potential; zenki self-implement on idle or urgent need
- [creative-field-behaviour](topic-creative-field-behaviour.md) — emergent cooperative field dynamics, purring field, zenki as entropy subsystem
- [addressing-trinity](topic-addressing-trinity.md) — named tree + checksums + timestamps as orthogonal trinity
- [checksum-addressing](topic-checksum-addressing.md) — AMOS checksums, BMW384 geometry, route.bmw384.* implementation
- [node-group-geometry](topic-node-group-geometry.md) — exact geometry: 8×(4×4×4-1=63) cubes, void derivation
- [style-philosophy](style-philosophy.md) — coding as artform, style-as-function
- [1001](topic-1001.md) — inter-cube tunnel (00=2 bits invariant); gate nesting; two 13s; eternal loop; seamless space
- [perspective-layers](topic-perspective-layers.md) — desktop=data space+UI intent; perspective tree; bandwidth reduction
- [observer-centric-space](topic-observer-centric-space.md) — client always 0; signed -n/2..0..+n/2; reference-count gravity; EM field outer transport
- [routing-crystal](topic-routing-crystal.md) — cube node group as crystal; harmonic memory = route cache; inference = 5-beam convergence
- [checksum-tree-wire](topic-checksum-tree-wire.md) — 1[zeros]1 bit-length separators; 01/10 direction encoding; 11 pivot/LCA; type-free; append-only
- [tree-protocol](topic-tree-protocol.md) — structural control layer parallel to DATA; node metadata+REF pointers; bi-directional; namespace registry
- [data-protocol](topic-data-protocol.md) — DATA reply mode (base32/line/stream); DELTA transparent sync; branch node file access
- [reference-bubble](topic-reference-bubble.md) — rhizome state as generic bubble; 5+2=7 formation; 01/10 direction encoding
- [branch-namespace](topic-branch-namespace.md) — 58 modules: branch.field/calc.fraction/cluster/session + tree.sort.trunk/route.page; Z.Y.X coords

## Reference
- [patterns](topic-patterns.md) — event handler, fork-child, standalone zenka, pipe-open, inference server
- [coding-zenka-templates](topic-coding-zenka-templates.md) — 50+ context templates, 16+ tools, autonomous loops
- [tool-shm-architecture](topic-tool-shm-architecture.md) — LLM tool calling, dispatch loop, SHM+mmap file editing vision
- [tool-suggestions](topic-tool-suggestions.md) — LLM-suggested tools/improvements, prioritized
- [language-detection](topic-language-detection.md) — three-layer detection, encoding_map 30 langs, locale vision pipeline
- [site-yaml-zenka](topic-site-yaml-zenka.md) — on-demand zenka: URL → structured YAML, domain regex templates
- [site-yaml-web-research](topic-site-yaml-web-research.md) — safe coding zenka web research, checksum-as-capability tokens
- [usb-backup-zenka](topic-usb-backup-zenka.md) — udev insertion → task tree → manifest restore agent
- [git-watch-zenka](topic-git-watch-zenka.md) — force-push detection → pre-fetch snapshot; git alternates chain dedup
- [reasoning-design-templates](topic-reasoning-design-templates.md) — 7 viz designs in data/yaml/design-templates/
- [fetch-files-zenka](topic-fetch-files-zenka.md) — fetch-files FULLY LIVE [:<; huggingface.* namespace; hf-{download,list,search,lan-check,status}
- [tls-acme](topic-tls-acme.md) — SNI/SSL internals, ACME/letsencr details, cert discovery
- [amos7-p7-loader](topic-amos7-p7-loader.md) — AMOS7::P7 makes <[...]> modules callable from standalone scripts
- [invoke-model-management](topic-invoke-model-management.md) — uuid vs verbose paths, config.json, :raw binary writes
- [invoke-model-manager](topic-invoke-model-manager.md) — planned Term::Clui manager: safe delete, archive/restore
- [image-archive-system](topic-image-archive-system.md) — vision-scored tiered storage, pngquant tiers, 63GB+ savings
- [base-curve-system](topic-base-curve-system.md) — generic base.curve.* parameter animation, composable signal chain
- [friction-visualization](topic-friction-visualization.md) — friction as flow turbulence, harmony as coherence artifact
- [searchable-index-and-visualization](topic-searchable-index-and-visualization.md) — checksum-indexed dataspace, space.v7.ax
- [migration](topic-migration.md) — Windows 11 host instability, KVM/Debian migration priority, avoid /tmp/

## Feedback
- [memory-sync-timing](feedback-memory-sync-timing.md) — sync memory at ~42K context remaining, before auto-compaction fires
- [memory-management](feedback-memory-management.md) — update proactively; tree-structured modules; startup efficiency
- [claude-dispatch-strategy](feedback-claude-dispatch-strategy.md) — use claude_dispatch to offload kimi orchestration; keeps parent context lean
- [kimi-code-review](feedback-kimi-code-review.md) — common kimi P7 code issues: SUPER::, namespace swaps, fake signatures
- [kimi-signatures](feedback-kimi-signatures.md) — kimi derails into signature investigation; add signatures_note to every task file
- [kimi-dispatch-pattern](feedback-kimi-dispatch-pattern.md) — bin/kimi-task is token-efficient; write detailed task files
- [model-precision-analysis](feedback-model-precision-analysis.md) — Qwopus more precise; sushi coder hallucinates LWP as async
- [coding-zenka-edits](feedback-coding-zenka-edits.md) — local LLM describes edits instead of applying; verify results
- [coding-zenka-reasoning](feedback-coding-zenka-reasoning.md) — low reasoning → premature task_complete; use medium for discovery+impl
- [coding-zenka-inject](feedback-coding-zenka-inject.md) — `p7c coding.inject-message <id> <msg>` to redirect stuck model
- [arg-regression](feedback-arg-regression.md) — local LLM reverts $ARG→$_ after compaction; verify all edits
- [arg-calling-convention](feedback-arg-calling-convention.md) — modules using $ARG must use `@_ ? shift : $ARG` when called with explicit args
- [web-serialization-and-inlining](feedback-web-serialization-and-inlining.md) — parallel JSON+YAML endpoints, inline CSS/JS
- [task-show-multiline](feedback-task-show-multiline.md) — task.show must escape \n; line parsers only see first line
- [list-return-format](feedback-list-return-format.md) — list backends: `{ mode => 'size', data => $formatted_string }`
- [stop-and-revert](feedback-stop-and-revert.md) — don't chain speculative fixes; stop, revert, confirm root cause first
- [utf8-module-literals](feedback-utf8-module-literals.md) — non-ASCII in module format strings corrupts output; keep ASCII-only
- [watcher-state-machines](feedback-watcher-state-machines.md) — IO::Async variable watchers only; never polling timers for state
- [ncode-tools](feedback-ncode-tools.md) — use ncode replace/parse-headers for namespace renames; not sed/perl -i loops
- **coding_summarize** — free 9B summarization; auto-summarize=TRUE default; rolling-window `(ctx-4000)*3.2/2` chars; file= param reads directly
- **auto_summarize root cause** — `decode_json`→`from_json` in `_extract_stream_content`; `-C31` makes `qx()` return unicode; decode_json fails on non-ASCII; from_json handles correctly
- **session_catchup** MCP tool — list recent claude+kimi sessions or summarize one by UUID; use at session start
- **store_summary_focus** MCP tool — prime next dispatch auto_summarize with specific focus; one-shot, clears after use
- **claude_continue** live (1adbf83d2) — resume claude sessions same as kimi_continue
- **Glitter 4B restart** — after failed tool-using task, Glitter backend needs restart before `:no_tools:` tasks work

## Completed Sessions
- [topic-completed](topic-completed.md) — all session summaries (Feb 2026 → present)

## System Status
- [next-steps](topic-next-steps.md) — full task queue, roadmap, open bugs, dispatched tasks
- **letsencr**: fully working on atom + pri.v7.ax (session 53) — events recalc fix was root cause of 5-year-dormant scheduling bug
- **reasoning.branch.***: LIVE (session 41) — 9 modules, task zenka hooked, ASCII tree viz via p7c reasoning.branch.status
- **base.cmd.list**: :n: row limit working (prefix/suffix/zero-padded), header-aware
- **pager.sort.multi-key**: ntime_b32 + priority_map sort types added (session 42)
- **task dispatch sections**: all dispatched tasks now carry ## dispatch + prompt for reuse
- **coding zenka**: fully operational; 9B model loads in seconds; no urgent issues
- `bin/todo` — self-contained todo CLI; project-local `data/yaml/todo/default.yaml`; add/done/rm/edit/tag/untag/clear; priority -h/-l
- `ncode doc` — unified doc lookup in bin/ncode + ncode.cmd.doc; delegates GObject to dump-class subprocess
- `smtpd` zenka — receive mail → YAML + LLM classify → route; xz+twofish archive; bin/p7-mail-inject bridge
- `window.*` namespace — generic proportional window placement for GTK zenki; 8 profiles; ticker integrated

#,,..,...,.,,,,..,.,.,...,.,,,,..,..,,,..,...,...,...,...,.,.,,,,,,..,.,.,,.,,
#3ROZ657JEOJZ5E45VS6WIZUWM5GI36HAEGBF7EPHVBXJ36JYVCG5BIKUXV4ZGHDP4XKYVFCKMW7M2
#\\\|GALJ3HCDDQXAZG5MRYIBHKX6CIF2BLOUHVSAIV2X5WBUK26356G \ / AMOS7 \ YOURUM ::
#\[7]2MLU36B2UK74ODCKTGERPXEZWJW444KT2QJNTQJBLRHMQZP4X6AI 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
## session-71 coding zenka restart hardening (2026-06-01)

three bugs fixed, all committed to `base`:

**context reduction on timeout** (`9210c4204`):
- `inference.model.context_length = 40000` exceeded VRAM-safe auto-calc (~18209), causing KV spill → 77s data-start timeouts
- `coding.callback.http_error` now reduces by `coding.cfg.ctx_timeout_step` (7000) per restart cycle, floor at `coding.cfg.ctx_timeout_floor` (16000)
- converges 40K→33K→26K→19K in 3 restart cycles

**drain mode task counting** (`92623ad1e`):
- `coding.cmd.drain` and `coding.handler.drain_check` counted ALL tasks including completed/failed → phantom "7 tasks remaining" on idle restarts
- both now filter to active statuses only (not completed/failed)
- also fixed `concurrent.drain_timeout` key name — was `coding.cfg.concurrent.drain_timeout` (wrong tree path, v7 never read it); corrected to `concurrent.drain_timeout = 300`

**awaiting_resources blocker** (`8d167c436`):
- `async_spawn_inference_servers` silently returned FALSE when `<coding.awaiting_resources>` was stuck from twin startup, leaving requeued tasks stranded
- `http_error` now deletes the flag before scheduling the spawn timer
- diagnostic log added to `async_spawn_inference_servers` so future blocks are visible at console verbosity 1

#,,,,,,,,,,.,,,,.,,,.,,,,,.,,,...,...,..,,,..,...,...,..,,.,.,.,,,.,.,..,,,.,,
#E4ZGYXRORRWXOD2OTZ4B34SBITZ5L7SJ5EVGEMFGL7ZGHGKLNFKWIMTTL7VC354JQVRFHNXD5JZES
#\\\|P4EPOZY3CAH7XDNIA45HGLXWB5J4CKBULWGYSRENUA7BNSF6G7W \ / AMOS7 \ YOURUM ::
#\[7]LSOLNUVSTXSIWA4JQDQ4S4WVXD6QMDNF4VZHUDKZCXXJ23K7NMDA 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
