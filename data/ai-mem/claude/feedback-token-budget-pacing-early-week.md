---
name: feedback-token-budget-pacing-early-week
description: be strategic about Claude token consumption from the start of each 7-day usage window, not just when usage.status shows it's already tight -- flagged 2026-09-17 after hitting ~50%/7d on day 1 of the cycle
metadata:
  type: feedback
---

**2026-10-09 :** the user has a ONE-TIME weekly reset available from the
cloud ui -- in a week with real work queued, don't idle while a kimi run is
out ; work on the non-overlapping part in parallel. pacing still applies,
but running out early is recoverable that week.

Be more strategic about my own token consumption pacing across a session,
starting from the beginning of each 7-day usage window, not just reactively
once `usage.status` already shows it tight.

**Why:** flagged 2026-09-17 -- Claude usage hit ~41-50%/7d on literally the
first day of that week's cycle. At that burn rate the week's quota runs out
long before day 7. This session's own pattern is a concrete example of what
drove it: repeated live `Monitor`-based RSS-polling loops during the CPU OOM
incident response (multiple rounds, each re-armed), several large multi-file
investigative reads in a row when a narrower targeted read or a fork/subagent
could have covered the same ground outside the main context, and fixing a
second unrelated bug (the kimi credential-refresh race) inline in the same
session rather than scoping it as a separate task.

**How to apply:** at the start of a session (or when `usage.status` shows
double-digit `%/7d` already), favor cheaper verification over repeated live
monitoring loops -- one well-placed check beats several `Monitor` re-arms for
the same fact. Prefer delegating implementation-heavy or low-risk-if-wrong
work to `kimi_dispatch`/subagents rather than doing every step directly
in-session, especially for work like the [[project-system-oom-watchdog-dynamic-poll-and-restart-escalation]]
task that was explicitly scoped for exactly this reason.

**Correction 2026-09-17, same session this was written**: user explicitly
confirmed via [[feedback-fix-immediately-reduces-cognitive-load]] that this
is NOT license to leave a found, real defect half-fixed or deferred to save
tokens -- would rather run short on tokens for a day or two than ship
half-fixed work, and argues fixing things right is ITSELF more token-
efficient mid-term (an unaddressed issue either escalates later at higher
cost, or sits as a standing tax on every future workflow touching it). This
memory is about trimming redundant PROCEDURAL overhead -- repeated live-
monitoring loops, more investigation than a question needs, over-doing
verification theater -- never about skipping a real fix or under-verifying
something that actually matters (the OOM safety fixes still needed live
confirmation, and got it).

## related

[[bug-coding-cpu-context-oom-forced-wsl-reboot-2026-09-17]]

**2026-10-07** : read the numbers myself -- `p7c usage.claude` \ `p7c usage.kimi` -- before stating any usage figure ; quoted a stale pasted 8% when it was 10%. the user prefers I run them [ also when watching kimi's budget during batch dispatches ].


**2026-10-29 :** thinking LOW is the default for kimi and for our own session -- quality stays high on current models. the real cost driver is CONTEXT GROWTH : one fresh, self-contained dispatch per piece over long kimi_continue chains ; hand a session over before its context bloats. bigger model + low thinking [ k3.1 low ] over smaller model + high for structural work. default kimi = k3.1 low [ mcp server ] ; LONG MECHANICAL tasks [ bulk renames, sweeps, many similar edits ] go to k2.8 low explicitly [ k2.7 = alias of the same model ]. 2026-10-29 runs : k2.8 low +3/+1 and +5/+2, k3.1 low +3/+1 [ 5h/7d ].


**update 2026-11-22 [ owner ]** : after a one-time weekly reset the remaining week budget is meant to be USED -- the 5h windows are the real pace limit then. shift work from kimi to claude_dispatch when kimi's week runs low [ kimi 65 % with 3 days left, claude 15 % ].

#,,,,,...,,,.,..,,,,.,.,.,..,,,,,,.,.,.,,,.,.,..,,...,...,,,,,,..,,.,,.,.,,,,,
#KSDEYONEQSPOEL77NEFJAD66M42SRY3Q2EQGYUU4RKNNEVOPRLEXXEIN7QAQNGANAGIXFCX372LAI
#\\\|WIQYYK3XFPBCK7JXH5GD74Z2BIQY7USMEMFTQ3YPJVQ4OEKBSRF \ / AMOS7 \ YOURUM ::
#\[7]JLNBYMGA6GKOF6BOB3NHADRY7U2G4KFRU5QK6CYJF5ZVNP4RXSBI 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
