---
name: vision-2026-10-05-generic-trust-chain
description: user direction 2026-10-05 [ incl. upward chains, node groups, MLS-style rekeying rings ] -- ONE initially trusted root key secures everything else through a generic chain-following verifier ; trust [ is this key really <name> ] separate from permission [ may <name> do X here ] ; root key LOCATION still open ; consumers : link-upgrade server proof, users key management, discover signature resolution, nodes trusting node lists regardless of proximity
metadata:
  type: project
---

**user, 2026-10-05** : "a generic approach to following a trust chain, so
that however the actual set-up is, only one true key being initially
trusted secures the rest, regardless of the actual decision to also allow
it in the given context or not". not urgent -- "we are not that far from
having the gaps closed".

## why it came up

- link-upgrade [ after the nonce fix, [[project-2026-10-05-link-upgrade-nonce-reuse-fixed]] ]
  binds the encrypted channel to NOTHING : the server only ANNOUNCES its
  key after `select auth-keypair` [ `TRUE <pubkey>` ], never proves
  possession, the DH is ephemeral-only -> an active MITM relays the
  announcement [ p-7-r's TOFU pin passes ] and runs separate DH with both
  sides. TOFU of an unproven key protects nothing -- p-7-r today, and
  `external.link.open` [ c26bfb171 ] which has no server check at all
- trust and permission are fused today : `authorized/cube/<label>.public`
  both authenticates AND names the access-grant label

## agreed shape [ my proposal, user agreed with the direction ]

- trust = generic, answered once : a chain of signed delegation
  statements from the root -> "key K is <name>" ; permission stays local
  [ `access.*`, keyed by the VERIFIED name ]
- PUBLIC delegation, not the key-tree doc's deterministic derivation :
  `data/md/design/KEY-TREE-AUTHORITY-FIELD.md` derives child keys from
  the parent [ verifier needs the parent SECRET ] -- fine inside one trust
  domain, impossible across hosts. keep its namespace-narrowing +
  root-at-top shape, swap the mechanism to "parent signs child pubkey
  [ name, may-certify <name>.*, expiry ]"
- one verifier [ `trust.verify` ] : walk to the root, check every
  signature \ expiry \ name constraint, return the verified name
- proof of possession bound to the context : sign the actual exchange
  [ link-upgrade : server signs both ephemeral pubkeys + nonce_sid ]
- short expiry + root-signed revocation list ; TOFU only as an explicit
  fallback outside the chain
- first consumer : link-upgrade server proof

## open [ user's decisions ]

- WHERE THE ROOT PRIVATE KEY LIVES -- unresolved ; it stalled once
  before on identity management, which spawned user-edit + the users
  zenka [ good direction, but no key management as such yet ]
- statement format [ AMOS7 signature-block style ? ]
- namespace as the authority boundary [ a host key certifies only
  `<host>.*` ? ]

## existing placeholder : the 'global-root' key [ found 2026-10-05 ]

- created by v7-zenki's first start in every user's key dir
  [ `crypt.C25519.post_init`, `cfg.create_global_root_key` //= TRUE ] next
  to `<user>.base` ; user : "a placeholder if you will, we can expand and
  tie in that mechanism"
- it is a FIXED, PUBLICLY KNOWN key pair : `crypt.C25519.gen_keys` maps the
  secret `'0' x 32` to hardcoded public + private keys IN THE SOURCE ->
  identical on every install, anyone can sign as it. harmless only while
  nothing verifies against it [ `sign_keys` is commented out in post_init ]
  -- NEVER anchor a chain on it as is ; a verifier must refuse chains that
  end at the well-known placeholder
- what the mechanism already gives : the "C25519" triplets are Ed25519
  [ `Crypt::Ed25519::generate_keypair`, they can sign ], and gen_keys can
  derive the secret from a passphrase [ `AMOS7::13::key_32( passphrase,
  name )` ] -> a candidate answer to the location question : root secret
  re-derived from the owner's passphrase on demand, never stored, only
  the public half on disk \ distributed [ like the source signing prompt ]
- proposed tie-in : keep 'global-root' as the anchor SLOT, fill it with
  the owner's real root ; the placeholder pair only marks "no root yet" ;
  root signs host \ user `.base` delegations [ the rewritten `sign_keys`
  in post_init ]

## per-host roots + fingerprint pinning [ user idea, 2026-10-05 ]

- user : if atom used its global-root to sign all further sub-keys, then
  knowing atom's key checksum [ or the key in full ] closes the trust
  chain, TOFU included ; on-demand resolution possible but adds latency
- agreed shape : a REAL per-host root [ not today's placeholder ] signs
  `<host>.cube`, zenka keys, `<user>.base`, session link keys ; peers pin
  only the root FINGERPRINT [ bmw384 B32, the osf-cache id format ] -- the
  full pubkey may come from anywhere, the fingerprint authenticates it ;
  TOFU shrinks to one pin per host, checkable out of band
- latency : the presenter SENDS its chain with the exchange [ link-upgrade
  : cube's delegation statement + its signature over the transcript ] ->
  verified locally, zero extra round trips ; verified statements cached
  by checksum ; on-demand resolution only as fallback \ for unknown roots
- layers : owner root signs host roots -> one pinned fingerprint [ the
  owner's ] covers the whole network ; host roots keep hosts autonomous
  [ certify locally ] ; same verifier, one more step
- caution : a HOST packet announcing its own root is self-certifying ->
  discover may OFFER fingerprints, trust comes only from a pinned or
  owner-signed root ; then nodes can trust lists regardless of proximity

## upward chains, node groups, rings [ user vision, 2026-10-05 ]

- user : "able to follow the chain upward.. like knowing whoever signed
  atom's global root key.. ultimately we will have node groups securing
  each of their members and cryptographic rings with re-keying when nodes
  join or leave"
- upward : a key may have SEVERAL parents [ owner root, group keys ], each
  delegation with its own name constraint + expiry ; verification =
  finding ANY valid path to ONE of the verifier's anchors for that
  context [ name constraints keep it from becoming an open web of trust ]
  ; revocation above cuts every path below
- node groups : a group key signs membership statements for member host
  roots [ "member of G until T" ] ; members verify each other via the
  group fingerprint only ; leave = expiry or group-signed revocation
- rings : a SEPARATE layer -- the chain answers WHO is in the group
  [ authentication ], the ring answers WHAT only the group can read
  [ confidentiality, one key per epoch, new epoch on every join \ leave :
  forward + post-compromise secrecy ]. do NOT invent the group key
  protocol : adopt the MLS structure [ RFC 9420 : epochs, add \ remove
  commits, TreeKEM ~log n rekey ] ; no known Perl implementation -> build
  to spec carefully ; tie into `data/md/design/RING-ROUTING-PROTOCOL.md`
- build order [ each step useful alone ] : 1. real host roots + chain
  verify + link-upgrade server proof [ closes the MITM gap ] ; 2. owner
  root above host roots, upward chains ; 3. group keys + membership,
  nodes trust lists via the group ; 4. epoch ring keys [ MLS structure ]

## unknown chains : offer the HIGHEST verified parent [ user, 2026-10-05 ]

- user : if the parents do not match a trust declaration yet, offer the
  HIGHEST parent for trusting or not, instead of the key at the
  connected-to level -- TOFU at the top of the chain, not the leaf
- rules : the walk goes up only as far as signatures VERIFY ; the top
  verified key is the candidate [ never an unverifiable claim above it ] ;
  shown with fingerprint, the path down to the connected key, and the
  SCOPE trusting it grants [ every name it may certify ] ; the highest is
  the suggestion, the decision may pick a lower level [ intermediate,
  or only the leaf, per context ] ; the placeholder global-root is never
  offered
- a decision = a trust declaration [ anchor, scope, context, optional
  expiry ], stored locally, ideally signed by the user's own key so
  declarations cannot be swapped on disk ; later connections find their
  path silently

## the sourcecode key as the public-context anchor [ user, 2026-10-05 ]

- user : the sourcecode key may get special meaning for validating
  official protocol-7 resources ; data stays signed, an encrypted link to
  them is then not hindered ; nodes joining the PUBLIC-facing network
  must be signed somewhere in their chain by the sourcecode key
- why it fits : every installation already carries its public half
  [ every source file is checked against it ] -> the one anchor that
  needs no TOFU anywhere
- shape [ my proposal ] : a separate CONTEXT, not a universal root --
  official \ public context anchors at the sourcecode key, private
  context at the owner root ; a node may hold both chains, neither key
  speaks for the other's context
- delegate, do not sign nodes directly : the sourcecode key signs ONE
  public-network key [ scope : public membership ], that key admits
  nodes ; revocable without touching code signatures ; sourcecode key
  stays offline [ releases + rare delegations ]
- signed data keeps integrity end to end ; the link adds confidentiality
  + a verified server [ chain to the sourcecode key ]
- revocation matters most here : network-key-signed revocation lists via
  the same official channel

## bootstrap : signed entry-node list in the source [ user, 2026-10-05 ]

- user : the source can carry a list of last known good entry nodes to
  the network, plus discovery strategies for when that list goes stale
  [ the Tor directory-authority \ bitcoin seed pattern, but trusted from
  the first byte : it is signed source ]
- entries = key fingerprint + last known addresses : a stale or hijacked
  address cannot impersonate [ whoever answers must prove the key ] ->
  staleness fails closed
- fresher lists from any reachable entry node, signed by the
  public-network key [ no release needed ] ; sequence numbers, never
  accept an OLDER list [ rollback to revoked nodes ]
- fully stale : LAN discover, nameserv \ dns, peer exchange give
  ADDRESSES only ; every found node must still chain to the
  public-network key [ discovery = where to look, chain = whom to believe ]
- eclipse attack : build the network view from several independent entry
  nodes, never from one peer

## discovery via external networks [ user, 2026-10-05 ]

- user : add all kinds of discovery methods, incl. external networks like
  XMPP, IRC, "all with entropic and cryptographic predictability"
- external media = rendezvous only, never trusted : only signed
  announcements travel there [ candidates : XMPP, IRC, Matrix, DNS TXT,
  bittorrent mainline DHT, mail, pastebins ]
- predictable rendezvous : `channel = H( key || epoch )` -> room \ channel
  \ dns label \ dht key, rotating per epoch, computable by every key
  holder without arrangement
- derived from a PUBLIC key [ public network ] : censors can predict it
  too -> rotation + many media keep blocking expensive ; from a GROUP
  SECRET [ private groups ] : unpredictable to outsiders
- announcements signed [ chain ] + epoch [ no replay ] ; group ones also
  encrypted with the group key ; expect squatters \ spam in predictable
  channels -> signatures make junk ignorable, still cheap filtering +
  limits, several media in parallel
- privacy : a constant node key links a node across epochs and media ->
  per-epoch BLINDED keys [ Tor v3 onion pattern : verifies as derived
  from the long-term key, unlinkable for outsiders ]

## private reuse : stealthy fallbacks \ encapsulated infrastructure [ user, 2026-10-05 ]

- user : what works in the public context, users can run themselves for
  stealthy fallback strategies, or hide their entire infrastructure
  distributed over encapsulations -- to an outside observer they just
  look more active in 'other protocols' contexts
- falls out of the design : public vs private = different anchor +
  rendezvous derivation [ group secret ], same code
- = pluggable transports [ Tor obfs4 \ meek \ Snowflake ] ; slot already
  exists : `external.init_code` "transport registry populated by
  plugin.external.* modules" ; carriers sit UNDER the chain + link
  encryption + signatures ; several carriers per link, per-group
  fallback order
- honest limit : blend in, not invisible -- content is easy, traffic
  analysis [ volume, timing, sizes ] is not ; MIMICRY FAILS ["The Parrot
  is Dead", 2013] -> tunnel through REAL protocol implementations [ real
  xmpp \ irc client libs ], never hand-made look-alikes ; padding \ timing
  normalization \ cover traffic as a per-group trade-off
- operational : heavy use of third-party services can break their terms
  \ get accounts banned -> spread load, prefer self-hosted \ federated

## observers : seeing vs interfering [ user, 2026-10-05 ]

- user : true invisibility = a growing PUBLIC protocol-7 network ; but
  who can see what differs, and not all who see also interfere [ e.g.
  automated blocking ]
- = collateral freedom : once enough ordinary traffic looks like yours,
  blocking it costs the blocker more than it gains ; the public network
  is every node's crowd
- tiered threat model :
  - automated blocking [ isp \ national DPI ] -- most common, cheapest to
    beat : acts on STATIC fingerprints [ ports, constant handshake bytes,
    sizes, known rendezvous ] -> no fixed handshake fingerprint, rotating
    rendezvous, real carrier protocols ; default-on
  - passive observers [ logging isp \ admin ] -- see volume + timing,
    rarely act -> the large public network is the defence
  - targeted active adversaries -- probe, correlate over time ; no
    transport makes a user invisible to them -> make each target
    expensive [ blinded per-epoch keys, unlinkable announcements,
    short-lived rendezvous ], never promise more

## participation as protection [ user, 2026-10-05 ]

- user : joining the public network implies processing \ routing data
  for it too -> user data is immediately indistinguishable from public
  data ; the true protection is regular participation in the network's
  interest, which is analogous to self-interest
- = the I2P \ Freenet argument [ every node routes -> "came from this
  node" is no safe inference ] ; ties to osf-cache stage 5 CREDITS :
  serving segments \ relaying earns a node its own capacity -> network
  interest becomes self-interest by mechanism
- conditions for the cover to be real :
  - per-hop re-encryption [ onion-style ] : a relayed message must not
    look the same going in and out, else flows are trivially matched
  - a node's OWN requests also take a hop or two through others : an
    outgoing flow with no incoming counterpart marks the origin ;
    per-request choice [ direct for public data like osf-cache segments,
    routed when it matters ]
- limits : long-term edge-to-edge timing correlation stays possible
  [ mixing helps, costs latency ] ; relaying has a liability side
  [ exit-node problem ] -> by default relay only WITHIN protocol-7, no
  open-internet exits ; prefer signed, content-addressed content ;
  per-node relay policy + resource budget

## nested layers + the intelligent queue = a mixnet [ user, 2026-10-05 ]

- user : the deeper data goes into nested network layers, the more it is
  disentangled from flow analysis ; the intelligent queue concept :
  equal-size packets [ 63K ] optimized in their queue positions while
  waiting, which influences their next routing steps -> tracking is lost
  at cubic scale [ the concept itself is not written down yet ; the
  63K\63M topology is in HYBRID-CONNECTION-TYPE-ROUTING.md ]
- = the mixnet design family [ Loopix, Nym ] : constant size removes the
  size signal, per-hop reordering multiplies the possible pairings
- conditions :
  - reordering must NOT be predictable : a deterministic optimizer over
    observable inputs can be modelled and inverted -> add randomness the
    observer cannot see [ e.g. exponential per-packet delays, Loopix ] ;
    the optimizer may still choose among options
  - mixing needs company : cover traffic [ dummy + loop packets ] keeps a
    minimum anonymity set when idle
  - n-1 \ flooding attacks : loop packets detect them [ own loops going
    missing \ delayed ], plus per-sender rate limits
- packet format : constant-size header that changes completely per hop
  [ Sphinx, as in Nym \ Lightning ] -- else header bytes link a packet
  across hops ; 63K means heavy padding for small messages -> bundling

## already designed : 63K buffer swaps, routing as search [ user pointer, 2026-10-05 ]

- `data/md/design/CONCEPT-DATA-ZENKA-ARCHITECTURE.md` ~l.860 "63K
  convergence : storage = network" : 63K content blocks = 63K packets,
  BMW checksum addressed, merkle verified, buffer-swapped at nodes,
  re-encrypted per hop, identical sizes against flow analysis, zero-copy
  [ block on disk = packet in flight ]
- 63K buffer swaps as BASE FALLBACK WORKLOAD [ full-chat capture
  3O37VUNMMS3UU l.16623 ] = the mixnet's continuous cover traffic [ queues
  never idle ] ; pushed junk "counts as valid network workload" for the
  target -> flooding \ n-1 attacks partly absorbed by design
- `data/md/design/ROUTING-AS-SEARCH-DISTRIBUTED-DISCOVERY.md` : route TO a
  checksum, discover along the path, cache along routes -> the natural
  future of osf-cache's "who holds H ?" [ instead of fan-out to known
  peers ]
- related memory : topic-observer-centric-space [ buffer swapping
  navigation ], topic-latency-algorithmic-authority-entropy-toll
- MISMATCH to resolve : osf-cache stage 4 [ 1c15c65d9 ] fixed the merkle
  leaf at 65536 bytes [ a protocol constant, part of tree identity ] ;
  the data-zenka design says 63K blocks = packets -> if osf-cache segments
  are those blocks, the leaf must be 63K. cheap now [ only local test
  trees in /var/protocol-7/osf-cache/merkle/ ]. open : is 63K the whole
  packet incl. header or the payload ; 64512 or 63000 bytes ?
- `data/asc/what-AI-thinks/html-form/protocol7/protocol7_essence_doc.html`
  ~l.545 : "cubic route queues : 63K packets in anti-entropic flow" +
  "latency becomes security -- flow analysis becomes impossible" = the
  mixnet trade-off [ queue wait buys unlinkability ] ; "63 visible
  subcubes, 4x4x4 grid with strategic missing corner, 64th bit gateway"
  -> MY READING, unconfirmed : 63K = 63 x 1024 = 64512 bytes, the missing
  1K slot of the 64K space could hold the per-hop header
- user : the 63 vs 64 is still slightly complex, tied to the 8+63
  subcube node group of the hyperspace visualizations ; the simple math
  was seen a few times, needs RE-DERIVING. spatial side recorded in
  [[topic-node-group-geometry]] [ 4x4x4 - 1 corner = 63, 8 x 63 = 504,
  the 4x4x4 void = ghost 9th cube ] ; the byte mapping is not written
  down anywhere. DECISION : osf-cache keeps 65536-byte leaves until then
  -- safe, peers on different leaf sizes get a merkle conflict and
  refuse, trees rebuild cheaply from the files
- user, same day : the 1K header idea "makes perfectly sense" -- often
  there are similar secondary advantages [ packing pattern ] : limiting
  code width to 78 chars also gave the 77 char octal header [ 70 + 7
  separators ] AND allowed the ': ' inline style from the bin/Protocol-7
  data block without reformatting -- "obvious that this will also be a
  pattern used in protocol itself"
- the 77 recurs : bmw384 in B32 is exactly 77 chars [ osf-cache's
  internal id ] -> one id fills one header field inside the 78-col lines
  the AMOS7 signature blocks use
- packet layout this suggests : packet 65536 [ 64K, buffer-friendly ] =
  1024 header [ per-hop routing, ids ] + 64512 payload [ 63 x 1024 = 63K
  = storage block = merkle leaf, zero-copy block-on-disk = payload ] ;
  osf-cache would move its leaf 65536 -> 64512 [ + segment size ]. held
  until the 63\64 re-derivation confirms it, unless the user is sure
- design signal : a constraint that satisfies several layers at once is
  usually the right one -- look for these when choosing protocol sizes
- user : the 1K entropy solves packet re-encryption -- the 63K payload
  stays unchanged, yet in the inter-node entropy stream every packet
  still changes its own visible entropy fully
  - holds for OUTSIDE observers : per-link encryption [ link-upgrade, a
    different key per link ] changes every visible byte per hop ; the
    1K header carries the fresh per-hop part [ routing + entropy ]
  - side effect : the payload stays content-addressed + stable end to
    end [ bmw384 id + merkle leaf valid along the path ] -> zero-copy
    forwarding, caching, dedup along routes [ routing-as-search,
    osf-cache segments served from relay caches ]
  - limit = INSIDERS : a relay sees the payload past the link layer ;
    colluding or repeat-seeing relays link the packet by its identical
    63K ; Sphinx changes the payload per hop for this, with a
    construction where bit-flip tagging only destroys the packet
  - -> two classes, per packet : PUBLIC cacheable content [ debs,
    official resources ] = stable payload [ insider linking costs
    little, caching gains a lot ] ; PRIVATE = per-hop payload keystream
    keyed from that hop's header + per-hop integrity in the header
    [ tagging fails ] ; the 1K header carries all class differences, the
    63K keeps size + format either way
- user : these dedicated bits can also be the space for a stream
  FRAMING the packets are embedded into, like the 3+1 octal bit encoding
  of the signature header lines
  - buys resynchronisation [ join mid-stream \ lost bytes -> find the
    next boundary ; HDLC flags \ COBS idea ] and embedding into any
    carrier stream [ pluggable transports need not know packet bounds ]
  - condition : a FIXED sync pattern is a static fingerprint [ what
    automated blocking matches ] -> KEYED framing marks derived from the
    link key + epoch : only the link ends find the boundaries, outsiders
    see uniform entropy
  - the 1K header then carries : per-hop routing + entropy, the private
    class's per-hop payload key + integrity, keyed framing ; the 63K
    stays pure payload
  - user : like a base32 string wrapped to 77 chars adds one line end per
    77 chars of payload -> POSITIONAL framing [ known by counting, not
    searched for ] ; packets the same shape one scale up : one 1K slot
    per 63K payload [ 1:63 vs 1:77 ]
  - positional = no searchable marker anywhere in an established stream
    [ the best answer to fingerprinting ] ; the slot carries content
    [ header, check bits, entropy ] where a line end carries nothing ;
    resync after loss : the slot content verifies against the link key
    -> test candidate positions until one checks out, outsiders see no
    pattern. = positional framing every 64K + keyed verification in the
    slot, same principle at line scale and packet scale
- user : part of the vision since the 63K idea or before -- packets have
  a NETWORK PROPORTION : the larger part is payload, the smaller a
  network "backpack" payload -> the 1K is not overhead but a second
  payload owned by the network [ ties to "63K buffer swaps as base
  fallback workload" : the network maintains itself on its own traffic ]
  - backpack cargo : per-hop routing \ payload key \ integrity, keyed
    framing ; gossip [ node lists, entry-list updates, trust statements,
    revocations, ring rekey commits ] ; credit receipts [ osf-cache
    stage 5 ] ; discovery fingerprints \ rendezvous hints
  - no separate control traffic -> the control plane leaks no timing \
    volume ; maintenance scales with use [ ~1:63 share, idle links carry
    cover packets with backpacks ]
  - rules : HOP-SCOPED, replaced at every hop under that link's
    encryption [ unchanged backpacks would link a packet along its path ]
    ; the intelligent queue fills it [ urgent revocations first ]
  - user : the security advantage is the additional DYNAMIC ENTROPY,
    beyond plain re-encryption with a different key each hop. precise
    framing : against OUTSIDE observers a sound cipher with per-hop keys
    is already indistinguishable from random [ no gain there ] ; the real
    gains : relays see genuinely new content per hop [ no stable pattern
    to link by -- re-encryption alone gives none, relays see plaintext ] ;
    a leaked link key exposes only that hop's transient cargo ; and
    DEFENCE IN DEPTH against implementation mistakes -- the 2026-10-05
    link-upgrade key + nonce reuse [ [[project-2026-10-05-link-upgrade-nonce-reuse-fixed]] ]
    leaks the XOR of two plaintexts, easy to unpick for predictable
    protocol text, far less so for fresh unpredictable cargo. size +
    timing unaffected [ still mixing + cover traffic ]
  - user : splicing the bits with that entropy, like the keys zenka key
    archive storage, so that breaking C25519 or twofish alone is not
    enough to get the bitstream
  - archive as built [ `base.parser.splice_in_data`, used by
    `keys.write_key_archive_file` ] : payload at a random bit offset in
    an entropy block, the offset appended [ BER int ] to the SAME block,
    then the whole block encrypted with the password key -> hides size +
    position [ real value ], but whoever breaks the cipher reads the
    offset in plain view : not a second lock [ finding, not a bug ]
  - rule : a layer meant to survive another layer's break needs its OWN,
    independently obtained secret, never derived from the same key nor
    stored inside the same ciphertext ; layers from one key add work,
    not independence
    - vs breaking C25519 [ realistic future : quantum ] : HYBRID key
      exchange, X25519 + a post-quantum KEM [ ML-KEM ], combined [ TLS,
      Signal PQXDH ] -- a broken DH alone reveals every derived key
    - vs breaking twofish : a cascade with independent keys [ e.g.
      ChaCha20 over Twofish ] ; a splice keyed by a separate secret acts
      as a keyed transposition layer, pattern per packet via a PRF
    - the backpack's dynamic entropy sits on top : whatever leaks is
      less predictable
  - user : the splice would DEPEND ON THE ENTROPY -- an encryption of the
    payload with the entropy stream, BIT [ stream ] oriented, not on octets
    - bit orientation = stronger : no byte alignment, octet patterns
      [ known protocol text, field bounds, char frequencies ] do not
      survive ; byte-aligned known-plaintext attacks no longer fit
    - the crux : does the attacker know the driving entropy stream ?
      IN-BAND [ the carrier, same packet ] -> after breaking the outer
      cipher they re-run the selection rule = strong obfuscation, adds
      work not secrecy ; SECRET [ from an independently obtained secret :
      group secret, separate KEM, entropy delivered earlier elsewhere ]
      -> a real independent layer, approaching a bit-level one-time pad
      if never reused -> breaking C25519 or twofish leaves an unreadable
      bitstream
    - robustness : a fresh stream per packet [ PRF of the independent
      secret + the packet's per-hop entropy ; a reused pattern falls to
      one known plaintext ] + integrity over the whole output bitstream
      [ no probing the pattern by flipping bits ]
  - user : parts of the network would COMBINED know the entropy -- parts
    that themselves have no interest in attacking the payload stream, as
    to them it all looks the same
    - = secret sharing along the path : stream = s1 xor s2 xor .. xor sn,
      each share with a different node ; any n-1 learn NOTHING
      [ information-theoretic ] ; each node applies \ removes its share
      like an onion relay strips a layer
    - holds while not all [ or < k of n ] holders collude -- Tor's path
      assumption. "no interest" is an INCENTIVE argument, not a
      cryptographic one [ compromised \ coerced \ curious holders, an
      adversary running many nodes ] -> holders = distinct trust-chain
      identities [ the Sybil defence, a concrete reason the chain matters
      here ] ; diverse groups \ operators, not proximity ; unpredictable
      selection per packet ; optional k-of-n threshold for dropouts
    - the indifference is still a real bonus : holders see uniform data,
      nothing singles out a target -- incentive and crypto agree
  - user : they may have an interest, but cannot LOCK ONTO a target because
    of the cross-mapping ; even denial of service only triggers a regular
    alternate selection and downgrades the attacker -- whatever the attack
    form, it is efficiency-degrading
    - agreed core : unpredictable cross-mapping = no target ;
      efficiency-measured routing makes attacks self-limiting without
      recognising the attack TYPE
    - close deliberately :
      - SELECTIVE DoS [ Borisov et al. 2007, Tor ] : fail only paths not
        controlled by colluders -> reselection lands on a compromised
        path ; fix : path failure = evidence [ penalise involved nodes ],
        cap reselection rate, prefer stable long-lived entry choices
        [ guards ] over reshuffling
      - reputation gaming : build standing then strike, or whitewash with
        a fresh identity -- the trust chain blunts whitewashing [ new
        identity = new delegation, no standing ] ; standing decays,
        weighted to recent behaviour
      - slander : colluders rating honest nodes down -> efficiency rests
        mainly on each node's OWN measurements, others' reports
        trust-weighted, never decisive alone

- user : with distance the network has time to ensure the transported
  logic is the same ; even the last hop before completion can still drop
  what does not resolve -- refs : 'spatial and temporal
  compartmentalization' [ `data/yaml/reasoning-templates/categorical-compartmentalization.yaml`
  : bounded regions with controlled permeability ; temporal = "which
  transitions are evaluated before being committed" ]
  - transit distance = the evaluation window ; nothing commits until it
    resolves = osf-cache stage 3's local rule [ an unverified byte never
    reaches the cache dir ] lifted to the path ; pushed exploits are
    dropped before commitment, count only as transport workload
  - what a hop can verify = what it can see [ the permeable boundary ] :
    PUBLIC content-addressed -> every hop checks the 63K against its
    merkle leaf + agreed root, poison dropped at the FIRST honest hop ;
    PRIVATE [ per-hop re-encrypted ] -> relays verify backpack integrity,
    chain signatures, structure only ; content meaning at the endpoint ;
    framing + backpack + chain checked at every hop for everything
  - caution : WHERE a packet is dropped must not become an oracle
    [ probing paths \ verification points with malformed packets ] ->
    the slot keeps moving as a cover packet, the drop shows only in the
    dropping node's own efficiency accounting



## consumers that must move with it [ user ]

- users zenka : key management [ identities exist, keys do not ]
- `discover` : signature resolution of HOST packets [ host keys today
  are taken from the packet ]
- `nodes` : key + identity awareness, so it can trust any node list it
  builds REGARDLESS OF PROXIMITY
- link-upgrade \ p-7-r \ external.link.open : server proof
- osf-cache cross-host peers ride on all of the above [ content integrity
  is already end-to-end via merkle + anchor ; command integrity is not ]

related : [[project-cross-host-trust-bootstrap-gap]],
[[project-keys-zenka-integration-direction]],
[[users-zenka-unblocks-cross-host-testing]]

#,,,.,,,,,.,.,,..,.,,,,,,,,,,,,.,,...,,.,,...,..,,...,...,...,...,,..,...,..,,
#6DMZBKAUPMZJKVEH4Y7IEBQDMLHWY3ZL754XNQUEA5EQOO4KI5CJKLXCH5KOQSPA6KI5OTP7R6QWU
#\\\|EX4WTZKIMJUE6SVRWVZZOEER4J3RF46Q3EZGVPGD2NTY3L4Q7AV \ / AMOS7 \ YOURUM ::
#\[7]FMTVZGH6XJ3GN34VEFNXRYFLELRXBHOCEFAUQKVZXR5TYLJ67UBA 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
