---
name: reference-per-target-log-levels
description: base.log / base.logs accept '<console>[:<buffer>][:<logfile>]' level specs [ 177ad80ff ] -- use '2:1' to hide a line on the console but keep it in buffer + logfile, instead of plain level 2 [ which drops it from the logfile at default verbosity ]
metadata:
  type: reference
---

Since 177ad80ff [ 2026-09-24 ] the level argument of `<[base.logs]>` /
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
Per command level offsets : `log.level.cmd-offset.<cmd>` in
`cfg/logging-configuration` [ `heart = +1` moves heartbeat routing lines
to level 3 ]. `devmod.skip_v7_heartbeat` was dead [ never set ] and got
removed 2026-09-24 ; `devmod.skip_log_msg` [ p7-log append lines ] is
still in use.

#,,,,,.,.,,.,,...,,,,,.,.,,,,,,..,...,,.,,...,..,,...,...,.,,,...,.,,,,..,,.,,
#HFGTIKQQZ5ZUWWYHY4OOVXQ6AZDHMKM2AX5IRXZNW45W7JGKXA77YF6SCXIZ4V66Z4FP34KWVLBIY
#\\\|4ZKWYL3W2URYHBR6OTD7S2LLGHQ4RL4DXJ75XFOIW47MTE6NKFS \ / AMOS7 \ YOURUM ::
#\[7]HP2LCLGTLHOLWPUVC2EMI5VKKHVEMWRN2ND42YTJQLT2CVS66IDY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
