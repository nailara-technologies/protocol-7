---
name: feedback-ondemand-helper-recursion-in-deps-register
description: a NEW helper sub called from base.register_*_deps [ or anything on the compile path ] recurses : compiling it on demand registers its deps first -- inline there, or add it to every load-early list
metadata:
  type: feedback
---

2026-11-05 : base.deps.recording [ new, in no subroutines.load-early ] called from register_src_deps :
its on-demand compile called register_src_deps again -> 'deep recursion' -> local weather stuck in
'starting'. fixed by inlining the check [ 0d60550d7 ] ; only subs already early-compiled in all 130
lists [ e.g. base.cfg_bool, verified with grep -L ] are safe to call there.

**Why:** new subs compile on first call, and the compile path itself uses the deps registrars.
**How to apply:** a new sub on a start-up \ compile path -> inline, or regenerate every zenka's list
[ bin/dev/gen-sub-whitelist ] ; always restart one local zenka [ weather ] after such a change.

#,,,,,,,.,.,,,.,.,.,.,,,,,.,.,,,,,,.,,,..,,,.,..,,...,..,,..,,,,,,,,.,.,.,.,,,
#JD67WGAF7P6ZR3ZRDDBDXIXEAMQ65M4YINHBTZFS4EURCNULZX524PKOP4OZCOMK5HUIURU56E2DK
#\\\|UXDJ57QGAHKCPDIUPMZ65H2Y2DIIFUAIMKFZ257NA4VWC6FAWTH \ / AMOS7 \ YOURUM ::
#\[7]LCYTFAHXEDCU25QBFHD5EOKETPDZLBXB52YYAA72K7UEXHJJRAAY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
