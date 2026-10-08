# host setup : the host-edit zenka [ draft ]

draft 2026-10-08. builds on `TRUST-CHAIN-STEP2.md` [ owner root, host pins,
`p7-keys` tools ]. direction [ user ] : multiple hosts by DEFAULT -- adding
a host to a network and everything around it is ONE smooth interaction.

## first slice

**add atom, end to end** : from this desktop, atom is entered once,
reached over SSH [ the remotes only expose ssh, on non-default ports ;
their cube port is off or local only ], its host-root key id taken over the
ssh-authenticated channel, pinned,
certified by the owner, the owner statement installed on atom over the
link, and discover on both sides shows `owner` trust. this also closes
the open second-host checks [ discover owner trust, host-root rotation ].

## decisions [ user, 2026-10-08 ]

1. **one form engine** : the record-independent part of user-edit
   [ terminal form, menus, drafts, outbox ] moves into a shared `form.*`
   namespace ; user-edit and host-edit both load it and keep only their
   record-specific parts. measured : 23 of user-edit's 68 modules touch
   users \ usernames [ form 13 \ 24, menu 3 \ 6, handler 7 \ 13 ; draft,
   outbox, key_actions none ].
2. **host records live in host-edit's own zenka dirs**, like user-edit :
   `/var/protocol-7/host-edit/` [ VAR_P7 ] and `/etc/protocol-7/host-edit/`
   [ ETC_P7 ] -- no separate hosts zenka.
3. **transports are plural** : direct tcp exists ; ssh is the FIRST one
   added, relay through a linked node and offline file exchange follow
   [ 'transports' ]. a host record lists the ones it can use.

## host record

what is OURS to decide -- nothing a pin already holds :

- `name` [ the label, e.g. `atom` ; also the external link name ]
- `addresses` [ `host[:port]` list, tried in order ; the cube port the
  pin is named after ]
- `ssh` [ `[user@]host`, `port` -- per host, never in the repo ]
- `link_user` [ the remote username for external links ]
- `transports` [ ordered : `tcp`, `ssh:<profile>`, later `relay:<node>`,
  `file` ]
- `owner` [ the owner pin name that should certify it, optional ]
- `roles` [ free tags : osf-cache peer, relay, .. ]

**never copied into the record** : key id, leaf name, since -- the host
pin in `servers/` [ `<host>_<port>.public` ] is the single source of
truth ; the form READS it [ `keys.list_remote_keys` ] and shows trust
from it. a record with no pin shows 'not yet contacted'.

## add-host flow

1. **enter** name + address [ + ssh, owner ] -> a draft record
2. **probe** : over the record's first transport -- for the first slice
   an ssh local forward to the remote cube [ 'transports' ] -- `p-7-r
   -strict` connects WITHOUT pinning and reports the offered host-root
   key id + leaf name [ PIN_UNPINNED ]
3. **verify** over a second, already trusted channel : the key id the
   tcp probe offered must EQUAL the one seen there -- this replaces the
   manual 'compare out of band' of `certify-host`. first channel : ssh
   [ 'transports' ]. none configured : the form shows the key id in
   halves for a by-eye compare [ the 7 char label is never enough ]
4. **pin** : a normal connect writes the host pin [ name-bound, since 0 ]
5. **certify** [ owner configured ] : `certify-host <owner> <name>
   <host-root>` with the probed public key ; the owner key form decides
   prompts [ any form, warnings only ]
6. **install on the host** : the statement goes over the link to the
   host's v7-zenki [ command below ] ; v7-zenki re-issues the .dlg
7. **done** : the form shows `owner` trust ; clients that pin the owner
   now trust atom on first contact

## host-side command [ written by claude, NOT a kimi lane ]

`v7-zenki.owner-statement install <chain field>` \ `drop` : the network
twin of `p7-keys accept-owner` \ `drop-owner`, a trust-chain WRITE :

- admin only [ cube access ; never `access.cmd.usr.cube` wildcard reach
  without the admin check ]
- verifies the full chain exactly as accept-owner does : subject = THIS
  host-root, scope covers `<node>.cube`, nothing expired
- writes `host-root.dlg` AS the backend user [ the effective-uid switch
  of `v7-zenki.delegation.issue`, extracted into one helper both use ]
- the previous statement goes to the backend user's trash [ undoable ]
- re-issues the delegation at once [ the reply carries the new .dlg
  state ]

## transports

- **tcp** [ exists ] : external links, `p-7-r`. first contact is TOFU
  unless an owner pin or a verification channel backs it.
