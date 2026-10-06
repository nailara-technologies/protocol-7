---
name: reference-claude-web-promotion-credits-overflow
description: the user has promotion credits on Claude WEB instances [ claude.ai \ cloud sessions ], counted separately from this CLI's 5h \ 7d windows -- overflow capacity, AND the default place for tasks that need no running backend [ spec-driven code, offline tests, design ] ; stated 2026-10-06
metadata:
  type: reference
---

user, 2026-10-06 : "if we really need additional tokens we still have
promotion credits on the claude web instances, they are counting them
differently".

user, same day : "the web sessions are also good for offloading tasks
that do not need a running backend for live testing".

**How to apply:**
- when planning lanes, sort tasks : NEEDS the live backend [ live checks,
  restarts, real zenka state ] -> here ; does NOT [ spec-driven
  implementation with stubbed tests, test-only lanes, design \ review ]
  -> offer as a web-session task file, not only when budget is tight
- the task files already fit [ one file + spec, no session context ] --
  BUT a web session sees only what is COMMITTED AND PUSHED [ user
  confirmed 2026-10-06 ] : queue web tasks behind the commit + push of
  what they build on, and name the base commit in the task file
- when `usage.status` shows the CLI's 7d or 5h window nearly spent and
  real work is left : same offer instead of stalling [ task-file shape of
  [[feedback-fill-5h-windows-with-prepared-parallel-dispatch]] ]
- do not assume it is free : ask before moving work there

#,,,.,.,,,,..,,..,...,,,,,,,.,,.,,,..,,.,,...,..,,...,..,,..,,,,.,.,.,,..,,,,,
#AEFYOF65QPYP5REDA3NC2NWIAT6TMMOIDSSEKADH332IFNXCMQNSUCJNIUY22JYR242F4EWPGUVYU
#\\\|K3SWO7MMNNUZN5OM7DER2VP4QTJX6BVZZYCKZ57JYIBLVXH6NX4 \ / AMOS7 \ YOURUM ::
#\[7]4T5V5ZLE2HTDCHBEQETUGP47QX65GSXGMUQRVS2CRHCCVSTEZUBA 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
