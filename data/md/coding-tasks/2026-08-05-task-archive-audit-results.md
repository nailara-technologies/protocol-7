# 2026-08-05 task archive audit — data/md/coding-tasks/ + data/tasks/

Audit of 171 task files (70 feature specs in `data/md/coding-tasks/`, 101
iteration tasks in `data/tasks/` — 94 top-level + 5 `unicode/` + 1
`needs-rewrite/` + 1 `research-findings/`). Read-only audit — no task files
were modified. Evidence = module/command existence in `src/`, `bin/`,
`cfg/`, `data/web-root/vhosts/`, `data/lib-path/pm/`, plus
`git log -S`/path history for ambiguous cases. Run via kimi k3 dispatch.

**Result: 89 done, 30 partial, 52 pending.**

Note (2026-08-05): multiple kimi sessions ran this same audit; this is the
first, most complete result recovered so far (exhaustive per-file list,
totals match exactly). Two more sessions from the same window are being
checked for consistency/redundancy — reconcile before archiving if either
disagrees with this one.

## done — ready to archive (89)

### data/md/coding-tasks/ (47)

- coding-inference-server-restart-policy.md : `src/coding.handler.inference_server_sigchld` + `inference_crash_restart` + `verify_inference_startup` all exist
- coding-state-machine-namespace.md : `<coding.state.backend>` lock/queue live in `src/coding.async.backend_acquire`; `backend_busy_retry` polling gone; `coding.state.save` exists
- coding-zenka-abort-inference.md : `coding.abort.{register,lookup,list,remove,task_bind}` + `coding.cmd.abort-inference` all exist
- context-batch-review-pipeline.md : `context.review.{plan,page,iterate,consolidate}` + `context.module.dep_*` all exist
- context-channel-frequency-separation.md : `graphics-matrix.channel.{init,palette,select,translate,current}` + `cmd.channel` all exist
- context-namespace-design.md : full `context.*` namespace exists (cache/compose/delegate/priority/share/template)
- context-ncode-test-protocol.md : `context.cmd.review` + `ncode.cmd.{tool_list,transform}` + `ncode.regex.assess` all exist
- context-runtime-testing-and-depgraph.md : `context.module.{dep_graph,dep_order,dep_pack}` + `delegate.handler.result` exist
- curses-widget-layer.md : `terminal.curses_ui.{app.models,keybindings,widget.detail,widget.list,load_lang}` all exist
- cursor-address-resolution-layer.md : `graphics-matrix.address.{encode,init,register,resolve}` + `cmd.address` all exist
- decoder-zenka-stream-protocol.md : decoder zenka fully built — 22 `decoder.*` modules (receive-entropy, stream-list, show-vterm, decode_d13_bits...)
- dep-graph-cmd-filter-false-positives.md : file records status: completed 2026-03-23; `bin/dev/dep-graph` exists with the fix
- dep-graph-whitelist-cmd-access-filtering.md : commits `05fc298e0` (white-list→load-early rename) + `1a3f2a33c` (loaded-namespace gating)
- event-loop-safety-template.md : `context.yaml/context-templates/event-loop-safety.yaml` exists
- fix-list-alignment-offset-truncation.md : commit `3169dd6b9` "base.parser.list — column width alignment for 10:ex1 key patterns"
- httpd-template-content-type-and-head.md : `httpd.process_template` maps `.tmpl`→`text/html`; `src/httpd.http_head` exists
- investigate-cmd-permission-mask-compilation.md : fix commits `183d6fa4c` + `5190ed149` on `src/base.parser.access_conf`
- invoke-ai-model-storage-management.md : `bin/scripts/invoke-ai/invoke-model-prefetch` + `invoke-model-recover` exist
- invoke-web-zenka.md : `invoke-web.cmd.{start,stop,restart,status,health}` + `handler.{check_health,monitor_startup}` + `init_code` exist
- invoke-zenka.md : `invoke.cmd.{generate,cancel,health,status,list-images,queue-status}` + `api.build_graph` + `handler.poll_jobs` exist
- kimi-handover-orientation.md : orientation task, file records status: completed; referenced ncode/context modules exist
- kimi-next-session-flag.md : `:next:` prefix handling live in `src/kimi.cmd.ask-reply` (lines 21-92)
- kimi-task-dep-graph-zenka-flag.md : `-zenka=NAME` flag implemented in `bin/dev/dep-graph` (lines 52,70,85-87)
- kimi-tasks-dep-graph-and-hook.md : `bin/dev/dep-graph` exists + `bin/dev/git-hooks/pre-commit` has the length check (line 98-99)
- lattice-cell-storage-namespace-bridge.md : `graphics-matrix.cell.{init,list,place,query,remove,survey}` + `cmd.cell` all exist
- line-edit-tools-encoding-param.md : encoding parameter present in `coding.tools.definitions` (multiple tools, lines 456+)
- lm-vision-http-backend.md : `lm-vision.handler.http_analyze` is the HTTP backend with LOVES_IT scoring inline; `lm-vision.cmd.analyze_image` exists
- local-model-participation-checklist.md : checklist artifacts exist (`coding.context.read_module`, `coding.routing.decide_service`, `plugin.storage.inference`)
- nameserv-phase1-design.md : `nameserv.cmd.{get,set,remove}-record/list-zones/show-zone/reload-zones/status` + `handler.query` + `zone.{lookup,save}` exist
- ncode-kimi-review-notes.md : review artifact; all 6+ reviewed ncode modules exist as reviewed
- ncode-zenka-self-refining-regex.md : `ncode.regex.{apply,assess,expand,load,save}` + `transform.wave` + `cmd.{tool_list,transform}` exist
- notes-tools-expansion.md : full `coding.tools.handler.note_*` family exists (read/write/list/search/merge/history/filter/delete/categorize/recent/init)
- plugin-storage-inference-cache.md : `plugin.storage.inference.{init_code,lookup,store}` + checksum cluster modules exist
- relocate-repo-tree-runtime-state.md : `var/sys-deps` + `data/state` gone from tree (gitignored as runtime), sys-deps zenka landed (commit `fe8244268`)
- remove-blocking-inference-path.md : commit `32cda2ea5` "remove blocking inference path"; `coding.handler.process-queued-task` no longer exists
- remove-redundant-json-registry.md : no `registry.json` refs remain; registry keyed by composite checksum (commit `b674ecd80`)
- searchable-index-synthesis.md : synthesis delivered as `data/md/design/SEARCHABLE-INDEX-SESSION-STATE.md`
- similarity-graph-cell-connections.md : `graphics-matrix.graph.{init,connect,disconnect,neighbors,cluster,survey}` + `cmd.graph` all exist
- space-index-build-pipeline.md : `plugin.web.space.index.{init_code,scan,load,persist,cmd.rebuild}` exist
- space-index-grid-endpoint.md : `plugin.web.space.grid.{init_code,scan}` + `handler.state_reply` + `state` exist
- summarize-context-command.md : `coding.cmd.summarize-context` + `task.cmd.summarize` + `task.handler.summarize-reply` exist
- sync-export-history-across-browsers.md : exported_stage synced via `src/plugin.web.jobs.sync` (line 55)
- task-zenka-kimi-coordination.md : task zenka (`cfg/zenki/task/zenka.v7`) + `models.handler.task-poll-step` + `kimi.cmd.ask-reply` exist
- verify-finish-reason-propagation.md : file records Status: VERIFIED; `coding.handler.check-completion-chain` exists
- web-plugin-inline-sub-extraction.md : `plugin.web.content.util.{calculate_checksum,format_size,generate_submenu}` + menu.tree extracted
- zulum-cube13-decoder-integration.md : `zulum.*` (6), `cube-13.cmd.*` (4), `decoder.*` (22) modules + all three zenki configs exist
- zulum-decoder-routing-reference.md : file records "verified working [Mar 10 2026]"; `zulum.cmd.stream-attach` + `decoder.cmd.receive-entropy` exist

