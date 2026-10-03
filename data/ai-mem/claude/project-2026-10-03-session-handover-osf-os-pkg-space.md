---
name: project-2026-10-03-session-handover-osf-os-pkg-space
description: handover of the 2026-10-02/03 marathon session [ ~22 commits, ends b82629df3 ] -- what landed [ trit\symmetry\chunker\condenser\os-pkg install\osf-cache stage 1 ], open next steps per area, and the workflow lessons [ sign-complete check, kimi review split ]
metadata:
  type: project
---

session 2026-10-02 -> 10-03, last commit `b82629df3`. start a fresh
session from here ; this note + the task files carry the state.

## landed [ code ]

- `branch.space.trit.{role,octant_bits,intent_frame,polarity}`,
  `branch.space.hop_ball_size` [ test-branch-space-trit.pl ]
- `branch.space.symmetry.{list,apply,invariants,random_baseline}` [ 48 cube
  symmetries, test-branch-space-symmetry.pl ]
- `base.chunk.rolling_mod` + `bin/dev/chunk-bench` [ `-t 4k` : mod 4095 =
  3²·5·7·13, 256³ ≡ 1 -> on par with gear on the two-version dedup case ;
  column `stored%` = LOWER is better -- kimi once read it backwards ]
- `debian.log.condense` [ one line per package, errors pass through ]
- os-pkg : `init_code` [ /etc/os-release -> backend ], `cmd.backend`,
  `cmd.status`, `cmd.install` + `handler.install_reply` [ forwards to
  `debian.install-packages`, sys-deps pattern ] ; access narrowed
  [ explicit list in zenka.v7, cube grant `access.cmd.usr.os-pkg` ].
  verified live : `p7c os-pkg.install hello` -> `hello` IS STILL INSTALLED,
  first test case for the future remove command
- osf-cache stage 1 : `osf-cache.debian.read_inrelease` \ `read_packages` \
  `holdings.scan_apt_cache` + `bin/dev/osf-holdings` [ trust = good
  signature AND matching list hash ; 8 of 18 cached debs anchored ]
- `bin/dev/commit-graph`

## found on the host

- github cli apt repo : InRelease signed by key 7F38BBB59D064DBCB3D84D725612B36462313325,
  NOT in the installed githubcli-archive-keyring.gpg [ jun 2025 ] -> key
  rotated ; user needs to refresh the keyring [ root ]
- invoke qwen 2.1 fork : negative vram model budget [ task
  `invoke-qwen21-vram-budget-tuning.md` ] ; 5 references = pcie-bound
- host pc warranty until ~2027-02 [ [[host-pc-warranty-until-2027-02]] ]

## next steps [ by area ]

- **os-pkg** [ `data/md/design/OS-PKG-GENERIC-PACKAGE-ZENKA.md` ] : stage 3
  streaming [ condensed lines as STRM ], 4 history, 5 remove \ upgrade \
  update \ search, contextualized p7c clone [ `bin/c_src/sftp_srv.c`
  pattern ], `native-pv7` as an additional package source [ discussed, not
  yet in the design ]. live-zenki work : do it WITH the user
- **osf-cache** [ `data/md/design/OSF-CACHE-ZENKA.md` ] : stage 2 hash
  lookup across nodes, then fetch, fuse takeover of /var/cache/apt
  [ reuse `data.mount.fuse.*` ], merkle per file, credits ; roadmap
  layers /etc -> home -> /data
- **signing** [ `data/tasks/signing-commit-wait-marker.md` ] : per-run
  markers, pre-commit hook waits ; signing agent = key-holding child
  [ [[vision-sessions-zenka-key-holding-children]] ], pin logic,
  protocol-7-menu dialogs. touches the hook -> with the user
- **chunker** : structure-alignment advantage untested ; always min \ max
  guards
- **deconfliction simulator** : split into stages before dispatch
- **open questions** : `data/tasks/design-open-questions-2026-10-02.md`
- other new tasks : psytrance stem remix + optical controller, povray
  optical topology, os-pkg condensed log stream

## workflow lessons

- before EVERY commit : `git -c color.ui=false status --short` must show no
  second-column change [ ` M` \ `MM` = signing still running ] -- see
  [[feedback-request-signed-version-before-each-batch-commit]]
- kimi does implementation well ; the review that matters is semantic
  [ column meaning, trust rules ] and needs design context. a sub-session
  can run dispatch + mechanical review [ tests, format-code ] from a
  precise task file ; semantic review and live-system changes stay with
  the main session \ user
- after a kimi job : run its tests yourself, `bin/format-code -c`, read the
  core module, and check its claims against the real numbers

#,,,,,,,,,...,,..,,..,,.,,..,,,,,,,.,,.,.,.,,,..,,...,...,,.,,...,,,,,,,.,.,,,
#U7WMCE46SOLCICRO7NH5LNWA2YD3K232AZSHM4LTS6EYWQH3WURP6XDE2PEXI2QUIVK33SSE7NFV2
#\\\|I3OREC75RMBO3PPKEVLDA2VZDIJLYUYL564HMQ34G3S57ESVUIF \ / AMOS7 \ YOURUM ::
#\[7]L63NXTJIXFAK7CPFC7MN6NSDF5AZUW7BMZT3RTO2CQWBOGI5V6BA 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
