---
name: vision-shared-pattern-registry-ncode-smtpd-forensics
description: generalizing ncode's self-refining regex engine into a shared base module used by ncode (code style), smtpd (mail routing/classification), and forensics (stylometric anomaly patterns)
metadata:
  type: vision
---

**Concept**: `ncode`'s already-designed self-refining regex engine
(`data/md/coding-tasks/ncode-zenka-self-refining-regex.md` — regex-pattern
registry with applicability/confidence/coverage/stats, hybrid regex+LLM
"wave" cycle, escalation ladder regex→callback→LLM→user, pattern extraction
from LLM diffs, tree compaction) is not actually code-specific in its core
mechanics. The same shape — apply known patterns fast/free, escalate only
what's uncovered, feed successful escalations back as new patterns — fits
at least two other domains already present or proposed in this codebase:

1. **`smtpd` mail routing/classification** — `modules/smtpd.classify`
   already has exactly this shape today, just not externalized: an inline
   hardcoded keyword-regex fallback (`interview`, `ablehnung`/`rejection`,
   `angebot`/`offer`, etc. — see the `$combined =~ m{...}` chain) used only
   when the LLM path is unavailable, with LLM as the primary path when
   present. This is backwards from ncode's design intent (regex-first,
   LLM only for what regex can't cover) and the patterns are frozen in
   Perl source rather than a registry that grows from experience the way
   ncode's does. smtpd needs a real pattern registry *structurally*, for
   routing/categorizing mail without an inference requirement at all —
   independent of forensics or any security angle.

2. **`forensics` stylometric-anomaly detector** (see
   [[vision-forensics-stylometric-anomaly-child-zenka]]) — the child zenka
   concept there needs somewhere to register and optimize the patterns it
   learns (which punctuation/style dimensions actually predict anomalies)
   without leaking raw mail into forensics's own investigation queue. If
   smtpd already carries a shared regex/pattern registry for routing, the
   forensics child zenka becomes an *adapter* to that same structure —
   registering new patterns it discovers, reading smtpd's existing ones —
   rather than inventing its own separate pattern store.

**Proposed shape**: extract the domain-agnostic core of ncode's design
(`*.regex.apply`, `*.regex.assess`, `*.regex.expand`, `*.regex.save`, the
wave/escalation-ladder logic, confidence/coverage/stats bookkeeping) into a
shared base module family (naming TBD — something like
`base.pattern-registry.*`), with `ncode.regex.*`, a new `smtpd.regex.*`,
and the forensics child zenka's adapter each becoming thin domain-specific
wrappers around the same engine and yaml pattern-definition format. Same
relationship as `ncode.transform.wave` already documents for code: apply →
assess uncovered remainder → escalate → extract new pattern → next cycle
needs less escalation.

**Why this is worth doing as ONE generalization rather than three separate
implementations**: the self-refinement property (successful LLM
resolutions become regex patterns, confidence adjusts from false-positive
tracking, tree compacts via LLM-driven generalization) is the valuable
part, and it's pure infrastructure — reimplementing it three times means
three places to fix the same future bug, and no cross-domain compounding
(a pattern-registry improvement made via ncode's code-style workload
wouldn't benefit smtpd/forensics unless the engine itself is shared).

**Open / not designed yet**: exact module boundaries and naming for the
shared base; whether smtpd's registry and ncode's registry should be one
yaml store with a `domain:` field or genuinely separate files sharing only
code; how the forensics child-zenka boundary (raw mail never leaves the
child) interacts with a registry smtpd itself can read — the child must
still only emit generalized pattern proposals, never raw content, even
when registering into a shared structure. This is a shape/connection note
across three existing pieces of design, not an implementation plan.

**Same shape found in a fourth, unrelated domain**:
[[vision-orbital-hop-sequence-hyperspace-flight-animation]] identified
`opencv.init_code` (a stub for a future opencv zenka) as a candidate cheap
color/curve-analysis pre-pass before escalating to a full vision-model
call on rendered cubic-space frames — the same "cheap deterministic check
first, expensive model only for what it can't resolve" shape as this
note's regex-before-LLM pattern, just for images instead of text/code.
Worth keeping in mind if/when the shared base module described above
actually gets built: a fourth domain wanting the identical escalation
shape strengthens the case for one generalized engine over reimplementing
the ladder per-domain.

#,,,,,.,.,,,,,,..,..,,...,,,,,,,,,.,.,.,,,.,.,..,,...,...,,.,,,,.,,.,,..,,,.,,
#KBJSLLW3VNWTVMQCKOANPVL77F54MAB3KUVIVYYN226LWGVC742EPN2VXHFINQTZIBDCFZPEINEUM
#\\\|VZYHIRL566E4ZTIDH75FQQ7PNY5TK4IHT5USNI2URY67OUT6UMJ \ / AMOS7 \ YOURUM ::
#\[7]N77J5TBLAKRS3CNXJHDONXM2ZEW6JMK55ZMYAW2COWJGRZP5ISCQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
