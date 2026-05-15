# Completed Work Sessions

## session 25 — httpd route registry + jobs UI (2026-05-15)

- **httpd route registry**: `configuration/zenki/httpd/routes` config file,
  `httpd.route.init_code` parses at startup, route_dispatcher checks as Route 0.
  Exact + prefix matching, ANY wildcard. cursor/context handlers moved out of http_post.
- **plugin.web.jobs cleanup**: swap_subs removed, JSON::XS+YAML::XS preloaded in init_code,
  handler.get→data + handler.sync→sync rename, per-call autoloads removed
- **jobsite.job.* path fix**: hardcoded 'jobsite' subdir via system.path.zenka-dirs —
  cross-zenka safe. file.make_path (post-swap name) for dir creation with correct ownership.
- **jobsite.util.build_prompt**: `${candidate_name}'s` apostrophe warning fixed
- **client sync rewrite**: lastNtime watermark, pushChange() POSTs on field change,
  30s auto-poll, localStorage demoted to reload cache
- **drain_pipe fix**: poll:'r' not 're' — eliminates IO::Async 'unexpectedly closed'
  warnings on coding.switch-model
- **jobs.vhost toolbar**: two-row layout, no-flicker sync button (label span),
  styled score slider, buttons scaled to match filter tabs

**Key lesson**: deferred P7 reply from httpd (route-send to jobsite, reply handler
writes HTTP response) is fragile — flush_shutdown vs flush, session lifetime,
crashes in loops. Web zenka is the right relay for distributed case because it
runs parallel to httpd as a stateful zenka, not as a request handler.

**Key lesson**: plugin.web.* belongs to web module dep namespace — httpd needs
explicit `[base.white-list.register:'plugin.web.jobs']` in start file. plugin.httpd.*
loads automatically. Foreign namespace plugins don't pre-load without registration.

## session 17 — summarize-context command (2026-05-09)

### summarize-context feature (fully working)
- `coding.cmd.summarize-context` — async deferred reply via task.enqueue,
  `:file:`/`:path:` prefix, `:b32:` prefix, `path=` kwarg, base32 auto-detect,
  relative path via system.root_path, file.encoding + file.read
- `coding.tools.handler.summarize_context` — LWP handler for tool use within tasks,
  JSON->utf8->encode bytes fix, port fallback gpu when cpu disabled
- `base.file.encoding` — BOM + UTF-8 probe, returns :encoding(X) string
- `task.cmd.summarize` + `task.handler.summarize-reply` — task zenka layer
- salvage of model-generated .pm files: wrong format, wrong endpoint, wrong args

### feature-impl template improvements
- handler module pattern (shift not $call), zenka config paths, m{} delimiter rule,
  base.cmd.* shadow warning, system-tools.yaml summarize_context entry

### model comparison (same file, CONCEPT-HARMONIC-VISUAL-INTELLIGENCE.md)
- Qwopus 9B v3: clean 4-para summary, no artifacts, preserves all specifics
- Kimi VL A3B Thinking: think-block leaked, AMOS signature confused for hash,
  otherwise comparable quality — faster at 3B
- Deepseek Opus distilled 9B: clean structured summary with headers, most complete,
  caught implementation status + harmonic entropy research connection

### deferred: think-block stripping for Kimi output, AMOS sig note in system prompt

## session 12 — valued tree + iteration loop + sushi coder (2026-05-08)

### valued tree primitive (modules/valued.*)
- valued.init_code, valued.node.create/add_ref/remove_ref/set_weight
- valued.resolve (N+f effective priority), valued.tree.load/register_node
- valued.tree.record_outcome, valued.tree.persist/restore (survives restarts)
- valued.cmd.list, valued.cmd.stats, valued.tree.top_n
- context.priority.rank wired to valued tree (live gradient over static weights)
- task.cmd.complete/fail wired to valued.tree.record_outcome (feedback loop)

