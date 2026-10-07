---
name: project-2026-10-06-host-root-never-created-root-held-keys
description: FOUND 2026-10-06 : host-root [ 25a60f33b ] was NEVER created on any host -- crypt.C25519.post_init returns early when auto_load_keys is off and v7-zenki sets it 0 [ every start profile ]. v7-zenki runs as ROOT, cube as protocol-7. decided : root-held keys in `<backend key dir>/root/` [ root 0700 \ 0600, checked on every read ], host-root signs cube's S [ .dlg ], clients pin the host-root fingerprint ; 3 lanes dispatched
metadata:
  type: project
---

**finding** [ local zenka, DESKTOP-FP4OP26, after a v7-zenki restart ] :
no `host-root.*` anywhere in the protocol-7 key dir [ `p7-keys list` :
only `self`, `protocol-7.base`, `remote-fetch-client` ]. cause :
`cfg/zenki/v7-zenki/zenka.v7:11` `crypt.C25519.auto_load_keys = 0` ->
`crypt.C25519.post_init` returns before its host-root block. remote
servers only differ by start profile [ `start-set-up.remote-server` vs
`base` ] -> same result expected there ; atom unverified. the keygen test
lane drove post_init with autoload ON, so it could not catch it.

**decided with the user** [ `data/md/design/HOST-ROOT-DELEGATION.md`
"decisions" ] :
- root-held keys live in the BACKEND user's tree, `user-keys/root/`
  [ user's idea -- not root's home ] ; root 0700 dir, 0600 files,
  checked on EVERY read ; protocol-7 can only rename \ delete [ DoS, never
  a swap -- it cannot create root-owned files ]
- one resolver `crypt.C25519.key_path` ; location = marker
- host-root signs cube's S -> `<S name>.dlg` [ 30 d, renew < 7 d ] ; 4th
  select field ; pins = host-root fingerprint [ bmw384 B32, 77 chars ],
  keyed `<host>_<port>` ; host = `<system.hostname>` lc
- reason to land BEFORE the binding live check : nobody has pinned S yet

lanes : `data/tasks/host-root-delegation-{perl,keys,c}.md`.
related : [[project-2026-10-06-auth-keypair-replayable]],
[[vision-2026-10-05-generic-trust-chain]]

**next consumers** [ user asked 2026-10-06 -- not yet in any spec ] :
- discover : `discover.format_discover_mcast_packet` signs with
  `<discover.crypt.key_name>` and ships its OWN pubkey + old `.sig.*`
  attachments [ sign_keys : Ed25519 over a bare pubkey, no label \ name \
  expiry ] ; `discover.process_host_packet` takes `hostkey` from the
  packet [ self-certifying, only compared with earlier claims ] -> carry
  the `.dlg` statement instead, receivers `trust.verify` against pinned
  host-root fingerprints ; discover may OFFER fingerprints, never trust
- nodes : no key \ trust handling yet [ only `nodes.parser.node_pkey`
  display ] -> key hosts by verified host-root fingerprint + name
- then retire `crypt.C25519.sign_keys` \ `.sig.*` [ raw-pubkey sig shape ]
- add a "next consumers" section to HOST-ROOT-DELEGATION.md after lane 1
- 2026-10-07 : discover lane DISPATCHED to a web session [ task
  `data/tasks/discover-host-root-delegation.md`, commit b7ffad700, branch
  `discover-host-root-delegation` ] -- review the branch + sign locally
- landed : 1adb45b02 + e3c3ee371 [ node name, not_before -300 s ] ; NOT
  live-checked yet [ v7-zenki restart -> root/host-root.*, protocol-7.base.dlg ]

#,,,,,.,,,,,.,,.,,,,,,,.,,,..,...,,,.,,..,.,,,..,,...,...,,..,,,,,.,.,...,.,.,
#GPGACX5DYK3Q6O5D5A6XLAGDBIDROALTIO757KIKSQVRDSVOQ2Z5O6O5Y6OIH6EEJDGOWLPU6T6OY
#\\\|23MJNAM5LDCWSORF66NMMNXSU7ZK7F6BC23CRAX2OM7MN52XWR2 \ / AMOS7 \ YOURUM ::
#\[7]WQ5SOVU7EPJHQACVJCYPM5OP6R3MNDOR7563QSUMN2SFII4AB4DQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::

**2026-10-07 discover MERGED** [ squashed onto base with the parked e2e
test 916a35658 ; web session 435ff591b + review 05e79435b ] :
- review fixed a BLOCKER : discover's modules.load lacked `trust` [ the
  test compiles modules directly, could not see it -- the same class as
  auth.binding missing in external \ users : CHECK modules.load NAMESPACES
  whenever a lane adds calls into a new namespace ]
- host-root change DROPS the packet ; both drop paths log with an
  adaptive level per sender key [ 0, then 1 2 3 capped, reset on accept ]
- suites on base : discover 33, e2e 54, delegation 186, binding 155,
  keys 121
- still open : LIVE CHECK after a v7-zenki restart [ root/host-root.*,
  protocol-7.base.dlg, fingerprint cmd 77 chars, external.self re-pins,
  discover hosts show trust ] ; follow-ups : nodes trust transitions only
  on re-appearance, orphaned %signatures modules, crypt.C25519.sign_keys
  still used by keys.console.sign-key ; delete branches
  `discover-host-root-delegation` + `parked/e2e-binding-test` [ local + hub ]

#,,..,,,.,.,.,.,.,,,.,,.,,.,.,.,,,.,,,,..,...,..,,...,...,,,,,..,,...,,.,,,,,,
#BGDUGE3W5MSJU6H5LPO5AHA44U4QBRUYDHJSTT2ZAXZUPBLRGRKHPHCNVOIEKMGBQLZNFB2MTHU3A
#\\\|USSZCMA3PZMFIORCDDYN2DNMR5EDUYW76UJUHBX4VI3XUHYFBXR \ / AMOS7 \ YOURUM ::
#\[7]STLDK2C6GTXR7IOIFPYFBHVORWI5GN3VBTOL6N2IVSMSN5ZRGEDY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
