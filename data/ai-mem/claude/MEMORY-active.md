# MEMORY-active — Active Topics

in-flight and recently-landed work: x11/window placement, mpv, ascii-frame/desktop UI,
coding & kimi zenka state machines, jobsite, streaming transport, web-browser capture/replay,
reasoning namespace, orbital/STRM push, credential-fabric transport.

## Active Topics
- [v7-prio-starvation-and-ansi-corruption](topic-v7-prio-starvation-and-ansi-corruption-2026-07-25.md) — LANDED 1391ba11b: v7.zenka.start prio=>0 fixes 11yr-inert starvation bug; -vvvq ANSI chase inconclusive (likely WezTerm-side); write-completion-loop fixes + base.stdout.raw_fh redirect utility
- [p7-text-formats-landed](topic-p7-text-formats-landed.md) — LANDED: format.kv_block (retired/kept) + format.inline-nested (promoted to base.*, show-access consolidated onto it); OPEN: yaml-config-codegen, reverse perl->p7, comment-preserving config-writer parser
- [format-code-bugs-fixed](topic-format-code-bugs-fixed.md) — LANDED: 17 bugs/features via dogfooding; applied clean to 13 namespaces/areas incl. base/coding/models/bin; perltidy-rejoin gap + whitespace-column list style + regex-literal safety + jobsite-apply still open
- [fake-signature-footer-detection](topic-fake-signature-footer-detection.md) — LANDED c5b78611a-adjacent: source.extract_sig_body now catches a sequential-pattern LLM-hallucinated fake footer that slipped past the existing PLACEHOLDER/size-mismatch checks; related session-37 "1 char too long" bug still open
- [agent-dispatch-worktree-isolation-escaped](feedback-agent-dispatch-worktree-isolation-escaped.md) — FEEDBACK: a nested Agent dispatch with isolation:worktree still corrupted the main working tree (agent's own cd + wrong-commit self-revert); fully recovered via git checkout HEAD, no commits touched; don't trust that isolation mode unverified
- [perl-mod-reload-redefined-warnings](project-perl-mod-reload-subroutine-redefined-warnings.md) — OPEN bug, unrelated to any content change: cube's `reload perl-mods` doesn't clear old symbol-table entries first, so every sub in a reloaded .pm warns "redefined"; mod-test zenka exists to fix this, not yet done
- [startup-race-send-before-connect](feedback-startup-race-send-before-connect.md) — LANDED 55abd6848+d6fdc1dc1; recurring bug class, 3 fix shapes, diagnostic technique
- [strm-subscription-evolution](topic-strm-subscription-evolution.md) — vision: reflection-vector → variable-target/fixed-suffix → STRM → future route-less pubkey channels
- [p7-log-wire-utf8-double-encoding](topic-p7-log-wire-utf8-double-encoding.md) — LANDED 2973129e6; devmod.cmd.echo = wire test tool
- [x11-protocol-hardening](topic-x11-protocol-hardening.md) — LANDED+verified 3b966708d+e0f4fddd7
- [x11-resolution-profiles](topic-x11-resolution-profiles.md) — OPEN: per-purpose xvfb profiles; reconcile w/ routing-ambiguity first
- [x11-bare-name-routing-ambiguity](topic-x11-bare-name-routing-ambiguity.md) — LANDED 770553ad2+505f5505b, verified live
- [ondemand-starting-flag-watchdog](topic-ondemand-starting-flag-race.md) — RESOLVED 056597b9b
- [orbital-strm-push-rollout](topic-orbital-strm-push-rollout.md) — LANDED; open: connect/disconnect-orbital access
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
- [coding-round-timeout-adaptive](topic-coding-round-timeout-adaptive.md) — LANDED: soft/hard ceiling, stall detect, restart-round
- [coding-round-timeout-no-autorestart-observed-2026-07-26](project-coding-round-timeout-no-autorestart-observed-2026-07-26.md) — FOLLOW-UP NEEDED: round hit 175% of ceiling with no auto-restart, manually aborted, not yet root-caused
- [audio-waveform-visualization-landed-2026-07-26](project-audio-waveform-visualization-landed-2026-07-26.md) — LANDED (kimi K3): new `audio` zenka, PDL-FFT+Imager standing-wave renderer, tested clean on 4 samples incl. saturnians.mp3 generalization case; pending human sign-off on 7 modules + 4 config files + 2 cube edits
- [audio-icon-three-stage-pipeline-landed-2026-07-27](project-audio-icon-three-stage-pipeline-landed-2026-07-27.md) — LANDED: 3rd orthogonal `audio.cfg.overlay` axis alongside render_style/post_process; `audio.overlay.waveform_trace.v1` draws translucent phosphor-green min/max amplitude trace over a background (true per-pixel alpha, not black-fill-blended opacity); icon use case = v3 render + rotation_stack.v4 mirror bg + waveform foreground, live-verified via p7c
- [audio-spatial-purr-icon-landed-2026-07-27](project-audio-spatial-purr-icon-landed-2026-07-27.md) — LANDED: audio.cmd.spatial-purr-icon, fixed-recipe sibling of spatial-purr via a per-call `pipeline` override in audio.finalize_decode (falls back to audio.cfg.* untouched), auto-crops wide via crop_wide.v1 when format_hint says so; keeps devmod experimentation on audio.cfg.* independent from "the current best, always working" command; had to add cmd to access.cmd.usr.cube before gen-sub-whitelist would discover it
- [povray-zenka-milestone1-landed-2026-07-27](project-povray-zenka-milestone1-landed-2026-07-27.md) — LANDED (kimi K3, 2nd dispatch attempt after mcp-server-p7 fix): async POV-Ray render pipeline mirroring audio's IPC::Open3 pattern; live-verified incl. non-blocking event loop during an active render; v7.register_child perm gap fixed same as audio's; not yet wired into audio zenka
- [plugin-web-jobs](topic-plugin-web-jobs.md) — LANDED, all fixes live through 2026-07-10, no longer CRITICAL
- [jobsite-ui-usability](topic-jobsite-ui-usability.md) — CONFIRMED: badges + render-gated sync, focus preserved
- [user-interleaves-debt-cleanup-with-creative-work](user-interleaves-debt-cleanup-with-creative-work.md) — this user runs dedicated backlog-clearing sessions between feature work (audio waveform viz, povray pipeline) and values them explicitly, not just as overhead
- jobsite tech-debt catch-up, 2026-07-28 session — a full backlog-clearing
  session, all LANDED same day: assess/repair dispatch watchdog timer +
  attempt-token stale-reply guard (65bbe1380); repair-done
  status='assessed' dead-end sibling fix (52e7c5fef); import-url feature
  spanning 3 entry points (p7c/HTTP/UI), kimi K3 dispatch reviewed +
  live-tested with 4 real postings (d3b0da9d8, c6e041563); configurable
  jobsite.cfg.assessment_model + base.handler.command opened_at/started_at
  undef-comparison fix (a56aa438e); coding.event.on_task_complete
  multi-waiter bug -- only resolved the first deferred reply per task_id,
  silently orphaning any other caller watching the same task (3ae52794a);
  jobsite.job.write orphaned-status-file defensive scan, kimi K3 dispatch,
  live-verified against a real leftover orphan (876981faf); jobsite.cmd.reset
  never decoded a short job_id= to raw numeric form -- silently created a
  near-empty record under the wrong index key, colliding on disk with the
  real job's file (vax-int.encode of both happens to produce the same
  filename) -- fixed (451c5e44e), root-caused live via one job (Amprion/
  ZKP5U) that kept reappearing in trash with score but no title/company;
  confirmed the watchdog's attempt-token guard is NOT implicated (reply
  routing is per-connection state, can't survive a restart to slip past
  it); separately confirmed the restart re-wire logic's own documented
  "narrow, restart-timing-window edge case" gap in jobsite.init_code is
  real and was what re-surfaced the deleted job after a restart -- judged
  an acceptable, already-deliberate tradeoff, not fixed further; job fully
  purged (file + in-memory index + tasks) once the reset bug was fixed. see
  [[reference-jobsite-vax-int-id-scheme]] for the id-scheme forensics that
  came out of this session.
