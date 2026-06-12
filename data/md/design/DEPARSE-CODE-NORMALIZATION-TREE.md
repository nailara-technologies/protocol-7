## [:< ##

# deparse-code normalization tree

## overview

`devmod.cmd.deparse-code` [ landed 2026-06-11, plus the companion
`devmod.cmd.exec-sub`; per-zenka copies under
`configuration/zenki/{proxy,models}/source/` ] returns the `B::Deparse`
output of a `%code` subroutine via
`base.sourcecode.in-mem.sub-source`. on the surface this is a debug /
introspection convenience. underneath, it is the first concrete piece
of a larger idea:

> **deparsing as a normalization filter step for many features —
> giving us full zenka and code mobility.**

`B::Deparse` takes a compiled coderef and re-emits perl source from
its optree. that round-trip [ source → optree → source ] is a
canonicalization: it discards original formatting, whitespace, comment
placement, and incidental textual variation, while preserving exact
runtime behaviour. once `%code` content has a canonical textual form,
every downstream feature that wants to *compare*, *diff*, *checksum*,
*relocate*, or *re-render* code can sit on top of a single normalized
representation instead of fighting raw source-text drift.

this doc captures the full tree of features the user has flagged
building on that idea, in dependency order: two missing foundations
first [ `base.load_code` and the `%CODE` / `%CODE_DEPARSED`
meta-namespaces ], then the resilience layer the foundations need, then
three consumer features that the canonical form unlocks [ reverse
formatter, deparsed diff history per `*.reload`, ascii-frame spiral
suggestion UI ].

related design docs:

- `data/md/design/DOT-PATH-CASE-NOTATION.md` — proposes the uppercase
  `%CODE` / `%DATA` meta-namespace this tree extends, and the
  `<a.b.c>` ↔ `$data{'a'}{'b'}{'c'}` reverse direction the formatter
  has to honour
- `data/md/design/CODE-NAMESPACE-AND-SIGNING-INFRASTRUCTURE.md` — the
  source-version key-shape that `%CODE`'s top level uses
- `data/md/design/LAYER-MATRIX-STATE-TRANSFER.md` — the unified
  self-restart / migration / branching / diff-addressing algebra that
  per-reload deparsed diffs feed into
- `data/md/design/PLUGIN-SLOT-SELECTOR.md`,
  `data/md/design/CONSOLE-FOLD-TREE-PHILOSOPHY.md` — the ascii-frame /
  slot substrate the spiral suggestion UI sits on top of

---

## 1. foundation: `base.load_code`

### current state

`base.load_code` is referenced as the intended compile-on-demand entry
point in a comment in `modules/base.protocol.compile_once`:

```
## module compilation is handled by base.load_code ##
## this stub just confirms the module exists ##
return TRUE;
```

but the module **does not exist on disk yet** [ checked 2026-06-11 ].
the existing module-loading path is `modules/base.load_modules` plus
the compile-once stub — they walk the modules tree, slurp source, and
compile module bodies into `%code` under their dot-notation keys.
that path is whole-tree, eager, and one-shot per zenka start; it
neither retains previous versions nor exposes a "compile this single
sub on demand" entry point.

### what `base.load_code` is for

`base.load_code` is the **per-sub / per-module compile-on-demand**
front door. semantics it needs to provide:

- given a module/sub name [ dot-notation, e.g. `base.init_code` ] and
  optionally a source version, ensure a coderef exists in `%code`
  [ or its versioned counterpart `%CODE` — see section 2 ] without
  forcing a full zenka-wide reload
- before re-installing a sub at a key that already holds an older
  compiled version, **snapshot the outgoing `%code` under a versioned
  slot**: `$CODE{$prev_version} = { %code }` [ shallow copy; the
  coderefs themselves are shared, only the hash-of-coderefs is
  duplicated ] — this is the mechanism by which previous versions
  remain addressable for diffing, deparse-cache lookups, and rollback
- be **idempotent** [ same module + same version + no source change =
  no-op, no recompile, no snapshot ] so a hot `*.reload` that touches
  only a subset of subs doesn't churn the snapshot store
- accept a source string directly as an alternative to a module path,
  so the deparse-cache fill path [ section 3 ] can hand it
  pre-resolved source rather than re-walking the loader

### relationship to the existing load path

`base.load_modules` stays as the bulk / startup loader. `base.load_code`
is the targeted, runtime-callable, version-aware variant — invoked by
`*.reload` handlers, by `%CODE_DEPARSED` cache misses for non-current
versions, and by any future "lazy materialize this sub" path. they
share the same compile machinery and the same `%code` destination
shape, differing only in scope and snapshot behaviour.

