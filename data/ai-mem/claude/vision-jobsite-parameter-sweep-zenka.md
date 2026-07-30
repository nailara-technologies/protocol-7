---
name: vision-jobsite-parameter-sweep-zenka
description: future idea — jobsite zenka extended with (1) parameter-sweep result-quality optimization and (2) reverse coherence audit of the full application package
metadata: 
  node_type: memory
  type: vision
  originSessionId: b44b4dad-1786-471d-a04e-f75e14a5b9c6
  modified: 2026-07-30T01:58:31.104Z
---

two complementary extensions for the jobsite zenka, same general shape as the
forensics/openvas enrichment → investigation handoff pattern (see git log
around b71fadde1), but applied to search tuning and application QA instead of
scan findings.

**1. parameter-sweep for result quality**: search category/keyword/URL
variants are currently hand-tuned by spot-checking trash contents and
adjusting `jobsite.cfg.url.*` / `profile.txt` exclusions one at a time (e.g.
finance/insurance exclusion measurably dropped a mismatched listing's score).
a sweep coordinator could instead: define variant dimensions (search slug
wording, category groupings, industry exclusion lists), run scored batches per
variant, and correlate variant → score-distribution / signal-to-noise, so
tuning stops being manual trial-and-error and becomes a measured optimization
loop.

**2. reverse coherence audit**: complementary pass over the full outgoing
application package (CV, cover letter, profile data) checking for internal
consistency and things an employer-side AI screener would likely flag — dead
links, misspelled company/address names, inconsistent dates or contact
details, formatting artifacts. this is a generically useful QA step
independent of the sweep idea, not an edge case: any coherence break in the
application package looks bad regardless of role fit.

once letter-writing itself is model-generated, this audit also needs to catch
LLM-tell stylistic signals that read as AI-generated to a screener — e.g. em
dashes, which are a well-known giveaway. this class of check (style
fingerprint that reads as machine-written) is as important as factual
coherence once generation, not just search/scoring, is in the loop.

**3. anti-exaggeration / honesty sweeps**: a further generalization of the
coherence audit — scanning generated or claim-bearing text for overstated or
aspirational language presented as current fact. same failure mode shows up
outside job applications: a repo README or docs file that blends vision/
roadmap language with actual current-state description reads the same way to
a careful reader (or screener) as an inflated CV claim. worth treating as one
check reused across both contexts (application text, project documentation)
rather than building it twice — the underlying pattern is "does this text
distinguish is from will-be."

**how to apply**: when this surfaces again, don't rebuild the scoring/prompt
logic — design a sweep coordinator + a separate coherence-checker pass, both
modeled on the existing enrichment-handoff shape (dispatch → collect outcome
→ correlate/report). keep application-sending itself manual/opt-in — these are
real applications, not synthetic test targets.

#,,.,,...,,,,,.,.,,.,,,..,,..,,.,,,..,,,.,,,,,..,,...,...,.,,,.,.,..,,..,,,.,,
#GE3D4QIZHOPDOH5ILY64FVFZE3F4XWZLF6GKLXIAF74A336DY5TE5V7PQWTYXBB6BUXA6KVUKFI4Q
#\\\|GHIOQ6ISNNT3Z6QSWMSUFFJQFVBD2KIU3V2QCYLRI3I5TJ4V7KR \ / AMOS7 \ YOURUM ::
#\[7]JELGAS4OPBA62V6XNAYS3SD3Z63YELMXILXZSIUG6N5FMFWX2GCQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
