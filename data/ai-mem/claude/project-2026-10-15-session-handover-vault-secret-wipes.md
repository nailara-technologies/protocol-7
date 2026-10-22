---
name: project-2026-10-15-session-handover-vault-secret-wipes
description: START HERE -- session 2026-10-14..15 handover [ last cd174a844, pushed ] : p7-vault auto-lock \ directory + saved sync targets \ input timeout \ quit clear \ cursor, secret + password wipes [ copy-on-write, vault, AMOS7::TERM reader rewrite, C25519 loaders ], IO::AIO stale-$@ poll bug, invented copyright header removed, run-tests
metadata:
  type: project
---

session 2026-10-14..15. follows [[project-2026-10-14-session-handover-history-rewrite-llm-identities]].

## landed [ all committed + pushed to hub base ]

- p7-vault [ a7894865f 0a7a33d45 53652cb4c cd174a844 ] : read pre-check +
  `-i`, styled tar \ ssh errors, TERM-style prompts, framed lists,
  `commands <kw>` + usage search on an unknown command, multi-host and
  directory [ external drive ] sync, saved targets [ `sync -a \ -r \ -l`,
  `<vault>/sync-targets`, a bare `sync` runs them ], auto-lock 78 min
  [ P7_VAULT_LOCK_SECONDS, `:keep-open:` ], key in a private mlocked
  buffer, quit \ q \ exit \ x wipe + clear screen [ ctrl-d \ ctrl-c keep it ],
  hidden input timeout 13 s [ P7_VAULT_INPUT_SECONDS ; slow accelerating
  rewind a key stops once, then twice as fast, wiped, cancelled, typed-ahead
  dropped ], ctrl-u \ abort rewinds, underscore shell cursor hidden in
  hidden input [ END + INT\TERM\HUP restore it and wipe the key ]
- secret wipes [ f0fd90189 6ca928a0f 1e6fe8766 3fdc6aad6 ] : see
  [[reference-perl-cow-secret-wipe]] -- copy-on-write copies, regex copies,
  vec-only in-place editing, memory scan as the proof. AMOS7::TERM's
  password reader rewritten [ byte-identical except ctrl-u now keeps what
  follows it ; test-term-password.pl, 40 cases incl. a memory scan ]
- IO::AIO : a callback-less request [ aio_mlock ] makes the next poll \ flush
  DIE with a stale $@ -> `local $EVAL_ERROR` in base.s_read \ s_write.file_io
- jobs-normalize-titles : an invented copyright header removed
  [ [[feedback-never-invent-attribution-headers]] ] ; sub lists regenerated
- bin/test-scripts/run-tests <word>... [ test-<word>*.pl, one summary ]
- uncommitted at handover : test-keys-single-file.pl [ staged, unsigned ]

## correction -- 1e6fe8766's message overstates the load_single bug

load_single stored decrypt_priv_keystr's REFERENCE as the private key [ fixed,
right ], but the claimed symptoms never happened : base.context.list [ via
base.reverse-sort in key_bin_checksums ] dereferences SCALAR refs, so
enc-key-chksum printed the right checksum ; FALSE is impossible there [ only
returned when a public key is passed, load_single passes none ]. proven by
running the new test against the old file. claimed without testing --
the lesson : verify a bug's effect before naming it.

## built in the second commit of 2026-10-15 [ after ea26cf761 ]

- single-file key password check : crypt.C25519.decrypt_priv_keystr checks
  the clamp bits when no public key is given, wipes a failed decryption
  [ 2000 real keys all clamped ; ~1 in 32 wrong passwords still pass ]
- p7-vault import -u [ -a <dir> \ <paths> ] : changes become new VERSIONS
  [ keyed content id in the entry ; unchanged adds nothing ]
- p7-vault sync into a missing vault : names the target's vault id, asks,
  fetches the key file [ 0600, parents 0700 ], pulls everything

## open

- DONE 2026-10-15 [ 439939cbe f8c40648c 814ba56e4 ] : p7-log rekey-anon-table [ :skip-unreadable: ] ; live : the weak 2025 archive rekeyed [ 4832 records ; 47 under a key that no longer exists, left in retired/ ] ; then p7-log moved to its OWN key p7-log.anon [ config key_name ; reload config, archive-anon-table + rekey-anon-table protocol-7.base : 5416 records, 0 missing ]. backup /var/protocol-7/p7-log/log-anon.bak-2026-10-15.
- user's call : delete log-anon/retired/ + the backup ; p7-keys remove protocol-7.base-anon-2026-10-07 [ protocol-7.base STAYS : cube S \ .dlg ]
- REMOTES : before a host gets 814ba56e4, as protocol-7 `p7-keys create -U p7-log.anon`, then reload config + archive + rekey <user>.base -- without the key every span becomes [L:-] [ lost ]. offered : auto-create + auto-migrate in p7-log [ undecided ]. also check remotes' protocol-7.base date [ before 2026-10-07 = weak prng key ; user thinks they were regenerated, not in memory ]
- truth check : the 3 failing keys were true under the PRE-2026-08-26 elf algorithm [ sourcecode, remote-fetch-client verified ; anon = 2025 key, old-lib check hangs -- old elf bug ]. no generator to fix. was : 3 of 7 genuine public keys fail it
  [ proto-7.sourcecode, protocol-7.base-anon-2026-10-07,
  remote-fetch-client ] -- generated without the filter, or misread format.
  investigate [ public keys only ]
- user to decide : vault `rekey` [ new id + random key, re-encrypt every
  version ; old copies stay readable with old secrets ] vs owner-key
  rotation first [ host-root rotation exists : PIN_ROTATED ; owner key has
  no path besides re-pinning by hand ]
- DONE 2026-10-15 : /etc/fstab /mnt/ext-xfs-data has nofail,x-systemd.device-timeout=13s [ reboot with the usb disk renumbered + not attached had stopped boot in emergency mode ; wsl --mount \\.\PHYSICALDRIVE<n> --bare, the disk = ADATA usb, sde3 'Taeki-data' ]
- live : a sessions secret hold \ release through host-edit \ user-edit form
- pii pattern placeholders : live host, postal address, assessment marker
- small : rewinds via '\b \b' if the vault prompt still flickers ; recovery
  code typed back still passes regexes

#,,.,,.,,,,,.,..,,.,.,,,,,,,,,,,.,,..,.,.,,,.,..,,...,...,.,.,,,,,.,,,.,,,,,.,
#2FXRRZTINSZLJQ7YKQ54YX3FWXJZ6HCUE63H3JNBFGKK355JEKKMMLK2V7M7DSQJ3AAN3GKCII6C2
#\\\|LPT4HBXVMVWMCJIJG5HGQJ2RGBV4OAYR47QFQJVZJZCEOONRW2R \ / AMOS7 \ YOURUM ::
#\[7]IZTU77NUSIUT773KJZTJU4I3ATVQ3FKBTIWL536F5LBAPESFH6BQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
