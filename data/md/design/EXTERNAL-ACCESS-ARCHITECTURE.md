## [:< ##

# external access architecture
# transports, arrival channels, one approval queue, roles and connection modes

---

## why

reaching a host from outside grew piece by piece : ssh -W, auth-keypair
wire v2, host-root pins, discover offers, the dns knock idea, the outer
cube decision. this file holds them together as five layers, so each one
can be refined alone and a new channel or transport slots in without
touching the others. [ owner 2026-10-31 : be multi-channel flexible, keep
refining the relevant ones ; a key waiting in an incoming queue beats
copying keys around by hand ]

builds on, does not repeat :

- `AUTH-LINK-BINDING.md` : wire v2 [ nonce, labelled sigs, link transcript,
  server proof, client pin ]
- `TRUST-CHAIN-STEP2.md` : host-root, owner root, certify-host \ owner-pin
- `AUTHORIZATION-BUFFER.md` : the pending-approval queue [ design only ]
- `NESTED-CUBE-NETWORK-SEGMENTATION.md` : outer cube = gateway [ ext-cube ]
- `HOST-SETUP.md` 'incoming, later' : cube never listens publicly
- `data/tasks/dns-knock-dynamic-ingress.md` : signed dns knock
- `data/tasks/command-relay-zenka.md` : optional mapping adapter
- `data/md/documentation/NETWORK-ADDRESSING-AND-TOPOLOGY.md` : segments
  joined by filtering relay zenki

---

## 1. transports : how the bytes travel

- ssh -W to `127.0.0.1:42` [ today, `:::` \ p-7-r ]
- plain tcp to a public listener [ the listener role, part 4 ]
- udt [ not designed yet ]

rule : nothing above this layer depends on the transport. wire v2 binds
nonces and keys, not tcp facts -- recheck that once when udt starts.
pins name the HOST, never the dial address [ HOST-SETUP.md ].

---

## 2. arrival channels : how a key or request reaches a host

| channel | scope | note |
|---|---|---|
| discover multicast | lan, zero config | offers only, unauthenticated announce |
| dns | any | fingerprints \ signed statements in our own zones, the knock |
| knock | public listener | one signed packet [ or the dns knock ], never a port sequence |
| manual | any | paste \ file, the fallback |

no channel is trusted by itself : each one only DELIVERS into the queue
[ part 3 ]. the same key arriving through several channels raises its
confidence shown to the owner, it never approves it.

---

## 3. one approval queue

the authorization buffer [ `AUTHORIZATION-BUFFER.md` ] is the single place
every channel delivers to. additions for key arrival :

- entry type `key_arrival` : key, full fingerprint, channel[s], source,
  first \ last seen, the requested user \ role
- expiry, rate limit per source, duplicates merged [ channels appended ]
- approval = a decision SIGNED by the owner key [ TRUST-CHAIN-STEP2 owner
  root ], from any already trusted session, local or remote
- the one automatic case : a key already certified by the owner key
  [ e.g. a new host of one's own ]. everything else waits for the owner
- approve writes the host-local user \ key mapping [ host cfg dir, never
  the repo ] ; only public halves ever travel

this replaces a separate 'authorize-remote' writer : 'put my key into host
X's queue through any channel that works, then approve it'.

---

## 4. roles

```
network ── listener zenka ──fd──▶ outer cube [ default : external-facing zenki ]
                          └─fd──▶ local cube [ admin sessions, by policy ]
```

- **listener zenka** : the only process on the network. least privilege.
  does the cheap risky front work : knock check, rate limit, banner, auth
  handshake, delivering pending keys to the queue. a broken parser takes
  down only the listener ; no cube sees an unauthenticated client
- **outer cube** : parallel to the local one, the default home of zenki
  that talk to external clients [ httpd, web, .. ]. registers as `ext-cube`
  at the local cube [ NESTED-CUBE-NETWORK-SEGMENTATION.md ]
- **local cube** : stays on `127.0.0.1` [ unix + loopback ]. reached from
  outside only by sessions an owner-signed rule allows
- **filtering relay zenka** [ optional, between two cubes ] : connects to
  both segments and forwards only the commands \ zenki its policy allows,
  with logging or transformation -- the policy point stays out of either
  cube [ `data/md/documentation/NETWORK-ADDRESSING-AND-TOPOLOGY.md`
  'Filtering Relay Zenka', `command-relay-zenka.md` ]. it is the natural
  home of routed-mode policy at a boundary, e.g. v7-zenki reachable from
  the outer cube with a restricted command set

---

## 5. connection modes

| mode | intermediate hops see | for |
|---|---|---|
| hand-off [ fd passed ] | nothing, none after set-up | same host : listener -> cube |
| routed [ today, plain ] | content : decrypt, route, re-encrypt | equal trust, one network |
| tunneled [ nested ] | the outer frame only [ next hop, size ] | less trusted -> more trusted |

- **hand-off** : `SCM_RIGHTS` over a unix socket after auth. latency only
  at set-up. the receiving cube then talks to the client directly : the
  boundary is the auth decision, not a relay
- **relay** : per host instead of hand-off, for set-ups where nothing
  external may touch the local cube directly [ one hop per message ] ;
  a filtering relay zenka [ part 4 ] makes it selective per command
- **tunneled** : outer layer = the per-hop link [ wire v2 + link-upgrade ] ;
  inner layer = the same handshake again end to end, client <-> target
  cube, bound to the target's host-root pin, carried as the opaque payload
  of a `tunnel` channel. middle hops hold no inner key : no read, inject or
  replay. own direction keys [ `link_role` ] and own nonces per layer,
  never shared [ lesson of the 2026-10-05 nonce reuse fix ]
- **udt** : one shared udp socket, no per-connection fd -- the listener
  stays in the path [ relay ] or forwards demultiplexed streams over a
  unix socket. tcp and udt must end in the same trust path

policy, per host and per target : e.g. 'local cube admin from outside :
tunneled only'. routed stays the default inside one trust zone.

---

## slices

1. queue : `key_arrival` entries in the authorization buffer, owner-signed
   approve, manual + discover channels [ first consumer ]
2. listener zenka on tcp, hand-off to the outer cube
3. tunneled mode [ inner wire v2 over a `tunnel` channel ]
4. dns channel + knock [ after nameserv is master ]
5. udt transport

## open

- hand-off vs relay as the per-host default
- where the listener runs when the outer cube is on another host
- the owner key choice [ TRUST-CHAIN-STEP2 : user to choose ]

#,,,,,,..,..,,,,.,...,,,.,,.,,...,...,...,,.,,..,,...,...,,,,,,,.,.,.,,,,,.,,,
#VW5XZKNVWGDMB2KOBYZT34AY7LRSWHJLSIKHJGPCUK6CI7M45TQSPJMQSUE5QOSF67BADQJXY6YHO
#\\\|Q2XVXRNRCY2T2O26QRVLTMH5UCY7X5HHTY2FH6FZDBL7P6VYHQB \ / AMOS7 \ YOURUM ::
#\[7]3GO5FIPNGJAOTNGF55HB2U6XWKYXBXSRWTYMIPD6RICSVCI2I2DI 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
