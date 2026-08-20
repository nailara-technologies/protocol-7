---
name: topic-deparse-code-features
description: follow-up reminder — user has a whole tree of planned "deparse code"-based features to discuss; ask about it next session
metadata:
  node_type: memory
  type: project
  originSessionId: 9ecacc19-6948-4beb-892e-5af7d7d24068
---

flagged 2026-06-11, right after `devmod.cmd.deparse-code` /
`devmod.cmd.exec-sub` modules appeared (existing on disk:
`src/devmod.cmd.deparse-code`, plus per-zenka source copies under
`cfg/zenki/{proxy,models}/source/devmod.cmd.deparse-code`,
`cfg/zenki/models/source/devmod.cmd.exec-sub`).

`devmod.cmd.deparse-code` returns the deparsed source of a `%code`
subroutine via `base.sourcecode.in-mem.sub-source`.

user said there is "an entire tree" of planned features building on
this deparse-code mechanism, but didn't elaborate yet — **ask the user
about this in a future session** to capture the actual idea(s) and
file them properly.

## hint dropped (2026-06-11)

"that will give us full zenka and code mobility, deparsing as a
normalization filter step for many features." — i.e. deparse-code
isn't just an introspection/debug tool: the user sees deparsing as a
**canonicalization pass** (source -> AST/optree -> regenerated source),
making `%code` content portable/comparable independent of original
formatting/whitespace/style — a normalization step that *other*
features can build on. "zenka and code mobility" suggests this feeds
into moving/migrating zenki or code between hosts/versions with a
stable canonical form. relates to [[project-layer-matrix-convergence]]
(self-restart/migration/branching/diff-addressing as one algebra) and
possibly [[topic-checksum-addressing]] (canonical form -> stable
checksums regardless of source formatting).

## sub-feature: %CODE_DEPARSED{<version>}{<sub_name>} cache (2026-06-11)

first concrete piece of "the tree": a global, **functionally-tied**
`%CODE_DEPARSED{<version>}{<sub_name>}` hash —

- a **self-cleaning cache** of deparsed source strings, keyed by code
  version then sub name (mirrors the `%DATA`/`%CODE` uppercase
  meta-namespace shape from [[topic-dot-path-case-notation]]: `%code`
  = the loaded subs themselves, `%CODE_DEPARSED` = derived/normalized
  data *about* those subs)
- for the `:loaded:` / current version, deparses **directly from
  `%code`** on first access, then caches
- for *other* (previous) versions, the source comes from a
  `$CODE{$prev_version} = {%code}` style snapshot — i.e. user
  envisions (not yet existing) `base.load_code` snapshotting the
  entire `%code` hash under a previous-version key before reload, the
  same pattern by which `%CODE` (uppercase, version-indexed) would be
  populated per [[topic-dot-path-case-notation]]'s `%CODE` proposal
- net effect: `%CODE_DEPARSED{$version}{$sub_name}` transparently
  yields the canonical deparsed source for *any* loaded version of any
  sub, computing+caching lazily, regardless of whether that version is
  the live `%code` or a frozen `%CODE{$prev_version}` snapshot
- this cached canonical-source layer is then **the foundation other
  deparse-tree features build on** (diffing across versions, mobility/
  migration, checksum-addressing of canonical form, etc — see hint
  below)

note: `%CODE{$prev_version} = {%code}` snapshotting and `base.load_code`
do not exist yet on disk (checked 2026-06-11) — this is forward design,
tied to the not-yet-implemented `%CODE` meta-namespace from
[[topic-dot-path-case-notation]].

## constraint: deparse needs a compiled coderef (2026-06-11)

verified live: `models.exec-sub devmod.cmd.deparse-code base.init_code`
returns deparsed source wrapped in a leading `{` — `B::Deparse` always
emits a coderef's body as a `{ ... }` block (the `data` value starts
`'{\n    $data{\'zenka\'}{\'init_return\'}...`).

