---
name: stream cancel / backchannel design
description: receiver-side stream termination via !TERM! backchannel; cmd_id opt-in; cube translation design; agreed 2026-04-20
type: project
originSessionId: 22e240a2-b6d9-41a1-bfe7-0b6526db01b4
---
## decision [ 2026-04-20 ]

Receiver-side stream termination uses a route backchannel frame:

    (<cmd_id>)!TERM! <reason>\n

- flows receiver → sender through the existing authenticated route
- cube handles cmd_id translation between client-visible id and routed id,
  and validates it [ prevents cross-zenka id guessing ]
- producer's next `base.stream.push` returns 0 via sticky cancel gate
- `cancel-stream` command retained for cube-local stream abort only
  [ where cube itself is the producer, no routing involved ]

**Why !TERM!:** existing `!TERM!` token was informative-only, never
functionally routed or wired. Repurposed here as the route-backchannel
termination signal. Original "admin terminates a P7 link" case becomes
`DISCONNECT <reason>\n` — a plain peer-direct notice, no routing, no
cmd_id, no special punctuation.

## cmd_id requirement for stream initiators

Sending a cmd_id prefix with a command is currently optional [ e.g.
`(12345) mod-test.strm-start 102400` ]. For streams the client may want
to terminate, it **must** supply one — without it, the client has no
handle to reference in `!TERM!`.

Cube cannot implicitly manufacture a client cmd_id retroactively; it only
assigns internal routing ids.

**Implicit lookup — agreed default behaviour:** bare `!TERM! <reason>\n`
with no cmd_id targets the most-recently-opened stream when streams exist.
Implementation: highest cmd_id key in `$session->{'streams'}` [ cmd_ids
are monotonically increasing so highest = most recent ; no extra tracking
needed ]. Always log at level 1: `!TERM! no cmd_id : implicitly targeting
cmd_id=M [ most recent ]` for visibility.
Configurable via session flag `stream_term_implicit` [ default true ] —
producers managing multiple concurrent streams can disable for safety.
Useful for: manual protocol interaction, simple single-stream zenki that
do not generate their own command ids.

**How to apply:** when wiring the !TERM! propagation path in cube and
base.handler.command, require cmd_id on the client side and document it;
optionally implement the implicit-most-recent fallback as a convenience
extension.

## frame format summary

| frame | direction | meaning |
|---|---|---|
| `(<cmd_id>)STRM open <N>\n` | sender→receiver | stream open |
| `(<cmd_id>)STRM <len>\n<data>` | sender→receiver | data chunk |
| `(<cmd_id>)STRM close\n` | sender→receiver | normal end |
| `(<cmd_id>)!TERM! <reason>\n` | receiver→sender | stop stream |
| `DISCONNECT <reason>\n` | peer-direct | session teardown notice |

## motivation [ original ]

cube logs `SIZE-reply to unknown route id [N]` when target session closed
before sender finished emitting. sender keeps emitting chunks into a drop
path → web zenka blocked → v7 heartbeat timeout → SIGTERM + restart.

**How to apply:** next time orphan-route log spam / web-SIGTERM pattern
recurs, this is the fix path.

## !TERM! reason string rules

- reason is **local context only** — logged at the receiving hop, never forwarded
- on propagation upstream, emit `(<src_cmd_id>)!TERM!\n` with no reason
- this closes the side-channel : verbatim forwarding would allow arbitrary
  data to travel silently through the route chain bypassing access control
- invalid !TERM! [ no cmd_id, no active stream ] : log and drop, no reply
  [ !TERM! is fire-and-forget ; FALSE replies would mix command and
  backchannel protocol layers ]

## propagation status [ 2026-04-20 ]

current implementation handles **one hop only** : sets
`stream_cancelled{src_cmd_id}` on the immediate source session.
multi-hop propagation falls out naturally from pass 3 : each intermediate
relay that receives a chunk on an orphaned route triggers !TERM! back one
hop ; the repeated trigger re-sets the cancel flag at each relay in turn,
no explicit recursive forwarding needed.

## pass-plan

1. **pass 1** [ done ] — base.cmd.cancel-stream + sticky cancel gate
   + base.stream.{open,push,close,gate,emit} wrapper API
   + mod-test.cmd.strm-{start,stop} + handler.strm-tick for e2e testing
2. **pass 2** [ done ] — wire `(<cmd_id>)!TERM!\n` in base.handler.command
   receiver side; propagate through cube route translation; set sticky
   cancel flag at source
3. **pass 3** [ done ] — orphan-route detection in unknown-route handler:
   set `stream_cancelled{$cmd_id}` on sender session for both complete and
   incomplete payload cases; logged at level 1 with cmd/route_id
   session-close proactive teardown: deferred (not yet implemented)

## known open question

`base.cmd.*` vs `cube.cmd.*` namespace — leaning `base.cmd.cancel-stream`
so any zenka with streams can implement it consistently.

#,,.,,...,,,,,..,,...,,,,,...,,..,.,.,,.,,,,,,..,,...,...,..,,,.,,,.,,,.,,..,,
#CVV4Z2BBUPSJJT6UG6D6NLJHSPENKN4C2FUW2P6ONMZ7RJWMV54Y37RDUTRSDP7HLJNY5HYANFF3I
#\\\|ENFRK5XJP2DOXXVD6HPGDUD6N2YQ4TUYBV5NU5SHDLRPPLXXPIS \ / AMOS7 \ YOURUM ::
#\[7]NW4GGAKZSMMR2XFIBQKWMZNMPZMVBDFSWDGUP6BVA637OISA6CBQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
