---
name: changed-established-behavior-silently
description: don't change an established operational behavior [ e.g. systemd Restart=always -> on-failure ] as a side effect and then call the new behavior "intended" -- name the change, ask first
metadata:
  type: feedback
---

2026-10-11 : while adding exit codes to v7-zenki.teardown I switched the systemd unit from Restart=always to Restart=on-failure, then told the user a teardown staying down was "the intended behavior". the user : "it is not the intended but a changed behaviour.. systemd would prior always restart the backend, so that teardown can be used for a restart". on a protocol-7 host v7-zenki is the process manager [ a desktop needs it to bring X-11 back ], a stopped protocol-7 is never a useful state.

2026-10-12, second case : the automatic `-lowram` start profile [ host.mem_mb < 3072 ] switched atom [ 964 MB ] from `remote-server` to `remote-server-lowram` after a pull. atom's deliberate local edit [ no nameserv \ web \ system ] lived in `remote-server`, so it silently started a name server on a host being retired. restored with `v7-zenki.cfg.lowram_mb = 0` in atom's /etc/protocol-7/v7-zenki/host.cfg. before an automatic selection ships : check every host for local edits of what it replaces [ `git show --stat HEAD` of each local-modifications commit ], announce the switch per host.

**Why:** the user relies on operational habits [ teardown = restart ] ; a silent change breaks them on every host and costs trust.

**How to apply:** before changing restart \ start \ stop semantics, defaults or anything a host does on its own, state the old behavior, the new one and why, and ask. add new behavior as an explicit opt-in [ here : `teardown :no-restart:` -> exit 76, not a changed default ]. related : [[servers-dns01-host-config-2026-10-11]].

#,,..,,.,,,..,.,,,,..,,,.,,,.,..,,,..,...,.,.,..,,...,...,.,.,,.,,...,..,,.,.,
#YSK645PBXFTYLW3RF54TQC4MFFS2L6H2A2X3ZBOHZPPHNHIURBJ2PJDJSVIVHAWQNZBYBU7TIXQBM
#\\\|DDKBPVPMHOC5TX4VGYIENZ4DUWENT37T54HDJF22QEFYGMRBRWO \ / AMOS7 \ YOURUM ::
#\[7]GUYCDVBBXJ7IJC5RT7SZJOMYBISXWYSWBYVHTT2OYMUWSHZZEICI 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
