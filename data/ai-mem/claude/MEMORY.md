# MEMORY — top-level index

this file is auto-loaded every session. it keeps only the CRITICAL items inline; everything else
lives in the category files below. when a topic surfaces in conversation that matches a category
summary, OPEN that file — it is not auto-loaded, so it is only consulted when you go read it.

## CRITICAL
- [web-browser ephemeral storage](feedback-web-browser-ephemeral-storage.md) — WebKit ephemeral=1: storage wiped every restart
- [WSLg deiconify limitation](feedback-wslg-deiconify-limitation.md) — Weston/WSLg blocks deiconify at compositor level
- [gtk-wsl-window-positioning](topic-gtk-wsl-window-positioning.md) / [weston-move-unreliable](feedback-weston-move-unreliable-use-compositor-grab.md) — begin_move_drag not move(); window.place grab-leak fixed fff81c212, initial-placement-before-show_all still open

## Category files — open the one that matches the topic in play

- **[MEMORY-active.md](MEMORY-active.md)** (55 pointers) — in-flight / recently-landed work.
  open for: x11 (hardening, resolution-profiles, multi-server, bare-name routing), window placement,
  mpv startup/persistence, ascii-frame & ascii-desktop-domains UI, coding & kimi zenka state machines,
  jobsite ui/assessment, streaming transport & reply modes, web-browser capture/replay/waypoints,
  reasoning namespace, orbital/STRM push, credential-fabric transport, ondemand watchdog, p7-log utf8.

- **[MEMORY-reference.md](MEMORY-reference.md)** (53 pointers) — durable how-to + settled rules.
  open for: how a convention works or the "right way" to do something — cube auth. prefix, .cmd. reply
  contract (mode/data STRING), send.local vs base., timer undef-interval, config-reload clobber,
  file-io API, deferred-init callbacks, C25519 config paths, ntime; zenka catalog (site-yaml, git-watch,
  fetch-files/huggingface, usb-backup, invoke-model-manager), tool-SHM architecture, tls-acme,
  unicode-encoding repair, core patterns/templates.

- **[MEMORY-feedback.md](MEMORY-feedback.md)** (49 pointers) — gotchas & failure modes.
  open for: kimi/claude dispatch strategy & infra hardening, dispatch-summarize hang, tasks-completed
  scan distrust, no-sudo on p7-owned files, perl and/or precedence, p7 route-send wire protocol,
  coding-zenka reasoning/edits/inject pitfalls, ncode tooling & access-gap, perltidy self-heal,
  arg calling convention, memory-management/sync timing, git-log false-duplication, webkit-vs-firefox css,
  undef-sub scanner verification (guards/eval-wrapping/dynamic-sprintf-dispatch before renaming),
  swap_subs nested-lifecycle-hook gate (base32/chk-sum.bmw crash-instead-of-defer, e90dd04ae).

- **[MEMORY-vision.md](MEMORY-vision.md)** (45 pointers) — long-horizon architecture, mostly design-only.
  open for: perspective/navigation geometry, C25519 trust identity & source-spoofing, namespace/routing
  algebra, checksum-addressing trinity, harmonic-mathematics / mod-13 vs Rodin, reference-bubble,
  network-as-computer, dedup-tree unification, coding-as-artform / style-philosophy, write-access security.

- **[MEMORY-completed.md](MEMORY-completed.md)** (5 pointers) — session archive & live status.
  open for: past session summaries (topic-completed), next-steps queue/roadmap, resolved bugs,
  system live-status (letsencr, reasoning.branch.*, coding zenka).

#,,,.,.,,,.,.,..,,.,,,,.,,,..,,,,,,..,.,,,,,,,..,,...,.,.,.,.,,,.,,..,..,,,..,
#ZZDX4LWPXXJRU5FUI367BC6VPXKXARMU2EK76LWTY6DFZZYWBSCL2KOKQRMLL6KVHB4TUQHJUTVMA
#\\\|OWWML5UVFYP2LNKNH5TRLKP6R2DNK7NGACKUHXN3L4767VU3D4V \ / AMOS7 \ YOURUM ::
#\[7]WKLD4RTWT6YCJMLHLW7K5DK2RFVDUCJR342JIDU6ULPWE3K2LCAQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
