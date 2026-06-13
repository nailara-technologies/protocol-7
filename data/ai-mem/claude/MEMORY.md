## CRITICAL
- [kimi reload baseline noise](feedback-kimi-reload-baseline-noise.md) — don't make kimi prove pre-existing reload errors are pre-existing; check baseline yourself first
- [kimi v7 console hint](feedback-kimi-v7-console-hint.md) — combined v7 console at `/dev/shm/.7/STDOUT/NIW7OAQ`, give kimi this path for live verification
- [File Creation](feedback-file-io-api.md) — never add `#,,.,,,...` stub — blocks signing
- [base. prefix stripped](feedback-base-prefix-stripped.md) — use `<[protocol-7.command.send.local]>` not `base.` prefix; check with `<zenka>.list-subs`
- [.cmd. segment stripped](feedback-cmd-segment-stripped.md) — `<zenka>.cmd.<name>` on disk = callable as `<zenka>.<name>`; verifying live 2026-06-08
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
- [config reload clobber](feedback-config-reload-clobber.md) — placeholder `key=val` in start config gets re-applied by `reload config/all`, silently overwriting runtime-resolved values; debug via on-disk zenka log not ring buffer

## Active Topics
- [cube-tree-dashboard](topic-cube-tree-dashboard.md) — planned ascii tree-view dashboard: per-zenka command/state trees, capability interrogation, push-registry watcher cache, zoom/crop
- [ascii-minimap](topic-ascii-minimap.md) — planned btop2-style ascii minimap: proportional density bars, anti-aliased gaps, glow color, spotlight, placeholder-template borders
- [dot-path-case-notation](topic-dot-path-case-notation.md) — uppercase=path level, lowercase-run=dotted key; %DATA/%CODE meta-namespace idea; design doc written
- [deparse-code-features](topic-deparse-code-features.md) — REMINDER: ask user about their planned tree of deparse-code-based features (not yet elaborated)
- [global-ui-menu-tree](topic-global-ui-menu-tree.md) — addressable stdio slots + menu tree; settings (new)/configure (stub) zenki as starting points
- [credential-fabric-proxy-transport](topic-credential-fabric-proxy-transport.md) — proxy round-trip WORKING (200 OK verified 2026-06-09); boot/UI fixes through b27ebb655; stale-socket issue clears on full P7 restart
- [ascii-frame-system](topic-ascii-frame-system.md) — reverse parser, elastic renderer, DRC validator
- [frame-plugin-slots](topic-frame-plugin-slots.md) — status-bar plugin slots + context-aware selector; variable border width; vertical-slot roadmap
- [ascii-desktop-domains](topic-ascii-desktop-domains.md) — border glyphs are domain-scoped; nested domains = nested planes = ascii desktop; role-vs-glyph descriptor is the windowing unlock
- [frame-idiom-convergence](topic-frame-idiom-convergence.md) — NEW frame features: margin/vertical-padding/self-invalidating-cache/corner-pinning-spring; `.:[ ]::[ ]:.` idiom; 5 frames still need conversion (REQUIRED)
- [ui-show-security-levels](topic-ui-show-security-levels.md) — steps 1-5 ALL LIVE (36d605896, 2026-06-13); credential_fabric slot name/meta gated; step 6 open
- [os-command-zenka](topic-os-command-zenka.md) — planned: networked command/script templates, security levels, STRM streaming, vterm result buffers
- [plugin-web-jobs](topic-plugin-web-jobs.md) — delta sync WORKING; open: ?since=N, remote deploy
- [clients-http](topic-clients-http.md) — clients.http.* + clients.https.* async; kimi-web parallel dispatch
- [reasoning-chain-repository](topic-reasoning-chain-repository.md) — native model; dedup-based self-improvement
- [reasoning-namespace](topic-reasoning-namespace.md) — `reasoning.*` namespace; 21 templates
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

