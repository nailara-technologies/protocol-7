## CRITICAL
- [web-browser ephemeral storage](feedback-web-browser-ephemeral-storage.md) — WebKit ephemeral=1: storage wiped every restart
- [WSLg deiconify limitation](feedback-wslg-deiconify-limitation.md) — Weston/WSLg blocks deiconify at compositor level
- [gtk-wsl-window-positioning](topic-gtk-wsl-window-positioning.md) / [weston-move-unreliable](feedback-weston-move-unreliable-use-compositor-grab.md) — begin_move_drag not move(); window.place grab-leak fixed fff81c212, initial-placement-before-show_all still open

## Active Topics
- [p7-log-wire-utf8-double-encoding](topic-p7-log-wire-utf8-double-encoding.md) — LANDED 2973129e6; devmod.cmd.echo = wire test tool
- [x11-protocol-hardening](topic-x11-protocol-hardening.md) — LANDED+verified 3b966708d+e0f4fddd7
- [x11-resolution-profiles](topic-x11-resolution-profiles.md) — OPEN: per-purpose xvfb profiles; reconcile w/ routing-ambiguity first
- [x11-bare-name-routing-ambiguity](topic-x11-bare-name-routing-ambiguity.md) — LANDED 770553ad2+505f5505b, verified live
- [ondemand-starting-flag-watchdog](topic-ondemand-starting-flag-race.md) — RESOLVED 056597b9b
- [orbital-strm-push-rollout](topic-orbital-strm-push-rollout.md) — LANDED 139cacef2; open: connect/disconnect-orbital access
- [async-window-startup-transition](topic-async-window-startup-transition.md) — LANDED 531aa14db, CLOSED (rare paint glitch only)
- [screen-setup-zenka](topic-screen-setup-zenka.md), [amos7-shm-phase1](topic-amos7-shm-phase1.md) — minimap+overlay LIVE; SHM phase 4 open
- [zenka-naming-cleanup](topic-zenka-naming-cleanup.md), [ondemand-heartbeat-upgrade](topic-ondemand-heartbeat-upgrade.md) — renames LANDED; tile test case
- [mpv-jobqueue-startup](topic-mpv-jobqueue-startup.md), [mpv-persistence](topic-mpv-persistence.md) — placement+geometry LANDED; persistence planned
- [x11-multi-server](topic-x11-multi-server.md), [tile-window-place-hybrid-desktop](topic-tile-window-place-hybrid-desktop.md) — LANDED
- [cube-tree-dashboard](topic-cube-tree-dashboard.md), [ascii-minimap](topic-ascii-minimap.md) — planned tree-view, btop2 minimap
- [dot-path-case-notation](topic-dot-path-case-notation.md), [deparse-code-features](topic-deparse-code-features.md) — path-case written; deparse tree later
- [global-ui-menu-tree](topic-global-ui-menu-tree.md), [credential-fabric-proxy-transport](topic-credential-fabric-proxy-transport.md) — menu tree planned; transport.select LANDED
- [ascii-frame-system](topic-ascii-frame-system.md), [frame-plugin-slots](topic-frame-plugin-slots.md), [frame-idiom-convergence](topic-frame-idiom-convergence.md) — parser/renderer/validator; 5 frames pending
- [ascii-desktop-domains](topic-ascii-desktop-domains.md), [ui-show-security-levels](topic-ui-show-security-levels.md) — border glyphs nest desktops; step 6 open
- [os-command-zenka](topic-os-command-zenka.md) — planned command templates, security levels, STRM
- [coding-round-timeout-adaptive](topic-coding-round-timeout-adaptive.md) — LANDED 411b5635c: soft/hard ceiling, stall detect, restart-round
- [plugin-web-jobs](topic-plugin-web-jobs.md) — LANDED, all fixes live through 2026-07-10, no longer CRITICAL
- [jobsite-ui-usability](topic-jobsite-ui-usability.md) — CONFIRMED: badges + render-gated sync, focus preserved
- [coding-zenka-abort-inference](topic-plugin-web-jobs.md), [jobsite-assessment-accuracy](topic-jobsite-assessment-accuracy.md) — LANDED; fix=consensus_vote
- [clients-http](topic-clients-http.md), [task-coordination](topic-task-coordination.md), [job-pipeline](topic-job-pipeline.md) — async http dispatch; jobs.vhost live
- [reasoning-chain-repository](topic-reasoning-chain-repository.md), [reasoning-namespace](topic-reasoning-namespace.md) — dedup self-improvement; `reasoning.*` ns
- [checksum-parenting-namespace-trees](topic-checksum-parenting-namespace-trees.md), [triple-twofish-name-entropy](topic-triple-twofish-name-entropy.md)
- [coding-state-machine](topic-coding-state-machine.md), [kimi-zenka-state-machine](topic-kimi-zenka-state-machine.md) — reconnect open
- [chat-script](topic-chat-script.md), [stream-transport-layer](topic-stream-transport-layer.md), [stream-reply-modes](topic-stream-reply-modes.md) — COMPLETE
- [radio-relay-zenka](topic-radio-relay-zenka.md), [vhost-install](topic-vhost-install.md), [model-load-time-statistics](topic-model-load-time-statistics.md) — COMPLETE
- [cursor-model](topic-cursor-model.md), [iris-spoke-labels](topic-iris-spoke-labels.md), [stream-framing-protocol](topic-stream-framing-protocol.md)
- [nshell-terminal-rendering](topic-nshell-terminal-rendering.md), [memory-tree-zenka](topic-memory-tree-zenka.md) — tree LIVE
- [web-browser-param-capture-graphing](web-browser-param-capture-graphing.md) — LANDED cae42647d; root-caused zoom-momentum bug
- [input-capture-replay-website-templates](project-input-capture-replay-website-templates.md) — LANDED 2026-07-16, kimi K3
- [web-browser-value-replay-waypoints](project-web-browser-value-replay-waypoints.md) — LANDED 2026-07-17, kimi K3; multi-window fan-out + access.zenki fix

