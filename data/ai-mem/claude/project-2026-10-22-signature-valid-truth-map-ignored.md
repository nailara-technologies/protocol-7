---
name: project-2026-10-22-signature-valid-truth-map-ignored
description: OPEN [ todo VWF ] : source.signature_valid ignores a caller's truth map -- owner 2026-11-05 : highly relevant, features with topologically significant truth distinctions build on it
metadata:
  type: project
---

src/source.signature_valid takes a truth map [ 3rd arg ] and fills it with defaults [ ~74-75 ], but its
checks read its own $truth_check_settings [ ~354 ] : a caller's map has no effect. harmless today [ every
caller uses the defaults ].

**Why it matters :** owner 2026-11-05 -- features will build on caller-chosen truth maps, with distinctions
of topological significance ; the form footer type is the first [ create_harmonic_footer needs truth
switches as a parameter for form signing ]. todo priority raised to high 2026-11-05.

**How to apply :** honour the passed map for the TRUTH checks only ; the binding checks [ AMOS match, BMW
match, Ed25519 ] stay outside it, never relaxable. related : [[project-2026-10-22-shm-permissions-forgeable-open]]
[ same SIGNED-STATEMENTS review ].

#,,..,,.,,...,.,.,,,.,,..,,.,,.,,,,.,,...,.,,,..,,...,...,.,.,,.,,,,.,,.,,,.,,
#DGGA74GKDF7FPYJBMG556KXDN6CPZONHDZZQ6Z634ICEZDCFYDXIKTMDRI5DB25I44MCJICVUZ3QC
#\\\|PAVMY5Q6MNT4C2UN4QVEF3EIIUHBXGRAYGA7QV5XTVXE5EW6H6T \ / AMOS7 \ YOURUM ::
#\[7]PUXVGK2JVAW3UTGFAQMKDDHT5ZKC5DZ2P6HGBYSAU4K5AGGH76AY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
