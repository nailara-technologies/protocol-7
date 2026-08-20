# BMW checksum family — template + exclusion expansion

## relation to prior docs

direct continuation of
`data/md/design/EPOCH-CHECKSUM-EXCLUSION-ADDRESSING.md` and its
narrowly-scoped follow-up task `data/tasks/epoch-bmw-l13-truth-
templates.md`. that task ships ONE templated module
[ `base.chk-sum.bmw.truth_template_L13` ] parallel to
`AMOS7::CHKSUM::amos_template_chksum` for the L13 harmonized digest
path. *this* doc widens the lens: the same `AMOS7::TEMPLATE` contract
[ `assign_truth_templates`, `template_is_true`, `template_timeout`,
`configure_exclusive_type_callback`, `CALLBACK_exclusive_type`,
`TEMPLATE_exclusive_type` ] should be available across the entire BMW
family, not just L13 — and the *minimum-duplication* shape for that is
a single shared chokepoint that every variant routes through.

## the chokepoint [ identified, with evidence ]

the BMW family today splits into two structural groups:

### group I — pure digest/encoding [ no template surface needed ]

```
base.chk-sum.bmw.ctx              Digest::BMW context factory; pure
base.chk-sum.bmw.encode_digest    binary digest → BASE32 [ encode_b32r ]
base.chk-sum.bmw.512_32           bmw_512 + encode_b32r [ no harmony loop ]
base.chk-sum.bmw.224.B32          bmw_224 + encode_b32r [ no harmony loop ]
base.chk-sum.bmw.strsum           string → digest [ no harmony loop ]
base.chk-sum.bmw.filesum          file → digest [ no harmony loop ]
```

these subs do not perform any harmony-truth iteration. they are
fixed-output functions of input bytes. wiring `AMOS7::TEMPLATE` into
them is a category error: there is no candidate-rejection loop in
which the template's verdict could change behaviour. they remain as
they are. consumers that *want* a template-validated form of a fixed
digest invoke the templated harmony variant of that digest's family
[ next group ] rather than these.

### group II — harmonized B32 with rejection loop [ template surface ]

```
base.chk-sum.bmw.calculate_L13_sum    digest-in,  L13 harmony loop
base.chk-sum.bmw.template_L13         strings-in, L13 harmony loop
base.chk-sum.bmw.filesum.56.TRUE      file-in,    56-bit AMOS7::13 loop
base.chk-sum.bmw.B-32-56.TRUE         string-in,  56-bit AMOS7::13 loop
base.chk-sum.bmw.str-b32.L13          b32-pre-encode wrapper of L13
base.chk-sum.bmw.L13-str              string→L13 wrapper [ pre_init/etc. ]
```

the two L13 modules carry **identical harmony-loop bodies** [ compare
`calculate_L13_sum:31-40` against `template_L13:41-50` ]; only the
validator predicate differs:

- `calculate_L13_sum` :  `AMOS7::Assert::Truth::is_true( $result_str_B32, 0, 1 )`
- `template_L13`      :  `is_true_with_template( $template, $result_str_B32, 0, 1 )`

both also share the same per-segment entropy mix [ identical bodies in
the `foreach my $segment_num ( unpack qw| Q8 |, $bmw_512_bin )` block
across both files ].

the `*.56.TRUE` modules delegate to `AMOS7::13::key_56`; that delegation
already handles its own harmony loop internally and accepts a single
`is_true_with_template`-style template [ see
`base.chk-sum.bmw.filesum.56.TRUE:49-63` ]. `AMOS7::13::key_56` is
*not* a Protocol-7 module file — it lives under
`data/lib-path/pm/AMOS7/13.pm` and is in scope of AMOS7 itself. that
makes it a separate, larger change with separate review surface; this
doc keeps it as a follow-up rather than a primary deliverable.

### the chokepoint

extract the duplicated L13 harmony-loop body into a shared module:

```
base.chk-sum.bmw.harmonize_L13
```

contract [ proposed ]:

```perl
##  param: $bmw_512_bin   binary 64-byte BMW512 digest
##  param: $validator     CODE ref:  ( $result_str_B32, $bits_num ) -> bool
##  returns: 13-char BASE32 string [ true under both validator + true_int ]
```

both `calculate_L13_sum` and `template_L13` collapse to one-line
wrappers — they each construct the appropriate validator and delegate:

