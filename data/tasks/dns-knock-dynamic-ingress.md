# dns knock : dynamic incoming addresses for linked hosts

idea [ user, 2026-10-09 ]. no well-known incoming port : a client proves its
key with a signed dns query to our own authoritative nameserver, and the
answer names a short-lived incoming address [ or port ] that only it knows.
builds on : own nameservers [ `data/tasks/letsencr-dns01-own-nameservers.md`,
`nameserv` zenka ], the outer cube as the only public listener
[ `data/md/design/HOST-SETUP.md` 'incoming, later',
`data/tasks/command-relay-zenka.md` decision ], host \ user key pins.

## shape

```
client                          our nameserv [ authoritative ]
  | q : <sig>.<key-id>.<nonce>.knock.<domain>  TXT \ AAAA
  |-------------------------------------------->|  verify sig against the
  |                                             |  pinned \ authorized key,
  |                                             |  nonce unused + fresh
  |                                             |  -> allocate ingress
  | a : AAAA <per-session address> [ ttl 0 ]    |  [ address \ port, window ]
  |<--------------------------------------------|
  | tcp -> outer cube on that address, normal auth-keypair v2 + link upgrade
```

- **knock name** : ed25519 signature 64 bytes = ~103 base32 chars -> two
  labels [ dns limits : 63 per label, 253 total ]. signed : key id, nonce,
  timestamp, the zone, and [ see below ] the client's own address
- **replay** : nonce + timestamp window ; nonces remembered for the window
- **no caching** : every name unique [ nonce ], answers ttl 0
- **answer** : prefer a per-session IPV6 ADDRESS over a port -- pri has a
  /64 [ 2a02:c206:3016:2071::/64 ] : the address itself is the secret, no
  scannable port at all. ipv4 hosts : a port, sent in a TXT encrypted to the
  client key
- **unknown key \ bad sig** : the same NXDOMAIN as any unknown name [ the
  knock zone looks empty from outside ]

## the catch : who is asking

a query normally arrives from the client's RESOLVER, not the client. a
firewall rule by source address needs the real client address :
- the client queries our nameserver DIRECTLY [ no recursion ], or
- the signed knock carries the client's address [ then the opened address
  accepts only that source ]
either way the opened ingress is bound to one source for one window.

## pieces

- `nameserv` : a knock zone handler [ verify, nonce store, allocate, answer ]
- privileged ingress step : add the address \ open the port for the window
  [ nftables set with timeout, or `ip -6 addr add ... valid_lft` ] -- root,
  so through v7-zenki \ system, never in nameserv itself
- outer cube : accept on dynamically added addresses
- client side : p-7-r \ external knock before dialing [ host record :
  `transports` gains `knock:<zone>` ]

## related

- the same signed dns queries can publish \ request host keys and discovery
  records [ key exchange, `nameserv.publish-node` \ `discover-nodes` exist ]
- order : after the outer cube exists ; nothing to knock for before

#,,,,,,..,,,.,,.,,,.,,..,,...,,.,,..,,..,,,..,..,,...,..,,,.,,.,.,...,...,...,
#PP3ZTAT5OLZOOHHIVSPBQZOC63DDH7RLNI54DSC7UV6ADWOKO2IBZBCIP7G7RVGH262WAEX4R755Q
#\\\|4EYPYKYKYL3JTBGBN55EV3PYAJEY5BLDAQBHS7FGH2RKOXCGCYH \ / AMOS7 \ YOURUM ::
#\[7]JYQFFCHW3WZXMO3YQMM5TWJGGSPF72RUG6OZY7B3NHOIAYRRZWDY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
