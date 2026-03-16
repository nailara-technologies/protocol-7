# Completed Work Sessions

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

#,,,.,,,.,,,.,,..,,,,,,.,,,,,,,..,...,,.,,...,..,,...,...,,..,.,.,...,.,.,,.,,
#L2HCZ77IEGZMZXCBQDR6P7KPQWVFVAR22LL2ZIXFY3QD7KNNALMVU33LRZGPRQBMSZIJKRFKNGKPO
#\\\|H3YROGNEKG3QTNOJ5C4ON7MBLUYBLNQFHYPSIGGU2KS4PRMHAT2 \ / AMOS7 \ YOURUM ::
#\[7]NNTUK5ILUBTDB4MVKZBRMHTDKYMNZZUJOKDGVA6ZSGE6FSLABMBI 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
