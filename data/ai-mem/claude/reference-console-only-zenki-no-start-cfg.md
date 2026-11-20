---
name: reference-console-only-zenki-no-start-cfg
description: console-only zenki [ zenka.v7 ends in console_command, no loop ] must have NO start.cfg -- its absence is the "not v7-managed" marker ; models added some by mistake
metadata:
  type: reference
---

v7-zenki only sees zenki that have a `cfg/zenki/<zenka>/start.cfg`
[ `v7-zenki.load_zenka_startup_cfgs` ]. a console-only zenka [ configure,
keys, sourcecode ; hybrid ones like user-edit \ vault-edit call
init-done:TRUE themselves ] has none, so v7-zenki cannot start it. with a
start.cfg, v7-zenki starts it with empty args, `base.call.console_command`
falls through to `commands`, it prints its command table, exits, and
restart-loops [ seen for session \ work ; their start.cfg came from models
not knowing this, removed 2026-09-30, a297b223c ].

**How to apply:** never add a start.cfg to a zenka whose zenka.v7 has no
`[zenka.loop]` \ `[init-done:TRUE]` path ; when creating a zenka, decide
managed vs console-only first. related :
data/tasks/zenka-hybrid-startup-followups.md

#,,..,.,,,.,,,,,,,,.,,.,,,,.,,.,,,.,.,,.,,,,.,..,,...,...,.,.,,.,,...,.,,,,,.,
#ABZMSJDSTDHL3HHRVFCFUVU6M5NWZCS3L5X763EZVWVTIKNUHCOQZQJ2YTSVHOXCDV3H56YN7XHCA
#\\\|TKDTQNAUFBILCFFV2OLZSNSCRLVVO5FMRMNTCLUUFJSRWMIAQPY \ / AMOS7 \ YOURUM ::
#\[7]PWPDD5ANB6HG7WL4H6LOKGOCEBUF4HFMYD5R7PRZCAY5IDR3KGDI 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
