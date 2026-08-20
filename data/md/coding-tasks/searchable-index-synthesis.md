# task: synthesize scattered searchable-index design docs into one session state reference

## why

the searchable checksum-indexed dataspace is an active initiative [ see
`data/ai-mem/claude/topic-searchable-index-and-visualization.md` ], but the
underlying design is spread across ~7 documents written at different times
and different abstraction levels. before we start implementing, we need one
consolidated reference document that:

- gives the unified architecture in a single diagram
- maps every relevant module to its current status [ exists / stub / planned ]
- flags tensions or gaps between the scattered designs
- lists actionable sub-components in priority order, each sized for one
  kimi-task-sized chunk
- is written with styled web template rendering in mind [ section anchors,
  clear heading hierarchy, p7ref references where applicable ]

this doc will become the context hand-off for subsequent implementation tasks.

## input documents to read [ in this order ]

1. `data/ai-mem/claude/topic-searchable-index-and-visualization.md`
   [ the current vision — starts the conversation ]
2. `data/yaml/coding-tasks/phase-2-indexer-checksum-filesystem.yaml`
   [ the full 70-110h plan from feb 2026, never executed ]
3. `data/md/design/INDEXER-SEARCH-ZENKA-INTEGRATION.md`
   [ harmonic / checksum / visual / wave index design, 4 search modes ]
4. `data/md/design/CONTEXT-TREE-INDEXCUBE-INTEGRATION.md`
   [ @INDEXCUBE routing stack, P7REF = TYPE:CHKSUM7:ADDR_B32,
     1001 cube topology, 19-bit border addressing, DTM, covert channel ]
5. `data/md/design/VISION-INDEX.md`
   [ meta-index of 10 vision docs — skim, follow the link to
     UNIFYING-PRINCIPLE-CHECKSUM-COORDINATES.md and read that too ]
6. `data/md/system/CODING_TASK_KNOWLEDGE_BASE_INDEXING.md`
   [ knowledge base dedup via paragraph clustering / fact extraction ]
7. `data/md/coding-tasks/indexcube-routing-stack.md`
   [ @INDEXCUBE push/pop/here/depth spec ]
8. `data/md/research/INDEX-DATA-FABRIC-DOCUMENTATION.md`
   [ data sync fabric reference library index — read the index itself,
     then selectively read the referenced docs it points at ]

also skim [ quickly, just for context ]:
- `data/asc/what-AI-thinks/` directory listing [ receipts efficiency principle ]
- `data/ai-mem/claude/topic-checksum-addressing.md`
- `data/ai-mem/claude/topic-namespace-tree-intelligence.md`

## code scan — map specified modules to actual state

for each doc, cross-reference the modules it mentions against what
actually exists in `src/`. use `list_modules` or `search_code` tools.

key namespaces to survey:

| namespace | specified in | actual state to verify |
|---|---|---|
| `src/index.*` | topic-file + implicit everywhere | some modules exist, `add-path` is stub |
| `src/storage.*` + `plugin.storage.*` | storage zenka files | kimi-generated, style issues, largely untested |
| `src/base.indexcube.*` | CONTEXT-TREE doc [ phase 1 "DONE" ] | 5 modules exist — verify they work as specified |
| `src/context.tree.*` | CONTEXT-TREE doc [ phase 1 "DONE" ] | ~10 modules exist — list them and their roles |
| `src/base.checksum-fs.*` | phase-2 yaml [ 7 modules planned ] | confirm: NONE exist |
| `src/search.*` | INDEXER-SEARCH doc | confirm: NONE exist [ not even the zenka ] |
| `src/indexer.*` | INDEXER-SEARCH doc | confirm: NONE exist |
| `src/knowledge.*` | KNOWLEDGE_BASE_INDEXING doc | confirm: NONE exist |
| `src/base.p7ref*` / `*.p7ref.*` | CONTEXT-TREE doc | several exist — list roles |

produce a "module status matrix" section in the output doc.

## output

write to: `data/md/design/SEARCHABLE-INDEX-SESSION-STATE.md`

required structure:

