---
name: feedback-fill-5h-windows-with-prepared-parallel-dispatch
description: near a 7d reset, unused budget is lost -- the binding limit becomes the 5h windows, so plan to FILL each one : prepare self-contained task files first, then run parallel claude_dispatch lanes [ + one serial kimi lane ] ; stated by the user 2026-10-06 with 45% claude left and ~9h to reset
metadata:
  type: feedback
---

near the end of a 7-day window the question flips from "pace" to "fill" :
whatever is unused at reset is gone, and the 5h windows [ 2-3 overlapping
the remaining hours ] cap how fast it can be spent. the user wants each
5h window filled well -- "perhaps even with nested dispatches, or even in
parallel, once task file is prepared, for the shorter windows".

**Why:** 2026-10-06, claude 55% \ 7d with 9h to reset, kimi 63% \ 7d with
~1d left. one serial session cannot burn 45% in ~3 windows ; parallel
lanes can. this is the end-of-week complement of
[[feedback-token-budget-pacing-early-week]] [ which stays right for the
START of a window ].

**How to apply:**
- the parent session's job in a short window is to PRODUCE task files
  [ shape : [[feedback-narrow-scoped-kimi-task-file-pattern]] ] and review
  results ; implementation goes out to lanes.
- claude lanes : background `Agent` subagents [ run_in_background ], NOT
  several `claude_dispatch` at once -- mcp-server-p7 is single-threaded
  and claude_dispatch still blocks it [ only kimi got fork+detach ], so
  parallel claude_dispatch calls serialize. give each lane a DISJOINT file
  scope [ new test files, one namespace each ] ; worktree isolation has
  escaped before [ [[feedback-agent-dispatch-worktree-isolation-escaped]] ].
- kimi lane : strictly one at a time [ [[feedback-kimi-dispatch-never-parallel]] ],
  k2.8 default ; kimi's reset is later, so queue its work to continue
  after claude's reset.
- security-critical design + final review stays in the parent ; lanes get
  tests, mechanical changes, pattern application.
- verify every lane's real diff yourself -- nested summaries are lossy
  [ [[feedback-nested-dispatch-session-tracking]] ] ; commits stay serial,
  each with a fresh signed version [ [[feedback-request-signed-version-before-each-batch-commit]] ].
- start lanes EARLY in a window ; a task file finished 20 min before the
  window resets wastes most of that window.

#,,..,,,.,.,.,,.,,,,,,...,,.,,..,,,,.,,,,,,..,..,,...,..,,.,.,,,.,,,,,,,,,.,.,
#OJIVUZAXUWKS6VJ77FYG7E755T6MPK2TOYPK3OUBWQWQOTBA2VKEAGKOON6FV25EJN3MW74EU47NW
#\\\|CMHVRKOCM2HR5FEKKQQI65WXWJCUKKYK36DKN5SRGRTLNVMLLT3 \ / AMOS7 \ YOURUM ::
#\[7]7TPO2KAZOF55OLTKVD3LTKPH6V4OTRQPPSZDJNXW6CQIXG4FBKCY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
