# discover : host packets carry the host-root delegation [ web session ]

**base commit : `e3c3ee371`** [ pushed ]. this task needs NO running
backend : implement against the code + spec, test with stubs only.

## context [ read first ]

- `data/md/design/HOST-ROOT-DELEGATION.md` -- host-root signs the
  backend key S -> `<S>.dlg` [ wire b32, one line ] ; `trust.statement`,
  `trust.verify`, `trust.fingerprint` [ section "modules [ Perl ]" ] ;
  "acceptance rules" ; "test vector"
- `data/ai-mem/claude/project-2026-10-06-host-root-never-created-root-held-keys.md`
  section "next consumers"
- `data/ai-mem/claude/vision-2026-10-05-generic-trust-chain.md` : "a HOST
  packet announcing its own root is self-certifying -> discover may OFFER
  fingerprints, trust comes only from a pinned or owner-signed root"
- CLAUDE.md [ module format, `<a.b>` \ `<[x.y]>` syntax, style ]

## today

- `src/discover.init_code` : `<discover.crypt.key_name>` = the default
  `crypt.C25519.key_vars` key = the backend user's `<user>.base` = the
  SAME S cube announces and host-root delegates
- `src/discover.format_discover_mcast_packet` : signs the packet with S,
  ships S's own pubkey + optional `.sig.*` lines [ old
  `crypt.C25519.sign_keys` format : Ed25519 over a bare pubkey, no label
  \ name \ expiry ]
- `src/discover.process_host_packet` : takes `hostkey` from the packet,
  only compares it with what earlier packets claimed [ self-certifying ]

## change

sender :
- add the host's `.dlg` [ `crypt.C25519.delegation_file` -> read, one
  line, <= 2048 chars ] to the packet as a new signed field, covered by
  the packet signature ; DROP the `.sig.*` lines [ no compatibility ]
- no `.dlg` readable -> send without it, level 1 log once per change

receiver [ `discover.process_incoming_packet` \ `process_host_packet` ] :
- parse + `trust.verify` the delegation with the packet's hostkey as the
  subject [ the existing packet signature check still runs first ]
- store on the host entry : `root_fp` [ 77 chars ], `delegated_name`,
  `trust` = `pinned` | `offered` | `unverified` | `invalid`
  - `pinned` : `root_fp` equals the content of ANY pin file in
    `<home>/.n/remote-keys/servers/*.public` [ the client pin store ;
    read-only here -- discover NEVER writes a pin ]
  - `offered` : delegation valid, root not pinned
  - `unverified` : no delegation field
  - `invalid` : field present but fails parse \ verify -> also DROP the
    packet [ level 0 log ] -- a broken claim is worse than none
- a host whose `root_fp` CHANGES between packets : keep the old entry,
  log level 0 `host-root changed for <host>`, mark `trust` = `invalid`
  until it is re-pinned out of band
- `discover.cmd.host_details` shows `root_fp`, `delegated_name`, `trust`

nodes :
- the route to `nodes` [ see discover.init_code "target route to
  'nodes' zenka" ] passes `root_fp` + `trust` along ; nodes stores them
  per node entry and shows them -- no trust decisions in nodes yet

retire :
- `crypt.C25519.sign_keys` + every `.sig.*` reader that only served
  discover [ grep `sig\.` \ `spk` \ `sign_keys` ; `crypt.C25519.post_init`
  loads `.spk` \ `.sig` files -- remove if nothing else uses them, else
  list the remaining users in the report and leave them ]

## rules

- touch only `src/discover.*`, `src/nodes.*`, the retired `crypt.C25519.*`
  sig code, `cfg/zenki/{discover,nodes}/` + load lists for any NEW module,
  and new tests
- fail closed ; exact parsing ; `$ARG` not `$_` ; lowercase comments,
  `[ ]` not `( )`, 78 columns ; syntax via `bin/format-code -c <files>`,
  then `bin/format-code` on every touched file
- do NOT sign files [ the user signs locally ] ; commit on a branch
  `discover-host-root-delegation` and push the branch -- never to `base`

## tests

NEW `bin/test-scripts/test-discover-delegation.pl` [ harness :
`bin/test-scripts/test-host-root-delegation.pl` ] : packet with a valid
`.dlg` round-trips [ build -> parse -> verify ] ; each trust state ;
pinned detection from a tempdir pin store ; invalid -> dropped ;
root_fp change -> invalid + logged ; `.sig.*` lines gone from the
packet ; host_details output. use the spec's test vector keys.

## report

`data/tasks/discover-host-root-delegation.report.md` : files changed,
what was retired \ kept + why, test output, open questions.

#,,.,,,.,,.,,,,,.,.,.,,.,,,.,,,.,,..,,,..,,,.,..,,...,...,,.,,,,,,,..,...,,,.,
#TFZQPMFSJJ2L7OMLRMAA3B3WPOHVBJCH3QHZO3TG4GCMB4ILKXFM5NR4LNNSWV4OFJLAFCXLTFZA6
#\\\|C3XNBPHT6JGYHCW2MDD3IRZ35VMGLAOEEQXV34EUTDPEJCVHKBM \ / AMOS7 \ YOURUM ::
#\[7]YH3TVMVLLT7IJ5W5AX2DNUMI3RAIOMOAVSK4FKEAL4GTSM5A5WBY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
