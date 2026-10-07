# discover : HOST packets carry the delegation CHAIN [ trust chain step 2 ]

**base : the commit that lands `trust.chain` \ `trust.pin_decide`** [ ask
for the hash ]. no running backend needed : implement against the code +
spec, test with stubs [ extend `bin/test-scripts/test-discover-delegation.pl` ].

## context [ read first ]

- `data/md/design/TRUST-CHAIN-STEP2.md` -- sections 'wire', 'pins',
  'verifier changes'. the `.dlg` file now holds a CHAIN : one b32
  statement per line, LEAF FIRST ; on the wire the statements are joined
  with `.`, leaf first
- `src/trust.chain` -- THE parser : `split` [ field -> wires anchor-most
  first ], `join` [ anchor-most-first wires -> field ], `file` [ .dlg
  content -> wires anchor-most first ]. NEVER split \ reverse by hand
- `src/trust.pin_decide` + `src/auth.client.owner_pins` +
  `src/auth.client.distrust_list` -- how the client decides ; discover
  must reach the SAME trust verdicts [ never writes a pin ]
- `src/auth.auth_select` [ the 'the leaf decides' block ] -- the server
  side rule to mirror when SENDING
- CLAUDE.md [ module format, `<a.b>` \ `<[x.y]>` syntax, style ]

## today [ step 1 ]

- `src/discover.format_discover_mcast_packet` reads line 1 of the
  `.dlg` only [ the leaf ] -> `   dlg:<wire>`
- `src/discover.handler.incoming_packet` + `src/discover.process_incoming_packet`
  : the `dlg:` field regex is `[A-Z2-7]{1,2048}` [ no `.` ]
- `src/discover.process_host_packet` : one statement, verified under its
  own issuer ; trust = `pinned` [ issuer fp in `discover.read_host_root_pins`
  ] \ `offered` \ `unverified` \ `invalid` ; a CHANGED root fp drops the
  packet and marks the host invalid

## do

1. **send** [ format_discover_mcast_packet ] : read the whole `.dlg`
   [ cap 2060 bytes, refuse > 2052 ], `trust.chain` `file`. verify the
   LEAF under its own issuer [ `trust.verify`, subject = the host key's
   public ] -- failing : no `dlg:` field [ as today ]. then the whole
   chain under its top issuer : valid -> `dlg:` = `trust.chain` `join`
   of the whole chain ; else the leaf alone + ONE level 0 line per change
   [ keep the existing `<discover.dlg.last_state>` pattern ]
2. **receive** [ incoming_packet + process_incoming_packet regexes ] :
   `dlg:[A-Z2-7.]{1,2048}` ; the field is handed on as the raw string
3. **verify** [ process_host_packet ] : `trust.chain` `split` [ refused
   -> drop reason ] ; verify under the LEAF's issuer fp [ + distrust from
   `auth.client.distrust_list` on `<usr_home>/.n/remote-keys` ; distrust
   unreadable -> drop, fail closed ]. `root_fp` stays the LEAF's issuer
   fingerprint [ the host-root ]
4. **trust states** : `pinned` [ host-root fp in the host pins ] ;
   NEW `owner` [ not pinned, but `trust.verify` with anchors = the owner
   pins accepts the chain AND its anchor is an owner pin ] ; `offered` ;
   `unverified` ; `invalid`. `pinned` wins over `owner`
5. **root change** : today a changed root fp drops the packet. NEW : a
   change is ADOPTED [ level 0 line, entry updated, nodes notified ] only
   when the new chain is `owner`-trusted, the delegated name is the SAME
   as before, and the not_before of the statement certifying the new
   host-root [ `$chain->[-2]` when the owner-verified depth >= 2, else
   the leaf ] is strictly LATER than the one stored for the previous root
   [ store it as `since` in `$data{'discover.host-root'}->{..}`, 0 when
   never owner-verified ] -- the same forward-only rule as
   `trust.pin_decide`. anything else : drop + invalid, as today
6. `discover.cmd.host_details` shows `owner` + the owner fingerprint
   [ two halves at the level the root fp uses ]

## tests [ test-discover-delegation.pl, stubs only ]

- a two-statement chain field [ owner seed 06 -> host-root, host-root ->
  S ] parses, verifies, trust `owner` with an owner pin, `offered`
  without, `pinned` with the host pin
- reversed field [ owner first ] -> dropped
- `..` \ leading \ trailing `.` \ 5 statements -> dropped
- distrusted host-root -> dropped ; malformed distrust file -> dropped
- root change : owner-covered + same name + later since -> adopted ;
  equal since -> dropped ; other name -> dropped ; no owner pin -> dropped
- send side : expired owner statement on disk -> `dlg:` carries the leaf
  alone [ no `.` ]
- `compile_module` every new module the test touches [ trust.chain,
  trust.pin_decide is NOT needed, auth.client.owner_pins,
  auth.client.distrust_list ]

## rules

- run `bin/format-code -c <every touched src file>` -- NEVER plain
  `perl -c` ; run the test yourself, paste the final `passed :` line
- touch ONLY the files named here + the test ; check `git status` before
  you finish -- no whitelist \ load-early regeneration of other zenki
- `qw| a b |` is a LIST : never use it as a scalar ; `<word>` needs a dot
- new test packages : `use English`
- do NOT commit ; write `data/tasks/discover-trust-chain.report.md`
  [ what changed per file, test output, open questions ]

#,,,.,.,.,,..,,..,,.,,,.,,,,.,.,.,,..,,..,..,,..,,...,...,,..,,,,,,..,..,,,..,
#P7HDVV7O5MSGJLAJGVAAWAUFRLDZFDAPQQKOQQ72NAAFV3M23W5TJFHUUMRHDPW7K4EEU4ZVGB7V2
#\\\|J4Z32ZISZWE5S4ID67EYPVXYFTNH2DPTNCB7ZH5KZZXYBB67M52 \ / AMOS7 \ YOURUM ::
#\[7]SYCJ5RFH52NID7RR5K7Y4WZFM2BRNRIVPOULODYQIENR5GNVIGDI 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