---

## 2. foundation: `%CODE` / `%CODE_DEPARSED` meta-namespaces

### `%CODE` — version-indexed `%code` snapshots

per `data/md/design/DOT-PATH-CASE-NOTATION.md`, uppercase
`%DATA` / `%CODE` are reserved as **meta-namespaces** — data *about*
the lowercase thing rather than the thing itself. for code this looks
like:

```
$CODE{'3TJNHUPSJA-8187.0'}{'base.init_code'} = $coderef
```

— a version-indexed registry of frozen `%code` snapshots, populated
by `base.load_code` at the moment it is about to overwrite an existing
entry [ see section 1 ]. the `:loaded:` / current version is the live
`%code` itself; every previous version is a `%CODE{$ver}` slot.

key-shape for the top level is the existing source-version string
[ see `data/md/design/CODE-NAMESPACE-AND-SIGNING-INFRASTRUCTURE.md` ].
whether to keep it as one composite key or split into nested levels
is left to the dot-path doc's open question 4 — this tree only needs
*some* unique versioned addressability, not a specific layout.

### `%CODE_DEPARSED` — self-cleaning canonical-source cache

layered on top of `%CODE`:

```
$CODE_DEPARSED{$version}{$sub_name} = $canonical_source_string
```

semantics:

- **lazy fill**. accessing a `($version, $sub_name)` pair that hasn't
  been deparsed yet triggers a fill: look up the coderef in `%code`
  [ if `$version` is the `:loaded:` / current one ] or in
  `$CODE{$version}` [ otherwise ], run `B::Deparse` over it, store the
  result, return it.
- **functionally tied**. invalidation is automatic: when
  `base.load_code` overwrites a sub in `%code`, the *current*-version
  slice of `%CODE_DEPARSED` is dropped for that sub name [ the new
  body will deparse differently on next access ]. snapshots in
  `%CODE` are immutable, so their `%CODE_DEPARSED` slices never need
  invalidation — only eviction under cache-size pressure.
- **canonical form, not raw `B::Deparse` output for consumers**. the
  raw deparse output already begins `{\n  $data{'zenka'}...` [ verified
  live 2026-06-11: `models.exec-sub devmod.cmd.deparse-code
  base.init_code` returns exactly this shape, because `B::Deparse`
  emits a coderef body as a `{ ... }` block ]. consumers that want
  protocol-7 idiom go through the reverse formatter [ section 4 ];
  consumers that want bit-stable canonical input for checksums or
  diffs go directly against `%CODE_DEPARSED`.

### why this shape

the lazy/self-cleaning split keeps memory bounded — only versions and
subs that are actually compared / displayed / diffed materialize. the
version-then-sub-name nesting [ rather than sub-name-then-version ]
matches the access pattern: most consumers want "all subs of one
version" [ rendering a snapshot ] or "one sub across two versions"
[ diffing across a reload boundary, where you already have both
version strings in hand ].

---

## 3. resilience layer: isolated compilation isn't side-effect-free

`B::Deparse` only works on a compiled coderef. compile-on-demand from
source through `base.load_code` is therefore the cache-fill bottleneck
— and isolated compilation of a single module/sub, outside its normal
zenka load sequence, has two known failure modes:

### 3a. compile-time side effects / hardware deps

some perl modules require **loading and partial init**, sometimes with
hardware present, to compile cleanly. concrete encountered example:
**`Device::GemBird`** — needs an actual device connected for clean
module init. the cache-fill path attempting to compile a sub whose
module pulls in `Device::GemBird` will either fail outright or block
on a missing device.

### 3b. implicit module-load dependencies

separate but same family: a sub may simply **fail to compile in
isolation** because its containing module's `init_code` ran a plain
`use Module;` [ or worse, an ad-hoc runtime `require` / `eval "use
..."` ] that the cache-fill path doesn't know to replay first.
isolated compilation assumes an environment that normally only exists
after the full load sequence has run.

### design options [ open, present for selection ]

these are not mutually exclusive — a real implementation likely picks
two or three:

1. **graceful skip / placeholder result**. on compile failure, the
   cache stores a sentinel value [ e.g. `\$UNCACHEABLE` ] rather than
   the deparsed string. consumers see "no canonical form available"
   and skip diffing / display for that sub. cheap, conservative,
   keeps the rest of the cache usable.
