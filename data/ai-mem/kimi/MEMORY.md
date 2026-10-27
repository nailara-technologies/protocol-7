# Kimi Development Memory — top-level index

this file is auto-loaded every session. it keeps only the CRITICAL items inline; everything else
lives in the category files below. when a topic surfaces in conversation that matches a category
summary, OPEN that file — it is not auto-loaded, so it is only consulted when you go read it.

## CRITICAL

- **commit policy** — never commit without a valid version number (`./bin/dev/update-version`) and
  proper signatures (`bin/Protocol-7 sourcecode update-signatures`). use `--no-verify` only in
  emergencies.
- **commit message form** — short `area : topic` title [ aim ~72 chars ], ONE empty line, then `- `
  bullets wrapped at ~75 [ two-space continuation ]. a one-line message is fine only when there
  is nothing more to say — never fold the whole body into the title with `;` `--` `[ ]`. the
  multi-line messages in the history are the CORRECT form, the long one-liners are the offenders
  [ 2026-09-30 a reword task inverted this, collapsed the correct messages and was force-pushed ;
  before any history reword, show the older-history baseline and state which form is produced ].
- **structural work conventions** — before structural work, read
  `data/md/development/STYLE-PHILOSOPHY.md` alongside `data/yaml/code-style/CONVENTIONS.yaml` and
  `data/md/development/CODE-STYLE-AND-LLM-INTEGRATION.md`; update the philosophy doc if you refine
  its perspectives.
- **signature updates require user passphrase** — ask the user to run the signing command; never
  skip hooks.
- **session-end ritual** — user signs + stages; I commit (running `./bin/dev/update-version` first if
  the hook flags a version mismatch); the user then rebuilds the bundle (`gbc` alias) and pushes
  `hub base`. pushing to the `ext-bundle` remote fails by design — it is the bundle FILE, read-only.
- **memory tool limits** — `p7_memory_update` enforces per-agent line limits on `MEMORY.md`
  (claude ~180/200, kimi ~300/400); use `target` for external topic files and `UPDATE FILE:`
  directives for category files.

## Category files — open the one that matches the topic in play

- **[MEMORY-active.md](MEMORY-active.md)** — in-flight / recently-landed work.  
  open for: `routing_mode`, `strm.subscribe`, `session_catchup`, `bin/chat`, jobsite pipeline,
  duck.ai security task tree, coding self-test async transport, kimi `QuestionRequest` decline,
  amos-term interaction prototype, `source.extract_sig_body` fake-footer fix, audio spatial-purr,
  ncode scope-stack phase 2, ascii.frame cursor marker, `AMOS7::TERM::Editor` hardening
  [ scroll-free frame, kill stack + paste, mlock/wipe hygiene, pty test discipline ].

- **[MEMORY-reference.md](MEMORY-reference.md)** — durable how-to + settled rules.  
  open for: memory update tool details, `%code` presence / cross-namespace calls, module name
  swaps, command return style / deferred replies, perlmod load/autoload lessons, user-edit outbox
  unlink choice, format-code sugar passes + test harness convention.

- **[MEMORY-feedback.md](MEMORY-feedback.md)** — gotchas, failure modes, and incidents.  
  open for: fork-child gotchas, iteration-counter quality rejection, `v7-zenki.terminate` deadlock,
  `v7-zenki.reload init` live-network teardown, format-code -m dynamic-key false positive +
  no-dot sugar sweep.

- **[topic-model-batch-harness-and-self-test-findings.md](topic-model-batch-harness-and-self-test-findings.md)**
  — 2026-09-21: Event.pm silent watcher suspension, `event.add_timer` `data` vs `params`,
  ambient `$call` hazard, self-test seed-restart gate coverage (prompts 2+3), prompt 3
  `mismatch_hint`, honest context-exhausted reporting, batch harness env blockers (open).

- **[topic-host-power-management.md](topic-host-power-management.md)**
  — 2026-10-27: `p7-deps host-power [awake|suspending]` implemented (AMOS7::deps::hostpower,
  41-check harness) + `host_power:` profile pin (basic-remote-server -> awake) ;
  wakeup-toggle / tmpfiles-dedupe / boot-time-guard-list / own-unit-upgrade gotchas ;
  same-session p7-install upgrade (aptlog-styled apt output, cpanminus bootstrap,
  debian-first resolution for cpan: entries).

- **[MEMORY-completed.md](MEMORY-completed.md)** — explicitly-completed / resolved work.
- **[MEMORY-archive.md](MEMORY-archive.md)** — stale chronological session log.

#,,,,,,.,,,.,,,,.,..,,.,.,,.,,,,.,...,,..,,.,,.,.,...,...,.,,,,..,,.,,,,.,,,.,
#YZ5PNGHZJ6QY3232KS7SFBPVASVWMVRC6KILCIBP6XGAQRZTA2GZWQGS6N5GVPLUO5LED7SAJ35DW
#\\\|M3KDPFMEMM65UR4TGA7RWP7C45WDF2PQJ4M4RTAGNCJQZEM3ASR \ / AMOS7 \ YOURUM ::
#\[7]IUSE36IXJPMXK7LLQYOFZRVS4J3MFA4B4ZRTOHYBFAAIHIT4H4BQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
## 2026-10-25 handover — coding tool-args encoding + mcp spawn env