key constraint this implies: **you can only deparse a sub that is
already compiled into `%code`** [ B::Deparse operates on a CODE ref,
not source text ]. for `:loaded:` / current version this is trivial
(`%code` already has it). but for the `%CODE_DEPARSED{<version>}{...}`
cache to work for *non-current* versions or subs that were only ever
**lazy-loaded** [ referenced via an autoload/lazy-load callback,
possibly never actually compiled ], the cache-fill path may need to
go through `base.load_code` first — to force-compile/instantiate the
coderef — before `B::Deparse` has anything to operate on.

`base.load_code` itself does **not exist on disk yet** (checked
2026-06-11) — only `src/base.protocol.compile_once` references it
in a comment ("module compilation is handled by base.load_code") while
itself just being a stub returning TRUE. so this whole tree has TWO
not-yet-built foundations: `base.load_code` (compile-on-demand +
`$CODE{$prev_version} = {%code}` snapshotting) and
`%CODE_DEPARSED{...}` (the deparse cache layered on top of it).

## edge case: compile-time side effects / hardware deps (2026-06-11)

force-compiling a module to get a coderef [ for `base.load_code` /
the deparse-cache fill path ] isn't always side-effect-free.
some perl modules require **loading and partial initialization** —
sometimes with hardware present — to compile cleanly. concrete
example: **`Device::GemBird`** has been encountered needing an actual
device connected for clean module init.

implication: the `%CODE_DEPARSED` cache-fill / `base.load_code`
compile-on-demand path needs **layers of resilience / desirable
default fallback behaviour** for subs whose compilation depends on
unavailable hardware or external state — e.g. graceful skip/placeholder
deparse result, or a way to mark a sub "uncacheable in this
environment" rather than failing the whole cache-fill or blocking on
a missing device. this is a real constraint to design around, not just
a hypothetical — flag it when the `base.load_code`/`%CODE_DEPARSED`
design doc gets written.

## edge case: implicit module-load dependencies (2026-06-11)

beyond hardware-init side effects, a sub may simply **fail to compile/
deparse in isolation** because its containing module's `init_code` (or
some call-time routine) does a plain `use Module;` [ or worse, an
ad-hoc runtime `require`/`eval "use ..."` somewhere ] that the
deparse-cache fill path doesn't know to replay first.

implication: `base.load_code` / `%CODE_DEPARSED` cache-fill may need
to **track or simulate** a module's load-time dependency chain
[ which `use`/`require` statements ran during that module's normal
`init_code`/load sequence ] before attempting to compile/deparse one
of its subs in isolation — otherwise compilation errors on missing
imports/symbols, distinct from [[topic-deparse-code-features]]'s
hardware-init edge case (`Device::GemBird`) but same family of
problem: **isolated compilation of a sub assumes an environment that
normally only exists after its module's full load sequence has run**.
both need to land in the same resilience-layer design.

## consumer feature 1: reverse protocol-7 style formatter (2026-06-11)

a formatter that takes raw `B::Deparse` output [ from
`%CODE_DEPARSED` ] and reverses it back into protocol-7 idiom:

- `$code{'sub.name'}->(...)` -> `<[sub.name]>->(...)` [ and the
  implicit-call form where applicable ]
- `$data{'another'}{'key'}` -> `<another.key>` [ dot-path form, see
  [[topic-dot-path-case-notation]] — this is a concrete consumer of
  that notation: deparsed code's verbose `$data{...}{...}` chains are
  exactly the "reverse direction" case that notation's preconditions
  were written for ]
- splits long strings B::Deparse tends to produce [ same job
  `bin/format-code` already does for hand-written code ], **then**
  runs `perltidy` over the result — despite deparsing, perltidy's
  strict formatting still applies as a final pass

net effect: deparsed code becomes visually/stylistically
indistinguishable from hand-written protocol-7 source — this is the
"normalization" half of "deparsing as a normalization filter step".