### data/tasks/ (42)

- audio-icon-povray-glass-cylinder-wrap.md : `audio.cmd.spatial-purr-icon` + `audio.overlay.waveform_trace.v1` + povray.init_code exist
- audio-render-v3-phase-bug-and-v4-temporal-idea.md : `audio.render_standing_wave.v4` exists (v4 prototype landed)
- audio-waveform-visualization.md : `audio.cmd.spatial-purr` + `overlay.waveform_trace.v1` + `tile.cmd.add_overlay` exist
- base-callback-data-tree-modes.md : DATA + TREE reply modes implemented in `src/base.callback.cmd_reply` (lines 105-163)
- base-parser-list-width.md : commit `3169dd6b9` fixes exactly this width bug
- branch-layer4-storage-data.md : `branch.data.{bind,query,unbind}` + `branch.storage.{list,persist,restore,sync}` exist
- branch-session-dag.md : all `branch.session.*` modules exist (dag.node_add/edges_from/open_list/parallel_dispatch, fork, jump, policy.*, round.checksum)
- coding-self-test-async-http-client-rewrite.md : async self_test suite exists (async_probe, handler.poll_probe/poll_switch, cmd.self-test-run/detail)
- coding-task-model-pinning.md : title says completed; `coding.task.ensure_model_pinned` + `handler.switch_model_reply` exist
- context-aware-scale-navigation.md : scale-level navStack implemented in `data/web-root/vhosts/space.v7.ax/visualization.html` (line 342+)
- cred-mesh-rotation-subscription-cross-zenka.md : `cred-mesh.cmd.subscribe_rotation` + proxy/transport `cred_rotated` handlers exist
- dispatch-template-param.md : template param + `p7_template_resolve` tool in `bin/mcp-server-p7`
- footer-line4-field-reconciliation.md : complete analysis doc (findings 1-6 + recommendation); referenced as authoritative by later audits
- harmonic-quality-correlation-study.md : `data/ai-mem/claude/topic-harmonic-correlation-ledger.md` + `data/md/documentation/harmonic-cycle-correlations.md`
- inline-subs-batch-misc.md : `download.util.resolve`, `letsencr.child.util.*`, `work.parent.util.*`, `space.search.util.*` all extracted
- mcp-coding-summarize-checklist-routing.md : checklist mode + `task_file` param live in `bin/mcp-server-p7` `coding_summarize`
- memory-maintenance-2026-05-29.md : routine dated maintenance; `data/ai-mem/{claude,kimi}` present and actively maintained
- perlmod-categorization-results.md : results artifact of the categorization pass
- perlmod-load-autoload-categorization.md : categorization completed → produced `perlmod-categorization-results.md`
- perlmod-move-confirmed-refactor.md : commit `d3f3ac001` "perlmod load/autoload: move 11 confirmed-hot loads to init_code"
- perlmod-move-reverification.md : re-verification completed → produced `perlmod-move-reverification-results.md`
- perlmod-move-reverification-results.md : results artifact
- povray-zenka-implementation.md : `povray.cmd.{render,status,template-resolve}` + `handler.render_{output,timeout}` + `template.resolve` + full config
- recurring-cube-number-collision-audit.md : complete 642-line audit (enumeration, headline answer, rejected list) — the file IS the deliverable
- rescued-last-night.txt : rescued-session transcript artifact; its verdicts were re-verified in the 2026-07-26 pass (per SESSION-STATUS-scan-resume)
- shm-streaming-payload-pipeline.md : `base.shm.{path,read,write}` + `httpd.handler.shm_write` exist
- space-engine-template.md : `space.template.{apply,branch,chain,define,list,root,verify}` + `space.register.*` + `route.resonance` exist
- sub-bit-element-definition.md : `base.stream.frame.{decode,detect,detect.grammar,detect.harmonic}` exist
- task-coding-wait-done-task-orphaning.md : fix commits `aaf139175` + `edf1b9a44`; `coding.handler.wait_done_timeout` + `coding.task.complete` exist
- task-summary-topic-tree.md : `task.cmd.summary-tree-{notify,query}` + `coding.cmd.tree-query-reply` + `task.persist.summary_tree.save` exist
- task-zenka-cold-queue-gpu-cooldown-trigger.md : `task.cmd.trigger-cold-queue` + `handler.cold-queue-sweep` + `handler.gpu_temp_update` exist
- v7-lpw-sync-debug.md : fix commits `e77cbaf7b` + `b777eff17` ("lpw sync") on `v7.calc_prefix_lengths` et al.
- web-auth-plugin.md : full `plugin.web.auth.*` suite (create/verify/destroy_session, handler.login/logout/status, session.*)
- web-browser-value-replay-waypoints.md : `web-browser.cmd.{goto-waypoint,goto-waypoint-group,waypoint-set,state-play}` + `replay.dispatch` exist
- x11-capture-commands-rewrite.md : screenshot zenka landed (`screenshot.cmd.capture-to-disk` + `cfg/zenki/screenshot`)
- zenka-name-routing-modes.md : configurable `routing_mode` disambiguation in `base.handler.command.route_to_target` (line 234)
- research-findings/forensics-zenka.md : research artifact; forensics zenka scaffolded (commit `86424b80c`, `cfg/zenki/forensics/`)
- unicode/test-double-encoded.txt, test-normal.txt, test-utf8-notes.md, utf8-test-content.md, tools-encoding.txt : test fixtures / pasted session log — data artifacts, nothing to implement

