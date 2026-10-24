---
name: project-2026-10-24-delta-link-managed
description: 2026-10-24 : pri -> delta fetch link is now a SUPERVISED link [ host record + ssh-w ], the by-hand tunnel is gone ; jobsite fetched stream recovers from a dropped link [ 7390c154d ] ; where the non-repo pieces live
metadata:
  type: project
---

supersedes the 'link is BY HAND' line of [[project-2026-10-22-session-handover-remote-fetch-link]].

## what happened
pri's external restarted ~2026-10-23 18:40 ; the by-hand `external.connect`
session died with it [ the `-L 4243` tunnel kept running ] -> every
`site-yaml.import` = 'client not present' for ~10 h, jobsite.status still
read 'idle'.

## the managed link [ live, tested : external restart + ssh child kill -> up in ~2 s ]
- record : pri `/var/protocol-7/host-edit/hosts/delta.json` [ root:protocol-7
  0640, dirs 02750 -- written by hand as root, host-edit as another user
  cannot rewrite it ] : addresses delta.protocol-7.network:42, ssh
  protocol-7@delta.protocol-7.network, ssh_port 22, transports ssh-w, af 4,
  link_user remote-fetch, roles link fetch, pin_from 127.0.0.1_4243
- pin moved once -> `~protocol-7/.n/remote-keys/servers/delta_42.public`
- `~protocol-7/.ssh/config` on pri : Host delta.protocol-7.network ->
  IdentityFile ~/.ssh/id_ed25519_link + IdentitiesOnly [ ssh-w has no
  identity field ; the link key is not a default identity ]
- the old `ssh -L 127.0.0.1:4243` tunnel is killed -- never redo it
- external is always-on [ start-set-up.base ] : a restart reopens the link

## jobsite [ 7390c154d, deployed pri ]
a dropped link answers the open subscribe-fetched with FALSE 'command
route collapsed', never an eof : 'subscribed' stayed set, the delta outbox
never drained [ 465 held ]. now refusal \ 90 s unanswered \ not routed ->
retry 30..300 s, subscribed self-checks against <base.strm.local>.
jobsite.status : fetch via \ stream \ last fetch [ 'N of N imports FAILED' ].
same refusal reset in models.handler.task-stream.

gotcha : `reload source` does NOT re-run init_code -- the stuck state
needed `jobsite.reload init` [ then 1687 -> 1743 jobs ].

## encoding [ 8b2384420 ]
backlog-delivered jobs arrived double-encoded [ DÃ¼sseldorf ] : the site-yaml
outbox wrote encode_json octets through the default UTF-8 layer. outbox
write \ backlog read now :raw ; 58 jobs repaired on pri [ backup
repair-encoding/backup-32E6H2E6ACCKWNQ.tar.xz ] ; 2 trash reasons [ SIZN2,
ACU54 ] keep model-echoed mojibake. rule : [[zenka-open-default-utf8-layer]].

open : the mid-stream drop recovery [ stream OPEN when the link drops ] is
not live-tested yet -- the cycle was assessing ; check the next scan's log
for refused -> 'next subscribe in 30 s' -> consumer registered.

#,,,.,..,,,,,,..,,,.,,.,.,...,,,,,,..,...,,,.,..,,...,...,,,.,,.,,...,,,,,,,.,
#7LPPO2R55X3MVTICDWBEVLAJVGCVFUYXMMXN3D6B725PALI3EFQL53X7FYPEQOJK74HVXKXPHZB42
#\\\|PKTYWPOP4RTE2VRUH6BHHYYMJXBFH2RPXEC5DQAADDSCP3RZRNZ \ / AMOS7 \ YOURUM ::
#\[7]UYSFAWWCVO3VCJUVI2YMSGJS4ORPVGBCUOKAOV4J4MBGZLI7PEDQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
