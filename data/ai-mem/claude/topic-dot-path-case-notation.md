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

#,...,...,...,...,...,...,...,...,...,...,...,...,...,...,...,...,...,...,...,

#,,,.,,.,,,.,,...,.,,,..,,.,.,,,,,.,,,.,.,,,,,..,,...,...,.,.,...,,..,..,,.,,,
#NMKYWOKILIROQ3SNS76R5HSD4EHSKFVPVXKHXVOTT7SQZBSXTBWWGD5SOUXLLDXY3VNQNO6ZSO4MO
#\\\|U25Q3Z7722RANB2T7OINH2QP6NUS2ZQQKQAN4U3E75CT75WWU2Y \ / AMOS7 \ YOURUM ::
#\[7]NJEGAT3PBNMFSKFJJ4NNJ3CGO7DSHHBFYLSCVNJWJJOKXQVRDQAA 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
