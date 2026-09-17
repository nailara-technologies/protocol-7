---
name: feedback-fix-immediately-reduces-cognitive-load
description: user's stated reasoning for always choosing the correct-but-more-work fix over a quick patch/caution-note -- resolving fully now means less to track/remember later, which keeps future work clearer and less "foggy", not just more correct
metadata:
  type: feedback
---

Said directly after the [[feedback-tool-probe-empty-args-destructive-default]]
incident (2026-09-16), once the framing was corrected from "remember to be
careful" to "fix the tool": incidents are useful training data for
choosing the seemingly-more-work-but-correct path with LESS hesitation,
not more — because if that path is completed immediately (not deferred
or worked around), there is less unresolved state left to carry forward
and remember. Framed explicitly as a "trainable fog-removal technique":
fewer open loops/compensations in flight keeps future reasoning more
focused and clear-minded, as a direct consequence, not a side benefit.

**How to apply**: this generalizes
[[feedback-upgrade-substrate-not-revert-on-tool-limits]] (fix the
underlying system, don't revert/patch around it) with the *reason why* —
when a real defect surfaces (a destructive default, a tool limitation, a
wrong assumption baked into shared code), resolve it at the root in the
same session if at all feasible, even when a narrower patch or a
caution/memory note would "work" too. The apparent extra cost up front
is offset by not having to carry the unresolved gap as tracked state
(a memory note to remember, a workaround to repeat, a landmine to step
around) in every future session that touches the area.

**Confirmed + extended 2026-09-17**, after the CPU OOM incident response
raised [[feedback-token-budget-pacing-early-week]] as a potential tension
(is fixing everything found, same session, actually affordable on a tight
token week?): user explicitly does NOT regret the practice under budget
pressure — would rather run short on tokens for a day or two with a
genuinely resilient system than ship a half-fixed one, or one stuck with
a half-working setup and no clean way to iterate further. Stated a second,
economic reason beyond the cognitive-load one above: doing the fix right
is ALSO more token-efficient mid-term, because an unaddressed real issue
either escalates later (usually costing more to resolve once it does) or,
left unaddressed, sits as a standing tax on every future workflow that
touches it. **Restated as a concrete design principle 2026-09-17** after the
model-sweep `:restart:` keyword work (explicit opt-in to discard a
cursor, safe resume stays implicit): "no data loss is exactly the
right behaviour type for the coding zenka" — the destructive action
gets the explicit, auditable flag; the safe default stays automatic.
Same underlying value as the rest of this memory, applied specifically
to state-persistence/recovery design, not just bug-fixing discipline.

**This means [[feedback-token-budget-pacing-early-week]]'s
"weigh fixing vs. deferring" framing is about trimming redundant
procedural overhead (repeated live-monitoring loops, more investigation
than a question needs) — NOT about leaving a found, real defect half
fixed to save tokens. Don't read that memory as license to defer real
fixes; it isn't one.**

#,,.,,,.,,..,,.,,,,,.,.,.,,,.,.,.,.,,,,..,,,,,..,,...,...,.,.,.,.,.,.,,.,,,.,,
#4KKSLN4VQOD3APTKCR44E5HLDCZCV3DNE5PS6WCSTXJO7NHGAUB42WFGJ3XV5RGBFPAJC3Y6GXIL2
#\\\|JUJQHQPD5GZQZYJ7V3UGCAHSCX5PAHMXYYVAJQS7G7DWV7XV5F3 \ / AMOS7 \ YOURUM ::
#\[7]RE4SDGUTQX7UUCYTJTW6O5FQHSRQOGU3AEH4YI7LD3X3OGPUAMCY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
