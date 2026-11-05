# route collapse and liveness

status : design [ 2026-11-05 ] ; the liveness probe is the next build step, the rest is the model it
fits into. related : `base.handler.command` [ the `# [LLL] set up reply timeout` placeholder at the
deferred reply ], `v7-zenki` heartbeats.

## 1. the default : however long it takes

a routed command has no time limit. when a hop fails, the route collapses and the caller is notified --
that is the normal end of a request that can not complete. a default or global reply timeout would end
slow but healthy work too, change the resilience of the network and make long tasks uncompletable : it
does not exist.

## 2. how a route collapses

| cause | who decides | status |
|---|---|---|
| a hop fails \ disconnects | the transport | exists |
| a target stuck but still connected | cube : liveness probe [ section 3 ] | next |
| a timeout on one hop | the caller or the target zone [ section 4 ] | opt-in, at the placeholder |
| max hops on the route exceeded | the routing layer | later |
| the request is no longer completable | the zone that knows it | later |

every collapse reaches the caller the same way : a `false` reply naming the cause and the hop.

## 3. liveness probe [ stuck targets ]

seen on pri 2026-11-05 : an nshell session lost its terminal, spun in its stdin watcher for 12 hours
and stayed connected. user sessions have no heartbeat, so `taeki.name` routed to it hung with no end.

- while a session has at least one forwarded command waiting for its reply, cube sends it `heart`
  every `cube.cfg.liveness.interval` seconds [ starting value 30 ].
- `heart` is answered by the event loop, not by the busy command : a session working on a long task
  still answers. only a session whose event loop no longer runs misses it.
- after `cube.cfg.liveness.misses` missed probes in a row [ starting value 3 ] cube closes the session
  and logs why ; its open routes collapse the normal way.
- sessions with nothing open are never probed : no traffic in the idle case.
- sessions v7-zenki already heartbeats need no second probe.

## 4. opt-in timeouts : per hop, never per route

a timeout sits on ONE hop and only exists where it is requested or assigned :

- **by the caller** : the calling zenka knows the range its request needs and adds a safe margin.
- **by the target zone** : the zenka around the activity, where it knows it signals task failure
  without false positives, or where it is coordinated with other zenki and network cycles.

- **by a map** : a zenka can keep a map for its outgoing commands [ command pattern -> hop timeout ],
  so the range is configured once, not repeated at every call site. cubes and filter zenki can keep
  the same kind of map and ENFORCE it, where a network boundary warrants it [ a remote zone, an
  untrusted link ] -- the timeout then belongs to that boundary hop.

carried with the request [ call args ] or set by the handler on its deferred reply. a reply arriving
after its hop timed out is dropped and logged at level 2.

## 5. later

- **max hops** : a route longer than its allowed hop count collapses before it is forwarded further.
- **no longer completable** : a zone that learns the request can not finish any more [ its input gone,
  its task cancelled upstream ] collapses it at once instead of waiting.

#,,,,,,..,,,.,.,.,,..,.,,,.,.,.,.,,..,..,,,,,,..,,...,...,..,,,.,,,..,.,,,,,.,
#FO4TFF6TFRWT4CTBT6ASTIPH7CI2WE75IYFTAIMY4XUZ45ZDUM6NDTR5ROXFIFXVPFGLTGOORYP24
#\\\|J7NUW6TTFURC7LYJPBAMK4LYAP7Z5NTSDGTCOREDXE46ESVEIS7 \ / AMOS7 \ YOURUM ::
#\[7]XMDZ2RTAAHXLUKOEZ7ULSOQPVD75HORVC5WBLK2BJHOC4MV7YECA 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
