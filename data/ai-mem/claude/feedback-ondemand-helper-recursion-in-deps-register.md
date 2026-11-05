---
name: feedback-ondemand-helper-recursion-in-deps-register
description: a NEW helper sub called from base.register_*_deps [ or anything on the compile path ] recurses : compiling it on demand registers its deps first -- inline there, or add it to every load-early list
metadata:
  type: feedback
---

2026-11-05 : base.deps.recording [ new, in no subroutines.load-early ] called from register_src_deps :
its on-demand compile called register_src_deps again -> 'deep recursion' -> local weather stuck in
'starting'. fixed by inlining the check [ 485d04329 ] ; only subs already early-compiled in all 130
lists [ e.g. base.cfg_bool, verified with grep -L ] are safe to call there.

**Why:** new subs compile on first call, and the compile path itself uses the deps registrars.
**How to apply:** a new sub on a start-up \ compile path -> inline, or regenerate every zenka's list
[ bin/dev/gen-sub-whitelist ] ; always restart one local zenka [ weather ] after such a change.

#,,.,,...,,,.,,,.,.,.,,,.,,,.,...,...,.,.,..,,..,,...,...,,..,,,,,,,.,,.,,,,.,
#PJCBOZL2EA52W6CYBQ46PRNV3FFMV64IJYFXSDYWTGYJK7C44DYWIVMPRTF36BPJS3BWGAUFFZZC4
#\\\|XFHH2JRQ7JOZMPSOZMIAISDO7CRB54NCDOXD62OGXTVMXGKJYZF \ / AMOS7 \ YOURUM ::
#\[7]RNCLLHVY627HJ346XRSRH5NG3GMGSPEIESZYUYFZ3EGRNTFOUEBY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