- **ssh** [ first one added ] -- two ways :
  - the existing **ssh zenka** : tunnel profiles [ `cfg/zenki/ssh/
    link-setup.*` ] pin the remote ssh host key [ `ssh.hostkey.elf` \
    `.bmw` ] and bridge cube to cube -- an authenticated channel ready
    to use ; its bridge still authenticates with a p7 user + PASSWORD
    [ pre auth-keypair ], so carrying a link over it means moving that
    bridge to auth-keypair + host-root pins
  - plain `ssh <host> p7c host-root-id` with the user's own ssh config :
    verification only, no tunnel, nothing to migrate
  **decided [ user, 2026-10-08 ] : plain ssh for the first slice** -- the
  remotes only expose ssh [ non-default ports ], so ssh IS the transport, not
  only a verification channel : `ssh -p <port> -N -L <local>:127.0.0.1:42
  <host>` forwards to the remote cube [ which may stay local-only ]. the
  key id that arrives through it is authenticated by the ssh host key
  [ the user's known_hosts ] -- the probe IS the verified first contact.
  the ssh zenka becomes the managed transport once its bridge speaks
  auth-keypair [ its own step : the last password-authenticated cube
  link ].
- **pins name the HOST, not the dial address** : through a tunnel the
  dialled address is `127.0.0.1:<local>` -- the pin must be the record's
  `<name>_<port>` [ `atom_42` ]. `auth.client.server_pin.check` and the
  helper's `check-pin` already take host + port : the transport layer
  passes the record's name + remote port, never the forward.
- **relay** [ later ] : through an already linked node [ external links ]
- **file** [ later ] : statements \ key ids as files [ air-gapped, usb ]

## landed [ 2026-10-08 ]

- `v7-zenki.owner-statement install <chain> | drop` [ the section above ]
  on `v7-zenki.backend.run` \ `.read_small` [ extracted from
  delegation.issue ]
- `p-7-r -host <name[:port]>` : the pin is checked under that name while
  dialling a forward ; with `-strict` it is the probe [ reports the
  offered key id, writes nothing ]
- the key trash moved to `keystore.*` [ was keys.trash.* ] : loading any
  `keys.*` sub-namespace pulls the keys zenka's init hooks, and
  keys.init_code resets `<system.amos-zenka-user>` from $ENV{USER} \ the
  euid -- inside v7-zenki [ root ] that would make the backend user root

## lanes

- **kimi A** : extract `form.*` from user-edit [ task file, user-edit's
  tests + a live show-form as the safety net ]
- **claude** : the host-side command + the backend-uid helper ; the
  probe \ ssh verify steps [ trust-relevant ]
- **kimi B** [ after A ] : host-edit zenka on `form.*` -- records,
  add-host form, actions calling the steps above
- every new namespace into every calling zenka's `modules.load` ;
  whitelists only for the affected zenki while a lane edits

## reuse [ user, 2026-10-08 ]

layering already in place : `editor.*` [ generic controls : fields,
lists, menus, cursors ] -> `form.*` [ the record form engine, 26 modules
on editor.* ] -> user-edit \ host-edit [ record sources ]. vault-edit [
cred-mesh client, on editor.* too ] has the two patterns the add-host
ACTIONS need -- lane B2 generalises them into form.* instead of copying :

- `vault-edit.send_action` -> `form.action.send` : exactly ONE routed
  call outstanding, a busy flag stops key decoding until its reply lands
  [ probe, certify, owner-statement install each wait on a reply ]
- `vault-edit.render_chrome` -> `form.chrome` : client-owned title bar,
  footer status line + key hints that survive every reply [ step
  progress : 'probing atom ..', 'pinned', 'certified', 'installed' ]

vault-edit can move onto them afterwards [ not part of B2 ].

## later

- relay through a linked node, offline file exchange [ transports ]
- remove \ rename host [ through the key trash : pin + record together ]
- several owners per host, roles driving osf-cache peers

#,,,.,,.,,,.,,,..,..,,,,,,,,,,,..,,..,,.,,,..,..,,...,...,.,,,..,,.,.,..,,...,
#OML4BZQXEPGWRMGDWYUYWBBLDTG2OCMPCO6YTFKPDDBSJTN2DMIOOPGNEX2L77ELTY3KG3MIA7WHY
#\\\|RKG2YRDNFG5SUECBN6OSEK47O7DQTS7SDECVM5JL6PT46E2O3OS \ / AMOS7 \ YOURUM ::
#\[7]FXDMCRGDVB27MCC7YQQCK4Q7GSPDEFOI25PGZNXSYBDG76GCTSAA 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