2. **"uncacheable in this environment" marking**. richer than (1):
   record *why* — missing module, missing hardware, runtime exception
   text. lets diagnostics distinguish "we haven't tried yet" from "we
   tried and it can't work here". feeds into a per-host capability
   profile [ "this host can deparse `Device::GemBird` subs" ].
3. **dependency-chain replay**. before attempting isolated compile of
   a sub, walk and replay the `use` / `require` statements its
   containing module's `init_code` ran during its last normal load.
   needs a load-time recorder [ track each `use` / `require` against
   the module that issued it ] so the cache-fill path can re-execute
   them. handles the implicit-import family of failures but does
   nothing for hardware-init.
4. **proxy / mock layer for hardware deps**. for the
   `Device::GemBird`-family, install a deparse-time mock of the
   underlying device interface during cache-fill, so module init
   completes against a no-op stub. risky [ a mock that compiles but
   misbehaves at runtime is worse than a hard failure ]; useful only
   if scoped strictly to compile-only paths.
5. **defer to runtime co-presence**. only deparse subs whose modules
   are *already* loaded in the current zenka — refuse cache-fill for
   anything else. simplest, but limits cross-version diffing to subs
   present in both versions' running zenki.

recommendation [ tentative ]: combine (2) + (3) + (5) — record
capability, replay imports where cheap, refuse rather than fake when
the environment can't support it. (1) is the universal fallback.
explicitly *not* recommending (4) without further design.

---

## 4. consumer feature: reverse protocol-7 style formatter

### purpose

raw `B::Deparse` output reads like canonical perl, not like protocol-7.
the reverse formatter takes the cache entry and emits source visually
indistinguishable from hand-written protocol-7 module code. this is
the **normalization** half of "deparsing as a normalization filter
step" — the canonicalization round-trip ends here.

### transformations

- **module call rewrite**:
  `$code{'sub.name'}->( @args )` → `<[sub.name]>->( @args )`
  [ explicit `->()` retained when args are present ]
  `$code{'sub.name'}->()` → `<[sub.name]>` [ no-arg form, per the
  project convention that implicit `->()` applies when no arguments
  are passed — see the special-syntax notes in `CLAUDE.md` ]
- **variable-keyed call rewrite**:
  `$code{$var}->()` → `<[$var]>` [ no quotes in the angle form ]
- **`%data` access rewrite**:
  `$data{'a'}{'b'}{'c'}` → `<a.b.c>` per
  `data/md/design/DOT-PATH-CASE-NOTATION.md`. the doc's section on
  preconditions for non-ambiguity is **directly load-bearing here** —
  the formatter is exactly the "reverse direction [ hash → string ]"
  case it warns about. when a path violates precondition 3 [ adjacent
  same-level lowercase keys ], the formatter falls back to leaving
  the raw `$data{...}{...}` chain in place rather than emitting an
  ambiguous dot-path string.
- **long-string splitting**. `B::Deparse` tends to produce single
  long string literals. `bin/format-code` already implements the
  protocol-7 line-splitting convention [ `LINE_MAX => 78`, `wrap`
  from `Text::Wrap`, the visual splitter at the top of the file ]
  for hand-written code; the formatter applies the same splitter to
  deparsed strings.
- **`perltidy` final pass**. even after the rewrites and splitting,
  perltidy's strict formatting still applies — deparsed code is no
  exception. the formatter ends by piping its output through the
  same perltidy config the project uses elsewhere [ `-sil=0`
  self-heals over-indented modules to column 0; see the project's
  ptd usage ].

### why "a collection of optimums" rather than a single answer

the rewrites above are not always uniquely determined. examples:

- a deparsed sub may legitimately fit either as `<[sub.name]>` or, if
  the surrounding context already has a captured ref, as the raw
  `$code{...}->()` form — both are valid protocol-7 idiom
- long-string splitting has multiple acceptable break points
- a `$data{...}{...}` chain that *barely* violates precondition 3 may
  be representable by adding an uppercase pivot level — but only if
  the underlying data layout permits

so the formatter is more accurately a **candidate generator** [ regex-
driven, categorical, per-style-element ] that produces a set of
acceptable reformattings, plus a default-pick heuristic. consumers
that want a single answer take the default; the spiral suggestion UI
[ section 6 ] is for the case where a human or LLM wants to choose
among the alternatives.

---

## 5. consumer feature: deparsed diff history per `*.reload`

### what

every `*.reload [source]` call already triggers a re-compile of one or
more module sources. with `%CODE_DEPARSED` + the reverse formatter in
place, the reload handler can additionally emit a **protocol-7-styled
diff** of each changed sub: before-version deparsed-then-reformatted,
after-version deparsed-then-reformatted, unified-diff between them.

