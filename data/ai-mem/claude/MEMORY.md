# Protocol-7 Development Memory
## Topic Files (details live here)
- `project-vision-origin.md` — 24-year foundational vision, threshold reached Apr 2026: encoding the surrounding cube of the optimization sphere
- `topic-creative-field-behaviour.md` — emergent cooperative field dynamics, formation antennas, homing resonance, purring field, 24 as cat layer, zenki as entropy research subsystem, holographic self-investigation
- `topic-migration.md` — Windows 11 host instability, KVM/Debian migration priority, avoid /tmp/
- `topic-self-contained-zenka.md` — self-contained zenka vision: __DATA__ registry, file.* abstraction,
  zenka serialization/dump, coderef P7REF transfer, STDIO transport, roaming zenki, empty bootstrap
- `topic-tls-acme.md` — SNI/SSL internals, ACME/letsencr details, cert discovery
- `topic-patterns.md` — event handler, fork-child, standalone zenka, pipe-open, inference server
- `topic-completed.md` — session summaries with details
- `topic-invoke-model-management.md` — uuid vs verbose paths, config.json requirement, :raw binary writes, partial download traps
- `topic-invoke-model-manager.md` — planned Term::Clui manager: safe delete, archive/restore, collection profiles, image provenance, zenka evolution path
- `topic-image-archive-system.md` — vision-scored tiered storage: thumbnail+metadata = full image, pngquant tiers, defect scoring, model↔image dependency graph, 63GB+ savings
- `topic-harmonic-mathematics.md` — generator 076923, quadratic residues, cube geometry,
  spiral topology, 4-crossing consent protocol, CCW matrix routing, heartbeat encoding
- `topic-vterm.md` — vterm module system: cell format, consensus algorithm, review findings
- `topic-self-improving-system.md` — LLM coordination as foundation for self-improving P7 network;
  user as coding zenka; tasks decomposed for autonomous execution between sessions
- `topic-distributed-consensus.md` — channels zenka, multi-model group chat, consensus groups,
  distributed P7 nodes with ik_llama.cpp on remote servers
- `topic-model-pinned-switching.md` — model param inert in summarize_context + compaction; needs switch-model integration; config keys ready
- `topic-coding-state-machine.md` — coding.state namespace design, watcher-based backend lock replacing polling timers, persist/restore lifecycle; timer-to-watcher.yaml template written
- `topic-kimi-zenka-state-machine.md` — COMPLETE (session 23): watcher state machine, task queue, reconnect-stuck fix; open: flush_on_acquisition extraction, approval warning
- `feedback-watcher-state-machines.md` — IO::Async variable watchers are the proven reliable pattern; never use polling timers/sleep loops for state; coding zenka is the reference
- `topic-amos7-p7-loader.md` — dep-graph P7 module loader vision: AMOS7::P7 makes <[...]> modules callable from standalone scripts/MCP handlers without a zenka
- `topic-task-tree-design.md` — unified task/subtask tree: multi-parent groups, passive deps (depends_on), active deps (requires: switch-model/worker/tool-set), history archive, bool via cfg_bool
- `topic-task-coordination.md` — task zenka as coordinator between kimi/coding/models,
  current state, dispatch flow, architectural questions, reference to scattered design docs
- `feedback-kimi-code-review.md` — common issues in kimi-generated P7 code: SUPER:: resolution,
  namespace swaps, SSL internals, missing log levels, style, fake signatures
- `feedback-kimi-signatures.md` — kimi derails into AMOS7 signature investigation; add signatures_note to every task file
- `topic-context-and-forensics.md` — context.* module namespace design, forensics zenka vision
  (nightly security audits via NIST/security models), model capabilities mapping
- `topic-addressing-trinity.md` — named tree + checksums + timestamps as orthogonal trinity; latest/current pointers; rolling 3-epoch validity window; temporal proximity pre-computed into address
- `topic-checksum-addressing.md` — AMOS checksums as universal routing primitive,
  everything-is-a-group-of-1, expectability principle, delegation via checksum endpoints
