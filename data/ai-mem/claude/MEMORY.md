## CRITICAL
- [File Creation](feedback-file-io-api.md) — never add `#,,.,,,...` stub — blocks signing
- [filter-repo prefix](feedback-filter-repo-amend.md)
- [P7 data nesting](feedback-p7-data-nesting.md) — `<a.b.c>` = `$data{a}{b}{c}`; use underscore for siblings not dot
- [timer undef interval](feedback-timer-undef-interval.md) — undef after/interval = IO::Async max-rate loop; always guard with fallback
- [each+continue+keys](feedback-each-continue-keys.md) — `continue{keys %h}` on `while(each %h)` resets iterator = infinite loop — `AMEND=1 git filter-repo ...`; also clear `.git/filter-repo/already_ran` if interrupted
- [ntime](feedback-ntime.md) — `encode_b32r` is reverse-byte-order, NOT sortable; use `<[base.ntime_BASE32_to_numerical]>`
- [Cross-zenka](feedback-cross-zenka-deferred-reply.md) — route-send + SIZE reply only; FS access forbidden
- [Access control](feedback-buffer-access-control.md) — cube/access.zenki is REAL gate
- [httpd](feedback-httpd-deferred-reply.md) — thin proxy; never load plugin.web.*
- [Timers](feedback-timer-module-args.md) — need after + interval + repeat:TRUE
- [Deferred Init](feedback-deferred-init.md) — push onto system.callbacks.initialized
- [Timer Args](feedback-timer-module-args.md) — timer modules get event as $ARG[0]; use `@ARG > 1`

## Active Topics
- [ascii-frame-system](topic-ascii-frame-system.md) — reverse parser, elastic renderer, DRC validator
- [frame-plugin-slots](topic-frame-plugin-slots.md) — status-bar plugin slots + context-aware selector; variable border width; vertical-slot roadmap
- [ascii-desktop-domains](topic-ascii-desktop-domains.md) — border glyphs are domain-scoped; nested domains = nested planes = ascii desktop; role-vs-glyph descriptor is the windowing unlock
- [frame-idiom-convergence](topic-frame-idiom-convergence.md) — NEW frame features: margin/vertical-padding/self-invalidating-cache/corner-pinning-spring; `.:[ ]::[ ]:.` idiom; 5 frames still need conversion (REQUIRED)
- [plugin-web-jobs](topic-plugin-web-jobs.md) — delta sync WORKING; open: ?since=N, remote deploy
- [clients-http](topic-clients-http.md) — clients.http.* + clients.https.* async; kimi-web parallel dispatch
- [reasoning-chain-repository](topic-reasoning-chain-repository.md) — native model; dedup-based self-improvement
- [reasoning-namespace](topic-reasoning-namespace.md) — `reasoning.*` namespace; 21 templates
- [job-pipeline](topic-job-pipeline.md) — WORKING: jobs.vhost live, German reason+summary
- [task-coordination](topic-task-coordination.md) — task zenka coordinator; dispatch flow
- [coding-state-machine](topic-coding-state-machine.md) — coding.state namespace, watcher lock
- [kimi-zenka-state-machine](topic-kimi-zenka-state-machine.md) — improvements ongoing; reconnect open
- [chat-script](topic-chat-script.md) — bin/chat COMPLETE; open: kimi dispatch, channels zenka
- [stream-transport-layer](topic-stream-transport-layer.md) — STRM stack complete; open: open-0 sentinel
- [stream-reply-modes](topic-stream-reply-modes.md) — bounded scalar, unbounded live, scalar-ref/filehandle
- [radio-relay-zenka](topic-radio-relay-zenka.md) — radio COMPLETE; phase 5 (buffer-fill) next
- [vhost-install](topic-vhost-install.md) — space.v7.ax live; open items remain
- [cursor-model](topic-cursor-model.md) — true cursor from hyperspace plane density
- [iris-spoke-labels](topic-iris-spoke-labels.md) — 63-ring spoke sequence; dot-fold; BASE32/bottom
- [stream-framing-protocol](topic-stream-framing-protocol.md) — 3+1 bit frame; separator inversion on 000
- [nshell-terminal-rendering](topic-nshell-terminal-rendering.md) — `(0)!TERM!` bug, overflow path, color reset, async reply during VIEWING_HISTORY
- [memory-tree-zenka](topic-memory-tree-zenka.md) — tree BUILD live (162 branches); focus steering works; step 2 = flow-weighting; per-node re-weighting engine vision

