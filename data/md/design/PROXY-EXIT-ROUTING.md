# proxy exit routing : which address a site sees

draft 2026-10-21 [ owner + claude ]. design only -- no code, no config.
builds on todo HS4 [ proxy -> external link tunnel, incl. the 2026-10-21
'blocked ranges' append ], 3W5 [ jobsite fetch nodes, permanent links on
host-edit records ] and B2K [ bidirectional STRM channel ], on
[ HOST-SETUP.md ] [ host records ], [ AUTH-LINK-BINDING.md ] [ named
links ], [ CREDENTIAL-FABRIC-INTEGRATION-AND-UI.md ] [ proxy <->
transport wiring ] and [ PROTOCOL7_TRANSPORT_HIERARCHY.md ] [ UDT ].

## situation [ owner, 2026-10-21 ]

- a few sites block or misbehave from the contabo provider ranges
  [ pri, yourum ] : stepstone.de answers both with a WAF block [ 3W5 ],
  some video streaming misbehaves too
- so the hysteria exit on pri [ unlimited traffic ] sits idle and atom
  [ 1 TB \ month ] still carries the local proxy
- delta [ another provider, us, 1 TB ] works ; two more nodes at delta's
  provider are planned [ dallas, us east coast ] -> 3 TB for alternate
  routing. the same nodes are 3W5's fetch nodes : one node set, two uses

the problem is not transport quality. pri is reachable and fast ; the
SITE refuses the address traffic leaves from. that is a second dimension
the transport layer does not have today.

## what exists today [ read 2026-10-21, base 07239e1f7 ]

- **proxy** [ `cfg/zenki/proxy/zenka.v7` ] : 127.0.0.1:8118,
  `proxy.cfg.transport = direct`. `modules.load` does NOT contain
  `transport` -- transport is its own zenka [ `cfg/zenki/transport/` ],
  so `proxy.transport.select` finds no local `transport.select` and
  replies undef. every request then leaves through
  `proxy.outbound.connect_or_use`'s direct fallback [ blocking
  `IO::Socket::IP`, 7 s ]. the context's `transport` block is a fixed
  `{ type direct, quality 1.0 }` [ `proxy.handler.connection` ].
  [ the credential-fabric doc says the proxy 'already calls
  transport.select' -- the call exists, it never reaches the transport
  zenka. ]
- **CONNECT** [ `template-selector.yaml` : `request.method CONNECT ->
  tunnel.passthrough` ] : the proxy pumps bytes, it never sees a status
  code [ HS4 ].
- **transport registry** keys : `quality{type}{dest}`,
  `demoted{dest}{type}`, `active{dest}` -- `dest` is the requested
  domain. the profile entry's `endpoint` [ e.g. `atom:443` ] is where a
  transport goes, but it is not part of any key : a hysteria entry to
  atom and one to pri would share one quality \ demotion slot per site.
- **profiles** [ `data/yaml/transport/profiles/` ] : `default.yaml`
  [ direct-tcp ] and `atom.yaml` [ `destination: atom.host` -- a profile
  for REACHING atom, matched by destination, not one for leaving through
  it ]. `min_quality` knows `loss_max` only ; no cost \ budget weight.
- **quic-hysteria handle** returns `proxy_url` \ `proxy_host` \
  `proxy_port` [ default 1040 ] but no `socket` -> `connect_or_use` would
  still fall back to direct even if selection ran. `transport.handle.
  socks5` [ the shared socks5 client ] exists and nothing calls it.
- **udt-tunnel** : a stub until `UDT::Simple` is available.
- **host records** [ `host-edit.record.field_names`, the single
  authority ] : `name addresses link_user ssh ssh_port transports owner
  owner_key roles`. nothing about provider, location or traffic.
- **external links** [ `external.link.open` ] : encrypted named links
  [ auth-keypair v2 + pin, link-upgrade ], reused while alive ;
  reconnect with backoff exists only for orbital
  [ `external.orbital.schedule_retry` ].
- **visit log** [ `proxy.log.visit` ] : per domain -- count, last visit,
  template, a stub extraction quality. no exit, no outcome.
- **site-yaml** fetches see content and status [ `site-yaml.async_fetch.
  reply` : the real http status, else 599 ] but its backoff is ONE global
  delay [ `site-yaml.fetch.backoff` ] -- a WAF refusal slows every site.

## 1. the exit dimension

