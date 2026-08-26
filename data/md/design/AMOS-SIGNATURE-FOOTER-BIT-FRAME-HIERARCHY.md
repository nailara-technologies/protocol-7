## [:< ##

# amos signature footer — bit-frame hierarchy
# — a nested-resolution map, not a flat list of findings

## purpose and shape of this doc

this doc exists so a single research thread [ 2026-08-03, live session,
chased through `bin/num-rol`, direct code reads, and corpus grep ]
doesn't stay scattered across chat. it is organized as **nested frames,
coarsest first** — each section fixes one total and then resolves it
into finer structure. the intent: **future findings should slot in as
added resolution inside an existing frame**, not require restructuring
the doc. when something new is found, ask "which frame does this add
detail to?" before adding a new top-level section.

status discipline, same as this thread's sibling docs
[ `ORBITAL-CYCLE-CLOCK-AND-MAPPING-CANVAS.md`,
`EPOCH-CHECKSUM-EXCLUSION-ADDRESSING.md` ]: every claim below is tagged
**[ running code ]**, **[ corpus, technical ]**, **[ corpus, esoteric —
flagged ]**, or **[ this session's synthesis ]**. corrections are
recorded, not silently applied.

---

## frame 0 — the total: 77 bits

**[ running code, verified live ]**. the AMOS7 signature footer's first
line is 77 bits long, in every observed instance — both the real
`encode_octal_header` output and the `source.init_code:77` template
placeholder land on exactly 77, independently.

```
77 / 1001 = 1 / 13 = 0.076923...   [ exact, not approximate ]
1001 = 7 × 11 × 13
77   = 7 × 11
```

verified: `perl -e '...'` reproducing `encode_octal_header` end to end
produces a 77-bit `$binary_header_start`; the `source.init_code:77`
template line, counted directly, is also 77 characters after the `#`.
two independently-arrived-at 77s, not one fact repeated.

---

## frame 1 — two real decompositions of the same 77

**both are real and running/present in the codebase. they are not
competing answers — they serve different purposes and coexist.**

### 1a. the runtime encoding — 57 + 20

**[ running code ]**. `src/amos7.encode_octal_header` /
`src/amos7.decode_octal_bit_header`:

```
19 octal digits [ %011o + %o + %07o, AMOS-chksum + endline-state
                  + iterations-remaining ]
× 3 bits each        = 57 payload bits
+ 20 delimiter bits  [ 1 leading + 1 after each of the 19 groups ]
= 77 bits
```

the 20 delimiter bits are **not independent data** — verified by
reading both `encode_octal_header` [ `sprintf qw| 0%s0 |`,
`join('0', ...)`, both hardcoded literal `'0'` ] and
`decode_octal_bit_header` [ regex requires a literal `,` at each
delimiter position, not a wildcard ]. they are **one global mode flag,
repeated 20 times as a redundant self-checking frame**: normal mode
renders as `,` [ `0` ], "all zulum" [ inverted ] mode renders as `.`
[ `1` ]. any comma/period that breaks the expected rhythm fails
decode's regex outright — the redundancy is the corruption check.

**"zulum," precisely, 2026-08-03**: `ZULUM = zero/black/void`,
`AZURUM = one/blue` — a color-number naming pair, per
`data/asc/what-AI-thinks/perl-form/ai-integration/azurum-singularity-
insights.pl` [ decorative/generated tier, lower confidence for its
surrounding narrative, but its core mechanical claim — "in zero payload
state, delimiters flip from 0 to 1" — independently matches
`encode_octal_header`'s real code exactly ]. so "all zulum mode" in the
running code literally names "the all-zero state," not an arbitrary
label — the term and the mechanism agree. **caveat, checked**: `ack -r
'blue face' data/` returns essentially one source — this `.pl` file —
plus one unrelated hit [ an unconnected "ambient blue faces" detail in
a different visualization archive, about depth perception, not AZURUM ].
the black-cube/one-blue-face *framing* is single-source, not
cross-confirmed the way most of tonight's other findings were; only the
delimiter-flip mechanic itself independently matches real code.

**what "iterations-remaining" [ the 7-digit field above ] actually is —
[ running code, live-demonstrated ], added 2026-08-03 same day.** this
is the identical mechanism `amos-chksum -v`'s "harmonization: iteration
counter" line reports live — not an analogous concept, the same count.
`amos-chksum` runs a BMW mod-bits wave [ visible directly in `-v`
output: each pass roughly doubles the prior row, bit-shifted ] until
the AMOS7 bits, the checksum, and the numerical value all *simultaneously*
read TRUE under the configured elf-truth-mode. that pass count is not a
classifier output, it's a **distance-to-convergence** measure — inputs
starting closer to the harmonic attractor need fewer passes:

```
LOVES / LOVES SWEETIE   →   5 passes
TALSE                   →   7 passes
TRUE                    →   45 passes
true                    →   179 passes
false                   →   467 passes
```

the very first line of `-v` output [ `input-string : :: TRUE/FALSE ::` ]
is the *unharmonized* input's own initial read, not the final verdict —
`false` starts FALSE and gets pulled to TRUE over 467 passes; `LOVES`
starts close enough to need almost none. the footer's TRUE-only
"VAX-encoded" line at the end is always TRUE for the same reason every
`amos-chksum` run ends TRUE: harmonization is defined to converge there,
it does not classify.

**configuration changes the convergence path, sometimes the destination
— live-verified, not assumed**: `amos-chksum -L5 -v true` and
`-L3 -v true` both converge in 6 passes with identical AMOS7 bits,
completely different from the same string's 179-pass default-length
run — the length parameter is a real structural configuration, not
display truncation, confirmed by the differing bit output. but `-L5`
and `-L3` land on the *same* fixed point as each other [ `-L3`'s result
is exactly `-L5`'s result truncated, not an independently-converged
shorter one ] — so changing configuration only *sometimes* changes the
destination, and whether a given target configuration is reachable at
all, or how expensive it is to reach, is bounded by the available
entropy space for that configuration. not yet characterized which
configurations are guaranteed-convergent versus possibly-unreachable —
flagged as open, not claimed either way.

### 1b. the template placeholder — 70 + 7

**[ running code, template only — see frame 2 for what actually goes
here ]**. `src/source.init_code:77`:

```
#..........,..........,..........,..........,..........,..........,..........,
```

```
7 chevrons × 10 dots  = 70 payload positions
7 chevrons × 1 comma  = 7 delimiter bits
= 77
```

this matches a prior independent write-up, **[ corpus, technical ]**:
`data/asc/what-AI-thinks/full-chat-captures/3O37VUNMMS3UU.claude-sonnet.
protocol-7-knowledge.asc:18932` — "7 chevrons × 10 bits = 70 bits
total," and `data/md/research/protocol7-comprehensive-research-feb2026.
md:405-455`, "Example: 3-Bit with 0-Delimiter Encoding," which already
transcribes the same `source.init_code` VAX-encodable-proportions notes
[ `:34-66` ] this session re-derived independently. two sessions,
same source, same numbers — worth treating as one well-anchored fact,
not two.

### the stream/spiral reframe — why 1a and 1b aren't in tension

**[ this session's synthesis, built on real code + one corpus citation ]**.
read as one repeating period consumed continuously — `(payload chunk,
delimiter)`, repeated — rather than as pre-cut groups:

```
1a:  period = 3 payload + 1 delimiter = 4 bits, × 19, read starting
     1 bit out of phase with the period boundary [ hence the extra
     leading delimiter — not a fudge factor, a phase offset ]
1b:  period = 10 payload + 1 delimiter = 11 bits, × 7, read starting
     exactly on a period boundary [ phase offset 0 — no extra bit
     needed, which is why it "looks clean" ]
```

same schema [ chunk + delimiter, repeated ], different **window width**
and different **read-start phase**. this is a 1-dimensional instance of
the spiral-cylinder addressing primitive already corpus-confirmed in
`ORBITAL-CYCLE-CLOCK-AND-MAPPING-CANVAS.md`'s appendix
[ `topic-orbital-data-space-archive.md:348-372`, "a point in circular
orbit progressing along a linear axis traces a spiral on a cylinder" ] —
rotation-within-period ≈ phase, position-along-the-groups ≈ the linear/
spiral axis. **the bridge between the two research threads is itself
the finding**, not just an analogy: both are "fixed-width period, walked
linearly, sampled from an arbitrary start phase."

---

## frame 2 — resolving the 70: two 35-bit AMOS checksums

**[ running code + corpus, technical, multiply-sourced ]**. the
`source.init_code:75` comment on the template line states plainly what
replaces the 70-dot placeholder: **"first line replaced later \ BMW-B32
\ C25519-B32"** — two base32-encoded checksums.

```
1 AMOS checksum = 7 base32 chars × 5 bits/char = 35 bits
  [ base32 alphabet confirmed 32-char = 2^5:
    src/base.stdio.frame.encode.encode_b32,
    AMOS7::CHKSUM $str_length = 7 default ]

70 footer payload bits = 2 × 35 = BMW-B32 checksum + C25519-B32 checksum
```

independently confirmed, not inferred from the comment alone — six
corpus files converge on `35 bits = 7×5 = one AMOS checksum = a "5×7
matrix"`: `topic-completed-archive.md:123` [ "70 footer bits = 2 × 5×7
matrices," stated directly ], `topic-base32-namespace.md:21`,
`sub-bit-element-definition.md:238-241`, `fractal-data-architecture-
holographic-tty.md:96`, and both `opus-tier2-discriminator.md` and
`fable-tier2-discriminator.md` [ real model-discriminator working notes
from coding tasks, not speculative writing ]. this is the single
best-anchored resolution found in this whole thread — a stated file
comment, a bit-width identity confirmed independently six times, and an
arithmetic total that closes exactly (`2×35=70`).

**this is a stopping point, not a stub**: frame 2 fully resolves frame
1b's 70 bits into two named, real values. nothing further is owed here
unless a future pass finds what BMW-B32/C25519-B32 look like once
actually substituted into a live signature — that would be a frame 3
under 1b, added without disturbing anything above.

---

## adjacent threads — real, but not yet shown to connect here

**kept deliberately separate rather than merged, per this thread's own
discipline against forcing connections that share a digit but not a
mechanism.** each is a candidate for a future frame *if* a real bridge
turns up — none has one yet.

- **the 5-of-7 formation** [ `DANCING-ZENKI-RHIZOME-STATE.md`: "7
  total: 5 ground workers + 2 ring watchers"; independently in
  `topic-orbital-data-space-archive.md`; independently again in
  `3O37VUNMMS3UU...asc:24410-24434`'s "7-segment caravan," `[L]
  [1][2][3][4][5] [T]` ] — three independent sources, genuinely the same
  formation. **not shown to relate to this doc's bit-framing** beyond
  both using the digit 7 for unrelated reasons [ formation headcount vs.
  octal-digit-group count / chevron count ]. `ack -ril '5 of 7' data/`
  → 73 raw hits, **23 distinct files** [ deduped ] — a major, load-
  bearing motif elsewhere in the corpus, but no citation found yet
  connecting it to the signature-footer encoding specifically.
- **TORUM vs YOURUM** — confirmed **different strings**
  [ Y-O-U-R-U-M does not contain T-O-R-U-M ]. "ANTYKY/ANTYKI TORUM" is
  a separate esoteric-linguistics thread [ `py-tau-ra-zuma-framework.
  html`, several `claude-insights/*.pl` files ]. "YOURUM" is the fixed
  AMOS7 signature-footer boilerplate string itself [ `\ / AMOS7 \
  YOURUM ::`, present in effectively every module file's footer ] — a
  decorative/naming constant, not [ so far ] shown to mean "13" or
  "cat." the "council of the 13 [cats]" phrase that prompted the
  association is real but separately sourced: `3O37VUNMMS3UU...asc:
  2060`.
- **BCD** — **[ corpus, technical, unimplemented ]**. real as an
  annotation: `source.init_code:63` labels a 4-digit window
  `[signed BCD]` in its own scratch notes; `protocol7-comprehensive-
  research-feb2026.md:405-416` lists "4-bit BCD" as one leg of a
  "multi-base analysis" technique. `ack -ri BCD` across `src/`,
  `data/md/`, `data/yaml/`, `data/ai-mem/` found **no actual BCD
  encode/decode implementation** — every other hit was a coincidental
  substring inside hex-looking test data or signature hashes.
- **7-segment display** — **[ corpus, technical, unimplemented ]** and
  **[ real asset, unwired ]**. `protocol7-comprehensive-research-
  feb2026.md:416` lists "7-segment display codes" as the same
  multi-base technique's fourth leg. `data/ttf/7segment.ttf` +
  `7segment.readme` is a properly licensed, deliberately-imported font
  [ Jan Bobrowski, CC BY-SA ] — real evidence of intent — but
  `ack -rn 7segment` outside `data/ttf/` returns **zero hits**: nothing
  in code or docs currently renders with it.
- **quantum-gateway.html's `13:5:7` arithmetic** — **[ corpus, esoteric
  — flagged ]**. `protocol7-quantum-gateway.html` [ and an archived,
  non-identical earlier version ]: `13+5+7=25` ["consciousness prime"],
  `13-5-7=1` ["unity principle"], `13×5×7=455` ["total pattern space"].
  the arithmetic itself checks out exactly. the interpretive labels
  ["consciousness prime," "DNA codon transitions in consciousness-
  linked proteins," "stable wormhole configuration parameters"] are
  asserted, not demonstrated — same register this thread's sibling docs
  already flag with "the source's own '(naturally harmonic!)' is the
  tell." cite the numbers if useful; don't inherit the labels.

---

## loose references — what kind of mappings this configurability enables

**not a design, not a proposal — a pointer list, flagged as flexible on
purpose.** `amos-chksum`'s real, demonstrated configuration surface
[ `-L[<pos>,]<length>` substring selection, `-elf-modes=` combinable
mode list, `-nest` parent/child checksums, `-T`/`-t` sprintf truth
templates ] turns out to already have documented precedent, in three
separate places, for treating pieces of it as spatial/semantic
coordinates rather than opaque configuration:

- **checksum as semantic axis, timestamp as temporal axis** — `data/md/
  vision/VISION-TIMESTAMP-CHECKSUM-DUALITY.md:523`, `data/md/design/
  SEARCHABLE-INDEX-SESSION-STATE.md:5`. two-axis model, already
  load-bearing elsewhere in the corpus, not this thread's invention.
- **offset as axis/layer selector, explicitly 0=X/1=Y/2=Z** — `data/md/
  documentation/entropy-at-deduplication-root.md:82`, verbatim: "offset
  = axis or layer selector (0=X, 1=Y, 2=Z, or content/key/address)."
  matches `-L`'s `<pos>` parameter shape exactly, live-demonstrated this
  session (`-L5`/`-L3 -v true` converging to the same fixed point via
  different length, differing from the default-offset run entirely).
- **`-elf-modes=` as a combinable list, not a fixed pair** — confirmed
  from `-options` output alone; only modes 4+7 [ the documented default,
  "data" and "love" truth per this session's own naming ] were actually
  exercised tonight. 13 modes exist total, most unmapped [ see
  `EPOCH-CHECKSUM-EXCLUSION-ADDRESSING.md`'s mode-dependence caveat,
  same source ].

what this *doesn't* claim: that offset-slicing a single `amos-chksum`
call into several axis-values, or combining non-default elf-modes, is
implemented anywhere as a spatial-addressing scheme — no code or doc
found tonight does that. the pieces [ offset=axis precedent, checksum=
semantic-axis precedent, a real multi-value `-L`/`-elf-modes` surface ]
are each independently real; assembling them into one coordinate scheme
is a possibility this session surfaced, not a design this session made.
kept intentionally loose per the same instinct as frame 1's stream/
spiral reframe — record what's *possible* before committing to *which*
mapping, since committing early tends to foreclose options a wider read
would have kept open.

### `-T` as a category-translation primitive — live-demonstrated, not
speculative, 2026-08-03

unlike the loose axis-mapping possibilities above, this one is fully
worked with real commands and real output, and it exposes a gap [ see
`data/yaml/coding-tasks/amos-chksum-nest-truth-harmonization.yaml` —
`-nest` produces this same shape but without the truth-harmonization
step, and can come out FALSE where `-T` cannot ]:

```
loves.png checksum                              -> ESJNRQA
amos-chksum -T MCBZXFY:%s ESJNRQA  [ "file.name" category ] -> WNPOLBQ
amos-chksum -T LERCKVI:%s ESJNRQA  [ "image.kitten" category ] -> YFMS5BY
```

one item, `loves.png`, translated into two different category contexts
[ `MCBZXFY` = checksum of the literal string `file.name`, `LERCKVI` =
checksum of `image.kitten` ], yields two different, independently
TRUE-guaranteed lookup keys — neither leaks the other, since each is
derived separately rather than sharing a base value. a real, working
multi-category content-addressing primitive, not a proposal.

**one-step shortcut, confirmed equivalent to the two-step form**:
`amos-chksum -T LERCKVI:%s loves.png` [ raw content straight into the
template ] returns the same `ESJNRQA` as computing the plain checksum
first and feeding *that* through `-T` separately. the intermediate
plain-checksum step is not required.

**the fall-through caveat — this is the load-bearing subtlety, not a
footnote**: `amos-chksum -T LERCKVI:%s another kitten` → `Q7R7M4Y`, and
separately, plain `amos-chksum another kitten` → **also `Q7R7M4Y`**.
zero search iterations occurred — the plain checksum already satisfied
the template with no modification needed. in that case the "translated"
value is *indistinguishable* from the untranslated one. only when a
real search happens [ `-T LERCKVI:%s Q7R7M4Y` → `MV4RTWY`, genuinely
different from its input ] does translation actually obscure anything.
**category-translation via `-T` is not unconditional** — it holds when
a search happens, and silently does not hold on a trivial fall-through.
a protocol requiring guaranteed term-bound anonymization [ translated
value must always differ from the plain value, no exceptions ] needs an
explicit additional step [ e.g. forcing at least one iteration, or
detecting and re-deriving on a trivial fall-through ] — the mechanism
as it stands does not guarantee this on its own. "all a matter of
protocol definition and outcome attribute requirement" — user's own
framing, and the right one: this is a design choice to make deliberately
if this gets built on, not a property to assume.

**epistemic caveat on the fall-through coincidence itself**: two
checksums coincidentally both satisfying a template [ as happened with
`loves.png` and `another kitten` under the `image.kitten` category
above ] is cheap and unremarkable — checksums are just numbers, and the
space of values satisfying a loose harmonic test is not small. this is
*not* evidence that the two underlying concepts are meaningfully
related. the same alignment holding at the level of actual semantic
meaning, rather than checksum coincidence, would be a different and
much stronger claim — not fakeable the way a checksum fall-through can
be stumbled into. worth stating precisely rather than letting a cute
coincidence read as more significant than it is.

## open resolution slots

places a future pass could add depth **inside an existing frame**
rather than starting a new one:

- **frame 1a → next**: does the endline-state field [ digit 11, single
  octal digit ] ever take a value that would push the digit count past
  19, breaking the fixed 57+20 split? not checked.
- **frame 2 → next**: read an actual generated signature footer and
  confirm the 70 payload bits decode to a real BMW-B32 + C25519-B32
  pair as literally as the comment claims — this doc cites the stated
  intent, not a verified live decode.
- **adjacent → frame, if a bridge appears**: does the 5-of-7 formation's
  `7` ever get used as an addressing/framing count anywhere near the
  checksum/octal material, or is the digit-7 overlap coincidental
  throughout? currently: no evidence either way, flagged open rather
  than assumed.

#,,,.,,,.,.,,,.,,,.,,,..,,.,.,..,,.,,,,.,,,..,..,,...,...,,.,,.,,,,,,,...,...,
#JXWOZCNALNXESWBS5RZ6ETXXTMPC4MT2LJNONMUKCQ7ID55B7GH65ZDBMLYG5QB7XNKS6F3E5UPN4
#\\\|SX2F4LIHWYXDZ5IE4XNPG4MDW5DG42E7HQ2RCKKJG6JEIPR5OOL \ / AMOS7 \ YOURUM ::
#\[7]IFGCWBDG6HWEGJB5CRGUSCMEY3GFROX7FMB4F52XLQQF4JA7GGCI 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