## Vision / Design
- [implicit-perspective-navigation](topic-implicit-perspective-navigation.md) — curves/thresholds ARE the nav decision; explicit/implicit/magnetic modes; design-only
- [dynamic-dependency-resolution](topic-dynamic-dependency-resolution.md) — local-capability-first, then preference match, then discovered capability chains
- [decision-node-polarity-geometry](topic-decision-node-polarity-geometry.md) — seed: polarity node = reference-bubble's 5-of-7; not yet reconciled w/ node-group-geometry
- [source-identity-spoofing](feedback-source-identity-spoofing.md), [project-vision-origin](project-vision-origin.md) — hostnames aren't a security boundary, C25519 is; 24yr vision
- [synchronous-multi-legged-pattern-extraction](topic-synchronous-multi-legged-pattern-extraction.md), [distributed-hybrid-inhabitants](topic-distributed-hybrid-inhabitants.md) — parallel component search
- [protocol-as-self-governing-authority](topic-protocol-as-self-governing-authority.md), [intelligent-glue-identity](topic-intelligent-glue-identity.md) — P7="intelligent glue"
- [resonance-field-emergence](resonance-field-emergence.md), [dedup-tree-unifying-mechanism](topic-dedup-tree-unifying-mechanism.md) — mod-13 vs Rodin mod-9; dedup tree unifies reasoning/tiering/QA
- [coding-zenka-improvement-pipeline](coding-zenka-improvement-pipeline.md) — tier0-2 LANDED 2bdc09631, tier3 gated
- [hybrid-namespace-routing](topic-hybrid-namespace-routing.md), [zenka-macro-language-postponement](project-zenka-macro-language-postponement.md) — 5 routing types; local-wins
- [layer-matrix-convergence](project-layer-matrix-convergence.md), [self-improving-system](topic-self-improving-system.md) — restart/migration/branching=one algebra
- [network-as-computer](topic-network-as-computer.md), [namespace-tree-intelligence](topic-namespace-tree-intelligence.md), [orbital-data-space](topic-orbital-data-space.md) — zenki-as-satellites
- [distributed-consensus](topic-distributed-consensus.md), [task-tree-design](topic-task-tree-design.md), [self-contained-zenka](topic-self-contained-zenka.md)
- [window-canvas-addressing](topic-window-canvas-addressing.md) — CONVERGED: identity = checksum-addressing, not new primitive; not started
- [style-philosophy](style-philosophy.md), [harmonic-mathematics](topic-harmonic-mathematics.md), [hyperspace-topology](topic-hyperspace-topology.md) — coding as artform
- [punctuation-topology](topic-punctuation-topology.md), [field-coherence-synthesis](topic-field-coherence-synthesis.md), [field-capability-emergence](topic-field-capability-emergence.md) — `:`/`.` separators
- [self-assembling-network](topic-self-assembling-network.md), [creative-field-behaviour](topic-creative-field-behaviour.md) — pre-loaded potential
- [addressing-trinity](topic-addressing-trinity.md), [checksum-addressing](topic-checksum-addressing.md), [node-group-geometry](topic-node-group-geometry.md) — tree+checksums+timestamps
- [1001](topic-1001.md), [perspective-layers](topic-perspective-layers.md), [observer-centric-space](topic-observer-centric-space.md) — cube tunnel/gate nesting
- [routing-crystal](topic-routing-crystal.md), [checksum-tree-wire](topic-checksum-tree-wire.md), [tree-protocol](topic-tree-protocol.md), [data-protocol](topic-data-protocol.md)
- [reference-bubble](topic-reference-bubble.md), [branch-namespace](topic-branch-namespace.md) — rhizome bubble (5+2=7); Z.Y.X coords

