---
name: feedback-no-sudo-privileged-fs-ops
description: "don't use sudo to chown/rm files owned by the protocol-7 zenka user — hand the exact command to the user, they run it themselves"
metadata: 
  node_type: memory
  type: feedback
  originSessionId: 8b3d1d3e-61f9-4577-a09f-fe20af9cd9b5
---

When a file/directory is owned by `protocol-7` (or another zenka user) and I hit
`Permission denied` trying to fix ownership, chmod, or delete it, do not reach for `sudo`.
This has come up repeatedly across sessions (jobsite var-dir ownership, web-cache duplicate
cleanup 2026-07-01).

**Why**: the user has explicitly rejected a `sudo -n chown ...` tool call outright via the
harness ("The user doesn't want to proceed with this tool use"), and separately declined
granting sudo for a similar fix in an earlier session. The user prefers to run these
privileged operations themselves — often via the normal zenka lifecycle (e.g. a full restart
that runs the cold-start privileged init path as root) rather than an ad-hoc `chown`/`rm`.

**How to apply**: when blocked by a permission error on a `protocol-7`-owned path, print the
exact command (or a short list of them) and ask the user to run it, rather than attempting
`sudo` myself. This has worked cleanly every time — the user runs it in seconds and confirms
back. Don't try to route around it via a different privileged mechanism either; just hand off
the command.

**Also for dispatched agents [ 2026-09-29 ]** : a kimi dispatch [ `-y`, no
harness gate ] ran `sudo -u protocol-7 test -d ..` to check path access as the
zenka user -- the password prompt landed on the user's terminal and blocked it
until the dispatch was killed. every dispatch prompt that may touch
permissions or other users' paths must say explicitly : no `sudo`, `runuser`,
`setpriv` or `su` -- report the question instead. checking what another user
can see is done by reading modes \ owners [ `ls -ld` along the path ], not by
becoming that user.

**the approved way to test AS the zenka user** [ user suggestion, verified
2026-09-29 ] : load devmod into that zenka, then eval inside its process --
its real uid and permissions, no sudo :

    p7c v7-zenki.devmod-enable models
    p7c models.eval-code 'return join " ", "uid=$<",
        ( -r "<path>" ? "readable" : "NOT readable [$!]" );'

[ answered uid=777, models dir visible, invokeai db `Permission denied` ].
give dispatched agents this recipe instead of any privilege switch.

#,,,.,,,,,.,.,,.,,.,,,,..,,,,,,,.,...,.,.,,,,,..,,...,...,,,,,..,,,..,...,,..,
#M2K7TOTST7OJ7YMWH7RP3TKTPHTAYNTTLQVZH4JBM4DKFKO24CZSYD5XMWBPGAOBDPQ66KARG6NEC
#\\\|XPG2564VPEDH2W3DGYS5PWLPC4367XCP3C7WQGX2UEDFLEC326L \ / AMOS7 \ YOURUM ::
#\[7]6RVIRUDKKQCB3K6EUIBQACOXAJCAXPLNQV26GE26BP4MJJUB2QCI 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
