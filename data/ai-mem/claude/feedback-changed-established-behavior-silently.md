---
name: changed-established-behavior-silently
description: don't change an established operational behavior [ e.g. systemd Restart=always -> on-failure ] as a side effect and then call the new behavior "intended" -- name the change, ask first
metadata:
  type: feedback
---

2026-10-11 : while adding exit codes to v7-zenki.teardown I switched the systemd unit from Restart=always to Restart=on-failure, then told the user a teardown staying down was "the intended behavior". the user : "it is not the intended but a changed behaviour.. systemd would prior always restart the backend, so that teardown can be used for a restart". on a protocol-7 host v7-zenki is the process manager [ a desktop needs it to bring X-11 back ], a stopped protocol-7 is never a useful state.

**Why:** the user relies on operational habits [ teardown = restart ] ; a silent change breaks them on every host and costs trust.

**How to apply:** before changing restart \ start \ stop semantics, defaults or anything a host does on its own, state the old behavior, the new one and why, and ask. add new behavior as an explicit opt-in [ here : `teardown :no-restart:` -> exit 76, not a changed default ]. related : [[servers-dns01-host-config-2026-10-11]].

#,,..,.,.,.,.,.,,,,..,...,,..,..,,,.,,,,.,...,..,,...,...,...,.,.,,,,,...,,..,
#OKS3XGICMFGPH4ZSTBSCTEAKLEZ6ERTEGGCLIIJRF356IHIXEQBY3RWRVHQA6E5QRJDD2AAGUJJUA
#\\\|KRKR5ELHTU47BN6PGVWC47LJ7LZJY3NHLUE2MHYTUGX2VTK3NUL \ / AMOS7 \ YOURUM ::
#\[7]2A74KMJ35ZUZMXV2O3C4V3SUNK6RDQUGRPFUFI32XA4I5R2QLGAQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