## Reference
- [unicode-encoding-repair](reference-unicode-encoding-repair.md), [patterns](topic-patterns.md), [coding-zenka-templates](topic-coding-zenka-templates.md) — UTF8 fix; core patterns
- [tool-shm-architecture](topic-tool-shm-architecture.md), [tool-suggestions](topic-tool-suggestions.md), [language-detection](topic-language-detection.md) — SHM+mmap vision; 30 langs
- [site-yaml-zenka](topic-site-yaml-zenka.md), [site-yaml-web-research](topic-site-yaml-web-research.md), [usb-backup-zenka](topic-usb-backup-zenka.md) — URL→YAML; web research; udev→restore
- [git-watch-zenka](topic-git-watch-zenka.md), [reasoning-design-templates](topic-reasoning-design-templates.md) — force-push detection; 7 viz designs
- [harmonic-silence-active-cancellation](topic-harmonic-silence.md), [key-tree-ring-routing](topic-key-tree-ring-routing.md) — waveform-cancellation; namespace=key-tree, rings=keys
- [fetch-files-zenka](topic-fetch-files-zenka.md), [tls-acme](topic-tls-acme.md), [amos7-p7-loader](topic-amos7-p7-loader.md) — huggingface.* LIVE; SNI/SSL/ACME
- [invoke-model-management](topic-invoke-model-management.md), [invoke-model-manager](topic-invoke-model-manager.md) — uuid vs verbose; Term::Clui planned
- [image-archive-system](topic-image-archive-system.md), [base-curve-system](topic-base-curve-system.md) — vision-scored storage; base.curve.* animation
- [friction-visualization](topic-friction-visualization.md), [searchable-index-and-visualization](topic-searchable-index-and-visualization.md), [migration](topic-migration.md) — checksum-indexed dataspace; KVM/Debian migration

