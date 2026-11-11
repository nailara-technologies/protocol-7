---
name: n7fs-relay-fanout-filters
description: 2026-11-11 : N7FS stage 6 landed [ relay, push fan-out, holder filters ] ; owner's hub topology, next steps
metadata:
  type: project
---

landed on base 2026-11-11 [ design : data/md/design/N7FS-INTAKE.md, N7FS-PLACEMENT.md ] :
- aaba12c7d `n7fs relay <from> <to>` [ blind copy via home + adopt ] ; receipts now count ONLY for the head version they checked [ any commit -> holder-check again ] ; intake drain counts its own domain
- 394beb78d fan-out : `relay -list` \ `bin/n7fs-push` on the hub [ no key ] \ `bin/n7fs-receive` forced command \ `relay -adopt` ; gc keeps pending
- e953c7343 `holder add -categories <a,b> -min-priority <n>`

owner topology [ names stay in the vault registry, never the repo ] :
- the biggest server = hub, durable ; its neighbour = second full copy + backup hub. both unlimited traffic, SAME failure domain [ count as one copy ]
- three small servers with ~2TB traffic \ month, own locations = the off-site copies : quota + filters ; one older 1TB host retires [ drain it, never a receiver ]

**Why:** home uploads once ; the off-site copy counts only on the small servers.
**How to apply:** next = live deploy [ owner sets keys \ authorized_keys \ ssh aliases ], first one small round, holder-check every live holder after the receipt change, decide default target 1 vs 2. untested : n7fs-receive under a real sshd. [[n7fs-host-migration-goal]]

#,,.,,,.,,...,,,.,..,,,..,.,,,.,.,.,.,,,.,.,,,..,,...,...,.,,,,,,,,,,,.,.,,,,,
#UY4YGQHOKLXN4EMVGL2RJUDGJLCW6R2RPXHWOVVIHNMXDDHTPIAHT7GHU322ZYO6T6EX5VN4CPI5Q
#\\\|RMZX34GO5TVCZAYLUS5FFKJQVOP3M3WMTPX32HMJ56YYCXJLEFT \ / AMOS7 \ YOURUM ::
#\[7]7PLBQTUG2RLATQGZVTVUAT6V6K2YB4LQJSLQ2C5YYEAC7HZFBEDI 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