an **exit** is the host whose address a target sees. a **path** is how
traffic reaches that exit [ external link + STRM, hysteria, later UDT ].
the two are independent :

| dimension | question | keyed by | learned from |
|---|---|---|---|
| path quality | how well do we reach the exit | exit x path type | loss, rtt, goodput, failures [ the existing quality.* ] |
| exit verdict | does the site accept the exit's address | site group x range class | block signals [ section 3 ] |
| exit capacity | can the exit still carry it | exit | traffic budget + usage [ section 2 ] |

selection order : exits the site allows [ verdict ] -> in the site's
region [ region binding ] -> weighted by remaining budget [ capacity ]
-> the sticky choice for the site [ section 4 ] -> the best path to that
exit [ quality, today's demote \ promote unchanged in meaning, re-keyed
from `{type}{dest}` to `{exit}{type}` ].

a path failure demotes a PATH, never the exit's verdict for a site ; a
site refusal marks the VERDICT, never the path. today both would land in
`demoted{dest}{type}`.

`local` [ the desktop's own address ] is an exit too, with its own range
class -- whether it is ever allowed by default is an owner decision
[ open questions ].

## 2. exit attributes from host-edit records

an exit is a host record with the role `exit` [ `roles` already exists,
free tags ]. three new fields, owner statements like the rest of the
record [ nothing a pin holds ] :

| field | meaning | example [ from the owner's statements ] |
|---|---|---|
| `range_class` | provider \ address range family a site may judge as one | pri, yourum : `contabo` ; delta + us nodes : delta's provider [ name to fill in ] |
| `region` | where the egress address geolocates [ country, optional sub-region ] | delta : us ; dallas : us ; us east : us |
| `traffic_budget` | monthly allowance + reset day, or `unlimited` | pri : unlimited ; atom : 1 TB ; delta, each us node : 1 TB |

- `host-edit.record.field_names` gains them [ value_set re-filters
  against that list, so nothing else needs to learn them ] ;
  `field_options` : `range_class` + `region` line, `traffic_budget` line
- **detection offers, the owner confirms** [ Q7O principle ] : the
  range class has candidates with sources -- the asn \ whois of the
  record's addresses, another record with the same asn -- shown with
  their reason ; never applied silently. a class is a label the owner
  owns : two asns can be one class if sites treat them as one
- atom's provider and location are not stated anywhere in the repo --
  to fill in [ open questions ]
- the record stays what a host IS ; usage counters, verdicts and sticky
  state are live data of the routing side, never written into records

## 3. block knowledge : site group x range class

### the table

one entry per `( site group, range class )` :

- `verdict` : `unknown` | `suspect` | `blocked` | `allowed` | `mixed`
- `evidence` : the observations that led there [ time, exit, signal,
  source ] -- an owner can read why
- `source` of the verdict : `owner` | `content` | `connection`
- `expires` : automatic verdicts expire and are re-verified ; owner
  marks never expire

consequences, as stated in HS4 :

- one refusal seen from pri marks the pair `( stepstone.de, contabo )`
  -> yourum is excluded too, without ever trying it
- a new node of a known class inherits every verdict of that class the
  moment its record names the class [ dallas and us east start with
  delta's ]
- evidence keeps the exit name, the verdict lives on the class. when
  exits of ONE class disagree [ one blocked, one allowed -- per-address
  reputation instead of a range block ] the verdict becomes `mixed` and
  falls back to per-exit evidence for that pair ; the owner is told,
  the class stays a class

the first entry is known now : `( stepstone.de, contabo ) -> blocked`,
source owner [ 3W5, 2026-10-21 : pri and yourum refused, atom and delta
fetch fine ].

the same table serves two consumers : the proxy [ the browser's
traffic ] and site-yaml fetch placement [ which fetch node takes a
site -- 3W5's 'per-site fetch-host list' becomes a query of this table ].

### learning it when CONNECT hides status codes

signals rank by what they can see :

1. **owner marks** [ strongest ] : `blocked` \ `allowed` for a site
   group and a class, or for the exit currently used by a site
   ['this video does not play over pri'] -> the class is looked up from
   the record. a command plus a menu entry later ; never overridden by
   automatic evidence, only shown next to it when they disagree
2. **content-seeing fetches** : site-yaml runs on a known node, so every
   fetch has a known range class. a 403 \ 429 with a WAF or captcha page,
   a redirect to a challenge, an empty body where the site normally
   answers -> `blocked` for that pair. today's global backoff gets a
   per-site-group side : a refusal is a verdict, not a reason to slow
   other sites
3. **verification probe** : a `suspect` pair gets ONE fetch of the site's
   front page FROM an exit of that class [ the fetch node \ exit runs it,
   so it sees the status ] -- turns connection-level suspicion into a
   content-level verdict. rate-limited per site, never a scan
4. **connection signals** [ weakest, CONNECT ] : reset right after the
   tls client hello, tls alerts, a connect timeout only via one class
   while others connect, a tunnel that closes after a few kilobytes on a
   site whose sessions are normally long. these only ever set `suspect`
   -- a WAF that answers with a 403 page inside tls looks like a normal
   short session from outside
5. **plain http \ terminating templates** : where a template terminates
   in the proxy [ non-CONNECT ], status and body are visible -> treated
   like (2)

HS4's trouble signals for exit stickiness [ 401 \ 403 \ 429, login
redirects, captcha pages, rejected session cookies ] feed the same table
where they are visible ; the visit log gains the exit and the outcome per
visit so the evidence has a home.

## 4. default routing

### budget-weighted distribution, sticky per site

for a site group without a sticky exit :

1. candidates = exits with role `exit` whose class verdict for the group
   is not `blocked` [ `mixed` : per-exit evidence decides ], whose path
   is up [ nodes \ link supervisor, 3W5 ] and whose budget is not
   exhausted
2. region filter [ below ]
3. pick by weight = remaining budget for the period, spread over the
   days left [ an allowance per day, so the first week does not spend
   the month ]. a reserve [ e.g. the last 10 % -- example value, to set ]
   leaves an exit for already sticky sites only
4. the choice is sticky : the group keeps its exit while in use, plus an
   idle expiry [ value open ]. it moves only on a `blocked` verdict, the
   exit going down, or its budget reaching the reserve -- each move is
   logged, since it can break an ip-bound session

**unlimited exits** [ pri ] : a weight cannot come from a remaining
budget. two readings, owner decision :
- pri takes every group it is allowed for, the finite exits carry only
  what contabo cannot -- saves the 3 TB for the sites that need them
- pri gets a configured share in the distribution -- spreads load and
  keeps the other exits warm
recommendation : the first, since the finite budgets are the scarce
part and the blocked sites are the reason they exist.

**usage** : the exit counts the bytes it carries per period ; the
provider counts everything on the host [ 3W5 fetches, ssh, upgrades ].
the budget field is the provider's allowance, the remaining value should
come from the host's interface counters where readable, the tunnel
counters otherwise [ open questions ].

### a site = its hostname group

a page and its cdn \ media hosts must leave through the same exit, or
the session breaks [ tokens bound to the address, geo checks per
request ]. groups, in rising effort :

- the registrable domain [ `www.` and `img.` of one site ] -- the base
- declared groups in the domain yaml [ `data/yaml/web-proxy/domains/
  <domain>.yaml`, already loaded by `proxy.selector.load` ] : a video
  site lists its media and cdn domains
- learned candidates : hosts a client first opens within seconds after a
  page host -> OFFERED as group members, the owner confirms
  [ managed abstraction ; never applied silently -- shared cdns would
  otherwise merge unrelated sites ]

a shared cdn host [ used by many sites ] rides the exit of the group
that opened it last within a short window ; outside any window it is its
own group.

### streaming

- one exit per stream : every connection of a playing stream rides the
  group's sticky exit -- never spread across exits [ different source
  addresses mid-stream look like a session hijack ]
- heavy groups weigh heavier : a group whose measured bytes are large
  [ video ] goes to the allowed exit with the most remaining allowance,
  light groups follow the weighted pick
- more capacity for one stream = **path parallelism** : more paths to the
  SAME exit [ two links, later tcp + udt side by side, HS4 'PATH' ] --
  invisible to the site. exit spreading stays for anonymous fetches only

### region binding

content region and licensing follow the egress address. a group may
carry a `region` requirement [ owner mark or domain yaml ] -> only exits
in that region are candidates, even when a farther one is allowed and
has more budget. no exit in the region and allowed -> the request fails
with a clear message naming the missing region, rather than silently
using another one.

## 5. transport under each exit

the exit dimension sits ABOVE the path ; paths change without touching
verdicts or stickiness :

- **now, interim** : hysteria [ atom + pri, hand-written systemd ] stays
  until the tunnel works. as exits each needs its own local socks port
  [ one hysteria client per exit ], the quic-hysteria handle must return
  a connected socket through `transport.handle.socks5`, and the registry
  must key by exit, not by type. delta has no hysteria today -- an
  `ssh -D` dynamic forward from its host record would give a socks5 exit
  at once [ ssh IS the transport, HOST-SETUP.md ] ; but 3W5's restricted
  link key [ `permitopen=127.0.0.1:42` ] forbids it, so this needs its
  own key or the owner's ssh -- owner decision
- **target** : HS4's tunnel -- the proxy's transport handle
  `external-link` asks the external zenka for a B2K channel [ two STRM
  streams ] over the named link to the exit [ link name = record name ] ;
  the exit side connects to the target and pumps both ways. exit
  permission, backpressure, lifecycle and the per-session C25519 keys
  as in HS4. permanent links come from 3W5's link supervisor [ one link
  per record with the role, reconnect with backoff ]
- **later** : UDT under the external link [ PROTOCOL7_TRANSPORT_HIERARCHY.md,
  `transport.handle.udt-tunnel` ] -- removes head-of-line blocking
  between tunnels on one link ; nothing above changes

the proxy must reach the transport zenka for any of this : either load
`transport` into the proxy [ one process, the registry beside the
clients ] or route `transport.select` over the cube [ a separate process,
one round trip per new site group -- cheap once sticky ]. decision open.

## 6. staged plan

1. **records** : `range_class`, `region`, `traffic_budget` + role `exit`
   in host-edit ; fill pri, yourum, atom, delta [ owner statements ].
   seed the block table with `( stepstone.de, contabo ) blocked` [ owner ]
2. **wiring** : the proxy reaches transport ; registry keyed by exit ;
   hysteria handle returns a socket via the socks5 client ; per-group
   exit choice from owner marks only [ no learning yet ]. first relief :
   stepstone and the misbehaving video sites through atom \ delta,
   everything else through pri
3. **learning** : visit log with exit + outcome ; site-yaml reports
   status with its node's class ; connection signals -> suspect ;
   verification probe ; owner mark command. site-yaml placement reads
   the same table [ 3W5 ]
4. **capacity** : usage per exit, allowance per day, reserve, weighted
   pick, heavy groups for streaming, region binding
5. **tunnel** : B2K channel + HS4 exit service on the nodes, 3W5 link
   supervisor ; hysteria \ `ssh -D` retired per exit once its tunnel
   carries
6. **new nodes** : dallas, us east -- a record with role `exit` + class
   inherits every verdict ; also fetch nodes for 3W5
7. **UDT** under the link ; path parallelism for streams

each stage works on its own ; stage 2 already moves traffic off atom for
everything contabo is allowed to fetch.

## open questions

- which sites besides stepstone.de -- and which video streaming services
  exactly ; are they range blocks or per-address reputation [ seen from
  both contabo hosts, or from one ]
- which regions a site needs [ e.g. a german site that answers us
  addresses differently ] ; delta fetches stepstone.de from the us fine
  today
- atom : provider, range class, region -- not in the repo
- delta's provider name as the class label
- unlimited pri : take all allowed traffic, or a configured share
- usage source : interface counters on the node vs tunnel counters ;
  reset days per provider
- the reserve level, the sticky idle expiry, verdict expiry and the
  probe rate per site
- `local` as an exit : ever allowed, or excluded by default
- interim delta exit : `ssh -D` with which key
- where the block table lives -- the desktop's proxy, the jobsite hub,
  both [ synced over the links ] ; it records browsing, so it stays with
  the owner's hosts
- proxy <-> transport : co-load or route
- grouping : is a public suffix list available offline for the
  registrable domain, or a small own list first

#,,,.,,,,,,,,,...,,,.,...,,,,,...,.,.,,,,,.,,,..,,...,...,..,,..,,.,,,..,,.,.,
#M7FUWQG2D7NTGSDZVJ53KOUICKPHOW5QCOG6DLJ7RJTAK7EFWXRDEEQHETZLBWCWA5A2IONCTNDJM
#\\\|WBQDPQZQN6A4N3GYBSUNANS4NPMTYC2AEGJD4EXCDSDFYB7LXTK \ / AMOS7 \ YOURUM ::
#\[7]LLMT6ENTTU6KLDCK2ZVNIVXBQ5HDE6TZU7VVPNRLE2NZWAASYCBI 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
