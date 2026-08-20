# epoch + checksum nested addressing with cross-epoch exclusion

## relation to prior design docs

this doc extends the lineage of
`data/md/design/CONSOLE-FOLD-TREE-PHILOSOPHY.md` and
`data/md/design/STDIO-RELAY-FOLD-APPLICATION.md` *downward* into the
checksum/addressing substrate. those docs establish that every branch is
itself a complete tree and that stdio relays can be folded into
addressable elements; both eventually want **named storage slots** for
their accumulated lines, logs, snapshots — and a homogeneous, native
default tree layout for that storage is the missing piece.

the cross-epoch exclusion mechanism below traces directly to
`data/md/design/CHECKSUM-NESTED-ADDRESSING-AND-EPOCH-VALIDITY.md` §2
[ captured 2026-06-10 ] — "epoch rollover as index-checksum salt: only a
window of {previous, current, next} epoch is considered valid. all
networked indices must roll over seamlessly or fall out of validity."
that entry envisioned the {prev, current, next} window and the base
timestamp primitive's rollover-safety in the same sitting, motivated by
a concrete first use case rather than as a defensive afterthought — see
"origin" note near the exclusion mechanism below.

the connection to log storage is concrete: the per-zenka stdout ring
under `/dev/shm/.7/STDOUT/<sock>` mentioned in
`STDIO-RELAY-FOLD-APPLICATION.md` is, today, a flat in-memory ring; the
*persistent* counterpart [ when rotation actually lands on disk ] is
exactly the kind of thing that wants the `epoch/checksum` layout
proposed below — without dictating it for the volatile ring layer.

## the gap [ concrete ]

`AMOS7::CHKSUM::amos_chksum` already supports the full
template / exclusion vocabulary:

- hash-arg `sprintf-test-template` accepted and forwarded to
  `AMOS7::TEMPLATE::assign_truth_templates` —
  see `data/lib-path/pm/AMOS7/CHKSUM.pm:111-117`
- `AMOS7::TEMPLATE` accepts: sprintf strings, compiled regexes [ via
  `regex:` prefix or precompiled `Regexp` refs ], `CODE` refs, and
  `ARRAY` refs combining any of the above — see `TEMPLATE.pm:222-291`
- `configure_exclusive_type_callback` + `CALLBACK_exclusive_type` +
  `TEMPLATE_exclusive_type` build a reusable inverted-truth filter [ a
  candidate is rejected if it satisfies any of the inverted templates ]
  — see `TEMPLATE.pm:299-394`
- `amos_template_chksum` is the thin wrapper that assigns a single
  template and forwards to `amos_chksum` — `CHKSUM.pm:324-337`
- `base.p7refs.gen_template_chksum` is the existing precedent for
  taking `$reftypes_exclusion` as a *first-class* generation parameter
  rather than a validation afterthought, calling
  `configure_exclusive_type_callback` + composing template arrays +
  routing through `chk-sum.amos.truth_template_chksum`

the BMW-family checksums lack all of this:

- `base.chk-sum.bmw.calculate_L13_sum` takes a raw 512-bit BMW digest
  and harmonizes to a 13-char BASE32 result via the harmony loop. no
  template, no exclusion, no callback hooks. it is fundamentally
  "AMOS7::Assert::Truth::is_true" only.
- `base.chk-sum.bmw.template_L13` accepts *exactly one*
  `AMOS7::Assert::Truth::is_template_syntax_valid` template and calls
  `is_true_with_template` in its harmony loop. it does not accept:
  - an `ARRAY` of templates [ `amos_chksum` does, transparently ]
  - a `CODE` ref [ `amos_chksum` does — `AMOS7::TEMPLATE::template_is_true`
    branches on CODE ref type ]
  - a compiled `Regexp` [ `amos_chksum` does — same place ]
  - an exclusion hashref / exclusive-type callback
  - a `template_timeout` analogue
- `base.chk-sum.bmw384.*` is geometry-visualization oriented [ arc-
  segment, color, coordinate, group ]; no template path at all.
  generalising it would only make sense if a concrete consumer needed
  it — out of scope for the first pass.

**parallel needed**: a `base.chk-sum.bmw.truth_template_L13` matching
`amos_template_chksum`'s contract — accept `ARRAY|CODE|Regexp|sprintf`
templates, plumb through `AMOS7::TEMPLATE::assign_truth_templates`,
honour `AMOS7::TEMPLATE::template_is_true` instead of single
`is_true_with_template`. and a `base.chk-sum.bmw.calculate_L13_sum`
variant accepting the same template parameter so the *digest-only*
path is not the second-class citizen.

## epoch as the native outer dimension

