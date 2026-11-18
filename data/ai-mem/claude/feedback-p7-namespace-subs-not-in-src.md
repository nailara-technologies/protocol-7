---
name: p7-namespace-subs-not-in-src
description: a $code{'base.x.y'} with no src file may be bin/Protocol-7's sub p7_x__y -- search that form before calling a module missing
metadata:
  type: feedback
---

2026-11-18 : I declared base.assert.harmony missing [ no src file, no `$code{..} =` ] and swapped it for a direct AMOS7 call ; the owner pointed at bin/Protocol-7 using it. it is `sub p7_assert__harmony` [ bin/Protocol-7:3461 ], registered from the p7_ namespace -- it adds -vh \ -vz \ -vd visualization and a no-AMOS7 fallback the direct call lost. reverted in ab75cf57f.

**Why:** the loader's p7_ subs never appear under their $code name in a text search.

**How to apply:** before calling a `base.*` sub missing, run `bin/Protocol-7 -nc -core-subs <pattern>` [ lists and extracts every p7_ core sub under its $code name ; it missed 16 of 78 until 2026-11-18 -- trailing comments after '{', one-line subs ] ; fallback grep `sub p7_<middle>__<last>`. prefer the registered sub over calling what it wraps.

#,,,,,.,.,,,.,.,,,...,,,.,,.,,,.,,.,,,..,,...,..,,...,...,,,.,.,.,,..,,,.,,,.,
#XOC2CF3E2UVBBNEY434W3Y36WFILIVHXLRBMEADHRQ4EUK5JHE5FM46VKKW4SD6G4XSTXHZSCPTZI
#\\\|HNLBGCX4ESCFMF5ZJO6PEERHLOP3CP2DEW2P3UZBV4Z3XJUC5LC \ / AMOS7 \ YOURUM ::
#\[7]QZBAJXC3JFHMHTVVCZMK2DGQSRB7GU6XRPEROEVGUYZ6ZBWH7GCI 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
