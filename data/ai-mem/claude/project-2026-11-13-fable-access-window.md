---
name: fable-access-window
description: Fable 5.2 included in the plan until about 2026-11-16 ; the N7FS review by Fable produced much valid work -- plan its use before it ends
metadata:
  type: project
---

2026-11-13 : owner says 3 days of Fable 5.2 access remain in the plan [ ends about
2026-11-16 ]. the one earlier use, the N7FS review [ ~/.n/private-notes/fable-n7fs-review-2026-11-11.md ],
gave many valid findings.

**Why:** a scarce, high-yield reviewer ; unused days are lost.

**How to apply:** spend it on review \ design where a fresh strong reader pays most :
1. review of finding 5 stages 1-4 [ e0c4b7916 1061c8697 38f26e53b + stage 4 ] -- crypto \
   nonce domains, release order, retain bucketing [ stage 2 already had a nonce reuse
   only caught in review ]
2. design of the open findings 7 [ rollback ] 8 [ snapshot before pull ] 9 [ n7fs cycle,
   restore drill ]
. the 3D hyperspace visualization [ visual.v7.ax = data/web-root/vhosts/visual.v7.ax/grid-v14-layered.refactored.html, 56 KB, loaded by index.html ; .optimized.html is byte-identical ; v13 baseline beside it ; docs/ARCHIVE-README.md ] -- owner : an early opus did 2 clean passes, 10x performance + advanced layer support ; respect [[rapid-pattern-visual-disruption-risk]] [ slow, easily slowed cycling ]
5. refresh read-me/documentation/dev/NRT.NRD.asc [ AMOS RESSOURCE TOKENS notes, 108 lines, old ] in the style of the current + envisioned structure : drops = 4200 / token [ the ntime factor ], accounts = checksum + C25519 key [ lambda principle ], resources = n7fs storage / traffic / compute, pool vs append-only declaration history [ loves_it ledger ], derived placement, grinding caveats ; ALSO review its key derivation [ passphrase seeds an AMOS-13 stream, PIN = iteration count : a low-entropy PIN, offline guessing if the stream state leaks ] -- AND owner : the iterations can be mathematically jumped to, so an iteration count is NOT work / slowdown on its own [ neither for the PIN nor as proof of work ] : needs a memory-hard KDF / sequential function where work is wanted. owner : what compensates is the transcendent agreement to the honest outcome [ validity by universal checking, the doc already says only valid states are signable ] -- keep that as the FOUNDATION ; it covers validity fully [ a jumped state that breaks the rules is refused, so PoW work is not needed for it ] but not SECRECY : a guessed PIN signs valid, rule-conforming transfers in the owner name, so the PIN side still needs the memory-hard KDF. owner : zulum zenka [ zulum.loop.generate_entropy ] + bin/dev/division-13-table as network entropy bound to grid location + timestamp = spatial and temporal compartments ; shortcuts do not weaken it against precomputation : an epoch "rainbow table" would have to be the whole network at full resolution for that time range, and it expires each epoch. limit to carry : with public coordinates the value for ONE known spot is directly computable -- unpredictable in advance, not secret ; ideal as public salt / epoch input [ e.g. the anti-grinding epoch of derived placement ], secret keys still need a secret mixed in and the "derivable secret key of the last state can be public" proof-of-work idea
dispatch via the Agent tool with model fable, a self-contained prompt.
RESETS [ owner 2026-11-13, claude UI ] : one Fable reset, expires 2026-11-17 08:59 CET [ refills the 5h window + Fable allowance AND gives back what Fable used of the week -- not the whole week ] ; one full reset, expires 2026-12-10 23:00 CET [ the whole week ]. so Fable runs are effectively free of week cost once the Fable reset is used : spend Fable freely, use the Fable reset late on 11-16 or early 11-17 before it expires ; keep the full reset for a tight week.
COST : run 1 [ design 7 8 9, effort high ] started at claude 7d 22.0 % [ 4d 09h44 left ] -- compare after, to size run 2.
RUN 1 COST : claude 7d 22.0 -> 28.0 % [ incl. my own stage 4 review ], 5h 72 % after -- one high run ~ 5 % week, most of a 5h window.
RUN 2 [ review finding 5, high ] : real baseline before start claude 7d 29 %, 5h 80 % ; the first ~2 minutes [ initial reading ] already took it to 7d 31 %, 5h 90 % -- the big read costs up front. RUN 2 DONE : 7d 29 -> 39 % [ 10 %, ~25 min ], 5h 61 % of a fresh window. result ~/.n/private-notes/fable-n7fs-review-finding5-2026-11-13.md : 17 findings R1-R17 ; R1 critical [ holder-prune / retain drop trees of detached disks ], R3 shard key = first char of the b32 address -> always ONE shard [ verified ; test hardcodes 56 ] ; repair order R1 R2 R8 -> R5 R7 -> R3 R6 R4 -> clock -> R9 with head v2. retain must not run on multi-disk / multi-holder roots until R1 R2 R8 land.
RESET PLAN [ owner ] : before 11-17 08:59 plan a whole 5h [ or 10h ] window ahead for Fable-only work, then use the Fable reset right after it.
RUN 1 DONE 2026-11-13 : ~/.n/private-notes/fable-n7fs-design-7-8-9-2026-11-13.md -- design 7 8 9 10 in 12 stages, 15 owner questions [ 1-6 before stage 2 ], 14 defects D1-D14 [ D1 place seals whole tree past filters \ quota, D2 receipts shared across roots, D3 service root still needs vault, D7 future receipts accepted, D13 tree names refuse "/" -> prefix snap: not snap/ ]. stage 1 [ receipts per root + clock floor ] can start at once.
[[session-handover-n7fs-review-findings]]

#,,.,,,,,,,,,,,..,...,.,,,,.,,.,.,.,.,,..,,.,,..,,...,...,...,..,,.,,,,,.,,,,,
#VXB3HYO6RIQ5SN3LPGYFO3AZOSKYHNJCXBE2DRS5R4GXQQJFG4D2HQ6YOJOMANHTK454KWK5XMNO2
#\\\|KNRTJU4RXPPO7O7YITMQFVTBRKZFRFB2RLW4IH3C7OIJ6LPSJDU \ / AMOS7 \ YOURUM ::
#\[7]L5XCTF2EOKS54F4QI25BXMPR4VC5HMOH34ETR6R62E5IJGANQQAA 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
