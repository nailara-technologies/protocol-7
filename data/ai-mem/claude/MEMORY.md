# MEMORY — top-level index

this file is auto-loaded every session. it keeps only the CRITICAL items inline; everything else
lives in the category files below. when a topic surfaces in conversation that matches a category
summary, OPEN that file — it is not auto-loaded, so it is only consulted when you go read it.

## CRITICAL
- [deleted-manually-tuned-captures-without-confirming](feedback-deleted-manually-tuned-captures-without-confirming.md) — 2026-08-28: deleted 117 files from a shared dir based on filename-pattern inference alone ("all named snapshot.*, must be disposable"), no confirmation asked; some were the user's hand-tuned interactive visualization states, unrecoverable (no fs snapshot/trash, plain ext4). NEVER delete anything outside a designated scratchpad without asking first, even when the naming/location looks conclusively like test debris — content value is not inferable from filename pattern or origin command alone
- [user-screen-brightness-sensitivity](feedback-user-screen-brightness-sensitivity.md) — real physical reaction to bright screens, not aesthetic; default new HTML/UI work to dark violet/blue-toned themes proactively, keep print forced light
- [rapid-pattern-visual-disruption-risk](feedback-rapid-pattern-visual-disruption-risk.md) — real, lasting adverse effect (temporary inability to read text) from sustained attentive exposure to dense high-entropy ANSI-cycling visuals (bin/atom-delta-term); default any future rapid/psychedelic visual work (incl. vision-orbital-hop-sequence-hyperspace-flight-animation) to conservative, easily-slowed cycling rate, not max intensity
- [no-personal-data-in-repo-tree](feedback-no-personal-data-in-repo-tree.md) — never hardcode emails/PII, or real hostnames/IPs of live deployments, into any repo-tracked file — src, gitignored, or memory files (`data/ai-mem/claude/*.md` is git-tracked too); use `<[file.zenka_dir.load]>->('cfg-dir:<zenka>/file')`, `/data/<project>-data/` external dirs, or generic phrasing instead
- [memory-write-path](feedback-edit-memory-via-ai-mem-path.md) — always Read/Edit/Write memory via data/ai-mem/claude/<file>, never the ~/.claude/projects/.../memory/ symlink path (same files, home path re-prompts every edit)
- [settings-json-repair-mode-does-not-persist](feedback-settings-json-repair-mode-does-not-persist.md) — broken .claude/settings.local.json (e.g. trailing comma) triggers in-session repair that burns tokens but never saves; verify JSON validity on disk directly, restart required after manual fix
- [web-browser ephemeral storage](feedback-web-browser-ephemeral-storage.md) — WebKit ephemeral=1: storage wiped every restart
- [WSLg deiconify limitation](feedback-wslg-deiconify-limitation.md) — Weston/WSLg blocks deiconify at compositor level
- [gtk-wsl-window-positioning](topic-gtk-wsl-window-positioning.md) / [weston-move-unreliable](feedback-weston-move-unreliable-use-compositor-grab.md) — begin_move_drag not move(); window.place grab-leak fixed fff81c212, initial-placement-before-show_all still open; 2026-08-24: hazard broadened past begin_move_drag (a plain close with no drag also freezes cross-process mouse input), real fix still unconfirmed — read the 2026-08-24 section before touching this again, and NEVER chain a synchronous destroy+recreate self-heal on a live freeze (escalated to needing a full host reboot)
- [editing-p7-owned-data-files-reowns-them](feedback-editing-p7-owned-data-files-reowns-them.md) — hand-editing a protocol-7-owned data file (e.g. a users.* record) via Edit/Write silently reassigns it to my own unix user, and the owning zenka then reports the record as NOT FOUND, not a permission error — check `ls -la` ownership before ever hand-editing such a file
- [rename-scope-policy](feedback-rename-scope-policy.md) — never cite scope/blast-radius as a reason to hesitate on a rename; judge renames on improvement only — `bin/ncode` makes even large ones mechanical, and commercial deployments elsewhere forked off `base` years ago so nobody tracking `base` is disrupted
- [hour-of-day-hedging-not-genuine](feedback-hour-of-day-hedging-not-genuine.md) — citing "the hour"/lateness as a reason to suggest stopping is a disengagement tic, not real signal (I don't know the user's actual local time); if a hard problem isn't converging, name the real uncertainty directly instead
- [cpanm-force-install-blast-radius](feedback-cpanm-force-install-blast-radius.md) — `sudo cpanm --force <module>` for one narrow CPAN need can silently pull in an apt dependency chain that upgrades shared system crypto libs AND shift the effective default perl version — check `dpkg.log`/`apt list --upgradable` before *and* after any force-install on this host, flag explicitly even when the target module has nothing to do with crypto
- [cpanm-triggered-inline-elf-utf8-boundary-bug](feedback-cpanm-triggered-inline-elf-utf8-boundary-bug.md) — FULLY CLOSED 2026-08-26, committed `0875c8668`+`94aa460a7`: three independent 2021-era bugs found and fixed — two in `AMOS7::CHKSUM::ELF::inline_elf` (stale-len underflow + u8_len=1 misalignment) and a third in `crypt.C25519.load_keypair` (wrong file read + unconditional prefix-strip) that only surfaced once new `keys.backup.*` infrastructure (also this session, fixes `.secret`-bearing keys in change-passwd/dec-key/enc-key) enabled a real end-to-end test. All verified against a real key, all committed and signed, working tree clean. Read before touching `crypt.C25519.*`, `AMOS7::CHKSUM::ELF`, `keys.console.*`, or a bulk re-sign — the full bug-hunt methodology (safe size-only diagnostics, never touching real key material) is worth reusing