### task tree seed (data/yaml/task-tree/)
- root.yaml (eternal attractor), branches.yaml (5 categories)
- branches-intelligence.yaml (intel sub-branches with bootstrap weights)
- branches-meta-workflow.yaml (post-success/blocked/surprising, workflow-query,
  template-query, session-summary — parallel non-blocking activities)

### iteration loop system (modules/iteration.*)
- iteration.init_code, iteration.loop, iteration.score_result
- iteration.template.delta (issue-to-patch classifier)
- iteration.finish, iteration-loop.yaml template
- wired into models.task.execute + models.handler.task-result
- tasks with iteration:true auto-retry with issues appended, escalate on failure

### task zenka commands
- task.cmd.next (gradient-sorted autonomous routing via valued.resolve)
- task.cmd.handover (queue state packager for session handover)

### coding zenka improvements
- line-edit tools: replace_line, delete_lines, insert_line (with chmod+stage)
- fixed: slurp ARRAY fatal warnings → scalar slurp + split
- fixed: tool_executor die hash (odd elements bug)
- fixed: inference_crash_restart watcher pattern (shift->w->data)
- queue pause/resume during crash restart
- loop detection: file_not_found_spiral pattern (catches core sub search loops)
- feature-impl template: core subs note, $call cmd pattern, tool param reference

### sushi coder (Qwen3.5-9B sushi) validated as default model
- fast, methodical, correct logic on first attempt
- survived context compaction mid-task (113→1 msgs, 55K→10K tokens)
- high reasoning + feature-impl template = reliable feature implementation
- remaining issues: newline-stripping in write_new_file, descr length

### next steps (planned end of session)
- task.cmd.start — step 3 of task zenka implementation plan
- valued.cmd.query — network command wrapping valued.tree.top_n  
- meta.session-summary wiring to task.cmd.handover on session end
- model evaluation workflow — first automated comparison run
- template: search_code parameter reminder, write_new_file newline note
- test iteration loop end-to-end with a real task marked iteration:true

## session 11 — module cleanup + parser tooling (May 3 2026, late)

- 94 modules across plan-9.*, storage.*, base.editor/encode/decode.*,
  plugin.storage.*, command.*, amos-term.* had `return sub { }` wrappers —
  caused modules to return coderefs instead of executing; all fixed
- `bin/dev/parsers/strip-return-sub`: new tool handling all three sub-patterns
  (multi-line+`my ($call)=@_`, multi-line plain, single-line); runs with `--all`
- `AMOS7.key-32-safeguard` deleted — dead code, knowledge in `AMOS7/13.pm`
- `<[$var]>->()` dynamic dispatch added to bin/Protocol-7 parser:
  `<[$var]>->($arg)` → `$code{$var}->($arg)`, `<[$var]>` → `$code{$var}->()`
- docs updated: CLAUDE.md, coding.system_prompt, data/ai-mem/kimi/coding-style.md,
  data/yaml/ncode-patterns/p7-style.yaml, memory/feedback-p7-module-call-syntax.md

## session 7 — coding zenka stability: spawning, subtasks, context, loops (May 1 2026)

### Spawning fixes
- `spawn_inference_server`: centralized `spawning_in_progress` guard (TRUE/FALSE) covering ALL call paths (crash-restart, timeout-recovery, model_path_reply, deferred timer) — was only in `async_spawn_inference_servers` which missed direct callers
- Stale-port kill race: `@killed_stale_pids` tracked from fuser scan, skipped in foreign-process pgrep check
- Pipe drain: `cancel_watcher.backend_monitor` replaces startup watchers with drain watchers (stored as `watcher_drain_stdout/stderr` in inference_servers hash); `spawn_inference_server` cancels drain watchers on respawn; `drain_pipe` precheck `fileno()` before sysread to avoid Perl warning; drain watcher self-cancels on EOF/EBADF
- Context auto-scaling: `inference.model.context_length` is now a **floor**, not a fixed value — servers use `max(auto_calc, configured_floor)` so small models get more context automatically
- `vram_safety_min_mb`/`vram_safety_max_mb` configurable in start file (defaults 512/3072)
- `max_tokens` defaults to `context_length` when not set separately (one config value)

