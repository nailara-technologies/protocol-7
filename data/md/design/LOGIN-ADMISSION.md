# login admission : web tokens, fair queue, address knowledge

status : design, agreed with the owner 2026-10-23 -- not built yet.
order of work at the end.

## why

the web ui logs in with a pre-shared token [ `web.auth-issue <user>` ]. its
generation is sound -- 32 bytes of os entropy in the input
[ `plugin.web.auth.create_session` ] -- but the token itself is an AMOS
checksum : 7 base32 characters, 2^35 values. one guess per request makes
that reachable at high request rates, and the login has no limit at all.

goals, as the owner set them :

- scanning must become pointless, not just slow
- **no denial of service exposure** : no shared budget a stranger can use
  up. a design that lets an attacker delay the owner's login by queueing in
  front of it is ruled out, bounded or not
- a source with 500 requests must not keep a source with one request from
  being checked next
- controlling a whole address range must add little acceleration
- no per-visitor queries to third parties [ privacy ]

## 0 : no token without tls

today `/auth/login` and `/jobs.json` answer over plain http too [ 401,
no redirect ] : a token sent there is checked, and readable on the path.

- httpd refuses `POST /auth/login` and every token-carrying request
  [ bearer header, `p7_session` cookie ] on a non-tls socket, except real
  loopback peers [ the existing `auth.exempt-loopback` rule : socket peer
  only, never X-Forwarded-For ]
- answer : `403` with a short body naming https ; a `GET` of the ui page
  may get a `301` to https instead

## 1 : BMW-L13 tokens

`create_session` takes `chk-sum.bmw.L13-str` instead of `chk-sum.amos` :
13 characters, 2^65 values. a million guesses per second would need
~580 000 years per hit on average -- the scan math is hopeless before any
limit applies.

- existing tokens stay valid : the store keeps only the hash of a token,
  and the login hashes whatever it is given, any length
- machine tokens [ jobsite push, long ttl ] keep working ; re-mint them at
  leisure

## 2 : per source limit

a source is an ipv4 address, or the ipv6 /64 [ one host easily switches
addresses inside its /64 ].

- the first few failures are free [ 5 ] ; then the source waits, doubling
  per failure [ 1 s, 2 s, 4 s .. capped at 1 h ]
- during its wait a source gets an immediate `429` with `Retry-After` --
  no held connection, no check
- a success resets the source
- this limit only ever slows its own source down : it is no lever on
  anyone else

## 3 : the fair, prioritized queue

every login request is held [ deferred reply ] until the queue admits it
to the check. nobody is refused for someone else's traffic ; the queue only
decides the **order**.

**per source** : each source has its own short queue [ at most 5 waiting
requests ] ; beyond that only that source gets `429`. a source with 500
requests holds no more than 5 connections.

**taking turns** : the scheduler takes one request per group per turn --
never several from the same one. a single request from a fresh source is
in the next turn, however much another source has queued.

**priority between groups** :

1. groups with a recent successful login [ known sources, e.g. 30 days ]
2. then fewest failures [ weighted, decaying -- see below ]
3. on a tie : who waited longest

a scanning group sinks behind every group that has not failed. the owner,
from a known network or with a session cookie, never meets the queue's
tail.

**check rate** : the checks overall are paced [ e.g. 20 per second ]. the
rate decides how fast the queue is worked through, never who waits -- it
replaces no priority.

### address distance

groups are levels of shared prefix, the natural distance between two
addresses :

| ipv6 | ipv4 | above both |
|------|------|------------|
| /64 -> /48 -> /32 | address -> /24 -> /16 | the AS [ section 4 ] |

- the scheduler takes turns level by level : first among the top groups,
  then among the subnets of the chosen one, then among single sources. a
  range of 10 000 addresses gets one turn per round in total -- jumping
  between its addresses gains almost nothing
- a failure counts towards its groups, weighted by distance : strongly for
  its /64 or address, less for /48 or /24, slightly for the AS. the weight
  decays over time [ a half-life of hours, not days ]
