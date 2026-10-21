---
name: verification-commands-no-side-effects-no-truncated-negatives
description: a verification command must have no state-changing fallback [ a stray `|| git stash` ] ; never claim "none exist" from a listing cut by head
metadata:
  type: feedback
---

two slips on 2026-10-21, both caught the same session :

- **a check command with a git side effect** : `git show HEAD:<new file> || git stash -q` -- the file was untracked, so the stash RAN. it was a no-op only by luck [ no tracked changes at that moment ]. verification commands are read-only, full stop : no `|| <fix>` fallbacks, never git stash \ reset \ checkout \ restore inside a check.
- **a negative claim from a truncated listing** : `ls -la hosts/ | head` cut off `pri.v7.ax.json`, and I told the user "no saved host records". before saying something does NOT exist, list without head \ cut or count it [ `ls | wc -l`, `find -name` ].

**Why:** the first risks the user's uncommitted work [ see [[deleted-manually-tuned-captures-without-confirming]] ] ; the second puts a false fact into todo notes and decisions. **How to apply:** read-only checks stay read-only ; negative claims need an untruncated listing or a count.

#,,.,,.,.,,,.,..,,..,,,.,,,..,.,.,..,,...,...,..,,...,...,..,,...,.,.,.,.,.,.,
#Q372AF5UAPHYONCG4PSWEFSD4MPWPC2I2BIPCV2QZUPPQV53Y4UZRJKTKQQAYPTM7SGIPQP5YSB7O
#\\\|QSJKDBNVJDSSQDL4IA74RAGAXTSN6INDP2LEPEAO6NJ3KVQGLC2 \ / AMOS7 \ YOURUM ::
#\[7]TDFETU65FP4A2MBYKERQB7JG36AMGAN7XKQDC2LC7BNRJ4UDVMAY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
