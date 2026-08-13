# MEMORY — top-level index

this file is auto-loaded every session. it keeps only the CRITICAL items inline; everything else
lives in the category files below. when a topic surfaces in conversation that matches a category
summary, OPEN that file — it is not auto-loaded, so it is only consulted when you go read it.

## CRITICAL
- [user-screen-brightness-sensitivity](feedback-user-screen-brightness-sensitivity.md) — real physical reaction to bright screens, not aesthetic; default new HTML/UI work to dark violet/blue-toned themes proactively, keep print forced light
- [rapid-pattern-visual-disruption-risk](feedback-rapid-pattern-visual-disruption-risk.md) — real, lasting adverse effect (temporary inability to read text) from sustained attentive exposure to dense high-entropy ANSI-cycling visuals (bin/atom-delta-term); default any future rapid/psychedelic visual work (incl. vision-orbital-hop-sequence-hyperspace-flight-animation) to conservative, easily-slowed cycling rate, not max intensity
- [no-personal-data-in-repo-tree](feedback-no-personal-data-in-repo-tree.md) — never hardcode emails/PII into any repo-tracked file, even gitignored; use `<[file.zenka_dir.load]>->('cfg-dir:<zenka>/file')` or `/data/<project>-data/` external dirs instead
- [memory-write-path](feedback-edit-memory-via-ai-mem-path.md) — always Read/Edit/Write memory via data/ai-mem/claude/<file>, never the ~/.claude/projects/.../memory/ symlink path (same files, home path re-prompts every edit)
- [settings-json-repair-mode-does-not-persist](feedback-settings-json-repair-mode-does-not-persist.md) — broken .claude/settings.local.json (e.g. trailing comma) triggers in-session repair that burns tokens but never saves; verify JSON validity on disk directly, restart required after manual fix
- [web-browser ephemeral storage](feedback-web-browser-ephemeral-storage.md) — WebKit ephemeral=1: storage wiped every restart
- [WSLg deiconify limitation](feedback-wslg-deiconify-limitation.md) — Weston/WSLg blocks deiconify at compositor level
- [gtk-wsl-window-positioning](topic-gtk-wsl-window-positioning.md) / [weston-move-unreliable](feedback-weston-move-unreliable-use-compositor-grab.md) — begin_move_drag not move(); window.place grab-leak fixed fff81c212, initial-placement-before-show_all still open
- [editing-p7-owned-data-files-reowns-them](feedback-editing-p7-owned-data-files-reowns-them.md) — hand-editing a protocol-7-owned data file (e.g. a users.* record) via Edit/Write silently reassigns it to my own unix user, and the owning zenka then reports the record as NOT FOUND, not a permission error — check `ls -la` ownership before ever hand-editing such a file

## Category files — open the one that matches the topic in play

- **[MEMORY-active.md](MEMORY-active.md)** (58 pointers) — in-flight / recently-landed work.
  open for: x11 (hardening, resolution-profiles, multi-server, bare-name routing), window placement,
  mpv startup/persistence, ascii-frame & ascii-desktop-domains UI, coding & kimi zenka state machines,
  jobsite ui/assessment, streaming transport & reply modes, web-browser capture/replay/waypoints,
  reasoning namespace, orbital/STRM push, credential-fabric transport, ondemand watchdog, p7-log utf8.

- **[MEMORY-reference.md](MEMORY-reference.md)** (56 pointers) — durable how-to + settled rules.
  open for: how a convention works or the "right way" to do something — cube auth. prefix, .cmd. reply
  contract (mode/data STRING), send.local vs base., timer undef-interval, config-reload clobber,
  file-io API, deferred-init callbacks, C25519 config paths, ntime; zenka catalog (site-yaml, git-watch,
  fetch-files/huggingface, usb-backup, invoke-model-manager), tool-SHM architecture, tls-acme,
  unicode-encoding repair, core patterns/templates, nshell SS3-arrow/DECCKM terminal gotcha + live
  debug-status/char-add session probing.

- **[MEMORY-feedback.md](MEMORY-feedback.md)** (52 pointers) — gotchas & failure modes.
  open for: kimi/claude dispatch strategy & infra hardening, dispatch-summarize hang, tasks-completed
  scan distrust, no-sudo on p7-owned files, perl and/or precedence, p7 route-send wire protocol,
  coding-zenka reasoning/edits/inject pitfalls, ncode tooling & access-gap, perltidy self-heal,
  arg calling convention, memory-management/sync timing, git-log false-duplication, webkit-vs-firefox css,
  undef-sub scanner verification (guards/eval-wrapping/dynamic-sprintf-dispatch before renaming),
  swap_subs nested-lifecycle-hook gate (base32/chk-sum.bmw crash-instead-of-defer, e90dd04ae).

- **[MEMORY-vision.md](MEMORY-vision.md)** (48 pointers) — long-horizon architecture, mostly design-only.
  open for: perspective/navigation geometry, C25519 trust identity & source-spoofing, namespace/routing
  algebra, checksum-addressing trinity, harmonic-mathematics / mod-13 vs Rodin, reference-bubble,
  network-as-computer, dedup-tree unification, coding-as-artform / style-philosophy, write-access security.

- **[MEMORY-completed.md](MEMORY-completed.md)** (5 pointers) — session archive & live status.
  open for: past session summaries (topic-completed), next-steps queue/roadmap, resolved bugs,
  system live-status (letsencr, reasoning.branch.*, coding zenka).

#,,.,,,.,,,,.,,..,.,.,..,,,.,,..,,..,,,.,,.,,,..,,...,.,,,..,,..,,,,.,,.,,..,,
#U475H3W4WLKLUGNGO6DCLLDB2ECIOZD6KBV2JJMJ3LQAYQZ3FKXU6WWTEQXPGC7B6XUFYTDFCVZ4W
#\\\|CGKU5CBXZT7NZJNNGCDCVY5QWUA43JWFBKDN73FWJ64VUDQYFIU \ / AMOS7 \ YOURUM ::
#\[7]3OZW7FHHVQNA35XGRLYZMT7NJS2QO7FNOLHBK7Z4TSW52QIK2GBQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