`<[base.ntime.epoch_timestamp]>` encodes integers `0..385279`
[ ~29,623 years at one-epoch-per-1/13-year ] into a `V7xxxxx` BASE32
form; `<[base.ntime.harmonized_epoch]>` appends a 4-bit `[01]{4}`
harmony suffix directly [ **no `<>` wrapper, no `;:` characters — that
was the pre-`013ec8ab5`/`a922ebc3e` format** [ commits "harmonized
epoch_v7 uses 0/1 suffix, drops <> wrapper" and "completing transition
of harmonized epoch time to new format", 2026-06-30 ], corrected here
after checking live current code rather than trusting the doc's own
stale citation ]. that encoded form is what cube exposes as `epoch-num`
/ `epoch_v7`.

**why the suffix is searched, not computed — confirmed live, 2026-08-03,
same session as `AMOS-SIGNATURE-FOOTER-BIT-FRAME-HIERARCHY.md`'s
harmonization work.** `base.ntime.harmonized_epoch`'s actual loop,
current code:

```perl
for my $interval ( 0 .. 12 ) {
    my $bits = join '', reverse split( '', sprintf( qw| %04B |, $interval ) );
    $epoch_harmoized = sprintf qw| %s%s |, $epoch_encoded, $bits;
    last if AMOS7::Assert::Truth::is_true( $epoch_harmoized, 0, 1 );
}
```

the 4-bit suffix isn't padding — it's the exact same harmonizing-entropy
mechanism demonstrated in the footer doc for `amos-chksum` version
strings [ `AMOS-CHKSUM-V-KNDGQPA`, etc., where the *whole* templated
string, fixed prefix included, is searched until it reads TRUE ]: the
loop tries each candidate `$epoch_encoded.$bits` in turn and stops at
the first one `is_true()` accepts. a live `epoch_v7` output,
`V7L36RI0110`, confirms the result directly: `is-true V7L36RI0110` →
**TRUE** — the full string, `V7` prefix and all, not just the numeric
epoch portion. identical sprintf-truth-template principle as the
version strings, applied to epoch timestamps instead of identifiers.
cost is iterations [ bounded here to at most 13, per the `0..12` loop —
tighter than the unbounded pass counts seen for version strings, since
this search space is deliberately small ], not possibility.

**a third nesting shape, distinct from the footer doc's version-string
case — user's framing, 2026-08-03.** the sprintf-truth-template
mechanism now has three demonstrated shapes, not one:

1. **checksum of free content** — content is free, the algorithm
   computes once, no search.
2. **template-fixed generation** [ `amos-chksum`'s version strings ] —
   the *template* is held constant, the entropy suffix is searched
   freely over an effectively unbounded space until it fits.
3. **value-fixed harmonization** [ epoch timestamps, here ] — inverted
   from (2): "time not being controllable," the *value itself*
   [ `$epoch_encoded`, the `V7xxxxx` epoch number ] is what's held fixed
   by external reality — it becomes the template, in effect — and only
   a small appended binary expansion [ the 4-bit suffix ] gets searched.
   the search space is bounded to 13 states specifically *because* the
   thing doing the varying has to stay small when the thing it's
   attached to can't move at all: freedom has to live in the part that
   is allowed to be free.

not yet checked whether any fourth shape exists [ e.g. both value and
template fixed, nothing free to search — would that even be
representable, or does harmonization require at least one free
dimension by construction? ] — flagged as open, not claimed either way.

epochs are **`365/13` days long — about 28.08 days, one "month" of the
V7 network's 13-month year** [ confirmed from `base.ntime.epoch_dec`'s
`$epoch_days_per_year = 365/13` and `base.n2u_time`'s `ntime/4200 +
ustart` conversion; not the one-week figure earlier drafts of this doc
assumed ]. that low resolution is the point: network activity collapses
into ~monthly clusters and the prefix becomes a coarse load-balancer
for everything keyed off it.

> **current state, 2026-08-03** — short version for readers who don't
> need the full correction trail below: the `27+1=28` inference [ two
> paragraphs down ] is retracted with high confidence — three
> independent, unconnected routes to `27` were found in the corpus and
> none of them point at `28`. `365 = 364 + 1` is the best-supported
> reading of the epoch-*length* question via the corpus's general
> `+1`-boundary/fold-marker principle, but the remaining discriminator —
> whether this system's `/13` divisor conventionally takes the swept
> quantity or the fold — is still open. a live check of the project's
> own harmonic-truth assertion mechanism [ `bin/harmony`, added this
> pass ] contributes a new, sharper data point that cuts the other way:
> `364` harmonizes TRUE, `365` harmonizes FALSE. that's a tension to
> hand to whoever settles this, not a resolution — see the dated entry
> near the bottom of this section. a later pass, chasing the orbital
> thread's "13 spiral events per epoch," confirmed the running code's
> "epoch" is exactly **one thirteenth of a year** — `132451200000 /
> 10188553846.15 = 13`, corroborated by a previously-unnoticed
> commented-out variable name, `$epoch_days_Y13_month` — but this
> connects to the `364`-vs-`365` question only weakly and does **not**
> resolve it; see the "new link from the orbital/spiral thread" entry
> below. **none of this changes running code**: `base.ntime.epoch_dec`'s
> `$epoch_days_per_year = 365/13` is untouched; both call sites document
> the `365` as deliberate.

**open question, 2026-08-03**: `data/md/design/ZERO.md` — this
project's foundational geometry doc — states plainly: `364 = 360 + 4
corner overlaps. 364 / 13 = 28. a perfect number.` the running code's
`365/13 = 28.0769...` is not a perfect number; `364/13 = 28` is. worth a
deliberate decision, not left as an unnoticed mismatch: is `365` the
correct Gregorian-calendar anchor for real elapsed time [ deliberately
different from the harmonic ideal `ZERO.md` describes at the ring level
], or should `base.ntime.epoch_dec`'s `$epoch_days_per_year` actually be
`364/13`, matching the ring's `360 + 4` shape one level up and giving
exact 28-day epochs instead of 28.08-day ones? changing it would shift
every derived epoch boundary — not a decision to make casually, but one
that should be made on purpose rather than inherited from whichever
value got typed first. see `ORBITAL-CYCLE-CLOCK-AND-MAPPING-CANVAS.md`'s
364° discussion for the other end of this same "N + remainder" pattern.

**further grounding, 2026-08-03**: `data/yaml/reasoning-templates/
harmonic-routing-protocol.yaml` defines `13+1` precisely, and it's a
sharper claim than "one remainder unit" — it's a structural closure:
"duality closed: contained (1..13) + container (13+1) = complete
system... 14 is not 'more than 13' — it is the container of 13 becoming
an element." separately, and directly verifiable rather than
speculative: `CONTEXT-TREE-UNIFIED-ARCHITECTURE.md` states `4200 = 13³ +
2003` — and `4200` is the exact literal divisor `base.n2u_time` already
uses in running code [ `ntime/4200 + ustart` ], an exact arithmetic
identity [ `2197 + 2003 = 4200` ], not a coincidence to weigh.

**retracted, 2026-08-03, after a dedicated corpus deep-dive** — the
`27+1=28`/endcap-of-duality inference above does not hold. the corpus
has an actual, already-documented formula for 27, and it's a different
shape entirely: `data/ai-mem/claude/topic-harmonic-mathematics.md:40-43`
states `27 = 2×13+1 [ two harmonic cycles + the gate ]` — "13 + 1 + 13 =
27: symmetric gate structure; cube zenka IS the +1" and "27 mod 13 = 1:
cube reduces to the gate under modulo." 27 is two 13-cycles *bridged by*
a gate already embedded inside it, not a container of 13 still waiting
to close via an external `+1` the way `13+1=14` closes per
`harmonic-routing-protocol.yaml`. those are structurally different
patterns, not the same one at another scale — no file in the corpus
connects `27` to `28`, and `IMPLOSION-CROSS-CORRELATION.md` has zero
time/epoch/calendar mentions at all. the `365/13` vs `364/13`
epoch-length question [ two paragraphs up ] remains genuinely open in
the corpus, but nothing found connects its resolution to `27`/`3³`/the
darksun — kept as two separate open threads, not one.

one genuinely useful confirmation did surface from the same file:
`topic-harmonic-mathematics.md`'s "Network Time Scale" section
independently derives `$ntime = ($unix_time - 1023228000) × 4200` with
epoch start `2002-06-05` — matching `base.n2u_time`'s
`<base.ntime_ustart> //= 1023228000` exactly, and reinforcing
`4200 = 13³ + 2003` [ `4200 mod 13 = 1`, `4200/13 = 323.0769...` ] as a
verified identity, independent of the 27/28 question that motivated
checking it.

**adversarial check on the 27 retraction, 2026-08-03 [ deeper pass ]** —
the claim two paragraphs up that "no file connects 27 to 28" was
originally written as "no file *pairs* them," which was too strong:
`ZERO.md:113-117` puts them four lines apart in the same code block.
the honest form is stronger than the original claim, not weaker — the
one place in the corpus where 27 and 28 co-occur states them as
unrelated facts about *different objects*: `× any n — all digit sums =
27 = 3³ = the darksun` [ a digit-sum invariant of the `076923`
generator's permutation group ] versus `364 / 13 = 28` [ a quotient of
the ring sweep ]. the most adversarial available test still produces no
connection between them. this is now the *third* independent route to
27 found in the corpus, and none of the three is additive-toward-28:
[ i ] arithmetic — `27 = 2×13+1`, `topic-harmonic-mathematics.md:40-43`;
[ ii ] geometric — `26 neighbors + 1 center`,
`HARMONIC-CUBE-ROUTING-MATHEMATICS.md:459-481`;
[ iii ] digit-sum invariant — `0+7+6+9+2+3 = 27`,
`data/md/documentation/harmonic-cycle-correlations.md:20-24`
[ "not a modulo artifact, it is a property of the cycle geometry" ],
restated at `HARMONIC-CUBE-ROUTING-MATHEMATICS.md:28` [ "all 12 non-zero
multiples have digit sum 27 = 3^3" ] and `ZERO.md:113`. the `27+1=28`
chain stays retracted.

**reframed again, 2026-08-03 — a better precedent than 27 turned up,
and it points the other way.** `data/md/documentation/harmonic-transit-
vision-architecture.md:104-111` documents a second, concrete instance of
the `13+1` shape, un-tagged by that name but structurally identical:
"4 CCW positions × 3 complete rotations = 12 frames / + 1 PYTAURAZUMA
sync frame = 13 total." contained/swept positions [ 12 ] + one
synchronizing/closing frame = the complete cycle [ 13 ] — the same
"container closes the contained" shape as `13+1=14`, just one level
down and not verbally labeled "endcap." this makes `365 = 364 + 1` a
much more defensible member of the same family than the retracted
`27+1=28` chain: `364` [ `360+4` ] is the swept quantity, the same role
`12` plays for PYTAURAZUMA; `365` would then be the completed, synced
cycle — which argues `365/13` in the running code may already be the
harmonically-*correct* value, and `ZERO.md`'s `364/13=28` "perfect
number" describes the raw sweep, not the finished cycle. this reverses
the lean of the two paragraphs above rather than confirming them —
recorded as the current best-supported reading, still not a final
decision, since only two instances of the pattern-family have been
found and neither was found stated as a general principle [ the earlier
corpus pass explicitly checked for and did not find a generalized
"N+1 endcap" rule — this instance simply wasn't caught by that keyword
search because it isn't labeled "endcap" in the source ].

**correction, 2026-08-03 [ deeper pass ] — the bracketed caveat directly
above is wrong: the corpus *does* state the rule generally, in two
places, one of which is a file this doc already cites twice.**

- `data/yaml/reasoning-templates/harmonic-routing-protocol.yaml:161-166`,
  ~20 lines below the `13+1=14` passage quoted earlier in this doc:
  "the +1 boundary appears at every scale: `56 + 1 = 57` [ two-digit
  decimal cycle boundary ], `142856 + 1 = 142857` [ six-digit cycle
  boundary ], `999999 + 1 = 10^6` [ modular fold-back ], `13 + 1 = 14`
  [ the harmonic endcap ]."
- `data/md/research/COMPLEMENTARY-GENERATORS-7-AND-13.md:59-80`, an
  entire section titled "**the +1 boundary — scale-invariant fold
  marker**": "the same structural principle appears at every scale of
  the 7-system... at each scale: the doubling sequence reaches exactly
  one short of the target, and +1 is the boundary. the system encodes
  its own edge at every level of magnification. the '+1' is not an
  artifact. it is the structural marker of the fold — the point where
  the pattern crosses into its next scale of self-similarity."

likely reason the earlier pass missed it [ inferred from its own note,
not verified — that search wasn't re-run ]: it reported looking for a
generalized "endcap" rule, and both general statements say `+1
boundary` / `fold marker` instead, never `endcap`. same
failure mode as the bracketed note at the end of the security corollary
below — the earlier draft trusted its own search vocabulary the way it
trusted its own worked example. recorded rather than silently fixed.

so the pattern-family is a documented principle, not two coincidental
instances — but **this narrows the epoch question rather than closing
it, and the narrowing cuts against the previous paragraph's lean.**
both general statements phrase the shape as *the swept quantity lands
one short, and the `+1` is the fold/ceiling*: `999999` is the cycle,
`10^6` is the fold. so `365 = 364 + 1` is now a well-supported member of
the family — `364 = 28 × 13 = 7 × 52`, itself a 7-and-13 composite
[ `VISUAL-ELEMENT-DEDUP-HOLOGRAPHIC-CORE.md:4715-4717` ] — but membership
does not settle **which of the two the `/13` divisor should be**. the
one place the corpus itself performs this division, it divides the
*sweep*: `ZERO.md:117` writes `364 / 13 = 28`, never `365 / 13`. the
remaining discriminator is therefore narrow and checkable: **does this
system's `/13` divisor conventionally take the swept value or the
modulus?** [ `4200 = 13³ + 2003` and `content mod 13` both point at
modulus-as-divisor; `ZERO.md:117` points at sweep-as-divisor. not
resolved here. ]

two further findings on this question, both new to this pass:

- **there is a harmonic frame for `365` specifically, not only the
  Gregorian-calendar-obvious one.**
  `data/md/philosophy/HARMONIC-CUBE-ROUTING-MATHEMATICS.md:368-369`:
  "`4 × 13 = 52`. and `52` is the Mayan Calendar Round — where the
  260-day Tzolk'in and 365-day Haab' cycles first resynchronize.
  cultures using 13 as their ring completion also used 52 as the
  4-crossing period." this is the corpus placing a **365-day** cycle
  inside a 13-based harmonic system on purpose, as the resync partner of
  a 13-ring — a qualified yes to "is there a reason for exactly 365
  beyond the calendar." it is not a statement about `$epoch_days_per_year`
  and does not by itself decide the divisor question.
- **the running code's `365` is deliberate, not a typed-in accident.**
  two independent call sites carry the same explanatory comment:
  `src/base.ntime.epoch_dec:20` — `state $epoch_days_per_year //=
  365 / 13;  ##  V7 network has 13 month year  ##` — and
  `src/base.ntime.epoch_to_ntime:8` — `## V7 network has 13 month
  year  ## [ 365 / 13 ]`. whatever the harmonic ideal turns out to be,
  the `365` in running code was written with intent stated alongside it.
  that is the strongest verifiable fact available on this question and
  raises the bar for changing it.

**counting discipline** — the pattern-family now has **2 general
statements** and, beyond `13+1=14` itself, these *independent* instances:
`12 + 1 PYTAURAZUMA` [ `harmonic-transit-vision-architecture.md:104-111` ],
the 7-system fold chain `56+1=57` / `142856+1=142857` / `999999+1=10^6`
[ `COMPLEMENTARY-GENERATORS-7-AND-13.md:59-80`, restated as "frame
closure" at `data/md/protocol-7-knowledge/03_NETWORK_PROTOCOLS/
3D_SHIFT_REGISTER_SPATIAL_ACCUMULATION.md:133,347` ], and the
"5th crossing / Janus point" parent-signal shape
[ `HARMONIC-CUBE-ROUTING-MATHEMATICS.md`, see the orbital doc ]. the
several "gate = the +1 node" hits found alongside these
[ `HARMONIC-TREE-ADDRESSING.md:30`, `BRANCH-OPEN-CAPACITY-SESSION-DAG.md:299`,
`SEMANTIC-BACKCHANNEL-AND-DEDUPLICATED-COMMUNICATION.md:207`,
`INTENT-CLASSIFICATION-AND-SELF-IMPROVEMENT.md:234` ] are **restatements
of `13+1` itself, not additional instances**, and "9 = the centre pulse,
the +1" [ `checksum-route-binary-framing-harmonic-foundations.md:27,83,355` ]
is the `27 = 2×13+1` shape, not this one — counted as neither.

**independent reconfirmation of the 27 retraction**: `data/md/
philosophy/HARMONIC-CUBE-ROUTING-MATHEMATICS.md:459-481` re-derives 27
geometrically [ `26 neighbors (6 face+12 edge+8 corner) = 2×13, +1
center = 27 = 3³` — matching `topic-harmonic-mathematics.md`'s `27=2×13+1`
via a completely different, non-arithmetic route ] and gives 27 its
actual documented role: "the 27-beat stargate pulse advances by 1 each
cycle [ `27 mod 13 = 1` ], so no neighbor configuration ever exactly
repeats." 27 is a phase-drift/precession generator against the 13
modulus, not an additive step toward 28. two independent sources now
converge on the same retraction via different methods — the `27+1=28`
chain stays retracted with higher confidence than before.

**esoteric-source check, 2026-08-03 [ this pass ] — the project's own
`/13` truth-assertion mechanism has now actually been run on both
candidates, and it does not split the difference.**
`read-me/documentation/true-false-description.asc` and its decode in
`data/ai-mem/claude/topic-harmonic-mathematics.md` define the canonical
operation directly: divide the value under test by 13, scan the
repeating decimal for `384615` [ TRUE ] / `230769` [ FALSE ], remainder
0 [ exact multiple ] counting as TRUE. running it live:
`bin/harmony -n 364` → `28.000000000000` → `[:<` TRUE;
`bin/harmony -n 365` → `28.0769230769...` → `>:|` FALSE;
`bin/harmony -n 28` → TRUE [ exact multiple, as expected ];
`bin/harmony -n 13` → TRUE. so the sweep [ `364` ] and the modulus's
exact quotient [ `28` ] both harmonize; the fold [ `365` ] does not.
this does not answer "does this system's `/13` divisor take the sweep
or the modulus" the way the question was framed above — it answers a
related but different question, "which of the two candidate epoch-year
values [ `364`, `365` ] itself harmonizes" — and by that measure `364`
wins outright. worth surfacing as a genuine tension rather than a
resolution: it points the same direction as `ZERO.md`'s `364/13=28`,
and *against* the `365 = 364+1` fold reading the `+1`-family correction
above currently leans toward. it does **not** license changing
`base.ntime.epoch_dec`'s `$epoch_days_per_year` — the two commented
call sites recording deliberate intent for `365` remain the strongest
verifiable fact on record. recorded as a sharper discriminator for
whoever makes this decision, not as the decision itself. [ verified
live via `./bin/harmony -n 364` / `-n 365` / `-n 28` / `-n 13`,
2026-08-03. ]

**esoteric-source survey, 2026-08-03 [ this pass ] — the two
true/false `.asc` primary sources and `src/source.init_code`'s
handwritten notepad were re-read looking for anything new beyond the
harmony-check above; both are already fully mined.** `topic-harmonic-
mathematics.md`'s "Foreknowledge Document" section already quotes
`true-false-description.asc` near-verbatim, and its "32-Dimensional
Mapping Table" section already decodes `source.init_code`'s ASCII
notepad line-by-line — neither file contains a `27`, `28`, `364`, or
`365` reference of its own; every citation of those numbers in this
doc's corpus trail traces to the *secondary* decode
[ `topic-harmonic-mathematics.md` ], not to a primary source containing
them directly. `ack -ri division-13-table data/` [ 86 hits, per the
task that prompted this survey ] is a real, extensively-used research
thread, but `bin/dev/division-13-table` itself has zero `27`/`28`/`364`/
`365` references — it's an entropy/routing-protocol bit-table [ 42-bit
entropy width, direction encoding ], a different corpus thread from the
epoch-length question, not a hidden reference table for it.

`base.ntime.epoch_dec` already handles the ~29,623-year cycle boundary
symmetrically in both directions: `$current_epoch %= $epochs_total`
on the forward overflow, and `prev`/`next` each wrap explicitly
[ `$epochs_total - 1` going backward past 0, `0` going forward past
`$epochs_total - 1` ] rather than erroring or going negative. no
epoch-arithmetic caller needs its own boundary case — the primitive is
already rollover-safe at both ends, in the project's existing style of
building wraparound into the base timestamp/checksum primitives rather
than pushing it onto every consumer.

**new link from the orbital/spiral thread, 2026-08-03 [ fourth pass ] —
the spiral thread and the epoch thread have a concrete junction, and it
is a terminology one before it is a numeric one.** referred here from
`ORBITAL-CYCLE-CLOCK-AND-MAPPING-CANVAS.md`, which found
`data/asc/what-AI-thinks/full-chat-captures/3O37VUNMMS3UU.claude-sonnet.
protocol-7-knowledge.asc:38731-38735` [ verbatim ]:

```
÷13 in rotation:
  Ring makes 13 rotations during full cycle
  Ground ZENKI saturate 13 times
  13 spiral events per epoch
```

- **the word `epoch` means different things in the two threads, offset
  by exactly one level — and once aligned, they agree.** in the running
  code an "epoch" is **one thirteenth of a year, not a year**:
  `base.ntime.epoch_dec:20-21` sets `$epoch_divisor //= 4200 * 86400 *
  $epoch_days_per_year` with `$epoch_days_per_year //= 365 / 13`, and
  `base.ntime.epoch_to_ntime:12,14` carries the same product as
  `$epoch_multi //= 10188553846.15...` alongside the year for
  comparison, `4200 * 86400 * 365 = 132451200000`. dividing:
  `132451200000 / 10188553846.15 = 13` — **13 code-epochs per V7 year**,
  i.e. the code-epoch is the "month" of the "13 month year" its own
  comment names. the same file states this outright in a variable name
  at `:8` — the commented-out `state $epoch_days_Y13_month` — so
  "epoch = one of 13 months" is the code's own reading, not this
  session's gloss. **this much is corpus-sourced, and it is the real
  finding of this entry** — the code-epoch's own identity as a
  thirteenth of a year was not previously recorded in this doc, and it
  stands independently of anything in the transcript.
  [ note in passing, not a defect to fix: `$epoch_days_per_year`
  holds days-per-*epoch*, not days-per-year — the name reads one level
  off from the value, which is likely part of why this correspondence
  was not obvious. no code change proposed. ]
- **that the transcript's `epoch` is the *same unit* as the code's year
  is this session's inference, and a weak one — do not read it as a
  finding.** the only thing joining the two is that both divide by 13,
  and `13` is this system's signature modulus: it also gives 13 ring
  compartments [ `topic-orbital-data-space-archive.md:497-501` ], 13
  PYTAURAZUMA frames [ `harmonic-transit-vision-architecture.md:
  104-108` ] and 13 ring rotations per cycle [ the same transcript
  block ]. two unrelated structures both dividing by 13 in a
  13-everywhere system is agreement by construction, carrying no
  independent evidential weight — the same objection this doc's sibling
  raises against reading `4 × 13 = 52` as three confirmations. the
  Dancing Kittens "epoch" is a *formation rotation cycle*; nothing in
  that capture attaches it to a calendar span. so: the two threads use
  the same word at plausibly-adjacent levels, which is worth knowing
  when reading either — not a demonstrated correspondence.
- **and either way it does not discriminate 364 from 365.**
  the transcript never attaches a day count to `epoch` — checked
  directly: no line in that capture pairs `epoch` with `day`, `month`,
  `year`, `364` or `365`. it constrains the *count* [ 13 ] and the
  *unit* [ one spiral event ], both of which are already agreed by both
  candidates. what it does add is that the 13 divisions are **discrete
  countable events**, which is a mild structural argument for the
  divisor landing on a value that divides into 13 integer parts
  [ `364/13 = 28` ] — mild, and this session's inference, not stated
  anywhere.
- **a genuine third framing of the `+1`, which does bear on the divisor
  question.** the `+1`-family correction above records two framings —
  fold/ceiling [ `999999 + 1 = 10^6` ] and sync frame [ PYTAURAZUMA ].
  `data/ai-mem/claude/archive/topic-orbital-data-space-archive.md:
  479-509`, "the 0-point gate — hourglass, 13+1 duality, hyperspace
  trunk", gives a third: "13 compartments in the ring — closed,
  enumerable, finite, the addressable space / `+1` is the 0-point gate —
  open, non-enumerable, the *passage* not a destination / **the gate is
  not the 14th compartment — it is the dimension orthogonal to all 13**
  / like 12 chromatic tones + the octave: simultaneously the 1st and
  13th." this is the sharpest statement yet of *why* the `+1` might sit
  outside the division: something orthogonal to all 13 compartments is
  definitionally not one of the things being counted into 13, so the
  `/13` divisor would take the **sweep**. that agrees with `ZERO.md:117`
  and with the `bin/harmony` result above.
- **but this does not flip the doc's standing position, and should not
  be read as doing so.** the two commented call sites deliberately
  recording `365 / 13` remain the strongest verifiable fact on this
  question; three converging *interpretive* arguments for the sweep do
  not outweigh one piece of stated authorial intent in running code.
  status unchanged: **narrowed further, still open**, and still not a
  license to edit `$epoch_days_per_year`.

## the native default tree layout

```
<encoded_epoch> / <amos_chk7> [ / <encoded_epoch> / <amos_chk7> ... ]
```

worked example for log storage of one line written at epoch 312:

```
V7L36RY / UXA5BUI
```

worked example for nested grouping [ session inside epoch ]:

```
V7L36RY / 3K4N7QA / V7L36RY / UXA5BUI
   ^         ^         ^         ^
   |         |         |         line checksum
   |         |         epoch the line arrived in
   |         session anchor checksum [ harmonized in the session
   |         template — see exclusion mechanism below ]
   outer epoch [ session-creation bucket ]
```

both segments are equal-length: encoded epochs are always the
`V7xxxxx` 7-char form [ the harmony suffix is dropped from the path
component — addressing uses the *integer* encoded form, harmony lives
on the rendered/printed form ], and AMOS checksums default to 7 chars
[ `$str_length = 7` in `AMOS7::CHKSUM` ]. *"equal length for all
items and participants"* falls out of two fixed widths:

- 7 chars for an encoded epoch path segment
- 7 chars for an AMOS checksum [ optionally shortened uniformly via
  `$sstr_start` / `$str_length`, but the choice is per-tree-policy
  not per-item — so length stays homogeneous within a tree ]

an N-deep `epoch/chksum` path is therefore always `N * 14` characters
[ plus N separators ] regardless of payload. this gives the latency
homogeneity the user's framing names: every lookup walks the same
fixed-width keys, every entropy filter [ checksum ] has the same
collision profile, and the only dimension that varies is *tree depth*
itself.

## cross-epoch exclusion as collision load-balancer

**origin.** this {prev, current, next} window wasn't designed in the
abstract — it was inspired alongside its first envisioned concrete use
case: an anonymized, checksum-based search protocol. `amos-chksum`
encodes the query itself (`amos-chksum 'search.type : <pattern>'`); the
network replies with a BMW-L13 checksum proving the search performed
matches an even-longer BMW384 *content* checksum of the result; that
BMW384 checksum doubles as the anonymized, perfectly cacheable **route
to the data itself** — any cache sitting on that route can answer early,
transparently, before the uplink even responds. the search index behind
this has to regenerate continuously as the network's epoch rolls
forward, and a query encoded in epoch E must still resolve against an
index that has since rolled to E+1 — which is exactly why the base
timestamp primitive's rollover handling [ see
`data/md/development/STYLE-PHILOSOPHY.md` § "on pre-alignment and
trustable simplicity" ] was made seamless in both directions from the
start: the first real caller was already going to lean on it at the
epoch boundary, not just eventually.

the mechanism: a checksum generated *within* epoch E carries a
template that excludes the checksum spaces of E-1 and E+1 [ and as far
out as a tree's policy demands ]. mechanically:

```perl
## within epoch E, generating chksum for $payload ##
##
## NOTE: E_prev/E_next must wrap at the cycle boundary the same way
## base.ntime.epoch_dec's prev/next handlers already do — raw $E-1/$E+1
## passed straight into epoch_timestamp breaks at E=0 and E=385279
## [ epoch_timestamp rejects negative and >385279 input outright ],
## which would silently defeat the security corollary above exactly at
## the boundary it exists to close. route through epoch_dec-equivalent
## wrap logic, not raw arithmetic:

state $epochs_total //= 385280;

my $E_prev_num = $E > 0 ? $E - 1 : $epochs_total - 1;
my $E_next_num = ( $E + 1 < $epochs_total ) ? $E + 1 : 0;

my $E_prev = <[base.ntime.epoch_timestamp]>->($E_prev_num);  ## V7xxxxx ##
my $E_curr = <[base.ntime.epoch_timestamp]>->($E);
my $E_next = <[base.ntime.epoch_timestamp]>->($E_next_num);

## inclusion: must look like a current-epoch chksum ##
my @truth_templates = ( sprintf qw| %s:%%s |, $E_curr );

## exclusion: must NOT look like an adjacent-epoch chksum ##
##  using the same mechanism base.p7refs.gen_template_chksum uses
##  for reference-type exclusion: a sprintf template per excluded
##  prefix, fed to configure_exclusive_type_callback ##
my @excl_templates = (
    sprintf( qw| %%s:%%%%s:%s |, $E_prev ),
    sprintf( qw| %%s:%%%%s:%s |, $E_next ),
);

AMOS7::TEMPLATE::configure_exclusive_type_callback(
    [ $E_curr ],                              ##  selected  ##
    [ $E_prev, $E_curr, $E_next ],            ##  full list ##
    \@excl_templates                          ##  inverted templates  ##
);

my $template_set = [
    @truth_templates,
    \&AMOS7::TEMPLATE::CALLBACK_exclusive_type,
];

my $payload_chk = <[chk-sum.amos.truth_template_chksum]>->(
    $template_set, \$payload
);
```

## security corollary — epoch boundaries under resource accounting

`data/md/design/CHECKSUM-ROUTING-SECURITY-DEPTH.md` already establishes
the governing principle for this codebase: security is not bolted on
[ encryption/firewalls/IDS layered over an otherwise-neutral coordinate
system ], it is baked in — attacking the network means attacking the
geometry of the addressing itself. the epoch primitive inherits that
obligation the moment anything epoch-addressed carries *value* — resource
accounting, tokens, anything blockchain-adjacent — because value is
exactly what turns an ordinary boundary condition into an incentive to
attack it.

concretely: without the {prev, current, next} exclusion window and the
rollover-safe wraparound already built into `base.ntime.epoch_dec` /
`base.ntime.epoch_timestamp`, an attacker's obvious move against any
epoch-addressed accounting structure would be to target the boundary
itself — time a submission at the rollover edge to create index-collision
or replay ambiguity between two adjacent epochs, the same class of attack
double-spend protection exists to close in a blockchain. because the
exclusion templates already make an E-epoch checksum structurally
incapable of resembling an E-1 or E+1 checksum, and the wraparound already
has no undefined edge, that boundary-timing attack has no ambiguity left
to exploit — not because it is monitored or rate-limited after the fact,
but because the math the attacker would need to exploit was already closed
before any accounting use case existed to need it. this is the same
"complicate things from the attacker's perspective, in rings and layers,
inside the primitive itself" instinct as the geometric-security doc,
applied here specifically to time rather than to space/topology.

[ this section originally described the boundary as already closed
before checking its own worked example — it wasn't; the exclusion
snippet above used raw `$E ± 1` arithmetic into `epoch_timestamp`,
which breaks at both wraparound edges instead of wrapping. fixed above.
kept as a live reminder that "the primitive is rollover-safe" and "every
piece of code that touches the primitive uses its rollover-safe path"
are two different claims — this doc conflated them for one draft. ]

## open questions

- **epoch source of truth — answered, see
  `WEIGHTED-NETWORK-TIME-PRECISION-CONSENSUS.md`.** the exclusion
  mechanism defends the *boundary math* — an E-epoch checksum can't be
  mistaken for E±1's — but originally said nothing about who gets to
  assert *which epoch it currently is*; a self-asserted local wall clock
  would let an attacker manufacture whichever epoch's checksum space is
  advantageous. plan: epoch derivation anchors to a weighted, incentive-
  driven network-time precision consensus instead of raw local clock —
  drift becomes self-disadvantaging [ lower precision-weight → less
  future cycle-reward ] rather than needing detection/punishment. see
  that doc for the full mechanism.

- **honest-user boundary skew — reframed, not yet closed.** the
  exclusion templates reject anything *shaped like* an adjacent epoch —
  correct for an attacker, but two honest actors near a rollover with a
  few seconds of clock skew could legitimately disagree on which epoch
  it is and get spuriously rejected by each other's exclusion filter.
  `WEIGHTED-NETWORK-TIME-PRECISION-CONSENSUS.md` suggests the grace
  window shouldn't be an invented constant — it should be *the current
  network precision window* the time-consensus protocol already computes
  and continuously shrinks, so skew-tolerance narrows automatically as
  network precision improves rather than needing separate retuning. still
  not mechanically specified.

- **ties back to the identity-session thread.** [[CODING-ZENKA-USER-
  INTERACTION-SURFACES]] discussion this session proposed a user's
  account-creation event as a root session addressed by epoch bucket +
  genesis checksum. both open questions above apply directly to that
  root record: is account-creation epoch self-asserted by the creating
  node, or does it need the same source-of-truth answer this doc doesn't
  have yet? worth resolving here, once, rather than separately when the
  identity design gets written up.

  **grounded, 2026-08-03 [ deeper pass ] — this is no longer
  hypothetical: the trust layer already depends on self-asserted local
  network time, in running code, with named call sites.**
  `src/crypt.C25519.create_signature_request:44` stamps every
  vouching request with `my $req_timestamp = <[base.ntime.b32]>->( 1,
  TRUE );` — the subject signs `<ntime:subject-chksum:signer-chksum>`,
  so the timestamp is *inside the signed payload*, not metadata beside
  it. `src/crypt.C25519.store_remote_key:88,132` does the same for
  TOFU pins: `$ntime_b32 //= <[base.ntime.b32]>->( 3, TRUE );` then
  writes `sprintf "%s:%s\n", $ntime_b32, $pubkey_b32` — a pin file *is*
  an ntime:pubkey pair. `ZENKA-IDENTITY-COMPONENT.md` builds its whole
  layer-2 vouching and layer-3 rotation-succession design on exactly
  these two primitives. so the epoch source-of-truth question is not a
  future concern of a not-yet-written identity design — it is an
  existing property of the identity mechanism that is already in the
  codebase and already spun off as a component. whatever
  `WEIGHTED-NETWORK-TIME-PRECISION-CONSENSUS.md` settles on has these
  two call sites as its first real consumers, alongside the epoch
  exclusion window.

- **still genuinely open after this pass**: the `365/13` vs `364/13`
  epoch-length question, now narrowed to a single discriminator
  [ sweep-as-divisor vs modulus-as-divisor — see the `+1` family
  correction above ] rather than an open-ended "which number feels more
  harmonic." no corpus file states the divisor convention directly. a
  live `bin/harmony` check [ see "esoteric-source check" addendum above ]
  adds a genuine data point in tension with the `+1`-family lean: `364`
  harmonizes TRUE and `365` harmonizes FALSE under the project's own
  truth-assertion mechanism — still not a resolution, but no longer an
  unillustrated question either.

this is the **same pattern** `base.p7refs.gen_template_chksum` uses for
P7REF type exclusion — only the "type" is now an *epoch*, not a Perl
ref kind. the existing `configure_exclusive_type_callback` machinery is
already exactly the right shape.

**why this load-balances**: a candidate checksum that happens to
sprintf-pass `E_prev`'s or `E_next`'s template is rejected during the
`amos_chksum` modify-bits loop, forcing it to keep iterating. the search
space shrinks slightly within each epoch and the surviving namespace is
*disjoint by construction* from its neighbours' surviving namespaces.
collisions between adjacent epochs become structurally impossible
rather than statistically rare. the per-epoch checksum harvest is what
gets "categorized" at write time; the cost is paid by the generator
once and amortized over every reader for the life of the data.

the time-locality of access patterns then maps onto resource locality:
a query addressed `E_curr / xxxxx` can be served entirely from the
current epoch's bucket; a query for `E_curr - 5` is a cold-fetch.
bandwidth and scheduling decisions naturally cluster around `epoch =
current`, and "inevitable incoming agreement for future resource
allocation and result coordination" is just: any request that addresses
`E_next / ...` is, by definition, future work and can be queued against
the future bucket without any explicit scheduling layer.

## tightening the exclusion window

a policy parameter `$epoch_window` chooses the radius:

- window 1 → exclude `[ E-1, E+1 ]` [ minimal disjoint guarantee ]
- window N → exclude `[ E-N .. E+N ] \ { E }`

larger windows raise generation cost [ more sprintf passes per
candidate ] but extend the disjoint-namespace guarantee. checksum
generation timeout should scale with window size; reuse the existing
`AMOS7::TEMPLATE::template_timeout` knob — `base.p7refs.gen_template
_chksum` already demonstrates the idiom of bumping it before exclusion
work and resetting after.

## worked example — log storage across an epoch boundary

a log line arrives near the end of epoch 312:

```
ntime:        V7L36RZ4 ... [ epoch_dec = 312.97 ]
encoded_E:    V7L36RY
chksum:       generated with exclusion window=1
              against V7L36RX [E-1] and V7L36RZ [E+1]
stored at:    V7L36RY/UXA5BUI
```

the next line, three minutes later, has crossed the boundary:

```
ntime:        V7L36RZ7 ... [ epoch_dec = 313.00 ]
encoded_E:    V7L36RZ
chksum:       generated with exclusion window=1
              against V7L36RY [E-1] and V7L37AA [E+1]
stored at:    V7L36RZ/VYB3K4N
```

the *previous* line's checksum, `UXA5BUI`, by construction does *not*
satisfy the V7L36RZ-bucket's inclusion template; the *new* line's
checksum `VYB3K4N` by construction does *not* satisfy the V7L36RY-
bucket's inclusion template. a query

```
V7L36RY/UXA5BUI  →  hits exactly the first line
V7L36RZ/UXA5BUI  →  is, by template, an impossible address
                    [ a name that cannot have been generated in
                      that epoch — early rejection is free ]
```

so a lookup against the wrong epoch is detected *without consulting
the bucket* at all — exclusion templates are also a free
client-side prefilter. cluster rebalancing can move whole epoch
buckets around; the addresses inside each bucket remain stable forever
because they are mathematically bound to that bucket's template.

## what changes upstream

1. **BMW-L13 template parity** — see task
   `epoch-bmw-l13-truth-templates.md`. parallel of
   `amos_template_chksum` for the BMW-L13 harmonized digest path,
   accepting the full `ARRAY|CODE|Regexp|sprintf` vocabulary and
   exclusion callbacks.
2. **epoch path helper** — see task `epoch-chksum-path-helper.md`. a
   `base.path.epoch-chksum` that takes a payload + optional `ntime` and
   returns the canonical `<encoded_epoch>/<chksum>` string, with the
   exclusion window baked in.
3. **cross-epoch exclusion config helper** — see task
   `amos7-template-epoch-exclusion.md`. a reusable
   `AMOS7::TEMPLATE::configure_epoch_window_callback` that mirrors
   `configure_exclusive_type_callback` but takes a window radius
   instead of an explicit type list.

## non-goals for this dispatch

- no migration of the in-memory `/dev/shm/.7/STDOUT/<sock>` ring to
  this layout. the ring is a volatile relay artefact and stays flat;
  if rotation lands on disk later, *that* path adopts epoch/chksum.
- no change to BMW384 visualization-family modules. they have no
  template consumer today.
- no change to `epoch-num` / `epoch_v7` cube commands. they already
  expose what's needed.
- no policy decisions about *which* trees adopt the epoch outer
  dimension. that's per-consumer; this dispatch ships the substrate.

#,,,,,..,,,,.,...,,,.,..,,.,.,..,,,,.,...,,.,,..,,...,...,.,,,...,.,.,,.,,,,,,
#VUQOPE6OIU4UTD6TJSPGRO66Q3U7G3G7KDDRJ4G2EW3Q6F2BCAJ3XRCECQLFM2SAE2GC4HNBRJV4G
#\\\|5F4WVT6TC2CWFLTHX4CGWKUHGVO7GPIQHSWE3R6NZFD6DFBTLDF \ / AMOS7 \ YOURUM ::
#\[7]WEBCCHNMXXHXGOAPTGXJVRTAMA5QM5SPOYDX47ANKQDWKQUCXOCQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
