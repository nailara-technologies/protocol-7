---
name: project-2026-10-08-trust-chain-step2-landed
description: trust chain step 2 LANDED 2026-10-08 [ 859a69f04 wire + pins, 22bc35644 tools + discover ] -- NOT live-checked yet [ needs a v7-zenki restart ] ; next : live check, then host-edit zenka + resilient initial transports [ user direction ]
metadata:
  type: project
---

previous : [[project-2026-10-07-session-handover-trust-chain-step1]].
design : `data/md/design/TRUST-CHAIN-STEP2.md` [ decisions + 'direction' ].

## landed

- `859a69f04` : `trust.chain` [ the ONE field \ .dlg parser + order flip ],
  .dlg = chain [ leaf first, one per line ], auth_select sends the chain
  only while it verifies [ else the leaf alone ], `trust.pin_decide` +
  helper twin [ shared trust-pin-vectors.pl ], name-bound host pins
  [ line 1 fp, 2 name, 3 since ], forward-only rotation, distrust param
- `22bc35644` : p7-keys certify-host \ accept-owner \ owner-pin \
  owner-unpin \ owner-pins \ distrust \ undistrust ;
  `p7c v7-zenki.delegation-issue` ; discover chain + 'owner' trust [ kimi
  k2.8, reviewed, 69 tests ]

## user decision [ 2026-10-07 ] -- revised the doc's 'no host pin'

owner-pinned first contact WRITES a name-bound host pin ; rotation only
when an owner covers it, same name, strictly later since. advisor found
the gap [ a certified sibling answering on another host's address ].

## next

1. LIVE CHECK part 1 PASSED 2026-10-08 [ v7-zenki restart ] : p-7-r
   recompiled on start, v7-zenki SigCgt bit 16 still set ; `p7c
   host-root-fingerprint` [ now host-root-id ] [ the CUBE command is dotless -- NOT
   crypt.C25519.cmd.. , that answers 'client not present' ] 77 chars ;
   .dlg unchanged [ one 284 char leaf, no owner file ] ; `p-7-r
   localhost:42 list sessions` authenticated, the step 1 pin gained
   '<node>.cube' + since 0. part 2 OPEN : an owner key [ the user's
   choice of form ] -> certify-host -> accept-owner -> delegation-issue
   -> owner-pin -> `PIN_OWNER`
2. second host [ atom ] : discover owner trust, rotation, step 1 leftovers
3. `describe` waits for an inline documentation format [ user ] ; arg
   details live in `# note =` meanwhile ; keep `# param` short [ the
   command list column width follows the longest param ]
4. host-edit zenka [ clone of user-edit ] + resilient initial transport
   types -- smooth 'add a host to the network' [ user direction ]

## terms + store [ 2026-10-08, user agreed ]

the 77 char bmw384 value is the KEY ID [ trust.key_id, `p7c
host-root-id`, keys.key_id_arg, `<id>` ] -- NOT a fingerprint [ longer
than the key ; kept as the fixed-size identity for future large key
types ]. label = first 7 chars, recognition only. known/ [ pre host-root
TOFU, old S keys ] archived as ~/.n/remote-keys/known.retired-2026-10-08,
p7-tofu-helper.pl removed ; known_hosts_dir = servers/ ; `remove
known:<host>` moves a pin aside [ was shred ].

## key trash [ 2026-10-08 ]

`undo-remove` \ `removed` [ user named it : a reliable undo is regular
operation, auto-purge the exception ] -- 90 d + newest 3 kept, asked only
on a TTY at most daily, `removed purge ::yes::`. host pins, owner pins,
distrust lists, the owner statement. the shredding incident was a test
entry [ no damage ] -- the fix landed in the same session.

## lessons

- gen-sub-whitelist [ zenka ] regenerates subroutines.load-early -- they
  are NOT maintained at runtime ; regenerate only the affected zenki while
  another agent edits the tree
- `ok( $x =~ m|..|, label )` : a failed match in list context shifts the
  label -- harness ok() gets a ($;$) prototype

#,,..,,.,,.,,,...,.,.,,,,,,,,,,,.,,.,,,.,,.,,,..,,...,...,,.,,,,.,,,,,,..,,.,,
#FT4TS4URQYH4B2CX7MP5QXXUNW6OO6H4LEWCNYYYED3YMY73BY3BRQLXAZP3IELRYYJSFGKK2UVUY
#\\\|GFHWA7RLO3IZEAQLQK2XQCXL452AIXQHDXCJUHBKFIBKZOIFZFO \ / AMOS7 \ YOURUM ::
#\[7]ZHKYTPILEDALOHSBDN5YTWEGKHII4QXE5ZSQ7QPHONZW7N6DGUDY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
- I ran `p7-keys remove known:127.0.0.1` with output discarded as a
  'probe' and it shredded a live pin [ restored byte-exact from an
  earlier cat ] -- never invoke a destructive command to see what it does,
  even with the output thrown away [ [[tool-probe-empty-args-destructive-default]] ]

#,,..,..,,,,.,...,,,,,.,,,..,,,..,,,,,,,.,...,..,,...,...,..,,..,,...,..,,,,,,
#HTRKP6VE3BBIX4WXBXOYIRVB7RUE2JPLHPLKBCFDYXBWZ6L4STOZBO5457PUKS2BUNSJPUF2MKTBW
#\\\|BOQRZVMKQHLDN7KEU6GOHCD7HCFDQE2MPJD6OQ4MC44MKZ4KMMF \ / AMOS7 \ YOURUM ::
#\[7]PHDBU3DAQXZTH7MZ2HHNERHZ3XXBWNZOZIBRFNRJ7CN33MC4FWAQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
