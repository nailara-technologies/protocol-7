---
name: verification-commands-no-side-effects-no-truncated-negatives
description: a verification command must have no state-changing fallback [ a stray `|| git stash` ] ; never claim "none exist" from a listing cut by head
metadata:
  type: feedback
---

two slips on 2026-10-21, both caught the same session :

- **a check command with a git side effect** : `git show HEAD:<new file> || git stash -q` -- the file was untracked, so the stash RAN. it was a no-op only by luck [ no tracked changes at that moment ]. verification commands are read-only, full stop : no `|| <fix>` fallbacks, never git stash \ reset \ checkout \ restore inside a check.
- **a negative claim from a truncated listing** : `ls -la hosts/ | head` cut off `srv-U.json`, and I told the user "no saved host records". before saying something does NOT exist, list without head \ cut or count it [ `ls | wc -l`, `find -name` ].

**Why:** the first risks the user's uncommitted work [ see [[deleted-manually-tuned-captures-without-confirming]] ] ; the second puts a false fact into todo notes and decisions. **How to apply:** read-only checks stay read-only ; negative claims need an untruncated listing or a count.

#,,.,,,..,.,.,,.,,..,,...,..,,...,..,,..,,.,,,..,,...,...,...,.,.,.,,,.,.,.,.,
#I7ITD7NX3NIFNKQT62HYIMCVW2O45OPULH66YQKAKXJF4N5EXSCWISVI7OU2DCTW6IB3Q34FH4NXM
#\\\|4YV2VYPG2SDGMFLR3UOA2OTJNZ43WVCIGF3RVXZWG5YXPZDD7RU \ / AMOS7 \ YOURUM ::
#\[7]A7RR3KT5277ZJ74UETLDKJLIDHANJOKQGZ3DFV7VRRTCVUIN54DA 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