## consumer feature 2: deparsed diff history per *.reload (2026-06-11)

once `%CODE_DEPARSED{<version>}{<sub_name>}` + the reverse-formatter
exist, every `*.reload [source]` call can produce a **protocol-7-styled
diff** between the previous and new deparsed-and-reformatted version of
each changed sub — a running "deparsed diff history". ties into
[[project-layer-matrix-convergence]] (diff-addressing as part of the
unified migration/branching algebra) and the `$CODE{$prev_version} =
{%code}` snapshot mechanism already noted above as `%CODE_DEPARSED`'s
dependency.

## consumer feature 3: ascii-frame dual-pane reformatting-suggestion UI (2026-06-11)

the reverse formatter doesn't always have one canonical answer — the
regex-driven "style element" categorization + reduction process can
produce **multiple candidate reformattings** for a given deparsed
segment ["a collection of optimums"]. UI for resolving these:

- **two parallel ascii-frame panes** [ reusing
  [[topic-ascii-frame-system]] / [[topic-frame-plugin-slots]] ]:
  - left pane: the code under reformatting (static — "code is not
    moving")
  - right pane: empty until the first alternative/suggestion arrives
    for the current segment
- candidates for the current segment are arranged in a **spiral
  layout** in the right pane; left/right cursor keys rotate/offset
  through the spiral
- the *boundary* between "suggestions" and "resumed code" is
  communicated implicitly by **motion**: suggestions roll/shift as you
  cursor through them, while the surrounding (already-resolved) code
  stays static — the visual distinction IS the animation, not a
  marker/highlight
- explicitly designed to be **fast for both humans and LLMs**, even
  with large suggestion lists — spiral indexing + cursor-offset
  navigation is a compact, uniform addressing scheme regardless of
  list size
- process is iterative: code gets divided into style/element
  categories, regex-driven candidate generation per category, until
  "all code elements are consumed into a protocol-7-encountered
  preferred form"

this is the first concrete *new* ascii-frame UI pattern in this
session's ideas (distinct from [[topic-cube-tree-dashboard]] and
[[topic-ascii-minimap]], though all three share the
ascii-frame-system/frame-plugin-slots substrate) — worth its own
design-doc section when this tree gets written up, possibly its own
doc given the spiral-navigation interaction model is novel enough to
need diagrams.

## consumer feature 4: extract native subs for standalone scripts / AMOS7 (2026-06-11)

design doc written up as `data/md/design/DEPARSE-CODE-NORMALIZATION-TREE.md`
(sections 1-6, see below) — but ANOTHER consumer feature surfaced
after that doc landed:

deparsed code has **already had protocol-7's special syntax compiled
away** [ `<[sub.name]>` -> `$code{'sub.name'}->(...)`, `<a.b.c>` ->
`$data{'a'}{'b'}{'c'}`, `<[$var]>` etc — all of it resolved to plain
`%code`/`%data` hash access by the time `B::Deparse` sees the coderef ].
that means a deparsed sub is **already plain, standard perl** — no
protocol-7 preprocessor required to run it.

implication: deparse becomes an **extraction mechanism** — taking a
`%code` subroutine [ which normally only exists inside a running P7
zenka, post-preprocessing ] and producing a self-contained perl sub
body usable by:
- standalone scripts [ same `BEGIN { use lib data/lib-path/pm }`
  pattern as `bin/is-true`/`bin/amos-chksum`, see
  [[topic-amos7-p7-loader]] ]
- the **AMOS7 perl module** itself — i.e. native P7 subroutines could
  become loadable/callable AMOS7::* functions outside any zenka

