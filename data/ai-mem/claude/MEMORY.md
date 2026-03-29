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
- `topic-task-coordination.md` — task zenka as coordinator between kimi/coding/models,
  current state, dispatch flow, architectural questions, reference to scattered design docs
- `feedback-kimi-code-review.md` — common issues in kimi-generated P7 code: SUPER:: resolution,
  namespace swaps, SSL internals, missing log levels, style, fake signatures
- `topic-context-and-forensics.md` — context.* module namespace design, forensics zenka vision
  (nightly security audits via NIST/security models), model capabilities mapping
- `topic-checksum-addressing.md` — AMOS checksums as universal routing primitive,
  everything-is-a-group-of-1, expectability principle, delegation via checksum endpoints
- `feedback-ptd-syntax-check.md` — use `ptd -c` not `perl -c` for P7 module syntax checks
- `feedback-kimi-dispatch-pattern.md` — dispatching tasks to kimi via bin/kimi-task is highly
  token-efficient; write detailed task files, review for known issues
- `topic-tool-shm-architecture.md` — LLM tool calling (8 tools), dispatch loop, SHM+mmap file editing vision
- `topic-coding-zenka-templates.md` — 25+ context templates, 13 tools, review cycles, meta-reflection cascade
- `feedback-p7c-multiline.md` — p7c cannot handle multiline task descriptions; use single-line or templates
- `feedback-coding-zenka-edits.md` — local LLM often describes edits instead of applying them; verify results

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
- Inline sub extraction: pager.* namespace in progress (19 subs across 7 modules)

### Active / Partial
- **pager inline extraction**: task-KWPCTLA running, 19 subs in 7 pager.* modules
- **deferred compilation stubs** (Mar 15): partial ✅ — deeper namespace/phase work pending;
  design doc at `data/md/documentation/deferred-compilation-design.md`
- **task coordination architecture**: see `topic-task-coordination.md` for full state + roadmap
- **multi-model consensus**: llm.service.consensus_vote modules extracted but untested;
  needs refinement for 5-of-7 algorithm group and real model providers

### Open Bugs / Cleanup
- **config double-load bug**: duplicate config key warnings — see `bug-config-double-load.md`
- **signature oscillation Variant B**: double-footer on never-signed non-empty files
- **repo var/ cleanup**: `var/httpd/` tracked from Nov 2025 AI error
- **dep-graph lifecycle hook gap**: see `feedback-devmod-whitelist.md`
- **kimi-web session data loss** (Mar 21): backup at `/data/backup/kimi/kimi-sessions.full_dir.0000.tar.xz`

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

#,,,,,,,,,.,.,,.,,.,.,,,.,,,.,.,.,,,.,.,.,,,,,..,,...,...,,,.,,..,,..,.,.,,..,
#N7P6THBJ5J24JU2EQ6DTCF4RJNWF52KG7DJ5HL54K6NHJG2B3CSG3WNNYGLBFF32TB43ETT6A3QO2
#\\\|NG3VZKDTIF7ECUBJ7XP7FYJRSCWI6LB2JI2PBWCCFF7QUGTTRUN \ / AMOS7 \ YOURUM ::
#\[7]NHWAY6EECEMUMJLY76UDLDLLQHGRC4X2T4HHOQUYJ2HKAYJ7VYAA 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
