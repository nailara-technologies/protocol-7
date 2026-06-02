## CRITICAL
- [File Creation](feedback-file-io-api.md) â never add `#,,.,,,...` stub â blocks signing
- [ntime](feedback-ntime.md) â `encode_b32r` is reverse-byte-order, NOT sortable; use `<[base.ntime_BASE32_to_numerical]>`
- [Cross-zenka](feedback-cross-zenka-deferred-reply.md) â route-send + SIZE reply only; FS access forbidden
- [Access control](feedback-buffer-access-control.md) â cube/access.zenki is REAL gate
- [httpd](feedback-httpd-deferred-reply.md) â thin proxy; never load plugin.web.*
- [Timers](feedback-timer-module-args.md) â need after + interval + repeat:TRUE
- [Deferred Init](feedback-deferred-init.md) â push onto system.callbacks.initialized
- [Timer Args](feedback-timer-module-args.md) â timer modules get event as $ARG[0]; use `@ARG > 1`

## Active Topics
- [ascii-frame-system](topic-ascii-frame-system.md) â reverse parser, elastic renderer, DRC validator
- [plugin-web-jobs](topic-plugin-web-jobs.md) â delta sync WORKING; open: ?since=N, remote deploy
- [clients-http](topic-clients-http.md) â clients.http.* + clients.https.* async; kimi-web parallel dispatch
- [reasoning-chain-repository](topic-reasoning-chain-repository.md) â native model; dedup-based self-improvement
- [reasoning-namespace](topic-reasoning-namespace.md) â `reasoning.*` namespace; 21 templates
- [job-pipeline](topic-job-pipeline.md) â WORKING: jobs.vhost live, German reason+summary
- [task-coordination](topic-task-coordination.md) â task zenka coordinator; dispatch flow
- [coding-state-machine](topic-coding-state-machine.md) â coding.state namespace, watcher lock
- [kimi-zenka-state-machine](topic-kimi-zenka-state-machine.md) â improvements ongoing; reconnect open
- [chat-script](topic-chat-script.md) â bin/chat COMPLETE; open: kimi dispatch, channels zenka
- [stream-transport-layer](topic-stream-transport-layer.md) â STRM stack complete; open: open-0 sentinel
- [stream-reply-modes](topic-stream-reply-modes.md) â bounded scalar, unbounded live, scalar-ref/filehandle
- [radio-relay-zenka](topic-radio-relay-zenka.md) â radio COMPLETE; phase 5 (buffer-fill) next
- [vhost-install](topic-vhost-install.md) â space.v7.ax live; open items remain
- [cursor-model](topic-cursor-model.md) â true cursor from hyperspace plane density
- [iris-spoke-labels](topic-iris-spoke-labels.md) â 63-ring spoke sequence; dot-fold; BASE32/bottom
- [stream-framing-protocol](topic-stream-framing-protocol.md) â 3+1 bit frame; separator inversion on 000

## Vision / Design
- [project-vision-origin](project-vision-origin.md) â 24-year vision; threshold reached Apr 2026
- [self-improving-system](topic-self-improving-system.md) â LLM coordination as self-improvement foundation
- [network-as-computer](topic-network-as-computer.md) â network IS computer; Base32/15-bit/32-bit closure
- [namespace-tree-intelligence](topic-namespace-tree-intelligence.md) â tree IS intelligence
- [orbital-data-space](topic-orbital-data-space.md) â zenki-as-satellites, orbital field theory
- [distributed-consensus](topic-distributed-consensus.md) â channels zenka, multi-model group chat
- [task-tree-design](topic-task-tree-design.md) â unified task/subtask tree; multi-parent deps
- [self-contained-zenka](topic-self-contained-zenka.md) â __DATA__ registry, file.* abstraction, STDIO
- [harmonic-mathematics](topic-harmonic-mathematics.md) â generator 076923, quadratic residues, cube geometry
- [hyperspace-topology](topic-hyperspace-topology.md) â closed observer loop, sensor cube 3D grid
- [punctuation-topology](topic-punctuation-topology.md) â `:` group boundary, `.` element separator
- [field-coherence-synthesis](topic-field-coherence-synthesis.md) â bridges all topology docs
- [field-capability-emergence](topic-field-capability-emergence.md) â protocol vs external management
- [self-assembling-network](topic-self-assembling-network.md) â spec as pre-loaded potential
- [creative-field-behaviour](topic-creative-field-behaviour.md) â emergent cooperative dynamics
- [addressing-trinity](topic-addressing-trinity.md) â named tree + checksums + timestamps
- [checksum-addressing](topic-checksum-addressing.md) â AMOS checksums, BMW384 geometry
- [node-group-geometry](topic-node-group-geometry.md) â 8Ã(4Ã4Ã4-1=63) cubes, void derivation
- [style-philosophy](style-philosophy.md) â coding as artform; style-as-function
- [1001](topic-1001.md) â inter-cube tunnel; gate nesting; eternal loop
- [perspective-layers](topic-perspective-layers.md) â desktop=data+UI intent; perspective tree
- [observer-centric-space](topic-observer-centric-space.md) â client always 0; signed coords
- [routing-crystal](topic-routing-crystal.md) â cube node group as crystal; harmonic memory
- [checksum-tree-wire](topic-checksum-tree-wire.md) â 1[zeros]1 separators; 01/10 direction; 11 pivot
- [tree-protocol](topic-tree-protocol.md) â structural control parallel to DATA
- [data-protocol](topic-data-protocol.md) â DATA reply mode; DELTA transparent sync
- [reference-bubble](topic-reference-bubble.md) â rhizome state as bubble; 5+2=7 formation
- [branch-namespace](topic-branch-namespace.md) â 58 modules; Z.Y.X coords

