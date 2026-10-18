---
name: reference-cloud-sessions-first-run
description: what the first real claude --cloud runs taught [ 2026-10-16 ] : --cloud needs a terminal [ claude_cloud_dispatch uses script ], agents \ logs only see LOCAL sessions, a session can start on a history-less snapshot without a remote -- it must prove its push path [ remote with write access, real history, empty dev/<topic> pushed ] BEFORE any work ; results arrive only as a pushed branch
metadata:
  type: reference
---

first real runs through bin/mcp-server-p7 [ claude_cloud_dispatch ] :

- `claude --cloud "<task>"` refuses without a terminal [ 'Error: --cloud
  requires an interactive terminal' -- piped stdout counts as
  non-interactive ; refused BEFORE a session exists, nothing billed ]. the
  tool runs it inside `script -q -e -c '..' /dev/null` [ bsdutils ]. the
  local claude prints 'Created cloud session: <title>' \ 'View: <url>' \
  'Resume with: claude --teleport <id>' and EXITS -- it does not stay
  attached.
- `claude agents --json` \ `claude logs` only know LOCAL background
  sessions -- never a cloud one. a cloud session is followed in the web ui
  [ its url ], taken over with `claude --teleport <id>` [ clean tree, real
  terminal : manual ], and its RESULT is only what it pushed :
  claude_cloud_result [ git fetch + log \ diff --stat, read-only ].
- the installer session [ session_018fjDZetZXhjdXJ6ecCrmzt, effort high,
  ~$6 of the cloud credits ] started on a single 'seed' snapshot commit
  WITHOUT a remote [ the docs' upload fallback : repo > 100 MB or not
  cloned from github ]. it noticed and worked anyway ; only at the end,
  told by the user, it attached the repo with write access, rebased onto
  real base and pushed dev/p7-install-frame-helpers. the preamble now
  orders : `git remote -v` -> attach the github repo with write access if
  missing -> fetch, confirm the start commit is in the history [ stop on
  a snapshot ] -> create dev/<topic> and push it EMPTY -> only then work ;
  push only to dev/<topic>.
- the user's rule : cloud sessions push to 'dev/<topic>' branches.
- WHY the snapshot : the cli decides clone vs upload by `git remote
  get-url origin` [ found in its own bundle ] ; this checkout has no
  origin ON PURPOSE [ owner : never add one ]. fix : claude_cloud_dispatch
  starts claude from a blobless LAUNCH CLONE [ data/state/cloud-launch/
  protocol-7, origin = the hub url, HEAD = the dispatched commit, sparse
  CLAUDE.md-only worktree ; PROTOCOL_7_MCP_CLOUD_LAUNCH_DIR moves it ].
  verified on the second session : real history, empty dev/ branch
  pushed before any work. the Claude GitHub App covers protocol-7 and
  workspace-transfer [ not DATA yet ].
- ONE-TIME per launch dir : claude shows a workspace trust dialog [ the
  pty makes it interactive ; with stdin /dev/null it waits forever ] --
  the owner ran `claude` there once : trust YES, the project mcp server
  NO [ the launch claude only creates the session ].
- cost : ~$6 per session for both runs [ installer at effort high, the
  p7-deps restyle at medium ] -- with a test requirement the session sets
  its own depth, the effort level barely changed the total.
  third run [ root runner, effort high, 2026-10-17 ] : ~$7 -- two advisor
  calls, a Digest::BMW build for bin/ncode, tracing the zenka user set-up.
  credits after it : $67 of $100 [ expire 2026-11-05 ].
- fourth run [ 2026-10-18, N7FS version 1, medium effort ] : ~$9 [ $67 -> $58 ]. 13 new files, 164 checks, 15 mutations, an offline amos collision search ; it pushed to the named branch dev/n7fs-v1 as briefed. its tests passed only on the pure-perl truth path [ no Inline::C in the cloud ] -- review here caught it.
  effort rule [ 2026-10-17 ] : send MEDIUM by default, HIGH only for
  security-critical work [ root, auth, crypto ] -- so far high \ medium
  cost about the same, keep comparing. the closing "burns fastest --
  medium handles most tasks" line is the cli's generic /effort text.
- results come back reviewed like kimi's : a worktree of the branch in
  the scratchpad, tests there [ a worktree path makes check-service's
  install-link check differ -- base fails the same way there ], then a
  squash merge into the main checkout and the owner signs.

see [[reference-usage-pools-fast-mode]] [ cloud credits, effort low by
default ].

#,,.,,.,,,...,...,,,,,,..,.,,,...,,,.,,,,,,.,,..,,...,...,.,.,...,..,,...,,,,,
#ETRLZ7QTR42D26CRZ6VN23V7CQQS6LHO2SBQSUM3252T776GQ2NM3BBJ6D65R3X5NBCZ63E4RPGLK
#\\\|SP3IKSDHV3ZS2D2C6ZWUPQTWPCNWMYOPUNCVKTMRWNODZ62HYSH \ / AMOS7 \ YOURUM ::
#\[7]KCUWRUGSHTC5RFZ7OWEDC4TSAUCRH3U53N6YSLOFR67VOL3JD6CI 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
