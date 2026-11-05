---
name: project-2026-10-22-shm-permissions-forgeable-open
description: OPEN, high [ todo FKS ] : AMOS7::SHM::sign_permission is a computable hash, not a signature -- shm mapping permissions forgeable by any header writer
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

#,,,,,..,,,.,,..,,,..,.,.,,..,..,,,,.,,,,,...,..,,...,.,,,.,,,,.,,.,.,..,,,,.,
#4ZWZSCXR3B6XDTBBDK6PCSSNO37B3VGGCEXJ5LMXXRET4HNYZBKW2ZH7D4JKUPBP7DQPZNNL73J4E
#\\\|MAZMBJL4GSJ7KR2O55MF4SQA6KWXAXVM62NZGA4MFCXFM6YTDTI \ / AMOS7 \ YOURUM ::
#\[7]LJQEXBRN5NYLIACSHCNWXR2ADJWHWUAAXXRFU4IRUQIVNVKKUUBA 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
