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

#,,,,,,..,..,,..,,...,,,.,,..,...,...,...,,,,,..,,...,...,...,,.,,,,,,,,,,..,,
#L5KV563YSYIMV2JVN4SDL6DF2OOW4JCJNWOLMY557KFA7UEF2UQQ2KTYB4YPYRMFTZJGCTV2B2RKI
#\\\|2LL33U37YMHASKT5IHUOJNEURIVGSLADT7JJH3N6IBFHUF37UU6 \ / AMOS7 \ YOURUM ::
#\[7]PVPUSSSMS5VTHFBDIEZZZZXMBVM5IGOURYKIBK5PW7NOIP6I64DY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
