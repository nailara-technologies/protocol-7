---
name: project-2026-10-22-shm-permissions-forgeable-open
description: grants fixed 2026-11-05 [ d02c3b067 ] ; open, normal [ todo FKS ] : a local reader with file rights can still map a segment
metadata:
  type: project
---

data/lib-path/pm/AMOS7/SHM.pm sign_permission [ ~439 ] : 31-multiplier polynomial hash of the canonical
permission string x key length -- no private key involved. used by data.mount.shm.permission.* via
data.mount.shm.open. bounded only by the unix rights on the segment ; must not be treated as authority.

fix direction [ todo FKS, data/yaml/todo/base.yaml ] : SIGNED-STATEMENTS.md 'p7 capability v1' +
'p7 shm permissions v1' [ header carries one statement id ], adoption step 7. until then : a real Ed25519
signature over the canonical string, or refuse header permissions as authority. found 2026-10-22,
still open 2026-11-05 [ owner : not closed, high prio ].

2026-11-05 step A landed [ d02c3b067 ] : the hash is replaced by real ed25519 grants. still open : a local reader
with file rights can map the segment -- encrypted pages close that, see [[project-2026-11-05-session-handover-shm-a]].

#,,,.,..,,.,,,.,.,.,.,..,,...,..,,,..,.,,,.,.,..,,...,...,..,,.,,,,,.,.,,,.,,,
#AB3DP35KNHVV7GBNPA5SIAC22B6GTZWN2JFGFQLKDIMW7BRJ7SOAZLQKG5AEMSOWVULCJP24VEANE
#\\\|MT6VCODREYDRQBPIB4PGFHA3R3FLPEPBA7YRZK527UMZDLW27IJ \ / AMOS7 \ YOURUM ::
#\[7]CFOI7TUEC6FGDFOETAOCIO3DY5CZUP4JELR6OTBONE77Y6CRCKBY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