### Task management
- `task-append`: new command to append user message to any task regardless of state; completed/failed tasks are resumed with full message history + tools restored (tools re-assembled from `coding.tools.definitions` if not saved)
- `coding.async.complete`: saves `messages` + `tools` to task record before state cleanup (enables task-append resumption)
- `coding.async.complete` fail path: inlines task status update (bypasses buggy `coding.task.fail`), removes from active list, fires deferred reply so `ask-reply` unblocks on failure

### Context/compaction
- `send_request`, `compact_context`: use actual server `n_ctx` from `inference_servers->{'n_ctx'}` instead of configured `context_length` — compaction threshold and overflow check now scale with model
- Context overflow: clean fail with error message instead of 200-token silent stub
- Context pressure warning: when `max_tokens < 3000`, inject `[CONTEXT PRESSURE]` user message so model can adapt strategy (break into chunks, shorter writes)

### Loop detection
- `stuck_retry` pattern: weight threshold removed — any tool called 3× in a row is a stuck loop (`allow_polling: 0`, no assertion)
- `model_output` buffer: always written even when model produces no text (shows `[tool call — no reasoning text]`), so `show-buffer model_output` always works
- Loop assertion interception: when `loop_assertion_pending` flag is set, `finish_stop` intercepts the model's assertion answer instead of completing the task; processes it through detect_loop assertion phase, injects "please continue" message, re-enqueues round
- **Open**: `loop_detect_count` is still global/zenka-wide — should be per-task in `$state`

### Config cleanup
- VRAM safety, context floor, max_tokens, and vram_safety_min/max all grouped in start file model configuration section

## session 6 — coding zenka improvements + cursor address wiring (Apr 27 2026)

### chk-sum namespace fix (systematic)
- 14 modules had `<[base.chk-sum.amos]>` — wrong after namespace reinstall with swap_subs
- ncode replace → all fixed to `<[chk-sum.amos]>` (local namespace)
- affected: graphics-matrix.cursor.checksum, pager.*, plugin.storage.checksum.*, context.tree.*, kimi-web, note.tree

### coding zenka: CTX% in model_output buffer
- round header now shows `[CTX:XX%]` on assistant turns
- `pct_used` passed via context hash to `coding.buffer.model_output`
- both user and assistant headers have the slot; pct only available post-inference on assistant side

### cursor address resolution layer
- `POST /cursor` endpoint added to `httpd.http_post`
- new module `plugin.web.space.handler.cursor_update`: reads JSON {selX,Y,Z}, routes to `graphics-matrix.cursor set x y z`
- `moveSelection()` in visualization.html now calls debounced `scheduleCursorPush()` (150ms)
- `p7c graphics-matrix.cursor-state` now reflects live browser navigation position
- bug fixed: premature `scheduleCursorPush()` call before `let` declaration blocked entire JS

### visualization bug fixes
- zoom rebound: `zoomTargetRotX/Y/Z` cleared on manual scroll so it can't fight the user
- orbital node glow scaled with zoom: `glowScale = Math.max(0.15, Math.min(1, zoom))`
  fixes sphere appearing to grow when zooming out (fixed-pixel glow halos were merging as nodes clustered)

### coding zenka: inject-message command
- `p7c coding.inject-message <task_id> <message>` injects a user turn into active task
- useful for redirecting stuck model mid-task without stopping and restarting

### insight: orbital nodes as planetary system
- at low zoom, self-node + known peers looked like a blue sun with 3 orbiting planets
- orbital ring radius 140 = CUBE_SIZE; FORMATION_SPACING/2 = 210 may be better (midpoint to next group)
- nested orbit infrastructure already present: discover.orbital.*, nodes.orbital.*, plugin.web.space.orbital.*
- shell-2 data via grid fragment sync → render at radius 280 (nameserv radius) would deepen the effect

## orbital pipeline + visualization wiring (Apr 26 2026)

commits `fbb4d246d`–`6e02d1475` on branch `base`

