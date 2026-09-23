---
name: reference-log-ntime-timestamp-conversion
description: zenka log lines start with a base32 ntime stamp -- convert with `p7c localtime <stamp>` / `p7c delta-time <stamp>` [ cube commands ; `::` is a p7c symlink ], don't guess or anchor on events
metadata:
  type: reference
---

Every `/var/log/protocol-7/<host>.<zenka>.zenka.log` line begins with a base32
ntime stamp [ e.g. `3XPZJS7EJSXJM4A` ]. Convert directly :

- `p7c localtime 3XPZJS7EJSXJM4A` -> `Wed Sep 23 2026 05:06:54 [ +0.58 ]`
- `p7c delta-time 3XPZJS7EJSXJM4A` -> age, e.g. `20h 34'09"`

`::` is a symlink to `/usr/local/bin/p7c`, so the user types `:: localtime ..`.
These are cube-zenka commands, not shell binaries -- `localtime` alone in bash
is "command not found".

**How to apply**: to locate an incident in a large log, convert the commit /
report time into position by sampling stamps with `p7c localtime`, rather than
anchoring on indirect events [ 2026-09-24 I wasted a round anchoring on the
first "queued behind itself" line before the user pointed this out ].
Related : [[project-coding-async-backend-acquire-reentrancy-race]].

#,,.,,,..,,.,,.,,,...,,,.,..,,..,,..,,.,,,,..,..,,...,...,..,,,.,,,,,,,,.,.,.,
#Y66KSKJKT6MWGCOKKO22WS3IRMPLB2HZB2YVREZD5M6MOGLCG6EQCILS6QWGWT5RTK2F5LVKC66D4
#\\\|73GGPSV2QHK47QHOIDZJVAYGFZXAGQ2JZXGU2NG5OK35SLCWEZ4 \ / AMOS7 \ YOURUM ::
#\[7]DLJOSEJYBUF5P5O3EKIHBZBM7NBKOFXH2RNZ5FU2HN3LIQ3IAWCQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
