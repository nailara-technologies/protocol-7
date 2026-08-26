---
name: feedback-p7c-command
description: always use p7c not p7 — the binary was renamed
type: feedback
originSessionId: de2c98be-b155-442a-9736-a7ad7941c3cb
---
Always use `p7c` for Protocol-7 network commands, never `p7`.

**Why:** the `p7` binary was renamed to `p7c`; `p7` now prints an error and exits.

**How to apply:** any time issuing a network command via the CLI — `p7c list users`, `p7c nodes.orbital-position`, `p7c v7.restart X`, etc.

#,,,.,.,,,,,,,..,,..,,.,.,,.,,,..,.,.,.,.,,.,,..,,...,...,,..,.,.,,,,,,.,,...,
#GLZ7BX3JLM6KB7X3445KBJZLMV7KEFIASCGZ3NP237LPV5AYUVH53MPO35EJJP7OCJMF6R52RG5K6
#\\\|LXDKASZEVV745BY223QWMK6GBMNT4CSKDMF5IC2YTO6XE7LSPDA \ / AMOS7 \ YOURUM ::
#\[7]YGSEYGVTJDULN6OJMJQ3DPP4F2SW6IKJ3GIWO4X3EHYHMB23FQAQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