```perl
##  calculate_L13_sum  ##
my $validator = sub { AMOS7::Assert::Truth::is_true( $ARG[0], 0, 1 ) };
return <[base.chk-sum.bmw.harmonize_L13]>->( $bmw_512_bin, $validator );

##  template_L13  ##  [ legacy single-template path ]
my $validator = sub {
    is_true_with_template( $template, $ARG[0], 0, 1 )
};
return <[base.chk-sum.bmw.harmonize_L13]>->( $bmw_512_bin, $validator );
```

now `truth_template_L13` from
`data/tasks/epoch-bmw-l13-truth-templates.md` becomes the *third*
one-line wrapper: it assigns via `AMOS7::TEMPLATE::assign_truth_
templates`, builds a validator that calls `template_is_true` [ honoring
`template_timeout` ] + `true_int`, and routes to the same chokepoint.

**timeout discipline** lives in the chokepoint, not the wrapper. the
chokepoint inspects `AMOS7::TEMPLATE::template_count()` at entry; if
templates are assigned it records `$time_start` and on each iteration
checks against `template_timeout()` — mirroring
`AMOS7::CHKSUM::amos_chksum`'s shape at `CHKSUM.pm:217-238`. wrappers
that don't use templates pay zero cost [ `template_count() == 0`
short-circuits ].

## the family-wide consequence

once the chokepoint exists, adding *new* templated variants is mostly
contract-naming. each new `truth_template_*` wrapper is:

1. an `AMOS7::TEMPLATE::assign_truth_templates` call before the digest
   path
2. a closure validator wrapping `template_is_true` + the digest's
   native truth predicate
3. a delegation into either `harmonize_L13` [ for L13 paths ] or
   directly into `key_56` [ for 56-bit AMOS7::13 paths ] passing the
   template/validator through
4. a matching `reset_truth_templates` at the exit

so the family-wide deliverable is:

- `base.chk-sum.bmw.harmonize_L13`         [ chokepoint, new ]
- `base.chk-sum.bmw.calculate_L13_sum`     [ rewrap onto chokepoint ]
- `base.chk-sum.bmw.template_L13`          [ rewrap onto chokepoint ]
- `base.chk-sum.bmw.truth_template_L13`    [ NEW, from L13 task ]
- `base.chk-sum.bmw.str-b32.L13`           [ optional thin templated form ]

the corresponding *string-in* and *file-in* templated wrappers for the
56-bit AMOS7::13 family [ `truth_template_strsum_56`,
`truth_template_filesum` ] are listed as follow-ups; they touch
`AMOS7::13::key_56`'s contract and are deferred until L13 ships.

## BMW384 geometry — inherits transparently

read of `base.chk-sum.bmw384.angle-bits`, `arc-segment`, `color`,
`color-dist`, `coordinate`, `coordinate-str`, `group`,
`init_code`, `pre_init`: every geometry sub is a *pure function* of a
48-byte BMW384 digest [ or of color/coordinate values already derived
from one ]. none harmonize; none iterate; none reject candidates.

template support therefore belongs **upstream of the geometry call**,
not inside it. a consumer that wants "coordinates of a digest that
satisfies template T" pre-harmonizes via:

```
1. produce a BMW384 binary digest that satisfies the template via a
   templated harmony loop [ the 384-bit analogue of harmonize_L13
   would be base.chk-sum.bmw.harmonize_384 — listed below as future
   work, NOT in this dispatch's scope ]
2. pass the resulting digest to bmw384.coordinate / bmw384.color /
   bmw384.arc-segment / etc.
```

since none of the existing BMW384 geometry callers today need a
templated source-digest path, **no BMW384 geometry sub gets touched in
this dispatch**. when a concrete consumer surfaces, the addition is
mechanical: one new `harmonize_384` chokepoint + one templated
producer wrapper, with no changes to the eight geometry subs.

## contract summary [ new and extended subs ]

### new

```
base.chk-sum.bmw.harmonize_L13
  param   = $bmw_512_bin, $validator_coderef
  returns = 13-char BASE32 string [ both validator AND true_int true ]
  honors  = AMOS7::TEMPLATE::template_timeout() when template_count() > 0
  notes   = MUST be pure with respect to the validator; the validator
            sees ( $result_str_B32, $bits_num ) and returns a boolean
```

