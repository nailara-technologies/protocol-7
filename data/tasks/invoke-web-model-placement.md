# invoke-web : model placement by use [ local for the used, archive for the rest ]

status : IDEA 2026-11-28 -- owner : automate it later, moving included. nothing built.

## why

v7's model list [ 208 entries, ~/.invokeai-v7/models links + /mnt/ext-xfs-data/models-invoke ]
mixes models used every day with ones never touched. the external disk is usb : a used model
there costs load time [ render-stats readGB \ MB/s ]. the native linux move [ more ram, local
disk ] is the moment to place them : used ones local, the rest on the archive disk.

## shape

- usage from evidence, not guesses : render-stats [ model per render ], the queue history
  [ session_queue graphs : main model, encoder, vae, lora selectors ], v7's own model
  last-used fields if present. a model's score = renders using it in the last n days.
- `invoke-web.models-usage [ days=<n> ]` : one row per model -- name, type, size, location
  [ local \ archive ], renders, last used. read-only.
- `invoke-web.models-place [ keep-local=<n days> ] [ :dry-run: ]` : moves used models to the
  local model dir and unused ones to the archive dir, then PATCHes the entry's path
  [ PATCH /api/v2/models/i/<key> keeps id, hash, lora assignments ]. NEVER DELETE a model
  entry : invoke.ai deletes its files [ and the linked dirs point into other installs ].
- moving safely : copy, verify [ size + bmw checksum, never sha ], patch the path, only then
  remove the source. never while the model is loaded \ a render runs [ check the queue,
  hold the gpu lease or pause ].
- space check before a move [ free space on the target, a margin ].

## open [ owner ]

- the local model dir on the native host [ path ], the archive dir [ stays
  /mnt/ext-xfs-data/models-invoke ? ]
- thresholds : how many days without use make a model 'archive'
- the linked dirs into ~/.invokeai and ~/.invokeai-qwen21 : once v7 is the only install,
  move their used models into v7's own dir and drop the links

## rules for the implementer

no sha, no json internally ; lowercase comments with [ ] brackets ; perl floor 5.32 ; plain
bin/format-code formats, -c checks [ read the whole output ] ; new commands need their zenka.v7
list, whitelist and access entries ; no commit, no sign, no reload ; never touch files you did
not change.

#,,..,,,,,,.,,..,,,,,,..,,,..,,,.,.,,,,.,,,.,,..,,...,...,,,.,..,,...,.,,,..,,
#HSGFW6GIAQX3TSM4QHR2T6OD523MXEBB52ORXUDBCADNCCPVC24STJSIX7XIHGBSJ62XFDPNUDDEQ
#\\\|7WZY6V7BCR6VXPE3B7ZKUZOUHFFZTY2DLMD6VBZBLLPKPGTGAJZ \ / AMOS7 \ YOURUM ::
#\[7]2GQYHWZG7BHVDPRWDYSBZYZ2MBHSYZNBC2PXO3YPJI345Q2L7WAA 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
