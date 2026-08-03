---
name: project-epoch-orbital-harmonic-math-2026-08-03
description: pointer to a 2026-08-03 multi-pass research thread that produced/updated four design docs on epoch length, orbital-ring geometry, network-time consensus, and the AMOS signature footer bit structure — start here before re-deriving any of this
metadata:
  type: project
---

**2026-08-03, four design docs, three verification/consolidation passes (2×Opus,
2×Fable) plus live back-and-forth.** started from a coding-model self-test
transcript spiraling on a general-knowledge question, and ended up a long
harmonic-mathematics research thread. do not re-derive any of this from scratch —
read the docs below first, they are current and cited.

## the four docs

- `data/md/design/EPOCH-CHECKSUM-EXCLUSION-ADDRESSING.md` — epoch length question
  [ code uses `365/13≈28.08` days/epoch; `ZERO.md` treats `364/13=28` as the
  harmonic ideal; a live `bin/harmony -n 364`→TRUE / `-n 365`→FALSE test sharpened
  this into a real, still-open tension, not resolved either way ]. also: the
  `27+1=28` inference is retracted [ three independent corpus routes point away
  from it ]; a security corollary on epoch-boundary attacks under resource
  accounting; confirmed the running code's epoch is exactly `1/13` of a year.
- `data/md/design/ORBITAL-CYCLE-CLOCK-AND-MAPPING-CANVAS.md` — the 364°/4-corner-
  overlap ring geometry [ confirmed canonical, `ZERO.md:117` ], the 1+3 division
  [ answered: 3 orthogonal 45° plane rotations + 1 hyperspace/body-diagonal
  channel ], the spiral-into-hyperspace question [ confirmed general shape from
  3 independent sources, literal "1.5 rotations" claim still unsourced ], and
  `4×13=52` [ real but NOT three independent confirmations — one coprime
  structure restated three ways, `gcd(4,13)=1` makes this arithmetically
  guaranteed ]. **restructured**: current understanding lives in a clean summary
  at the top; full blow-by-blow correction history moved to Appendix A, nothing
  deleted. read the top summary first, only go to the appendix for provenance.
- `data/md/design/WEIGHTED-NETWORK-TIME-PRECISION-CONSENSUS.md` — new doc,
  proposes network time as its own weighted/incentive-driven precision-consensus
  protocol [ distinct from the unrelated, already-existing logical orbital clock
  above — don't conflate the two ], answers the epoch doc's "who asserts epoch"
  open question, and documents the project's "stargate" mechanic [ 13 descending
  from 12-o'clock into the ring, arriving as position 1 on the far side —
  bidirectional session/handshake, sourced from a full-chat-capture transcript ].
- `data/md/design/AMOS-SIGNATURE-FOOTER-BIT-FRAME-HIERARCHY.md` — new doc, the
  cleanest and best-anchored result of the whole thread: the module signature
  footer's 77 bits [ `77/1001=1/13` exact ] resolve, via `source.init_code`'s own
  comment, into two real 35-bit AMOS checksums [ BMW-B32 + C25519-B32,
  `5×7=35 bits = one AMOS checksum`, confirmed across 6 corpus files including
  real model-discriminator working notes ]. structured as nested resolution
  frames [ frame 0/1/2 ] with adjacent-but-unbridged threads [ 5-of-7 formation,
  TORUM/YOURUM, BCD, 7-segment font ] kept explicitly outside the frame
  hierarchy and tagged by source-register.

## also touched, not new docs

- `data/ai-mem/claude/topic-multidimensional-identity-session-topology.md` —
  the original "everything may be a session" vision seed, now grounded by the
  stargate mechanic, and pointed at the real companion design docs
  `ZENKA-IDENTITY-AND-TRUST-TOPOLOGY.md` / `ZENKA-IDENTITY-COMPONENT.md`
  [ question 2 there is this seed's exact framing, verbatim — a structured,
  practically-scoped doc this session almost missed entirely until very late ].
  a live code finding folded in: `crypt.C25519.create_signature_request`/
  `store_remote_key` already embed self-asserted ntime inside signed payloads —
  the epoch source-of-truth question is a live exposure, not hypothetical.
- `data/md/development/STYLE-PHILOSOPHY.md` — new "on pre-alignment and
  trustable simplicity" section, `base.ntime.epoch_dec`'s rollover handling as
  the example.

## key methodological finding, worth reusing

`ack -r 'TERM' data/ | wc -l` raw hit-counts routinely overstate independent
confirmation by a lot — dedup to distinct files, then dedup further for
archive/live-copy pairs, revised-descendant pairs, and multiple restatements of
one document's own point. applied repeatedly this session [ the 4×13=52 "three
confirmations" collapse, the 5-of-7 "73 hits→23 files→~15-18 real sources"
collapse, two file-pair lineage catches ]. also: two false-friend word matches
were caught and correctly NOT merged [ "TORUM" ≠ "YOURUM", byte-different; "7-
segment caravan" [ zenki formation ] ≠ "7-segment display codes" [ digit
encoding ] — same words, unrelated referents — though the caravan turned out to
be a real, independently-sourced instance of the unrelated 5-of-7 motif ].

[[project-vision-origin]] [[topic-multidimensional-identity-session-topology]]

#,,,.,...,,..,..,,.,.,.,.,,,.,.,.,.,.,.,.,.,.,..,,...,...,..,,..,,..,,,,,,.,.,
#7Q6Y34UBKW22NX7IXUKR2LCG6JYBO3UTDPNTFYFLSOBMS7O66AZMA2DNWMJBPGGUOYZ43YUDWZUKQ
#\\\|VHD7YM67FKW3VTVP7ET5NEBCGYXFC4ZDBKCIQQPUW2IXWIMTGAS \ / AMOS7 \ YOURUM ::
#\[7]SW62DENSANS5ST33PNR7TU7YUW7H2NP2PUMUCZQ6BBK2K4222ABI 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