## partial — keep (30)

### data/md/coding-tasks/ (10)

- context-tree-checksum-addressing.md : `context.tree.checksum.{init_code,state,stream,template}` exist; `tree.node.{fetch,store}` + `index.relevance` missing
- context-tree-checksum-inspiration.md : inspiration doc; `checksum.template` landed, `checksum.validate` missing
- context-tree-checksum-templates.md : `context.tree.checksum.template` exists; `.generate`/`.cfg`/`.templates` missing
- cube-coordinate-network-topology.md : `base.indexcube.{push,pop,depth,here,reset}` + `decoder.cmd.show-indexcube` exist; full coordinate/color/integer addressing vision incomplete
- indexcube-routing-stack.md : stack primitives exist; color_mix/distance/neighbors/tint missing
- lm-vision-binary-rebuild.md : superseded — HTTP backend via `bin/dependencies/llama-server-vision.sh` replaced the binary-rebuild approach
- next-steps-plan.md : planning doc; delegate/review/valued modules landed, `step_group.*` + `compliance.calculate` + `ncode.meta.*` missing
- roadmap.md : living planning document — never "done" by design
- task-multiplexing-async-architecture.md : early architecture doc; async landed under different names (`coding.async.http_client`/`state_machine`); most proposed modules never created — largely superseded
- zenka-key-identity-infrastructure.md : `crypt.C25519.*` key infrastructure extensive (gen_keys, load_keypair, cmd.*); `zenka.tasks.*` layer missing

