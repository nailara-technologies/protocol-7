## CRITICAL
- [web-browser ephemeral storage](feedback-web-browser-ephemeral-storage.md) — WebKit ephemeral=1: storage wiped every restart; treat as volatile
- [WSLg deiconify limitation](feedback-wslg-deiconify-limitation.md) — Weston/WSLg blocks deiconify at compositor level
- [UNCOMMITTED 2026-06-20 mpv/X-11 set](topic-mpv-jobqueue-startup.md) — fade_in test values must be reverted before commit
- [gtk-wsl-window-positioning](topic-gtk-wsl-window-positioning.md) / [weston-move-unreliable](feedback-weston-move-unreliable-use-compositor-grab.md) — use begin_move_drag/resize_drag not move(); initial-placement-before-show_all open

## Active Topics
- [p7-log-wire-utf8-double-encoding](topic-p7-log-wire-utf8-double-encoding.md) — LANDED 2973129e6: missing utf8::decode before :encoding(UTF-8) print; devmod.cmd.echo = live wire test tool
- [x11-protocol-hardening](topic-x11-protocol-hardening.md) — COMMITTED 3b966708d + e0f4fddd7: base.exec.with_timeout + dual-connection pool (query-reroute/health-oracle) both landed+verified live
- [x11-resolution-profiles](topic-x11-resolution-profiles.md) — OPEN design: xvfb needs per-purpose resolution profiles (subname `xvfb:WxH` sketch); reconcile with `-\d+` index suffix from bare-name-routing-ambiguity before building
- [x11-bare-name-routing-ambiguity](topic-x11-bare-name-routing-ambiguity.md) — LANDED 770553ad2+505f5505b: generic sid resolver (subname group-match), per-instance display ranges, v7 per-instance display tracking; verified live w/ 3 concurrent instances
- [ondemand-starting-flag-watchdog](topic-ondemand-starting-flag-race.md) — RESOLVED 056597b9b: watchdog rescues stuck-`starting` queue via online-truth check; restart-disabled zenki get 3-strike tolerance
- [orbital-strm-push-rollout](topic-orbital-strm-push-rollout.md) — LANDED 139cacef2: push via STRM not poll; open: connect/disconnect-orbital access
- [async-window-startup-transition](topic-async-window-startup-transition.md) — LANDED 531aa14db, live-verified; CLOSED except rare paint glitch
- [screen-setup-zenka](topic-screen-setup-zenka.md), [amos7-shm-phase1](topic-amos7-shm-phase1.md) — minimap+overlay LIVE; SHM phases 1-3 LANDED, phase 4 open
- [zenka-naming-cleanup](topic-zenka-naming-cleanup.md), [ondemand-heartbeat-upgrade](topic-ondemand-heartbeat-upgrade.md) — renames LANDED; tile=on-demand+heartbeat test case
- [mpv-jobqueue-startup](topic-mpv-jobqueue-startup.md), [mpv-persistence](topic-mpv-persistence.md) — placement+geometry LANDED; persistence planned (snapshot+curve automation)
- [x11-multi-server](topic-x11-multi-server.md), [tile-window-place-hybrid-desktop](topic-tile-window-place-hybrid-desktop.md) — jobqueue+multi-window LANDED; tile-as-relay next
- [cube-tree-dashboard](topic-cube-tree-dashboard.md), [ascii-minimap](topic-ascii-minimap.md) — planned tree-view dashboard; btop2-style minimap w/ glow
- [dot-path-case-notation](topic-dot-path-case-notation.md), [deparse-code-features](topic-deparse-code-features.md) — path-case design written; REMINDER: elaborate deparse-code feature tree
- [global-ui-menu-tree](topic-global-ui-menu-tree.md), [credential-fabric-proxy-transport](topic-credential-fabric-proxy-transport.md) — stdio slots+menu tree planned; transport.select LANDED ef11aaec3
- [ascii-frame-system](topic-ascii-frame-system.md), [frame-plugin-slots](topic-frame-plugin-slots.md), [frame-idiom-convergence](topic-frame-idiom-convergence.md) — parser/renderer/validator; plugin slots; 5 frames need `.:[ ]::[ ]:.` conversion
- [ascii-desktop-domains](topic-ascii-desktop-domains.md), [ui-show-security-levels](topic-ui-show-security-levels.md) — border glyphs unlock nested desktops; steps 1-5 LIVE, step 6 open
- [os-command-zenka](topic-os-command-zenka.md) — planned command templates, security levels, STRM
- [plugin-web-jobs](topic-plugin-web-jobs.md) — LANDED fc6fcb43a+beaf00a87 2026-07-02: watermark/tombstone/scan-order/reassess-dedup fixed live; delete-mid-assessing fix beb1129e5 2026-07-09 + pending_count restart-orphan fix d5f9ba894 2026-07-10 both landed, no longer CRITICAL
- [jobsite-ui-usability](topic-jobsite-ui-usability.md) — CONFIRMED 2026-07-13: always-visible subtle/highlighted apply+skip badges; sync render-gated on actual change + focus/scroll preserved across rebuild
- [coding-zenka-abort-inference](topic-plugin-web-jobs.md), [jobsite-assessment-accuracy](topic-jobsite-assessment-accuracy.md) — LANDED 90537980b abort registry; assessment drops soft facts, fix=consensus_vote
- [clients-http](topic-clients-http.md), [task-coordination](topic-task-coordination.md), [job-pipeline](topic-job-pipeline.md) — async http/https+kimi-web dispatch; task coordinator; jobs.vhost live
- [reasoning-chain-repository](topic-reasoning-chain-repository.md), [reasoning-namespace](topic-reasoning-namespace.md) — dedup-based self-improvement model; `reasoning.*` ns, 28 templates
- [checksum-parenting-namespace-trees](topic-checksum-parenting-namespace-trees.md), [triple-twofish-name-entropy](topic-triple-twofish-name-entropy.md) — `<C0>:<C1>` collision protection; Twofish defeats header-bruteforce
- [coding-state-machine](topic-coding-state-machine.md), [kimi-zenka-state-machine](topic-kimi-zenka-state-machine.md) — coding.state+watcher lock; kimi reconnect open
- [chat-script](topic-chat-script.md), [stream-transport-layer](topic-stream-transport-layer.md), [stream-reply-modes](topic-stream-reply-modes.md) — bin/chat COMPLETE; STRM done (open-0 sentinel open); bounded/unbounded reply modes
- [radio-relay-zenka](topic-radio-relay-zenka.md), [vhost-install](topic-vhost-install.md), [model-load-time-statistics](topic-model-load-time-statistics.md) — radio COMPLETE, phase 5 next; vhost live; planned per-model load stats
- [cursor-model](topic-cursor-model.md), [iris-spoke-labels](topic-iris-spoke-labels.md), [stream-framing-protocol](topic-stream-framing-protocol.md) — hyperspace cursor; 63-ring spoke/BASE32; 3+1 bit frame
- [nshell-terminal-rendering](topic-nshell-terminal-rendering.md), [memory-tree-zenka](topic-memory-tree-zenka.md) — `(0)!TERM!` bug, VIEWING_HISTORY; tree/IDF/digest all LIVE
- [web-browser-param-capture-graphing](web-browser-param-capture-graphing.md) — LANDED cae42647d: reusable live var-graphing tool; root-caused [[topic-zoom-jump-debug-instrumentation]] (RESOLVED)

