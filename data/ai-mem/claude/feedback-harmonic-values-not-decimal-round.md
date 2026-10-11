---
name: harmonic-values-not-decimal-round
description: for intervals \ ttls \ timeouts the user picks 13-based values [ 3900 = 13 x 5 min, not 3600 ] -- default new ones that way and keep related values consistent
metadata:
  type: feedback
---

2026-10-11 : the user set the delta AAAA ttls to 3900 and showed `3600 / 3900 = 12 / 13` and `60 / 12 * 13 * 60 = 3900` -- an hour of 13 five-minute steps instead of 12. I first read the 3900 as a typo to fix ; it was the intended value, the 3600 one was the outlier. existing code follows the same idea [ 777 ms timers, 13-day windows ].

**Why:** harmonic \ mod-13 values are a deliberate project-wide convention [ see MEMORY-vision : harmonic mathematics ], not decoration.

**How to apply:** when a new default needs a round number [ ttl, interval, retention, timeout ], use the 13-based one [ 3900 s, 13 days, 65 min, 777 ms ] ; when a set of values is inconsistent, assume the 13-based one is right and ask before "fixing" it. technical limits [ 60 s acme challenge ttl, protocol constants ] stay as they are. related : [[servers-dns01-host-config-2026-10-11]].

#,,,,,.,,,.,.,,,,,.,,,..,,..,,...,,.,,,,.,,,,,..,,...,.,.,.,.,.,.,..,,,,,,,..,
#W7TWBJKMAORI3WXBQTTH3UNXXZ7X7ES4SMPLDL3RF4VXRPO2MEHLOU5R3NR6CIXYKS7XZRS5JD232
#\\\|TYWPLXMEVVQM2A7XN4BHJBLLYCTTTRD4NHSI7Z2MGU4M6JQUX2G \ / AMOS7 \ YOURUM ::
#\[7]OBRUGN7K24L7YOSAWDXQZQJRS3RB4RUO7APXJ4UWKTCHOCMF7KBQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