### Settled conventions
- [cube-auth-name-collision](feedback-cube-auth-name-collision.md) — names matching `(declare|select)-<word>` broke auth; mandatory auth. prefix
- [zenka shutdown end_code](feedback-zenka-shutdown-end-code-callback.md), [gtk ondemand zenka startup](feedback-gtk-ondemand-zenka-startup.md) — `push <callbacks.end_code>` not $SIG{}; gtk needs Gtk3->init first
- [cmd reply must be string](feedback-cmd-data-must-be-string.md) — .cmd. routines must return {mode=>true|false, data=>STRING}
- [kimi reload baseline noise](feedback-kimi-reload-baseline-noise.md), [kimi v7 console hint](feedback-kimi-v7-console-hint.md) — check baseline first; console at `/dev/shm/.7/STDOUT/NIW7OAQ`
- [File Creation](feedback-file-io-api.md), [version files every commit](feedback-version-files-every-commit.md) — no fake signature stub; version files ride every commit
- [tile openbox dep redundant](feedback-tile-openbox-dependency-redundant.md), [base. prefix stripped](feedback-base-prefix-stripped.md) — use `send.local` not `base.`
- [.cmd. segment stripped](feedback-cmd-segment-stripped.md), [filter-repo prefix](feedback-filter-repo-amend.md), [P7 data nesting](feedback-p7-data-nesting.md) — .cmd. callable w/o segment; <a.b.c>=$data{a}{b}{c}
- [s_warn single-arg](feedback-s-warn-single-arg.md), [access grant scope](feedback-access-grant-scope.md) — plain `warn` for single-msg; "no perm" needs whitelist only
- [ondemand zenka start checklist](feedback-ondemand-zenka-start-checklist.md), [devmod leave disabled](feedback-devmod-leave-disabled.md) — start-file recipe; leave devmod eval/exec commented
- [timer undef interval](feedback-timer-undef-interval.md), [each+continue+keys](feedback-each-continue-keys.md) — undef after/interval=max-rate; `continue{keys %h}` = infinite loop
- [ntime](feedback-ntime.md), [eval-code no angle-brackets](feedback-eval-code-no-angle-brackets.md), [zenka config relative paths](feedback-zenka-config-relative-paths.md) — cfg needs <system.root_path>
- [Cross-zenka](feedback-cross-zenka-deferred-reply.md), [Access control](feedback-buffer-access-control.md), [httpd](feedback-httpd-deferred-reply.md) — httpd never loads plugin.web.*
- [Timer Args](feedback-timer-module-args.md), [Deferred Init](feedback-deferred-init.md) — push onto system.callbacks.initialized
- [config reload clobber](feedback-config-reload-clobber.md), [route-send command format](feedback-route-send-command-format.md) — `reload config/all` overwrites runtime; no cube. prefix
- [user-perfectionism-and-pace](user-perfectionism-and-pace.md) — "done" means perfectly smooth; let solo tuning passes run

