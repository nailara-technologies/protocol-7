# dream embedding layer : first concrete step [ from data/md/design/DREAM-EMBEDDING-LAYER.md ]

the design is long-horizon [ four visual domains, aspiration conditioning,
self-reflection ]. this task is only its first buildable slice : idle GPU
time produces renders, each stored with provenance. read `CLAUDE.md`, the
design sections "idle state as dream time" and "dream corpus structure",
and `data/ai-mem/claude/project-images-elfdb-planning-base.md`.

## what exists now [ 2026-09-30 ] to build on

- invoke-web : queue control [ hold \ requeue ], every finished render
  indexed [ `index.on_render` ], output transport + ring buffer
- v7-zenki pressure level [ calm \ elevated \ critical, `p7c
  v7-zenki.pressure` ] and the start gate -- "idle enough to dream" needs
  at least `calm`
- coding \ invoke.ai run side by side at critical pressure -- dreaming
  must never compete with them : `coding-invoke-awareness.md`
- idle signals named in the design : `watch_tiles.inactive_timeout`, the
  on-demand idle timeouts [ `base.zenki.set_ondemand_timeout` ]

## phase 1 : design questions, answered from the code [ read-only ]

1. idle definition : which signals together mean "nobody needs the GPU"
   [ invoke.ai queue empty, coding idle, pressure calm, user idle ] --
   where each is readable today, file:line
2. who submits : a new zenka, invoke-web itself, or the task zenka's cold
   queue [ `task-zenka-cold-queue-gpu-cooldown-trigger` precedent ] ;
   dream items must be lowest priority and yield to any user render
   [ invoke.ai queue priority -- see invoke-web-queue-sessions.md open
   question on negative priority ]
3. provenance record : map the design's fields [ spatial anchor, network
   state, epoch, generation params, lm-vision verdict, aspiration flag ]
   onto what `index.on_render` stores today -- which exist, which are new
4. the prompt source : fixed per visual domain first [ kittens \ elves \
   crop circles \ cosmic space ], no conditioning loop yet

## smallest slice [ after the user's go ]

when all idle signals hold for N minutes : submit ONE low-priority render
from a fixed domain prompt, index it with the provenance fields that
exist, stop the moment a user render or coding task arrives. no
aspiration \ lm-vision loop yet.

## open for the user

idle thresholds, which domains first, where dream renders live [ separate
from user renders in the index ], GPU temperature limits overnight.

#,,.,,...,,..,,..,..,,.,.,,,,,,,.,,,,,...,,,,,.,.,...,...,..,,...,,,.,,,,,.,,,
#NAYMKYTHCDQVAI7FEWFMBUOHHEXFGLXEKIPS7UBXJ7SZOKK3PQH656XGDYM3IX4GM4D3BLQGYLB4K
#\\\|KN4ZFHY7CRS6ZC2NDU6TDHTW6T5BO5RZJUG6OTQY3ZMLYWQUFBE \ / AMOS7 \ YOURUM ::
#\[7]DUKCARWKBKWD7JNMBFJR3ARSZDYW6PVWMQCU4MM6RUPEBOLGJQAQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
