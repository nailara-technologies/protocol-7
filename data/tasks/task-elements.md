## task elements : one native, referenceable form for todos, task-zenka tasks and briefs

owner direction 2026-11-25 : a session is a round of a task [ as a tool call is a round of a
session ] ; tasks and sessions are many-to-many [ data/tasks/claude-zenka.md, coding zenka
item 6 ]. that needs a generic task element with references -- format, ids and timestamps all
NATIVE. anything not native afterwards is marked for refactoring.

### today : three forms of the same thing

- todo list elements with short ids [ 4ZW, WEQ, FKS, VWF, ZA2 .. ] -- referenced in commit
  messages and memory files
- task zenka tasks [ ZDPA6FI .. ] : status, history, park \ continue \ claim
- briefs in data/tasks/*.md : stages, open points, decisions

### the element

- identity : ONE native short id [ the existing todo id scheme -- read it before inventing ] ;
  the same id in todos, the task zenka, commits, memory and sessions
- timestamps : ntime [ numerical ntime at least ] -- never unix seconds in stored form
- state : open, active, parked [ waiting for : time \ signal \ element \ decision \ budget ],
  done, dropped
- references, one key line each, typed :
    part-of \ depends \ blocks     other elements
    brief                          data/tasks/<file>.md [ section ]
    session                        coding session registry entries
    commit                         hashes
    sign \ decision                sign queue entries, open decisions
    file \ zenka \ host            what it touches
- text : title, a short body, notes appended [ never rewritten history ]

### native form

p7 config style, one block per element, readable and hand-editable :

    element.4ZW.title     = nameserv cache
    element.4ZW.state     = parked
    element.4ZW.waits     = decision:D17
    element.4ZW.created   = <ntime>
    element.4ZW.brief     = data/tasks/4ZW-nameserv-cache.md
    element.4ZW.commit    = 915c78fb87
    element.4ZW.session   = claude-1446

### rule : extend the native formats, do not reach for classic ones [ owner 2026-11-25 ]

when an element needs something the native forms cannot express yet [ lists, nesting, multi-line
text, typed values, references ], the native format is ADJUSTED OR EXTENDED -- in AMOS7::Config
and the native writer, documented, tested -- instead of introducing a classic format [ json,
yaml, sqlite, toml .. ] for it. classic formats stay at the edges [ external exchange ] only.

why it holds [ owner ] : native is the HUB, every common format a converter at the edge [ json,
yaml, xml, toml, csv .. -- and protocols alike ]. whoever has a favourite or a constraint gets it
covered, so "it should have been only json" has no ground ; inside, one consistent form keeps
what the classic ones lack [ AMOS checksums \ signatures, ntime, host overlays, readable without
a parser, extensions we decide ourselves ]. the converters are first-class : round-trip tested.

### parts to build first

1. a shared NATIVE WRITER [ hash -> p7 config lines, stable key order, atomic write ] next to
   AMOS7::Config::normalize_lines [ the reader ] -- modules writing their own `key = value`
   lines today [ event buckets, usage pace, coding sessions \ sign queue .. ] move onto it
2. native <-> yaml converter from existing parts : AMOS7::Config + the writer +
   format.yaml.load_str \ dump_str [ yaml for external exchange only ]
3. the element store in the coding zenka ; the task zenka executes elements [ its tasks become
   elements with state + history ] ; the todo list and the briefs become views

### perspective : thinking as content-addressed elements [ owner 2026-11-25 ]

decision \ reasoning steps in a shared native form -- structure, not data -- get an identity
[ BMW over the normalised form ], can be cached [ worked out once, reused by every session,
agent, host ], evaluated in parallel [ only dependencies order them ] and shared without leaking
[ structure shared, values local -- as n7fs blind replicas hold sealed content ]. small cases
exist already : the sign queue's `criteria hold -> sign -> commit` is a decision node.

first step without a new language : the DEDUP TREE. session rounds [ reasoning, tool rounds,
decisions -- the session archive ] stored chunked and checksummed show the overlap by themselves :
recurring chunks across sessions, agents and tasks mark what is worth caching ; the language
follows from what is actually shared, not designed ahead [ extend what exists ].

the dedup tree NORMALISES : equal content in different wording \ formatting lands on one node.
those normalised nodes are where a later symbolic form attaches -- a symbol per node, not per
phrasing ; translating language to symbols then means mapping text onto existing nodes, and the
symbols inherit the nodes' identity, cache and sharing.
the symbolic form is the ALWAYS CURRENT TREE LANGUAGE [ owner ] : derived, not designed --
new content brings new nodes and symbols, nodes merged by normalisation merge their symbols ;
it cannot go stale, it is a view of the tree [ as native need not be static, one level up ].

### open

- how far todo ids and task-zenka ids merge [ one scheme, or a mapping ]
- migration of the existing todo list and task history
- which views first : the dashboard [ portrait panel ], the handover, `coding.elements`

#,,,,,,..,,,,,,..,,,,,.,.,..,,,..,,,.,,..,,,.,..,,...,...,,,,,...,...,,..,,,,,
#MI2QQVQT5GRDPEW4ZAUUEN7OGXCPLLRJIXHWBUN2GYCEPTFXSUBNR76KBGGQ6LLALPG7SSEID5YA6
#\\\|UK4DQPGTDBZA4G4BEQNZGTVCV2UKHAUFWQZCJF6BXPA6S5RZCUA \ / AMOS7 \ YOURUM ::
#\[7]HLJVXMLBPOWOXWHPHDDZ55NB4W5TXJNW2WOPMLYH73AXUZBQPGBQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
