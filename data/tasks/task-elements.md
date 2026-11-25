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

### open

- how far todo ids and task-zenka ids merge [ one scheme, or a mapping ]
- migration of the existing todo list and task history
- which views first : the dashboard [ portrait panel ], the handover, `coding.elements`

#,,,,,...,,,,,..,,,,.,.,.,..,,.,,,..,,.,,,,,,,..,,...,...,..,,,.,,.,,,,..,..,,
#JDXXHWRFSFQPTCLRHGJUVCBAYEXSGKDHO5N22GV5CC3Z3QCXEOXAJLGPK5KIYYFWD5HSRC35B7KVQ
#\\\|GDT7BQXYWAOPBN52VPWQLOOIV4GQRBBX5A6QYU5Y3IWKHWHNOPQ \ / AMOS7 \ YOURUM ::
#\[7]FWJYIG7GM2OCQ2O5M5OXUNYKFDYB4RJCL3PWGRNM2OQIY5RT74CY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
