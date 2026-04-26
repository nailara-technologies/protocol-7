# Completed Work Sessions

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

#,,,,,,,.,,..,,,.,...,,,,,,,.,.,,,,.,,,,,,.,,,..,,...,...,,,.,,.,,...,.,,,,,,,
#4ZFEDYPGDNEL7LF4OGGEJLAWVGINSVG73VLNZP34ZHV5SI47ZDA5LZODSMDNYQOEHWPQ2FEPMAPBM
#\\\|VBYSJEESPEGPOCTYIMYAAIDHHKYBZ4NYAWHAPMSN7V42EDZ5UZD \ / AMOS7 \ YOURUM ::
#\[7]KUWZXYPQCIWUAWJEAGHAQY7L5DSONO7T5WTCVEUKDO4VHLPY4ACA 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