## Vision / Design
- [project-vision-origin](project-vision-origin.md) — 24-year vision; threshold reached Apr 2026
- [self-improving-system](topic-self-improving-system.md) — LLM coordination as self-improvement foundation
- [network-as-computer](topic-network-as-computer.md) — network IS computer; Base32/15-bit/32-bit closure
- [namespace-tree-intelligence](topic-namespace-tree-intelligence.md) — tree IS intelligence
- [orbital-data-space](topic-orbital-data-space.md) — zenki-as-satellites, orbital field theory
- [distributed-consensus](topic-distributed-consensus.md) — channels zenka, multi-model group chat
- [task-tree-design](topic-task-tree-design.md) — unified task/subtask tree; multi-parent deps
- [self-contained-zenka](topic-self-contained-zenka.md) — __DATA__ registry, file.* abstraction, STDIO
- [harmonic-mathematics](topic-harmonic-mathematics.md) — generator 076923, quadratic residues, cube geometry
- [hyperspace-topology](topic-hyperspace-topology.md) — closed observer loop, sensor cube 3D grid
- [punctuation-topology](topic-punctuation-topology.md) — `:` group boundary, `.` element separator
- [field-coherence-synthesis](topic-field-coherence-synthesis.md) — bridges all topology docs
- [field-capability-emergence](topic-field-capability-emergence.md) — protocol vs external management
- [self-assembling-network](topic-self-assembling-network.md) — spec as pre-loaded potential
- [creative-field-behaviour](topic-creative-field-behaviour.md) — emergent cooperative dynamics
- [addressing-trinity](topic-addressing-trinity.md) — named tree + checksums + timestamps
- [checksum-addressing](topic-checksum-addressing.md) — AMOS checksums, BMW384 geometry
- [node-group-geometry](topic-node-group-geometry.md) — 8×(4×4×4-1=63) cubes, void derivation
- [style-philosophy](style-philosophy.md) — coding as artform; style-as-function
- [1001](topic-1001.md) — inter-cube tunnel; gate nesting; eternal loop
- [perspective-layers](topic-perspective-layers.md) — desktop=data+UI intent; perspective tree
- [observer-centric-space](topic-observer-centric-space.md) — client always 0; signed coords
- [routing-crystal](topic-routing-crystal.md) — cube node group as crystal; harmonic memory
- [checksum-tree-wire](topic-checksum-tree-wire.md) — 1[zeros]1 separators; 01/10 direction; 11 pivot
- [tree-protocol](topic-tree-protocol.md) — structural control parallel to DATA
- [data-protocol](topic-data-protocol.md) — DATA reply mode; DELTA transparent sync
- [reference-bubble](topic-reference-bubble.md) — rhizome state as bubble; 5+2=7 formation
- [branch-namespace](topic-branch-namespace.md) — 58 modules; Z.Y.X coords

