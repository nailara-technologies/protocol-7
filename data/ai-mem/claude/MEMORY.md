# Protocol-7 Development Memory
## Topic Files (details live here)
- `topic-tls-acme.md` — SNI/SSL internals, ACME/letsencr details, cert discovery
- `topic-patterns.md` — event handler pattern, variable watcher, SSL server socket behavior
- `topic-completed.md` — session summaries (cert discovery, models memory, data zenka, SHM log)
- `topic-harmonic-mathematics.md` — generator 076923, quadratic residues, cube geometry,
  spiral topology, 4-crossing consent protocol, CCW matrix routing, heartbeat encoding
- `topic-vterm.md` — vterm module system: cell format, consensus algorithm, review findings

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
- **v7 stdout SHM log** (Feb 27 2026): completed ✅ — `/dev/shm/.7/STDOUT/<socket>`, early message
  reconstruction, banner re-emit, colored output; details in `topic-completed.md`
- **fork-child cleanup + sig_chld pid filter** (Mar 2 2026): completed ✅ — commit `1ffe1d2fa`
  image2html, pdf.html, vision-batch pattern unified; `base.handler.sig_chld.shutdown` upgraded
- **kimi-web WebSocket client zenka** (Mar 2 2026): completed ✅ commit `68af03d0a` — 14 new
  modules: `websocket.*` + `kimi.*`; `models.chat` routes kimi/kimi-code through kimi_web backend;
  deferred `get_session_id` — online only after WS+initialize handshake; backoff 2→4→…→60s
- **route-send migration + binmode fix** (Mar 2 2026): completed ✅ — commit `0c1f202ba`
  `cube.X.Y` → `protocol-7.route-send` + relative names across all zenki; pipe-open `:utf8` fix
- **standalone zenka log_cmd race fix** (Mar 4 2026): completed ✅ — commit `8f81bfdb1`
  Ctrl+U in AMOS7::TERM called `Event::loop(0.07)` which fired idle send-buffer callback installed
  before `pre_init` could delete `log_cmd` — race between early log message and pre_init ordering.
  Fix: `buffer.zenka.log_cmd = ''` in start file immediately after `[load_config_file:'shared-params']`,
  before `[load_modules]` — deterministic, no module code ever sees non-empty log_cmd.
  Applied to: sourcecode/start, keys/start, work/start.
- **work zenka cleanup** (Mar 4 2026): completed ✅ — commit `8f81bfdb1`
  Removed network modules (auth net protocol io.unix), access.cmd.usr.cube block; 8 obsolete
  work.cmd.* deleted (superseded by work.console.*); work.cmd.regenerate-indexes renamed to
  work.console.regenerate-indexes; work.init_code now splits space-separated config string to
  arrayref for work.git.remotes; explicit remotes set: `hub ext-bundle`

## Key Technical Insights

### Standalone Zenka Pattern (CRITICAL)
- sourcecode, keys, work are standalone (no cube connection, no network logging)
- In start file, after `[load_config_file:'shared-params']` and BEFORE `[load_modules]`:
  `buffer.zenka.log_cmd = ''    ## standalone zenka : no network logging`
- `shared-params` → `logging-configuration` sets `buffer.zenka.log_cmd = p7-log.append`
  so this override must come AFTER shared-params loads
- `add_line` guard: `defined AND length` — empty string is sufficient to block send-buffer init
- `base.log.send-buffer.idle-callback-set` guards: checks `log_cmd` defined, send-buffer exists
- `base.log.send-buffer.add-queue` foreach block (lines 28-45): user noted "that entire foreach
  block is wrong" — recursive re-queue of existing buffer content; **still present, not yet fixed**

### Config String → Arrayref Pattern
- P7 start file values are scalars — `work.git.remotes = hub ext-bundle` sets a string, not arrayref
- Code checking `ref(<key>) eq 'ARRAY'` fails on strings from config files
- Fix in init_code: `if defined and not ref → split m|\s+|, $val into arrayref`
- Applied to `work.git.remotes` in `work.init_code`

### fork-child Pattern (canonical form, Mar 2026)
- **Child side** (in fork_conv_child, child branch):
  - `IO::AIO::reinit()` first
  - `<[event.add_signal]>->( { 'signal' => 'CHLD', 'handler' => 'dev.null' } );` — null inherited handler
  - `<callback.session.closing_last.params>->[1] = 1;` — silence shutdown
  - `$data{'session'}{$session_id}{'shutdown'} = TRUE;` — close inherited cube session
  - `<buffer.zenka.log_cmd> = qw| p7-log.append |;` — route logs through parent
  - `delete <access.cmd.usr.cube>; delete <access.cmd.regex.usr.cube>;`
  - `unshift <protocol-7.network.parent_route>->@*, qw| parent |;`
