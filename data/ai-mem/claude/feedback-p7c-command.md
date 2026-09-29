---
name: feedback-p7c-command
description: always use p7c not p7 — the binary was renamed
type: feedback
originSessionId: de2c98be-b155-442a-9736-a7ad7941c3cb
---
Always use `p7c` for Protocol-7 network commands, never `p7`.

**Why:** the `p7` binary was renamed to `p7c`; `p7` now prints an error and exits.

**How to apply:** any time issuing a network command via the CLI — `p7c list users`, `p7c nodes.orbital-position`, `p7c v7-zenki.restart X`, etc.

#,,,,,..,,...,,.,,.,.,,..,,,.,.,,,,.,,,,.,,,,,..,,...,..,,.,.,..,,,,.,...,...,
#QPGAJQEZKB2ONBLXDL7MDJGIC36KXNNJF4ZTMB3I6UDNIIHSPAE4XC7ME4YPRT5WFZH54UTWQ6N5G
#\\\|2MNZDPFKNUXL5IUKU7S36WAVQANIIRXJU64I676FIJ4JGTYEWOW \ / AMOS7 \ YOURUM ::
#\[7]IRBAP6G6UF62DDFNVVYOP755Q5QBEG24VKHPMV2UDY74WVPSDOBA 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
