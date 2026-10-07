---
name: project-2026-10-07-session-handover-trust-chain-step1
description: handover of the 2026-10-06 -> 07 session [ last f1b7c83ef, pushed ] -- trust chain step 1 landed : auth-keypair v2 mutual binding [ replayable auth + unproven server + relayed auth closed ], host-root delegation with root-held keys, discover carries the .dlg ; p-7-r shell injection + argv secrets fixed ; NOT live-checked yet
metadata:
  type: project
---

session 2026-10-06 evening -> 2026-10-07, last commit `f1b7c83ef` [ base,
pushed to hub ]. previous : [[project-2026-10-06-session-handover-security-sweep]].
worked as parallel lanes [ background Agents + kimi + one web session ]
-- [[feedback-fill-5h-windows-with-prepared-parallel-dispatch]].

## landed

- `ad31ddd5a` **auth-keypair v2 + link-upgrade mutual binding**
  [ `data/md/design/AUTH-LINK-BINDING.md` ] -- closes
  [[project-2026-10-06-auth-keypair-replayable]] : server nonce, labelled
  sigs, sessions PENDING until the client signs the link transcript,
  server proof ; p-7-r : secrets off argv [ stdin ], no shell [ server
  replies could inject commands ], no plaintext temp files ; p7c's
  half-built link-upgrade removed
- `8a50cf992` gen_keys keeps a caller's secret exactly [ letsencr ]
- `1adb45b02` + `e3c3ee371` **host-root delegation**
  [ `data/md/design/HOST-ROOT-DELEGATION.md` ] -- host-root was NEVER
  created before [ [[project-2026-10-06-host-root-never-created-root-held-keys]] ] ;
  root-held keys in `user-keys/root/`, resolver `crypt.C25519.key_path`,
  `trust.statement \ verify \ fingerprint`, v7-zenki issues
  `protocol-7.base.dlg` [ name `<system.node.name>.cube`, 30 d,
  not_before -300 s ], 4th select field, clients pin the host-root
  FINGERPRINT [ 77 chars ], keys zenka knows root-held keys
- `f1b7c83ef` **discover carries the .dlg** [ trust pinned \ offered \
  unverified \ invalid, drop on invalid \ changed root, adaptive flood log
  level ] + e2e test [ real server vs real client, 54 ]
- tests : binding 155, delegation 186, keys 121, discover 33, e2e 54,
  external 84, keygen, helper self-tests

## next steps

1. **LIVE CHECK** [ needs a v7-zenki restart, cube restarts with it ] :
   `ls -la /home/protocol-7/.n/user-keys/root/` -> host-root.* root 0600,
   dir root 0700 ; `protocol-7.base.dlg` beside the base key ;
   `p7c crypt.C25519.cmd.host-root-fingerprint` -> 77 chars ; re-open
   `external.self` -> one `pinned host-root ..` log ; `discover`
   host_details shows trust. remove any old 52-char pins under
   `~/.n/remote-keys/servers/` first. then the same on atom \ remote
   servers [ start profile differs, same v7-zenki config ]
2. regenerate the `.base` placeholder keys [ weak-seed era, from the
   previous handover -- still open ]
3. follow-ups : nodes gets trust transitions only on re-appearance ;
   orphaned `%signatures` modules ; `crypt.C25519.sign_keys` \ `.sig.*`
   still used by keys.console.sign-key ; `Digest::BMW` into bin/p7-deps
   [ the C helper needs it ] ; keys.console.encoding-upgrade root-held
   guard
4. trust chain step 2 : host-root certifies per-service keys [ scope
   field ], owner root above host roots

## workflow lessons

- a lane that calls into a NEW namespace must add it to every calling
  zenka's `modules.load` -- missed twice [ auth.binding in external \
  users, trust in discover ] ; tests that compile modules directly cannot
  see it
- web sessions need everything committed + pushed ; check the web usage
  bar for credits vs plan [ [[reference-claude-web-promotion-credits-overflow]] ]
- unpushed fix-ups : `AMEND=1` ; parking without a version : the user
  toggles `$skipping_disabled` in bin/dev/git-hooks/pre-commit ; squash
  onto base with `--ours` version files, then update-version once

#,,..,,.,,...,,,,,,,,,...,,.,,.,,,...,,,.,,,,,..,,...,...,,,.,,..,..,,.,.,...,
#6JSFZVOPJWXHWEN4RSD7QPFNMBYZSGACFMSP2VJDD5T3PQUGFDSD2B6HITCPL3M5SHKW3BTGFTA4G
#\\\|RRZJBFQKGQPS4BS6VKENAAOL5SK22JVGBITM5R32SRT2QHPFSQO \ / AMOS7 \ YOURUM ::
#\[7]GKDHLZOZP23UDNYTFXO7T2FG7BN4VV3CGMKY4SZHUZHUN4DEZ6CY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::

**status 2026-10-07 [ next session ] :** 1. live check DONE on this host [ root/, .dlg, fingerprint 77, pins via p-7-r + external.self ] -- discover trust + atom \ remote servers still open [ needs a 2nd host ]. 2. DONE [ both .base keys rotated ]. 3. Digest::BMW : already in the cryptography profile [ nothing to do ] ; encoding-upgrade guard : 6e2d170ec ; %signatures : dead cluster removed [ load_all_signatures, key_signatures_list, verify_key_signature, the global, post_init's readerless {root} glob ] ; sign-key \ remove-signature \ .ks .sk .rq helpers KEPT -- migrate to trust.statement with step 4 ; name_from_skey_name is live [ key_name_to_skey round-trip ]. nodes trust transitions : DONE [ discover notifies nodes on every trust change, invalid on a changed root -- test-discover-delegation 38 ; live check needs a 2nd host ].

#,,,.,...,,..,.,,,.,,,...,,,.,...,.,,,..,,,..,..,,...,..,,.,.,,,,,,.,,,.,,,.,,
#ALIFG3E2AQGWYPOLRKPFA2527E6MOCLWRABEQTTWDJQY3KB6WFN32IQXDN2SNWCVEM3T2LQTVL6SA
#\\\|EFHRAP3G4IGSVWG2ULTPNT7BVWBDV6CQORJMKBKIYLU3ZCLOZND \ / AMOS7 \ YOURUM ::
#\[7]V54DANWYFE3R5I6LUQL7U6GIUSXBPEFAEBKJVY3MNESUGLMUCYDI 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