#,,,,,,,.,,,,,.,.,.,,,,,.,,..,,..,..,,,,,,,..,..,,...,...,...,.,,,..,,,.,,,,,,
#X7A5O6SR7XXIGEQQ2YW73I4I7UKAKCCP23SCC62X75XOCCRYYFIEZDB4JGT5EBPQKC43J4SDCG7YA
#\\\|PORSXZYL2YA2YLNBNER3VL2HZBQJV6RIWGVATETMQR27SPPCA45 \ / AMOS7 \ YOURUM ::
#\[7]53I3HWX7BHKFPV35ORXC52KXAMO77MOOZ2GUDHLFJUREXGEU7MAY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
UPDATE FILE: topic-credential-fabric-proxy-transport.md

Replace the entire file content with the following (preserve existing signature block at the end):

---
name: topic-credential-fabric-proxy-transport
description: credential_fabric/proxy/transport zenki — proxy HTTP round-trip WORKING (200 OK verified 2026-06-09); boot/UI fixes through b27ebb655; live traffic verification COMPLETE
metadata: 
  node_type: memory
  type: project
  originSessionId: 540d7622-310e-4b0f-8485-ccf9ab5cebcd
---

Three infrastructure zenki (credential_fabric, proxy, transport) landed
their initial wiring in `21f4edfa5`, but a manual verification pass
(`data/md/development/CREDENTIAL-FABRIC-WIRING-FINDINGS.md`, commit
`c336ce62c`) found none of them could actually boot. Session 2026-06-08
dispatched fixes via kimi (`kimi_dispatch`, task files now in
`data/tasks/completed/`) and committed the result as `3349352df`.

**Fixed and committed:**
- proxy: `$proxy` bareword compile error in `proxy.handler.accept`,
  `proxy.selector.load` cwd-relative path failure, `httpd.status_codes`
  load-order in `modules.load`, `max_concurrency = 1` (was racing 3
  simultaneous instances on `127.0.0.1:8118` bind)
- credential_fabric: `cube/access.zenki` granted *prefixed* command names
  (`credential_fabric.resolve`) to the cube-side check, but routed
  commands arrive *prefix-stripped* (`resolve`) — see [[base-prefix-
  stripped]]. Fixed `access.cmd.usr.cube` to use plain names + added
  admin grants. Console can now call `.approve`/`.resolve`/`.rotate`
  without "no perm" errors.
- transport: scaffolded the entire missing config dir (`start`,
  `zenka-startup.v7`, `subroutine.white-list`, `access.zenki`, dep
  manifests), fixed `AF_INET()`/`SOCK_DGRAM()` bareword compile error in
  `transport.handle.udt-tunnel:57` (needs `()` under `strict subs` — see
  precedent `SOCK_STREAM()` in `proxy.listen`/`clients.http.request`),
  fixed `init_code` return-value semantics (see [[init-code-return-
  values]]), and **renamed `<external.transports>` → `<transport.
  registry>`** across all 11 `transport.*` modules.

**The `<external.transports>` rename — a real trap, worth remembering:**
`transport.init_code` borrowed the namespace name `<external.transports>`
from `external.init_code` ("initialize generic transport registry for
external plugins"). This LOOKED like a cross-zenka dependency (and
produced "external.init_code not loaded" boot failures), but per-zenka
isolation means `<external.transports>` inside `transport` and inside
`external` are two completely separate hashes — borrowing the name
bought nothing and created a spurious, *unsafe* apparent dependency
(loading the real `external.init_code` would have scheduled live orbital
auto-connect timers — see `external.init_code:44-72` — wildly
inappropriate inside `transport`). The fix was to seed the registry
locally (`<external.transports> //= {}`) and then rename the namespace
to its own (`<transport.registry>`) once the safety analysis confirmed
none of `transport`'s actual usage (`profiles`/`quality`/`demoted`/
`active`/`stats.connections_ok`) depended on anything `external.init_code`
uniquely provides.