## Reference
- [unicode-encoding-repair](reference-unicode-encoding-repair.md) — bin/dev tool: fixes double-UTF8 mojibake in files or dirs
- [patterns](topic-patterns.md) — event handler, fork-child, standalone zenka, pipe-open
- [coding-zenka-templates](topic-coding-zenka-templates.md) — 50+ templates, 16+ tools, autonomous loops
- [tool-shm-architecture](topic-tool-shm-architecture.md) — LLM tool calling, SHM+mmap vision
- [tool-suggestions](topic-tool-suggestions.md) — LLM-suggested tools, prioritized
- [language-detection](topic-language-detection.md) — three-layer detection; 30 langs
- [site-yaml-zenka](topic-site-yaml-zenka.md) — URL → structured YAML; domain regex
- [site-yaml-web-research](topic-site-yaml-web-research.md) — safe coding web research
- [usb-backup-zenka](topic-usb-backup-zenka.md) — udev insertion → task tree → restore
- [git-watch-zenka](topic-git-watch-zenka.md) — force-push detection; git alternates dedup
- [reasoning-design-templates](topic-reasoning-design-templates.md) — 7 viz designs
- [fetch-files-zenka](topic-fetch-files-zenka.md) — fetch-files LIVE; huggingface.* namespace
- [tls-acme](topic-tls-acme.md) — SNI/SSL internals; ACME/letsencrypt
- [amos7-p7-loader](topic-amos7-p7-loader.md) — AMOS7::P7 callable from standalone
- [invoke-model-management](topic-invoke-model-management.md) — uuid vs verbose; config.json
- [invoke-model-manager](topic-invoke-model-manager.md) — planned Term::Clui manager
- [image-archive-system](topic-image-archive-system.md) — vision-scored tiered storage
- [base-curve-system](topic-base-curve-system.md) — generic base.curve.* animation
- [friction-visualization](topic-friction-visualization.md) — friction as turbulence, harmony as coherence
- [searchable-index-and-visualization](topic-searchable-index-and-visualization.md) — checksum-indexed dataspace
- [migration](topic-migration.md) — Windows 11 instability; KVM/Debian migration

## Feedback
- [memory-sync-timing](feedback-memory-sync-timing.md) — sync at ~42K context remaining
- [memory-management](feedback-memory-management.md) — tree-structured modules; startup efficiency
- [claude-dispatch-strategy](feedback-claude-dispatch-strategy.md) — offload kimi orchestration
- [kimi-code-review](feedback-kimi-code-review.md) — common issues: SUPER::, namespace swaps
- [kimi-signatures](feedback-kimi-signatures.md) — signature investigation derailment
- [kimi-dispatch-pattern](feedback-kimi-dispatch-pattern.md) — bin/kimi-task token efficiency
- [model-precision-analysis](feedback-model-precision-analysis.md) — Qwopus more precise
- [coding-zenka-edits](feedback-coding-zenka-edits.md) — LLM describes edits; verify results
- [coding-zenka-reasoning](feedback-coding-zenka-reasoning.md) — low reasoning → premature completion
- [coding-zenka-inject](feedback-coding-zenka-inject.md) — `p7c coding.inject-message` redirect
- [arg-regression](feedback-arg-regression.md) — $ARG→$_ compaction revert
- [arg-calling-convention](feedback-arg-calling-convention.md) — `@_ ? shift : $ARG` for explicit args
- [prefer-parsed-config](feedback-prefer-parsed-config.md) — use «<v7.start_setup.zenki.config>» not FS rescan
- [true-false-constants](feedback-true-false-constants.md) — booleans use TRUE/FALSE constants, never 0/1
- [web-serialization-and-inlining](feedback-web-serialization-and-inlining.md) — parallel JSON+YAML
- [task-show-multiline](feedback-task-show-multiline.md) — task.show must escape \n
- [list-return-format](feedback-list-return-format.md) — `{ mode => 'size', data => $string }`
- [stop-and-revert](feedback-stop-and-revert.md) — stop, revert, confirm root cause first
- [utf8-module-literals](feedback-utf8-module-literals.md) — non-ASCII corrupts output
- [watcher-state-machines](feedback-watcher-state-machines.md) — IO::Async variable watchers only
- [ncode-tools](feedback-ncode-tools.md) — use ncode replace/parse-headers
- [coding_summarize](feedback-coding-zenka-edits.md) — free 9B summarization; auto default
- [auto_summarize](feedback-coding-zenka-edits.md) — `decode_json`→`from_json` fix
- [session_catchup](feedback-coding-zenka-edits.md) — MCP tool for recent sessions
- [store_summary_focus](feedback-coding-zenka-edits.md) — MCP to prime next dispatch
- [claude_continue](feedback-coding-zenka-edits.md) — live (1adbf83d2); resume same as kimi
- [Glitter restart](feedback-coding-zenka-edits.md) — restart after failed tool task
- [perltidy-sil0](feedback-perltidy-sil0.md) — format-code/ptd `-sil=0` self-heals over-indented modules to col0

