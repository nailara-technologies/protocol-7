---
name: ext-bundle-backup-alias
description: "gbc bash alias creates+verifies the ext-bundle git backup of protocol-7's base branch"
metadata:
  type: reference
---

`gbc` (in `~/.bashrc`) runs:
`git bundle create /mnt/ext-xfs-data/repository/bundle.protocol-7.base base && git bundle verify /mnt/ext-xfs-data/repository/bundle.protocol-7.base`

Added 2026-08-09 after a `work purge-paths` history rewrite ([[topic-protocol-7-menu-dialog-plugin-system]]-adjacent session landing all three `CODING-ZENKA-USER-INTERACTION-SURFACES.md` branches) required regenerating the bundle by hand since a force-push changes every commit hash. User said they'll likely run ext backups much more often now that the alias exists.

**How to apply:** the `ext-bundle` git remote (alongside `hub` = GitHub, `session-work` = local tmp) is a `.bundle` **file**, not a normal remote — bundles are read-only snapshots, `git push` to it always fails (`error: failed to push some refs`, not a real problem). To refresh it, either tell the user to run `gbc`, or run the two-command sequence directly (`git bundle create <path> base && git bundle verify <path>`) — don't waste a turn diagnosing the push failure as a bug.

#,,,,,.,,,,,.,.,.,.,.,,,.,.,,,...,..,,.,.,.,,,..,,...,...,...,,..,.,,,..,,...,
#YT4H22MPRLP6TROJIK3W5H4XNTIIDCDXGZB5NN5ISDSTAOVKWKINHY37WE6OAK2L2KDP2OIKMXPQI
#\\\|AOPF6WSFF4KRAX7GKH5PH3G2QUVKDR6MXGTPHKO3SXW2S6RU74J \ / AMOS7 \ YOURUM ::
#\[7]3LH563KULWL6JC2L6T6ZJWEAOXTKSSRQOHWUZXRABDPKCBQJXQDA 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