## Vision / Design
- [project-input-capture-replay-website-templates](project-input-capture-replay-website-templates.md) — design-only: input capture/replay + curve synthesis + state snapshots, unblocks not-yet-built screenshot-driven website templates
- [decision-node-polarity-geometry](topic-decision-node-polarity-geometry.md) — seed: escalation/repelling polarity node = reference-bubble's 5-of-7; "27 subcube inverse 3D-plus" geometry not yet reconciled with node-group-geometry
- [source-identity-spoofing](feedback-source-identity-spoofing.md), [project-vision-origin](project-vision-origin.md) — hostname strings aren't a security boundary, C25519 is; 24-year vision, threshold Apr 2026
- [synchronous-multi-legged-pattern-extraction](topic-synchronous-multi-legged-pattern-extraction.md), [distributed-hybrid-inhabitants](topic-distributed-hybrid-inhabitants.md) — parallel component search ("exoskeleton"); tooling folds in
- [protocol-as-self-governing-authority](topic-protocol-as-self-governing-authority.md), [intelligent-glue-identity](topic-intelligent-glue-identity.md) — emergent governance, resource-efficiency as design value; P7="intelligent glue"
- [resonance-field-emergence](resonance-field-emergence.md), [dedup-tree-unifying-mechanism](topic-dedup-tree-unifying-mechanism.md) — mod-13 vs Rodin mod-9; dedup tree unifies reasoning/task-tree/tiering/QA
- [coding-zenka-improvement-pipeline](coding-zenka-improvement-pipeline.md) — tier0-1.5 done, tier2/3 gated; result_constraint+tiered-escalation UNCOMMITTED since 2026-06-21
- [hybrid-namespace-routing](topic-hybrid-namespace-routing.md), [zenka-macro-language-postponement](project-zenka-macro-language-postponement.md) — 5 routing types, local-wins; intent→code makes destructive intent inexpressible
- [layer-matrix-convergence](project-layer-matrix-convergence.md), [self-improving-system](topic-self-improving-system.md) — restart/migration/branching=one algebra; LLM coordination as foundation
- [network-as-computer](topic-network-as-computer.md), [namespace-tree-intelligence](topic-namespace-tree-intelligence.md), [orbital-data-space](topic-orbital-data-space.md) — network IS computer; tree IS intelligence; zenki-as-satellites
- [distributed-consensus](topic-distributed-consensus.md), [task-tree-design](topic-task-tree-design.md), [self-contained-zenka](topic-self-contained-zenka.md) — multi-model chat; unified task tree; __DATA__ registry/STDIO
- [window-canvas-addressing](topic-window-canvas-addressing.md) — CONVERGED 2026-07-11: canvas/group identity is checksum-addressing (TYPE:CHKSUM7:ADDR_B32), not a new primitive; implementation not started
- [style-philosophy](style-philosophy.md), [harmonic-mathematics](topic-harmonic-mathematics.md), [hyperspace-topology](topic-hyperspace-topology.md) — coding as artform; generator 076923; closed observer loop, sensor cube
- [punctuation-topology](topic-punctuation-topology.md), [field-coherence-synthesis](topic-field-coherence-synthesis.md), [field-capability-emergence](topic-field-capability-emergence.md) — `:`/`.` separators; bridges topology; protocol vs external
- [self-assembling-network](topic-self-assembling-network.md), [creative-field-behaviour](topic-creative-field-behaviour.md) — spec as pre-loaded potential; emergent cooperative dynamics
- [addressing-trinity](topic-addressing-trinity.md), [checksum-addressing](topic-checksum-addressing.md), [node-group-geometry](topic-node-group-geometry.md) — tree+checksums+timestamps; AMOS/BMW384; 8×63 cubes
- [1001](topic-1001.md), [perspective-layers](topic-perspective-layers.md), [observer-centric-space](topic-observer-centric-space.md) — cube tunnel/gate nesting; perspective tree; client always 0
- [routing-crystal](topic-routing-crystal.md), [checksum-tree-wire](topic-checksum-tree-wire.md), [tree-protocol](topic-tree-protocol.md), [data-protocol](topic-data-protocol.md) — cube as crystal; wire separators/pivot; DATA/DELTA sync
- [reference-bubble](topic-reference-bubble.md), [branch-namespace](topic-branch-namespace.md) — rhizome bubble (5+2=7); 58 modules, Z.Y.X coords