## Completed Sessions
- [topic-completed](topic-completed.md) — all session summaries (Feb 2026 → present)

## System Status
- [next-steps](topic-next-steps.md) — full queue, roadmap, open bugs, dispatched
- **letsencr**: fully working on atom + pri.v7.ax; 5-year scheduling bug fixed
- **reasoning.branch.***: LIVE (session 41); 9 modules, ASCII tree via p7c
- **base.cmd.list**: :n: row limit; prefix/suffix/zero-padded; header-aware
- **pager.sort.multi-key**: ntime_b32 + priority_map sort types
- **task dispatch**: all carry ## dispatch + prompt for reuse
- **coding zenka**: fully operational; 9B model loads in seconds
- `bin/todo`: self-contained CLI; add/done/rm/edit/tag/untag/clear; priority
- `ncode doc`: unified lookup; delegates GObject to subprocess
- `smtpd`: receive → YAML + LLM classify → route; xz+twofish archive
- `window.*`: proportional placement; 8 profiles; ticker integrated
- **v7 ondemand auto-register**: `v7.register_ondemand_zenki` re-registers at cube on reload + cube restart; dedup hash `<v7.registered_at_cube>` survives source reload, wiped by cube post-init callback
- [signature endline bug](bug-signature-endline-restoration.md) — RESOLVED: harmonize state-0/7 early-return; state-7 (0-trailing-nl) files oscillated; fix + regression net `test-endline-state7-oscillation`; **test re-sign ≥2 passes to see oscillation**

#,,..,.,,,,.,,...,..,,,.,,.,,,,,,,,,.,.,.,,,,,..,,...,...,,.,,.,,,..,,,.,,.,,,
#NA62WCAUJIZLWZNLJO6VINOMNVRKVGXWBZTPXKTPAM3DQZ7RRPTJ25K37QJS3WANEFJD4AZYH2MFO
#\\\|YI4J6G4MPGIH47OKNPN26PZZTUB2AU7WIPSRVJHVLRLOXK5DELV \ / AMOS7 \ YOURUM ::
#\[7]O2VZPNURHCCMPJ2QHPCVQWJM4PZ4BK763QEHAJBHOQNVPBTWDEDQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
## 2026-06-02 — nshell `(0)` prefix bug fix

**Root cause:** `base.handler.command` orphaned route handler generated `(0)!TERM!` when processing prefix-less replies (`cmd_id == 0`). The `clear` command triggers this via SIZE reply orphan paths.

**Fixes applied:**
- `base.handler.command` lines ~1470, ~1516: added `$cmd_id > 0` guard before `sprintf "(%d)!TERM!\n"` in orphaned route handlers
- `base.protocol-7.command.send.local` line 107: changed wrap regex from `^(\d+)$` to `^([1-9]\d*)$` so `0` never gets wrapped as `(0)`
- `nshell.editor.process`: fixed `terminal_size()[0]` for cols + color reset on empty submit
- `nshell.handler.command_reply`: newline safety before cursor redraw

**Key insight:** The `!TERM!` backchannel logic at line ~565 already guarded with `$tgt_cmd_id > 0`, but the orphaned-route fallback paths did not.

**Diagnostic:** Improved `base.handler.command` syntax error log to show full bad line (`line=['...']`) instead of stripping it.

#,,,.,,,,,,,.,,,,,.,,,,.,,..,,...,,.,,,.,,,,,,..,,...,...,...,...,,..,,,.,...,
#LAFQCCONBTVG4BLVS5URTNJTSTHMRNLM3YFW7BUD3OZKFL4T54D55IWU5TCV4TDR554K36JT7WXCS
#\\\|JSO7PAVB3FKOAGGPMSIQQL3G5SNOPOD47TFXFDZAZQJFZ22QX3G \ / AMOS7 \ YOURUM ::
#\[7]GTUO4DJ4MKNQ3PGPKUS23PLOWIBVFQ3NLDOQQRBDYSYDH66O3SCQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
