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
(`989f137ad`, `0b35ddbb6`) both went through on a single "signed and
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

#,,,.,,..,.,.,..,,.,,,...,,..,.,.,..,,,.,,,,,,.,.,...,..,,,.,,.,,,,..,.,,,,..,
#V2YMGJH3P2YEYGBQBSJPOORR6R7TFJRUNSDT4IE6S6C6VWFPO4M342C2IJ7CLTFSLPIU72KDXK7HS
#\\\|J565SMAIEUWPKHMS72JNANJJP3GJWIOPTGGLKTIG4FNVRTKLKQB \ / AMOS7 \ YOURUM ::
#\[7]7HF2RUOZG3ZYQPAZJBYVBYHNPYJTHZHS3BT6QJHXG7B5BK35X4CY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
