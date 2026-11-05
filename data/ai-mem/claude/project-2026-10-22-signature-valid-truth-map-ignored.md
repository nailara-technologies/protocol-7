---
name: project-2026-10-22-signature-valid-truth-map-ignored
description: FIXED 2026-11-05 [ 66f759706, todo VWF ] : source.signature_valid ignores a caller's truth map -- owner 2026-11-05 : highly relevant, features with topologically significant truth distinctions build on it
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

**FIXED 2026-11-05 [ 66f759706 ] :** effective map = defaults + valid caller entries [ known keys,
0 \ OP \ RQ, anything else ignored ] ; caller hash no longer written to ; truth checks only. every caller still
passes {} -- a non-default map is untested until the form footer type uses one : add its test then.

#,,,.,,,,,..,,.,.,..,,.,,,.,,,.,,,,,,,...,,,,,..,,...,...,,,,,..,,.,.,,.,,...,
#HV5NALLAWV76QP7XOF7SAAOHGSU4P5H42RFWWEFUEYYOTDZMF5O7PCV7AU5BA7E5JIVQOZJRPCWQG
#\\\|6MIKTRA5JU27PADL4YYJLM6ZQGKM2LSTIZLXPAACJ3RF56G6UW3 \ / AMOS7 \ YOURUM ::
#\[7]X2ELD4T6VNBWEDKUJHW3VHIQNRJPCCWTALUYIPC5ANAE5C23M2AA 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
