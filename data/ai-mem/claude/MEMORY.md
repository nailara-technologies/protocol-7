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

## Key Technical Insights

### Standalone Zenka / fork-child / Pipe-Open / Inference Server patterns
- See `topic-patterns.md` for full details

### Config String → Arrayref Pattern
- P7 start file values are scalars — `work.git.remotes = hub ext-bundle` sets string, not arrayref
- Fix in init_code: `if defined and not ref → split m|\s+|, $val into arrayref`

### protocol-7.route-send
- Wraps `send.local`, auto-prepends `<protocol-7.network.parent_route>`
- Use for cube-routed commands (`v7.*`, `httpd.*`, `p7-log.*`, etc.)
- Do NOT use for `child.*` commands (local socketpair aliases)
- ✅ `<[protocol-7.route-send]>->( { 'command' => 'v7.notify_online', ... } )`

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

#,,..,..,,,..,,.,,...,...,,,,,,..,..,,...,.,.,..,,...,...,,,,,,.,,,..,,,,,.,,,
#5724G43V6KXTTYUDTWKHT2X4O3IDC5QOT22PZJVO6442DXTF6S3G6KHZ5WM7TWIJDET2BJ4I7HFKS
#\\\|SLJ3Z5TPJWFDM7RZDCZQNFWQVM64P6V7EQFIAPUVDAG7SAD4CD6 \ / AMOS7 \ YOURUM ::
#\[7]TZEIINLRLQKV6MTASS3KFB7APQAQFOGGIIFNIMLHY727YUEHCQDA 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
