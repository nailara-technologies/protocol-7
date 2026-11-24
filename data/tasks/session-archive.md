## session archive : deep search and extraction over every agent session

owner idea 2026-11-24 -- for later. the archive does not exist yet ; the files to fill it are
nearly complete.

### sources [ already on disk ]

- claude code sessions : ~/.claude/projects/<dir>/*.jsonl [ every turn, tool call and result ]
- headless claude runs : data/state/claude-runs/*.out [ stream-json, mcp-server-p7 ] and the
  claude zenka's events.log \ session.cfg
- kimi : its session store [ wire.jsonl per session ], data/state/kimi-dispatch-*.out, the kimi
  zenka's acp.log
- chat : data/development/chat/ channel histories and archives [ bin/chat ]
- external chats : exports from duck.ai and other web chats [ owner-held ]
- the memory files [ data/ai-mem ] and handovers as an index into all of it

### what it should do

- one archive : each session normalized into one readable form [ p7 config style headers, one
  line per event : time, speaker, kind, text ] -- the raw files stay as they are, the archive
  points back to them
- search : full text plus structure [ by session, date, agent, tool, file touched, commit,
  run id ] ; "where did we decide X", "every session that touched src/events.*"
- extraction : the decision, the code snippet, the command line, the error text and its fix --
  pulled out with its context and a link to the turn
- feeds : the coding zenka [ handovers, open decisions ], the memory zenka [ p7_memory_search ],
  the dashboards

### one search, several stores [ owner 2026-11-24 ]

the archive search merges with what is already planned -- not a separate tool :

- the knowledge repository : data/asc/what-AI-thinks/ [ INDEX.md ; the plan in
  protocol7-holistic-convergence-architecture.yaml : an index zenka that discovers it, a
  checksum-based filesystem index ]
- the memory search [ p7_memory_search \ memory tree zenka ] and the data/ai-mem files
- the design files [ data/md/design/, data/tasks/ ] and the code [ ncode search ]
- the session archive [ above ] as one more source

one index [ checksum addressed, BMW \ AMOS ], one query form, results that say where they come
from [ session turn, design file, memory entry, knowledge page, code line ]. the private layer
stays private : a query from a shared context never sees archive or private-note results.

### rules

- private by default : the archive lives outside the repo [ an n7fs private-layer category ],
  never in git ; secrets [ tokens, keys, account ids ] are masked when an entry is normalized
- checksums BMW \ AMOS, no sha, no json in the archive's own files [ the sources' json is read
  at the edge only ]
- one host holds the writable archive ; others search a read-only copy

#,,,.,,,,,,,.,.,.,,,.,.,.,,.,,,,.,.,.,...,..,,..,,...,...,.,,,,,.,..,,.,.,..,,
#OUATTDNPBBE2NHNBDZ343XASPECQWGX4QRGWO2HOETSIW53N3EDRDVG5K7IPRSFMA5UJXNVP3T36Y
#\\\|AS6UP25UIQHP4OQS2WBP4XWP2ZCVKHFM4AXYIOO557L5RMKVP3I \ / AMOS7 \ YOURUM ::
#\[7]HL7NVFQAQVYEFNWWOTYTLR6BTHWWDCNSGXA7GK4TU53AMLOBPOAY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
