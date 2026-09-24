---
name: reference-per-target-log-levels
description: base.log / base.logs accept '<console>[:<buffer>][:<logfile>]' level specs [ 3ef566b27 ] -- use '2:1' to hide a line on the console but keep it in buffer + logfile, instead of plain level 2 [ which drops it from the logfile at default verbosity ]
metadata:
  type: reference
---

Since 3ef566b27 [ 2026-09-24 ] the level argument of `<[base.logs]>` /
`<[base.log]>` may be :

- `1` -- plain digit, same level everywhere [ unchanged behaviour ]
- `'2:1'` -- console 2, buffer + logfile 1
- `'2:1:0'` -- console / buffer / logfile separately

Missing parts inherit from the previous one. Separator is `:` -- not `/`
[ project avoids slashes ] and not `.` [ '2.1' would silently pass as a
number in level arithmetic like `2 + $llvl_offs` ].

**Why it matters:** zenka logfile verbosity is usually 1, so plain level 2
lines never reach `/var/log/protocol-7/*.log` -- demoting a line to 2 to
quiet the console silently loses it from the files too.

**How to apply:** for routine-but-worth-keeping lines [ lock handoffs,
connection record ] use `'2:1'` ; plain `2` only for real debug detail.
In use : coding lock lines, cube `session authorized` / `disconnected`.
Old alternative still in the code : devmod skip flags for heartbeat /
network lines [ `devmod.skip_v7_heartbeat`, `devmod.skip_log_msg` in
base.protocol-7.command.send.local ] -- candidates to convert.

#,,,.,,..,..,,,,,,,,.,.,,,,,.,..,,,,.,,,.,.,,,..,,...,...,...,,.,,.,.,,,,,..,,
#C4GSOPVH7AIARWOM6BBF23IOKNJAKWF7RKEVF6WVGMJBGQZDF3X5D3JYU6EU7J7YER5BK4AIQEUQ6
#\\\|U43BVWUHLLLIJUU4HIBO23FA3PADQGZ3VPJMLTZM2YG7J3NCITP \ / AMOS7 \ YOURUM ::
#\[7]FIRGJGL7JDRC2MACZWRJCWJK5HWMQ3FDR2MT6MS2CZZWMJ6PKYBY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
