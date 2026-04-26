---
name: feedback-p7c-command
description: always use p7c not p7 — the binary was renamed
type: feedback
originSessionId: de2c98be-b155-442a-9736-a7ad7941c3cb
---
Always use `p7c` for Protocol-7 network commands, never `p7`.

**Why:** the `p7` binary was renamed to `p7c`; `p7` now prints an error and exits.

**How to apply:** any time issuing a network command via the CLI — `p7c list users`, `p7c nodes.orbital-position`, `p7c v7.restart X`, etc.

#,,,.,,.,,,,.,..,,.,,,,,,,,,,,.,,,,..,,,.,,..,..,,...,...,,..,.,,,.,,,.,,,...,
#35SXSV5Q3VE4W3QB6ZK7G5ZJGM6MIMKHFV34LFP4S4TEZOWSSUBA36X4OR6RADFCGOO3X3KROLSKY
#\\\|YU6PCLCHE3HDN4G6S34OEII7F4JIRXQVOCGGIVCNEFZVRV4VRC7 \ / AMOS7 \ YOURUM ::
#\[7]AGX4C2GNCD3FYCVQ2SHSAXRIRAKGNC7TEQLWROOAIETZ6HCSQQAQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
