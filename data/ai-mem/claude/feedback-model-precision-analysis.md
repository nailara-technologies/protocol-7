---
name: model precision on analysis tasks
description: Qwopus 9B v3 significantly more precise than sushi coder on code analysis; sushi coder hallucinates "async" for blocking calls
type: feedback
originSessionId: 66f44304-8c27-4c9c-927c-f41b97361621
---
Qwopus 9B v3 (ZDMAPAY:AR3OCKQ) correctly identified LWP::UserAgent in a while loop as CRITICAL
in round 1. Sushi coder (UU4JSVQ:MEHBONI) on the same module with the same template said
"no blocking occurs because the HTTP call is async at the OS level" — a false belief.

**Why:** LWP::UserAgent is synchronous blocking — it blocks the entire OS thread for the full
request duration. event.once() before the call does not help.

**How to apply:** For analysis tasks (event-loop audits, security reviews, architectural
investigations), prefer Qwopus until the evaluation system establishes a better-ranked model.
Sushi coder remains good for methodical coding tasks (file edits, module extraction) where
precise technical analysis is less critical.

Default model switched to Qwopus on 2026-05-09 based on this evidence.

#,,..,.,,,,..,,.,,,,.,.,.,.,.,.,.,.,,,,..,.,,,..,,...,...,.,.,,,.,,,,,...,,,,,
#HV422R2R2MPU2SN6ZTGY2DVMEQ4KXXY2MARQNUS6SUUW67Q3GNXHQVS34W32J5ENDKYBLRIO4V6GU
#\\\|7BYRO6KOG47D7TP6Z62A2VW6CLWYM7FIZS2NJHQAWULBQ6IDSNN \ / AMOS7 \ YOURUM ::
#\[7]KQYU3X2JLOM3BNKPOQNB4R5ULX22FRPJGI436OFNEZAJLFYNB2CA 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
