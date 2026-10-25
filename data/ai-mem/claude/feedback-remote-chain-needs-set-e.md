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

**How to apply [ owner, the project way ] :** pull through the ext-bin
zenka `pull-git` [ remote-server profiles : exec-external
p7-git-pull--rebase as root ] and wait for it exactly :
`:: v7-zenki.start_once pull-git && :: v7-zenki.notify_offline pull-git
&& <restart>` -- notify_offline replies once the zenka has shut down. TESTED
2026-10-25 [ /bin/false vs /bin/true ext-bin entries ] : a non-zero exit
goes extbin -> error -> shutdown [ level 0 log ] but notify_offline still
answers TRUE, rc 0 -- the && chain does NOT stop on a failed pull [ only
notify_online reports 'error' ]. until notify_offline replies false after
an error exit, still check git log -1 before the restart.
otherwise : remote deploy steps run under `set -e`, the pull without
a pipe, restart only after `git log -1` shows the expected commit. check
`git status --porcelain` for untracked files the pull would overwrite
first. related : [[never-feed-command-substitution-into-destructive-cmds]].

#,,,.,.,,,.,,,,,,,...,..,,,.,,..,,.,.,,..,,..,..,,...,...,.,.,.,,,.,,,.,,,...,
#JTKRVHK2ZBEBDKV2UQ5PUFY4242WNHXAOQEX6RSTVYUOQ7CJTUD5X3W44WCXQLNYPDY66ZZH3HF46
#\\\|XLOMW5T7GXCXWPVFCVVHUMQ3ORUXGFMHCK2DLEHBIH5ZQRQ37TT \ / AMOS7 \ YOURUM ::
#\[7]6BUBYISWC2AJAFIMW6TNR6ZXLR4CSCT22KVHLVGXBHZTLW4BI6AA 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
