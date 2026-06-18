## CRITICAL
- [WSLg deiconify limitation](feedback-wslg-deiconify-limitation.md) — Weston/WSLg blocks deiconify at compositor level; iconify works, nothing deiconifies (X11 or GTK); don't re-investigate unless Weston version changes


- [gtk ondemand zenka startup](feedback-gtk-ondemand-zenka-startup.md) — on-demand gtk3 zenka needs Gtk3->init in init_code + [base.get_session_id] before [base.gtk.main_loop], else silent hang
- [cmd reply must be string](feedback-cmd-data-must-be-string.md) — .cmd./whitelisted routines must return {mode=>true|false, data=>STRING}; split internal helpers (raw hash/undef) into separate non-.cmd. routines + thin wrapper
- [kimi reload baseline noise](feedback-kimi-reload-baseline-noise.md) — don't make kimi prove pre-existing reload errors are pre-existing; check baseline yourself first
- [kimi v7 console hint](feedback-kimi-v7-console-hint.md) — combined v7 console at `/dev/shm/.7/STDOUT/NIW7OAQ`, give kimi this path for live verification
- [File Creation](feedback-file-io-api.md) — never add `#,,.,,,...` stub — blocks signing
- [base. prefix stripped](feedback-base-prefix-stripped.md) — use `<[protocol-7.command.send.local]>` not `base.` prefix; check with `<zenka>.list-subs`
- [.cmd. segment stripped](feedback-cmd-segment-stripped.md) — `<zenka>.cmd.<name>` on disk = callable as `<zenka>.<name>`; verifying live 2026-06-08
- [filter-repo prefix](feedback-filter-repo-amend.md)
- [P7 data nesting](feedback-p7-data-nesting.md) — `<a.b.c>` = `$data{a}{b}{c}`; use underscore for siblings not dot
- [s_warn single-arg](feedback-s-warn-single-arg.md) — single fixed-message warn fixes: use plain `warn 'msg <{C1}>'`, NOT `base.s_warn` padded with `<{C1}>, ''`
- [access grant scope](feedback-access-grant-scope.md) — taeki has wildcard access; "no perm" fixes need `<zenka>/start` modules.load + subroutine.white-list only, not per-zenka access.zenki
- [ondemand zenka start checklist](feedback-ondemand-zenka-start-checklist.md) — full start-file recipe (shared-params, namespaces, drop_privs, net.connect+get_session_id, cube auth.zenki + access.cmd.usr.cube); reasoning zenka LANDED 2026-06-16
- [devmod leave disabled](feedback-devmod-leave-disabled.md) — when adding devmod for diagnostics, leave eval-code/exec-sub/set/del commented out by default
- [timer undef interval](feedback-timer-undef-interval.md) — undef after/interval = IO::Async max-rate loop; always guard with fallback
- [each+continue+keys](feedback-each-continue-keys.md) — `continue{keys %h}` on `while(each %h)` resets iterator = infinite loop — `AMEND=1 git filter-repo ...`; also clear `.git/filter-repo/already_ran` if interrupted
- [ntime](feedback-ntime.md) — `encode_b32r` is reverse-byte-order, NOT sortable; use `<[base.ntime_BASE32_to_numerical]>`
- [eval-code no angle-brackets](feedback-eval-code-no-angle-brackets.md) — `<registry>` not pre-processed in eval-code strings; use `$data{...}` directly
- [zenka config relative paths](feedback-zenka-config-relative-paths.md) — cfg paths must use `<system.root_path>/...`; cwd is /home/protocol-7, not project root
- [Cross-zenka](feedback-cross-zenka-deferred-reply.md) — route-send + SIZE reply only; FS access forbidden
- [Access control](feedback-buffer-access-control.md) — cube/access.zenki is REAL gate
- [httpd](feedback-httpd-deferred-reply.md) — thin proxy; never load plugin.web.*
- [Timers](feedback-timer-module-args.md) — need after + interval + repeat:TRUE
- [Deferred Init](feedback-deferred-init.md) — push onto system.callbacks.initialized
- [Timer Args](feedback-timer-module-args.md) — timer modules get event as $ARG[0]; use `@ARG > 1`
- [config reload clobber](feedback-config-reload-clobber.md) — placeholder `key=val` in start config gets re-applied by `reload config/all`, silently overwriting runtime-resolved values; debug via on-disk zenka log not ring buffer