**Fixed and committed 2026-06-08 (`353f5f39f`, kimi `cf799057` + follow-up
via `kimi_continue`), across 9 `credential_fabric.*` modules:**
- `subscribe_rotation` wildcard (`*`) bug — fixed with `$slot ne qw| * |`
  guard bypassing the registry-existence check; wildcard bucket that
  `handler.rotation_strm` reads from is now unblocked
- ~9 hardcoded `var/credential_fabric/...` path occurrences (init_code,
  store.local, key_holder.child, register, rotate, seed_registry,
  handler.auth-relay-reply) migrated to `file.zenka_dir.write/load/
  unlink_file/data_path` — paths now resolve to the zenka's own
  `/var/protocol-7/credential_fabric/` instead of cwd. NOTE: this also
  makes `<credential_fabric.cfg.store_dir/registry_file/audit_log>`
  config vars dead (paths now inlined as relative strings) — harmless,
  pre-existing pattern issue, not worth a follow-up
- `credential_fabric.cmd.approve` argument-parsing — was expecting a
  hashref (`$call->{'args'}` shifted as `$params->{'req_id'}`) but real
  callers (p7c, jobsite.cmd.approve) pass positional `"req_id payload"`
  strings; rewritten to `split qr|\s+|, $args_str, 2`
- regression caught mid-fix: kimi's first pass on `store.local` write
  path dropped atomic temp-file+rename semantics (direct
  `file.zenka_dir.write` unlinks-then-writes non-atomically — risky for
  encrypted credential blobs); follow-up `kimi_continue` restored
  atomic write-temp→rename→cleanup-on-failure, fully routed through
  `file.zenka_dir.*`

**Done (unsigned/uncommitted) 2026-06-08 — task `data/tasks/
credential-fabric-console-cmd-access.md`:** dispatched via
`claude_dispatch` (outer session `f870d68f-5996-4ada-83ee-
54a80deeb531`, PID 2503034). The session itself **hung for ~50min**
on a `coding_summarize`/review-summarization call that the local 9B
coding zenka rejected with `initial prompt overflow: estimated 22294
tokens exceeds n_ctx=22000` (task `7277779` — failed+resolved on the
coding-zenka side, but the outer session's poll loop only treats
"completed" as terminal and blocked forever burning near-zero CPU);
killed manually. **However the actual implementation work it produced
on disk was complete and reviewed-clean** (Claude reviewed directly
since the session never self-reported):
- `credential_fabric.cmd.resolve`/`.cmd.rotate`/`.cmd.list-slots` —
  positional `$call->{'args'}`+`split` parsing matching `cmd.approve`
  (the bug class just fixed is NOT reintroduced), bridge correctly to
  hashref-based internal subs, no fake signature stubs, perl -c clean
- `list-slots` avoids the `base.cmd.list` collision; formats a slot
  table (name/owner/type/sensitivity/storage/rotated) without leaking
  secret material