caveat: the extracted sub still references `%data`/`%code`/`%keys` [
now as plain hash variable names, no longer P7 syntax sugar, but the
*hashes themselves* may not exist or be populated outside a zenka
context ]. so this consumer feature likely needs either (a) a minimal
shim providing empty/stub `%data`/`%code`/`%keys` for subs that don't
actually touch them, or (b) restriction to subs whose deparsed body
doesn't reference those hashes at all [ pure-function subs ] as the
practical v1 scope. relates to the section-3 resilience-layer
discussion in the design doc (isolated-compilation environment
assumptions) — same family of problem, opposite direction [ extracting
*out* of the zenka environment vs. compiling *in* isolation within
it ].

this should be folded into `DEPARSE-CODE-NORMALIZATION-TREE.md` as a
section 7 (or appended near section 4, the reverse formatter, since
"already-resolved syntax" is the same underlying fact that makes
both features possible) next time that doc is revisited.

### the (a)/(b) shim question is mostly already answered

user's follow-up: the set of "special cases and initializations
required" per sub is **small and already largely surfaced** by the
existing **dep-graph output**
[ `data/md/documentation/module-dependency-graph.asc`, regenerated by
the dep-graph tooling touched in recent commits — see
`b9d909aa3` "docs: dep-graph regen for base.ui/base.slot" ]. the
dep-graph already enumerates which `%code`/`%data`/module dependencies
a given sub pulls in, which is exactly the information needed to:
- decide whether a sub is "pure enough" for option (b) [ no shim
  needed ], or
- generate the **minimal shim** for option (a) [ only the specific
  `%data`/`%code` keys/subs that sub's dep-graph entry references,
  not a full zenka environment ]

so extraction tooling doesn't need new dependency analysis — it's
largely a **dep-graph consumer**: cross-reference a sub's deparsed
body against its existing dep-graph entry to size the shim (possibly
empty) automatically. lowers this consumer feature's cost
significantly — worth noting prominently when section 7 gets written.

## consumer feature 5: checksum-resolved %CODE versions over the network (2026-06-11)

`tail -42 bin/Protocol-7` ends with a `base.parser.pattern_split`
base32 blob followed by:

```
<PXU4LI6PAGTEUFVZANWFGP3KACXZ3N6CMQO2IT5Z7FOMFYKBJCEQ:0069:000247:000003104>
```

— a `<checksum:epoch:offset:size>`-shaped line [ checksum + 3
zero-padded numeric fields ], then a final
`base.protocol-7.source-key` block with a single qw| BASE32 | key.
this is the existing checksum-addressing convention from
[[topic-checksum-addressing]] / `data/md/design/CHECKSUM-NESTED-
ADDRESSING-AND-EPOCH-VALIDITY.md` / `data/md/design/EPOCH-CHECKSUM-
EXCLUSION-ADDRESSING.md`, embedded directly in the binary's own
trailer.

user's framing: these `<checksum:...>` lines are **also** a
deparse-tree consumer. if a `%CODE{<version>}` entry is *missing
locally* [ e.g. an old or not-yet-fetched version ], the **checksum
alone can resolve the route to the actual code over the network** —
as long as that version was ever released [ likely, since released
versions propagate ]. so:

- a row of `<checksum:epoch:...>` lines is potentially a **fully
  network-resolvable list of compilable subroutines** — the checksum
  *is* the address, independent of whether the bytes are present
  locally
- if the resolved+deparsed subroutine is **signed as a full pass**
  [ canonical deparsed form + AMOS7 signature, tying back to
  `data/md/design/CODE-NAMESPACE-AND-SIGNING-INFRASTRUCTURE.md` ], the
  result is **fully cryptographically secured** code, addressed by
  checksum alone
- user's claim: this combination [ checksum-addressed + canonical
  (deparsed) + signed ] approaches "the maximal still reasonable
  compression ratio" — i.e. you cannot meaningfully compress further
  than "a checksum that resolves to a canonical, verifiable
  subroutine body over the network", since the checksum itself is
  smaller than any non-trivial sub body

