---
name: no-manual-modifications-on-hosts
description: avoid manual edits on servers -- deploy code via pull-git, keep host specifics in /etc/protocol-7/<zenka>/host.cfg, automate one-time steps in code ; manual changes erode reproducibility
metadata:
  type: feedback
---

user, 2026-10-11 : "i do not want any more manual modifications where possible, as reproducibility is otherwise deteriorating..". also : private names [ the private domain, the desktop's host name ] never in the tree, commit messages or memory -- "one private domain".

**Why:** every hand edit on a host is state no repository or future N7FS set-up holds [ 4EO : nodes restored by reference ] ; local-modifications commits block clean pulls.

**How to apply:** deploy with `p7c v7-zenki.start pull-git` on the host ; when a step needs a file on a host, prefer code that creates it [ nameserv ensure-zone instead of hand-written zone files, base.load_host_config creating its dir, auto-detection writing /var state ] ; the few unavoidable host decisions go into host.cfg, nothing into the checkout. when you must ask the user for a root step, keep it to one block and say it is the last one. related : [[servers-dns01-host-config-2026-10-11]], [[keep-new-server-1]].


**Updating a host's checkout : `p7c v7-zenki.start pull-git`, never a
plain `git pull` [ 2026-10-18 ].** the pull-git set-up runs
bin/admin/p7-git-pull--rebase as root : fetch, clears untracked files the
incoming commits start tracking with the same content, `pull --rebase`,
then bin/admin/restore-p7-permissions. a manual pull skips the last two
steps. done wrong once on srv-U, then repaired by running pull-git.

#,,,.,...,.,,,..,,.,.,,.,,,,.,.,.,...,,,.,,,.,..,,...,...,.,.,.,.,..,,,..,,.,,
#HVS4R26BEUAMGGO47E2KT2JC2HJ3CD47IJ3TI5LVBME64SNGRULER44HYJIU3ZR4ELFAKLQSZA3YO
#\\\|ZPAFITSUJXVY6BLBAL4K6XOQ3JE5EBI75DMTD4FNKP27NYC3G6Q \ / AMOS7 \ YOURUM ::
#\[7]UV46YNLKL3EIGKQOQNHHMZ2AQAAMVGLTTCJGW2T4FWCTBYFGWSAY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