- fixed the coding-zenka tool-args utf-8 double-encoding class [ the
  site-yaml-family bug that garbled a local model's edit of
  data/tasks/completed/inline-subs-batch-4-final.md ] : commit 1a5fb0698.
  three sites : xml/json producers now emit character strings via shared
  coding.async.tool_args_decode ; state_machine stores arguments as
  character JSON ; edit_file reads the staged copy with its write
  encoding + drops it after write. regression test
  bin/dev/tests/test-coding-tool-args-encoding.pl 12/12.
- the task report was reworded to the actual fix state [ 12 callers on
  <[workspace-transfer.util.chdir_workspace]>, workspace_transfer::
  count 0 in src/ ] ; follow-up : live-run one workspace-transfer caller
  once its ondemand zenka starts.
- mcp-server-p7 gained _sanitize_agent_env [ strips all *_proxy vars
  before every agent spawn ] : a bracketed [::1] in a child no_proxy
  crashed httpx [ Invalid port ':1]' ] — see
  [[bug-mcp-kimi-dispatch-proxy-env-crash]]. live-verified after restart.
- open thread : WHO injects the bracketed [::1] upstream of the exec
  [ kimi CLI MCP-spawn env suspected, not proven ] — the sanitizer makes
  it moot; /etc/environment still has a malformed ALL_PROXY=socks5//…
  and .bashrc builds no_proxy with bare $(hostname -I) IPv6 — both
  landmines for stricter parsers.

## 2026-10-27 handover — WSL usbipd host-USB + async powershell zenka

- powershell zenka gained `usbipd-{list,attach,detach}` [ attach =
  DEFERRED reply + poll timer ] + wedge-proof `powershell.exec`
  [ concurrent drain , 60s idle timeout ] : commits c37c63580..54ae2453e.
  full detail + the WSL-tETHER-STALL forensics [ 18-experiment matrix ,
  Start-Process -WindowStyle Hidden escape , mechanism UNKNOWN ] :
  [[project-2026-10-27-session-handover-usbipd-wsl]].
- editor `detail_editor_wrap_segments` clamped to width >= 1 [ headless
  zero-width spun 9h ] : 11cf1d92a.
- LAST-BUG-STANDING lesson : qw|IO::Select| import list in a
  base.perlmod.autoload call made init_code abort midway , silently
  skipping later init sections — autoload importless modules with a
  single arg ; follow-up : init-runner per-section error containment.
- ops : zenka logs at /var/log/protocol-7/<host>.<zenka>.zenka.log +
  /dev/shm/.7/STDOUT ring bypass wedged MCP ; p7c unusable from agent
  bash [ silent hang ] ; kimi-legacy shim repaired [ uv python 3.13 ].

#,,..,...,,,.,.,.,..,,,.,,..,,...,,,,,,.,,.,,,..,,...,...,.,.,.,.,...,..,,...,
#HO7YA2TZBDAYVXVQITCGEA2XRWVRMDMTM5GDEPYNYVU55ZNYCJCJX4NSW2DMJTGJMS3QM6GX2QRNC
#\\\|U32LHPTFMEUI5HZSGRNSJQTLXC33X2B7JJEWZPVTLU4QP2I7YHR \ / AMOS7 \ YOURUM ::
#\[7]WVR5VDFQ5YOXO5IJHQMA4TL26TXAKNNXGFILO7E2ST77XIERS6BY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
## 2026-10-27 handover — azurum host power + p7-install upgrade

- azurum kept suspending to S3 killing SSH : culprit chain GNOME gsd-power
  idle-suspend -> logind -> systemd [ journalctl _COMM=systemd-logind names
  the requester ]. hand fixes : mask the 4 sleep targets, gsettings
  sleep-inactive-ac/battery-type 'nothing', guard-based wakeup-disable
  oneshot. gotchas : /proc/acpi/wakeup writes TOGGLE ; systemd-tmpfiles
  w-lines dedupe by path AND toggle -- unusable here .
- implemented `bin/p7-deps host-power [awake|suspending]` [ AMOS7::deps::
  hostpower , 41-check harness ] : awake masks targets + guards all non-RTC
  wake devices + gnome keys ; suspending keeps manual/zenka suspend, keeps
  firmware wake defaults, persists WakeOnLan via 50-p7-wol-*.link [ mac
  matched , wired only ] . modes undo each other . `host_power:` key in
  profiles.yaml runs after a clean install [ basic-remote-server pins
  awake ] . commits 398741922..b7f23922c .
- p7-install upgrade [ a92333739 , d8bc276d7 ] : apt output streams through
  the aptlog condenser with framed rows ; cpanminus bootstrapped from apt ;
  cpan: entries with a debian mapping install the .deb first [ fresh hosts
  need no XS toolchain ] ; cpanm -q with framed failure tail . verified live
  on azurum .
- open : KDE/XFCE idle-suspend keys ; `host-suspend` counterpart for the
  v7-zenka host power commands ; azurum wired-NIC WoL check once cabled .

#,,,,,.,.,...,..,,...,,,.,.,,,,,.,...,,,,,,,,,...,...,...,...,,.,,.,.,...,..,,
#ZG3RVVMDMUZREG45O3TFWYZKFBKXMBLIVSYO5BF5PEKAJLUO36ZLRUJPK257NUH4KBGGIPVYTIBG4
#\\\|C372CCMUDSRURYNMY5BG255CJ24KGIJN7VHDJL5M5RSOHCNATZQ \ / AMOS7 \ YOURUM ::
#\[7]44SPHFWEMHBRKBHU6QVEGPDER6SL5UJYIQHO2KMSJ5FZPW4N54AY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