- **Parent side** (in fork_conv_child, parent branch):
  - `delete <access.cmd.usr.parent>; delete <access.cmd.regex.usr.parent>;`
  - `$data{'session'}{$id}->{'authenticated'} = qw| yes |;` — child session
  - `$data{'session'}{$session_id}->{'authenticated'} = qw| yes |;` — cube session
- **Parent init_code**: register SIGCHLD + child PID filter:
  ```perl
  <[event.add_signal]>->( { 'signal' => 'CHLD', 'handler' => 'base.handler.sig_chld.shutdown' } );
  <sig.chld.shutdown.pid>->{<zenka.child.pid>} = 1;
  ```
- **Start config**: `access.cmd.usr.child = cube.v7.notify_online cube.p7-log.append`
  - ⚠️ keep `cube.` prefix — `has_access` checks command AFTER `parent.` hop is consumed
  - child sends `parent.cube.v7.notify_online`; parent receives `cube.v7.notify_online`
- **sig_chld.shutdown filter**: `<sig.chld.shutdown.pid>` triggers exit; `<sig.chld.ignore.pid>` silent skip;
  unknown PIDs logged at level 1 but no exit. Uses WNOHANG to avoid blocking on live children.
- **Log storm trap**: child log routing at `zenka_logfile = 2` → every `:network:` routing message
  becomes a p7-log.append call → feedback loop. Keep `zenka_logfile` at default (1) for child zenki.
- **vision-batch**: child does NOT fork further → no SIGCHLD in child → no handler needed (correct)
- **Reference**: `data/yaml/coding-tasks/fork-child-pattern-remaining.yaml`

### protocol-7.route-send
- Wraps `send.local`, auto-prepends `<protocol-7.network.parent_route>`:
  - root zenki (`parent_route=['cube']`) → `cube.X.Y`
  - fork-child children (`parent_route=['parent','cube']`) → `parent.cube.X.Y`
- Use for cube-routed zenka commands (`v7.*`, `X-11.*`, `httpd.*`, `p7-log.*`, etc.)
- Do NOT use for `child.*` commands — these are local socketpair aliases, not cube-routed
- Direct cube protocol commands (`whoami`, etc.) → stay `send.local` with literal `cube.`
- ✅ `<[protocol-7.route-send]>->( { 'command' => 'v7.notify_online', ... } )`

### Pipe-Open binmode Fix
- `bin/Protocol-7` has `use open qw| :encoding(UTF-8) |` → ALL `open()` calls inherit `:utf8` layer
- Two-arg pipe-open `open(my $fh, "cmd 2>&1 |")` inherits `:utf8`; `sysread()` fails on `:utf8` handles
- Fix: `binmode($out_fh, ':raw') if defined $out_fh;` immediately after pipe-open
- `IPC::Open3::open3()` is NOT affected (bypasses PerlIO layer)
- Applied to: `openbox.start_wm`, `auto-hide.startup`, `X-11.post_init`, `coding.inference.spawn-server`

### Event Timers (CRITICAL)
- Repeating timers require BOTH `'interval' => N` AND `'repeat' => TRUE`
  - ❌ `'repeat' => 62` (sets boolean to 62, no interval → "no interval" error)
  - ✅ `'interval' => 62, 'repeat' => TRUE`
- One-shot timers: `'after' => N` with no interval key

### Module Loading (CRITICAL)
- `base.perlmod.autoload` and `base.perlmod.load`: one module per call, NOT a list
  - ❌ `<[base.perlmod.autoload]>->(qw| IPC::Open3 YAML::XS |)`
  - ✅ `map { <[base.perlmod.autoload]>->($_) } qw| IPC::Open3 YAML::XS |`

### Module Invocation Syntax (CRITICAL)
- ALWAYS `<[module.name]>->($args)` — closing `]>` BEFORE `->`
  - ❌ `<[module.name]->($args)` (missing `]>`)
  - ✅ `<[module.name]>->($args)`

### Inter-Process Communication
- `protocol-7.route-send` for zenka commands; `send.local` for direct/cube-protocol calls
- Use `<[base.protocol-7.command.send.local]>->(\%params)`:
  ```perl
  my $cmd_count = <[base.protocol-7.command.send.local]>->({
      'command'   => 'target.name',   ## no .cmd. — that's disk-only, stripped at routing
      'call_args' => { 'args' => $data },
      'reply'     => { 'handler' => 'caller.handler.reply',
                       'params'  => { 'context' => $value } }
  });
  ```
- Returns: number of commands sent (0 if target zenka offline)
- Base32: `encode_b32r()` / `decode_b32r()` from `Crypt::Misc`
- ❌ Don't use: `base.zenki.is_online`, `base.zenki.send_command` (don't exist)

