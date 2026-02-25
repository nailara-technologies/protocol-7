# Protocol-7 Development Memory
## Topic Files (details live here)
- `topic-tls-acme.md` — SNI/SSL internals, ACME/letsencr details, cert discovery
- `topic-patterns.md` — event handler pattern, variable watcher, SSL server socket behavior
- `topic-completed.md` — session summaries (cert discovery, models memory, data zenka)

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

### Variable Watcher Backup/Restore (CRITICAL — see topic-patterns.md)
- Stop → back up → replace → restore with `->again()` (never `->now()`)

### Event Handler Pattern (CRITICAL — see topic-patterns.md)
- Handlers receive Event object as first param, not data directly
- Extract: `my $event = shift->w; my $server = $event->data;`

#,,,.,,,,,,.,,,.,,.,.,...,,..,.,,,,..,,.,,,,,,..,,...,...,,,.,...,...,,..,,.,,
#HWZDQGOZVLXGTX77KMZ443KUNM6BVFETKBWKOWX6UKXZBKEGVXTHWZZOZUKQMBLUAWLDUIJDQIJ4O
#\\\|6IF276C6437HIHSNCYMC3GOUBBTMO5U4F2MMCLWBLIPCF3X5P7G \ / AMOS7 \ YOURUM ::
#\[7]RVH7OVYZINH6KZGJADW57LHDBSGKPV3ZJLLVALOTGXYIBDSBHGBY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