## Category files — open the one that matches the topic in play

- **[MEMORY-active.md](MEMORY-active.md)** (59 pointers) — in-flight / recently-landed work.
  open for: x11 (hardening, resolution-profiles, multi-server, bare-name routing), window placement,
  mpv startup/persistence, ascii-frame & ascii-desktop-domains UI, coding & kimi zenka state machines,
  jobsite ui/assessment, streaming transport & reply modes, web-browser capture/replay/waypoints,
  reasoning namespace, orbital/STRM push, credential-fabric transport, ondemand watchdog, p7-log utf8.

- **[MEMORY-reference.md](MEMORY-reference.md)** (58 pointers) — durable how-to + settled rules.
  open for: how a convention works or the "right way" to do something — cube auth. prefix, .cmd. reply
  contract (mode/data STRING), send.local vs base., timer undef-interval, config-reload clobber,
  file-io API, deferred-init callbacks, C25519 config paths, ntime; zenka catalog (site-yaml, git-watch,
  fetch-files/huggingface, usb-backup, invoke-model-manager), tool-SHM architecture, tls-acme,
  unicode-encoding repair, core patterns/templates, nshell SS3-arrow/DECCKM terminal gotcha + live
  debug-status/char-add session probing.

- **[MEMORY-feedback.md](MEMORY-feedback.md)** (55 pointers) — gotchas & failure modes.
  open for: kimi/claude dispatch strategy & infra hardening, dispatch-summarize hang, tasks-completed
  scan distrust, no-sudo on p7-owned files, perl and/or precedence, p7 route-send wire protocol,
  coding-zenka reasoning/edits/inject pitfalls, ncode tooling & access-gap, perltidy self-heal,
  arg calling convention, memory-management/sync timing, git-log false-duplication, webkit-vs-firefox css,
  undef-sub scanner verification (guards/eval-wrapping/dynamic-sprintf-dispatch before renaming),
  swap_subs nested-lifecycle-hook gate (base32/chk-sum.bmw crash-instead-of-defer, e90dd04ae).

- **[MEMORY-vision.md](MEMORY-vision.md)** (51 pointers) — long-horizon architecture, mostly design-only.
  open for: perspective/navigation geometry, C25519 trust identity & source-spoofing, namespace/routing
  algebra, checksum-addressing trinity, harmonic-mathematics / mod-13 vs Rodin, reference-bubble,
  network-as-computer, dedup-tree unification, coding-as-artform / style-philosophy, write-access security.

- **[MEMORY-completed.md](MEMORY-completed.md)** (5 pointers) — session archive & live status.
  open for: past session summaries (topic-completed), next-steps queue/roadmap, resolved bugs,
  system live-status (letsencr, reasoning.branch.*, coding zenka).

#,,..,,,,,,..,,,,,,.,,...,...,,..,...,,,,,,.,,..,,...,...,,.,,...,.,.,,,.,,,,,
#CN7IFRFHOSPGAZJN2YUL4SQAPCZTRZA3OAPODRT3UUPPUYH5XYVMUZVUJ6MSNVBZB6BEBZUBYI2QI
#\\\|RQSGEKHT36OT6G7EDLWE6X76XXUOO2INGWLVGSP2WNO4LRF6OO4 \ / AMOS7 \ YOURUM ::
#\[7]AOBDCPI4J2PPVTGYGHGT4NKW2DX2G5ILCKUVNQ4RGLTTMMXIXUBI 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
