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

#,,,,,,..,,,.,,.,,..,,..,,.,.,...,.,.,.,.,.,,,..,,...,...,...,,,.,,,,,..,,,.,,
#622YHWWKMGB5VX7KGFCZ57BMHYTTPRGY6P273RDLZJYNH27IQNKB3RBJSDBYLK7PPGQGBCO4PPIIE
#\\\|2GFGTEHBJZN3AS2BHR2OCW7JD7Z3RWVM5UMQT54JRFV24XZZSZT \ / AMOS7 \ YOURUM ::
#\[7]UMYT5QWXWFCCU2I3JYB6L5FAAID47YLI4XS6FYG3FCU3AU44RWBQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
