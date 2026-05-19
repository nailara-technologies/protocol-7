---
name: git-watch-zenka
description: "force-push detection and deduplicated backup — two modes, git alternates chain for zero-redundancy storage"
metadata: 
  node_type: memory
  type: project
  originSessionId: cdd64615-ffac-4aad-8bb6-53bd6445a768
---

## Two modes, one zenka

**Mode 1 — local guardian**: wraps git fetch, detects force push in incoming refs
BEFORE applying them, snapshots current state first. Uses `p7 git-watch.fetch` or
git alias `safe-fetch = "!p7 git-watch.fetch"`.

**Mode 2 — remote watcher**: polls `git ls-remote` on timer, detects force push
on watched remote repos, creates deduplicated backup clone before fetching new state.
Pure backup/redundancy, no local development work.

## Dedup mechanism

**Primary: git alternates chain**
- backup-0: full bare mirror clone
- backup-N: `git clone --bare --mirror --reference backup-(N-1)` — shares all
  objects with prior backup, pays only for unique (orphaned) objects
- Storage ≈ one full clone + all force-pushed-away commits combined

**Fallback: btrfs reflinks** — `cp --reflink=always .git/ .git-backup-<ntime>/`

**Last resort: git bundle** — `git bundle create backup.bundle --all`

## Force push detection

```perl
git merge-base --is-ancestor $old_sha $new_sha
# exit code != 0 → not ancestor → force push
```

## Backup lifecycle

Entropy transformation model applies: refcount = up_refs + directional + visual_ref.
refcount=0 → write transformation record, remove backup dir (commits still in mirror).
GC disabled in rescue backups (`gc.auto = 0`). max_backups = 13 per repo.

## Key config

```
cfg.backup_strategy = alternates  # alternates | reflink | bundle
cfg.safety_window_seconds = 300
cfg.max_backups = 13
cfg.poll_interval = 60  # mode 2
```

## Task file

`data/tasks/git-watch-zenka.md` — complete implementation spec ready for kimi dispatch.

**How to apply:** Dispatch to kimi when git backup is needed. Both modes in one zenka.
The alternates chain is the key efficiency — total storage barely exceeds one clone.

Related: [[usb-backup-zenka]] [[self-assembling-network]]

#,,..,,..,...,,..,,,,,,,.,,,,,..,,,,.,,,,,,..,..,,...,..,,.,.,,,.,,.,,.,.,.,.,
#IIQCJRZK5YUT37E7JD4OTMD2ATSZPKXSVDBKF5MFZ4XZ67WOGP2R6QNT4R67C4K3Y3U2FWZMJOWUM
#\\\|7VNQZJZ7ZN3RKNZO3OWXAGMF4UVYXV5SCRCXXTPBNZLL3SRXF36 \ / AMOS7 \ YOURUM ::
#\[7]D5ZQ7NKH2X6V47MHXK7R627EMQFVQAUQPOT7CFQUFBRX7DDCTGCI 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