### orbital → graphics-matrix bridge
- plugin.web.space.orbital.to_cells: maps theta/phi/psi → cell coords, places in graphics-matrix
- graphics-matrix.cmd.orbital-sync: JSON-encoded glow_shells/channel/graph reply
- orbital.json enriched with glow_shells, channel, graph from graphics-matrix
- visualization: glow radius modulation, channel.palette trail tinting, cluster indicator

### send.local → route-send fix (root cause: web plugin context)
- web plugin modules need route-send for cross-zenka calls; send.local only reaches httpd↔web IPC
- fixed in: orbital.fetch, space.fetch, orbital.to_cells

### command routing fixes (multi-dot names don't route)
- all .cell.place/.cursor.set/.glow.compute → single-dot with subcommand in args
- nodes.orbital.current_position → nodes.cmd.orbital-position (mode=size key=value)
- discover.orbital.grid_fragment → nodes.cmd.orbital-grid-fragment

### nodes → discover p7ref push
- nodes.orbital.update_position: route-send to discover.orbital-p7ref-update each 13s tick
- nodes.cmd.orbital-p7ref: plain string reply for simple parsing
- discover.cmd.orbital-p7ref-update: stores p7ref for mcast packet inclusion
- format_discover_mcast_packet: appends p7ref line when cached

### other fixes
- graphics-matrix idle timeout 23s → 420s (orbital fetch cycle is 13s)
- orbital.handler.reply: known/connections empty-response guards
- httpd POST /context: force Connection: close (body bleed on keep-alive)
- plugin.web.space.cmd.context: stores zoom/intent/history
- kimi reconnect: flush pending approvals on session restore
- bin/kimi-task: UTF-8 encoding fix (encode_utf8 before b32r)
- nodes.orbital timestamps: base.time → base.ntime

### result
orbital.json live with self + known nodes, visualization rendering at space.v7.ax,
graphics-matrix glow/channel data flowing. self-echo test confirmed pipeline end-to-end.
distinct nodes visible once second P7 instance joins network.

## radio zenka — full stack + resilience (Apr 23-25 2026)

### base infrastructure (Apr 23, commit `61688a279`)
- `event.add_idle` helper added to base event API
- `base.stream-file` command: idle-driven streaming of a file over STRM to caller
  (bounded, non-blocking, exercises full STRM stack without unbounded extension)

### radio phases 1-4 (Apr 23-24, commits `9c4875214`–`707415c7b`)
- **phase 1** (`9c4875214`): ICY stream reader + unbounded STRM relay to listeners array
- **phase 2** (`dc9243962`): jingle detection (radio.filter.jingle) + skip/keep commands
- **phase 3** (`498a12c73`): keep-library accumulation + gap filler (idle watcher, since replaced)
- **base** (`cf2f6c023`): local STRM consumer primitive (base.strm.local.register/cancel/consume)
  + recv-test dev tool (base.strm.callback.recv_test)
- **httpd bridge** (`b6e20ce10`): plugin.httpd.radio.* — /radio/stream HTTP endpoint, per-client
  radio.listen STRM subscription
- **TCP rewrite** (`f388f8674`): replaced curl subprocess with base.open ip.tcp + IO::Socket::SSL
- **phase 4** (`707415c7b`): mpv[audio-0] background player via v7.start_once + v7.notify_online;
  fade-in to configured volume; TLS connect + strm_open guard on route collapse

### STRM cancel + cmd_id fixes (Apr 25, commit `01b6be26e`)
- `base.session.cancel_route`: sends `($cmd_id)!TERM!\n` to target on consumer disconnect;
  sets stream_cancelled + cleans stale route entry — prevents cube undef-deref crash
- cmd_id format fixed: `sprintf '(%d)'` (no trailing space) in base.handler.command,
  base.stream.open, base.stream.emit, base.callback.cmd_reply
- mpv command renames: add_file→append-play, mpv_pid→pid, is_idle→is-idle,
  get/set_speed/volume→get/set-speed/get/set-volume

