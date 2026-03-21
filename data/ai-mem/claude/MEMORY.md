# Protocol-7 Development Memory
## Topic Files (details live here)
- `topic-migration.md` — Windows 11 host instability, KVM/Debian migration priority, avoid /tmp/
- `topic-self-contained-zenka.md` — self-contained zenka vision: __DATA__ registry, file.* abstraction,
  zenka serialization/dump, coderef P7REF transfer, STDIO transport, roaming zenki, empty bootstrap
- `topic-tls-acme.md` — SNI/SSL internals, ACME/letsencr details, cert discovery
- `topic-patterns.md` — event handler, fork-child, standalone zenka, pipe-open, inference server
- `topic-completed.md` — session summaries with details
- `topic-harmonic-mathematics.md` — generator 076923, quadratic residues, cube geometry,
  spiral topology, 4-crossing consent protocol, CCW matrix routing, heartbeat encoding
- `topic-vterm.md` — vterm module system: cell format, consensus algorithm, review findings
- `topic-self-improving-system.md` — LLM coordination as foundation for self-improving P7 network;
  user as coding zenka; tasks decomposed for autonomous execution between sessions
- `topic-distributed-consensus.md` — channels zenka, multi-model group chat, consensus groups,
  distributed P7 nodes with ik_llama.cpp on remote servers

## File Creation Notes (CRITICAL)
- **Never add** the single-line `#,,.,,,...` stub at end of new files
- That line is NOT a valid signature — it blocks the signing system
- Leave new files clean; `bin/Protocol-7 sourcecode update-signatures` adds the real 4-line footer
- Real footer: checksum line, hash line, two AMOS7/YOURUM lines, separator

## System Status
- **HTTPS (httpsd)**: production cert on pri.v7.ax ✅ full chain served (leaf + R12 via .pem)
- **Models memory system**: completed ✅ collision-free AMOS checksums, `[:memory:CHECKSUM]` expansion
- **Models-coding integration**: completed ✅ `models.chat` routes local models through coding zenka
- **Data zenka + SHM mounting**: built by Kimi (Feb 21-25) ✅ — 97 modules, holographic topology
- **Harmonic mathematics session** (Feb 27 2026): deep exploration → `topic-harmonic-mathematics.md`
- **v7 stdout SHM log** (Feb 27 2026): completed ✅ — details in `topic-completed.md`
- **fork-child cleanup + sig_chld pid filter** (Mar 2 2026): completed ✅ — commit `1ffe1d2fa`
- **kimi-web WebSocket client zenka** (Mar 2 2026): completed ✅ — commit `68af03d0a`
- **route-send migration + binmode fix** (Mar 2 2026): completed ✅ — commit `0c1f202ba`
- **standalone zenka log_cmd race fix** (Mar 4 2026): completed ✅ — commit `8f81bfdb1`
- **work zenka cleanup** (Mar 4 2026): completed ✅ — commit `8f81bfdb1`
- **non-blocking socket read fix** (Mar 7 2026): completed ✅ — commit `0c590de22`
- **models registry consolidation** (Mar 8 2026): completed ✅ — see `topic-completed.md`
- **coding zenka event loop + switch-model** (Mar 8 2026): completed ✅ — see `topic-completed.md`
- **deferred compilation stub mechanism** (Mar 15 2026): partial ✅ — stubs install for non-whitelisted
  runtime subs; lifecycle hooks excluded (absence = skip by convention); event loop readiness guard
  fixed (`$data{'watcher'}{'io'}{'transfer'}` check); `base.handler.deferred_compile` uses
  `base.load_runtime_modules` to bypass whitelist; level-1 log visibility for any stray triggers;
  design doc at `data/md/documentation/deferred-compilation-design.md` for deeper namespace/phase work
  and `topic-patterns.md` (inference server status pattern)
- **zulum→decoder entropy wiring** (Mar 10 2026): completed ✅ — route-send callback,
  level-5-B32 buffer, is_true stream state; see `zulum-decoder-routing-reference.md`
- **harmonic transit vision architecture** (Mar 11 2026): documented ✅ —
  DTM 6×7×13 CCW shift register, 15-bit `#:::::` footer encoding, binary sunburst
  zoom promotion (0110/1001), multi-speed lanes, lens effect on distance, PYTAURAZA;
  see `data/md/documentation/harmonic-transit-vision-architecture.md`