## Reference
- [unicode-encoding-repair](reference-unicode-encoding-repair.md), [patterns](topic-patterns.md), [coding-zenka-templates](topic-coding-zenka-templates.md) — double-UTF8 fix tool; core patterns; 50+ templates/16+ tools
- [tool-shm-architecture](topic-tool-shm-architecture.md), [tool-suggestions](topic-tool-suggestions.md), [language-detection](topic-language-detection.md) — SHM+mmap vision; tool suggestions; three-layer, 30 langs
- [site-yaml-zenka](topic-site-yaml-zenka.md), [site-yaml-web-research](topic-site-yaml-web-research.md), [usb-backup-zenka](topic-usb-backup-zenka.md) — URL→YAML; web research; udev→task tree→restore
- [git-watch-zenka](topic-git-watch-zenka.md), [reasoning-design-templates](topic-reasoning-design-templates.md) — force-push detection; 7 viz designs
- [harmonic-silence-active-cancellation](topic-harmonic-silence.md), [key-tree-ring-routing](topic-key-tree-ring-routing.md) — waveform-cancellation silence; namespace=key-tree(who), rings=keys(through what)
- [fetch-files-zenka](topic-fetch-files-zenka.md), [tls-acme](topic-tls-acme.md), [amos7-p7-loader](topic-amos7-p7-loader.md) — huggingface.* LIVE; SNI/SSL/ACME; AMOS7::P7 standalone
- [invoke-model-management](topic-invoke-model-management.md), [invoke-model-manager](topic-invoke-model-manager.md) — uuid vs verbose; planned Term::Clui manager
- [image-archive-system](topic-image-archive-system.md), [base-curve-system](topic-base-curve-system.md) — vision-scored storage; base.curve.* animation
- [friction-visualization](topic-friction-visualization.md), [searchable-index-and-visualization](topic-searchable-index-and-visualization.md), [migration](topic-migration.md) — friction=turbulence; checksum-indexed dataspace; KVM/Debian migration