```
base.chk-sum.bmw.truth_template_L13
  param   = $template_param, <string>[, <string>..,]
  returns = 13-char BASE32 string satisfying every template + true_int
  templates: sprintf | Regexp | CODE | ARRAY of any of those, per
             AMOS7::TEMPLATE::assign_truth_templates
  exclusion: include \&AMOS7::TEMPLATE::CALLBACK_exclusive_type in the
             ARRAY after configure_exclusive_type_callback to plumb
             cross-epoch [ or any other type-based ] exclusion
```

### extended [ behaviour preserved, internals rewrapped ]

```
base.chk-sum.bmw.calculate_L13_sum  → delegates to harmonize_L13
base.chk-sum.bmw.template_L13       → delegates to harmonize_L13
```

bit-identical output for the same inputs. regression net: any existing
caller that does not specify a template observes no change. covered
by the acceptance check in `epoch-bmw-l13-truth-templates.md` plus a
diff-by-fixture pass before/after the rewrap.

## reconciliation with `epoch-bmw-l13-truth-templates.md`

the L13 task **stands** [ its acceptance criteria are exactly what
shipping the L13 template path requires ], but its implementation is
now layered on top of the chokepoint deliverable in this doc:

- task `bmw-harmonize-l13-helper.md` ships the chokepoint and rewraps
  the two existing L13 modules onto it
- task `epoch-bmw-l13-truth-templates.md` then becomes "add the
  `truth_template_L13` wrapper that delegates to the chokepoint",
  significantly smaller than its original full re-implementation scope
- task `bmw-truth-template-family.md` collects the family-wide
  additions [ B32 + 56-bit string/file templated wrappers, BMW384
  harmonize_384 placeholder ] as the *next* tranche, depending on the
  chokepoint landing first

ordering is therefore strict: chokepoint first, L13 templated wrapper
second, family expansion third. a one-line **supersession header** is
added to `epoch-bmw-l13-truth-templates.md` pointing at this doc and
at `bmw-harmonize-l13-helper.md`; the L13 task is *not* rewritten
[ its acceptance criteria remain authoritative ].

## non-goals [ for this dispatch ]

- no touch to `AMOS7::13::key_56` itself [ deferred; that change has
  its own review surface and a separate task should it be needed ].
- no touch to any `base.chk-sum.bmw384.*` geometry sub. the 384-bit
  harmonized-digest path [ `harmonize_384` ] is named only as future
  work, not implemented here.
- no signature-footer regeneration, no whitelist edits, no
  update-signatures — same constraints as the parent design doc.
- no change to the existing `bmw.filesum.56.TRUE` template path until
  the family-wide tranche lands; its current single-template form
  remains valid and will gain the multi-template ARRAY/CODE/Regexp
  vocabulary in `bmw-truth-template-family.md`.

## consolidation into AMOS7::CHKSUM [ scope widening ]

user direction [ 2026-06-10, verbatim ]: *"we can include BMW into the
AMOS7 module"* and *"same with jhash for a really fast one, also
32-bit."* — i.e. promote BMW [ L13 + raw digests + BMW384 access ] and
JHA [ the fast 32-bit Jenkins hash family ] into
`data/lib-path/pm/AMOS7/CHKSUM.pm` as first-class exported subs
alongside `amos_chksum` / `amos_template_chksum`. each `base.chk-sum.*`
module then becomes a thin zenka-callable wrapper around the AMOS7
implementation, rather than the implementation itself living inside
the zenka module file.

this is the **same chokepoint move** as the L13 harmonize work, one
level up: instead of "extract the harmony loop from two zenka
modules," extract *the whole family* from its zenka modules into
AMOS7. the templated/exclusion vocabulary then needs only to be
implemented once at the AMOS7 level — every `base.chk-sum.*` caller
inherits it transparently.

### what already exists in AMOS7::CHKSUM

- `amos_chksum`               [ exported ]
- `amos_template_chksum`      [ exported ]
- internals share `AMOS7::TEMPLATE`, `AMOS7::Assert::Truth`,
  `AMOS7::CHKSUM::ELF`, `Digest::BMW` [ for the AMOS digest path ],
  `Crypt::Misc::encode_b32r`
