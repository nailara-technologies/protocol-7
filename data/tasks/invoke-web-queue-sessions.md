# invoke-web : put a render session aside, pursue a new idea, resume

idea [ user, 2026-09-29 ]. not built. read `CLAUDE.md` first. builds on the
queue control of 2bfc5f649 [ queue-order, queue-interactive, queue-front ;
`invoke-web.queue.db` ].

## the need

a long render session is queued [ e.g. 85 pending items ]. a new idea comes
up and should be tried immediately -- the session must step aside completely
and resume unchanged once the experiment concludes. interactive mode already
puts new items first, but the old session still runs as soon as the new
items are done, and experiments often take many rounds.

## two levels

1. park [ build first : small, lossless ]
   - `invoke-web.session-park <name>` : store every pending item's current
     priority under <name> [ state file ], then set them far below anything
     new [ e.g. priority - 1000000 ]. nothing leaves the queue
   - `invoke-web.session-resume <name>` : restore the stored priorities
     exactly [ items that finished \ failed meanwhile are skipped ]
   - `invoke-web.sessions` : list parked sessions [ name, item count, age ]
   - resume mode per parked session [ user, 2026-09-29 ] :
     `manual` [ default : only session-resume ] |
     `empty` [ as soon as the queue runs empty ] |
     `cold` [ cold-queue : the experiment is over AND the machine rested --
     queue empty, no new item added for N minutes [ e.g. 30 ], GPU below a
     temperature threshold ; then resume on its own, e.g. while the user
     is asleep ]
   - mirror the coding zenka [ user, 2026-09-29 ] : its cold queue is
     `task.handler.cold-queue-sweep` [ `task.cmd.trigger-cold-queue` ], the
     GPU temperature arrives as a SUBSCRIPTION from X-11 -- no polling :
     `<X-11 sid>.gpu_metric` args `temp subscribe` / `.gpu_load` args
     `subscribe`, wired in `coding.init_code` [ ~:700, via
     `base.zenki.resolve_primary_sid` + `protocol-7.route-send` ] into
     `coding.handler.gpu_temp_update`. invoke-web subscribes the same way
     [ nvidia-smi works under WSL too : RTX 3060, 54 C idle -- fallback only ]
   - the cold check doubles as a guard : never auto-resume while the GPU is
     still hot from the experiment [ thermal cycling \ back-to-back load ]
   - interplay : interactive mode keeps pushing new items to the front ;
     park must not touch in_progress items [ like queue-order ]

2. export \ import [ real session storage, later ]
   - export the pending items [ session graph, field_values, workflow,
     batch_id, origin \ destination, priority ] to
     `/var/protocol-7/invoke-web/sessions/<name>.json`, then remove them
     from the queue ; import re-creates them [ api enqueue vs db insert :
     check which keeps everything, incl. batch grouping ]
   - removal ONLY after the export was read back and verified complete --
     the user's queue must never lose an item [ same rule as : never cancel
     a running item ]
   - several named sessions side by side ; possibly portable between nodes

## open questions

- does invoke.ai's own ui \ batch logic react to items with negative
  priority [ display order, anything relying on priority >= 0 ] ?
- export : is `field_values` + graph enough to re-create an item 1:1, or do
  batch-level records [ batch table ] have to travel along ?
- cold mode : reuse the task zenka's cold-queue sweep directly, or only its
  shape [ it serves the coding task queue ] ; which signals it combines

#,,.,,..,,.,.,..,,..,,..,,.,,,,,.,,.,,,,.,,..,..,,...,..,,...,..,,,.,,,.,,,,.,
#XJUXD3MOIS6KXTV47T7NVABMG7L4YJCRJLPW2JFWUBDRCZFTJE27K3RDVIEQLDXVW54W5ZX4GK4UO
#\\\|IAKXZGHJGALTYPDNZPNCVQLFTIJ6F5A7OSEYXFZNM25U4E343HJ \ / AMOS7 \ YOURUM ::
#\[7]E53U36WCVA4OIQEZ6VKNZ765RYTWUAVWXVN4FWODO34NSXPAL4CY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
