---
name: feedback-remote-chain-needs-set-e
description: a remote 'git pull ... ; restart' chain without set -e restarted srv-U on the OLD code when the pull aborted [ an untracked file the commit now tracks ] -- deploy chains gate the restart on the pull
metadata:
  type: feedback
---

2026-10-24 : `cd tree && git pull ... | tail -2; ...; systemctl restart
Protocol-7` on srv-U. the pull aborted [ an untracked runtime marker,
cfg/zenki/jobsite/deps/src-used/clients.https, was committed meanwhile ],
the `| tail` and `;` hid the failure, Protocol-7 restarted on the old
commit. harmless only because the old overlay files were still in place.

**Why:** a restart on the wrong code during a migration can leave a host
without its config [ the new code ignores the old files ] -- silent.

**How to apply [ the project way, 08ab710b8 ] :** one line per host :
`:: v7-zenki.start_once :wait-down: pull-git && <restart>` -- pull-git is
the ext-bin zenka of the remote-server profiles [ p7-git-pull--rebase as
root ] ; :wait-down: registers the waiter first and replies when it ended :
TRUE on a clean end, FALSE + 'exit : N' on an error end -> rc != 0 stops
the chain [ tested : /bin/false rc 1, /bin/true rc 0, live on srv-F ].
:wait-up: replies when a startup completed or failed. the old two-call
form 'start_once ; notify_offline' races a fast ext-bin -- do not use it.
notify_offline \ notify_online stay observers : no start option on a
read-only command [ httpd holds notify_offline ]. related :
[[never-feed-command-substitution-into-destructive-cmds]].

#,,,,,,,.,,,,,..,,.,,,.,,,...,..,,,,,,,,.,..,,..,,...,..,,...,..,,,..,,,.,,,,,
#JIPPC5ABPEBT4ETUJPMQP6LT6KUAJRVDHKGXBECASH7D2WLTASPPYPZ5BLHJF5JN6QYJ2XGNWWMR2
#\\\|IAEI4AXIGMQE24TMQBUV7P3RCIAVQN522ZRHJFZTSB2QDFKQT3K \ / AMOS7 \ YOURUM ::
#\[7]DI3GPR72EBJBAERXWQTPUVC4EOULT5OPD6UFMAZEMCGZJHANEQAA 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