## Active Topics
- [zenka-naming-cleanup](topic-zenka-naming-cleanup.md) — cred-mesh + window-place renames landed; pattern for spotting/fixing more underscore/dotted zenka names; tile-groups->tile LANDED 2026-06-15 (82e65f2d6); command-name cleanup pass LANDED (switch-group, reset-group, base-group, show-groups, count)
- [ondemand-heartbeat-upgrade](topic-ondemand-heartbeat-upgrade.md) — tile set up on-demand+heartbeat-enabled+no-timeout as test case; two v7 follow-ups identified (exclude heartbeats from idle timer; pre-exit termination notification)
- [mpv-jobqueue-startup](topic-mpv-jobqueue-startup.md) — async startup state machine LANDED 2026-06-18; dep chain fork_player→finalize; send_command no longer exit(2); deferred command queue; open: snapshot/restore + visual curves + player restart job
- [mpv-persistence](topic-mpv-persistence.md) — planned: full state snapshot + visual curve automation + cross-mapped parameter routing; restore via deferred send_command queue
- [x11-multi-server](topic-x11-multi-server.md) — X-11 multi-server jobqueue arch LANDED 2026-06-18; display registry keyed by display str; x11_display_flag dep type; host-mode timing bug fixed; tile display-awareness; xvfb cmds open
- [tile-window-place-hybrid-desktop](topic-tile-window-place-hybrid-desktop.md) — window-place multi-window UNBLOCKED & landed 2026-06-15 (9c899f360, 68dec757b); resident after commit/cancel, 70% centering, multi-monitor fix; tile-as-relay next
- [cube-tree-dashboard](topic-cube-tree-dashboard.md) — planned ascii tree-view dashboard: per-zenka command/state trees, capability interrogation, push-registry watcher cache, zoom/crop
- [ascii-minimap](topic-ascii-minimap.md) — planned btop2-style ascii minimap: proportional density bars, anti-aliased gaps, glow color, spotlight, placeholder-template borders
- [dot-path-case-notation](topic-dot-path-case-notation.md) — uppercase=path level, lowercase-run=dotted key; %DATA/%CODE meta-namespace idea; design doc written
- [deparse-code-features](topic-deparse-code-features.md) — REMINDER: ask user about their planned tree of deparse-code-based features (not yet elaborated)
- [global-ui-menu-tree](topic-global-ui-menu-tree.md) — addressable stdio slots + menu tree; settings (new)/configure (stub) zenki as starting points
- [credential-fabric-proxy-transport](topic-credential-fabric-proxy-transport.md) — scenarios 1/2/3 all passing at max (4/5, 5/5, 2/2); async transport.select LANDED 2026-06-16 (ef11aaec3)
- [ascii-frame-system](topic-ascii-frame-system.md) — reverse parser, elastic renderer, DRC validator
- [frame-plugin-slots](topic-frame-plugin-slots.md) — status-bar plugin slots + context-aware selector; variable border width; vertical-slot roadmap
- [ascii-desktop-domains](topic-ascii-desktop-domains.md) — border glyphs are domain-scoped; nested domains = nested planes = ascii desktop; role-vs-glyph descriptor is the windowing unlock
- [frame-idiom-convergence](topic-frame-idiom-convergence.md) — NEW frame features: margin/vertical-padding/self-invalidating-cache/corner-pinning-spring; `.:[ ]::[ ]:.` idiom; 5 frames still need conversion (REQUIRED)
- [ui-show-security-levels](topic-ui-show-security-levels.md) — steps 1-5 ALL LIVE (36d605896, 2026-06-13); credential_fabric slot name/meta gated; step 6 open
- [os-command-zenka](topic-os-command-zenka.md) — planned: networked command/script templates, security levels, STRM streaming, vterm result buffers
- [plugin-web-jobs](topic-plugin-web-jobs.md) — delta sync WORKING; open: ?since=N, remote deploy
- [clients-http](topic-clients-http.md) — clients.http.* + clients.https.* async; kimi-web parallel dispatch
- [reasoning-chain-repository](topic-reasoning-chain-repository.md) — native model; dedup-based self-improvement
- [reasoning-namespace](topic-reasoning-namespace.md) — `reasoning.*` namespace; 28 templates
- [job-pipeline](topic-job-pipeline.md) — WORKING: jobs.vhost live, German reason+summary
- [task-coordination](topic-task-coordination.md) — task zenka coordinator; dispatch flow
- [checksum-parenting-namespace-trees](topic-checksum-parenting-namespace-trees.md) — `<C0>:<C1>` auto-parenting collision protection; user-trunk/transit-ring/parabolic-mirror riff; design doc dispatched
- [triple-twofish-name-entropy](topic-triple-twofish-name-entropy.md) — fwd-bwd-fwd Twofish on xz payload defeats header-bruteforce; name/checksum as key entropy (new)
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
- [memory-tree-zenka](topic-memory-tree-zenka.md) — tree LIVE; IDF search LIVE; digest pipeline LIVE (2026-06-05); cube.coding.* routing; base. prefix stripped