### radio resilience refactor (Apr 25, commit `a4154a294`, kimi task radio-resilience)
- **reconnect**: exponential backoff (5s→60s) via radio.handler.reconnect; guards double-schedule
- **gap_fill pacing**: replaced Event->idle with 1s repeating timer; chunk 65KB→16KB (~128kbps);
  fixes "stopped suddenly" mpv disconnect caused by STRM buffer overflow
- **mpv offline handling**: radio.audio.handler.player_offline clears active flag, re-inits after 3s
- **post-hoc jingle detection**: tracks under min_track_seconds trigger gap_fill retroactively;
  magicstreams/PsyNdora added to filter patterns

### verified working end-to-end
- TLS connect → ICY parse → jingle filter → gap_fill → STRM relay → httpd → mpv/curl
- STRM cancel on client disconnect propagates correctly back to radio producer
- mpv[audio-0] starts automatically, survives v7 restart and reconnects within 3s

## graphics-matrix critical path — 36 modules in 6 kimi tasks (Apr 16 2026)
Full critical path implemented via kimi task dispatch (bin/kimi-task -next):
- Task 1 (82bbf70): cursor namespace bridge — 7 modules (cursor.init/move/position/set/checksum, cmd.cursor, cmd.cursor-state)
- Task 2 (60a267a): glow intensity layer — 4 modules (glow.init/compute/query, cmd.glow)
- Task 3 (8bca17e): context channel frequency separation — 6 modules (channel.init/select/current/translate/palette, cmd.channel)
  - f4 (diagonal/hyperspace) = alpha/mask channel, not opaque; magenta = transparency bridge
  - Convert::Color::HSV used (not manual HSV→RGB), autoloaded in init_code
- Task 4 (b990d6f): address resolution layer — 5 modules (address.init/register/resolve/encode, cmd.address)
  - 6 addressing schemes: decimal, checksum, directional routing, octal-7, base32, channel-qualified
  - Dual kimi session coordination via TASK.md (archived)
- Task 5 (bd672fb): lattice cell storage — 7 modules (cell.init/place/remove/query/survey/list, cmd.cell)
  - Glow bridge: cell.survey counts refs by hop → glow.compute → channel.translate → color
- Task 6 (60e0f9b): similarity graph — 7 modules (graph.init/connect/disconnect/neighbors/cluster/survey, cmd.graph)
  - Edge-weighted survey: connected cells contribute refs*weight, cluster boost 0.3, base 0.1

Design additions: spatial tuning section (364° circle, 7-zenki formation, palette translation,
snake game data flow, hyperspace channels, division-13-table as frequency generator, magenta as alpha)

Issues found: kimi auto-approval regression (some tool calls need manual approval in web UI);
bin/kimi-task without -next returns cached output but session keeps working in background

## kimi session management + task dispatch hardening (Mar 23 2026)
New modules: `kimi.session.create` (extracted REST session creation), `kimi.session.reset_and_reconnect`
(fresh session for `:next:` prefix), `models.handler.notify-online-reply` (dispatch after online confirm).
`:next:` prefix: `models.task.execute` prepends to all prompts, `ask-reply` detects it, stores deferred,
triggers reset_and_reconnect, ws_message dispatches after ready. `v7.notify_online` extended with `:start:`
prefix (calls start_once before waiting). `models.task.execute` gates dispatch on `v7.notify_online :start:`
— prevents "route collapsed" on restarts. Kimi startup: `get_session_id` in start file (immediate online),
`kimi.connect` via 0.5s timer (non-blocking for v7). Stale session verification via GET (handles 200+null
and archived). Idle disconnect: no aggressive retry, reconnect on demand in `ask-reply`. Websocket
`SO_RCVTIMEO` for handshake timeout. All `perlmod.load` moved to init_code. `decode_json` → `from_json`
fix in `kimi.session.create`. Task T32NUNA assigned to kimi for self-review of remaining style/architecture
issues.

