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

**Side-note — implicit lookup option:** cube could offer a convenience
fallback: if only one stream is active for the session, or always for
the most recent one, `!TERM!` with no cmd_id [ bare `!TERM! <reason>\n` ]
could resolve implicitly. Useful for simple single-stream clients, but
fragile with concurrent streams. Defer until there is a concrete need.

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

## pass-plan

1. **pass 1** [ done ] — base.cmd.cancel-stream + sticky cancel gate
   + base.stream.{open,push,close,gate,emit} wrapper API
   + mod-test.cmd.strm-{start,stop} + handler.strm-tick for e2e testing
2. **pass 2** — wire `(<cmd_id>)!TERM!\n` in base.handler.command receiver
   side; propagate through cube route translation; set sticky cancel flag
   at source
3. **pass 3** — cube-side trigger: on orphan-route detection, emit !TERM!
   back to source; on session close, proactively terminate each in-flight
   route

## known open question

`base.cmd.*` vs `cube.cmd.*` namespace — leaning `base.cmd.cancel-stream`
so any zenka with streams can implement it consistently.

#,,,.,,,,,,,.,,..,.,,,..,,.,,,,,.,,..,...,,.,,..,,...,...,...,...,,,.,..,,,.,,
#F5NVKM6FDGDVZ7GBICJVVTOBVAEN5H4Y3B6C3UZFS25CE6ZSMRAJH3UMFAXVQYYLKS262QAB7AGTS
#\\\|SRLNX6SZJ3K5JK4RKSMBHUJG4V6OTFHAQCKPBRJH3YLLROSHBWD \ / AMOS7 \ YOURUM ::
#\[7]UHXFMXZZOU74FKC4YRD6PPCE3KAIIY5YFBJZ2HPSB7ZBT7SV2OBQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