- [jobsite-reports-archive-vision](project-jobsite-reports-archive-vision.md) — vision, "step by step": archive tying sent CSV/PDF reports to source rejection emails, for periodic jobcenter proof; blocked on a mail-reading zenka existing
- [coding-zenka-abort-inference](topic-plugin-web-jobs.md), [jobsite-assessment-accuracy](topic-jobsite-assessment-accuracy.md) — LANDED; fix=consensus_vote
- [clients-http](topic-clients-http.md), [task-coordination](topic-task-coordination.md), [job-pipeline](topic-job-pipeline.md) — async http dispatch; jobs.vhost live
- [reasoning-chain-repository](topic-reasoning-chain-repository.md), [reasoning-namespace](topic-reasoning-namespace.md) — dedup self-improvement; `reasoning.*` ns
- [checksum-parenting-namespace-trees](topic-checksum-parenting-namespace-trees.md), [triple-twofish-name-entropy](topic-triple-twofish-name-entropy.md)
- [coding-state-machine](topic-coding-state-machine.md), [kimi-zenka-state-machine](topic-kimi-zenka-state-machine.md) — reconnect open
- [chat-script](topic-chat-script.md), [stream-transport-layer](topic-stream-transport-layer.md), [stream-reply-modes](topic-stream-reply-modes.md)
- [radio-relay-zenka](topic-radio-relay-zenka.md), [vhost-install](topic-vhost-install.md), [model-load-time-statistics](topic-model-load-time-statistics.md)
- [cursor-model](topic-cursor-model.md), [iris-spoke-labels](topic-iris-spoke-labels.md), [stream-framing-protocol](topic-stream-framing-protocol.md)
- [nshell-terminal-rendering](topic-nshell-terminal-rendering.md), [memory-tree-zenka](topic-memory-tree-zenka.md) — tree LIVE
- [web-browser-param-capture-graphing](web-browser-param-capture-graphing.md) — LANDED; root-caused zoom-momentum bug
- [input-capture-replay-website-templates](project-input-capture-replay-website-templates.md) — LANDED, kimi K3
- [web-browser-value-replay-waypoints](project-web-browser-value-replay-waypoints.md) — LANDED, kimi K3; multi-window fan-out + access.zenki fix
- [scratchpad-import-tool](topic-scratchpad-import-tool.md), [scratchpad-rescue-coding-zenka-task](topic-scratchpad-rescue-coding-zenka-task.md) — mcp-server-p7 scratchpad tools tested; follow-up task filed w/ kimi K3 for native coding-zenka rescue tools + chmod g+rx fix
- [ncode-pattern-learning-loop](topic-ncode-pattern-learning-loop.md) — design, not built: two-tier mechanical/LLM pattern model, reuse existing stats/confidence fields for self-reinforcement, LLM-prefers-editing-patterns interaction model, namespace scope gating, nested-dispatch for batch-apply without confirmation storms; next step is the pattern-schema fix (steps not persisted) blocking the loop

#,,..,...,,..,..,,.,.,.,,,,,,,..,,,,.,,,.,.,,,..,,...,...,...,,,.,.,,,,..,..,,
#H5RRNFMLIBDHFDKM34PRODQGY5KYHYV6JHBOBY5I7B3OBI2KOTTZANEMVSUYFTVMOTUYK4RP5O6R4
#\\\|BZUSK6D72QHBLNGNO5QB2AWTVSSICRQD3KCRCDTSN4BV6E7ZHGM \ / AMOS7 \ YOURUM ::
#\[7]4IXLDWF5TJRZG2VG66HGPOZLP3Y7IJOEHVHFSZJDWSN2S6FIHWBA 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
