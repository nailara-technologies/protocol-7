# task claims, gpu lease and quiet retries : rework

status : OPEN 2026-11-26 -- findings from the load incidents of that day, nothing designed yet.
owner : "the claim handling needs refinement anyway, was causing issues itself".

## what happened [ fixed as stop-gaps ]

- **silent re-ask loop** [ f89cde7816 ] : models.task.peek-claim asked coding.inference-status,
  the reply re-ran peek-claim, models.task.pin-accepted answered UNKNOWN again for a pinned,
  unloaded model when the fresh status carried no idle time -- models, coding and cube at full
  cpu, no log line. stop-gap : FALSE there, plus an `asked` marker on the re-run.
- **lease kept by name, not instance** [ 6977613221 ] : a restarted invoke-web acquired, tick
  dropped the request as 'already held', no grant was sent, the lease expired after 45 s and
  went to coding. stop-gap : an acquire from the holder refreshes it and sends the grant.

## still open

1. **coding without a lease answer** : `models gpu lease request unanswered : using existing
   memory check` -- under critical memory pressure models did not answer in time and coding
   fell back to its own vram check. it may then spawn its gpu llama-server while invoke-web
   holds the lease. wanted : no lease answer = stay held, retry on a base.interval.next rhythm.
2. **claims** : the claim, peek, capacity chain re-sends requests from reply handlers ; the 60 s
   local_models cache is the only brake. every re-send needs a marker or a delay. claims holding
   slots [ ttl 1800 s, lease renewals ] need a review against the task zenka's own deadlines.
3. **lease identity** : holder by name only. an instance id [ or the session ] would let models
   tell a restarted owner from the running one, instead of the re-acquire rule.
4. **stale waiting entries** : `waiting : coding` stayed after coding was terminated ; harmless
   [ the grant route fails ] but the state lies.

## quiet retries [ owner's list ]

the owner terminated the external zenka by hand to get work done ; things kept restarting and
logging anyway :
- cube : hundreds of `offline : 'external' : 'zulum.task.next'` \ `zulum.task.subscribe`
- models : `task notice stream external.zulum.task : subscribe refused : client not present`
  on a steady rhythm

wanted : a manual terminate is respected [ no restart, no retry storm ] ; callers of a zenka
that is off back off on base.interval.next and log once per state change, not per attempt. the
start \ terminate time parameter for keeping a zenka off exists -- check that the subscribers
honour it too.

## principles for wirings [ owner 2026-11-27 ]

no part behaves unaware and makes noise : the mechanisms exist, extend them where they fall
short, never fall back to patterns of 'regular' software [ blind retries, the router doing the
work ].

- **state, not polling** : cube knows a zenka is offline, `present` answers presence. a caller
  subscribes to 'back online' [ events ] instead of retrying.
- **intent, not guessing** : a manual terminate or the time parameter is a recorded intent ;
  callers get 'off on purpose, until ..' once and go quiet.
- **rhythm** : a retry that stays needed uses base.interval.next with kept state.
- **log on change** : once per state change, not per attempt.
- **core stays, features are plugins** : a proven core path is not rewired for a new feature.
  the feature [ eg. each polling category : memory, io pressure ] is a plugin.* module with its
  own rhythm and state, behind ONE narrow hook the core asks [ 'extend this timeout ? by how
  much' ] ; no answer or disabled = the core behaves as before the feature existed. a plugin
  never touches the core's timers. off = not loaded, not skipped inside shared code. [ the
  v7-zenki pressure branch inside heartbeat_response_timeout is the counter-example : the
  SIGSEGV path of 2026-11-26 ran through it ]
- **later : auto-disable failing sub-features** : once errors can be traced and categorized, a
  plugin that keeps failing can be switched off by itself -- decided by the installation's
  operation mode [ a production host disables and records, a development host stays loud ]. a
  faulty feature then costs itself, never the core.

## related

- data/tasks/v7-zenki-anchor.md -- its 2026-11-26 spin [ signals had no effect ] matches the
  SIGSEGV loop found the same evening [ fbd58a42de ] : worth re-reading its 'why'.
- memory : feedback-busy-zenka-gdb-curcop-and-event-faults.md

#,,.,,,,.,...,.,.,.,,,,..,...,,,,,.,,,,,,,..,,..,,...,..,,...,,.,,.,.,,.,,,,,,
#TE2A3GNIITKBPRELPZCVH7AHK6AIHDQQ6XGZDZ27DBURPFUUVYJVR3PWHCXPOYSGWSFDUT23GMWC2
#\\\|DK4OGV5R6GPTW2XHZXMZQVBGJTCY42QWQTZY65BISYR3GWNLFG2 \ / AMOS7 \ YOURUM ::
#\[7]V3C5JSB5EQWTEQVLLTI3JDAWG5ALONYMS3JWXWILJM3JQGFWM6AY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
