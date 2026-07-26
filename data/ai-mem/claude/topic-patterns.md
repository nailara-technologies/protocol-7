# Protocol-7 Patterns

## Standalone Zenka Pattern
- sourcecode, keys, work have no cube connection, no network logging
- In start file, AFTER `[load_config_file:'shared-params']` and BEFORE `[load_modules]`:
  `buffer.zenka.log_cmd = ''    ## standalone zenka : no network logging`
- `shared-params` → `logging-configuration` sets `buffer.zenka.log_cmd = p7-log.append`
  so this override must come AFTER shared-params loads
- `add_line` guard: `defined AND length` — empty string is sufficient to block send-buffer init
- `base.log.send-buffer.add-queue` foreach block (lines 28-45): recursive re-queue of existing
  buffer content — noted as wrong, still present, not yet fixed

## fork-child Pattern (canonical form, Mar 2026)
- **Child side** (in fork_conv_child, child branch):
  - `IO::AIO::reinit()` first
  - `<[event.add_signal]>->( { 'signal' => 'CHLD', 'handler' => 'dev.null' } );`
  - `<callback.session.closing_last.params>->[1] = 1;` — silence shutdown
  - `$data{'session'}{$session_id}{'shutdown'} = TRUE;` — close inherited cube session
  - `<buffer.zenka.log_cmd> = qw| p7-log.append |;`
  - `delete <access.cmd.usr.cube>; delete <access.cmd.regex.usr.cube>;`
  - `unshift <protocol-7.network.parent_route>->@*, qw| parent |;`
- **Parent side**: delete parent access entries; mark both sessions authenticated
- **Parent init_code**: register SIGCHLD + child PID filter:
  ```perl
  <[event.add_signal]>->( { 'signal' => 'CHLD', 'handler' => 'base.handler.sig_chld.shutdown' } );
  <sig.chld.shutdown.pid>->{<zenka.child.pid>} = 1;
  ```
- **Start config**: `access.cmd.usr.child = cube.v7.notify_online cube.p7-log.append`
  - keep `cube.` prefix — `has_access` checks command AFTER `parent.` hop is consumed
- **sig_chld filter**: `<sig.chld.shutdown.pid>` triggers exit; `<sig.chld.ignore.pid>` silent skip
- **Log storm trap**: child `logfile = 2` → feedback loop; keep at default (1)
- **Reference**: `data/yaml/coding-tasks/fork-child-pattern-remaining.yaml`

## protocol-7.network.parent_route
- Arrayref tracking network path, nearest-first: `['parent','cube']` in children, `['cube']` in root
- Initialized empty in `net.init_code`; prepended with `unshift` in fork-child modules
- Use `qw| parent |` (not zenka name) — matches literal session alias
- Reference: `data/md/documentation/NETWORK-ADDRESSING-AND-TOPOLOGY.md`

## Pipe-Open binmode Fix
- `bin/Protocol-7` has `use open qw| :encoding(UTF-8) |` → ALL `open()` inherit `:utf8` layer
- Two-arg pipe-open inherits `:utf8`; `sysread()` fails on `:utf8` handles
- Fix: `binmode($out_fh, ':raw') if defined $out_fh;` immediately after pipe-open
- `IPC::Open3::open3()` NOT affected (bypasses PerlIO layer)

## Variable Watcher Backup/Restore
- Stop → back up → replace → restore with `->again()` (never `->now()`)

## Event Handler Pattern
- Handlers receive Event object as first param, not data directly
- Extract: `my $event = shift->w; my $server = $event->data;`

## Inference Server Status Pattern (coding zenka, Mar 2026)
- `<coding.inference_servers>->{$backend}->{'status'}`: 'starting' / 'ready' / 'crashed'
- Set by `coding.handler.monitor_inference_startup` via stdout/stderr IO watchers
- Read non-blocking by dependency callbacks and spawn_smart health checks
- `$server->{'crash_logged'}` flag prevents double-processing (stdout+stderr both fire EOF)
- `$server->{'ready_logged'}` flag prevents duplicate readiness log
- IPC::Open3 pipes are blocking by default — must `fcntl O_NONBLOCK` after `open3()`
- After SIGKILL to GPU server, wait 0.3s before nvidia-smi (driver VRAM release delay)
- `spawn_smart` with `force=1` kills old server BEFORE memory check so check is accurate
- Always pass `model_path`/`mmproj_path` through to `spawn_smart` — it uses provided path
  directly, skipping metadata lookup that can resolve the wrong model

#,,.,,,.,,.,,,,,,,,.,,,..,,.,,,.,,,..,.,,,,.,,..,,...,...,,.,,...,.,.,.,.,.,.,
#6JZBMMXERFD3DYLDBKZTIQRS6S2HS7U47EAABVWTV5CVG5LPVYLRTFMYEV4R754Z4WZQOTPPYELAI
#\\\|RD4EWNY22DFODENR3C75EFRCYNHO5YEYRGSN5MAHY4M4DFFXPOT \ / AMOS7 \ YOURUM ::
#\[7]Q4D6FQ4NFTYVJMPBFBTD4VVE2ZTJNEEALRVLKU2ASGJU47NXVSCI 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