## kimi zenka upgrades (Mar 21-22 2026) — commits `8452304ae` through `772e7e964`
JSON parse root cause: `decode_json` expects UTF-8 bytes but websocket frame parser returns
decoded Perl strings; multibyte chars (box-drawing `┌─│└`) caused silent parse failures with
empty `$@`. Fix: `from_json`. Approval replay dedup: kimi-web re-sends pending approvals on
reconnect; `responded` hashset persisted to `/var/protocol-7/kimi/approval_responded` (one UUID
per line); `session.acquired` guard drops approvals during history catchup; dedup drops re-sends
after initialize. New commands: `new-session` (clear+reconnect), `session-info` (state dump).
Added devmod, format.json modules to kimi start. Websocket eval wrapper for frame parse errors.

## httpsd crash capture fixes (Mar 21-22 2026) — commits `785b51751` through `a7763b0da`
(1) `file.slurp` returns scalar ref — `split("\n", $content)` stringified to `SCALAR(0x...)`;
fix: `->$*` dereference. (2) Buffer init moved from init_code to collect module (on-demand);
`buffer.httpsd-crash-log.log_cmd` config line replaced with `httpsd.cfg.request_capture_send`
flag, buffer+log_cmd set in collect on first use. (3) Reload false-positive: `post_init` re-runs
on reload, collecting normal operation capture file as crash; guard: `return if
<system.zenka.initialized>`. (4) Cert path renamed `current.pem` → `default.pem` aligning
with content dir convention; premature file-existence warning removed from pre_init; discovery
overwrites path in post_init anyway. Task file for deeper cert architecture cleanup created.

## httpsd SSL handshake hang (Mar 22 2026) — investigation, not yet fixed
Crash capture (now working) shows `ssl-handshake-start` event from AWS EC2 IPs. V7 console
shows rapid "connection was closed" + SNI callbacks then zenka becomes unresponsive to heartbeat.
V7 TERM→KILL→restart cycle. Root cause: likely blocking IO::Socket::SSL accept when client sends
partial ClientHello then goes silent. Needs non-blocking SSL accept with timeout.

## signature oscillation Variant A fix (Mar 16 2026) — commit `2bf1b3d46`
state=7/6 encoding fix in source.create_harmonic_footer (0-newline bodies → state=7,
empty files → state=6); "remove exactly N" restore semantics in
source.restore_payload_endline_state (was "strip all + add N"); 109 files resigned.
New tool: sourcecode.console.report-endline-state (3-bit state from footer first line).
test.0/1/2/3/empty created; verification YAML at data/yaml/coding-tasks/signature-endline-state-verification.yaml.
Variant B (double-footer on never-signed non-empty files) remains open.
Archive: data/yaml/archive/completed-fix-tasks/signature-oscillation-variant-a.yaml

## non-blocking socket read fix (Mar 7 2026) — commit `0c590de22`
Three bugs: (1) `io.unix.socket.input.connect` missing `blocking(0)` after accept() — TCP/SSL
had it from `2d64177a3` but unix was missed; (2) `net.read_linewise_estimated` returning `TRUE`
(=5) for incomplete — style conversion changed `return 1` to `return TRUE`, but `> 1` in
`base.handler.read` triggered disconnect; (3) `base.handler.auth` missing newline guard

## standalone zenka log_cmd race fix (Mar 4 2026) — commit `8f81bfdb1`
Ctrl+U in AMOS7::TERM called `Event::loop(0.07)` which fired idle send-buffer callback installed
before `pre_init` could delete `log_cmd`. Fix: `buffer.zenka.log_cmd = ''` in start file after
`[load_config_file:'shared-params']` and before `[load_modules]`. Applied to: sourcecode, keys, work.

## work zenka cleanup (Mar 4 2026) — commit `8f81bfdb1`
Removed network modules; 8 obsolete work.cmd.* deleted; work.init_code splits remotes string
to arrayref; explicit remotes: `hub ext-bundle`

## kimi-web WebSocket client zenka (Mar 2 2026) — commit `68af03d0a`
14 new modules: `websocket.*` + `kimi.*`; models.chat routes kimi/kimi-code through kimi_web;
deferred get_session_id — online only after WS+initialize handshake; backoff 2→4→…→60s

