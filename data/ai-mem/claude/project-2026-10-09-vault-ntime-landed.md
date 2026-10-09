---
name: project-2026-10-09-vault-ntime-landed
description: LANDED 2026-10-09 a143c2f64 + 58ddba430 -- bin/p7-vault [ AMOS7::Vault, personal passwords \ notes \ contacts, standalone ], AMOS7::NTIME + bin/ntime [ ntime without backend ], format-code title box + bracket-aware reflow. open : real vault not created yet, backup command, sync, pri argon2 package
metadata:
  type: project
---

**why it exists** : the user's passwords were unencrypted [ memory, files,
forgotten -- locked out of several accounts ] and the main host is about to be
swapped [ gpu fan repair ]. the vault is the "better minimum state".

**vault** [ `data/md/design/VAULT-FORMAT.md` is the spec ] :
- `bin/p7-vault` + `AMOS7/Vault.pm` + `AMOS7/NTIME.pm` -- standalone on
  purpose, no zenka. store `~/.n/vault` [ `P7_VAULT_DIR` ]
- argon2id [ CryptX >= 0.088, else Crypt::Argon2 -- debian bookworm 0.013
  verified identical ] wraps a random vault key ; passphrase + recovery code
  wraps. CASCADE [ user's call 2026-10-09, still format 1 -- no vault existed
  yet ] : twofish-gcm inside chacha20-poly1305, independent hkdf keys, on the
  key wrap AND every entry version [ wrap-only-chacha would leak the vault
  key ]. ad binds vault \ id \ version. python's `cryptography` has no
  twofish : spec recovery = python kdf + outer layer, CryptX twofish-gcm
- storage : binary fields [ 'P7VK' \ 'P7VE' + format byte, layouts in the
  spec ] in ONE base32 block per file, framed in the ': ' inline format of
  bin/Protocol-7's __DATA__ subroutines [ '.:[ title ]:.', ': ' + 76 chars,
  short last line centred with '0' ; readers drop 0 \ 1 ]. names
  `vault.key.B32`, `<id>.<version>.vlt.B32` [ user's choice over text lines ]
- considered + declined : the keys archive's bit-splicing [ no gain under an
  aead, needs base.vec.* ]. ITS size-class padding is the idea worth taking,
  -> BUILT as `p7-vault archive` \ `restore-archive` : key file in the clear +
  cascaded payload of EVERY version, padded to 13312 x 3^n, read back +
  compared after writing ; restore checks names first, refuses another vault,
  never replaces. a public repo keeps every pushed archive : a passphrase
  change does not protect old ones [ said in passwd + spec ]
- bug found by the archive tests : vault_rewrap's last-wrap refusal died with
  the wrap already deleted from the handle -> a later write from it dropped
  the recovery wrap silently. fixed, regression test
- one immutable file per version [ `<id>.<ntime 14 digits>.<rand>.vlt` ] :
  sync = union of files, `restore` = undelete. random ids [ public DATA repo ok ]
- synced writes [ tmp + fsync + link \ rename + dir fsync ] ; damaged newest
  version falls back to the older one
- recovery proven : copied `p7-vault` + `AMOS7/` to a bare dir works ; an
  independent python [ `cryptography` 49 ] decryptor written from the spec alone
  decrypted it
- clipboard : xsel under wslg [ windows history warning keyed on wsl ],
  clip.exe gets utf-16le+bom [ UNTESTED -- would overwrite the real clipboard ]

**ntime** : `AMOS7::NTIME` mirrors base.ntime \ encode_ntime_to_B32 \
BASE32_to_numerical [ test pinned to real core log stamps ], duration_str =
base.parser.duration format, localtime_str = cube localtime format. NOT loaded
by zenki. `bin/ntime` : base32 \ ntime \ unix [ `0+` prefix ], `.. ago` \
`in ..`, two args = duration. base32 ntime does NOT sort in time order -- the
vault file names use decimal.

**open** :
1. the user has not created the real vault yet -- right after, copy it to usb
   + pri [ offered : `p7-vault backup <dest>` writing the recovery layout ]
2. pri needs `libcrypt-argon2-perl` [ apt, user's call ]
3. later : sync over protocol-7 \ the checksum storage layer, session agent,
   vault-edit form ui [ form.* drafts \ outbox write plaintext -- must be off
   for a vault source, char-add too ], totp display
4. dedupe the ntime ports in bin/todo, bin/dev/update-version, AMOS7::Version
   onto AMOS7::NTIME [ offered ]

**lessons** : `qw| |` is an EMPTY list, not a space [ broke joins + padding ] ;
format-code -c compiles .pm files inside a sub -- file-level `my` reads as
"not available", use `our`. pkill -f with a pattern from my own command line
kills my own shell.

#,,.,,,..,,,,,..,,,,.,,,.,.,.,,,,,,..,.,.,.,.,..,,...,...,...,.,.,.,.,.,,,,,,,
#M3UQE7QC5LBQFRRD35AMBQFMTHBXSGKZ2QBS4747C5YSVR7W5ZNPGVMLEQBZWTRXS5EVKOXUJDPT6
#\\\|NZZHC4KF6NXVAFPAVP4FTTYRF5MLVZXAG3SOV2TYMVVQIRQFJHY \ / AMOS7 \ YOURUM ::
#\[7]3PEBT2DK7Q3N4O355JHG4U7AEZRRNFBTRZM2JO7CUCJ4NR34NEAI 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
