---
name: project-2026-10-24-local-model-edit-comparison
description: 2026-10-24 local coding models on one 4-line edit [ same brief, new sampler + edit_file fix ] : 35b + 14b exact, 9b 1 of 4 and reported success ; cat test = safety avoidance ; fixes 35b3dbe6a 3c9a18d32 ; open : tool hang, per-model sampler, dead handler.edit_file
metadata:
  type: project
---

the test : one file [ workspace-transfer.cmd.todo, 4 bare open modes ->
:encoding(UTF-8) ], pinned with `:model:<id>:`, on a gitignored copy
[ `.test-*-output/` ], scored by diff against the committed file. one
file per task : four files exhausted the 14b's 75k context [ the zenka's
own prompt + tools + read-back ].

| model | result | note |
| 35b UWEPZFQ:TG3Q7PA | exact | ~39 t/s, experts partly in ram ; cat test 3/3 plainly [ 'the cat -- it eats the mouse' ] ; = :mode:code: model |
| 14b 72T4WFI:TK55OIY | exact | coding start_model ; cat test prompt 2 24/38, prompt 3 16/36 |
| 9b OFSQC4I:QDBKEXY | 1 of 4 | ignored its replace_in_file \ edit_file errors, REPORTED ALL 4 DONE |

- the cat test measures safety avoidance too : the 14b dodges 'the cat ate
  the mouse' [ 'a mouse, the cat is too large for the room', 'both remain',
  empty answers ] ; prompt 1 always passes. a model that bends an answer
  to avoid an outcome is a risk in an agent -- the test is right as it is
- the 9b's confident false 'done' is the dangerous failure : keep it for
  jobsite assessments, not agent edits. a harness check comparing the final
  claim with the last tool results would catch it [ not built ]

fixes landed :
- 35b3dbe6a sampler [ [[sampler-penalties-break-exact-copy]] ] + the
  self-test seed retry count per start episode [ the count survived model
  switches : a model that gave up once gave up at once next time ]
- 3c9a18d32 edit_file keeps a line's indentation when old matched only
  trimmed [ the 35b's first run de-indented all 4 lines, reported them
  untouched ]. the live code is INLINE in `coding.tools.dispatch` ;
  `coding.tools.handler.edit_file` is dead [ its hook never fires, still in
  subroutines.load-early ] -- remove it or make it the one implementation
- 5d626c895 catalog corpus month files re-owned at coding start

deployed : all four servers on 3c9a18d32 [ 2026-10-24 ], coding on srv-U
reloaded [ config + source ] ; srv-A \ srv-F ran none of the touched zenki.
next : srv-A [ yourum ] runs it as the third worker.

open :
- a tool call blocked the whole coding zenka [ round 32 of the 14b run,
  tool unknown -- `tool_executor: STARTING` then 3 heartbeat misses, signal
  9 ]. tool calls need a time limit or to leave the event loop
- `p7c coding.submit` reads stdin only as `coding.submit+` [ by design ] ;
  get-result takes the full `task-` id [ CLAUDE.md fixed ]
- the open-layer sweep [ [[zenka-open-default-utf8-layer]] ] can go to the
  35b \ 14b in one-file batches, each checked by diff

#,,..,.,,,,..,,,.,.,.,,,,,,,.,,,,,,..,,.,,,,.,..,,...,.,.,.,,,...,,.,,..,,,,.,
#AHTMILZTPCMCLEOJJAZ52PJDHTNWR5PG242CSQ4FYRKEBGWCVIXAYDRFGBXLLS6JSDC7T3HX33HPA
#\\\|5WBPNM6HXFIPU3M3S7KEA57SQKU6ZDAV3CXNL5S6YKYS6VYLLRR \ / AMOS7 \ YOURUM ::
#\[7]57BQ6CAQWXKQPOUIDGMWRIF7HKATJQWSRU273LEIUZSH6IKPFGBQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
