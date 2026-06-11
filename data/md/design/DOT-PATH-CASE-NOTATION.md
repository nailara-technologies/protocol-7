## [:< ##

# dot-path case notation

## overview

a compact textual notation for addressing nested `%data` [ or any other
nested hash ] keys as a single dot-separated string, using letter case
to disambiguate **path-level boundaries** from **literal dots inside a
key name**.

core example:

```
CAT.LOVES.bird.blue.SOUND = TRUE

  =>  $data{'cat'}{'loves'}{'bird.blue'}{'sound'} = TRUE
```

read informally: "CAT LOVES bird.blue SOUND" — almost a tiny natural
language sentence, which is part of the appeal.

## the rule

- an **uppercase token** [ a run of characters with no literal `.`,
  written in uppercase ] is always exactly **one path level**. it is
  lowercased on translation to become the actual hash key.
- a **lowercase token**, or a run of consecutive lowercase tokens
  joined by literal `.`, collapses into **one path level** whose hash
  key is the lowercase string *with its internal dots preserved*.
- uppercase tokens always act as level **separators** as well as
  levels themselves — they break any adjacent lowercase run.

walking the example token by token:

| token   | case  | effect                                   |
|---------|-------|------------------------------------------|
| `CAT`   | upper | level: `cat`                              |
| `LOVES` | upper | level: `loves`                            |
| `bird`  | lower | start of lowercase run                    |
| `blue`  | lower | continues run -> joined run = `bird.blue` |
| `SOUND` | upper | run closes as level `bird.blue`; new level `sound` |

result: 4 levels — `cat` / `loves` / `bird.blue` / `sound`.

## preconditions for non-ambiguity

this notation is unambiguous **only if the underlying hash keys obey a
naming constraint**:

1. every hash key is either:
   - **purely uppercase, containing no literal `.`** [ becomes one
     uppercase token ], or
   - **purely lowercase, optionally containing literal `.`** [ becomes
     one lowercase run ]
2. **mixed-case keys are not representable** [ e.g. `fooBar`,
   `Content-Type` ] — not supported by this notation at all.
3. **no two adjacent tree levels may both be single-segment, dot-free,
   all-lowercase keys** without an uppercase level somewhere between
   them. if they were adjacent, both
   `$data{'bird'}{'blue'}` [ two levels ] and
   `$data{'bird.blue'}` [ one level, literal dot in key ] serialize to
   the *identical* string `bird.blue` — the reverse direction
   [ hash -> string ] becomes ambiguous.

precondition 3 is **not new** — it already matches the existing
project convention from [[feedback-p7-data-nesting]]: *use underscore
for siblings, not dot* [ i.e. adjacent same-level lowercase keys are
named `foo_bar`, `foo_baz`, not chained as separate dot levels ]. as
long as that convention holds, dot-path notation round-trips cleanly
in both directions.

## forward direction [ string -> hash path ] is always safe

even *without* precondition 3, **parsing** a dot-path string into a
`%data` access path is unambiguous — case alone tells the parser where
levels split, deterministically, every time. precondition 3 only
matters for the **reverse** direction [ generating a canonical
dot-path string *from* an existing hash structure, e.g. for display,
addressing, or diffing ].

so: dot-path notation is safe to ship as a **write/access** mechanism
[ "set this address to this value" ] immediately. the **reverse
serialization** [ "what is the canonical dot-path name of this node" ]
needs precondition 3 to hold across whatever subtree is being
addressed.

## non-letter characters [ open question, see below ]

tokens like `slot-addr`, `hop_id`, `read-me`, numeric segments, etc.
contain characters with no case at all [ digits, `-`, `_` ]. the
notation needs an explicit rule for which "bucket" [ uppercase-token /
lowercase-run ] such characters fall into when they appear:

- adjacent to lowercase letters in the same key [ `slot-addr` — almost
  certainly lowercase-run, no real ambiguity ]
- as a standalone token with no letters at all [ rare, but should be
  defined ]

this is flagged as an open question below.

## %DATA / %CODE meta-namespaces [ user's extension idea ]

alongside the per-zenka `%data` [ lowercase, application data ] and
`%code` [ lowercase, loaded subroutines ] hashes, the user proposes
**uppercase sibling hashes** as **metadata-about-the-namespace**
hashes, following the *same* case convention one level up:

- **`%DATA`** — metadata about `%data` keys/namespaces themselves
  [ e.g. provenance, type hints, last-write timestamp, access-level,
  schema version — *about* a `%data` subtree, not data *in* it ]
- **`%CODE`** — keyed by **source-code version**, e.g.

  ```perl
  $CODE{'3TJNHUPSJA-8187.0'}{'base.init_code'}{ ... }
  ```

  i.e. `%CODE` becomes a version-indexed registry of `%code` snapshots
  — every loaded module's source/compiled-form addressable by the
  `protocol-7.src-ver` style version string seen in
  `configuration/protocol-7.src-ver` and the signing pipeline
  [ see `data/md/design/CODE-NAMESPACE-AND-SIGNING-INFRASTRUCTURE.md` ].

this is a clean fit with the dot-path notation's case rule extended
**one level higher**: `%data`/`%code` = lowercase = "the thing
itself"; `%DATA`/`%CODE` = uppercase = "data *about* the thing,
addressed the same way". a dot-path string could then optionally be
prefixed to select which top-level hash it addresses
[ see open question 3 ].

## relation to existing work

- [[feedback-p7-data-nesting]] — the underscore-vs-dot sibling
  convention this notation depends on (precondition 3)
