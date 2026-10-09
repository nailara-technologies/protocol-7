---
name: feedback-no-sha2-no-hex
description: user preference 2026-10-09 -- no sha-256 \ sha-2 where it is not necessary, and no hex encoding ; base32 [ rfc 4648 ] is the project's encoding, blake2b \ bmw for hashing
metadata:
  type: feedback
---

said twice during the vault work [ 2026-10-09 ] : "no sha256 if not
necessary" and "no hex encoding".

**Why:** project convention -- every stored or shown binary value in
protocol-7 is base32 [ keys, ntime stamps, checksums, inline subroutines ],
and its own hashing is bmw \ blake2b, not sha-2.

**How to apply:**
- a kdf \ mac hash : prefer blake2b [ CryptX `BLAKE2b_512` ; python
  `hashes.BLAKE2b(64)` ] -- the vault's hkdf moved from sha-256 to it
- don't pre-hash input that a kdf takes at any length [ argon2id ] --
  length-prefix and concatenate instead
- show ids \ digests in base32, never hex -- even git's sha-1 blob id is
  printed base32 [ `AMOS7::Vault::git_blob_id` ]. sha-1 stays only where an
  outside format defines it [ git ], for identification, never as key
  material
- related : [[project-2026-10-09-vault-ntime-landed]]

#,,,,,.,,,,.,,...,,..,.,,,,..,..,,,.,,,.,,,,,,..,,...,.,,,...,.,.,.,,,,,.,,..,
#KKLTHAHQ2KQDYPLZ4J6OZJO5Z7V4DNFXDFEIWWXMU7MUBERA4KSUDWNHGP5M2EMWA4AIVM4DGSIA4
#\\\|MCZZ5MUC7WHWFYFOOUFH7NUAWX3X5UTN5UHFJEZC2S5EC5OQNFP \ / AMOS7 \ YOURUM ::
#\[7]TCJG3BNHHC3YRTFBDPKJ2RQCSDZNWZJO7Q5V4JV32NQCLRAMFABQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