- one BMW384 sister module already lives under
  `data/lib-path/pm/AMOS7/CHKSUM/BMW384.pm` [ used by
  `base.chk-sum.bmw384.*` via `AMOS7::CHKSUM::BMW384::bmw384_*` ]

so AMOS7 already half-owns BMW: the geometry layer is in a sister
package, but the raw `Digest::BMW`-based digest + L13 harmony + 56-bit
key derivations are scattered across zenka modules.

### proposed AMOS7::CHKSUM public surface [ post-consolidation ]

```
package AMOS7::CHKSUM;

@EXPORT = qw|

    ##  AMOS  [ existing ]
    amos_chksum
    amos_template_chksum

    ##  BMW  [ new — moved from src/base.chk-sum.bmw.* ]
    bmw_digest                 ##  ( $bits, $data )   → binary digest
    bmw_b32                    ##  ( $bits, $data )   → BASE32 string
    bmw_l13                    ##  ( $data )          → 13-char B32 L13
    bmw_template_l13           ##  ( $template, @data ) → templated L13
    bmw_harmonize_l13          ##  ( $bmw_512_bin, $validator ) → L13
    bmw_56_true                ##  ( $data, $key? )   → AMOS7::13 56-bit
    bmw_template_56_true       ##  ( $template, $data, $key? )

    ##  BMW384  [ re-exported from AMOS7::CHKSUM::BMW384 for one home ]
    bmw384_angle_bits
    bmw384_arc_segment
    bmw384_color
    bmw384_color_dist
    bmw384_coordinate
    bmw384_coordinate_str
    bmw384_group

    ##  JHA  [ new — moved from src/base.chk-sum.jha.* ]
    jha_num                    ##  ( @data ) → 32-bit unsigned int
    jha_hex                    ##  ( @data ) → 8-char hex
    jha_b32                    ##  ( @data ) → BASE32 string
    jha_b64u                   ##  ( @data ) → URL-safe base64
    jha_b32_harmonized         ##  ( @data ) → harmonized BASE32
    jha_template_b32           ##  ( $template, @data ) → templated jha

    $VERSION
|;
```

naming convention: lowercase, snake_case, family-prefixed
[ `bmw_*`, `jha_*` ] — matches the existing `amos_*` shape.

### where each family lands inside the package

```
data/lib-path/pm/AMOS7/CHKSUM.pm           [ top-level + re-exports ]
data/lib-path/pm/AMOS7/CHKSUM/BMW.pm       [ NEW — bmw_* digest + L13 ]
data/lib-path/pm/AMOS7/CHKSUM/BMW384.pm    [ existing; re-exported ]
data/lib-path/pm/AMOS7/CHKSUM/JHA.pm       [ NEW — jha_* fast 32-bit ]
data/lib-path/pm/AMOS7/CHKSUM/ELF.pm       [ existing ]
data/lib-path/pm/AMOS7/CHKSUM/ELF/         [ existing dir ]
```

`CHKSUM.pm` `use`s the four sister packages and re-exports their subs
in one `@EXPORT` list, so a single
`use AMOS7::CHKSUM qw| bmw_l13 jha_b32 amos_chksum |;` gets the whole
family — same ergonomic shape standalone callers expect [ e.g.
`bin/amos-chksum`, `bin/is-true`, the AMOS7::P7 loader ].

### zenka-module collapse

after consolidation, every `src/base.chk-sum.bmw.*` and
`src/base.chk-sum.jha.*` becomes a one-line wrapper:

```perl
##  src/base.chk-sum.jha.b32  ##
return AMOS7::CHKSUM::jha_b32(@ARG);
```

bit-identical output, identical contract, zero behavioural change for
existing P7 callers using the `<[chk-sum.jha.b32]>` form. but now any
standalone script doing `use AMOS7::CHKSUM` gets the same digest
without needing the P7 module-loader bootstrap.

the L13 harmonize chokepoint lives at `AMOS7::CHKSUM::bmw_harmonize_l13`
[ inside `CHKSUM/BMW.pm` ]. `bmw_template_l13` builds the validator
closure + assigns templates via `AMOS7::TEMPLATE` + delegates. the
zenka-side `src/base.chk-sum.bmw.harmonize_L13` becomes the same
one-line wrapper pattern as every other family member.

### what this buys

1. **one home for digest+template+exclusion logic.** `AMOS7::TEMPLATE`
   integration is implemented once per family at the AMOS7 level and
   inherited transparently by every existing P7 module wrapper.
