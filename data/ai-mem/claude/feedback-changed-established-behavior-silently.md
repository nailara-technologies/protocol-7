---
name: changed-established-behavior-silently
description: don't change an established operational behavior [ e.g. systemd Restart=always -> on-failure ] as a side effect and then call the new behavior "intended" -- name the change, ask first
metadata:
  type: feedback
---

2026-10-11 : while adding exit codes to v7-zenki.teardown I switched the systemd unit from Restart=always to Restart=on-failure, then told the user a teardown staying down was "the intended behavior". the user : "it is not the intended but a changed behaviour.. systemd would prior always restart the backend, so that teardown can be used for a restart". on a protocol-7 host v7-zenki is the process manager [ a desktop needs it to bring X-11 back ], a stopped protocol-7 is never a useful state.

2026-10-12, second case : the automatic `-lowram` start profile [ host.mem_mb < 3072 ] switched srv-F [ 964 MB ] from `remote-server` to `remote-server-lowram` after a pull. srv-F's deliberate local edit [ no nameserv \ web \ system ] lived in `remote-server`, so it silently started a name server on a host being retired. restored with `v7-zenki.cfg.lowram_mb = 0` in srv-F's /etc/protocol-7/v7-zenki/host.cfg. before an automatic selection ships : check every host for local edits of what it replaces [ `git show --stat HEAD` of each local-modifications commit ], announce the switch per host.

**Why:** the user relies on operational habits [ teardown = restart ] ; a silent change breaks them on every host and costs trust.

**How to apply:** before changing restart \ start \ stop semantics, defaults or anything a host does on its own, state the old behavior, the new one and why, and ask. add new behavior as an explicit opt-in [ here : `teardown :no-restart:` -> exit 76, not a changed default ]. related : [[servers-dns01-host-config-2026-10-11]].

#,,..,.,.,,..,,,.,,,,,,..,,,.,,,.,,,,,,,,,.,.,..,,...,...,,..,..,,,,,,,,.,.,.,
#OLYAM3XXYX33SQQ2PLCZC5Q2FNYEPMSRINLG4AFE5RQ4FUOS6QA6IPTBT4QAM5BMXJA7JASRAR2MG
#\\\|M5YLUKZ4MBSU7M3FBKEWI646SDJ3QL5A3LQ5CABB6ATRQBJX27G \ / AMOS7 \ YOURUM ::
#\[7]ON5NPNLMIXAKW37QVFBANYUH5ALX6JXP2L4NJDOGMPY7UFI33AAY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