- **merging only when conspicuous** : normal traffic is scheduled per
  source. only when failing sources accumulate under one prefix does it
  become one bucket [ heavy-hitter detection ] -- a big provider is not
  penalized in advance for being big
- bystanders behind the same carrier-grade nat or in an attacker's /24
  share its bucket : turns come less often, they are never refused. the
  known-source lane keeps returning users out of it ; first-time logins
  from such a network pay that price

### residual case

a botnet with many fresh addresses : each gets one attempt at the priority
of a stranger, then falls behind after its first failure. with L13 those
single attempts are worthless.

## 4 : geoloc -- what is known about an address

the `geoloc` zenka exists as a skeleton [ "IP based geolocation", local
geonames dumps in `/var/cache/geoloc`, code still a todo ]. it becomes the
one place for address knowledge, kept locally.

- a range table : prefix -> AS [ origin ], a few MB, refreshed as a
  **fixed download** [ e.g. daily ] from a source needing no account
  [ the free iptoasn table, or a RIPE RIS dump ]
- **never a live query per visitor or per prefix** [ whois, rdap, the
  dns-based AS lookups ] : each would tell a third party, and every
  resolver on the way, which networks talk to the server and when. the
  download is the same whoever logs in
- a lookup answers the whole range, so a neighbour of an earlier source is
  known at once -- a scan through a block costs one lookup ; lookups are
  local and instant, no prefetch needed
- its city \ country data follows later the same way. other zenki may use
  it too [ smtpd, nameserv, log enrichment ]
- **propagation between the geoloc zenki** [ owner, 2026-10-23 ] : one
  server fetches the public table, its peers pull it over the zenka
  network -- fast-wired neighbours first [ srv-U -> srv-A ]. modelled on
  nameserv's zone sync [ 4CJ : a serving host, peers, a writer grant keyed
  by host-root id ]. one outside download instead of one per server
  [ tells the source less ], and every server decides on the same table
  version [ two name servers must not answer one resolver differently ].
  a table travels with its BMW checksum and the source's version ; a peer
  keeps its previous table when a new one does not match
- **every server may fetch, phase offset** [ owner ] : each has its own
  slot in the interval [ from its host-root id, a checksum modulo the
  interval, plus jitter ]. at its slot a server first asks its peers for a
  newer version and takes that ; only when none has one does it fetch,
  then passes it on. normally one download per interval [ whoever comes
  first ] ; when one server's path to the source is blocked, the next slot
  fetches instead -- a lazy fallback without failover logic. the newest
  source version wins, so all servers converge on one