## route-send migration + binmode fix (Mar 2 2026) — commit `0c1f202ba`
`cube.X.Y` → `protocol-7.route-send` across all zenki; pipe-open `:utf8` fix

## fork-child cleanup + sig_chld pid filter (Mar 2 2026) — commit `1ffe1d2fa`
image2html, pdf.html, vision-batch pattern unified; `base.handler.sig_chld.shutdown` upgraded

## v7 stdout SHM log (Feb 27 2026)
`/dev/shm/.7/STDOUT/<socket>`, early message reconstruction, banner re-emit, colored output

## models registry consolidation (Mar 8 2026)
JSON registry removed; unified `models.resolve.entry` (aliases→definitions→registry);
both `get_path_by_amos` and `get_model_path` return YAML (file_path, mmproj_path, is_vision,
quantization, context_size, batch_size); 7 dead JSON modules deleted; `update_model_entry`
saves via `yaml_save`

## coding zenka event loop + switch-model (Mar 8 2026) — commit `56a60310f` area
- `@lines[-3..-1]` lvalue exception when `@lines < 3` → 93% CPU busy loop in event handler
- blocking LWP/system/IO::Socket in dependency callback → replaced with status field lookup
- IPC::Open3 pipes blocking by default → fcntl O_NONBLOCK after open3()
- switch-model: auto backend (gpu first, cpu fallback); kill old server before VRAM check;
  0.3s wait for GPU driver VRAM release; use provided model_path directly in spawn_smart

## Async HTTP streaming infrastructure (Apr 2 2026) — commits `8b237edc2` area
Full async inference pipeline for coding zenka committed:
- `coding.async.http_client` — non-blocking HTTP with event-based I/O
- `coding.handler.http_io` — SSE chunk parsing, chunked encoding support
- `coding.async.chunk_handler` — extract content/reasoning_content from deltas
- `coding.async.state_machine` — 7 states (STREAMING, TOOL_EXEC, USER_INPUT, SUBTASK, PAUSED, COMPLETE, ERROR)
- `coding.async.tool_executor` — dispatch tool calls, collect results, resume streaming
- `coding.buffer.model_output` — chat-like formatting with box drawing
- `coding.callback.http_complete` — debug logging added for tool loop investigation
Basic streaming works. Tool execution loop broken (tasks complete after first response).
See `topic-async-tool-loop-debug.md` for full debug state.

Also completed: vision system overhaul (shared HTTP backend, OOM protection, mmproj detection),
inference server crash detection + auto-restart, retry on timeout/5xx, intelligent loop detection,
B32: prefix handling fix in single-line mode, Jinja template sanitization, NShell history nav fix,
zenki-create/zenki-feature-port/footer-cleanup templates added.

## Coding zenka self-improvement cycle (Mar 29 2026)
- Inline sub extraction: context.* (9 subs → 8 modules, manual), plugin.storage.cluster.* (6 subs → 5 modules, autonomous)
- Pager extraction failed (wrong structure, edit mismatches) → diagnosed → refined template + new tools
- New tools from model self-reflection: replace_in_file (content-based edit), validate_module_format,
  list_inline_subs, replace_all flag. Model suggested these after meta-reflect tasks.
- drop_privs moved into coding.init_code after check-zenka-paths + chmod child fork
- Path escape hardening: Cwd::abs_path in dispatch and write_new_file
- Compaction threshold 53%, max_tokens 8192, context-tree path fix
- Extraction template refined 3x: verbatim copy, no return sub{}, one-at-a-time, tool workflow
- Tool suggestions tracker created (topic-tool-suggestions.md) for deferred improvements
- Commits: c0f31ed72 (context extraction + hardening), 774836862 (template v1),
  638686882 (template v2 = commit 7000), bbb9fd34b (new tools), 2e13d3817 (autonomous extraction)

