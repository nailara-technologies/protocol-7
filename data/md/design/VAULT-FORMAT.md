# vault format : p7-vault 1

2026-10-09. the personal vault [ logins, notes, contacts ] behind
`bin/p7-vault` and `data/lib-path/pm/AMOS7/Vault.pm` [ + `AMOS7/NTIME.pm` ].
this file is the recovery reference : copy it next to every backup of a
vault, together with those three files [ layout : `p7-vault`, `AMOS7/Vault.pm`,
`AMOS7/NTIME.pm` in one directory ]. everything below uses standard
primitives only, so a vault opens without protocol-7 -- with the script, or
by hand from this text.

## directory

```
<vault>/            0700   default ~/.n/vault [ P7_VAULT_DIR ]
  vault.key         0600   key file : vault id, kdf, wrapped vault key
  entries/          0700
    <id>.<version>.vlt     one file per entry VERSION, never rewritten
```

- `<id>` : 16 base32 chars [ 80 random bits ]. file names carry no title,
  url or user name -- the list of sites stays private even in a public copy
- `<version>` : `<ntime, 14 decimal digits>.<8 base32 chars>`. sorted as
  text = sorted in time. the random tail keeps two devices that edit the
  same entry offline from colliding ; a sync is a plain union of files
- an edit or a delete ADDS a version. the newest version is the entry ;
  a newest version with `"deleted":1` hides it. nothing is overwritten,
  `restore` writes an older version again as the newest

## encodings

- base32 : rfc 4648 alphabet `A-Z2-7`, upper case, no `=` padding
- network time [ ntime ] : `( unix seconds - 1023228000 ) * 4200`
  [ 1023228000 = 2002-06-05 ]. decimal in version names ; in `created`
  and `updated` : base32 of perl `pack( 'w', <integer ntime> )` [ ber
  compressed integer ], the same stamps as protocol-7 logs [ `bin/ntime
  <stamp>`, no backend needed ; `p7c localtime <stamp>` ]

## key file

text, one item per line :

```
p7-vault-key 1
vault <vault id : 16 base32>
created <ntime base32>
kdf argon2id <t> <m KiB> <p>
wrap <name> <salt> <nonce> <ciphertext> <tag>      [ base32 each ]
```

- the vault key : 32 random bytes, never stored in the clear
- each `wrap` holds the vault key encrypted under one secret. names :
  `passphrase` [ chosen by the owner ], `recovery` [ 32 base32 chars shown
  once at init, `XXXX-XXXX-..` on paper ; dashes, spaces and case are
  ignored, `0 1 8` read as `O L B` ]
- wrap key = argon2id [ rfc 9106, version 0x13 ] of the secret [ utf-8
  bytes ; the recovery code in its normalized form ], salt 16 bytes,
  t \ m \ p from the kdf line, 32 byte output
- vault key = chacha20-poly1305 [ rfc 8439, 12 byte nonce ] decrypt of
  `<ciphertext>` + `<tag>` under the wrap key, associated data :
  `p7-vault-key 1 <vault id> argon2id <t> <m> <p> <name>` [ single spaces ]
- a passphrase change rewrites only this file. older COPIES of the file
  still open with the old passphrase

## entry file

one line :

```
p7-vault-entry 1 <vault id> <id> <version> <salt> <nonce> <ciphertext> <tag>
```

- entry key = hkdf-sha256 [ rfc 5869 ] : key material = vault key, salt =
  `<salt>` [ 16 bytes, fresh per version ], info = `p7-vault-entry 1`,
  32 bytes
- plaintext = chacha20-poly1305 decrypt under the entry key, nonce
  `<nonce>`, associated data `p7-vault-entry 1 <vault id> <id> <version>`.
  the ad binds the blob to its vault, entry and version : a renamed or
  swapped file fails to decrypt
- the header words must equal the file name's id and version
- plaintext : a json object [ utf-8 ], a newline, then spaces up to a
  multiple of 512 bytes [ hides value lengths ]

## record

```
{ "type": "login", "title": .., "url": .., "username": .., "password": ..,
  "totp": .., "notes": .., "updated": "<ntime base32>" [, "deleted": 1 ] }
```

types and fields : `login` [ title url username password totp notes ],
`note` [ title body ], `contact` [ title name phone email address notes ].
absent fields are left out. unknown fields are kept as they are.

## opening a vault by hand

needs perl with CryptX >= 0.088 [ or CryptX + Crypt::Argon2 :
debian `libcryptx-perl libcrypt-argon2-perl` ], or any argon2id +
chacha20-poly1305 + hkdf implementation :

1. read `kdf` and the `passphrase` wrap from `vault.key`, derive the wrap
   key with argon2id, decrypt the vault key [ ad as above ]
2. for each newest `entries/<id>.*.vlt` : hkdf the entry key from the vault
   key and the salt, decrypt with the ad, parse the json

`bin/p7-vault --dir <copy> verify` does both for every version.

## not in format 1 [ later ]

sync between hosts over protocol-7, a session agent [ unlock once per
login ], the vault-edit form ui, totp code display, purging old versions.

#,,..,...,,..,,,.,,,,,,,.,,.,,...,..,,,.,,,,.,..,,...,...,.,.,,..,.,,,,.,,,,.,
#YSNL33S6XUXUDZWPWVACUOT3O5ATJYJHZ37QYVH5JZRGCDPERKZBILB3LAGRLK5YN6SK6N2IA45HI
#\\\|PORQPTKHWI5CZCWU2NI7WGFIGUSPZYALKCOT6O42FRP2SK56CI4 \ / AMOS7 \ YOURUM ::
#\[7]LWASSSX3XFS36SMBZHKYBFICJEV3X24ZVT6VCBS4YSWKUD3O4ABA 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