- **a new version is announced at once** [ owner ] : whoever got it
  notifies its peers [ version, source, BMW checksum -- not the table ] ;
  a peer without it pulls right away and announces it to its own peers, so
  the table spreads in minutes [ like a dns primary's NOTIFY ]. the slot
  stays the fallback for an offline server or a lost notice. a notice is
  only a cue : the peer checks what it pulls, a forged notice at most
  triggers a pull that finds nothing new
- a second table : prefix -> country [ \ continent ], from the RIRs'
  delegated statistics files [ public, no account, ranges per country ] --
  needed by the geo-aware name service [ section 7 ]

## 5 : who does what

| zenka | part |
|-------|------|
| web [ `plugin.web.auth` ] | the admission : queue, priorities, failure records with decay, source groups. it mints, checks and revokes tokens already -- the authority for login |
| httpd \ httpsd | hold a login request, ask web when it may be checked, answer `429` \ `403` themselves. one decision point : http and https cannot diverge, an httpsd restart changes nothing |
| geoloc | the range table and lookups [ section 4 ] ; web asks it lazily for a new source's group |
| forensics | reads the failure records in its nightly sweep -- a recurring scanning network becomes a finding \ rule proposal. not in the request path |

state that must survive a restart [ failure weights, known sources ] lives
with web, written to the shared web-auth store [ setgid group `httpd`,
see `base.file.make_path` \ `base.file.open` of 2026-10-23 ].

## 6 : later, optional -- a proof of work

when the global failure rate rises, `/auth/login` asks for a small proof
before checking : a hash with a given number of leading zero bits, computed
by the login page. the difficulty follows the attack ; every guess costs
the attacker cpu, the owner pays the same once [ seconds at worst ] and is
never turned away. the server checks one hash per answer. the global
counter only sets the difficulty -- it blocks nobody, so it is no lever
either.

## 7 : the second geoloc user -- nameserv by region

planned by the owner : nameserv answers with the address of the nearest
server -- the us server for north america, the german one for europe, and
so on. the same local lookup, another answer : the region instead of the
AS.

- a query reaches nameserv from the visitor's **resolver**, not from the
  visitor. some resolvers pass a part of the client address along
  [ EDNS Client Subnet ], some deliberately do not [ privacy ]. so : use
  the ecs subnet when present, else the resolver's address -- a resolver
  usually sits close to its users, the region split holds
- answers carry a short ttl and, with ecs, the scope of the subnet they
  were decided for [ so a resolver caches them only for that subnet ]
- a fallback server for unknown \ unlisted regions ; the region -> server
  map is host config of the zone, not code

### beyond region : context-dependent selection [ owner, 2026-10-23 ]

region is one input among several. the answer is chosen from the servers
able to serve the name, ordered by a policy over :

| input | from |
|-------|------|
| region \ distance | geoloc [ the resolver or ecs subnet ] |
| health | is the service up -- v7-zenki's own heartbeats, httpd answering ; a down server is never answered |
| load | cpu, memory, connections, the zenki's queues [ system zenka, v7-zenki ] -- a busy server is weighted down, not dropped |
| capacity | a per-server weight in host config [ a 2 GB server gets less than a 23 GB one ] |
| state | maintenance \ draining [ a server being retired or updated drains first ] |
| service | which server offers what at all [ not every name is on every host ] |

- all of it comes from our own servers over the zenka network : no
  third party, no privacy question -- unlike the address tables
- dns caching bounds how fast a change takes effect : the ttl is the
  reaction time. health and drain need short ttls ; region alone could
  live with longer ones
- several servers may be returned, ordered -- clients try the next one
  when the first fails, which smooths over the ttl gap
- the policy is per zone \ name, in host config ; the inputs are collected
  continuously, never fetched per query
- this only applies once the delegation moves to our name servers [ the
  registrar answers the main zones today -- see todo 5W7 ]

## order of work

1. no token without tls [ section 0 ]
2. BMW-L13 tokens [ one line ]
3. per source limit [ section 2 ]
4. the queue with prefix levels [ section 3 ] -- no external data needed
5. geoloc range table + the AS level [ section 4 ]
6. forensics reading the failure records
7. proof of work, if wanted [ section 6 ]
8. geoloc country table + nameserv by region [ section 7 ], after the
   delegation switch

## open

- the queue's numbers [ 5 per source, 20 checks \ s, the decay half-life,
  the known-source window ] are first guesses ; measure on the live hosts
- a login by `user + token` would let the target be the user [ the check
  then compares against that user's sessions only ] -- not decided
- the AS table source and its licence, checked before the first download

#,,,,,,..,.,,,.,,,,,.,...,,.,,,..,...,,,,,,.,,..,,...,..,,...,...,.,,,,.,,..,,
#226MRKXPP5YV5PX6XNJ4KJSLHFAOUC76V4TSOWXEC3WC6YVHZYYAFRUQHANB3NEJKS55GKTVATIRK
#\\\|HJOWU3YRD4KDBBO4L2XPT7Z26GPRKA5YG2IQJ3NFPBMJJXE5GL6 \ / AMOS7 \ YOURUM ::
#\[7]XC6IEV522QBWPIIVZ5U3WCC5VQWEWYMUDROFKUQT74SDV2IETECA 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