- `cube/access.zenki` grants `credential_fabric.resolve`/`.rotate`/
  `.approve`/`.list-slots` to the admin wildcard using the *stripped*
  form — confirms [[feedback-cmd-segment-stripped]] (still needs a
  live end-to-end `p7c credential_fabric.resolve <slot>` test to fully
  close that memory's "verifying" status)
- `subroutine.white-list` updated with the 3 new module names
**Ready for your sign+stage+commit flow — not yet signed/committed.**

**Fixed and committed 2026-06-08 (`b27ebb655`) — key-holder liveness +
ascii-frame width drift:**
- **fork-before-drop_privs liveness false-negative (generalizable
  pattern, see [[feedback-fork-child-module-loading]] for the sibling
  module-loading trap)**: `credential_fabric.init_code` forks the
  key-holder child during `[init_modules]`, which runs BEFORE
  `[root.drop_privs:<system.amos-zenka-user>]` — so the child stays
  root-owned while the parent later runs unprivileged. Both liveness
  checks (`ui.query.key_holder`, `key_holder.parent`) used
  `kill(0,$pid)`, which reads `EPERM` (cross-uid signal denial) as
  "dead" — UI permanently showed `terminated`/`dead` for a live process,
  AND `key_holder.parent` would fork a fresh root child on EVERY
  operation (process leak). Fixed both call sites to
  `<[base.exists.sub-process]>->($pid)` — a `waitpid`-based check
  (`base.waitpid`/`base.exists.sub-process`) that depends only on the
  parent-child process relationship, not uid match. **General lesson:
  any liveness check on a child forked pre-drop_privs must use
  waitpid-based existence, never `kill(0,...)`.**
- renamed UI state `'dead'` → `'terminated'` (less presumptive about
  whether key material is still recoverable) — also added to
  `cmd.ui-show`'s colorisation status-word list
- **ascii.frame width drift (two compounding bugs)**: the key-holder-
  status frame rendered at inconsistent widths across rows. (1) the
  YAML mockup's bottom border had a hardcoded 62-dot fill, 10 chars
  wider than the frame's actual computed width — `render.border_line`'s
  elasticity model assumes `min` is a true minimum and produces an
  oversized line when `$fixed > $width` (slack clamps to 0, no
  shrinking); fixed the dot count in the source mockup. (2)
  `ascii.frame.render`'s `required_width` contribution from inline
  border slots used `$min_width + $val_len`, where `$min_width` only
  sums *anchor* lengths — it ignored fill runs (the `::::`/dots either
  side of the bracket), under-counting the line whenever the slot value
  is longer than its placeholder (`'running'` 7 chars overflowed where
  `'dead'` 4 chars happened to fit). **General fix** — now computes the
  border line's true fixed width (anchors + fill mins + slot value),
  mirroring `render.border_line`'s own `$fixed` formula; benefits any
  frame with state-driven inline border slots, not just this one. See
  [[topic-ascii-frame-system]] for the broader frame architecture (that
  memory's "DRC validator"/generic-mockup-type content looks stale/
  mismatched against the actual reverse-template-parser code — verify
  before relying on it).

**Fixed 2026-06-09 — proxy HTTP round-trip now WORKING (200 OK verified):**
- `proxy.listen`: data=>$sock watcher fix + FD_CLOEXEC on listen socket
- `proxy.init_code`: listen guard + stale socket cleanup on startup
- `proxy.handler.connection`: async auth + half-close race fix
- `proxy.auth.lookup`: async route-send to credential_fabric
- `proxy.handler.auth_lookup_reply`: new module
- `proxy.handler.post_auth`: new module
- `proxy.transport.select`: guard for missing transport.select
- `proxy.template.generic`: site-yaml.cmd.fetch → site-yaml.fetch
- `proxy.template.passthrough`: `<$var>` → `<[$var]>` dispatch fix
- `proxy.handler.accept`: store watcher handle
- `proxy.client.close`: cancel watchers before close
- `cube/access.zenki`: added site-yaml.fetch for proxy

**Known remaining issue:** stale listen socket from a prior run held by
root process (v7?) causes ~50% connection timeouts; clears on full P7
restart. FD_CLOEXEC on the new socket prevents recurrence after first
clean restart.

**Still open:**
- `credential_fabric.resolve`/`.rotate`/`.subscribe_rotation`/`.register`/
  `.request-authorization` are plain subroutine modules, not `.cmd.`
  command modules — internal APIs only, not console-callable
- on-demand auth (407/pending/approve flow) end-to-end not yet verified

#,,..,.,.,.,.,.,,,,,,,,,.,.,,,.,,,,.,,,,.,,.,,...,...,..,,,,,,,..,,.,,,..,.,.,
#4XVDFQGOXS3WDNT757H5UE5CVVCC6SSVT6RMHMD25ZWO6U5DDHBVVHYWD7RDQ5JOLKQCA7CJNMWZQ
#\\\|C4CWMVRW62ED73FJ676SYL4DHI5CJEIALD2IHLVKMHC5VEMRO6K \ / AMOS7 \ YOURUM ::
#\[7]7HQAGGT6BP3YTOFIOMJMEYIH4MQP5RB7WFJDEY6SNETHFDJNHGDI 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
