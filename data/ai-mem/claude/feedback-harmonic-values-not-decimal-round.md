---
name: harmonic-values-not-decimal-round
description: for intervals \ ttls \ timeouts the user picks 13-based values [ 3900 = 13 x 5 min, not 3600 ] -- default new ones that way and keep related values consistent
metadata:
  type: feedback
---

2026-10-11 : the user set the srv-V AAAA ttls to 3900 and showed `3600 / 3900 = 12 / 13` and `60 / 12 * 13 * 60 = 3900` -- an hour of 13 five-minute steps instead of 12. I first read the 3900 as a typo to fix ; it was the intended value, the 3600 one was the outlier. existing code follows the same idea [ 777 ms timers, 13-day windows ].

**Why:** harmonic \ mod-13 values are a deliberate project-wide convention [ see MEMORY-vision : harmonic mathematics ], not decoration.

**How to apply:** when a new default needs a round number [ ttl, interval, retention, timeout ], use the 13-based one [ 3900 s, 13 days, 65 min, 777 ms ] ; when a set of values is inconsistent, assume the 13-based one is right and ask before "fixing" it. technical limits [ 60 s acme challenge ttl, protocol constants ] stay as they are. related : [[servers-dns01-host-config-2026-10-11]].

#,,,,,...,.,,,.,.,.,.,.,.,,..,..,,,,,,...,.,.,..,,...,...,..,,,..,...,,,.,,,,,
#VFWTTIFOUHOUAIK5IAX3XG62V2YKJQAZ62AYUAXUNFNWMG4GCT4WPFIYUO2RYOS5WQO2VSAN2XNF4
#\\\|M7NDH2GJ2XL2YE356OCSFSU6V2JYW4W3Y5SLVSBKOGQMBXEGN5F \ / AMOS7 \ YOURUM ::
#\[7]FXLUPA4Y2CTH36GBG2OUZETSKE2SI352CLCZ5BVTQGNJZTFERCAY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
