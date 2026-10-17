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


## boot medium path [ 2026-10-17, owner ]

- earlier boot medium work may be LOST [ two crashed laptops, only disk
  recovery could bring it back ] -- the experience stays.
- convergence order : own signed debs for everything [ step 7, see
  [[project-2026-10-17-session-handover-installer-cloud]] ] -> a LIVE
  boot medium RUNNING protocol-7 with persistent user data [ overlayfs,
  usable offline and connected ] -> INSTALLER MODE as a natural addition
  of that medium [ the installer zenka above : more capable than
  debian-installer, which stays the simpler option -- a preseed
  late_command adding the medium's repo + a profile metapackage ].
- the debs make it simple : no cpan \ network \ compiling at install
  time, profiles as metapackages, the same repo for medium, stick and
  offline node groups.
- open : the trust anchor on the medium [ no pin on a fresh machine --
  the medium carries the repo key + host-root pub + signed fingerprint,
  could write the first pin ] -- owner's call.
- the plan side survives in the repo : data/yaml/coding-tasks/
  phase-5-multinode-deployment.yaml [ 2026-02-07 ] -- task A2 = data
  recovery of both laptops [ image first, checksums ], A3 = install media
  [ usb for laptops, sd image for the pi, usb \ net boot for the atom,
  preseed ] ; all still pending. git history holds no boot medium code.
  the path above would replace A3's preseed-only approach.
- still intent, not a build request.

#,,..,.,,,...,.,,,,..,...,,.,,..,,,.,,,,,,..,,...,...,...,..,,...,...,.,.,.,,,
#2KGKRKEDW5EQF77PZDSOB3S3U772Z4EOP77QSTB4WN6KLNEU4PKDBAXRTF5ESDZJ2WYME2Y7GJYAQ
#\\\|O7ESVORTQQMCEWDHVIEDOD2YNKJQEOP67JUK5AXZPWP6XHFOAQP \ / AMOS7 \ YOURUM ::
#\[7]MTB3EREAM7HFSZ4ANJE6CIXQL46E4ENR2WBRRBGOG4ZRCCI7ZCBY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