stored, addressable, and queryable — a running "deparsed diff
history" per zenka, per source tree, per sub.

### why deparsed-then-formatted, not raw-source diffs

the whole point of going through the canonical form is that **purely
cosmetic source-text changes** [ whitespace, comment edits, perltidy
churn, identifier reordering inside an `our` list, etc ] collapse to
empty diffs when both sides round-trip through deparse. only changes
that actually affect compiled behaviour show up. this is the same
property that makes the canonical form attractive for checksum-
addressing of behaviour rather than text.

### relationship to layer-matrix

`data/md/design/LAYER-MATRIX-STATE-TRANSFER.md` casts self-restart,
migration, branching, and diff-addressing as one reversible algebra.
the per-`*.reload` deparsed diff is the **concrete diff-addressing
substrate** that algebra needs: each diff entry is a labelled,
reversible edge between two `%CODE` snapshots, addressable by
(`from_version`, `to_version`, `sub_name`). that is exactly the shape
the layer-matrix doc takes as input.

it also dovetails with the canonical-form-as-checksum-input thread in
`data/md/design/CODE-NAMESPACE-AND-SIGNING-INFRASTRUCTURE.md` — a
behaviour-only diff is a behaviour-only checksum delta, which is what
signing eventually wants to verify against.

---

## 6. consumer feature: ascii-frame dual-pane spiral suggestion UI

### the problem this UI is for

the reverse formatter [ section 4 ] is a candidate generator. for any
non-trivial sub it can emit a *collection of optimums* for each
style-element category [ module-call shape, dot-path collapse, string
splitting, etc ]. a human or LLM reviewing the reformatting needs to
navigate that collection fast — for one sub there might be dozens of
candidates, across a reload sweep there might be thousands.

flat lists, dropdowns, scroll-views: all degrade as candidate count
grows. the spiral pattern below is designed to stay legible at scale
and to be *equally* navigable by humans on cursor keys and by LLMs
addressing candidates by spiral-index.

### substrate

built on the existing ascii-frame / plugin-slot system — see
`data/md/design/PLUGIN-SLOT-SELECTOR.md` for slot-as-CODE-provider
semantics and `data/md/design/CONSOLE-FOLD-TREE-PHILOSOPHY.md` for
the framing / fold idiom this UI follows. this is the first concrete
new ascii-frame pattern in the deparse tree, distinct from the
cube-tree-dashboard and ascii-minimap ideas tracked elsewhere though
sharing the same substrate.

### layout

two parallel frames, vertically split:

```
.:[ left pane — code under reformatting ]::[ right pane — candidates ]:.
:                                         :                              :
:   sub base.init_code                    :          ┌─ #1 ─┐            :
:   ----------------------------          :        ┌─ #2 ─┐  └─ #8 ─┐    :
:                                         :      ┌─ #3 ─┐  ┌─ #7 ─┐ │    :
:   <[base.event.register]>->(            :     │ #4   │  │ cur. │ │    :
:       <ev.name>, <ev.cb>                :      └─ #5 ─┘  └─ #6 ─┘ │    :
:   );                                    :        └──── ... ──────┘    :
:                                         :                              :
:   <weather.location> = <[base.geo]>;    :   ← left / right rotates →   :
:                                         :                              :
'.:[ static — does not move ]::[ rolls under cursor ]:.'
```

- **left pane**: the sub being reformatted, in its current
  best-candidate rendering. **static**: it does not move. it is the
  fixed reference the candidate suggestions are being compared
  against.
- **right pane**: empty until the first candidate arrives for the
  current segment. as candidates stream in [ from the formatter's
  per-category regex passes ] they are laid out in a spiral around a
  central "current" cell. left/right cursor keys rotate the spiral,
  bringing the next candidate into the centre cell.
- **already-resolved code** behind the current segment stays
  motionless. only **unresolved candidate cells** move under the
  cursor.

### the motion-as-boundary idiom

there is no marker, no border colour, no highlight separating
"resolved" from "in-flight" code. the distinction *is* the motion:
suggestions roll when the cursor moves; resolved code stays still.
peripheral vision picks this up instantly — both human and LLM
parsers benefit from the same single cue rather than having to track
a separate state attribute.

this is the part of the design that is genuinely novel and worth real
attention when implementing. the temptation will be to "improve" it
by adding an explicit highlight; resist that — the motion *is* the
information channel.

### spiral indexing