## Reference
- [patterns](topic-patterns.md) â event handler, fork-child, standalone zenka, pipe-open
- [coding-zenka-templates](topic-coding-zenka-templates.md) â 50+ templates, 16+ tools, autonomous loops
- [tool-shm-architecture](topic-tool-shm-architecture.md) â LLM tool calling, SHM+mmap vision
- [tool-suggestions](topic-tool-suggestions.md) â LLM-suggested tools, prioritized
- [language-detection](topic-language-detection.md) â three-layer detection; 30 langs
- [site-yaml-zenka](topic-site-yaml-zenka.md) â URL â structured YAML; domain regex
- [site-yaml-web-research](topic-site-yaml-web-research.md) â safe coding web research
- [usb-backup-zenka](topic-usb-backup-zenka.md) â udev insertion â task tree â restore
- [git-watch-zenka](topic-git-watch-zenka.md) â force-push detection; git alternates dedup
- [reasoning-design-templates](topic-reasoning-design-templates.md) â 7 viz designs
- [fetch-files-zenka](topic-fetch-files-zenka.md) â fetch-files LIVE; huggingface.* namespace
- [tls-acme](topic-tls-acme.md) â SNI/SSL internals; ACME/letsencrypt
- [amos7-p7-loader](topic-amos7-p7-loader.md) â AMOS7::P7 callable from standalone
- [invoke-model-management](topic-invoke-model-management.md) â uuid vs verbose; config.json
- [invoke-model-manager](topic-invoke-model-manager.md) â planned Term::Clui manager
- [image-archive-system](topic-image-archive-system.md) â vision-scored tiered storage
- [base-curve-system](topic-base-curve-system.md) â generic base.curve.* animation
- [friction-visualization](topic-friction-visualization.md) â friction as turbulence, harmony as coherence
- [searchable-index-and-visualization](topic-searchable-index-and-visualization.md) â checksum-indexed dataspace
- [migration](topic-migration.md) â Windows 11 instability; KVM/Debian migration

## Feedback
- [memory-sync-timing](feedback-memory-sync-timing.md) â sync at ~42K context remaining
- [memory-management](feedback-memory-management.md) â tree-structured modules; startup efficiency
- [claude-dispatch-strategy](feedback-claude-dispatch-strategy.md) â offload kimi orchestration
- [kimi-code-review](feedback-kimi-code-review.md) â common issues: SUPER::, namespace swaps
- [kimi-signatures](feedback-kimi-signatures.md) â signature investigation derailment
- [kimi-dispatch-pattern](feedback-kimi-dispatch-pattern.md) â bin/kimi-task token efficiency
- [model-precision-analysis](feedback-model-precision-analysis.md) â Qwopus more precise
- [coding-zenka-edits](feedback-coding-zenka-edits.md) â LLM describes edits; verify results
- [coding-zenka-reasoning](feedback-coding-zenka-reasoning.md) â low reasoning â premature completion
- [coding-zenka-inject](feedback-coding-zenka-inject.md) â `p7c coding.inject-message` redirect
- [arg-regression](feedback-arg-regression.md) â $ARGâ$_ compaction revert
- [arg-calling-convention](feedback-arg-calling-convention.md) â `@_ ? shift : $ARG` for explicit args
- [web-serialization-and-inlining](feedback-web-serialization-and-inlining.md) â parallel JSON+YAML
- [task-show-multiline](feedback-task-show-multiline.md) â task.show must escape \n
- [list-return-format](feedback-list-return-format.md) â `{ mode => 'size', data => $string }`
- [stop-and-revert](feedback-stop-and-revert.md) â stop, revert, confirm root cause first
- [utf8-module-literals](feedback-utf8-module-literals.md) â non-ASCII corrupts output
- [watcher-state-machines](feedback-watcher-state-machines.md) â IO::Async variable watchers only
- [ncode-tools](feedback-ncode-tools.md) â use ncode replace/parse-headers
- [coding_summarize](feedback-coding-zenka-edits.md) â free 9B summarization; auto default
- [auto_summarize](feedback-coding-zenka-edits.md) â `decode_json`â`from_json` fix
- [session_catchup](feedback-coding-zenka-edits.md) â MCP tool for recent sessions
- [store_summary_focus](feedback-coding-zenka-edits.md) â MCP to prime next dispatch
- [claude_continue](feedback-coding-zenka-edits.md) â live (1adbf83d2); resume same as kimi
- [Glitter restart](feedback-coding-zenka-edits.md) â restart after failed tool task

