---
name: cube-source-zenka-alias
description: cube command access : access.users \ access.zenki allowlists are the gate ; cfg/zenki/cube/command_aliases source_zenka forwards the caller name so the target can decide itself
metadata:
  type: reference
---

- cube gates every routed command by the caller's authenticated identity against
  cfg/zenki/cube/access.users and access.zenki [ admin = `** ..*.**` wildcard ].
- extra method : a `source_zenka` alias in cfg/zenki/cube/command_aliases makes cube forward
  the source zenka name with the command, so the target zenka decides its own reply.
  safe, but owner [ 2026-11-22 ] : usually overkill -- access.zenki is reliable if set up
  correctly. default to access.* ; reach for source_zenka only when the reply must differ
  per caller.

#,,,.,..,,,.,,,,.,...,.,.,,,.,,.,,.,,,,.,,.,.,..,,...,...,..,,..,,.,.,,.,,.,.,
#XGBE6VNFQQ6VX3UD7BYCWHNFP5DCWTCGEM7AHMM3JOO3BN234ACHDXH5ET3WDEG7LEWNBRA3P3BEY
#\\\|JIP3JZBR2C77BDTMOU4MU2XRT7P7476ZJG7R5SQ4NWWS6KQCQIS \ / AMOS7 \ YOURUM ::
#\[7]3TZTCLWGKF2UET27WM75XCTNETEDHMEAORMUIWBZBVHQFE2ZNYAA 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