candidates are addressed by their position on the spiral. concretely:
the centre cell is `#0` [ current ], `#1` is one step outward along
the spiral, `#-1` is one step inward, and so on. cursor-right
increments the offset; cursor-left decrements. for an LLM driving the
UI, `select #N` is the entire interaction — no need to model the
visual layout.

for large candidate lists the spiral can be **multi-armed** [ several
overlapping spirals, one per style-element category — module-call,
dot-path, string-split, etc ]. cursor up/down switches arm, left/right
rotates within an arm. addressing extends to `(arm, offset)`. this
keeps the spiral compact regardless of total candidate count: each arm
only needs to hold one category's optimums.

### iteration cycle

per sub the process is:

1. divide code into style-element categories [ regex-driven ]
2. candidate-generate per category
3. user [ or LLM ] picks one per category via the spiral
4. picked candidates fold back into the left pane as resolved code
5. repeat for the next unresolved segment until "all code elements
   are consumed into a protocol-7-encountered preferred form"

once a sub fully resolves it lands in `%CODE_DEPARSED` as the
preferred canonical form for that version-and-sub.

### why fast for both humans and LLMs

- **compact uniform addressing**: `(arm, offset)` regardless of list
  size — no DOM walk, no fuzzy selection
- **single motion channel**: peripheral motion replaces an explicit
  state attribute, halving the parse work
- **streaming-friendly**: candidates appear as the regex pipeline
  produces them; the spiral can render with N candidates and re-render
  with N+1 without any layout reshuffle
- **decoupled from terminal size**: spiral can crop or zoom [ same
  primitives the cube-tree-dashboard / ascii-minimap concepts use ]

---

## status

this is **pre-implementation design**. nothing in this tree has been
built beyond the seed `devmod.cmd.deparse-code` /
`devmod.cmd.exec-sub` modules and the `base.protocol.compile_once`
stub. dependency order for any future build-out:

1. `base.load_code` [ compile-on-demand + `$CODE{$prev_version} =
   {%code}` snapshotting ] — section 1
2. `%CODE` / `%CODE_DEPARSED` meta-namespaces — section 2, blocked on (1)
3. resilience layer choices for isolated compilation — section 3,
   blocks robust (2)
4. reverse protocol-7 style formatter — section 4, blocked on (2)
5. per-`*.reload` deparsed diff history — section 5, blocked on (2)+(4)
6. ascii-frame spiral suggestion UI — section 6, blocked on (4),
   substrate-blocked on existing ascii-frame / plugin-slot work

following the precedent set by
`data/md/design/UI-SHOW-SECURITY-LEVELS.md` [ design doc first, then
split into task files under `data/tasks/` per stage, e.g.
`ui-caller-security-level.md`,
`console-fold-primitive-ui-show-fallback.md` ], this doc should be
split into task files once the user is ready to start. **no task
files are being written here** — those wait on confirmation that the
tree is captured correctly and that the resilience-layer choice in
section 3 is settled enough to act on.

### open questions flagged

- **resilience strategy [ section 3 ]**: which combination of options
  (1)–(5)? tentative recommendation is (2)+(3)+(5) with (1) as
  fallback, but this is the single biggest open decision in the tree
  — it shapes how much of `%CODE_DEPARSED` is actually populatable
  per-host.
- **`%CODE` key shape [ section 2 ]**: composite version string vs
  split levels — inherits the open question from
  `data/md/design/DOT-PATH-CASE-NOTATION.md` section 4. not blocking,
  but worth resolving before consumers start hard-coding access
  patterns.
- **whether the spiral suggestion UI [ section 6 ] warrants its own
  design doc**. the interaction pattern is novel enough that a
  dedicated doc with proper ascii diagrams may serve it better than
  one section here. flagged for split if/when this doc grows further.
- **does the user have more nodes in this tree?** the source riff
  ended with "still ask the user if more nodes exist"; this doc
  captures the six pieces surfaced so far but is not claimed
  exhaustive.

#,,,.,.,.,,.,,.,.,,.,,.,,,,,,,,,.,,,.,...,,.,,..,,...,...,,.,,,,.,,..,,,,,,,.,
#6O55RKALSLWQITBSGOVIRDSLIR44H7T6X3ATUNP4JYAHDXRQIVYX3S3OH2MF6HF4MJKTNIVL3VFBS
#\\\|CKCXNNDLPXB34JKKCHA3C3JUZGAVCIBFL47TGQ2RS5MFGZQZRAN \ / AMOS7 \ YOURUM ::
#\[7]2BZHVO22GZHVM7ICLX72FFZRLD4C2GLJH7J5KIPYFIOSTEHFMIAI 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