### Settled conventions
- [cube-auth-name-collision](feedback-cube-auth-name-collision.md) — names matching `(declare|select)-<word>` broke auth; fixed via mandatory auth. prefix
- [zenka shutdown end_code](feedback-zenka-shutdown-end-code-callback.md), [gtk ondemand zenka startup](feedback-gtk-ondemand-zenka-startup.md) — use `push <callbacks.end_code>` not $SIG{}; gtk needs Gtk3->init+get_session_id first
- [cmd reply must be string](feedback-cmd-data-must-be-string.md) — .cmd. routines must return {mode=>true|false, data=>STRING}
- [kimi reload baseline noise](feedback-kimi-reload-baseline-noise.md), [kimi v7 console hint](feedback-kimi-v7-console-hint.md) — check baseline first; console at `/dev/shm/.7/STDOUT/NIW7OAQ`
- [File Creation](feedback-file-io-api.md), [version files every commit](feedback-version-files-every-commit.md) — no `#,,.,,,` stub (blocks signing); version files ride every commit
- [tile openbox dep redundant](feedback-tile-openbox-dependency-redundant.md), [base. prefix stripped](feedback-base-prefix-stripped.md) — tile hang was openbox dep under Weston; use `send.local` not `base.` prefix
- [.cmd. segment stripped](feedback-cmd-segment-stripped.md), [filter-repo prefix](feedback-filter-repo-amend.md), [P7 data nesting](feedback-p7-data-nesting.md) — .cmd. callable w/o segment; <a.b.c>=$data{a}{b}{c}, underscore siblings
- [s_warn single-arg](feedback-s-warn-single-arg.md), [access grant scope](feedback-access-grant-scope.md) — plain `warn` for single-msg; taeki has wildcard, "no perm" needs whitelist only
- [ondemand zenka start checklist](feedback-ondemand-zenka-start-checklist.md), [devmod leave disabled](feedback-devmod-leave-disabled.md) — start-file recipe (shared-params, drop_privs, auth.zenki); leave devmod eval/exec commented
- [timer undef interval](feedback-timer-undef-interval.md), [each+continue+keys](feedback-each-continue-keys.md) — undef after/interval=max-rate, guard it; `continue{keys %h}` resets each-iterator = infinite loop
- [ntime](feedback-ntime.md), [eval-code no angle-brackets](feedback-eval-code-no-angle-brackets.md), [zenka config relative paths](feedback-zenka-config-relative-paths.md) — encode_b32r not sortable; <registry> unexpanded in eval-code; cfg needs <system.root_path>
- [Cross-zenka](feedback-cross-zenka-deferred-reply.md), [Access control](feedback-buffer-access-control.md), [httpd](feedback-httpd-deferred-reply.md) — route-send+SIZE only; access.zenki is REAL gate; httpd never loads plugin.web.*
- [Timer Args](feedback-timer-module-args.md), [Deferred Init](feedback-deferred-init.md) — after+interval+repeat:TRUE, event as $ARG[0]; push onto system.callbacks.initialized
- [config reload clobber](feedback-config-reload-clobber.md), [route-send command format](feedback-route-send-command-format.md) — `reload config/all` overwrites runtime values; route-send has no cube. prefix
- [user-perfectionism-and-pace](user-perfectionism-and-pace.md) — "done" means perfectly smooth; let solo tuning passes run

