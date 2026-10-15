# 4ZW : nameserv forwarding dns cache [ loopback clients only ]

todo 4ZW in data/yaml/todo/base.yaml. you implement the cache MODE of the
nameserv zenka ; instance wiring [ nameserv[cache] in start set-ups ],
resolv.conf changes and any live deployment are NOT yours.

## what exists today [ read these first ]

- `src/nameserv.answer` : synchronous. parses the query, answers from the
  zones it is authoritative for ; anything else ends at line ~96 :
  `$reply->header->aa(0); $reply->header->rcode('REFUSED');`
- `src/nameserv.handler.query` : udp. `recv` one packet, `nameserv.answer`,
  `send $sock, $reply->data($udp_size), 0, $from_addr` right away.
- `src/nameserv.dns_tcp.handler.read` : tcp [ rfc 7766 ]. framed messages,
  `nameserv.answer`, appends `pack('n', len) . data` to `$conn->{'out'}`,
  then `nameserv.dns_tcp.handler.write( $conn->{'id'} )`. connections live
  in `<nameserv.dns_tcp.conns>` [ keyed by connection id ].
- **async dns precedent - copy its shape** : `src/nameserv.consistency.query`
  [ `Net::DNS::Resolver->new(...)->bgsend`, `event.add_io` on the returned
  socket + `event.add_timer` timeout ], `src/nameserv.consistency.handler.
  answer` [ `bgread` when readable ], `src/nameserv.consistency.handler.
  timeout`. the zenka never blocks on dns.
- `src/nameserv.init_code` : config defaults `<nameserv.cfg.*> //= ...`.

## what to build

the mode is on when `<nameserv.cfg.cache.enabled>` is true [ cfg_bool ;
default `no` ]. off : behaviour exactly as today.

1. **client check** - `src/nameserv.cache.client_allowed` : param a peer
   ip string. TRUE only for 127.0.0.0/8, ::1 and ::ffff:127.x.x.x. this is
   enforced in CODE for every query, never only by bind address or config :
   no open resolver, ever. not allowed -> the existing REFUSED reply.
2. **cache** - `src/nameserv.cache.get` \ `src/nameserv.cache.put`, state in
   `<nameserv.cache.entries>`, key = lc qname + qtype + qclass.
   - get : a hit returns a COPY of the stored reply with the query's id, rd
     copied, and every rr ttl decremented by the elapsed time [ never below
     0 ] ; an expired entry is removed and is a miss.
   - put : expiry = now + the lowest ttl of answer + authority rrs, capped
     at `<nameserv.cfg.cache.max_ttl>` [ default 86400 ]. negative answers
     [ NXDOMAIN, or NOERROR with an empty answer section ] use the SOA
     minimum \ SOA ttl from the authority section, the lower one, capped
     at `<nameserv.cfg.cache.max_negative_ttl>` [ default 900 ] ; no SOA :
     not cached. never cached : SERVFAIL, REFUSED, truncated [ tc ] replies,
     ttl 0.
   - size limit `<nameserv.cfg.cache.max_entries>` [ default 7777 ] : past
     it, evict the entries that expire first.
3. **forwarding** - `src/nameserv.cache.forward` : param the parsed query
   packet and a deliver code ref [ called once with the reply packet ].
   - upstreams : `<nameserv.cfg.cache.upstream>` [ space separated ips ] ;
     unset -> the `nameserver` lines of /etc/resolv.conf WITHOUT loopback
     addresses [ the cache must never ask itself ]. read once, at init or
     first use.
   - rd = 1 to the upstream. one Net::DNS::Resolver bgsend per upstream try,
     io watcher + timeout timer [ `<nameserv.cfg.cache.upstream_timeout>`,
     default 3 s ]. timeout or socket error -> the next upstream ; all
     failed -> deliver a SERVFAIL reply [ id of the client query ].
   - a truncated upstream reply : retry the same upstream over tcp
     [ `usevc(1)` resolver, bgsend works for tcp too ] before delivering.
   - in-flight coalescing : a second query for the same key while one is
     pending waits for that one [ list of deliver callbacks ], no second
     upstream query.
   - on a good reply : `nameserv.cache.put`, then deliver to every waiter
     with ITS query id. cancel the io watcher and timer when done.
   - handlers : `src/nameserv.cache.handler.answer` [ io ],
     `src/nameserv.cache.handler.timeout` [ timer ].