- `feedback-inline-sub-naming.md` — extracted helper subs `_foo` become `namespace.foo` (no underscore) in P7 module names
- `feedback-ptd-syntax-check.md` — use `ptd -c` not `perl -c` for P7 module syntax checks
- `feedback-ptd-formatting.md` — use `ptd` (not `ptd -c`) after writing modules — formats + checks syntax in one pass; skip separate syntax check step
- `feedback-cross-zenka-deferred-reply.md` — cross-zenka deferred replies need local reply_id store + callback_id + route-send back; call_args.data not transmitted; multiline = :B32:
- `feedback-p7c-command.md` — always use `p7c` not `p7`; binary was renamed
- `feedback-v7-restart-cube.md` — `p7c v7.restart cube` restarts all zenki at once; use after editing cube/access.zenki
- `feedback-p7-module-call-syntax.md` — `<[mod]>` is implicit no-arg call; never add `->()` for zero args
- `feedback-model-precision-analysis.md` — Qwopus more precise on analysis; sushi coder hallucinates LWP as async
- `feedback-kimi-dispatch-pattern.md` — dispatching tasks to kimi via bin/kimi-task is highly
  token-efficient; write detailed task files, review for known issues
- `topic-tool-shm-architecture.md` — LLM tool calling (8 tools), dispatch loop, SHM+mmap file editing vision
- `topic-coding-zenka-templates.md` — 50+ context templates, 16+ tools, tree tools, autonomous loops
- `feedback-p7c-multiline.md` — p7c cannot handle multiline task descriptions; use single-line or templates
- `feedback-coding-zenka-edits.md` — local LLM often describes edits instead of applying them; verify results
- `feedback-coding-zenka-reasoning.md` — low reasoning → premature task_complete mid-investigation; use medium for tasks needing discovery + implementation
- `feedback-chmod-child-restore-readline.md` — every restore cmd to chmod child needs readline after; missing one desyncs the pipe, all subsequent writes stage silently
- `feedback-config-in-start-file.md` — coding.cfg.* keys go in configuration/zenki/coding/start; never create modules/coding.cfg (loader treats it as Perl sub); never set key to empty string
- `feedback-descr-tag-max-55.md` — module # descr = lines enforced to 55 chars max by pre-commit hook
- `feedback-coding-zenka-inject.md` — use `p7c coding.inject-message <id> <msg>` to redirect stuck model mid-task with explicit file paths
- `feedback-arg-regression.md` — local LLM reverts $ARG→$_ after context compaction; verify all edits
- `topic-tool-suggestions.md` — LLM-suggested tools/improvements, prioritized; implemented/deferred/sources
- `topic-namespace-tree-intelligence.md` — the tree IS the intelligence: unified namespace for
  code/data/state/history/planning, branch summarization, universal off-band access
