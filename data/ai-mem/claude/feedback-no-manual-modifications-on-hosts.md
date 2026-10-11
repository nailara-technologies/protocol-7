---
name: no-manual-modifications-on-hosts
description: avoid manual edits on servers -- deploy code via pull-git, keep host specifics in /etc/protocol-7/<zenka>/host.cfg, automate one-time steps in code ; manual changes erode reproducibility
metadata:
  type: feedback
---

user, 2026-10-11 : "i do not want any more manual modifications where possible, as reproducibility is otherwise deteriorating..". also : private names [ the private domain, the desktop's host name ] never in the tree, commit messages or memory -- "one private domain".

**Why:** every hand edit on a host is state no repository or future N7FS set-up holds [ 4EO : nodes restored by reference ] ; local-modifications commits block clean pulls.

**How to apply:** deploy with `p7c v7-zenki.start pull-git` on the host ; when a step needs a file on a host, prefer code that creates it [ nameserv ensure-zone instead of hand-written zone files, base.load_host_config creating its dir, auto-detection writing /var state ] ; the few unavoidable host decisions go into host.cfg, nothing into the checkout. when you must ask the user for a root step, keep it to one block and say it is the last one. related : [[servers-dns01-host-config-2026-10-11]], [[keep-new-server-1]].

#,,.,,,.,,.,.,,,.,,.,,..,,.,.,.,,,,.,,..,,,.,,..,,...,...,.,.,..,,,..,.,,,.,,,
#BCYQ7OFVY3Y4SGSQMSFYMW53NRSAEXXSSJUSXASJSAG4ALVOMVCW3J2PZ2M6AMN5ZDJ5EMPHYSTMQ
#\\\|42BZTXDAL2GVSWP4FMXG52OLAX2I4BB7MV4M7CTDJMVH5R5XMYW \ / AMOS7 \ YOURUM ::
#\[7]L7AJMAAX7QHVOF3PKIYOP6XIP2ONOHBCGPJPVB7G5MZGNQYS7EBI 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
