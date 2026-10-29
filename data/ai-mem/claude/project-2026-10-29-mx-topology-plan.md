---
name: project-2026-10-29-mx-topology-plan
description: 2026-10-29 owner plan : today the only MX is postfix on atom ; once the smtpd zenka carries the full configuration -> MX yourum primary, pri secondary, delta third [ US, deprioritized ] ; later two more US nodes beside delta [ NY \ Dallas \ LA ]
metadata:
  type: project
---

**MX topology plan [ owner, 2026-10-29 ]**

- **now** : one MX, postfix on atom [ srv-F ]
- **trigger** : the smtpd zenka takes over with full configuration
- **then** : yourum = primary [ calmer host, fastest cpu worker, mail
  inference runs there ], pri = secondary [ busier : jobsite, httpd,
  fetch stream, coding -- restarts likelier ], delta = third
- **delta is in the US** -> lowest preference for a European domain ;
  later a second US node on the same continent as its neighbour, then one
  in LA -> three US nodes [ NY, Dallas, LA ], the three together for the
  price of atom or less

- **geo MX [ with the planned geoloc dns replies ]** : US resolvers get the
  US nodes first, everyone else the EU order ; the edge accepts + filters,
  then routes over protocol-7 to the mailbox host. every answer set keeps
  ALL MX names [ only the order changes ] so fallback still works.
  owner : the regions INVERT priorities between each other, and the US
  nodes adjust their order among themselves by load and activity
  [ short TTL ; damp changes so the answer does not flap ]. base rule :
  lowest PREDICTED latency between the asker and each resolved host
  first [ estimated : hop count, AS path, geo -- refined by real
  measurements where known ], unless another reason [ load, outage,
  policy ] reorders it relatively. it is only a reordering [ every answer
  stays correct ], so the prefix -> latency mappings refine LAZILY in the
  background ; a query never waits on a measurement
- **dns is only the ENTRY layer** [ owner ] : behind it the web backends
  reroute too -- an open connection measures the REAL client rtt
  [ TCP_INFO ] in parallel, the backend can hand the session to a closer
  node over protocol-7, and those real rtts feed back into the dns
  prefix mappings [ the best measurement source there is ]
- **browser as a peer** [ owner ] : the network is p2p, crypto- and
  consensus-secured, so the browser can run PARALLEL streams to several
  hosts directly ; content verified by checksum, so trust never depends
  on which host served it. the hosted side keeps the browser's host list
  live : shrink \ reorder as optimizations land, and DRAIN a host ahead of
  a planned restart [ clients move before it goes down ]. links
  [[vision-sessions-zenka-key-holding-children]]
- **the browser routes too** [ owner ] : relaying between streams is a
  workload a browser can take, as long as what it carries is safe --
  symmetric sub-bit streams [ data/tasks/sub-bit-element-definition.md :
  elements have no category until full assembly ] -> a relay holds no
  readable part. browser constraints : no inbound sockets [ WebRTC data
  channels for peer links ], opt-in + bandwidth \ battery budget
- **an open browser = the cheapest way into the network economy**
  [ owner ] : relay work is contribution, and functions can be PAID WITH
  WAITING [ routing time ] instead of money. fits layer 5 of
  data/md/design/NETWORK-RESOURCE-TOKEN-ARCHITECTURE.md [ pools sized by
  contribution ]. open : relay receipts [ the next hop signs, consensus
  counts ] so contribution can't be faked
- **browser storage too** [ owner : perfectly symmetric to routing ] :
  the browser keeps network data in its local storage, again only
  category-free sub-bit fragments. use IndexedDB [ quota = share of the
  disk ] not localStorage [ ~5 MB ] ; browsers EVICT -> a volatile tier,
  redundancy across holders, navigator.storage.persist() asked ; proof of
  storage = checksum challenges on random ranges
- **rendering is networking too** [ owner ] : rendering visuals and
  sharing the perspective \ realizations ; the UNIQUE factor is the
  participant's position [ e.g. on a ring ] -- every view adds what no
  other position can, so even pretty visualizations are useful work.
  links [[topic-observer-centric-space]], [[topic-perspective-layers]],
  [[topic-implicit-perspective-navigation]]. ALREADY DESIGNED [ ack
  ring.+topology : 40 hits ] -- data/md/design/RING-ROUTING-PROTOCOL.md
  [ ring = shared key material, layered rings toward a center, 'through
  what' ] + VISUAL-ELEMENT-DEDUP-HOLOGRAPHIC-CORE.md 'self-rendering'
  [ transporting data IS rendering the topology ] : extend those, don't
  restate

**Why:** primary on the host least likely to restart ; mail lands where
its processing runs [ correlation with jobsite rejections, dossier
evidence -- see [[project-jobsite-report-dossier]] ].

**How to apply:** before the swap check the mailbox store location
[ the primary should hold or sync it, else it only relays ], equal
recipient \ spam filtering on every MX [ backup MX is a spam target ],
TLS certs for each MX name [ MTA-STS lists all names ], lower the MX TTL
a day ahead. outbound [ SPF, rDNS ] is separate.

related : [[vision-shared-pattern-registry-ncode-smtpd-forensics]],
[[topic-smtpd-actionable-mail-channels-notify]]

#,,,,,.,.,..,,.,,,..,,,..,.,,,,.,,,..,...,.,.,..,,...,...,.,,,..,,,..,,.,,...,
#HGTXPFOVYL6LXTXULNONANJG6MYPKQWTRDFXOENVHU43DI5LBXFRULNMSRFCY73I7VB5VK77R7TD6
#\\\|AUF4RONRIKACWA3SYATN6MAM7CSQXNME4DOUI6AM3GKGU3QQD6M \ / AMOS7 \ YOURUM ::
#\[7]Q3JVQ6HTC2LMSKOVXLHR4DD2FG7T6HTQIDT2TWYZUHECQFMTSGBA 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
