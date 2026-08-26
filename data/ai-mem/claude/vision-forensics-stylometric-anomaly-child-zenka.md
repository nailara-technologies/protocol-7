---
name: vision-forensics-stylometric-anomaly-child-zenka
description: design-only concept for a forensics child zenka that scores incoming correspondence for writing-style anomalies as one low-weight input to agent/zenki auto-response authorization
metadata:
  type: vision
---

**Concept**: a stylometric-drift detector for incoming correspondence
(mail, portal messages, anything a zenka might consider auto-responding to)
that tracks a known correspondent's writing fingerprint over time —
punctuation habits (em-dash rate is one dimension, not the whole signal),
sentence-length distribution, function-word frequency — and flags when a
new message deviates sharply from that fingerprint. Feeds into whatever
authorization/trust score gates automatic agent/zenki responses, as one
low-weight input among many, never a sole gate.

**Why this shape, specifically**:
- **Never a trust-raiser, only an anomaly-flagger.** Any signal that grants
  MORE trust when present is trivially forgeable by an attacker who knows
  the heuristic exists (the seed case: a prompt-injection attempt padded
  with em-dashes to look "AI-polished" and therefore safe). The sound
  version only ever lowers confidence / raises suspicion on a mismatch from
  an established baseline — it can't be gamed toward *more* privilege by
  imitating the signal, only toward blending in with a correspondent's
  existing pattern, which is a much narrower and harder attack.
- **Belongs on the existing `forensics` zenka** (nightly sweep +
  investigation + report pipeline already live — see
  `src/forensics.init_code`, `forensics.investigate.finding`,
  `forensics.report.assemble`), not a new top-level zenka. It's the same
  shape of work: ingest something suspicious, produce a generalized
  finding, don't leak raw source material into the aggregate record.
- **Must run as a child zenka, not inline in `forensics` itself** — per
  CLAUDE.md's Child Zenka pattern (parent forks for blocking/isolated work,
  child stays network-accessible, nested routing e.g. `forensics.child.*`).
  The reason is data-hygiene, not just process isolation: raw mail
  content is PII-dirty and itself an attack surface if it ends up sitting
  in `forensics`'s own investigation/report queue (exactly the class of
  problem [[feedback-no-personal-data-in-repo-tree]] already guards
  against for repo-tracked files — same principle, applied to a live data
  queue instead of a git tree). The child zenka receives/handles the raw
  message, computes the stylometric comparison, and returns ONLY the
  anomaly report (a score + which dimensions triggered it) to the parent —
  the raw text never crosses into `forensics`'s persistent queue at all.

**Open / not designed yet**: how a correspondent's baseline fingerprint is
built and stored (needs its own PII-safe home, presumably external per the
usual `/data/<project>-data/` convention, not repo-tracked); what the
actual scoring function looks like; how many messages are needed before a
baseline is trustworthy; how this plugs into the auto-response
authorization path itself (which zenka/gate currently owns that decision).
This is a shape/architecture note, not an implementation plan.

**Follow-up**: see [[vision-shared-pattern-registry-ncode-smtpd-forensics]]
— the pattern-registration side of this child zenka fits naturally as an
adapter onto a shared regex/pattern-registry engine generalized from
ncode's self-refining-regex design, rather than inventing its own store.

#,,,.,,..,.,,,,,,,,.,,,.,,,..,,,,,.,.,,.,,.,,,..,,...,...,,,.,,.,,.,,,,..,,,.,
#UNBVTVOQCDLNWSCZBEM2QFNR4L4CBXUASXTMWTDYBAOOKRA3ZTFTQ4K3RUXDVX6O4NHVKMJBLXKQ4
#\\\|IMXTVUSXS33J6CMNVRNY3XJ2RRKUFDJBWIJXIKUESA35SA5FUEJ \ / AMOS7 \ YOURUM ::
#\[7]XP2LN6VNNO72HSTA2LSNGSCEZQ6AFWDB5ULYY4FMXHMGONHAGCBQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
