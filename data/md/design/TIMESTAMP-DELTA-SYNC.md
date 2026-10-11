# timestamp delta sync -- signed, transport independent

status : design, 2026-10-11. first user : nameserv [ zone sync between
DN0000, DN0110, DN1110 ]. later : any `%data` branch, N7FS [ todo 4EO ].

shaped after the timestamp sync fabric
[ data/md/vision/VISION-DATA-SYNCHRONIZATION-FABRIC.md ] and the channel
commands `last-data-timestamp` \ `next-data-timestamp` \ `channels-since`
[ data/md/architecture/PHASE-7-CHANNELS-AND-NODES-INFRASTRUCTURE.md ;
`src/channels.cmd.*` are still stubs ]. the checksum-as-state idea is the
one from data/md/design/DATA-PROTOCOL-SYNC.md.

## why not axfr \ tsig

- tsig secures the CHANNEL with a shared secret ; the transferred zone
  proves nothing afterwards and only the primary can serve it.
- serial numbers say THAT something changed, not WHAT ; ixfr needs the
  primary's change journal.
- one writer only : every host's letsencr would have to route through
  the primary to publish its `_acme-challenge` txt.

here the DATA is signed, not the channel : any peer can relay, any
transport can carry it, and every host may write the names it is
allowed to write.

## data model

every record is an entry :

```
{ zone, name, type, value, ttl, ts, writer, sig }
{ zone, name, type, deleted => ts, writer, sig }      ## tombstone ##
```

- `ts` = network time, base32 [ `base.ntime.b32` ], set by the writer at
  the change. timestamps are compared by value [ `base.ntime.delta_seconds`
  ], never trusted as strings of different length.
- record identity = `zone + name + type + value` for multi-value types
  [ txt, ns, a, aaaa ], `zone + name + type` for single-value types
  [ soa, cname ].
- a delete is a tombstone with its own `ts` ; it stays for
  `sync.tombstone_keep` [ default 13 days ] so a peer that was offline can
  still learn about it, then it is dropped. a peer offline longer than
  that does a full fetch.
- zone ts = newest entry ts in the zone ; set ts = newest zone ts. this is
  the hierarchy of the fabric : one value answers "anything new at all?",
  the zone value narrows it down.
- zone checksum = BMW over the sorted live entries [ tombstones excluded,
  sort by identity ], base32. two peers holding the same records hold the
  same checksum, whatever order they learned them in.

## the signed entry

```
entry_body = pack( 'Z* n/a* n/a* n/a* n/a* N n/a* n/a*',
        'p7 sync-entry v1', zone, name, type, value_or_empty,
        ttl, ts, deleted_flag )

sig = Ed25519_sign( writer_key, entry_body )
```

same conventions as data/md/design/AUTH-LINK-BINDING.md : `Z*` = label +
one \0, `n/a*` = 16-bit length + bytes, `N` = 32-bit. the label keeps an
entry signature from being valid as any other signed message.

- `writer` = the signing key's fingerprint [ host-root or the zenka key
  of the writing host ].
- peers pass entries on UNCHANGED, signature included. a relay adds
  nothing and cannot alter anything.

## who may write what

per host config [ `/etc/protocol-7/nameserv/host.cfg` or a pins file next
to the server pins in `~/.n/remote-keys/servers/` ] :

```
sync.writer.<fingerprint> = zone:protocol-7.network zone:v7.ax
sync.writer.<fingerprint> = name:_acme-challenge.acme.protocol-7.network
```

- `zone:` = any name in the zone ; `name:` = exactly that name [ and only
  txt ] -- a host's letsencr gets its challenge names, nothing else.
- an entry from an unknown writer, or outside its grant, is dropped and
  logged [ level 1, once per writer and zone ]. fail-closed.
- the local nameserv signs its own changes [ `set-record`, `add-txt`,
  `remove-txt`, `ensure-zone` ] with its host's key ; the grant for the
  own key is implicit only for zones the host holds as primary.

## accepting an entry

in order, each a hard reject :

1. label, length fields and base32 ts parse.
2. signature verifies against the writer's pinned public key.
3. writer grant covers zone + name [ + type txt for `name:` ].
4. ts not more than `sync.max_future` [ default 300 s ] ahead of local
   time -- a writer cannot make its entry win forever.
5. if an entry with the same identity exists : the newer ts wins. equal
   ts : the lower signature bytes win [ deterministic on every peer ].
   an older entry is ignored, NOT an error [ normal when relayed twice ].

replay : an old, validly signed entry loses step 5 against anything
newer. a replayed entry for a record deleted long ago [ tombstone already
dropped ] is the one gap : step 4 bounds it from the future side ;
`sync.max_age` [ default = tombstone_keep ] rejects entries older than
the tombstone window from the past side.

## queries

a small line protocol, one request per line, replies end with a line
`.` -- the same shape as the cube command lines, but needing no cube,
no session and no link : every reply is checked entry by entry.

```
last-data-timestamp [<zone>]
  -> TRUE <ts> <checksum>                  [ zone ] or
  -> TRUE <ts>                             [ whole set ]

next-data-timestamp [<zone>] since:<ts>
  -> blocks until something newer than <ts> exists
  -> TRUE <ts>

since <ts> [<zone>]
  -> ENTRY <base32 entry body> <base32 sig> <writer>     [ per entry ]
  -> CHECKSUM <zone> <checksum> <ts> <base32 state sig> <writer>
  -> .

full <zone>
  -> same as since, all live entries
```