- `data/md/design/CODE-NAMESPACE-AND-SIGNING-INFRASTRUCTURE.md` —
  existing version-string format (`protocol-7.src-ver`), the natural
  key-shape for `%CODE`'s top-level keys
- [[topic-addressing-trinity]] / [[topic-checksum-addressing]] — this
  notation is a *human/config-facing* address form; the addressing
  trinity (named tree + checksums + timestamps) is the underlying
  machine address space. dot-path strings would resolve into trinity
  addresses, not replace them
- `data/md/design/HARMONIC-TREE-ADDRESSING.md` — tree/space/field as
  one structure; dot-path notation is one more "rotation" — a textual
  serialization of tree paths

## open questions

### 1. non-letter character bucketing

how do digits, `-`, `_`, and other non-alpha characters classify when
tokenizing a dot-path string?

- **option A — "non-uppercase" bucket** [ recommended ]: any character
  that is not an ASCII uppercase letter [ `A-Z` ] is treated as
  belonging to a lowercase run. simple, single regex class
  (`[^A-Z]`), matches natural reading of `slot-addr`, `hop_id`, `v7`,
  `protocol-7` etc. risk: a token that is *entirely* digits/symbols
  with zero letters [ rare ] still parses fine under this rule — it's
  just always "lowercase-run-like".
- **option B — explicit allow-list per key**: only `[a-z0-9_-]` legal
  in lowercase runs, anything else is an error. more defensive, more
  upfront validation cost, probably unnecessary given option A's
  simplicity.

### 2. mixed-case keys — disallow entirely, or escape hatch?

precondition 2 says mixed-case keys [ `fooBar` ] aren't representable.
options:

- **option A — disallow, full stop** [ recommended for v1 ]: any
  existing `%data` keys with mixed case simply cannot be addressed via
  dot-path notation; callers use direct `$data{...}` access for those.
  given protocol-7's existing lowercase-snake / UPPERCASE-constant
  convention, mixed-case keys should already be rare-to-nonexistent in
  practice.
- **option B — escape syntax**: introduce an explicit escape [ e.g.
  backtick-quoted segment `` CAT.`fooBar`.SOUND `` ] for the rare
  mixed-case key. adds parser complexity for a case that may never
  occur — defer until a real key demands it.

### 3. top-level hash selection [ %data vs %DATA vs %code vs %CODE ]

how does a dot-path string indicate *which* top-level hash it
addresses?

- **option A — leading sigil/prefix token**: e.g. a bare leading `.`
  or a reserved first-uppercase-token (`DATA.CAT.LOVES...` vs
  `CODE.3TJNHUPSJA-8187.0...`) selects the meta-hash; absence of the
  reserved prefix defaults to `%data`. simple, stays within the
  existing case grammar — `DATA`/`CODE` are just uppercase tokens like
  any other, made special by position [ first token only ].
- **option B — separate notation entirely for meta-hashes**: dot-path
  notation only ever addresses `%data`/`%code`; `%DATA`/`%CODE` get
  their own (possibly identical-shaped) notation invoked through a
  different API entrypoint, never mixed in the same string. cleaner
  separation of concerns, but doubles the surface area for what is
  conceptually "the same kind of address".
- recommendation leans **option A** for symmetry with the rest of the
  notation [ everything is dot-path strings; only the *resolver*
  differs based on the leading token ], but this should be revisited
  once there's a concrete `%DATA`/`%CODE` consumer to validate against
  — same pattern as [[topic-os-command-zenka]]'s relationship to
  [[topic-ui-show-security-levels]].

### 4. `%CODE` key shape — full version string, or split?

`$CODE{'3TJNHUPSJA-8187.0'}{'base.init_code'}{...}` uses the full
`<checksum>-<epoch>.<rev>` version string as a single top-level key.

- **option A — single opaque key** [ as proposed ]: simplest, matches
  `protocol-7.src-ver` format as-is, no parsing of the version string
  required by `%CODE` consumers.
- **option B — split into checksum / epoch / rev sub-levels**: e.g.
  `$CODE{'3TJNHUPSJA'}{'8187'}{'0'}{'base.init_code'}{...}` — enables
  range queries [ "all versions in epoch 8187" ] via normal hash
  traversal without string parsing, at the cost of a deeper, more
  rigid structure. only worth it if epoch-range queries become a real
  use case [ see `data/md/design/EPOCH-CHECKSUM-EXCLUSION-ADDRESSING.md`
  for related epoch-based exclusion logic that might want this ].

## status

idea / notation proposal only — not yet implemented. no parser,
resolver, or `%DATA`/`%CODE` hashes exist yet. natural next step once
picked up: a small `base.data.dot-path.*` (or similar) parser/resolver
pair implementing the forward [ string -> path ] direction first
[ always safe ], with reverse serialization gated on auditing
precondition 3 across whatever subtree it's applied to.

#,...,...,...,...,...,...,...,...,...,...,...,...,...,...,...,...,...,...,...,

#,,,.,,.,,.,,,,,,,,,,,.,,,...,,..,,,.,...,...,..,,...,...,...,,,,,.,.,,,.,.,,,
#VJS5GSGSAD5YJIZOCYNGXKM65KIQY43NYZLCQ5XHW4CVDF5CFLFA7UI6ULFAZDDJFPEHLVUEHYXKE
#\\\|42OKNFAJOVYZXZ25HTTOXQ7ZMTI3UOIXTKEXQM2HJC4YNV2KJAS \ / AMOS7 \ YOURUM ::
#\[7]XB45KKNAPJ7F5BSI6CUL3CW2YYFMGIKYYJ3ZY7EX376QHI3ZG2CQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