ties `%CODE`/`%CODE_DEPARSED` [ consumer features above ] directly
into the existing checksum-addressing / addressing-trinity topics —
this may be the strongest argument for *why* `%CODE_DEPARSED` should
exist: canonical form is what makes a checksum a stable, useful
address for code (raw source-text checksums would change on every
reformat).

should also fold into `DEPARSE-CODE-NORMALIZATION-TREE.md` — likely
as its own section near %CODE (section 2), since it's as much a
"why %CODE_DEPARSED matters" argument as a standalone feature.

## consumer feature 6: ascii-frame as code transfer container (2026-06-11)

an ascii-frame [ [[topic-ascii-frame-system]] ] with the **subroutine
name as its title** is itself a natural **transfer container format**
for a deparsed+canonicalized+signed sub: title = address [ sub name or
checksum, see consumer feature 5 ], body = the canonical source, frame
border = integrity/framing boundary.

this retroactively explains a long-standing convention: **code line
length limit is 78, not 80** — chosen to leave room for a trailing
` : ` [ 3 chars: space-colon-space ] frame-border segment without
exceeding 80 columns. verified live: signature footer lines in
existing modules [ e.g. `src/base.stdio.frame.encode` tail ] are
**exactly 78 chars** —

```
#,,..,.,,,,,,,,,.,.,.,...,...,,..,,..,..,,..,,.,.,...,...,..,,.,.,,..,,,,,...,
#2WQKIL46O6ZDT4T4VW7RDX3NJJNPFAJV5J5PG2OVF7VDYFSCP7RNPWKNW2U2OMW7RD4MOYALYLDA2
#\\\|I7T6OPQCDVAVHV4B5LN3S2MAUL3DO67PSWIYQNM4SM73LAFJ5TU \ / AMOS7 \ YOURUM ::
#\[7]6DDHTT7NUJXZKADX3YGJX5JDPHT6YR3ALQ2AWSMK7VXY2YYGXCBY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
```

so the 78-col code-line convention and the source-signature footer
width are **not a coincidence** — both already budget for the same
` : `-bordered ascii-frame container. a deparsed+reformatted sub
[ consumer feature 4, reverse formatter ] dropped into an ascii frame
with this width is therefore *already* shaped correctly for this
transfer-container use, with zero extra reflow needed — the
reformatter's perltidy pass at 78 cols IS the frame-packing step.

ties together: consumer feature 4 (reverse formatter, produces 78-col
canonical source) + consumer feature 5 (checksum/title addressing) +
ascii-frame substrate (consumer feature 3's substrate) — three
previously-separate pieces converge into one container format.

should fold into `DEPARSE-CODE-NORMALIZATION-TREE.md`, likely as a
short closing section tying sections 4, 5(new), and 6 together.

## status

design seed captured: %CODE_DEPARSED cache + base.load_code dependency
+ B::Deparse compiled-coderef constraint + hardware/load-dependency
resilience edge cases + 3 consumer features (reverse formatter,
deparsed diff history per reload, ascii-frame spiral suggestion UI).
still "ask the user" if more nodes exist — this tree is getting large
enough that it may warrant promotion to its own design doc
(`data/md/design/DEPARSE-CODE-NORMALIZATION-TREE.md` or similar) soon,
following the [[topic-ui-show-security-levels]] precedent of
doc-then-split-into-tasks.

#,,,.,.,,,,,,,,,,,.,,,...,.,,,,.,,.,,,,,,,..,,..,,...,...,.,.,,.,,.,,,,,,,...,
#Q76MRDSIOPBSPYS5XLN2UFAXSNAAJSOGWTDDQ43WBHL2L6NI4T52GHY4SNEYLCNVUH7KRIL7MXL74
#\\\|MUVFC6DBQPKANZJMJBQ5RITE6ZWOPOPLXLNYBYMS5XYEB7FZSCX \ / AMOS7 \ YOURUM ::
#\[7]ET5D6VLLNXZD3IIF2CWQFK5AMT2MAYUK4YYWPHHKOO6Q7SEQNSAA 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