- `CHECKSUM` is the state after applying the listed entries, signed with
  label `p7 sync-state v1` over `zone, checksum, ts`. a peer that leaves
  entries out cannot produce a matching checksum : the receiver applies
  the entries, computes the checksum itself, and on a mismatch fetches
  `full` [ from another peer when possible ].
- `next-data-timestamp` is the push : each nameserv keeps one open
  connection to each peer and gets woken on a change. no separate notify.
- a dropped connection reconnects with backoff ; on reconnect a
  `last-data-timestamp` compare decides whether `since` is needed.

## transport

- tcp, own port [ `sync.port`, derived like the other protocol-7 ports ].
  dual-stack `::` with ipv4 fallback, like nameserv's dns socket.
- no confidentiality needed [ dns data is public ] ; integrity comes from
  the entries. a later version can carry the same lines over a p7 link,
  a DATA channel or a file -- nothing in the protocol depends on tcp.
- limits : max line length, max entries per reply, max open connections
  per peer address -- an unauthenticated port must not be a memory sink.

## storage

nameserv zone files stay yaml ; entries gain `ts`, `writer`, `sig`.
tombstones live in a separate `<zone>.tombstones.yaml` so a hand-read
zone file still shows only live records. hand-written zone files without
signatures load as before but are local-only : they are never sent to
peers [ a host's unsigned file must not override signed data elsewhere ].

## stage 3 decisions [ 2026-10-11 ]

**sync key** : one long-lived C25519 key per host, `nameserv-sync`, in the
backend user's key tree [ next to cube's S ; nameserv drops to the same
user ]. nameserv creates it on first start [ after drop_privs ], never
regenerates it -- entries are relayed unchanged for as long as they live,
a new key would orphan every signature. rotation is an explicit command
that re-signs this host's own entries.

**its delegation** : host-root signs it with the existing statement
[ data/md/design/HOST-ROOT-DELEGATION.md, `p7 delegation v1` ] :
name `<host>.nameserv-sync`, scope '', 30 days, renewed below 7 days --
`v7-zenki.delegation.issue` handles it next to cube's S [ same file
`<backend key dir>/nameserv-sync.dlg`, same owner-chain handling ]. the
statement is not a copy of `crypt.C25519.generate_session_keypair` [ that
one signs with the zenka's own base key and is regenerated on a timer ] :
the anchor here is host-root, the shape the session key would take once
host-root signs it [ the root/ key is a child of the host that becomes the
parent of every key it delegates ]. `trust.*` stays unchanged [ shared
with auth and the C client's test vector ].

**writer** = the sync key's id [ bmw384 b32, 77 chars, like the host-root
id ]. a peer asks `writer <key id>` once and caches the answer : the
`.dlg` chain [ leaf = the sync key's statement ]. verified with
`trust.verify`, anchors = exactly the host-root ids the RECEIVER grants.

**grants** : receiver config only, keyed by host-root key id, never by a
statement's own scope :

```
sync.writer.<host-root key id> = zone:protocol-7.network zone:v7.ax
sync.writer.<host-root key id> = name:_acme-challenge.acme.protocol-7.network
```

tombstones are checked like records [ a `name:` grant cannot delete
anything else ].

**stored bytes** : every record and tombstone written locally is
normalised, then signed ; the store keeps `body` [ the exact signed bytes,
b32 ], `sig` and `writer`. `since` \ `full` send the stored bytes, never a
re-encoding. records without a signature [ hand-written, pre-stage-3 ]
answer DNS locally but are never sent.

**state line** : `CHECKSUM <zone> <checksum> <ts>` signed with
`p7 sync-state v1` by the replying host's sync key -- it attributes the
claim, it cannot prove completeness.

**hardening of stage 2 paths** :
- `full` never deletes : each entry goes through the accept rules ; a
  record the peer did not send stays.
- one `full` per peer timestamp : a lasting checksum mismatch [ entries
  outside our grants ] is logged, not refetched in a loop.
- equal ts : the lower signature bytes win.

**commits** : 3a = sync key + its delegation [ v7-zenki, root-held code,
reviewed line by line ] ; 3b = signing, verifying, grants, accept rules.

## stages

1. timestamps + tombstones in nameserv's record store, zone checksum,
   `last-data-timestamp` [ local command first ]. no network.
2. the tcp line protocol with `since`, `full`, `next-data-timestamp`,
   unsigned, between two local test instances.
3. signing + verifying entries and state, writer grants, the accept
   rules above. security-critical : reviewed line by line.
4. letsencr writes its challenge txt as signed entries to every nameserv
   [ replaces the single `add-txt` route ].
5. generic : the same entry format for a `%data` branch [ channels
   memory-sync ], then N7FS.

## open

- [ settled 2026-10-11 : a dedicated sync key delegated by host-root,
  see 'stage 3 decisions' ]
- whether `sync.port` should also answer dns-over-tcp, or stay separate.
- tombstone_keep vs. peers that are offline for weeks [ full fetch is
  fine for zones ; for larger data a checksum tree like N7FS is needed ].

#,,,.,...,,,,,.,.,,,.,,.,,...,...,...,...,,.,,..,,...,...,.,.,,,.,,,,,,..,..,,
#AYS5GYQSKRL3RM6VF35TWOR5HJFNSKMKDZTVZJEODFQMYQLVN5Y2OOJP2GEVMRNWXTZLNLAQYPEOQ
#\\\|AQA2LKMB2AS5ZT66FZVEGUCMHQ3H5GNQ5O624G6OHNJM6SAQFD5 \ / AMOS7 \ YOURUM ::
#\[7]FG6CJPWPK22CJYUSHVTCDHPU57KZ5KNL7QGPC6YA6NJEDPZXCKBI 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
