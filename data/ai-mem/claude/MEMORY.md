# Protocol-7 Development Memory
## Topic Files (details live here)
- `topic-tls-acme.md` — SNI/SSL internals, ACME/letsencr details, cert discovery
- `topic-patterns.md` — event handler pattern, variable watcher, SSL server socket behavior
- `topic-completed.md` — session summaries (cert discovery, models memory, data zenka)
- `topic-harmonic-mathematics.md` — generator 076923, quadratic residues, cube geometry,
  spiral topology, 4-crossing consent protocol, CCW matrix routing, heartbeat encoding

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
- **Harmonic mathematics session** (Feb 27 2026): deep exploration of mod-13 structure →
- **v7 stdout SHM log** (Feb 27 2026): completed ✅ — `/dev/shm/.7/STDOUT/<socket>`, full early
  message reconstruction, banner re-emit, colored output matching console exactly

## v7 Stdout SHM Log Architecture
- **Log path**: `/dev/shm/.7/STDOUT/<socket>` symlinked from `/var/run/.7/STDOUT/<socket>`
- **Config**: `v7.cfg.zenka_stdout_redir = yes`, `v7.path.zenka_stdout.parent_dir`
- **Early flush source**: `$data{'buffer'}{'zenka'}{'data'}->@*` — base.buffer ring array
  - NOT `$data{'system'}{'start'}{'zenka-buffer'}` (only has ~4 pre-init messages)
  - `base.buffer.add_line` is loaded as a module file during `[load_modules]`, so most
    early messages go to base.buffer directly, not zenka-buffer
- **Skip indices 1 and 2** in base.buffer (startup + version markers; index 0 is `.\7`)
- **Colors**: apply `base.log.format_entry` to each `TIMESTAMP LEVEL MSG` line
- **Banner**: `p7_banner` now owns the opening `\..../` line (moved inside the sub);
  call `<[base.banner]>->( '', $log_fh )` to re-emit full banner to log
- **After flush**: `base.log` writes directly to shm via `v7.stdout_log.write` (already colored)
- **p7_log_hook**: completely unchanged (original destructive drain + delete)
- **p7-log deferred path**: untouched — reads base.buffer when network logging initializes
- **Pending**: v7 end_code callback to run shm reinit/teardown (terminate listening `tail -f` processes)

## Planned: SHM Log Viewer Client (next step after stdout log)
- Console/hybrid zenka: tty UI + cube network access (control commands)
- Search/filter mode reusing nshell history buffer code → extract into `log-viewer.*` namespace
- Key bindings: Ctrl+L → clear-cons, Ctrl+C → SIGINT, Ctrl+R → v7.reload (SIGHUP), extensible
- Shared rendering pipeline with full disk log viewer (p7-log source vs shm live-tail source)
- `log-viewer.*` modules provide core; shm client and disk viewer load from same namespace
  committed to `data/md/philosophy/HARMONIC-CUBE-ROUTING-MATHEMATICS.md`; tools
  `bin/dev/iter-rank` and `bin/dev/prng-truth` created; `bin/harmony` false-positive fixed

## Coding Zenka — Models Integration (Kimi, Feb 2026)
Removed all hardcoded model paths/names; full dynamic discovery from models zenka.

- **Model discovery**: on init, coding fetches registry via `cube.models.discover` →
  stored in `<coding.model_metadata>` (persisted to `state/model_metadata.yaml`)
- **Dependency-based spawning** (`coding.handler.spawn_with_deps`): servers wait on chain:
  - `dep.model_gpu` / `dep.model_cpu` — model discovered and available
  - `dep.memory_gpu` / `dep.memory_system` — memory polled before spawn
  - GPU server requires both memory deps; CPU server requires system memory only
- **`coding.switch-model <XXXXXXX:XXXXXXX> [backend=gpu|cpu|both]`**: switch active model
  by AMOS checksum; fetches path via `cube.models.get_path_by_amos`, restarts servers
- **`coding.ask-reply`**: synchronous deferred-reply command — submit prompt, wait, return result
  - Prompt base32r-encoded for multiline safety through single-line IPC
- **`models.backend.coding.invoke`**: IPC bridge models → coding
  - Converts `messages[]` → prompt via `models.chat.messages_to_prompt`, sends to `coding.ask-reply`
  - Enables `models.chat` command to work with local models transparently

## Key Technical Insights

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
- Use `<[base.protocol-7.command.send.local]>->(\%params)`
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

### SSH Zenka Race Condition Fix (Kimi, Feb 2025)
- Multiple `register_*_deps` calls race during startup before system user exists
- Fix: check if deps already registered before attempting user creation
  ```perl
  return TRUE if -d $mod_dir and scalar( glob("$mod_dir/*") ) > 2;
  ```
- Applied to: `base.register_pm_deps`, `base.register_bin_deps`, `base.register_src_deps`