### data/tasks/ (20)

- amos7-chksum-consolidation.md : `AMOS7::CHKSUM.pm` exists with BMW; JHA not consolidated (`base.chk-sum.jha.*` still separate, 0 JHA refs in `CHKSUM.pm`)
- bmw-truth-template-family.md : `AMOS7::TEMPLATE` + `bin/amos-chksum` truth-template support + `harmonize_L13`/`template_L13` exist; per-family `truth_template_*` modules mostly absent
- configure-zenka-fallback-ui.md : configure zenka scaffolded (init_code + config start/load-early); `configure.cmd.*` + `ui.*` missing
- context-management-system.md : `coding.async.compact_context` exists; `compaction.{model,strategy,threshold}` config layer missing
- credential-fabric-ui-interactive.md : `cred-mesh.ui.interactive.{action,up,down,refresh,select_view}` exist; `unlock_dialog`, `cmd.unlock`, `ui.render` missing
- dep-graph-semantic-embeddings.md : phase 1 landed (`bin/dev/depgraph-corpus`, commit `89ab6a836`); `coding.context.semantic-load` integration missing
- direct-event-io-to-wrapper-migration.md : `base.session.init` migrated; direct `Event->io` remains at `src/httpd.route.handler.web-relay:64`
- epoch-bmw-l13-truth-templates.md : `harmonize_L13` + `template_L13` exist; `truth_template_L13` never landed (machinery moved to `AMOS7::TEMPLATE`)
- FASTTEXT-MEMORY-PIPELINE.md : `bin/dev/train-embedding` + corpus assemblers exist; `embeddings.*` zenka modules (load-for-session, select-categories, retrain triggers) missing
- jobsite-sync-multiplex.md : `jobsite.sync.{push,apply_reverse}` + `plugin.web.jobs.sync.merge` exist; multi-endpoint `cfg.sync_urls` missing
- loves-it-gpu-allocator-phase1.md : real mode-4/7/13 scoring landed inline in `lm-vision.handler.http_analyze`; shared `resource.gpu.loves_allocator` module never created
- repo-root-cleanup-var-local-batches.md : `local/` removed; `var/httpd/` + `batches/` still in repo root
- research-knowledge-base-extraction.md : 11 topics planned; only topic 10 (forensics) extracted to `research-findings/`
- security-intel-embedding-domains.md : `bin/dev/{cwe-corpus,mitre-attack-corpus,cisa-kev-corpus}` exist; comment says "task 1.1b partial"; `embeddings.cmd.retrain-category` missing
- SESSION-STATUS-tasks-completed-scan-resume.md : scan rounds 1-3 complete but records 52 files never scanned — superseded by this audit
- SESSION-STATUS-tranche1-followup.md : tranche-1 fixes verified landed (harmonize_L13 whitelisting etc.); has "still pending dispatch" remainder
- signal-cancel-log-library.md : `signal.cancel.{load,match,init_code,cmd.filter,cmd.add-pattern,cmd.scan-baseline}` exist; `cmd.stats` + categorize missing
- v7-stdout-foldable-relay.md : stdout_log write/rotate + output handlers exist; `v7.stdout.view.{bind,unbind}` + `address.resolve`/`filter.*` missing
- valued-tree-task-zenka-integration.md : `valued.tree.record_outcome` exists; `task.cmd.block` + `task.transition` missing
- x11-user-fallback-and-audio-awareness.md : `mpv.callback.silenced` + `cfg/X11-vars` + X-11 multi-server commits exist; intelligent user/fallback selection not evident

