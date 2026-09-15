---
name: reference-ntime-x4200-and-cube-cross-zenka-access
description: base.ntime is scaled x4200 (network time, not unix seconds) — never use it for real-second TTL/age math; and cross-zenka commands need a cube-side access.cmd.usr.<zenka> grant, live-applied via 'p7c reload config'
metadata:
  type: reference
---

Two gotchas hit while fixing the coding zenka's check_account_usage roundtrip, 2026-09-15.

## base.ntime is NOT unix time

`<[base.ntime]>` = `(unix_seconds - 1023228000) * 4200` (core `p7_ntime` in bin/Protocol-7,
"secs from 2002-06-05 * 4200"). It ticks 4200x faster than real time. Any TTL, age, or
throttle math meant in real seconds must use `<[base.time]>->(3)` (unix + ms precision,
the coding zenka's idiom) — comparing an ntime delta against `300` gives an effective TTL
of 0.07 real seconds (cache never fresh, refresh fired per call). Symptom seen: "age"
jumping ~100000 per minute and always "stale".

## cross-zenka commands need a CUBE-side grant

When zenka A sends `<zenka>.<cmd>` (e.g. coding -> `usage.status` via
`protocol-7.route-send`), the CUBE process checks ITS OWN access map BEFORE routing:
cfg/zenki/cube/access.zenki, block `access.cmd.usr.<requesting-user> = ...`. Denial logs
as `cube: [N] no perm. [ src '<user>' cmd|usr '<full.cmd.name>' ]` — logged by cube, so
it appears in the net console (NIW7OAQ) even when the target zenka never sees the request.
Deliveries that pass arrive at the target as user 'cube' with the zenka prefix stripped
— which is why target zenka configs grant `access.cmd.usr.cube` with SHORT command names.

Fix pattern: add the full prefixed name (`usage.status`) to the requester's block in
cfg/zenki/cube/access.zenki, then apply live WITHOUT restarting the root-owned net
process: `p7c reload config` (base.cmd.reload re-runs base.parser.access_conf).
The per-target-zenka `access.cmd.usr` list in its own zenka.v7 is the SECOND gate and
was not the issue here.

Verified end-to-end 2026-09-15: coding.call-tool check_account_usage returns real
claude/kimi numbers, TTL-fresh for 300s, on-demand usage zenka starts on first request.
Note: reload preserves runtime %data — a change of time SCALE in a stored timestamp
survives `reload source` and can read as nonsense; `v7-zenki.restart <zenka>` clears it.

#,,.,,,..,...,,,,,,.,,,.,,,,,,..,,,,,,,,,,,..,..,,...,..,,,..,,,.,,,,,,.,,.,,,
#7JUCRXE6XHT3AXTPWWSPEVYMV3MTSMQGGHXWXO4PNQJEZQD563PU5T7VUG4CUX6G3DKJT4N2TFHRS
#\\\|P7BPMB4B2U46ONUFAYEY6EY2CFABPA6WL63ZCXII4J3FRKUKCOG \ / AMOS7 \ YOURUM ::
#\[7]XQQW6EKFKCNNLBHI7UDDWQ6MDWOZFBT5CYNYUETZN2SJKKYS7YCQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