### Data Zenka / SHM Architecture (Kimi, Feb 2025)
- 97 modules: `data.get.*` (hash resolution), `data.mount.shm.*` (crypto SHM),
  `data.channel.shm.*` (ring buffer IPC), `data.topology.interference.map.*` (holographic)
- SHM naming: `/dev/shm/p7:M:<pub-key-B32>:<data.sub.path>`
- Cryptographic access control: Ed25519 signed permissions per path
- Docs: `data/md/data-zenka/` and `data/md/data-zenka/AGENTS.md`

### nshell UTF-8 Echo Fix (Feb 2026)
- **File**: `data/lib-path/pm/AMOS7/TERM.pm` — `editor_process_key`
- **Bug**: `cursor_pos++` on insertion split multi-byte UTF-8 sequences; `render.viewport`
  then printed byte 0xCF alone + byte 0x84 alone → `ÏÂ` instead of `τ`
- **Fix**: `cursor_pos += length($key)` for insertion; backspace/left-arrow scan back over
  continuation bytes (0x80-0xBF) to find char start; right-arrow/delete/Ctrl-D determine
  forward byte length from leading byte
- All rendering goes through `render.viewport` (full `\r` redraw), so the `result->{output}`
  strings in editor_process_key are never printed by nshell — only `cursor_pos` accuracy matters

### nshell Viewport / Terminal Rendering (Feb 2026)
- New modules: `nshell.render.viewport` (unified renderer), `nshell.handler.term_resize` (SIGWINCH)
- **Pending-wrap trap**: printing exactly `term_cols` chars puts cursor in pending-wrap state;
  `\e[K]` then wraps to next line and erases the rightmost character. Fix: use `term_cols - 1`
  as available width so total render is always ≤ `term_cols - 1`
- **SIGWINCH registration**: `<[event.add_signal]>->( { 'signal' => qw| WINCH |, 'handler' => qw| handler.name | } )`
- **Term restore**: use `TCSANOW` not `TCSAFLUSH` during signal exit (TCSAFLUSH blocks on i/o drain)
- **Line clearing**: use `\r\e[2K` not `\r . (" " x N)` — space-fill wraps on long lines
- **Resize remnants**: clear line below too: `print "\r\e[2K\e[1B\r\e[2K\e[1A"`
- `vc-changed-files -exc-len` finds modules with lines over 78 cols (wraps comment lines only);
  note: originally had UTF-8 char-width counting issue, fixed in the tool itself
- Docs: `data/md/documentation/NSHELL_REFACTORING_SUMMARY.md` (updated Feb 2026 addendum)

### `protocol-7.network.parent_route` (Feb 2026)
- Arraref tracking network path back to root, nearest-first: `['parent', 'cube']` in children,
  `['cube']` in directly-connected zenki
- Initialized empty in `net.init_code`, assigned directly in `base.net.connect` and
  `v7.callback.connect_to_cube`, prepended with `unshift` in five fork-child modules
- Fork-child modules use `qw| parent |` (not `<system.zenka.name>`) — matches the literal
  session alias; using zenka name would give `weather.weather.cmd` redundancy from cube
- Direct assignment (not push) for connection-side modules — idempotent on reconnect
- Reference: `data/md/documentation/NETWORK-ADDRESSING-AND-TOPOLOGY.md`

### `log.base_log_complete` core sub (Feb 2026)
- Gates full log chain readiness: `base.log` + `base.log.format_entry` + `v7.stdout_log.write`
  all present before any log output path attempts to use them
- Defined in `bin/Protocol-7` as `sub p7__log__base_log_complete` — naming convention:
  `p7__` prefix stripped, `__` → `.` for dots → `$code{'log.base_log_complete'}`
- State-cached with `state $are_present` — checks `exists` not `defined`, returns TRUE once set
- Call sites use `$code{'log.base_log_complete'}->()` not `defined $code{'base.log'}`
  (except line 3343 purge-detection path which correctly keeps `exists $code{'base.log'}`)

### Variable Watcher Backup/Restore (CRITICAL — see topic-patterns.md)
- Stop → back up → replace → restore with `->again()` (never `->now()`)

### Event Handler Pattern (CRITICAL — see topic-patterns.md)
- Handlers receive Event object as first param, not data directly
- Extract: `my $event = shift->w; my $server = $event->data;`

#,,..,...,,,.,,..,,.,,..,,,..,,,.,.,.,.,.,,..,..,,...,...,.,,,,..,.,,,.,.,,,,,
#OEWGQ7GGZV567KDKJO4DKNTMX4SEL5BJBAQXKGEVT4WRKIM4L35IODGFKCUKU7QM267OOTSNLFZFC
#\\\|YJQ2UL3BQCVMPPY6EKESXXBI6BWYHV45Q37CEOPXQ3PEZFG7RIJ \ / AMOS7 \ YOURUM ::
#\[7]7EJHG3W6MOHCZHXC7GZIXS3HXFMOAA672NCKLNJSPXYVWZJLBSBQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
