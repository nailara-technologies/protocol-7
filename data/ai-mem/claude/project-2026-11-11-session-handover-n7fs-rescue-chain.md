---
name: session-handover-n7fs-rescue-chain
description: 2026-11-11 handover : N7FS stages 1-5 part 1 + drain\move built and committed, first real rescue copy proven, jobsite stall fixed ; open items
metadata:
  type: project
---

START HERE for N7FS. personal setup, disk ids, hosts and rescue state are in
`~/.n/private-notes/n7fs-state.md` [ outside the repo, read it when working on
the migration ].

**built and committed 2026-11-08 .. 11 :**
- stage 1 tree manifests + categories, stage 2 incoming pool [ tag -from rules
  in one run, list -group-by name:<n> ], stage 3 one-way union sync
- stage 4 sealing : twofish-ctr inside chacha20-poly1305, per-writer nonces,
  roots as passphrase files or `vault:<name>`, `root convert` both ways, ssh
  holders [ sshd + posix tools only ], packs of small nodes [ 16 MiB ],
  `-bwlimit`, clean-machine recovery of named trees
- stage 5 : holder registry as the vault note `n7fs holders`, host-signed
  receipts from holder-check [ 7 days ], `placement` [ copies per failure
  domain ], `place` [ new domains, owned first, quota + reserve ],
  `holder-drain`, `place -exclude`, `holder-gc -only-root [ -delete ]`
- imports are linear for duplicates and write one batch record per category
- designs : N7FS-SEALED-REPLICAS, N7FS-SEALING, N7FS-PLACEMENT, N7FS-SYNC,
  N7FS-INCOMING, N7FS-TREE-CATEGORIES, WEB-UI-USER-LOGIN [ d ] + escalation

**proven live :** an import, a packed seal and a byte-identical recovery of a
named tree from only the key and an owned ssh holder.

**rules learned :** sealing over a weak wireless link at full rate took the
host down twice : use `-bwlimit` or a cable. never put the owner's setup,
layout, hosts or history in repo files [ [[no-personal-data-in-repo-tree]] ].
validate yaml after editing the todo file [ an unquoted ' : ' broke it ].
editing a file while its signature waits for approval aborts the sign run.

**open :**
- jobsite todo UFG : the drain poll timer died with no cause found [ ruled out
  in the todo ] ; jobsite.scan now resets such a cycle, the status shows it
- second root, never in the vault, before any foreign holder ; foreign holders
  by provider \\ region as failure domains
- stage 5 rest : home-signed deletes on holders the owner does not control,
  holder-to-holder relays, intake eviction ; laptops, working copies, chat log
  index [ ideas in [[vision-2026-11-09-n7fs-mapping-features-from-layout-thread]] ]
- `claude_dispatch` defaults to opus, `fable5.2` alias id unverified

continues [[n7fs-host-migration-goal]].

#,,,,,.,.,...,.,.,..,,.,.,...,,,,,..,,,,.,,,,,..,,...,..,,..,,...,,.,,,,,,,,.,
#ZISZ4SIZC6BOU6MCTEKH4I46QQOVU7ZDKEXS3CPOIZ5RLRSB5RBZQ4AL5S7INWP7MEISQ5DD3426K
#\\\|UNVEUPWDQETZZDIBSZLBCJOPVZLRHHOHB4BPDY6CXLZXKKMKJ6X \ / AMOS7 \ YOURUM ::
#\[7]2NKSBJV7PMB5KQ7UGQ3P7NKAE6WMHF3M76UCNSLX2Q2GWHAZICDI 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
