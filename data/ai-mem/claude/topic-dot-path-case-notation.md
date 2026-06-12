---
name: topic-dot-path-case-notation
description: dot-path case notation design doc — uppercase=path level, lowercase-run=literal-dot key; %DATA/%CODE meta-namespace idea; 4 open questions
metadata:
  node_type: memory
  type: project
  originSessionId: 9ecacc19-6948-4beb-892e-5af7d7d24068
---

idea captured + written up 2026-06-11. design doc:
`data/md/design/DOT-PATH-CASE-NOTATION.md`.

## the notation

`CAT.LOVES.bird.blue.SOUND = TRUE` -> `$data{'cat'}{'loves'}{'bird.blue'}{'sound'} = TRUE`

uppercase tokens = single path levels (lowercased). lowercase tokens
(possibly dot-joined runs) = one path level whose key keeps its
internal dots. uppercase tokens always break/separate adjacent
lowercase runs.

## key findings

- **forward (string -> hash path) is always unambiguous** — safe to
  implement immediately as a write/access mechanism.
- **reverse (hash -> canonical string) needs a precondition**: no two
  adjacent tree levels may both be single-segment dot-free all-lowercase
  keys (else `{'bird'}{'blue'}` and `{'bird.blue'}` both serialize to
  `bird.blue`). this precondition already matches the existing
  [[feedback-p7-data-nesting]] convention ("underscore for siblings,
  not dot"), so it should hold in practice if that convention is
  followed.
- mixed-case keys (`fooBar`) are NOT representable — out of scope for v1.

## %DATA / %CODE meta-namespace extension (user's idea)

uppercase sibling hashes one level up from `%data`/`%code`:
- `%DATA` = metadata *about* `%data` namespaces (provenance, schema,
  access-level, last-write)
- `%CODE` = version-indexed registry of code, e.g.
  `$CODE{'3TJNHUPSJA-8187.0'}{'base.init_code'}{...}` — keyed by the
  `protocol-7.src-ver` style version string (see
  `data/md/design/CODE-NAMESPACE-AND-SIGNING-INFRASTRUCTURE.md`)

extends the case rule one level higher: lowercase = "the thing",
uppercase = "data about the thing", same addressing grammar.

## first-element case-sensitive escape (2026-06-11 addition)

new idea: make the **first element only** case-sensitive, and let it
select the actual perl package/hash by name in `main::` — not just
`%data`/`%code`/`%DATA`/`%CODE`. i.e. the reserved-first-token idea
(open question 3 above) generalizes: instead of a small fixed enum of
top-level hashes, the first token can name *any* `main::`-namespace
hash/glob, case-sensitively.

- this would let dot-path lines address arbitrary zenka-internal
  symbol-table entries beyond `%data`, not just the blessed
  `%data`/`%code`/`%DATA`/`%CODE` set.
- because a zenka's compiled subs, lexical closures over `%code`, and
  `%data` together constitute "the zenka," a notation that can name all
  of these in one uniform line format starts to look like a **zenka
  transfer protocol** — a serialization that can represent not just data
  but (pointers to/addresses of) running code.
- user's framing: "in form could overlap to code running on routes of
  abstracted distributed hyperspace" — i.e. this notation, plus
  [[checksum-parenting-namespace-trees]] (checksum-addressed code,
  consumer feature 6 in [[topic-deparse-code-features]]: ascii-frame as
  code transfer container) and [[topic-checksum-addressing]] (route =
  field/symmetry condition, not stored path), could converge: a dot-path
  namespace line becomes both an *address* (where) and a *transfer unit*
  (what), and "running on a route" becomes meaningful if routes
  themselves can carry/host addressed code.
- not elaborated further yet — flagged as a convergence point between
  three previously-separate topics (dot-path notation, checksum
  parenting/addressing, deparse-code transfer container). worth folding
  into a doc once more nodes arrive.

## open questions (in design doc)

1. non-letter char bucketing (digits/-/_) — recommend "anything not
   A-Z is lowercase-run" (option A)
2. mixed-case keys — disallow for v1 (option A), escape syntax deferred
3. top-level hash selection (%data vs %DATA vs %CODE) — leans toward
   reserved-first-token (`DATA.*`/`CODE.*`) but defer until a real
   %DATA/%CODE consumer exists
4. %CODE key shape — single opaque version-string key (option A) vs
   split checksum/epoch/rev sub-levels (option B, only if epoch-range
   queries become real — see EPOCH-CHECKSUM-EXCLUSION-ADDRESSING.md)

## relation

[[feedback-p7-data-nesting]], [[topic-addressing-trinity]],
[[topic-checksum-addressing]] (dot-path is a human-facing serialization,
trinity is the underlying machine address space).

## status

idea + design doc only, not implemented. next step when picked up: a
`base.data.dot-path.*` parser/resolver pair, forward direction first.

#,,.,,.,.,.,.,.,,,,.,,.,,,.,.,,..,,,.,,,,,,..,..,,...,...,.,,,,..,,,.,,,,,,,,,
#QYOGFB6774ECLMFAMLAPHSAQU7DLRPQFWMAFDA2T4HDPMFZT6JKASDGW5ALWQ5QUG274D5EVBGA5M
#\\\|KV3Q3GVZLX5VXTE5V2Y2OWT4PTWMBL3U46SVKZ4RJJS7HNGOBR7 \ / AMOS7 \ YOURUM ::
#\[7]4OGTFVQM3A4NQYF2W2CZCBRFH6AEZCI76OYSUJWDSGX5DDJRHKDQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
