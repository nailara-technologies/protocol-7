# work and private contexts : one person, several contexts, a clean split on leaving

status : brief, not dispatched [ owner 2026-11-21 ; an earlier discussion of encryption,
access models and the automatic split on leaving was not written down -- this restates
it ]. builds on data/md/design/PRIVACY-PRESERVING-IDENTITY-CREDENTIALS.md [ multiple
personas, unlinkable credentials ], N7FS-TREE-CATEGORIES.md [ layer private \ generic,
foreign-work ], N7FS-SEALED-REPLICAS.md [ holders ], token-lease-and-lan-media.md
[ groups, scopes ], input-and-window-forwarding.md [ presence, prepared sessions ].

## problem

- people mix contexts on the same devices and networks : private, work, sometimes
  several employers or projects, at home and at the workplace
- today the split is by habit and by app : work data ends up on private devices and
  the reverse ; leaving a job means sorting by hand, and both sides lose or keep
  more than they should
- an organisation needs its data back and gone from private devices ; the person
  needs their private data untouched and unread by the organisation

## principle : every item belongs to exactly one context from creation

- a context = its own persona [ unlinkable credentials ], its own keys, its own n7fs
  trees and holders, its own zenki or zenka instances
- the context is set when an item is created [ by the zenka, the desktop, the mail
  account, the tree ], never inferred later ; an item moves between contexts only by
  an explicit, logged act of its owner -- a copy into the other context, never a
  silent reclassification
- on a shared device both contexts run side by side, each with its own encrypted
  stores ; the window frame \ theme shows which context a window belongs to

## encryption and access

- each context has its own key hierarchy :
  - private : held by the person only [ home ring, vault ]
  - work : held by the organisation's key authority, delegated to the person for the
    duration of the employment [ a lease, renewable, revocable -- the token lease
    model one level up ]
- the mirror case on WORK machines [ owner 2026-11-21 ] : the private context there runs
  on private key instances made for that machine only -- delegated from the person's
  private key, used nowhere else, never the main key itself. the person revokes them
  the moment they leave [ or the machine is replaced ], and the private stores on
  that machine become unreadable at once ; nothing of the private hierarchy above
  them is exposed by the work machine, even if it is kept or inspected
- still an overlapping trust context : the organisation administers the work machine's
  system, so whatever is unlocked there while in use is within its reach in principle
  [ memory, input ]. revocation ends access afterwards, it cannot undo what was
  visible during use. so the private context on a work machine is minimal and
  short-lived by default : prepared-locked sessions [ input-and-window-forwarding.md ],
  forwarded windows from the person's own hosts instead of local copies, nothing
  private stored there that is not needed for that day ; the same holds in reverse
  for work data on private devices
- the organisation cannot read private context data on any device, the person's
  private zenki cannot read work data outside the work context
- holders per context : work trees replicate to the organisation's holders, private
  trees to the person's own ; no tree is placed on both
- presence and arrival notices [ input-and-window-forwarding.md ] cross from private
  to work only as the person chooses [ e.g. 'joining late' to a work meeting ], never
  the other way by default

## context-aware device policy [ owner 2026-11-21 ]

instead of mac address filters [ spoofable ] and blanket usb bans on driver level :

- network admission by context, not by device : a personal device joins the work
  network only in its work context, proven by the work context key [ an attested
  session ], never by a mac address ; its private context does not see the work
  network, and the work network does not see the private context
- usb and other storage is mounted INTO a context : a work stick opens in the work
  context only ; a private stick on a work machine opens in the private context's
  minimal sandbox, invisible to the work context's zenki [ within the limits of the
  overlapping trust context above ] ; an unknown device is offered, never auto-mounted
- data carriers can carry their context : an encrypted stick bound to a context key
  is readable only there ; copying between contexts is the explicit, logged act of
  the principle above, so a stick cannot become a silent bridge
- the policy is the organisation's for the work context and the person's for the
  private one -- each side decides about its own context only
- routing per context, not per device : each context of a device has its own route
  and encapsulation. work traffic from a private device at home is carried to the
  organisation's network inside the work context ; private traffic from a device on
  the organisation's premises is carried to the home ring inside the private context
  -- the network in between carries only padded, encrypted streams and sees neither
  content nor which context is busy. no vlan, no per-device vpn : the device stays
  one device, its contexts travel separately
- processing where the policy wants it : an organisation may decide that work data is
  processed only on its own powerful, sandboxed virtual machines -- the device shows
  forwarded windows [ input-and-window-forwarding.md part b ] and holds nothing.
  each vm gets mapped only what its task needs [ the trees, scopes and leases of that
  task, nothing else ], and the mapping is the audit trail. a lost or private device
  then carries no work data at all
- quarantine after upload : what a device uploads lands in an intake area mapped to no
  vm and no person yet [ the n7fs incoming pool model ]. the network decides there,
  after the upload has completed, what happens to it -- scan, release to the task's
  vm, hold, or reject -- before anything has gained access anywhere. a malicious or
  wrong upload is contained by default, not caught afterwards
- release checks in the intake : the decision can require signatures -- from a plain
  check that the uploader's context key signed it, up to delegation and permission
  trees [ HOST-ROOT-DELEGATION.md, TRUST-CHAIN-STEP2.md, the layered signatures of
  WEB-UI-USER-LOGIN.md ] : who may release which kind of data into which task, a
  second signature for sensitive kinds, sized delegations. an unsigned or
  insufficiently signed upload simply stays in quarantine
