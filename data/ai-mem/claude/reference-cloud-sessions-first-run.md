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
- open : why it got a snapshot -- check that the Claude GitHub App
  installation covers the nailara-technologies org \ this repo.
- results come back reviewed like kimi's : a worktree of the branch in
  the scratchpad, tests there [ a worktree path makes check-service's
  install-link check differ -- base fails the same way there ], then a
  squash merge into the main checkout and the owner signs.

see [[reference-usage-pools-fast-mode]] [ cloud credits, effort low by
default ].

#,,,,,,,.,,..,.,,,.,,,,,.,,.,,,.,,...,.,.,.,,,..,,...,...,...,,.,,,.,,.,.,,.,,
#JFCV242V6OTNZJTCN57WBZ7FU4KVQ5AMSQ3QYMJGWOHNLDNJ6J3KGRLF6HZRNWZCDYTRMA3AQXC2K
#\\\|BNXPWSOUBDBDIEJ362L4AJTTAAHMT362MQFTHQCTCQFRAGJIG45 \ / AMOS7 \ YOURUM ::
#\[7]FS5675VWMJ3Q2CBCSBFM3KVZIMZ2JS3LSLFAN5QEJHUUUTASACDY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
