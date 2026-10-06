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

#,,.,,,..,.,.,,.,,,.,,..,,,..,.,,,,..,...,,..,..,,...,..,,.,,,,,.,,.,,,..,,,.,
#36EDENUDUG2I3A24B7KGE2P57XKCA2FEUKGNAPI4TYIUKT6YWNBZJPZ336STU5H5HLYHKT5F5UWGU
#\\\|CUR6BK3WXA7NPE3C74F42I3IVJDFAONTIZDLJNDNAUFRVNJNIJA \ / AMOS7 \ YOURUM ::
#\[7]MLJTOB24UA77AHKEBG77MHVDJUZCGOUT4V3L7E6SI2EOPGG3WMCA 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
