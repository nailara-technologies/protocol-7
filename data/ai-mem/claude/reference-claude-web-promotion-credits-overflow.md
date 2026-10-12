---
name: reference-claude-web-promotion-credits-overflow
description: the user has promotion credits on Claude WEB instances [ claude.ai \ cloud sessions ], counted separately from this CLI's 5h \ 7d windows -- AND the default place for tasks that need no running backend [ spec-driven code, offline tests, design ] ; stated 2026-10-06
metadata:
  type: reference
---

user, 2026-10-06 : "if we really need additional tokens we still have
promotion credits on the claude web instances, they are counting them
differently".

user, same day : "the web sessions are also good for offloading tasks
that do not need a running backend for live testing".

**2026-10-07 : switched, cause unknown** : the credits page states
"applies automatically to cloud sessions. after it's used or expires,
your plan's regular usage applies" [ credit expires 2026-11-05 ]. but the
WEB UI USAGE BAR shows which pool a web session draws : the first time it
stayed at 0 while the web session worked [ credits ] ; on 2026-10-07 it
tracked the plan's usage [ plan windows ] -- user's evidence, stronger
than inferring from usage.status [ local lanes ran in the same window ].
glitch or silent change ; accounting glitches happen [ the weekly reset
also moved ~6 h that day ].

**2026-10-12 : confirmed again** : a cloud session [ started from the
claude project, opus 5.5 ] moved the plan's weekly bar 77% -> 78% while
the credit stayed at $94 of $100 after a page reload. cloud sessions
currently draw the PLAN, not the credit -- no token advantage over local
lanes ; use them for what only they give [ a fresh environment : DJ2
bootstrap tests ].

**plan, user 2026-10-12** : ignore the credit until the weekly limit is
reached ; THEN test whether it applies [ a small cloud or web task,
watch the credit amount ]. nothing works -> a case for support, and
until the reset : strict prioritization of the remaining work.

- CHECK the web usage bar right after starting a web lane : at 0 ->
  credits [ free extra capacity ] ; moving -> plan [ competes with local
  lanes, budget accordingly ]

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

#,,..,.,.,,..,,..,.,.,...,.,.,,..,..,,..,,..,,..,,...,...,,.,,...,..,,,,.,.,,,
#IA2IZ2TWV7Y6YF5MS7ZRJWD56GSE524VHPLNAR7H7HV3RA2VXL2WC5HTHOVMC54CWYYFQ3GNWPTO6
#\\\|OYI2LGCVO32SGRBVS3IEGVREZLJK3NOASWJMAP2FSCVBHTT4IN5 \ / AMOS7 \ YOURUM ::
#\[7]FKA27LF65HQ5ZABTCFZIHI6HC46ABHGPWV4Z6OWA6IFYHMEK3MDQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
