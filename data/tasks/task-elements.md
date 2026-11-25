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

writer migration list [ ncode-search, 2026-11-25 ] :
- AMOS7::Switch::format_state and its callers : coding.sessions.store, notify.dnd.store
- events.bucket.save, events.bucket.journal, events.signal.journal_write
- usage.pace.observe
- coding.sign_queue.store, coding.sign_queue.describe
- coding.park.store, coding.remind.store
- protocol-7-menu.pending-lines
- network.lease.save, network.dns_policy.save, nodes.ifaces.save
- session_move.export [ manifest ]

first native extension needed : lossless multiline scalar values. the writer currently refuses
multiline \ tabbed values and literal single quotes rather than inventing a syntax.

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
several human languages point to the SAME nodes [ owner ] : a content exists once, not once
per language -- translation becomes a lookup from the node to a phrasing, what one session
worked out in german is the same node in an english one ; the symbols sit above all human
languages as their shared reference. normalise at the level of meaning, not only characters.
non-human sources too [ owner ] : a cat at an empty bowl [ weight \ camera sensor ], a water
level under a threshold -- they point to the same node as the spoken "need to feed the cat" \
"need to change the water", and the same reminder \ notify \ parked task follows. practical
path : sensor events as an events source plugin [ next to timetable \ signal ], the reminder
chain as built 2026-11-25 ; camera input could learn from the rescued tinykittens collection
[ private notes : input for the kitten inference runs ].
it learns from the outcome : the reaction [ fed, door opened, ignored -- seen by the bowl \ door
sensors or an answer on the phone ] labels the cue ; meaning and urgency sharpen over time and
pick the path [ soft cue at home, phone message with the audio clip, loud when nobody reacts ].
rules carry the decision, the learned part refines only what they cannot tell apart.
privacy by addressee [ owner ] : forward only what was meant for someone -- the meow at the
bowl or the door is addressed, the chatter at the birds outside stays home. local by default,
out only with an addressee [ as network silence is a feature ] -- for people the same.

### memory and contexts take the same shape [ owner 2026-11-25 ]

data/md/design/ROUTING-CRYSTAL-HARMONIC-INFERENCE.md says it for routes : "new route traversal ->
adds to harmonic memory", "accumulates until routing is near-instantaneous", branch.route.cache
as its store, symmetric. the same for tasks, thinking and memory : what actual use leaves
behind [ nodes weighted by traversal, current because derived, fading when unused ], not
written snapshots. a CONTEXT is then a fresh selection of the nodes relevant to the task now
[ open items, their conditions, the nodes they touch ] -- what a compaction does crudely today
[ cut the old, summarise ] becomes a lookup in that structure.
the mechanism exists : the dynamic context templates [ data/md/documentation/DYNAMIC-CONTEXT-
TEMPLATES-USAGE.md, data/yaml/context-templates/ -- context assembled per request from provider
commands ; p7-dispatch-rules is one ]. what is missing are PROVIDERS : context.handover [ the
derived open state ], context.elements [ the task's elements, conditions, references ], later
context.nodes. the thesis behind it : topic-dynamic-context-prep-vs-model-size [ prepared
context turns model size into precision more cheaply than compute ] -- seen 2026-11-25 : sonnet
runs with the rules template did work that would have needed opus and rounds of correction.
compaction stays, targeted [ owner ] : per SECTION, not per conversation -- a provider offers
levels [ full, compact, one line ] picked by space and relevance ; introductions to the current
state are written from the RECEIVER's perspective [ the run building a fix reads the state
differently than the one setting a reminder ] ; a compacted introduction is cached per node and
reused while the node is unchanged [ checksum addressed ]. the local summariser
[ coding_summarize ] fits : cheap, for sections, not whole contexts.
compaction as a TOOL the model controls [ owner ] : `context.compact section=<x> level=<y>`,
`context.keep <x>` -- a conscious decision backs the automatic one off for that section. and
state aware : at natural breakpoints the system OFFERS it [ a debugging session reached its
result -> condense the dead ends, keep the finding ; a commit went through -> its preparation
becomes "committed as X because Y" ; a run reported -> keep the report, drop the waiting ] --
an offer, the model may decline. the breakpoints are existing signals [ claude.run.done, the
commit, the sign approval ] -- sections addressed RELATIVE to the current position [ owner ] :
`-1`, `-3..-1` [ position ], `since:commit`, `since:run.done`, `until:result` [ event ],
`topic:<word>` [ the nearest section on it, searched outward from here ], `last:debug`,
`last:decision` [ kind ] -- `context.compact since:commit level=compact` needs no id. the
observer is the model at its point in the context [ OBSERVER-CENTRIC-REFERENCE-SPACE.md ].
and many to many again [ owner ] : a context BRANCHES [ 2026-11-25 ran the place, the C: cleanup,
the kimi runs and the node ideas interleaved ] -- sections form a graph, one section can belong
to several branches [ a sign carrying two tasks ]. relative addresses name the branch :
`-1@place`, `since:commit@relay`, no `@` = the branch the model works on now [ as git's HEAD~1
\ HEAD^2 ]. the finer level of data/tasks/branch-session-dag.md [ sessions as a DAG ].
branches compact by their OWN state [ owner ] : a finished branch down to its result [ the C:
cleanup -> "63 G free, 210 files verified" ], the active one keeps every detail, a parked one
stays at a middle level until it wakes -- nothing relevant in another branch is lost, unlike
today's global compaction that condenses the active strand together with the finished ones.
the offer is one more bucket entry with an `offer-compaction`
action. 2026-11-25 had many such points ; the context grew until automatic compaction took all.

### open

- how far todo ids and task-zenka ids merge [ one scheme, or a mapping ]
- migration of the existing todo list and task history
- which views first : the dashboard [ portrait panel ], the handover, `coding.elements`

#,,,,,.,,,..,,,..,,.,,...,.,.,,,.,,,.,.,,,,,,,..,,...,...,,..,...,...,,.,,,.,,
#IHY2ZLLKO6PJZT4DNBJFH6INSKF427ZJNEZW6U252DLAPG2WZIB5QTOIXTVULPNIO3O5MLC6MPKOE
#\\\|T2QVRRDO5YTPKEK75D3BBHMHHEATNCBFTPFAH3QVH2BCYEXMKKB \ / AMOS7 \ YOURUM ::
#\[7]KB4KXOOCFB2NIHOBI4A5XSUOJH3G6TSFKLJBDWDPNC32AMO5S2BA 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