## pending — keep (52)

### data/md/coding-tasks/ (13)

- add-multiline-command-support-to-clients.md : zero multiline/+-mode handling in `bin/c_src/p7c.c` and `p-7-r.c` (grep: 0 matches)
- archive-completed-task-files.md : this audit task itself — executing now, not complete until this report is acted on
- checksum-route-binary-framing.md : design doc; no B32R framing code anywhere (grep B32R in src/+bin/: 0 hits)
- checksum-route-binary-framing-harmonic-foundations.md : pure math-grounding companion doc; no implementation target exists
- context-tree-octal-encoding.md : no `context.tree.encode_*` modules (`amos7.encode_octal_header` exists but the context-tree application doesn't)
- export-history-undo-stack.md : no undo stack anywhere in `plugin.web.jobs.*` (grep: no hits)
- lmstudio-zenka-wiring.md : `cfg/zenki/lmstudio/` is an empty dir; no `lmstudio.*` modules
- multi-model-design-chat.md : `bin/models-chat` + `models.chat.{design_session,expand_inline_refs,export_task}` missing; git shows only the task-doc commits
- rewind-stack-file-diffs.md : `coding.cmd.rewind`/`coding.tools.rewind.*` never existed; git log shows only task-file-addition commits
- tool-hints-and-extended-docs.md : `coding.tools.handler.{register_hint,tool_help}` + `hints.check` missing; git -S shows only docs commits
- version-aware-loader.md : no `cfg/loader/`, no loader-versioning git evidence
- zenki-elves-network-habitat.md : philosophical design doc, no code targets referenced or found
- zenki-profile-configuration-interface.md : no profile interface; only `cfg/zenki/v7/start-set-up.base` exists

### data/tasks/ (39)

- amos7-shm-coding-zenka-prompt-transport.md : self-declares "design only — nothing implemented"; `data.mount.shm.transport.*` missing, no shm refs in `coding.cmd.submit`
- amos7-shm-log-channel-handshake.md : self-declares "design only"; `data.channel.shm.transport.*` missing
- branch-layer5-9p-bridge.md : no `branch.9p.*` modules at all
- branch-layer6-file-abstraction.md : no `branch.file.*` modules at all
- coding-self-error-processing-cycle.md : no `coding.error.*` modules; no git evidence
- command-relay-zenka.md : requirement note; no command-relay zenka in `cfg/zenki` or `modules`
- cosmic-space-visualization-layer.md : no `cosmic.scene.*` modules (only an unrelated mention in lm-vision)
- crop-circle-acquisition-pipeline.md : no `image.crop-circle.*` modules
- crop-circle-assertion-mask.md : no `route.bmw384.visual.mask` modules
- dispatch-create-template.md : no `create_template` param in `bin/mcp-server-p7` (template param exists; create_template does not)
- epoch-chksum-path-helper.md : no `base.path.epoch-chksum`; git -S shows only task-shuffling commits
- epoch-validity-search-protocol.md : no `epoch.*` or `search.cache.*` modules
- generate-all-spec-pages.md : `iris.v7.ax` has no spec pages; `reasoning.summarize.node` missing
- git-watch-zenka.md : no git-watch zenka config or modules
- glitter-cosmology-priming.md : one-shot model-priming prompt doc; no verifiable outcome artifact
- group-mode-reply-count-protocol.md : no reply-count/`reply_count` anywhere in `src/`
- index-cube-storage-cache.md : no `index.cube.cache.*` / `index.cmd.cache-stats`
- index-cube-storage-migrate.md : no `index.migrate.v2-to-v3` / `detect_schema`
- index-cube-storage-verify.md : no `index.cube.verify*`/`verify_chain` / `cmd.verify-cube`
- installer-zenka-template-flow.md : no `installer.*` modules or zenka
- keyring-phase1.md : no `keyring.*` modules
- kitten-acquisition-pipeline.md : no `image.kitten.*` modules
- litter-row-encoding.md : no `base.module.litter*`; no git evidence
- mcp-kimi-status-check-reattach.md : no status-check/reattach tool in `bin/mcp-server-p7` (only dispatch/continue)
- mcp-regex-approval-system.md : no `cfg/mcp/approval-patterns.yaml`; no approval logic in mcp-server-p7
- network-elf-avatar-pipeline.md : no elf avatar artifacts/src
- real-estate-agent-port.md : zero real-estate references in `src/`, `bin/`, `cfg/`
- ring-routing-phase1.md : no `ring.*` modules, no `cfg/zenki/cube/rings.cfg`
- space-engine-grid-orbit.md : no `space.grid.*` / `space.orbit.*` modules (space-engine-template landed, this one didn't)
- task-archiving-with-context-templates.md : no `bin/dev/archive-task`
- taws-integration.md : no `web.handler.taws_*` modules; no taws files anywhere
- v7-console-log-filter-overlay.md : no `v7.console.filter.*` modules
- v7-console-per-zenka-tree-view.md : no `v7.console.view.by-zenka.*` modules
- visual-feedback-capture-analyzer.md : no `cfg/zenki/visual-feedback/`
- visual-feedback-vision-loop.md : no `llm.service.vision_query` / `cfg.vision.*`; same missing zenka
- visual-mask-model-layer.md : no `image.mask.*` modules
- wayland-screenshooter-perl-prototype.md : no wayland files anywhere in repo
- web-sessions-distributed.md : no `plugin.web.sessions.sync` / `plugin.web.auth.session.changed_since`
- needs-rewrite/base-has-access-source-sid-matching.md : no hierarchical source-SID (`usr.cube.system = cmds`) matching in `base.parser.access_conf`

## Key structural surprises

1. **lm-vision-binary-rebuild** was silently superseded — the HTTP
   llama-server backend (a different task) replaced the binary approach,
   and the LOVES_IT allocator from **loves-it-gpu-allocator-phase1** landed
   inline inside `lm-vision.handler.http_analyze` rather than as the
   planned `resource.gpu.loves_allocator` module (hence `partial`, not
   `done`).
2. Truth-template machinery partially migrated out of `src/` into the
   new perl libs `data/lib-path/pm/AMOS7/{CHKSUM,TEMPLATE}.pm`, which is
   why bmw/epoch template tasks look half-missing in `src/` — but JHA
   was never consolidated into `AMOS7::CHKSUM` (0 refs), so
   **amos7-chksum-consolidation** stays `partial`.
3. Both AMOS7::SHM integration tasks self-declare "design only — nothing
   implemented" and the code agrees, despite related shm infrastructure
   (`data.channel.shm.*`, `base.shm.*`, `httpd.handler.shm_write`) having
   landed for other callers — an easy false-done trap.
4. **multi-model-design-chat** exists only as doc commits — `bin/models-chat`
   was never created.
5. `unicode/*` (5 files) and `rescued-last-night.txt` are not tasks at all
   (test fixtures / a rescued transcript) and could be moved out of the
   task list entirely; likewise `roadmap.md` and `next-steps-plan.md` are
   living planning docs that will never be "done" and probably shouldn't be
   archived by evidence rules.
6. **SESSION-STATUS-tasks-completed-scan-resume.md** records this exact
   backlog-scan effort through round 3 with "52 never scanned" — this
   audit completes that scan, so both `SESSION-STATUS-*` files are natural
   archive candidates once a human confirms the supersession.

## Next steps

- Reconcile against the other two kimi sessions from the same window
  before archiving anything (per note above — not yet done).
- Archive the 89 `done` files above once reconciled.
- Prioritize the 30 `partial` modules (e.g. `cred-mesh.cmd.unlock`,
  `context.tree.node.fetch`, `resource.gpu.loves_allocator` extraction).
- Treat the 52 `pending` files as backlog for verification or deletion.
- Human confirmation needed before any file is actually moved/archived —
  this document is the audit trail, not an archival action itself.

#,,.,,.,.,.,.,...,...,...,,,,,.,,,,..,...,,..,..,,...,...,..,,,,,,.,,,,,.,..,,
#ELYFOMA7SM75WM3DPLAWVM6ICAVYLNYKSIPKJXOUWSTLTCEE6OESZQ26BUMD5IFB5JNRMALS3KIOE
#\\\|DSURV3GCMK5KJQDOXD25HMGYP2OO7C65LBP3P73HHCBPZD3OMH4 \ / AMOS7 \ YOURUM ::
#\[7]QHJDV5IQZEPWJKYJO544YGFYYJFBWUNN3CX4H6MCDIFQSN6AUWBI 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
