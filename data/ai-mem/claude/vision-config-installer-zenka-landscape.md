---
name: vision-config-installer-zenka-landscape
description: "current + planned zenki around system configuration: set-up (renamed from settings, freeing that namespace for a future settings zenka) and configure both exist today; installer zenka and a user-edit CLI-style interface plus web-UIs are future work, connected to the template-extraction plan (vision-generic-web-template-hybrid-doc-browser)"
metadata:
  node_type: memory
  type: project
  originSessionId: fee6b203-065d-46ee-9e22-bac7aa31efd1
---

2026-08-31, user context-dump while discussing os-pkg/reproducible-installs
and user-data-derived-config vision (see [[vision-os-pkg-reproducible-installs]],
[[vision-user-data-derived-zenka-configuration]] — this note is adjacent to
both but distinct: it's about the *zenka landscape* for config/setup/install,
not the data-driven-generation pattern itself).

## current state (confirmed live)

- `set-up` zenka exists (`cfg/zenki/set-up/`) — handles
  create-profile/install-profile/export-config/fetch-zenka-config/
  list-dependencies/dump per its `access.cmd.usr.cube` grant. **Was
  renamed from `settings`** specifically to free the `settings` namespace
  for a future, distinct `settings` zenka — not a random rename.
- `configure` zenka also exists separately (`cfg/zenki/configure/`,
  "nailara configuration management zenka") — a third, currently-distinct
  concern from both `set-up` and the future `settings`.
- `user-edit` zenka already exists.
- No `installer` zenka yet, no `settings` zenka yet (namespace
  deliberately held open).

## planned

- An actual **installer zenka** — not yet started, no design captured
  yet beyond the name.
- A **user-edit CLI-style interface** in addition to whatever access
  exists today, PLUS **web-UIs** for these same config/setup/install
  concerns — ties directly into
  [[vision-generic-web-template-hybrid-doc-browser]]'s stage 3
  ("locked-down local system config/setup/management UI") and stage 4
  (network-facing config builder) — same template-extraction work this
  whole family of zenki would eventually draw its UI from.

## status

Pure context/vision capture, no design decisions made on how `set-up`,
`configure`, the future `settings`, and the future `installer` zenka
divide responsibility from each other — that boundary isn't drawn yet.
Don't start building the installer zenka or a settings zenka
unprompted; the namespace being reserved is a signal of intent, not a
request to fill it.

#,,..,,..,,..,..,,,,.,,.,,,.,,.,.,,,.,.,,,.,.,..,,...,...,.,.,.,,,...,,.,,...,
#JPEULEAHWGPE7UA2OKDUKJE4QO6MO557XFQSZ53JEBCAPWYHJVO73XENDZIC3UDFET4OFH376XZNK
#\\\|PMVFYVZEX4ZCU4YOLBU3PWOLHT7KFIOQBUIR57ZPQADYF7ZSXZN \ / AMOS7 \ YOURUM ::
#\[7]DDNODTBGXQZ3FTDJUFRXZ5AKV75AJJ2X7QFPMRJD75E42BJKEOAY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