## Feedback
- [tasks-completed-scan-verdict-trust](feedback-tasks-completed-scan-verdict-trust.md) — "still open" as unreliable as "move to completed"; 31/52 false negs 2026-07-17, incl. live auth gap
- [kimi-dispatch-infra-hardening](topic-kimi-dispatch-infra-hardening.md) — --afk flag, k3/k2.7/k2.7-fast model routing; MCP bridge timeout ≠ dispatch failure
- [kimi-k3-thinking-effort](topic-kimi-k3-thinking-effort.md) — Low/High/Max in vendor UI, not yet in API/installed CLI
- [coding-zenka buffer rescue](topic-coding-zenka-session9.md) — idle-shutdown backups readable via group-perm `xz -dc`, no sudo
- [nested-dispatch-session-tracking](feedback-nested-dispatch-session-tracking.md), [webkit vs firefox css blindspots](feedback-webkit-vs-firefox-css-blindspots.md) — auto_summarize lossy, verify via git diff
- [no sudo for privileged fs ops](feedback-no-sudo-privileged-fs-ops.md) — never `sudo` a protocol-7-owned file; hand command to user
- [perl and/or precedence in my-assignment](feedback-perl-and-or-precedence-in-my-assignment.md) — `my $x = A and B` only assigns A; use && / ||
- [p7 route-send wire protocol](feedback-p7-route-send-wire-protocol.md), [oversize single-line protocol](feedback-oversize-single-line-protocol.md) — oversize wedges buffer
- [no unsolicited cross-zenka push](feedback-no-unsolicited-cross-zenka-push.md), [vax-int vs v7-epoch](feedback-vax-int-vs-v7-epoch.md) — consumer pulls; `p7c localtime`
- [log string hygiene](feedback-log-string-hygiene.md), [ondemand timeout tiering](feedback-ondemand-timeout-tiering.md) — not raw $EVAL_ERROR
- [claude_dispatch summarize hang](feedback-claude-dispatch-summarize-hang.md) — prompt-overflow hangs; kill PID, work safe on disk
- [init-code-return-values](feedback-init-code-return-values.md), [memory-sync-timing](feedback-memory-sync-timing.md), [memory-management](feedback-memory-management.md) — TRUE/FALSE=success
- [claude-dispatch-strategy](feedback-claude-dispatch-strategy.md), [kimi-code-review](feedback-kimi-code-review.md), [kimi-signatures](feedback-kimi-signatures.md), [kimi-dispatch-pattern](feedback-kimi-dispatch-pattern.md)
- [model-precision-analysis](feedback-model-precision-analysis.md), [coding-zenka-edits](feedback-coding-zenka-edits.md) — verify LLM-described edits
- [coding-zenka-reasoning](feedback-coding-zenka-reasoning.md), [coding-zenka-inject](feedback-coding-zenka-inject.md) — low reasoning→premature completion
- [arg-regression](feedback-arg-regression.md), [arg-calling-convention](feedback-arg-calling-convention.md) — `@_ ? shift : $ARG`
- [prefer-parsed-config](feedback-prefer-parsed-config.md), [true-false-constants](feedback-true-false-constants.md)
- [web-serialization-and-inlining](feedback-web-serialization-and-inlining.md), [task-show-multiline](feedback-task-show-multiline.md) — task.show escapes \n
- [list-return-format](feedback-list-return-format.md), [stop-and-revert](feedback-stop-and-revert.md) — root cause first
- [utf8-module-literals](feedback-utf8-module-literals.md), [watcher-state-machines](feedback-watcher-state-machines.md)
- [ncode-tools](feedback-ncode-tools.md), [perltidy-sil0](feedback-perltidy-sil0.md) — use ncode replace/parse-headers; ptd `-sil=0` self-heals
- [git-log-all-false-duplication](feedback-git-log-all-false-duplication.md) — false "dup commits" = pager strips +/-, colors lost
- [design-ideation-capture](feedback-design-ideation-capture.md), [coding-timeout-restart-loop](feedback-coding-timeout-restart-loop.md) — offer spin-off docs

## Completed Sessions
- [topic-completed](topic-completed.md) — all session summaries (Feb 2026 → present)
- [httpd route-arg parsing fix](topic-httpd-route-arg-parsing-fix.md), [jobsite stray-job recovery](topic-jobsite-stray-recovery.md) — LANDED 20bdf36ff / a52a6a4b8

## System Status
- [next-steps](topic-next-steps.md) — queue, roadmap
- letsencr working; reasoning.branch.* LIVE; coding zenka operational
- [signature endline bug](bug-signature-endline-restoration.md) — RESOLVED: state-0/7 harmonized

#,,..,,,,,,,,,.,,,..,,..,,.,,,,,,,..,,...,.,,,..,,...,...,,..,,,.,...,,,,,,.,,
#ZLH6HUAPUMCDBWENYI6J7LRMDJ6FOXY3D6PKA4QVVML7RGM26KFTYCYIAABA6HRHXVK64RJPE5TE2
#\\\|5CALZWHSMTRDAZ6WBK5HS3ZIYTYXZNVYW6XKU6XL3FE2SEPGWDN \ / AMOS7 \ YOURUM ::
#\[7]HITD6MFP4NRTB474A2DNEKUBEUS6CIYCGNVJBTDTVP337ONPVADA 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
