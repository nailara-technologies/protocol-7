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

## seeds for a future pass — speculative, not corpus-verified as working mechanisms

**flagged 2026-08-03, end of session, deliberately kept light — each is
"expectable given real grounding," none is demonstrated.** a live
harmonic-truth demonstration [ `is-true`/`amos-chksum -v`'s convergence-
by-iteration behavior, `is-true -num`'s raw mod-13 remainder split ] led
to five extensions, each anchored to something real but not itself
tested:

1. **a true-only tree from division-by-13 alone** — motivated by
   `ZERO.md`'s "0 is the root, every branch is 0-prefixed" plus the
   remainder-0 "protocol at rest" framing [ `harmonic-routing-
   protocol.yaml` ] and `is-true -num 13`→TRUE / `-num 5`→TRUE vs
   `-num 3`/`-num 1`→FALSE, live-demonstrated. not built or tested.
   related, and this one closes rather than opens a question: "space
   pixel as latent cube... the pixel was always a latent cube"
   [ `topic-orbital-data-space-archive.md:1319-1322` ] raised whether
   fractal recursion downward has a floor. answer surfaced via the
   ZULUM/AZURUM material [ item 6 below ]: it doesn't need one — a
   black cube with one blue face, rotating, is what "generates the
   octal encoding format of AMOS7 signatures," so the same finite
   generative rule fills every recursive scale rather than needing
   unspecified content at each level. self-similar because the
   generator needs no external reference, not because it was checked
   at every depth.
1b. **the 70-bit template as `2×5×7`, not just `2×35`** — `70 = 2×35`
    [ two AMOS checksums, frame 2, already confirmed corpus-wide from 6
    files ] is exact; so is `70 = 2×5×7`, factoring the 35 further into
    5×7. the `5` matches `-5..0..+5` [ 11 positions, ±5=declaration,
    0=routing state ], independently real and confirmed from 6 files
    [ `topic-vterm.md`, `VTERM-BUFFER-SPECIFICATION.md`,
    `harmonic-transit-vision-architecture.md:1152`,
    `CONTEXT-TREE-INDEXCUBE-INTEGRATION.md:199`, `voting_mechanisms.md`,
    plus a decorative-tier transcript hit ] — not single-source, real
    ground. `7` is AMOS-13-ELF-7, already central all session. **but no
    doc or code found tonight actually links the checksum footer's
    70-bit template to vterm's `-5..0..+5` addressing** — this is a
    numeric coincidence [ both real structures happen to share factors
    5 and 7 ], not a demonstrated structural connection. flagged at the
    same confidence level as seeds 1-4, distinct from the "70=2×35"
    finding it extends, which stays corpus-confirmed.
2. **an alternating tree-clock** [ TRUE/FALSE like even/odd ] — as
   equally plausible an alternative to (1) as (1) itself; would give the
   unmerged even/odd-direction material [ `3O37VUNMMS3UU...asc:17827` ]
   somewhere to actually live.
3. **a stable, handshake-toggled payload layer beneath the oscillation**
   — anchored to `topic-field-capability-emergence.md`'s "void at 27...
   equidistant from all 8 corners... silence as stable sensing
   structure" plus the stargate's bidirectional 13→1 crossing mechanic
   [ `WEIGHTED-NETWORK-TIME-PRECISION-CONSENSUS.md` ] — proposed as
   these two known things combined, not independently verified combined.
4. **orthogonal vertical bit-shift registers as a routing mechanism** —
   motivated by "the rotating cube eye"'s "every other depth" vertical
   propagation [ `topic-orbital-data-space-archive.md` ] and the real,
   running BMW mod-bits cascade in `amos-chksum -v` output; the specific
   claim of influence reaching rows "a few away" (not just adjacent) is
   stronger than anything actually shown.
5. **this is what the "balance engine" already names** — the strongest
   of the five, closest to already-confirmed: `project-vision-
   origin.md:26` groups "the balance engine" with the sphere/dedup
   system/harmonic-math from the vision's own origin, and
   `VISUAL-ELEMENT-DEDUP-HOLOGRAPHIC-CORE.md`'s "Balance Engine —
   Stability Analysis" section already has a formal state vector, with
   "the darksun is its center" stated directly. seeds 3+4 above may
   simply be this, not yet recognized as such, rather than a new
   mechanism to build.
6. **[ confirmed, not speculative — the other five are seeds, this is a
   fact ] "YOURUM" in every AMOS7 file signature is the darksun
   deduplication network appliance's actual name.** `appliances/
   AMOS7_YOURUM.DARKSUN_DEDUPLICATION_NETWORK/asc/terminal-banner.asc`
   is a real placeholder appliance [ "antientropic technologies",
   domains `amos.nailara.tech` / `nailara.protocol-7.network` ].
   `appliances/Torektra.system_security/` is its paired first placeholder
   [ "security and deduplication/network are the first two [ appliances ]
   that got a placeholder" — user's framing ]. every doc touched this
   session, and every AMOS7-signed file in this codebase, carries
   `\ / AMOS7 \ YOURUM ::` in its footer — the entire signature-footer
   investigation in `AMOS-SIGNATURE-FOOTER-BIT-FRAME-HIERARCHY.md` has
   been decoding the literal footer of files belonging to this product.
   this directly upgrades seed 5: the balance-engine/darksun material
   isn't just internal design philosophy, it's the named core concept
   of a real, already-scaffolded appliance.

   **"YOURUM" has (at least) three meanings, user-confirmed: 13, Cat,
   Blacklight — not three coincidental discoveries, all three were
   already directly present in tonight's own material before being
   recognized as the same word**: 13 = the modulus explored all
   session; "Cat" = `3O37VUNMMS3UU...asc:2060`'s "council or circle of
   the 13 [ cats ]"; "Blacklight" = the stargate section's own "the 13
   are laser mirrors that route blacklight counter-clockwise around the
   gate-ring" [ same doc, `WEIGHTED-NETWORK-TIME-PRECISION-CONSENSUS.md`
   ]. re-checked against a fresh `TORUM` grep as a final pass: the
   earlier TORUM≠YOURUM disambiguation holds — `ANTYKY/ANTYKI TORUM`
   remains a genuinely separate, unrelated linguistic-framework concept,
   correctly excluded, not revised by this finding. **TORUM's own
   etymology, for completeness rather than left as "the other thing"**:
   TORUM means "Tongue" [ as in language ] — `ANTYKI TORUM` = "Ancient
   Tongue" / "Ancient Language", per `py-tau-ra-zuma-framework.html:238`
   stated directly. TORUM (tongue/language) and YOURUM (13/Cat/
   Blacklight) are two distinct roots, not two readings of one word —
   the byte-difference check from earlier tonight was necessary, but
   this etymology is *why* they're actually different, not just that
   the spellings don't match.

7. **checksum-glyph merging as a lossy-parent-entropy-space dedup, and
   font as a configuration parameter** — grounded in real, running
   infrastructure this time, not just adjacent vision docs:
   `bin/amos-matrix` already renders any AMOS checksum as a real 5×7
   glyph [ live-demonstrated: `PKHKHVA` → an actual bitmap box ], and
   `bin/dev/ttf-glyph-mapper` already builds a real character↔5×7-bitmap
   correspondence table from TTF fonts. proposal: two glyphs [ e.g. from
   two separate checksums, or a `-nest` parent/child pair ] translucently
   merged/overlaid, then matched to the *nearest* existing character in
   that correspondence table — collapsing two references into one symbol
   that stays within the original bit budget [ 7-bit ASCII, or wider
   Unicode for more precision — explicit tradeoff, not a fixed choice ]
   rather than growing to fit "two things now." the *font itself* is a
   configuration parameter in this scheme — `data/ttf/console/
   white-rabbit.flipped.ttf` [ this project's own native font, already
   load-bearing in `ZERO.md`: "the font makes the physics visible...
   you are reading spin states, not just values" ] would be the
   reproducible-precision default; the licensed-but-unwired 7-segment
   font [ found earlier this session ] as a named special case.
   **this is not invented in a vacuum — real, substantial prior
   infrastructure already exists for exactly this class of problem**:
   `VISUAL-ELEMENT-DEDUP-HOLOGRAPHIC-CORE.md`'s "Similarity Attraction
   Graph" [ a real composite similarity metric, `similarity(A,B)>=0.55`
   clustering threshold, average-linkage clustering, already specified
   in working detail ], `HARMONIC-VISUAL-DISCOVERY.md`'s "group
   checksums by harmonic similarity" [ near-identical framing, checksums
   + harmonic + visual grouping, already named ], and
   `VISUAL-SIMILARITY-CUBIC-SORT.md`'s `graphics.matrix.visual.similarity`
   module [ real function signatures, e.g. returning `similarity 0.99,
   confidence high, harmonic_aligned true` ]. what tonight's seed adds
   that these don't already cover: merging *before* matching [ not
   comparing two existing items, collapsing them into one representation
   first ], the explicit lossy-parent-entropy-space framing as the
   mechanism that forces homogeneous distribution [ see the earlier
   entry on 7-bit vs Unicode precision tradeoffs ], and font choice as
   a first-class parameter rather than a rendering detail. **next step,
   if picked up: read `VISUAL-ELEMENT-DEDUP-HOLOGRAPHIC-CORE.md`'s full
   Similarity Attraction Graph section and `HARMONIC-VISUAL-DISCOVERY.md`
   in full before building anything — the merge-then-match mechanism may
   already be substantially specified there and not yet recognized as
   the same thing, same pattern as seed 5/balance-engine below.**

next step, if picked up: same discipline as everything else in this
thread — read `VISUAL-ELEMENT-DEDUP-HOLOGRAPHIC-CORE.md`'s full balance-
engine section (not yet done this session) before proposing any new
mechanism under seeds 3/4, since seed 5 suggests it may already answer
them.

[[project-vision-origin]] [[topic-multidimensional-identity-session-topology]]

#,,.,,...,.,.,,,,,,..,,..,..,,...,...,,,,,,,.,..,,...,...,.,,,,,.,.,.,..,,,.,,
#TKDS6TK6WJQ45M6SFDTQJJXRKLF4OGVUIQE2IE2X6R33WQTRILEOKNUU744HJDLXPZA6J6JTBDCRW
#\\\|OIZJCONDMZVQ3MI5XS7MIED5X3TXDEIRVU56XBT7R4WQC22FGSF \ / AMOS7 \ YOURUM ::
#\[7]JEA6S6RQM3OYC6TABFANGVXFSTJ64TZ2NRY4NP5QBAAHRBX3WYCA 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