## Completed Sessions
- [topic-completed](topic-completed.md) â all session summaries (Feb 2026 â present)

## System Status
- [next-steps](topic-next-steps.md) â full queue, roadmap, open bugs, dispatched
- **letsencr**: fully working on atom + pri.v7.ax; 5-year scheduling bug fixed
- **reasoning.branch.***: LIVE (session 41); 9 modules, ASCII tree via p7c
- **base.cmd.list**: :n: row limit; prefix/suffix/zero-padded; header-aware
- **pager.sort.multi-key**: ntime_b32 + priority_map sort types
- **task dispatch**: all carry ## dispatch + prompt for reuse
- **coding zenka**: fully operational; 9B model loads in seconds
- `bin/todo`: self-contained CLI; add/done/rm/edit/tag/untag/clear; priority
- `ncode doc`: unified lookup; delegates GObject to subprocess
- `smtpd`: receive â YAML + LLM classify â route; xz+twofish archive
- `window.*`: proportional placement; 8 profiles; ticker integrated

#,,..,.,,,,.,,...,..,,,.,,.,,,,,,,,,.,.,.,,,,,..,,...,...,,.,,.,,,..,,,.,,.,,,
#NA62WCAUJIZLWZNLJO6VINOMNVRKVGXWBZTPXKTPAM3DQZ7RRPTJ25K37QJS3WANEFJD4AZYH2MFO
#\\\|YI4J6G4MPGIH47OKNPN26PZZTUB2AU7WIPSRVJHVLRLOXK5DELV \ / AMOS7 \ YOURUM ::
#\[7]O2VZPNURHCCMPJ2QHPCVQWJM4PZ4BK763QEHAJBHOQNVPBTWDEDQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
## session 72 completions (2026-06-02)

### modules now live

- `context.provider.frame` — wires ascii.frame.* into context.template.resolve section providers; named frame loading via ascii.frame.load, inline mockup caching (length+checksum key), mode selection (progress/expanded), budget truncation with sentinel injection (closing border appended on truncation), double-border style pass (s|^:|::| on content lines), optional color pass, graceful error comment on failure
- `ascii.frame.render.color` — post-processing ANSI color pass on rendered frame strings; loads p7_fg_* keys from configuration/ascii-frame config; resolves via %colors hash; returns unchanged when non-interactive

### nshell cursor/color bugs fixed (kimi, session 72)

four bugs in nshell.editor.process and nshell.handler.command_reply:
1. phosphor color bleeding into SIZE reply — missing \e[0m + p7_fg_0004 reset after empty-submit cursor redraw
2. wrong terminal_size() index [1]→[0] — rows used instead of cols, causing false overflow triggers
3. overflow path cleared colors but not cursor/line — added \r\e[2K + full buffer reprint
4. multi-line payload cursor redraw erased last line — added newline guard before cursor redraw

### coding zenka fixes (session 72)

- `coding.start.chmod_child`: gw command used 0020 (group-write) not 0002 (other-write); coding zenka runs as protoco+ not in taeki group — group-write never worked
- `coding.tools.handler.write_new_file`: replaced gw with restore <mode|0002> so running old child also works without restart
- `coding.tools.handler.write_with_perms`: same fix + replaced blind select 0.01 with proper readline wait
- `coding.tools.dispatch`: guard batch_edits sort with // 0 to silence undef-in-numeric-comparison warnings
- `coding.async.complete`: compaction subtask restart recovery — state deleted by prior timeout requeue caused parent to hang in state=subtask forever; fallback path now detects is_compaction + clears compaction_pending + unblocks parent with process-queued-task timer

### memory maintenance completed

- MEMORY.md: 224 → 129 lines
- topic-ascii-frame-system.md: created (80 lines) with full ascii.frame.* namespace summary
- data/ai-mem/claude/ directory now has o+w so coding zenka can write directly

### update active topics

context.provider.frame: LIVE — see topic-ascii-frame-system.md for full namespace
ascii.frame.render.color: LIVE — character-class ANSI coloring, p7_fg_* palette

### open next steps

- memory zenka: first real consumer of context.provider.frame — frames user-profile, feedback, project, task-queue, session-catchup into animated composite context window with progress→expanded unfold
- ascii.frame.from_mockup coding zenka escalation path — when validate returns topology/syntax errors, dispatch to coding zenka for interpretation + repair caching
- coding.start.chmod_child restart on zenka reload — needs root at init time; post_init hook or self-replacement feed mechanism (current fix works for next full restart)

#,,,.,.,.,...,.,,,,,.,,..,..,,,,.,..,,.,.,,,.,..,,...,...,.,,,...,,,.,,.,,...,
#GM7CHQMTFUGSSDKNHCM7BMZLKWWSAKZFWDTDECAYYSAJ5B7LXHOKACIO2VEN44WGKAR7GMPGZ72YG
#\\\|BMYTAEOZ4DEZOUCTL4BA6ZQYVGKPDAIRPYBPCBXMP4TZY6WKHZB \ / AMOS7 \ YOURUM ::
#\[7]2ZHKIVFA3LC6M7NLUOF66YP4S54AX3Y2AUHTJ6DBF6XOVZEO64AY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