2. **standalone parity.** `bin/amos-chksum`, `bin/is-true`, smtpd
   classifiers, the AMOS7::P7 loader path — all gain BMW+JHA access
   with no P7 module loader required, matching the existing
   `amos_chksum` ergonomics.
3. **clearer ownership.** the zenka-callable `<[chk-sum.*]>` namespace
   becomes a pure-routing surface; the actual algorithm code lives in
   one CPAN-shaped package tree.
4. **cross-epoch exclusion gains JHA path for free.** once
   `jha_template_b32` exists with the same template/exclusion contract,
   epoch-windowed addressing [ from EPOCH-CHECKSUM-EXCLUSION-
   ADDRESSING.md ] can use the fast 32-bit hash where the heavier BMW
   path is overkill [ e.g. ephemeral routing IDs, short-lived index
   buckets ].

### template / exclusion support per family

```
amos_*       full     [ already shipped ]
bmw_l13      full     [ via bmw_template_l13 + bmw_harmonize_l13 ]
bmw_56_true  partial  [ single template today;
                        ARRAY/CODE/Regexp + exclusion in next tranche ]
bmw_b32      none     [ pure digest; consumers harmonize upstream ]
bmw_digest   none     [ pure binary digest ]
bmw384_*     none     [ pure derivation from a digest ]
jha_b32      none     [ pure hash + encode ]
jha_b32_harm partial  [ self-template only; ARRAY/CODE/Regexp +
                        exclusion in jha_template_b32 ]
```

so the *full* template+exclusion vocabulary lands at L13 first
[ chokepoint dispatch ], then propagates to `jha_template_b32`
[ family-tranche dispatch ], then to `bmw_template_56_true`
[ AMOS7::13 changes, deferred ].

### sequencing with the L13 chokepoint work

the consolidation does NOT block the L13 chokepoint task. preferred
order:

1. **L13 chokepoint** lands as `src/base.chk-sum.bmw.harmonize_L13`
   first [ task `bmw-harmonize-l13-helper.md` ]. proves the contract
   inside the P7 module space where regression is easy to bisect.
2. **L13 templated wrapper** lands next [ task
   `epoch-bmw-l13-truth-templates.md`, rewrapped to delegate ].
3. **AMOS7 consolidation** lifts both into `AMOS7::CHKSUM::BMW.pm` and
   collapses the zenka modules to one-liners [ task
   `amos7-chksum-consolidation.md` below ]. lift is mechanical because
   the contracts are already settled by [1] and [2].
4. **JHA + family tranche** lands fourth [ task
   `bmw-truth-template-family.md`, extended to cover JHA ].

at every step, `<[chk-sum.*]>` callers see no contract change. the
consolidation is a *home migration*, not a contract migration.

## task tree rooted here

```
EPOCH-CHECKSUM-EXCLUSION-ADDRESSING.md           [ outer doc ]
└── BMW-CHECKSUM-TEMPLATE-EXPANSION.md           [ this doc ]
    ├── bmw-harmonize-l13-helper.md              [ chokepoint, prereq ]
    ├── epoch-bmw-l13-truth-templates.md         [ existing; rewrapped
    │                                              onto chokepoint ]
    ├── amos7-chksum-consolidation.md            [ NEW: lift BMW+JHA
    │                                              into AMOS7::CHKSUM ]
    └── bmw-truth-template-family.md             [ family tranche;
                                                   includes JHA
                                                   templated variant
                                                   + 56-bit string/file
                                                   wrappers + 384
                                                   harmonize placeholder ]
```

#,,,.,..,,,,,,,,,,..,,,,.,,,,,..,,..,,,,,,,,,,..,,...,...,...,,,,,..,,,..,,.,,
#RF4OMYTNCFOD6VYOPE4NU6RS5SJAQI4SKIQRV3PWPXSR5XF56KW7VQ7K2E7KSTOMMYVVUINVCGBXW
#\\\|WURPLWL75R6W63VB6XFKYR3GVGBQWB2IQ7B3YZSOCQFN7MZMLIV \ / AMOS7 \ YOURUM ::
#\[7]YOM2LAVUG6AFF6F7PPQGK4YKLBDCTOTDGOCSHW2PFMUR4EMWP6DA 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
