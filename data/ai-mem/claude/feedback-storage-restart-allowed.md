---
name: storage-restart-allowed
description: the user allows restarting the storage zenka myself with `p7c v7-zenki.restart storage` whenever a change needs it -- no need to ask first
metadata:
  type: feedback
---

`p7c v7-zenki.restart storage` is safe to run on my own when a change
needs a fresh start [ user, 2026-10-04 ].

**Why:** storage is not stateful in a way a restart can hurt ; asking
each time only stalls verification.

**How to apply:** restart storage directly when needed, say so in the
report. this covers storage only -- other live zenki still with the user
unless they say otherwise. reload gotchas : [[reload-success-doesnt-guarantee-new-file-loaded]]

#,,,.,.,,,,,,,,.,,,..,...,..,,...,..,,...,,..,..,,...,...,...,,,,,,,.,,,,,.,,,
#B44DHWVI3NVE6DR36KHZ3FUR2OFPE2SG7QKJFVP6BDYM3ZDCKLSHMAUIMA7TMUNN2Z5V2ILHUPQVS
#\\\|BSOWG3MTJNQV75T3AQDTHISC2M5K4LP6OBVNJJZPKPQWEBKWZVR \ / AMOS7 \ YOURUM ::
#\[7]5DRXYFCMZLHWXZ6WTIKY4NVQZ5QYX6ECFAPCKVIFAANCRPVKVGCA 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