## Feedback
- [tasks-completed-scan-verdict-trust](feedback-tasks-completed-scan-verdict-trust.md) — "still open" verdicts need spot-checking too, not just "move to completed"; caught 3 false negatives (jobsite-ui trio) in one session
- [coding-zenka buffer rescue](topic-coding-zenka-session9.md) — idle-shutdown backups readable via group-perm `xz -dc`, no sudo; no auto-restore path exists
- [nested-dispatch-session-tracking](feedback-nested-dispatch-session-tracking.md), [webkit vs firefox css blindspots](feedback-webkit-vs-firefox-css-blindspots.md) — auto_summarize lossy, verify via git diff; WebKit misses stacking/`:checked` bugs
- [no sudo for privileged fs ops](feedback-no-sudo-privileged-fs-ops.md) — never `sudo` a protocol-7-owned file; hand command to user
- [perl and/or precedence in my-assignment](feedback-perl-and-or-precedence-in-my-assignment.md) — `my $x = A and B` only assigns A; use && / ||
- [p7 route-send wire protocol](feedback-p7-route-send-wire-protocol.md), [oversize single-line protocol](feedback-oversize-single-line-protocol.md) — SIZE auto-fragments; TRUE/FALSE/WAIT unframed, oversize wedges buffer
- [no unsolicited cross-zenka push](feedback-no-unsolicited-cross-zenka-push.md), [vax-int vs v7-epoch](feedback-vax-int-vs-v7-epoch.md) — consumer always initiates pull; decode epoch dirs with `p7c localtime`
- [log string hygiene](feedback-log-string-hygiene.md), [ondemand timeout tiering](feedback-ondemand-timeout-tiering.md) — base.str.eval_error not raw $EVAL_ERROR; survey existing timeouts by tier first
- [claude_dispatch summarize hang](feedback-claude-dispatch-summarize-hang.md) — prompt-overflow hangs session forever; kill PID, work safe on disk
- [init-code-return-values](feedback-init-code-return-values.md), [memory-sync-timing](feedback-memory-sync-timing.md), [memory-management](feedback-memory-management.md) — TRUE/FALSE both=success; sync at ~42K ctx; tree-structured modules
- [claude-dispatch-strategy](feedback-claude-dispatch-strategy.md), [kimi-code-review](feedback-kimi-code-review.md), [kimi-signatures](feedback-kimi-signatures.md), [kimi-dispatch-pattern](feedback-kimi-dispatch-pattern.md) — kimi orchestration; SUPER::/ns-swap; sig-derail; kimi-task
- [model-precision-analysis](feedback-model-precision-analysis.md), [coding-zenka-edits](feedback-coding-zenka-edits.md) — Qwopus more precise; LLM describes edits, verify results
- [coding-zenka-reasoning](feedback-coding-zenka-reasoning.md), [coding-zenka-inject](feedback-coding-zenka-inject.md) — low reasoning→premature completion; `coding.inject-message` redirect
- [arg-regression](feedback-arg-regression.md), [arg-calling-convention](feedback-arg-calling-convention.md) — $ARG→$_ revert; `@_ ? shift : $ARG`
- [prefer-parsed-config](feedback-prefer-parsed-config.md), [true-false-constants](feedback-true-false-constants.md) — use parsed config not FS rescan; TRUE/FALSE not 0/1
- [web-serialization-and-inlining](feedback-web-serialization-and-inlining.md), [task-show-multiline](feedback-task-show-multiline.md) — parallel JSON+YAML; task.show must escape \n
- [list-return-format](feedback-list-return-format.md), [stop-and-revert](feedback-stop-and-revert.md) — `{mode=>'size', data=>$string}`; stop/revert/confirm root cause first
- [utf8-module-literals](feedback-utf8-module-literals.md), [watcher-state-machines](feedback-watcher-state-machines.md) — non-ASCII corrupts output; IO::Async variable watchers only
- [ncode-tools](feedback-ncode-tools.md), [perltidy-sil0](feedback-perltidy-sil0.md) — use ncode replace/parse-headers; ptd `-sil=0` self-heals indent
- [design-ideation-capture](feedback-design-ideation-capture.md), [coding-timeout-restart-loop](feedback-coding-timeout-restart-loop.md) — offer spin-off doc on riffs; data-start scales w/ est_tokens

## Completed Sessions
- [topic-completed](topic-completed.md) — all session summaries (Feb 2026 → present)
- [httpd route-arg parsing fix](topic-httpd-route-arg-parsing-fix.md), [jobsite stray-job recovery](topic-jobsite-stray-recovery.md) — LANDED 20bdf36ff / a52a6a4b8

## System Status
- [next-steps](topic-next-steps.md) — queue, roadmap
- letsencr working; reasoning.branch.* LIVE; coding zenka operational; ondemand auto-register survives reload
- [signature endline bug](bug-signature-endline-restoration.md) — RESOLVED: state-0/7 harmonized; test re-sign ≥2 passes to see oscillation

#,,..,,.,,.,.,,,.,,,.,...,,..,...,.,.,,,.,,,,,..,,...,..,,...,...,,..,,..,.,.,
#MSDZIM7MIYSRAGU5B7GMSOZ5NQMPVLRJTENAA2APF4HJIVED6623KAMPUSRY53IWE4NZ6LCWD4CNM
#\\\|RYRXRJCPRS6NG6RTBUFPNSP6CDK7FJS7LYDCGCKZKUKC3JVUKOL \ / AMOS7 \ YOURUM ::
#\[7]CHCVP2QCHB5OH3H43EJEEXA2DEDVBHSZJRRTI45S4CLJ5PQGPOCI 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