- **signature oscillation Variant A** (Mar 16 2026): resolved ✅ — state=7/6 encoding fix,
  remove-N restore semantics, empty file state=6; commit `2bf1b3d46`; 109 files resigned.
  Variant B (double-footer on never-signed non-empty files) still open — fixtures at
  `data/asc/test-fixtures/signature-oscillation-2026-03-15/`
- **config double-load bug**: pre-existing duplicate config key warnings on startup/reload — needs "already loaded" guard in config parser; see `bug-config-double-load.md`
- **task zenka** (Mar 20 2026): completed ✅ — YAML persistence via format.yaml, ntime.b32 timestamps
- **models task dispatch** (Mar 20 2026): completed ✅ — jobqueue integration with dispatch_slot
  dependency type for sequential execution; event-driven notify → claim → enqueue → execute pipeline
- **kimi task-poll async fix** (Mar 20 2026): completed ✅ — rewrote broken sync assumption, param→call_args fix in ws_message
- **repo var/ cleanup needed**: `var/httpd/` tracked from Nov 2025 AI error — should be removed, template relocated to `data/html/templates/`
- **dep-graph lifecycle hook gap**: `*.init_code`, `*.pre_init`, `*.post_init`, `*.end_code` must always be whitelisted for loaded namespaces — see `feedback-devmod-whitelist.md`
- **MCP server for Claude Code** (Mar 20 2026): completed ✅ — `bin/mcp-server-p7` stdio MCP server,
  config at `data/json/claude/.mcp.json` symlinked from project root `.mcp.json`;
  tools: p7_command, p7_task_create, p7_task_show, p7_task_queue, p7_task_complete, p7_task_continue;
  unbuffered sysread I/O, unix-$USER auth, `close\n` disconnect; commits `9901a539d`, `3a8be6700`
- **kimi zenka upgrades** (Mar 21-22 2026): completed ✅ — see `topic-completed.md`
  - JSON parse fix: `decode_json` → `from_json` for UTF-8 websocket text frames
  - approval replay dedup: `responded` set persisted to zenka_dir across restarts
  - session management: `new-session`, `session-info` commands; devmod + format.json modules
  - websocket frame: eval wrapper in handler.read, 16MB max_payload_size
- **httpsd crash capture fixes** (Mar 21-22 2026): completed ✅
  - `file.slurp` returns scalar ref — was stringifying to `SCALAR(0x...)` in crash log
  - on-demand buffer init: moved from init_code to collect module, config flag for log forwarding
  - reload guard: skip collect when `system.zenka.initialized` (not a real crash)
  - cert path: `current.pem` → `default.pem`, removed premature warning from pre_init
  - task file: `data/yaml/coding-tasks/httpsd-cert-architecture-cleanup.yaml`
- **httpsd SSL handshake hang** (Mar 22 2026): identified, not yet fixed — AWS bots send partial
  ClientHello then go silent, blocking SSL accept indefinitely; v7 heartbeat timeout kills+restarts;
  crash capture now shows `ssl-handshake-start` event with client IP; needs non-blocking accept
- **kimi-web session data loss** (Mar 21 2026): hundreds of real sessions lost from `~/.kimi/sessions/`,
  likely caused by kimi zenka API interactions rewriting `kimi.json` (birth=Mar 21 03:22);
  35 sessions remain on disk with content intact; full backup at
  `/data/backup/kimi/kimi-sessions.full_dir.0000.tar.xz` (105M)
- **httpd favicon.ico binary read bug**: `file.slurp` applies UTF-8 decode to binary .ico files,
  `\xAB` fails → HTTP 500; needs `:raw` binmode for binary content types

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

#,,,.,,,.,..,,,.,,,,,,...,..,,,.,,,,.,...,,,.,..,,...,...,,.,,.,,,,,.,,,.,,..,
#C3X3DAENEI6L7CHFGO63QKCM7RSIZSVQCJL6XZY5NZJGOAXQ5YL7MHYYOU2KOCALRD4UJ5YVJU4IU
#\\\|TOLEDR3PS7ZAT4CNQBPBQ5ROWX7VN5YPG2YGWQJG4CPIS7M5KHQ \ / AMOS7 \ YOURUM ::
#\[7]3FXNSD37Z6G33NUYGVVGZA53KE2JZ3LTGK44DDIHD234LTLNGGCQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