## invoke model recovery + adapter design (Apr 7-8 2026)
- `bin/scripts/invoke-ai/invoke-symlink-repair` (new): queries invokeai.db, creates {base}/{type}/{name}→uuid
  symlinks, sd-1+sd-1.5 dual aliases, decoded+%xx filename variants, --dry-run/--type/--verbose
- `invoke-model-recover` 4 fixes: (1) UUID path → {uuid}/model.safetensors destination, (2) diffusers
  always use download_diffusers_model (fetches config.json — required for correct architecture init),
  (3) binary writes use `:raw` mode (UTF-8 global pragma was corrupting; 5GB→7.5GB symptom),
  (4) dry_run: separate missing/have sizes, dir_size() for whole UUID dirs
- UUID alias symlink: 2fd93aa6→7fe3f986 for stale DB reference (IP Adapter SD1.5 Image Encoder)
- 35GB corrupted/duplicate files deleted; 70GB→252GB free on /mnt/ext-xfs-data
- Design docs: MODELS-PATH-ADAPTERS.md (storage adapter plugin system, 4-step impl order),
  TERMINAL-ZENKA-ARCHITECTURE.md (UI adapter system, curses/web/gtk3/sdl, abstract action protocol),
  TASK-invoke-adapter-step1.md (concrete first task: extract scripts → modules.storage.adapter.invoke.*)
- CONVENTIONS.yaml: colon_keywords section added (:flag: not --flag in p7 contexts)
- philosophy: ETERNAL-TEMPLATE-KITTEN.md (deduplication tree crystallizes truth, kitten as template process)
- Commits: 98743c227 through 30bbd31b4 + fe3d3a295

#,,,,,,.,,,,,,,..,,,,,.,.,,,.,..,,,.,,.,,,,..,..,,...,...,,..,.,.,,..,.,.,,.,,
#5OXXM5KOXKLXF6DERMYNQAFF3G6X6OWWQVJGJHI4TJXB6AQCYJXN5WWHLOEQ7YNUODKUTO4XBFWJI
#\\\|M7PGEUVVWK2VXQJY52KFSDRINSG6MGDGCFDCMFBCUPQRWNYZYSA \ / AMOS7 \ YOURUM ::
#\[7]MGKRVRTCDQTR4WCWXPURMLLUS267RZMQPDWH7JMYV5J33UTNMGBA 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::

## signature "no separator endline" bug fix — verified working (Apr 2026)

### Bug description
When generating P7 module signatures, the code incorrectly called `harmonize_payload_line_feed`
when `endline_modification_state == 7` AND `last_line_incomplete` was set. This caused the
signature footer to be improperly formatted, resulting in:
- The footer being glued to the last line of code without a separator
- Example: `return sprintf(...);#,,.,,...` appearing on one line
- Pre-commit rejects this as "no separator endline" error

### Root cause
The signature system tracks whether a file ends with incomplete payload (no trailing newline)
and adjusts endline_modification_state accordingly. However, when both conditions were true:
1. endline_modification_state == 7 (indicating incomplete payload handling needed)
2. last_line_incomplete was set (file lacks trailing newline)

The code would call harmonize_payload_line_feed, which was unnecessary and caused the formatting issue.

### Fix
Skip calling harmonize_payload_line_feed when both conditions are met:
- endline_modification_state == 7
- last_line_incomplete is set

### Verification
- Fix tested and verified working
- Signatures now properly formatted with correct separator endline
- Pre-commit validation passes

#,,..,...,,,,,...,.,.,,..,...,,.,,..,,...,,,.,..,,...,...,..,,...,...,,,.,.,.,
#4DUTGZVD3U4XJD5PKMACQAGT3TCKEMA7CKKWOBF3COJQ5YKNE4USSHTDLVRVUCJXMHE62ZDDP3C76
#\\\|LHQ65RHAFQOD3HOXQCQWUMUHGW6PEDEZWUX6PRSCU2NEVURHTFE \ / AMOS7 \ YOURUM ::
#\[7]CW4TYRLSUIHJ4Z4HLE555P4T5A37CLJXIYAAK7NNVZCIWE4DNYDI 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
