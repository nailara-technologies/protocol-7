# host memory : a signed, add-only history from the installation on

status : brief [ owner 2026-11-23 ] -- not dispatched. ties into data/tasks/host-build.md
[ stage 2 creates the host-root ], the host-root delegation [ cube .dlg ], nodes \ discover
[ peers remember heads ], n7fs sealed replicas [ storage ].

## why

a host should have a memory that starts with its installation and that nobody on the host can
quietly rewrite or remove : what happened, which keys and pins it got, which security states
it went through, which networks it saw. its absence or a rollback is a forensic security
alert. a host at the lowest security level still has a readable, verifiable memory.

## identities

- the host has an identity [ host-root ] ; zenki and llm zenki are sub-identities with their
  own keys, delegated from host-root [ like cube's .dlg ]
- every identity has its own memory ; the host memory records the first line of a
  sub-identity's memory at delegation, and its head from time to time [ anchors ]
- every entry is signed by the identity that wrote it -- attribution : 'the coding llm zenka
  on host X, delegated on day Y'
- a reinstall on the same hardware is an entry in the identity's memory, the memory goes on

## identity strands and hardware strands [ owner ]

some memory belongs to the identity, some to the hardware it runs on [ a disk's history, its
smart state, a board's firmware, a nic's mac, what was installed where ]. so a memory is made
of strands :

- the identity strand : keys, delegations, decisions, security states, the context
- a hardware strand per device : its own first line [ ntime, a key made for that device, the
  hardware fingerprint : serials, macs ], its own chain
- while they belong together, the identity strand records the hardware strand's first line and
  anchors its head ; the hardware strand names the identity it serves

moving apart :

- detach : a handover entry in both strands, signed by both sides, with the checksums of the
  hardware strand up to that point
- the identity moves on with its context to other [ better ] hardware ; it keeps the anchors
  of the old hardware strand [ provable history, not the device ]
- the hardware stays with its strand and is inherited by a new identity [ a fresh install, the
  data disk role ] : the new identity's genesis names the inherited strand and its last
  checksum -- the device's history goes on, under a new owner
- either side may also keep a copy of the other's part up to the handover [ by policy ] ; what
  was shared stays verifiable on both sides through the common checksums
- example : the W520 identity moves to the larger disk, the Intel disk's strand is inherited
  by the X220T data-disk role

## secure reference bundle [ owner ]

the strands of one host [ identity, hardware, zenki, security contexts ] form a bundle that
protects itself :

- each member signs, from its own level, the relative presence of the others : 'at <ntime>,
  seen from here : strands A C D [ with checksums where my level may see them ]'
- absence is noticed from inside : a missing or swapped disk, nic, zenka or context shows in
  the next presence signatures -- no outside peer needed [ peers still hold the receipts ]
- each level vouches only for what it can see : a low level signs presence, a higher level
  also the checksums -- nobody signs or learns more than its level allows [ inward rule ]
- relative, not absolute : 'together with, seen from here' ; the bundle's integrity is the web
  of these statements, no central authority [ the rhizome ]
- a planned detach is signed by both sides and the others record 'left, with handover' ; an
  unannounced disappearance is 'missing' -- a disk swap and a theft look different
- projected to hardware : measured boot [ extend-only registers per stage ], keys sealed to the
  measured state [ the next level's key does not come out if a lower one changed ], a device
  key [ tpm, secure element, self-encrypting disk ] as a hardware strand's own first line --
  used where present, never required ; the software form works without

## the first line

  <ntime> <sign key, b32> [ <seal key, b32> ] [ <signature> ]

- always plain, also when the body is encrypted : the file stays identifiable and verifiable
  without being readable
- sign key : verifies every entry of a signed memory
- seal key : entries are encrypted to it [ x25519 sealed boxes ] -- anyone holding the file can
  add, only the secret key holder can read
- the optional signature : the installer's or a higher level's countersignature [ a memory
  made without a witness still works, it just has none ]
- the private halves never live in the file : root-held or delegated [ user-keys/root/ ], the
  content readers' keys away from the host where the set-up wants that

## two versions [ owner ]

1. recent memory : encrypted, add-only [ seal mode ]. every level writes into it, sealed to the
   key of the level above. the low level cannot read back or remove what it wrote -- also an
   attacker on the host cannot
2. history : plain, signed, read-only [ sign mode ]. the next security level up decrypts the
   recent entries, reviews them and publishes them signed. the host reads this version, every
   level verifies it, nobody below changes it

the link : each publication names the checksum of the encrypted chain it covers and how many
entries it took in. withheld or redacted entries show as a count -- the upper level decides
what is published, and that decision is itself on record. the tail since the last publication
exists only encrypted, safe from a host compromised in between.

it nests : a zenka's memory is published by the host level, the host's by the owner level.

## chain

- every entry carries the checksum of the one before [ BMW, as the n7fs journal ] ; never sha
- entry : ntime, writer key id, kind, body [ plain or sealed ], previous checksum, signature
- kinds : install [ genesis : installer, disk serials, macs, layout ], key \ delegation \ pin,
  security level change, policy decision [ dns policies, roles ], network fingerprint seen,
  incident, hardware change, sync receipt, publication checkpoint

## sync receipts [ owner ]

a network sync signs '<ntime> <peer key id> <chain checksum> <entry count>' : on this peer, at
this time, a copy exists from which the memory is re-creatable up to here -- whatever form it
is stored in [ the peer signs the checksum of the form it holds, encrypted or plain ; the
publication link ties both forms together ]. the receipts go back into the memory as entries :
'where can i restore from' has an answer.

## absence and rollback alert

- the first line of each version is pinned elsewhere : the installer keeps it [ like the 77-char
  host pins ], peers learn it through discover \ nodes
- peers remember the last head and the last publication checkpoint they saw per host
- alert on : memory missing, a different first line, a shorter chain, a checkpoint older than
  one already seen -- raised by the peer \ the installer, so the host itself cannot suppress it

## security levels

- writing : delegated identities at their level [ seal mode lets low levels write without
  reading ] ; publishing the history : the level above
- reading : the plain history at every level ; the recent encrypted part only with the seal
  secret
- verifying : every level, with the first line alone
- a minimal host may carry only a seal key ; an installed server both

## full adoption : plain traffic as awareness [ owner ]

it is about awareness first. once two hosts share an authenticated protocol-7 session, their
awareness of each other lives in it ; plain network activity between them becomes the
exception, and the exception is a signal :

- vouched : the originating host announces legitimate plain activity over the session [ ntime,
  network fingerprint, flow, purpose, signed by the sub-identity that caused it ] -- 'the wol
  packet at X is ours'
- unvouched : the receiving side asks the origin's forensics side over the session 'did you send
  this ?' ; 'not me' or no record means something on the origin acts outside protocol-7 -- the
  origin considers itself alerted from then on
- safeguards : questions only over the session, rate-limited, summarised [ never amplifiable ] ;
  only between fully adopted hosts [ foreign networks and other hosts : observe only ] ; an
  unclear origin [ nat, shared address ] is recorded as unattributable, not escalated ;
  discovery and handshaking back in stay allowed

### awareness levels

  record  visualize  dev-realtime-report  admin-event  security-review  security-alert
  forensics-alert  forensics-review  forensics-report

- record : written, nothing shown -- the quiet case, where most events land
- observe [ visualize, dev-realtime-report ] -> operate [ admin-event, security-review ] ->
  incident [ security-alert, forensics-alert, forensics-review, forensics-report ]
- an event ENTERS at a level by its kind [ late vouch : admin-event ; 'not me' : forensics-
  alert ; memory rollback seen by a peer : forensics-alert ] ; a review moves it up or closes
  it as explained -- not a strict chain
- each level fixes recipients and channel [ live view, notify zenka, the owner on another host ]
- who may see a level mirrors who may read that part of the memory ; forensics-report is a
  signed history entry [ mode A ]

### sealed until known, dropped when cleared [ owner ]

before anything is known, an observation is encrypted already -- so a cleared one can be dropped
without leaving traces that go beyond security into profiling or surveillance :

- observations go into a sealed pending buffer, NOT into the add-only chain : sealed to a
  short-lived key held by the reviewing level
- cleared [ vouched, explained, closed by a review ] : the entry is dropped and, per window, the
  pending key destroyed -- crypto-shredding : copies of the buffer become unreadable too
- the chain keeps at most an aggregate where policy wants one [ '<n> observations cleared in
  window <ntime range>' ] -- no flows, no addresses, no names
- only what escalates [ security-alert and up ] is promoted into the memory, with what the
  investigation needs
- the visualize \ dev-realtime levels show live and keep nothing
- builds on the p7-log anon mode [ src/p7-log.anon.* ] : classified spans [ addresses, names ]
  become keyed [L:<bmw-l13>] tokens, the plaintext goes twofish-encrypted into a table, an
  archived key is retired by rekey-anon-table. what it needs for this model :
  - today the same address gives the same token for as long as the key lives, so token lines
    can be linked over weeks without decrypting anything -- profiling by structure
  - unlinking [ owner : epoch based entropy ] : the window id joins the token input,
    bmw-l13( token key : window : fragment ), the window id taken from the network epoch at a
    chosen precision [ the fractional epoch-num, e.g. its first digits = a window ] -- tokens
    link inside a window, never across windows, no new key needed
  - the resolution is adjustable per purpose [ owner ] : every 'profile' is cut into buckets
    of that size -- the 28 day epoch at 0 digits, ~2.8 days at 1, ~6.7 h at 2, ~40 min at 3.
    debugging \\ incident work wants a bucket long enough to follow one session ; privacy
    wants it short. an incident that spans buckets is followed through promoted [ decrypted ]
    entries, never by re-linking tokens
  - the more legitimate the use appears, the shorter the bucket [ owner ] ; scanners and
    probing sources can be followed over days. nothing is fixed : a line is written at the
    resolution its source has NOW, and continued use moves over to another level -- the old
    level is simply no longer used for it, its buckets run out and their keys drop as usual :
    - an unknown source starts with the SHORT bucket
    - growing trust moves a source to even shorter buckets \\ statistics only
    - a source classified as scanning \\ probing [ security-review and up ] gets a watch entry :
      its entries are promoted and from then on recorded under a long-lived watch token,
      held by the reviewing level -- the linking over days happens there, on purpose and on
      record, never by lengthening the buckets of everyone
    - the watch ends with a review [ closed : its data follows the normal drop rules ]
    - the approach path [ owner ] : without more, a move is unrecorded and an attacker's
      reconnaissance before the first trigger is dropped with its buckets. so :
      - a lookback horizon : a bucket's key is dropped some buckets AFTER it closes, not at
        once [ policy, e.g. a day ] ; cleared data lives that much longer, sealed only
      - when a trigger fires, the reviewing level reaches back : with the now known fragment
        [ the source address ] it re-derives that source's token for each bucket still inside
        the horizon, decrypts only those entries and promotes them -- the approach path is
        recovered for THIS source, nobody else's lines are opened or linked
      - every move of a source between levels is itself recorded [ sealed, old and new token ]
        so its own history stays correlatable across the move
      - per-bucket statistics [ codes, route classes, rates ] stay after the drop and can feed
        triggers that look for slow scans below the per-bucket threshold

### an in-memory correlation zenka [ owner ]

- gathers statistics and correlates at full resolution, in RAM only, longer than the disk
  horizon -- it can hand more and older data to an incident than the sealed buffer still has
- exports only into an incident [ security-alert and up, promoted under the reviewing level's
  key ] ; never writes its full-resolution state to disk
- it agrees to export only to an incident it can CONFIRM from its own data, or one it found
  itself [ owner ] -- a request naming an incident is not enough : it checks the claimed
  source \\ pattern against what it holds and answers 'not confirmed' otherwise [ recorded ].
  so a compromised requester, or a made-up incident, cannot use it to pull full-resolution
  data about ordinary users
- the export is scoped to what the confirmation covers [ that source, that pattern, that time ]
- rules are known to both sides and bound to the data [ owner ] :
  - the rule set [ what is gathered, buckets, horizons, triggers, export conditions ] is a
    signed, versioned document ; its checksum is named in every request and every answer --
    a request under a different rule set is refused
  - data carries the checksum of the rule set it was gathered under ; a new rule set applies
    only to data gathered after it. never retroactively : stricter rules cannot re-open what
    looser rules dropped, looser rules cannot widen what was gathered under stricter ones
  - loading a new rule set is treated like a code change : the full-resolution state is
    wiped first, the change is a memory entry [ old and new checksum ]
- strict about destroying that state : on any source code change it would load [ reload
  source \\ plugins, a deferred compile of a changed module, a restart ] and before the devmod
  module [ base.devmod.* : dump_var, param dumps ] is enabled in it -- new or debugging code
  must never see what the old code gathered. wiped first, then loaded ; the wipe is a memory
  entry [ 'state destroyed : code change <version>' ]
- the process itself : not dumpable [ no core dumps, ptrace refused ], memory locked against
  swap, no shm segments for this state
- what survives a wipe is only what already left as statistics or promoted entries
    - classifying is a decision with a reason in the memory, so it cannot quietly become
      tracking of ordinary users
  - shredding needs more than that : a window id is public, so the token key holder could
    still re-derive tokens and decrypt -- the table entries of a window are encrypted under a
    RANDOM per-window key [ not derived from a master ], and dropping it is what shreds
  - promoted entries are re-encrypted under the reviewing level's key first [ the rekey path
    already does this for a whole table ]
- data minimisation is part of the security model : a memory that profiles its users is itself
  a risk

### the same on the servers : http[s]d requests [ owner ]

- every request is sealed into the pending buffer as it arrives [ method, path, headers,
  timing, the reply and its code ]
- a request that caused unexpected behaviour [ a 5xx, an exception, a timeout, a rate-limit or
  signature refusal, a template error, an outlier in timing ] is KEPT : promoted for forensic
  review and debugging, with what is needed to reproduce it
- everything else becomes a statistic only when its window closes [ counts per route \ code \
  timing band ] and its sealed entries are shredded -- no access log of visitors kept by default
- the entry level follows the kind : a template error -> dev-realtime-report \ admin-event, a
  refused signature or probing pattern -> security-review, a repeated exploit pattern ->
  security-alert

## p7-host-build

- stage 2 writes the genesis : the first line [ host-root sign key, a seal key for the owner
  level ], countersigned by the installer, the install entry, and the installer keeps the pin
- the report names the memory's first line key id next to the host-root pin

## lineage [ owner ]

the same structure as the deduplicating knowledge tree and the substrate's identity tree :

- data/asc/what-AI-thinks/perl-form/knowledge-management/deduplicating-knowledge-tree.pl
  [ trunks, branches, needles, cones = seeds that regenerate branches, redundant recovery
  paths ], dynamic-tree-balancing.pl, holographic-systems/advanced-reconstruction-algorithms.pl,
  data/md/protocol-7-knowledge/README.md -- knowledge surviving damage ; this brief adds who
  may see which part and signed edges
- data/md/design/SUBSTRATE-SYNTHESIS.md : two views over the same nodes -- the identity tree
  [ timeless, rooted at the empty parent : lineage, version history, attribution ] and the
  occupancy view [ dated, rooted at the epoch : who holds now, which references are alive ]
- here : the identity strand and the chain are the identity tree ; presence signatures, sync
  receipts and epoch buckets are the occupancy view. a hardware strand inherited by a new
  identity changes occupancy, its identity [ content part, chain ] stays
- one substrate : n7fs nodes as needles, references as edges, receipts and presence
  signatures as the security layer -- a knowledge paragraph and a memory entry are the same
  kind of node, deduplicated, signed, with a position

## open

- storage : a sealed n7fs replica, so it survives a reinstall ; the local file under the
  root-held tree
- publication rhythm [ base.interval.next ] and who triggers it when the owner level is offline
- size : rotation by checkpoint [ a publication can start a new file whose first line names the
  previous chain's checksum ]

#,,,.,..,,.,.,,,,,..,,.,.,,,,,,..,,.,,.,,,...,..,,...,...,...,,.,,,.,,.,,,.,.,
#IKKDCCWBNOADR5VQNOACUH7PXKMISBQBC5AO5CJT6DO73T5U3LLWPSN2WZI7RCUJDOBV5L5BMIPL6
#\\\|4C2YKW67W6MVAGZOKQKVTS7CUEASEIKTTO27MUNVSESDGFDM5QL \ / AMOS7 \ YOURUM ::
#\[7]O7HAKRGQYWGFIMVUDEPPLJVNQTJR25VYFEJEYJN53SSIM7WYZ4AA 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
