# N7FS cycle timer example

This is an example only. Do not install it until the cycle config, root key,
pass-file permissions, holder paths and service account have been reviewed.
The cycle's own lock rejects overlapping runs, and its non-zero exit is the
degraded or failed signal.

Run `cycle -status` with the same `-host-dir` to inspect the last run without
opening the root key. Use `-dry-run` to evaluate the gate and print the
planned destructive steps without changing data or cycle state.

## `n7fs-cycle.service`

```ini
[Unit]
Description=N7FS additive and gated destructive cycle

[Service]
Type=oneshot
User=n7fs
ExecStart=/usr/bin/perl /path/to/protocol-7/bin/n7fs -host-dir /path/to/n7fs-host cycle service
```

## `n7fs-cycle.timer`

```ini
[Unit]
Description=Run the N7FS cycle about every 1Y4

[Timer]
OnBootSec=5min
OnUnitActiveSec=18min
AccuracySec=1s
RandomizedDelaySec=78
Persistent=true

[Install]
WantedBy=timers.target
```

`OnUnitActiveSec=18min` approximates `1Y4`. The service must not be started
manually while another cycle is running; the cycle lock is the final guard.
The example is deliberately not installed or enabled by the repository.

#,,,.,.,,,..,,...,...,..,,,..,.,,,,..,,.,,...,..,,...,...,,,,,,..,,..,...,,.,,
#B257KJGE6KTMNU75MYLTXUURM6OHCW2QQEWJFJVLV7EVLUIZAPW5HEVECVPDM2QA5TT2D4XAIBR7K
#\\\|KTORCLOTELPH43VIC75YKPW5JJUASTBVSMMKF72DKTQPG6GBCWV \ / AMOS7 \ YOURUM ::
#\[7]RB3GOGTCZEYII757IH7S5FWZCTFTIJ26OVNUB4UGXFZ6GX6A7IDY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
