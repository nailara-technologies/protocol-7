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

#,,.,,.,,,..,,,..,.,.,,,,,,..,.,.,..,,,,,,.,.,..,,...,...,..,,.,.,...,..,,.,.,
#KFMPWT5LHYQ4FC3SQG5AXHWOSJFBWWLFC6X4TDRB6UICEYVG5A5GAB6ANH3HOWPETAJV2LFCBQGEQ
#\\\|4UH7AKRWLTHKP234NZWPVNR34JIRBIM4X5GQADCXMLPYYXXFMHV \ / AMOS7 \ YOURUM ::
#\[7]CTQ6GARGSAKOWM32PRTQZK7NWLBCI7CVEDF6FZDVIBN5XL66DQBQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