### Logging and Log Levels
- `base.logs` handles sprintf format strings; `base.log` has default log_level [1]
- Log levels: 0=error, 1=default, 2=info, 3=debug
- Format: `:. :` at start/end; permission changes: `[ 0755 --> 0775 ]`
- Path display: use `center_ellipse_string` for readable relative paths

### V7-Managed Zenka Detection
- Use `<[base.zenka.is_v7_started]>` — TRUE for v7-started, cube, or v7 types
- Used for permission logic: `skip_chmod = ! <[base.zenka.is_v7_started]>`

### Code Style Conventions
- Lowercase comments: `## read config from file` (not `## Read Config`)
- Annotations: `[ word ]` not `( word )`
- No variable interpolation in logs — use sprintf format codes
- Relative paths: `center_ellipse_string`

### File Ownership and Permissions
- Pattern: owner from parent dir, group from zenka user (httpd, httpsd, etc.)
- Files: 0664, directories: 0775 (group writable)
- `getpwnam` returns `(name, passwd, uid, gid, ...)` — uid at index 2, not 0
- Namespace swapping: `base.file.*` → `file.*` via swap_subs in base.file.init_code

### AMOS Checksums
- 7 characters, pattern `^[A-Z0-9]{7}$` (not 9)
- Use `AMOS7::TEMPLATE` with CODE ref collision detector for unique generation

### Protocol::WebSocket::Frame Constructor (CRITICAL)
- `Frame->new($text, type => ..., masked => ...)` passes ODD elements → silent data loss
- ✅ Always use named arg: `Frame->new( buffer => $text, type => 'text', masked => 1 )`

### Deferred Zenka Online (`base.async.get_session_id`)
- Remove `[get_session_id]` from start file; call `<[base.async.get_session_id]>` from within
  the event loop once the zenka is ready to serve (e.g., after a backend handshake completes)
- Guards: checks `cube_sid` already set (idempotent); use a `<zenka.session.acquired>` flag
  to avoid duplicate calls on reconnects
- Pattern used by: weather, dbus, start-anim, image2html, ticker, kimi, etc.

### Config Variable Path Conflicts (CRITICAL)
- `<a.b.c>` and `<a.b.c.d>` CONFLICT — `a.b.c` is a scalar, `.d` tries to deref it as hash
- ❌ `<kimi.connect.retry_delay>` = 60 AND `<kimi.connect.retry_delay.current>` = 2
- ✅ Use a flat sibling name: `<kimi.connect.retry_cur>` = 2

### Variable Watcher Backup/Restore (CRITICAL — see topic-patterns.md)
- Stop → back up → replace → restore with `->again()` (never `->now()`)

### Event Handler Pattern (CRITICAL — see topic-patterns.md)
- Handlers receive Event object as first param, not data directly
- Extract: `my $event = shift->w; my $server = $event->data;`

### `protocol-7.network.parent_route` (Feb 2026)
- Arrayref tracking network path back to root, nearest-first: `['parent', 'cube']` in children,
  `['cube']` in directly-connected zenki
- Initialized empty in `net.init_code`, assigned directly in `base.net.connect` and
  `v7.callback.connect_to_cube`, prepended with `unshift` in five fork-child modules
- Fork-child modules use `qw| parent |` (not `<system.zenka.name>`) — matches the literal
  session alias; using zenka name would give `weather.weather.cmd` redundancy from cube
- Reference: `data/md/documentation/NETWORK-ADDRESSING-AND-TOPOLOGY.md`

### `log.base_log_complete` core sub (Feb 2026)
- Gates full log chain readiness: `base.log` + `base.log.format_entry` + `v7.stdout_log.write`
  all present before any log output path attempts to use them
- Defined in `bin/Protocol-7` as `sub p7__log__base_log_complete` — naming convention:
  `p7__` prefix stripped, `__` → `.` for dots → `$code{'log.base_log_complete'}`
- State-cached with `state $are_present` — checks `exists` not `defined`, returns TRUE once set
- Call sites use `$code{'log.base_log_complete'}->()` not `defined $code{'base.log'}`

#,,.,,,.,,.,,,...,..,,,..,.,.,,,.,,..,,.,,.,.,..,,...,...,.,.,,,,,.,,,...,...,
#SEVMU7GS33F4KHUQR7LHQG7PA45DCFZETZ5F2ZPC253HYZYAWF3YLPJFC74UDD62BQP42UJPIYVEE
#\\\|UPWDRYOADMZSHCGHG6GL5Y3RSEIK2MDIBXYS5S52ZWNJ35S4KLD \ / AMOS7 \ YOURUM ::
#\[7]UJCRL7WWKSONOP5OUBBARPFDIC4D2SNTNKBERIF3PDDX4XLSQQCY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