```
# Searchable Index — Session State Document

## 1. Vision [ one-paragraph distillation ]
## 2. Unified Architecture [ one diagram replacing the 5 scattered ones ]
## 3. Module Status Matrix [ the table you built in the code-scan step ]
## 4. Design Tensions & Open Questions
## 5. Actionable Sub-Components [ priority-ordered, kimi-task-sized ]
## 6. References [ links back to the 8 source docs, each with a one-line
                   summary of what it uniquely contributes ]
```

## design tensions to investigate [ at minimum ]

section 4 of the output should address these explicitly, not paper over:

1. the new topic file proposes nodes as "single base32 character in namespace
   grid" [ width-1 = zero attack surface ]. the CONTEXT-TREE doc uses
   19-bit border addressing [ 13-bit L-matrix + 6-bit face selector ].
   how do these reconcile? is width-1 a degenerate case of the larger
   scheme, or a genuinely different addressing plane?

2. `index.gen_path` already implements anti-entropic path generation
   via AMOS checksum character matrix with truth filtering. does this
   subsume the phase-2-yaml's "directory structure specification" task,
   or complement it?

3. `@INDEXCUBE` is described as per-zenka routing stack. the checksum
   dataspace vision describes a network-wide grid. is the per-zenka
   stack a local view into the shared grid, or something independent?

4. phase-2 yaml proposes `base.checksum-fs.*` [ 7 modules ]. CONTEXT-TREE
   doc says storage goes through `plugin.storage.checksum.map-file`
   [ which exists, kimi-generated ]. which is the intended storage layer?
   are these the same thing under different names, or actually different?

5. `search` zenka is specified but not implemented. should search be a
   standalone zenka or a set of commands on an existing zenka
   [ e.g. expand `index.*` to include search ]?

## priority ordering — guidance for section 5

actionable sub-components should be ordered by:
1. things that unblock visualization [ space.v7.ax already works; what does
   it need to show real data? ]
2. things that validate the architecture on a small test case
   [ code repo indexing first — smallest scope, no dedup needed ]
3. things that extend to the broader vision [ knowledge base dedup, network
   discovery, multi-node ]

for each sub-component, include:
- title [ one line ]
- effort estimate [ small / medium / large ]
- blockers / dependencies
- acceptance criteria [ 2-4 bullets ]

## style and length

- this is a design/reference doc, not code — normal english prose + markdown
- aim for ~400-600 lines total [ concise, scannable, not exhaustive ]
- use markdown tables where they help
- no emoji
- heading levels: `#` for title, `##` for top sections, `###` for sub-sections
- when referencing code, use backticks and full module paths
  [ e.g. `src/index.gen_path` not `index.gen_path` ]
- when referencing the 8 source docs, use relative paths from repo root

## verification

before marking task complete:

1. confirm all 8 input documents have been read
2. confirm the module status matrix has been built from actual filesystem
   scan, not from memory of the docs
3. confirm section 4 addresses all 5 tensions listed above [ briefly is ok,
   but each must be acknowledged ]
4. confirm section 5 has at least 5 actionable sub-components, each with
   all four required fields
5. the doc should be self-contained — a reader who has never seen the
   8 source docs should get the full picture from this one file

## not in scope

- do NOT write any code / new modules
- do NOT edit the 8 source documents
- do NOT implement any of the sub-components listed in section 5
- this is a pure synthesis task — reading, cross-referencing, writing one doc

the output doc becomes the input to the NEXT implementation task. keep it
useful as a reference, not as implementation instructions.

#,,..,...,...,,,,,,,,,..,,.,,,,,,,...,,,.,..,,..,,...,...,.,.,,,.,...,.,.,,..,
#OLKCANJSCPGDPZUAU3CP2RXL3LUGW5CFRKK5XI4EQ4UHZYD35D7XVDF2QSHGBF5FTRPJV2UTHZIOC
#\\\|6LUZPSH4XKUFLBMIL6MINFBZWZV2RARMKXPTUTT5K3AKJL7L5MJ \ / AMOS7 \ YOURUM ::
#\[7]ZDADN7XN5MMYDLSJ7VYBDE6M3VZJCAXAOAAISYTBML3GX7XGC6AQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
