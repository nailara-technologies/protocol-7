---
name: reference-cube-runtime-set-and-restart
description: how to change a %data value in a running zenka [ cube ] and restart cube -- devmod-enable first, cube takes bare commands, v7-zenki.restart
metadata:
  type: reference
---

- `p7c set <key> <value>` on cube answers `command does not exist` until devmod
  is loaded : `p7c v7-zenki.devmod-enable cube` first [ user tip 2026-09-29 ].
  avoids a temp `zenka.v7` edit + restart for a runtime toggle
- cube takes BARE commands : `p7c reload source`, not `cube.reload`
  [ -> `client not present` ]
- restart cube : `p7c v7-zenki.restart cube` [ `v7.restart` -> not present ]
- Event.pm hooks [ `Event->add_hooks` ] can't be removed from a running loop :
  instrumentation installed that way needs a zenka restart to go away

**Why:** cost several round trips in the 70ms-stall session [ 227d50b90 ].
**How to apply:** runtime experiments on cube -> devmod-enable + set, not
config edits. see [[reload-success-doesnt-guarantee-new-file-loaded]].

#,,,.,.,.,.,.,,,,,.,,,...,..,,.,.,...,.,,,..,,..,,...,...,,,.,...,.,,,.,,,...,
#NJQ7NKLPGLIREZWCDQHMVCY6KFJVLBEAJXUJIB4UJEWTDZNALSP423EF7IVNRC2O5H7TYTN663GXM
#\\\|YJKTGEAFL5S3IPGAJCVJVL4D4RCD36M3YHGQOENNCUW2EKYC4IO \ / AMOS7 \ YOURUM ::
#\[7]5TRKP346WZHXTK35FPKFW2GDWHPFLHWT3SURPJQC6AWIMCYLOUCI 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