- `topic-async-tool-loop-debug.md` — RESOLVED: async tool loop fixes, XML parsing, root cause chain
- `topic-coding-zenka-session8.md` — May 1: llama-server 4266 pinned (Jinja crash), 4B Claude distilled v2 default, tool JSON repair, nshell Ctrl+O + (0) bug
- `topic-coding-zenka-session10.md` — May 3: inference compaction VERIFIED (14msgs→1, 53%→17% ctx), :model: keyword, extract-inline-subs naming rules, hallucination patterns
- `topic-coding-zenka-session9.md` — May 2/3: reasoning_content separation, 3-tier task buffers, buffer lifecycle (47m save/63m xz), sub-agent infra, model/compaction config plan
- `topic-async-round-2-timeout.md` — RESOLVED (Apr 30): double-spawn VRAM starvation + subtask lock deadlock + timeout restart; full subtask round-trip verified
- `topic-coding-zenka-session7.md` — May 1: spawning guard centralized, drain pipe lifecycle, context floor semantics, task-append + resumption, loop detection fixes, context pressure warning; open: loop_detect_count per-task
- `feedback-list-return-format.md` — list backends: mode 'size' + formatted string, not arrayref
- `topic-searchable-index-and-visualization.md` — checksum-indexed dataspace, space.v7.ax/source.v7.ax, index/file zenki
- `feedback-web-serialization-and-inlining.md` — parallel JSON+YAML data endpoints, inline CSS/JS for offline-viewable native-app-like reliability
- `feedback-file-io-api.md` — file.read/slurp/write/write_encoded/append param order + return types
- `feedback-file-stat-shadowing.md` — bin/Protocol-7 `use File::stat` shadows builtin stat; always use `File::stat::stat($p)->size/mtime` in modules
- `feedback-cube-pause-starvation.md` — base.handler.read pause on cube socket starves all routed traffic; size-overflow drop must respect SIZE boundary or injection
- `feedback-set-capability-session-id.md` — cube.cmd.* modules receive $call_args with 'session_id'/'args'; using 'sid'/'args_list' silently FALSEs out
- `topic-stream-cancel-design.md` — stream cancel: !TERM! forwarded to route target + source-gone else branch added; session-close teardown NOT yet implemented (open item)
- `topic-strm-unbounded-gap.md` — STRM/STRM-SIZE require declared total; unbounded needed for audio/webcam relay; protocol extension sketch
- `topic-stream-transport-layer.md` — STRM stack complete: cancel, base.stream-file, unbounded relay (radio); remaining: formal open-0 sentinel, transport.register (when 2nd consumer), webcam/log-tail
- `topic-strm-write-blocking.md` — RESOLVED 2026-05-07: STRM-SIZE large-stream blocking root cause (EAGAIN + var watcher), fix in base.handler.write + base.session.cancel_route
- `topic-radio-relay-zenka.md` — radio COMPLETE: TLS relay, STRM cancel, mpv offline/resilience, gap-fill paced; phase 5 (buffer-fill curve) next
- `topic-base-curve-system.md` — generic base.curve.* parameter animation; composable signal chain (daytime × ambient × fade); mpv.param.curve is a thin wrapper on top
- `topic-buffer-access-control.md` — per-buffer-name ACL deferred; revisit when 3+ zenki expose buffers via show-buffer
- `topic-orbital-data-space.md` — full orbital field theory + zenki-as-satellites: zenki orbit a work/memory ring; ring buffers+translates between free-rotation zenki and cubic grid routes; data flows electrically along ring; routes stay static near ring while zenki orbit freely — explains why zenki can migrate/restart without breaking routing
- `topic-vhost-install.md` — httpd vhost install infrastructure: DNS-gated symlink/copy, letsencr TLS, space.v7.ax live with orbital.json+templates.json+visualization.html; key fixes + open items
- `topic-cursor-model.md` — true cursor emerges from hyperspace plane line density (not drawn); glow=influence gradient; liquid crystal desktop; brightness-only color model; next: remove wireframe cube, queue glow task
- `topic-node-group-geometry.md` — exact geometry: 8×(4×4×4-1=63) cubes, 4×4×4 void = ghost cube slot; void derivation 2+1+1=4 per axis; corrects earlier wrong 20/10 ratio
- `style-philosophy.md` — living manifesto: coding as artform, style-as-function, harmonization layers, fractal self-similarity, normalization resistance; give to LLMs before structural/refactor work; models update it after sessions
- `topic-punctuation-topology.md` — `:` as group boundary, `.` as element separator; universal scale-independent addressing; AMOS checksums as atoms; route=session=task=cache at different resolutions; doc at data/md/development/PUNCTUATION-TOPOLOGY.md
- `topic-hyperspace-topology.md` — closed observer loop as anti-entropic; intent-saturated chains self-strengthen; sensor cube 3D grid as physical hyperspace; on-route topology teaching; feature-to-topology mapping; context as position; doc at data/md/development/HYPERSPACE-TOPOLOGY.md
- `topic-field-coherence-synthesis.md` — bridges all topology docs; one structure, multiple readings
- `topic-friction-visualization.md` — friction as flow turbulence; harmony as coherence artifact; optimization direction as fixed truth; live readout as priority queue; profile drift/recalibration; stats+curve infrastructure
- `topic-job-pipeline.md` — WORKING (session 22): jobs.vhost live, German reason+summary in one pass, retry on timeout, letsencr fixed
- `topic-chat-script.md` — bin/chat COMPLETE (session 23): dispatch wired, all 6 features + summary, timeline, -wait-reply; open: kimi state machine, coding zenka dispatch, phase 2 channels zenka
- `topic-language-detection.md` — three-layer detection (heuristic→wordlist→inference), encoding_map 30 langs, locale vision pipeline with terminal+web+matrix render targets; fix_encoding rewritten generically
- `topic-plugin-web-jobs.md` — plugin.web.jobs.* design: bi-directional sync, B32 backups, replaces export-jobs-json+scp
- `topic-job-pipeline-title-filter.md` — future: batch title screening via AMOS checksums before page fetch; 30-50% savings
- `topic-site-yaml-zenka.md` — on-demand zenka: fetch URL → clean structured YAML; domain regex templates; job/music/podcast discovery; site-auth companion for login-gated sites
- `topic-usb-backup-zenka.md` — udev insertion → task tree: mount→prioritize(LLM)→write→manifest→verify→safe-eject; manifest is self-contained restore agent with P7REFs
- `feedback-task-show-multiline.md` — task.show must escape \\n in description/context; line parsers only see first line otherwise
- `feedback-fork-child-module-loading.md` — parent branch of fork must explicitly load_runtime_modules for all subs it calls; child loads don't reach parent %code