- full inflow provenance : every release is a signed record [ what, content address,
  from which device and context, who released it into which task \ vm, when ]. when an
  exploit is detected later, its content address leads back to every place the data
  went -- which vms, which derived files, which people -- and those can be isolated
  or rebuilt from before the release. content addressing [ n7fs ] makes the trace
  exact : the same bytes have the same address everywhere
- strip by input route : the provenance records also name the input route [ device,
  context, upload path, releasing delegation ]. once an attack vector is identified,
  everything that came in over the same route in the affected time window can be
  isolated or stripped at once -- including uploads not yet recognised as malicious
  -- without touching data from other routes. the route is the selector, not a
  signature of the exploit
- the one requirement for complete coverage : ALL input is signed at inflow, or it is
  not worked with at all. the intake signs what it accepts [ route, time, content
  address ] if the sender did not ; nothing reaches a vm, a task or a person without
  such a signature. then every byte in use has a provenance, and every route can be
  traced and stripped -- no unrecorded side door remains
- signed as checksum lists : one signature covers a list of content addresses per
  batch or time window [ like the signed n7fs tree manifests ], not one signature per
  item. checking is one signature plus fast address lookups [ BMW \ AMOS ], so signing
  everything stays cheap and quick even at high inflow
- rolling batches : the intake closes a batch at intervals [ <[base.interval.next]> ],
  signs its list and releases it while the next batch still fills -- earlier batches
  are usable at once, inflow never waits for the whole transfer. the interval trades
  latency against the number of signatures ; the rule stays the same : a batch is
  used only once its list is signed
- the batches are also a security boundary : interval \ idle signing cuts the inflow
  into closed, signed time windows. an attack is then bounded to the windows it
  touched -- they are isolated or stripped as a whole, every window before and after
  stays trusted and needs no review. smaller windows mean finer isolation ; an idle
  close [ no inflow for a while ] ends a window early, so a quiet period never joins
  a later attack window
- and the inverse : the idle close seals the work just done. an attack that uses the
  following silence [ when nobody is uploading and nobody watches ] lands in a new
  window of its own -- the sealed work before it stays intact and provably untouched,
  and anything in that silent window stands out by being there at all
- anomaly close, the complement of the idle close : usually harmless anomalies close
  the current window at once -- a new input channel becoming active, sudden
  unexpected errors in a component, an unusual peer, a route used for the first time.
  closing is cheap and harmless when the anomaly is benign ; when it is the start of
  an exploit, it seals the still unaffected state at the very moment of the attack,
  and the attack begins in a fresh window of its own. the trigger list is
  configurable ; a false alarm costs one extra signature, nothing more
- physical anomalies count too : movement in the room [ a motion sensor, the
  remote-cam zenka ], a door, a device plugged in, input at a desk while the user's
  presence is elsewhere [ input-and-window-forwarding.md ]. each closes the window
  like a digital anomaly. the sensor data itself stays on the local host -- only the
  'anomaly : close' event travels
- escalation levels per anomaly type, configurable :
  1. close the window [ every anomaly ]
  2. + notify the owner on the host that has their presence
  3. + lock the sessions on that host and unload the session keys from memory [ the
     approval ladder of WEB-UI-USER-LOGIN.md : unlocking again needs the passphrase ]
  4. + suspend the leases and delegations used from that host until the owner
     confirms, and alert the home ring
  e.g. 'human not recognised' [ recognition runs locally, nothing of the image
  leaves the host ] : level 2 while the user is present and nearby, level 4 when
  their presence is elsewhere

## leaving : the automatic split

- the split is a KEY operation, not a sorting job : because every item already belongs
  to one context, leaving means
  1. the organisation stops renewing the work context lease
  2. work context keys on the person's devices expire ; the work stores there become
     unreadable at once, then are wiped and the wipe confirmed back [ receipts ]
  3. the organisation keeps its data on its own holders, complete -- nothing needs to be
     collected from private devices
  4. the private context is untouched : nothing was ever readable to the organisation,
     nothing needs review
  5. on the work machines, the person revokes their per-machine private key instances
     -- the private stores there end the same way the work stores end on private
     devices : unreadable at once, then wiped. both directions are symmetric
- items the person co-created and may keep [ own notes, references, a portfolio part
  agreed in the contract ] are copied into the private context BEFORE leaving, as an
  explicit, logged release by the organisation -- the release list is the only place
  where the two sides negotiate
- a grace period with read-only access for handover, then expiry ; both sides see the
  same timeline

## stages

1. contexts as a first-class property : the context tag on items, trees and windows ;
   one device, two contexts side by side
2. per-context key hierarchy ; the work context as a delegated lease
3. per-context holders and placement
4. leaving : lease end, expiry, wipe with receipts, the release list
5. several work contexts at once [ two employers, projects ]

## rules

- fail closed : an item without a context is not stored, not synced
- p7 config style, no json ; BMW \ AMOS checksums, no sha ; perl floor 5.32
- no names of organisations, people or hosts in repo files

#,,..,,,,,.,,,,,,,...,.,.,,,,,.,.,.,.,...,...,..,,...,...,.,.,,.,,,.,,.,.,...,
#54P7FEIB7CEL7PQU3YJOH6WFWV3EHSSPWZMR4T3RO6SN2JOHCPIJST6LE7K4JLJ4PMC73V3D5LUAS
#\\\|XQVBJ6UFXH5TKS4LIU6X7YOVJ6OEW6AMIOUBABOPK4WAJ4PYEFE \ / AMOS7 \ YOURUM ::
#\[7]S452H72SUSLBG6YZXZKKSRJENSLQFRELEP6OCRLZNWEZVFWCWADQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