## Vision / Design
- [incidental-signal-channels](topic-incidental-signal-channels.md) — entropic modulation: alignment/sort/serialization choices double as free statistical-shape signals
- [project-vision-origin](project-vision-origin.md) — 24-year vision; threshold reached Apr 2026
- [layer-matrix-convergence](project-layer-matrix-convergence.md) — self-restart/migration/branching/diff-addressing = one reversible layer-matrix algebra; commutativity is the crux
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
- [harmonic-silence-active-cancellation](topic-harmonic-silence.md) — silence via waveform cancellation = sensing event horizon; regex library as "negative of the world"; canvas of absence for anomaly detection
- [key-tree-ring-routing](topic-key-tree-ring-routing.md) — namespace=C25519 key-tree (authority outward); rings=shared keys (self-removing layers inward); tree answers "who", ring answers "through what"
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
- [claude_dispatch summarize hang](feedback-claude-dispatch-summarize-hang.md) — coding_summarize prompt-overflow leaves outer session stuck forever (near-zero CPU); check ps + coding zenka log, kill PID, work is safe on disk
- [init-code-return-values](feedback-init-code-return-values.md) — TRUE(5) AND FALSE(0) both = success; only undef/exception = failure
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
- [coding-zenka-misc](feedback-coding-zenka-edits.md) — coding_summarize (free 9B, auto default); auto_summarize `decode_json`→`from_json`; session_catchup/store_summary_focus MCP; claude_continue live; Glitter restart-after-fail
- [perltidy-sil0](feedback-perltidy-sil0.md) — format-code/ptd `-sil=0` self-heals over-indented modules to col0
- [design-ideation-capture](feedback-design-ideation-capture.md) — engage substance + offer fold-in/spin-off doc when user riffs unprompted; write immediately once confirmed
- [coding-timeout-restart-loop](feedback-coding-timeout-restart-loop.md) — data-start 13s too short for large prompts (now scales w/ est_tokens); ctx "reduction" on recovery was a no-op (floor≠ceiling) — both fixed 2026-06-08

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

#,,..,,,.,,,,,.,,,.,,,,.,,,,.,.,.,.,.,,..,...,..,,...,...,,,,,..,,.,.,.,,,.,.,
#PFNCEJP4HZYARIKWDP5DDBD7VPJFTHFR3CC76EWCFNDEEBMUZQZJH2LJTAUYYI46X7KBJUHJD6HP4
#\\\|QZFCRMJO7LVJYADUZTWEB3KNDFXPXA2EJO773NP5PTZVMMS7IQK \ / AMOS7 \ YOURUM ::
#\[7]2F4BHSG4UUAKO6WJ6GSFHTZWJE7YBBKYSX22EHVPHT4ZMDI67IBY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
