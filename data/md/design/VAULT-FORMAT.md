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
  vault.key.B32     0600   key file : vault id, kdf, wrapped vault key
  entries/          0700
    <id>.<version>.vlt.B32   one file per entry VERSION, never rewritten
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
  [ 1023228000 = 2002-06-05 ]. decimal in version names, an unsigned
  64 bit integer in the key file ; the record's `updated` : base32 of perl
  `pack( 'w', <integer ntime> )` [ ber compressed integer ], the same
  stamps as protocol-7 logs [ `bin/ntime <stamp>`, no backend needed ]
- every file is ONE base32 block in protocol-7's inline format [ the
  frame of the inline subroutines in `bin/Protocol-7`'s `__DATA__` ] :

```
.:[ p7-vault entry ]:.                   [ 'p7-vault key' in vault.key.B32 ]
:
: <76 base32 chars>                       payload lines : ': ' + 76 = 78
: 0000<last chars>0000                    short last line centred with '0'
:
```

  reading : take the lines starting `: `, drop those two characters, delete
  every `0` and `1` [ outside the base32 alphabet ], join, base32 decode.
  the result is the binary layout below. integers are big endian

## cascade : two ciphers, every layer of the file

the key file and every entry version are encrypted twice, with independent
keys -- a break of either cipher alone reveals nothing and changes nothing.
the key file is cascaded too : with only the entries cascaded, breaking
chacha20 on `vault.key.B32` would yield the vault key and with it both layers.

`cascade( root, salt, label, ad, plaintext )` :

- twofish key \ nonce = hkdf-sha256 [ rfc 5869 ] : key material = root,
  salt = salt, info = `<label> twofish-gcm`, 44 bytes -> key = bytes 0..31,
  nonce = bytes 32..43
- chacha key = hkdf-sha256 : key material = root, salt = salt,
  info = `<label> chacha20-poly1305`, 32 bytes
- INNER : twofish-gcm [ twofish, 256 bit key ; gcm as nist sp 800-38d,
  12 byte nonce, 16 byte tag ] of the plaintext, associated data = ad
- OUTER : chacha20-poly1305 [ rfc 8439 ] under the chacha key, a random
  12 byte `<nonce>`, associated data = ad, over INNER ciphertext followed
  by its 16 byte tag
- stored : `<nonce>` `<ciphertext>` `<tag>` of the outer layer

decrypting : outer layer first, split the last 16 bytes off as the inner
tag, then twofish-gcm. both tags must verify.

the twofish nonce comes from the hkdf output, so it never repeats : every
salt is fresh random per encryption.

what the cascade does not cover : a weak passphrase [ argon2id slows a
guess, it cannot make a short passphrase long ], and a break of argon2id or
hkdf-sha256, which both layers' keys pass through.

## key file

binary, inside the base32 block [ offsets in bytes ] :

```
 0   4  'P7VK'
 4   1  format                 1
 5  10  vault id               [ base32 of these 10 bytes = the 16 char id ]
15   8  created                ntime, unsigned 64 bit
23   1  kdf                    1 = argon2id
24   4  t                      argon2id passes
28   4  m                      argon2id memory, KiB
32   4  p                      argon2id lanes
36   1  wrap count
37  ..  per wrap : name length [ 1 ], name [ ascii ], salt [ 16 ],
        nonce [ 12 ], tag [ 16 ], ciphertext length [ 2 ], ciphertext
```

- the vault key : 32 random bytes, never stored in the clear
- each `wrap` holds the vault key encrypted under one secret. names :
  `passphrase` [ chosen by the owner ], `recovery` [ 32 base32 chars shown
  once at init, `XXXX-XXXX-..` on paper ; dashes, spaces and case are
  ignored, `0 1 8` read as `O L B` ]
- root = argon2id [ rfc 9106, version 0x13 ] of the secret [ utf-8 bytes ;
  the recovery code in its normalized form ], salt = `<salt>` [ 16 bytes ],
  t \ m \ p as stored, 32 byte output
- vault key = cascade decrypt : root, salt = `<salt>`, label =
  `p7-vault-key 1 wrap`, associated data =
  `p7-vault-key 1 <vault id> argon2id <t> <m> <p> <name>` [ single spaces ]
- a passphrase change rewrites only this file. older COPIES of the file
  still open with the old passphrase

## entry file

binary, inside the base32 block :

```
 0   4  'P7VE'
 4   1  format                 1
 5  10  vault id
15  10  entry id               [ base32 = the file name's <id> ]
25   8  version ntime          [ 14 digit decimal in the file name ]
33   5  version tail           [ base32 = the file name's 8 char tail ]
38  16  salt
54  12  nonce                  outer layer
66  16  tag                    outer layer
82  ..  ciphertext             outer layer, to the end
```

- plaintext = cascade decrypt : root = vault key, salt = `<salt>` [ 16
  bytes, fresh per version ], label = `p7-vault-entry 1`, associated data
  `p7-vault-entry 1 <vault id> <id> <version>`. the ad binds the blob to
  its vault, entry and version : a renamed or swapped file fails to decrypt
- the header ids and version must equal the file name's
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
debian `libcryptx-perl libcrypt-argon2-perl` -- CryptX carries twofish and
gcm too ], or any argon2id + hkdf-sha256 + chacha20-poly1305 + twofish-gcm
implementation [ twofish : CryptX \ libtomcrypt, libgcrypt, botan ; NOT
python's `cryptography` package ] :

1. read `kdf` and the `passphrase` wrap from `vault.key.B32`, derive the root
   with argon2id, cascade decrypt the vault key [ label, ad as above ]
2. for each newest `entries/<id>.*.vlt.B32` : cascade decrypt with the vault key
   as root and the entry's salt, parse the json

`bin/p7-vault -d <copy> verify` does both for every version.

## not in format 1 [ later ]

sync between hosts over protocol-7, a session agent [ unlock once per
login ], the vault-edit form ui, totp code display, purging old versions.

#,,,,,.,.,,..,.,,,.,,,.,.,...,..,,.,,,..,,...,..,,...,..,,.,.,..,,,,.,,,.,.,.,
#2E3PZ3NNJTLMUWSB4ACD32F2MJ6RVBEVE5PF4KYRQWPMMJR4LO5K423I56NZK2DL56CT3TLRS3MOS
#\\\|E66SNQFBLS7ZXDJMH53ZNFYJIPI2Q3LO4HW4WVLGKFUAK4OZJSY \ / AMOS7 \ YOURUM ::
#\[7]TEMA6E6V2GZOVKUACZQQ4ZDRE3Q2T3K2GWR4RP7RADLAIKB2IOBA 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