## File Creation Notes (CRITICAL)
- **Never add** the single-line `#,,.,,,...` stub at end of new files
- That line is NOT a valid signature — it blocks the signing system
- Leave new files clean; `bin/Protocol-7 sourcecode update-signatures` adds the real 4-line footer
- Real footer: checksum line, hash line, two AMOS7/YOURUM lines, separator

## System Status

### Completed (Feb-Mar 2026) — details in `topic-completed.md`
- HTTPS httpsd, models memory, models-coding integration, data zenka + SHM
- v7 stdout SHM log, fork-child cleanup, kimi-web WebSocket client
- route-send migration, standalone log_cmd race, non-blocking socket read
- models registry consolidation, coding zenka event loop + switch-model
- zulum→decoder entropy wiring, harmonic transit vision architecture
- signature oscillation Variant A (`2bf1b3d46`), task zenka, models task dispatch
- kimi task-poll async fix, MCP server for Claude Code (`9901a539d`)
- kimi zenka upgrades (JSON/websocket/approval/session), httpsd crash capture
- httpsd non-blocking SSL accept (deployed pri.v7.ax), favicon binary read fix
- kimi reconnect busy-status preservation (`0799bb8d6`)
- llm inline subroutine extraction — kimi task AKXEYFQ (`526d91760`)

