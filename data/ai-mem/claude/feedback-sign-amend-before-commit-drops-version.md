---
name: feedback-sign-amend-before-commit-drops-version
description: p7_sign op amend on uncommitted work rewinds the version file to <previous>.1 and the commit hook refuses it ; re-sign extra files with op new, version true until the commit exists
metadata:
  type: feedback
---

2026-11-07 : hit twice in one session. after a `new` sign bumped to 10576.0, a follow-up `p7_sign op amend` for a late fix set the version file to 10575.1 ; `p7_commit` refused with 'expected *-10576.1'.

**Why:** amend counts from HEAD's version, it folds into an EXISTING commit. before the new commit exists there is nothing to fold into.

**How to apply:** while a signed change is still uncommitted, sign late fixes with op new + version true. use op amend only after the commit landed. also : do not send p7_sign in the same step as the tests it depends on, and edit signed files by text, never by line number [ signing reformats ]. see [[mcp-sign-commit-workflow]].

#,,,.,,,.,...,..,,,.,,.,.,,.,,...,,,,,.,,,.,.,..,,...,...,..,,,.,,.,.,.,.,,..,
#5TVS5SSRK2LFZ3NVHDFQPXACEYLQ2BUXMNSQUWOD6T27UIYMKIWH2UYA6W3JFKORZWYYXCVBB4ID4
#\\\|GLA3YHCTOOBYWPQFW6JWNUZJ3KIT64BCKTAGETBP7XCSK5UHBEV \ / AMOS7 \ YOURUM ::
#\[7]6OPAAFTN2PU5MGUAEQXUQSHXHWPO7YCU6ZQOTH6UJJNYXZFVCEBA 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
