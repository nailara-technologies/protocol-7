---
name: feedback-request-signed-version-before-each-batch-commit
description: when doing multiple/batch commits in a session, explicitly request a new signed version number from the user before EACH commit -- don't assume back-to-back commits can proceed without asking again, stated 2026-09-17
metadata:
  type: feedback
---

When more than one commit is wanted in a session (batch commits), explicitly
request a new signed version number from the user **before each individual
commit**, not just once at the start of the batch. They add it themselves.

**Why:** stated directly 2026-09-17 after two back-to-back commits
(`a3a9120c1`, `e0e88a5ff`) both went through on a single "signed and
staged" from the user without a fresh request in between. The user's own
words: "if you want batch commits again then you need to request a new
signed version number before each from me and i will add it." The signing
step (`cfg/protocol-7.src-ver` + the AMOS7 data-signature scheme this repo
uses throughout, visible as the pre-commit hook's "staging version files" /
"checking signatures" step) is user-controlled authority, not something to
self-serve or assume carries over from a prior commit in the same session.

**How to apply:** when proposing or asked to make more than one commit in a
session, ask for a fresh signed version number before each one specifically
-- don't chain commits on the strength of an earlier "signed and staged"
covering the whole batch. A single commit following one explicit sign-off
is fine as-is; this is specifically about NOT assuming that sign-off
extends to a second, later commit without asking again.

**Signing may still be running when the user says "staged"** [ 2026-10-03 ] :
the signing zenka stages files when it finishes. before committing, check
`git -c color.ui=false status --short` : any entry with a second-column
change [ ` M` or `MM` ] means signing is still in progress -> wait and
re-check instead of committing. one commit [ `7bd872518` ] went through
mid-signing and only came out complete because the zenka finished first.

#,,,,,...,.,,,...,...,..,,.,.,.,,,.,.,.,.,.,.,.,.,...,...,...,...,.,,,,,.,,,,,
#X2BSZSCK36QPBJVORY3DOUXRGJGVOECRHRFYQHY7BO55JTBKNIXHWIRCZ47FRU5INAGIJQQ6XRNU4
#\\\|WJIOIP3IHDLWAWIBWIQSGZG2QURRHB35SSTM6K5GKNDCPSXXGI3 \ / AMOS7 \ YOURUM ::
#\[7]YSVOTCNJGG7EZDPD22JHOFCU2IKB7EGH4ERG5APNUEYNZ66LN4DY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