### Completed (Mar 28-29 2026)
- Coding zenka chmod child: runs as admin user (taeki), gw/restore/create commands
- edit_file/write_new_file wired through chmod child for direct file writes
- Context compaction verified working: 71→1 msgs, 47%→10% context
- Token estimation 1.4x JSON overhead multiplier, round limit 42→247
- Learning persistence: outcomes.json, get_statistics, check_cache_first, update_success_rate
- Model successfully applied edits to identify_patterns via chmod child
- edit_file defaults to apply=true (model wasn't setting it)
- whats-next reconnaissance template, cmd-style-fix template
- Inline sub extraction: context.* done (8 modules), plugin.storage.cluster.* done (5 modules)
- New tools: replace_in_file (content-based edit), validate_module_format, list_inline_subs
- Extraction template refined: verbatim copy rules, one-at-a-time, new tool workflow
- First fully autonomous extraction succeeded (plugin.storage.cluster.* via task-THFSFBY)

### Completed (Mar 30 2026 — earlier session)
- Inline sub extraction complete: pager.* (30 subs), plugin.storage.* (7 subs), context.* (8 subs)
- All extracted to .util.* namespaces, source call sites updated, zero inline subs remain in pager.*
- Coding zenka tool loop: task_complete + escalate stop signals, record_question/record_suggestion
- Observations stash working: JSONL in /var/protocol-7/coding/observations/
- extract-inline-subs template refined: return sub unwrap, one-call-per-round, task_complete
- Removed 5 .disabled modules crashing loader, fixed regex/interpolation/log-level bugs

### Completed (Mar 30 2026 — Claude session)
- Tree tools: tree_read, tree_write, tree_list modules + P7 cmd wrappers + tool definitions
- Plugin loading: plugins.load + [load_plugins] in coding zenka start (before init_modules)
- Spawn race fix: model_path_reply re-triggers deferred spawn when gpu_pid is 0
- Log refinement: process-queued-task consolidated to 1-line round summary
- 13 new autonomous templates created (all with round budget hints + $ARG preservation):
  autonomous-direction, integrate-recent, p7-style-enforce, fix-format-issues, git-diff-review,
  header-tags-fix, regex-style-fix, param-validation-fix, error-resilience,
  cross-namespace-wiring, observations-triage, post-task-verify, + round budgets on 4 existing
- Bug fixes: tree_read slice undef, tree_read sprintf warn, pager.source.file-list regex crash
- Coding zenka autonomously fixed 6 modules via templates (descr/param tags, format issues)
- $ARG preservation reminder added to all 12 code-editing templates (local model regresses this)
- Verbosity reduced to 2 in zenki/coding/start

### Completed (Apr 2 2026) — details in `topic-completed.md`
- Async HTTP streaming infrastructure: http_client, handler.http_io, chunk_handler, state_machine
- tool_executor, buffer.model_output, callback.http_complete — all committed
- Vision system overhaul, inference crash detect/restart, retry on timeout/5xx
- B32 prefix fix, Jinja sanitization, NShell history fix, 3 new templates

### Completed (Apr 2-4 2026) — async tool loop resolution
- Async tool loop RESOLVED: 29+ rounds, 30+ tools verified by model autonomously
- XML tool call parser (coding.parse.xml_tool_calls) — root cause: model emits XML in reasoning_content
- reasoning_content fallback fix (empty string is defined, use length not //)
- Context compaction (coding.async.compact_context) matching blocking version
- Loop detection ported to async state_machine (detect_loop + assertion + force-stop)
- XML markup stripping from output buffer display
- Shared jinja sanitization (coding.sanitize.jinja_messages)
- Jinja-safe argument re-encoding, retry on 500/timeout, tool_calls stripping

### Completed (Apr 5 2026) — notes tools expansion
- Notes system expanded from 7 to 12 tools: note_tag, note_recent, note_filter, note_history, note_merge
- 5 backends + 5 handlers + 5 tool definitions, all tested via MCP
- Bug fix: note.filter crash — `$meta->{'tags'}` needs `ref eq 'HASH'` guard, not `//`
- Bug fix: note.tag same defensive type check
- List-type backends use `{ mode => 'size', data => $formatted_string }` pattern

### Completed (Apr 16 2026) — graphics-matrix critical path
- 36 new modules across 6 kimi tasks: cursor, glow, channels, address, cells, graph
- Full pipeline: cells → graph edges → clusters → survey → glow → channels → color
- Design: spatial tuning, division-13-table frequency mapping, magenta as alpha channel
- Details in `topic-completed.md`

### Completed (Apr 16-17 2026) — web template pipeline + space.v7.ax
- pattern_split capture group fix: non-capturing groups (?<!...) miscounted, filtered with grep
- web template pipeline: httpd → web zenka → process_template_recursive → plugin commands → HTML
- space.v7.ax vhost: plugin.web.space.* modules (init_code, state, fetch, handler.state_reply)
- content-type override: web.response.content_type template command, IPC header prefix, reply extraction
- .tmpl routing: serve_static + http_head route all .tmpl files through template processor
- HEAD for templates: full render for correct Content-Length/Content-Type, body suppressed
- inline sub extraction (kimi): 3 util modules from plugin.web.content.dirlist + menu.tree
- httpd template content-type: .tmpl matched as text/html, kimi task
- log cleanup: removed level-0 debug scaffolding from IPC/reply handler, switched to base.logs
- $data shadowing fix: renamed to $reply_content in httpd.handler.web_template_reply
- plugin init naming: plugin.web.space.init → init_code for lifecycle hook discovery

### Completed (Apr 27 2026) — session 6
- chk-sum namespace fix: 14 modules had wrong `base.chk-sum.amos` ref after swap_subs reinstall
- coding zenka: CTX% now shown in model_output buffer round headers
- POST /cursor endpoint + visualization debounced push → live cursor-state in graphics-matrix
- visualization: zoom rebound fix (clear zoomTarget on scroll), node glow scales with zoom
- coding.inject-message discovered as mid-task redirect tool
- insight: orbital nodes at low zoom look like planetary system — nested orbit infra already present

### Completed (2026-05-08) — session 12 — valued tree + iteration loop
- valued tree primitive: N+f nodes, ref counting, gradient routing — details in topic-completed.md
- task tree seed: eternal root + 5 category branches + meta-workflow nodes
- iteration loop: score_result, template.delta, loop controller — wired into models dispatch
- sushi coder (Qwen3.5-9B) validated as default: fast, methodical, survives compaction
- line-edit tools: replace_line/delete_lines/insert_line with chmod+stage fallback
- crash restart: watcher pattern fix + queue pause/resume during backend restart
- loop detection: file_not_found_spiral pattern catches core sub search loops
- feature-impl template: core subs note, $call cmd pattern, tool param reference

### Completed (2026-05-09) — session 16 — chmod pipe sync, summarize_context, staging UTF-8 bug
- restore readline missing in all 6 write handlers — pipe desync caused silent staging fallthrough
- coding.task.execute dangling $result after blocking path removal — compile error on reload
- summarize_context: 5 new modules written + corrected (cmd loop, LWP endpoint, json encode, data assignment)
- modules/coding.cfg antipattern caught: config belongs in zenka start file, not modules/
- staging system UTF-8 corruption: open bug, em dash mangled on write/read cycle
- descr tag max 55 chars (pre-commit enforced, now in memory)

### Completed (2026-05-09) — session 15 — review pipeline, templates, chmod child, model eval
- consensus_query tool + :review: task type + review-cycle template (verify-then-find)
- sliding-compact template: tree_read/write state, tested on 214K doc end-to-end
- chmod child reply channel: r_fh captured, child prints ok/skip/err, readline replaces all sleeps
- event-loop-safety.yaml template: written by coding zenka, LWP=blocking explicitly stated
- jinja sanitizer: idempotent backslash fix via (?<!\\) lookbehind
- base.file.read encoding param fix, write_new_file chmod race fix
- model eval: Qwopus correctly flagged LWP as CRITICAL, sushi coder misclassified as safe
- default switched to Qwopus (ZDMAPAY:AR3OCKQ) until evaluation system establishes better
- blocking inference path: async.enabled=1 means process-queued-task is dead code
  removal task dispatched to Qwopus (bd7wocqi6)
- task files: summarize-context-command, tool-hints, rewind-stack+read-only-flag, remove-blocking

### Completed (2026-05-10) — session 19 — job pipeline zenki
- site-yaml zenka: stepstone JSON-LD extraction, job store YAML, web template (jobs.html.tmpl)
- job-site-scan coordinator: stage engine idle→scanning→assessing→reviewing→idle
  var watcher on pending_count gates stage.review — fully event-driven, no poll timers
  named categories (linux-sysadmin, ki-automation, devops, platform-engineer) with real URLs
- job-assess.yaml context template: no_tools, max_rounds=1, profile.txt inject, JSON score output
- multi-category fetch: fetch_pending counter, all categories reply before assess dispatch
- cube auth/access entries for both zenki; plugin.web.jobs.* in web whitelist
- topic-job-pipeline.md written to memory with first-run checklist + HTTP sync design

### Next Steps (immediate)
- **first-run**: p7c v7.restart cube → write profile.txt → p7c job-site-scan.scan
- **profile.txt** at /var/protocol-7/jobs/profile.txt — CV/skills for LLM scoring
- **multi-page search** — stepstone 25/page; cfg.max_pages per category
- **orphan re-queue** — re-create tasks for jobs stuck in 'assessing' after restart
- note_read pagination (offset/limit on sections)
- active deps execution (requires list in task dispatcher)
- think-block stripping — <think>...</think> from Kimi/Deepseek leaks into output
- task.cmd.start — task zenka step 3

### Planned / Future
- **HTTP sync** — /api/jobs/sync httpd endpoint, C25519-signed YAML payload, last-write-wins merge;
  see `topic-job-pipeline.md`; deferred until remote server model selection settled
- **USB backup zenka** — udev medium insertion → watcher → backup task tree; see `topic-usb-backup-zenka.md`
- **site-auth zenka** — session/auth for scrapers requiring login (companion to site-yaml)
- **job automation workflow** — pipeline PARTIALLY IMPLEMENTED: site-yaml + job-site-scan zenki done;
  remaining: jobtracker integration (existing HTML/JS tool, CSV/PDF), email reply monitor (Gmail zenka)
- **base.handler.command refactor**: plan at `data/md/development/BASE-HANDLER-COMMAND-REFACTOR-PLAN.md` — identical-behavior extraction steps, namespace map first, per-session isolation as boundary, cross-reference maps (`$data{'route'}`) as only explicit cleanup surface. Claude designs seams + namespace map; local models execute. Related to SIZE packet loss bug below.
- **SIZE packet loss bug**: STRM interaction causes zenka to stop returning SIZE replies until an unrelated command (e.g. `heart`) is sent. No reliable reproducer yet — radio zenka group expected to trigger it. Investigate alongside or before the refactor.

### Active / Partial
- **namespace tree as intelligence layer**: see `topic-namespace-tree-intelligence.md`
- **deferred compilation stubs** (Mar 15): partial — deeper namespace/phase work pending
- **task coordination architecture**: see `topic-task-coordination.md` for full state + roadmap
- **multi-model consensus**: llm.service.consensus_vote modules extracted but untested
- **signature "no separator endline" bug fix**: resolved bug where harmonize_payload_line_feed was incorrectly called when endline_modification_state==7 and last_line_incomplete was set; fix tested and verified working

### Open Bugs / Cleanup
- **config double-load bug**: duplicate config key warnings — see `bug-config-double-load.md`
- **signature oscillation Variant B**: double-footer on never-signed non-empty files
- **repo var/ cleanup**: `var/httpd/` tracked from Nov 2025 AI error
- **dep-graph lifecycle hook gap**: see `feedback-devmod-whitelist.md`
- **kimi-web session data loss** (Mar 21): backup at `/data/backup/kimi/kimi-sessions.full_dir.0000.tar.xz`
- **kimi auto-approval regression** (Apr 16): some tool calls not auto-approved during kimi tasks,
  requires manual approval in web UI. observed in tasks 3+4. may relate to ask-reply task queue wiring

## Key Technical Insights

### Standalone Zenka / fork-child / Pipe-Open / Inference Server patterns
- See `topic-patterns.md` for full details

### Config String → Arrayref Pattern
- P7 start file values are scalars — `work.git.remotes = hub ext-bundle` sets string, not arrayref
- Fix in init_code: `if defined and not ref → split m|\s+|, $val into arrayref`

### protocol-7.route-send (CRITICAL)
- Wraps `send.local`, auto-prepends `<protocol-7.network.parent_route>`
- **Returns count of sent commands (0 or 1), NOT the reply data**
- Replies arrive asynchronously via the `reply.handler` callback
- Use `call_args => { args => $string }` — NOT `param => { hashref }`
  (`param` hashref is never transmitted; only `call_args.args` string is sent)
- For async chains: pass state via `reply.params`, dispatch in handler
- Use for cube-routed commands (`v7.*`, `httpd.*`, `p7-log.*`, etc.)
- Do NOT use for `child.*` commands (local socketpair aliases)
- Multiline args corrupt protocol framing — base32r encode or collapse newlines

### Event Timers (CRITICAL)
- Repeating timers require BOTH `'interval' => N` AND `'repeat' => TRUE`
  - ❌ `'repeat' => 62` (no interval → error)
  - ✅ `'interval' => 62, 'repeat' => TRUE`
- One-shot timers: `'after' => N` with no interval key

### Module Loading (CRITICAL)
- `base.perlmod.autoload`: one module per call, NOT a list
  - ❌ `<[base.perlmod.autoload]>->(qw| IPC::Open3 YAML::XS |)`
  - ✅ `map { <[base.perlmod.autoload]>->($_) } qw| IPC::Open3 YAML::XS |`

### Module Invocation Syntax (CRITICAL)
- ALWAYS `<[module.name]>->($args)` — closing `]>` BEFORE `->`
  - ❌ `<[module.name]->($args)`
  - ✅ `<[module.name]>->($args)`

### Inter-Process Communication
- Use `<[base.protocol-7.command.send.local]>->(\%params)`:
  ```perl
  my $cmd_count = <[base.protocol-7.command.send.local]>->({
      'command'   => 'target.name',
      'call_args' => { 'args' => $data },
      'reply'     => { 'handler' => 'caller.handler.reply',
                       'params'  => { 'context' => $value } }
  });
  ```
- Returns: number of commands sent (0 if target offline)
- Base32: `encode_b32r()` / `decode_b32r()` from `Crypt::Misc`

### Logging and Log Levels
- `base.logs` handles sprintf format strings; `base.log` has default log_level [1]
- Log levels: 0=error, 1=default, 2=info, 3=debug
- Format: `:. :` at start/end; no variable interpolation in logs — use sprintf format codes

### Code Style Conventions
- Lowercase comments: `## read config from file` (not `## Read Config`)
- Annotations: `[ word ]` not `( word )`; relative paths: `center_ellipse_string`
- `$ARG` instead of `$_`; `$data_ref->%*` style dereferencing

### File Ownership and Permissions
- Files: 0664, directories: 0775 (group writable)
- `getpwnam` returns `(name, passwd, uid, gid, ...)` — uid at index 2, not 0
- Namespace swapping: `base.file.*` → `file.*` via swap_subs in base.file.init_code

### AMOS Checksums
- 7 characters, pattern `^[A-Z0-9]{7}$` (not 9)
- Use `AMOS7::TEMPLATE` with CODE ref collision detector for unique generation

### Harmonized Ref String Format
- `TYPE:CHKSUM7:ADDR_B32` where ADDR_B32 is `[2-9A-Z]{1,16}` (NOT fixed {16})
- All parsers aligned to `{1,16}`: decode_harmonized_refstr, data-keys.find_perlref
- Generator (gen_template_chksum) and syntax.p7_reference already used `{1,16}`
- Regex delimiter must not conflict with `{1,16}` — use `m''` not `m,,` for these patterns

### Protocol::WebSocket::Frame Constructor (CRITICAL)
- ✅ Always: `Frame->new( buffer => $text, type => 'text', masked => 1 )`
- Set `max_payload_size => 16 * 1024 * 1024` for large messages (tool results)
- `->next` DIES on oversized frames — wrap in eval

### JSON decode_json vs from_json (CRITICAL)
- `JSON::decode_json($text)` expects raw UTF-8 **bytes** (octets)
- `JSON::from_json($text)` accepts decoded Perl **character strings**
- `Protocol::WebSocket::Frame->next` returns decoded strings with UTF-8 flag set
- ✅ Use `from_json` for websocket text frames, `decode_json` for raw I/O

### file.slurp Returns Scalar Ref (CRITICAL)
- `<[file.slurp]>->($path)` returns `\$content`, NOT `$content`
- Dereference: `->$*` or `$$ref` — otherwise stringifies to `SCALAR(0x...)`
- Pattern: `my $content = <[file.slurp]>->($path)->$*;`

### system.zenka.initialized Flag
- FALSE during initial startup, TRUE after zenka goes online
- Stays TRUE during reload (end_code does not run on reload)
- Use to distinguish real restart from reload in post_init

### Deferred Zenka Online (`base.async.get_session_id`)
- Remove `[get_session_id]` from start file; call from within event loop when ready
- Guards: idempotent; use `<zenka.session.acquired>` flag against reconnect duplicates

### Config Variable Path Conflicts (CRITICAL)
- `<a.b.c>` and `<a.b.c.d>` CONFLICT — `a.b.c` is scalar, `.d` tries to deref as hash
- ✅ Use flat sibling name: `<kimi.connect.retry_cur>` not `<kimi.connect.retry_delay.current>`

### Swap-Boundary Module Dispatch (CRITICAL)
- `<[chk-sum.amos]>` fails P7 pre-validation during base init (swap not yet applied)
- `<[base.chk-sum.amos]>` fails after re-init (swap already applied, name gone)
- Fix: use raw `$code{}` dispatch — checked at runtime, not compile time:
  ```perl
  my $amos_chksum = $code{'chk-sum.amos'} // $code{'base.chk-sum.amos'};
  $amos_chksum->($input);
  ```
- Pattern applies to any module called across a swap boundary

### Style Conversion Hazard: TRUE ≠ 1 (CRITICAL)
- `TRUE=5`, `FALSE=0`, `UNKNOWN=2`
- `> 1` checks trigger on `TRUE` (5) — use literal `1` for "more to read" return codes

### PERSISTENT_AMEND env var
- Not normally set; prefix git commit to override: `PERSISTENT_AMEND=0 git commit -m "..."`

### `log.base_log_complete` core sub
- Gates full log chain readiness; state-cached with `state $are_present`; checks `exists`

### Warning Capture in Sort Blocks
- `<=>` on non-numeric emits warning, not exception — `$EVAL_ERROR` stays empty
- Use `looks_like_number()` (Scalar::Util, already loaded) pre-pass before sort
- Pattern: `my @non_num = grep { defined $data_ref->{$ARG}->{$key} and not looks_like_number(...) } keys $data_ref->%*`
- Global `$SIG{__WARN__}` exists — if wrapping warn handler, capture `$prev_warn = $SIG{__WARN__}` first and call through

#,,..,,..,,.,,...,,,,,.,.,,,.,...,.,.,,,.,,,.,..,,...,..,,..,,,,,,..,,.,,,..,,
#QJSW5OCAGHI6W63RWFI3DVPPEVWYLHUINOHH27C226TLNI5PUMD4QD5BWOBLRMI5ORVE4LEG4JKHE
#\\\|XXEW74BXC3OUJIPIAYJA7I6JLTZLM7GXOJHDRRIR6TGZBLYZ3JL \ / AMOS7 \ YOURUM ::
#\[7]YLZYWUKERJTGTJYDOEROGLNSLNLD3LMZFU23WDWIC5YOXSBPBODQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
