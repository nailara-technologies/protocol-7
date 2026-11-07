---
name: kimi-wrapper-exit-not-done
description: the kimi_dispatch wrapper pid exiting does NOT mean kimi finished -- kimi-code lives on and keeps editing ; wait for pgrep -x kimi-code too
metadata:
  type: feedback
---

2026-11-07 : I took the wrapper's exit notice as completion and started reviewing while `kimi-code` was still running and editing files.

**Why:** reviewing, testing or signing half-written files gives false results, and the sign run stages every modified signed file -- an agent's unfinished edits included.
**How to apply:** after kimi_dispatch, wait for the wrapper pid AND every `kimi-code` process : `bin/dev/notify-pid-gone <pid>; while pgrep -x kimi-code >/dev/null; do bin/dev/notify-pid-gone $(pgrep -x kimi-code | head -1); done` as a background command. never sign while it runs. kimi_check_status needs the `session_` prefix on the id. a long `perl ... mutate.pl` child means it is in its final check. see [[kimi-dispatch-model-verify-before-send]].

#,,..,,.,,,,.,,..,.,.,..,,,,,,,.,,,..,...,,,,,..,,...,..,,..,,,,.,,..,,..,...,
#UIDUJKPX3MZQVWOAU4LDTH4NGM34OMI6DRJST5QPMAGX5C7UADLL36D7XJLY2VZW52UIGP4LO5BII
#\\\|YJ65NW3KKEEQRPHUUKL6MJXKAYYUDERA6YHROYLWPHL6M2TWVJ6 \ / AMOS7 \ YOURUM ::
#\[7]APCNUWMBJZHAYG63QHQLQ4FV4XLVNPPRAPYVIKULTZER2LZXPACI 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
