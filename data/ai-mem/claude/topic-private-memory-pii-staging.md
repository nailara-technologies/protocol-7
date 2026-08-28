---
name: topic-private-memory-pii-staging
description: "pointer — REPO-PII-LEAK-PREVENTION.md is the authoritative design (already comprehensive); this records a confirmed live incident plus the one genuinely uncovered angle (a formal private-memory-tree convention)"
metadata:
  node_type: memory
  type: vision
  originSessionId: 577750da-e5fd-428b-82bf-ca6d96b88ac1
---

**2026-08-28.** Initially wrote this as a fresh "SEED" after this session
leaked employer/company-name context into git-tracked content twice in
one night — once into a memory file's context line
(`project-vision-origin.md`, caught + scrubbed via `AMEND=1` before push),
once directly into a commit-message subject for an unrelated
`jobsite.util.build_prompt` bugfix (caught before commit, redone
generically). **Corrected same session**: `data/md/design/
REPO-PII-LEAK-PREVENTION.md` already exists and already covers this
ground in much more depth — 9 generalized leak vectors (tracked content,
filenames, embedded strings, commit messages both introduce- and
remove-and-narrate-direction, tag objects, bulk imports, fake/placeholder
data treated identically to real, the incident-record-itself becoming a
new leak, outbound dispatch payloads to external inference APIs),
detection requirements (pre-commit/pre-push diff scan, external
pattern-list location, second-pass LLM-assisted check, standard
PERSON/LOCATION/etc. entity taxonomy), a periodic full-history audit
design, and a documented `git filter-repo` recovery runbook. That doc is
the authoritative reference — read it directly rather than this file for
the real design.

**What tonight actually adds, concretely**: a confirmed live occurrence
of leak vector 3 (personal/employer string embedded in an otherwise-
generic file — a memory-file context line) and vector 4's *introduce*
direction (commit message, not the more-dangerous remove-and-narrate
direction the doc specifically calls out as easier to miss). Worth citing
as a real example if that doc's detection patterns ever get implemented
and need a first test case.

**The one angle not already covered there, still worth keeping**: that
doc's mechanism is fundamentally *detective/corrective* — scan the diff
being committed, encrypt matched spans in place. What's still open is a
*preventive/structural* split: a formal distinction between "memory
that's fine to be public" and "memory that should default to a private
location," decided at write time rather than caught at commit time. This
session's `/data/interview/` (an active job search, deliberately created
outside this repo, established as convention mid-session — see
[[project-vision-origin]]'s scrubbed reference to it) is already the
working example of this pattern, just informal/manual/one-off rather than
a system-level convention. Formalizing it (e.g. a parallel private
memory-tree location, chosen automatically for certain memory `type`s or
topics) is genuinely additive to REPO-PII-LEAK-PREVENTION.md's scope, not
a duplicate of it — that doc guards the repo's boundary, this would guard
*which side of the boundary something gets written to in the first
place*.

## how to apply

Design-only, no urgency. If picked up:
1. Read `REPO-PII-LEAK-PREVENTION.md` first — it is the real design doc,
   this file is not a substitute for it.
2. The one net-new idea here (formal private-memory-tree convention) is
   small enough to fold into that doc's scope as an addendum, or could
   stay a separate short doc — not decided, genuinely either works.
3. Don't re-derive the leak-vector taxonomy, detection requirements, or
   recovery runbook — they're already done, in more depth than this file
   would add.

[[project-vision-origin]]

#,,,.,.,,,,,,,.,.,,,.,...,.,,,,.,,...,,.,,...,..,,...,..,,..,,,,.,...,...,,.,,
#7OXMHSSE66CKZU4FEUMNS3TF2CPWWFAX2T3ICEOC63JWOQSGWZTH4PUKOZUQHNZUCGJVVLYBCEX4M
#\\\|RVRJVIVUBJZG2AFAWYN22LEPURW5NUV5X6XDZJJK4TBCJTYFZAJ \ / AMOS7 \ YOURUM ::
#\[7]ULHSIYRO5BK3NR7VAHLUFUB7N4FMCA6VQNPGUZWOXL3G6AEPHQAQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
