---
name: project-2026-10-08-session-handover-host-setup
description: handover of the 2026-10-07 -> 08 session [ last 4bfbbb717, pushed up to b7f30c4e5 ] -- trust chain step 2 complete + live, key id rename, key trash \ undo-remove, host-edit zenka with the full add-host flow [ ssh forward -> probe -> pin -> certify -> install ] ; next = the first REAL add-host run [ the fanless backup host ]
metadata:
  type: project
---

previous : [[project-2026-10-08-trust-chain-step2-landed]] [ detail of the
step 2 part ] and [[project-2026-10-07-session-handover-trust-chain-step1]].
designs : `data/md/design/TRUST-CHAIN-STEP2.md`, `data/md/design/HOST-SETUP.md`.

## landed [ base ]

- trust chain step 2 : chains on the wire, name-bound host pins, forward
  only rotation, distrust, owner tools, discover owner trust -- LIVE
  [ throwaway owner key run, backed out ]
- the 77 char bmw384 value is the KEY ID [ trust.key_id, `p7c
  host-root-id` ] ; `p7c host-root-dlg` = the public delegation chain
- key trash : `p7-keys undo-remove` \ `removed [purge ::yes::]`,
  keystore.trash.* [ ~/.n/remote-keys/trash/<kind>/<name>.<epoch>.mxz.B32 ]
- v7-zenki.owner-statement install \ drop [ network twin of accept-owner
  \ drop-owner, backend user via v7-zenki.backend.run ]
- p-7-r -host <name[:port]> [ the pin is named after the HOST through a
  forward ; -strict = the probe ]
- form.* engine extracted from user-edit [ <form.source> callbacks ],
  form.action.send [ one action, late replies dropped ], form.chrome
- host-edit zenka : records [ /var/protocol-7/host-edit/hosts/*.json :
  addresses, ssh, ssh_port, owner = pin name, owner_key = local authority
  key ], host-edit.transport.* [ ssh -N -L forward ], host-edit.action.*
  [ probe, pin, fetch_chain, install, run_p7r ], host-edit.flow.* [ the
  add-host state machine, one step per timer tick ], plugin.host-edit.
  actions [ the tab : Enter = flow, masked passphrase prompt, c = cancel ]
- keys.certify_host [ certify core ; a supplied passphrase never prompts,
  never retries ], editor.buffer.mask_star_count [ AMOS7::TERM random
  stars, Fortuna ], load_keypair prints the colour reset only after a
  real prompt, keys.console.rename warns for derived \ virtual keys
  [ ::yes:: ], base.disable_console_command [ + disable_command listing
  fix ], keys list shows servers\ + owners\ pins, known\ retired

- `:pass-env:` [ 1394aba35 + this commit ] : certify-host \ get-sp-pub-key \
  gen-pwd-keyfile read PROTOCOL_7_KEY_PASSPHRASE \ PROTOCOL_7_KEY_SEED from
  the environment ONLY with the tag [ read once, deleted ; key creation
  keeps the 13 char floor ] -- scripts + tests : bin/test-scripts/
  test-keys-pass-env-live.pl drives the REAL p7-keys with no prompt
- a virtual key cannot tell a wrong phrase [ the stub holds only a
  timestamp -- a wrong phrase is ANOTHER key ] : keys.certify_host
  expect_id fails closed ; certify-host takes it from an owner pin of the
  same name or ':expect=<key id>:', the host-edit flow from the record's
  owner pin [ missing pin = error ]. recommended order : get-sp-pub-key
  -> owner-pin -> certify

## user decisions [ 2026-10-08 ]

- ssh is the first-slice TRANSPORT : the remotes expose ssh only, on
  non-default ports -- NEVER write real ports \ hosts into the repo
- transports on the list : tcp, ssh, discover [ LAN announce packets,
  cross-check with nodes -- offers, by-eye key id compare verifies ], dns
  [ signed back channel + relay ], relay, file
- the network authority key : a virtual seed-phrase or passphrase-derived
  key [ never on disk ] ; the NAME is part of the derivation -- choose it
  once [ AMOS7::13::key_32 over passphrase + name ]
- dns back channel [ design only ] : `[<arg>.]<command>.<ntime-bucket>.
  <fqdn>` TXT, signed over the whole query name -- an ntime label never
  collides with a real subdomain
- `describe` waits for an inline doc format ; kimi's inventory :
  data/tasks/inline-doc-format-inventory.report.md

## next

1. the first REAL add-host run : the fanless backup host [ LAN, the GPU
   goes for repair ] -- choose the authority key first ; ssh the host once
   by hand [ BatchMode needs known_hosts ] ; the user must be admin there
   for owner-statement install
2. atom \ second-host checks : discover owner trust, rotation
3. later : discover as a host-edit source [ offered hosts -> records ],
   the dns back channel, vault-edit onto form.action.send \ chrome

## lessons

- a v7-zenki RELOAD suffices for new namespaces [ reload config re-reads
  its zenka.v7 ] and recompiles p-7-r ; check SigCgt bit 16 after
- loading any keys.* sub-namespace drags keys.init_code [ it resets
  <system.amos-zenka-user> ] -- v7-zenki loads keystore.* instead
- kimi lanes hit the 100 step limit -- resume with kimi_continue ; kimi
  writes fake signature-like '#,,..' lines into NEW files -- awk check
- a harness copying another's header redefines subs : the sign run's
  format-code -c fails on 'Subroutine .. redefined'
- never probe a destructive command [ remove known: shredded a live pin,
  restored byte-exact ] -- the fix [ key trash ] landed the same session

#,,..,,,.,...,.,,,.,,,,.,,..,,..,,,..,,.,,,,,,..,,...,..,,.,,,,,,,...,.,.,...,
#2PZLLUXQYPZG7PZZC3INWE6MNHLSJBACLMWCZM2UTWSXUAY6MAT6F6TLRU7OXSACKGLJHWMFCGYE2
#\\\|534BU3VQYEB2JRXUAX2KEGQEZN5IWSTCDJNYAKXKLOXVN2K47NS \ / AMOS7 \ YOURUM ::
#\[7]MDL6H4DFKHAF6JCDNR5J2RXGK5XDPE56N33AMZT76MQ6VIQ3JOBI 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