4. **integration** [ the only edits to existing files ] :
   - `src/nameserv.handler.query` and `src/nameserv.dns_tcp.handler.read` :
     when the authoritative answer is REFUSED **and** the mode is on **and**
     the query has rd set **and** `nameserv.cache.client_allowed( <peer ip>
     )` : cache hit -> reply at once ; miss -> `nameserv.cache.forward`
     with a deliver callback. udp : the callback sends to the same socket
     and `$from_addr` [ keep both in the closure ], with the same udp size
     logic as today. tcp : the callback appends the framed reply to the
     connection's `out` ONLY IF that connection still exists [ look it up
     by id, it may have closed ], then calls the write handler. rfc 7766
     allows out-of-order replies over tcp.
   - `src/nameserv.init_code` : defaults for every new `nameserv.cfg.cache.*`
     key, `<nameserv.cache.entries> //= {}`. re-init safe [ `$reinit` is
     its first argument -- never reset the cache on reinit ].
   - `cfg/zenki/nameserv/zenka.v7` : commented example lines for the new
     keys, next to the existing tcp ones. do not enable anything.
5. **status** - add cache counters [ hits, misses, forwarded, servfail,
   entries ] to `<nameserv.stats>` ; if `src/nameserv.cmd.status` exists,
   show them there in its existing style.

## rules

- module files : the header `## [:< ##`, `# name  = ...`, `# descr = ...` ;
  NO `sub { }` wrapper -- the file IS the sub ; args via `@ARG` \ `shift`.
  call other modules as `<[module.name]>->( ... )`, data as
  `<nameserv.cfg.x>` [ see any existing nameserv file ].
- **event api** : `<[event.add_io]>->( { fd, poll => 'r', handler, data,
  desc } )`, `<[event.add_timer]>->( { after, handler, data, desc } )` --
  `event.*`, never `base.event.*`. a handler gets the EVENT : data via
  `$event->w->data`, fd via `$event->w->fd`. cancel with `->cancel`.
- never a blocking read : only `bgread` inside the io handler.
- comments lowercase, annotations in `[ ]` never `( )`, `##  ...  ##` style
  as in the surrounding files. no copyright \ author \ license headers.
- minimum perl 5.32 [ `use v5.32.0` ] : chained comparisons ok, nothing
  newer.
- module files end with a 4-line AMOS7 signature footer starting with
  `#,,` -- IGNORE these lines completely, never edit or investigate them ;
  new files get them later from the signing run, do not add any.
- syntax check every touched src file with `bin/format-code -c <files>`
  [ NOT `perl -c` -- it gives false errors on this code ].

## test [ the acceptance criterion ]

`bin/test-scripts/test-nameserv-cache.pl`, modelled on
`bin/test-scripts/test-nameserv-dns-tcp.pl` [ compiles the real src
modules, stubs event.add_io \ event.add_timer \ base.logs, real sockets on
127.0.0.1 only, NEVER port 53, no zenka started ]. a fake upstream = a udp
[ + tcp for the truncation case ] socket on 127.0.0.1 at a random port,
answered by the test itself ; the test drives the io \ timer handlers.
must cover at least :

- client_allowed : 127.0.0.1, 127.5.5.5, ::1, ::ffff:127.0.0.1 TRUE ;
  192.168.1.1, ::ffff:10.0.0.1, 2001:db8::1, '' FALSE
- a non-loopback client with rd : REFUSED, nothing forwarded
- miss -> forwarded with rd=1 -> reply delivered with the client's id ->
  second query is a hit, no upstream traffic, ttl decremented
- expiry : an entry past its ttl is a miss again
- negative cache : NXDOMAIN with SOA cached [ capped at max_negative_ttl ],
  without SOA not cached
- SERVFAIL \ tc are not cached ; tc retries over tcp
- first upstream silent -> timeout -> second upstream answers ;
  all silent -> SERVFAIL to the client
- two identical queries in flight -> ONE upstream query, both delivered
  with their own ids
- max_entries eviction
- mode off : REFUSED exactly as before [ no forwarding ]
- authoritative zones still answered from the zone, never forwarded
- a tcp connection closed before the upstream reply : no error, nothing
  appended

run it and `bin/format-code -c` on every file ; both must pass.

## out of scope

- no live network beyond 127.0.0.1 in tests, no port 53, never start or
  restart a zenka, no `p7c` commands, no git commits, no signing.
- no start set-up \ v7-zenki changes, no resolv.conf writing, no
  systemd-resolved handling, no full recursion, no dnssec validation.
- do not touch any file not named above.

## report

the list of new \ changed files, the test output [ last lines ], the
format-code result, and anything you could not do or had to decide
yourself.

#,,..,,..,..,,,,.,..,,..,,..,,..,,,,.,,,.,,.,,..,,...,...,...,,.,,..,,,,,,.,,,
#2FOKV2DTQLJOTVL466ILG66JVMGCF3QTPTUR7CEPV2CUC3IT6DM6BYQJMPEF65XJUD6X7XIMIJCXQ
#\\\|UECETAJ4QAEIJZM6ZUJI7JI2IXRPNAOKZTZAIAAIUTAEXM7NAU2 \ / AMOS7 \ YOURUM ::
#\[7]YYHHZA2SBYMBWL7XB65BWSJQYX75XXDGB62XC2UOQYCJ4QEGAQAQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
