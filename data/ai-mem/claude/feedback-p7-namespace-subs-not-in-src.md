---
name: p7-namespace-subs-not-in-src
description: a $code{'base.x.y'} with no src file may be bin/Protocol-7's sub p7_x__y -- search that form before calling a module missing
metadata:
  type: feedback
---

2026-11-18 : I declared base.assert.harmony missing [ no src file, no `$code{..} =` ] and swapped it for a direct AMOS7 call ; the owner pointed at bin/Protocol-7 using it. it is `sub p7_assert__harmony` [ bin/Protocol-7:3461 ], registered from the p7_ namespace -- it adds -vh \ -vz \ -vd visualization and a no-AMOS7 fallback the direct call lost. reverted in 2c590c1d0.

**Why:** the loader's p7_ subs never appear under their $code name in a text search.

**How to apply:** before calling a `base.*` sub missing, run `bin/Protocol-7 -nc -core-subs <pattern>` [ lists and extracts every p7_ core sub under its $code name ; it missed 16 of 78 until 2026-11-18 -- trailing comments after '{', one-line subs ] ; fallback grep `sub p7_<middle>__<last>`. prefer the registered sub over calling what it wraps.

#,,..,,.,,...,...,.,.,.,.,...,...,...,...,,,.,..,,...,...,.,.,.,,,,.,,,,.,...,
#DUWWJ4FTDAG6MLUSZSBK7TX3KMYFVQCQIE4NAE6KGJMYQ7A6OWHCLRZBJG45TZZO436ZB76PCIFW6
#\\\|DBZARSRKG6SF3B4PJSVVRNFRVIUZWONT7Q663HXNPWV67ANKQZG \ / AMOS7 \ YOURUM ::
#\[7]YMDUR2IVO3HVFJOUUFDC4XCKZD757IDNGXEY5JFWRFUJ5LDK5SBY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
