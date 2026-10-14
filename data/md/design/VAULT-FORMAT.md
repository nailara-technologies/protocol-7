# vault format : p7-vault 1

2026-10-09. the personal vault [ logins, notes, contacts ] behind
`bin/p7-vault` and `data/lib-path/pm/AMOS7/Vault.pm` [ + `AMOS7/NTIME.pm` ].
this file is the recovery reference : copy it next to every backup of a
vault, together with those three files
[ layout : `p7-vault`, `AMOS7/Vault.pm`,
`AMOS7/NTIME.pm` in one directory ]. the 3-char entry codes
additionally use `AMOS7/CHKSUM.pm` with its AMOS7 dependencies, the note
editor `AMOS7/TERM/Editor.pm` -- both only for interactive use, the
three files above open every vault on their own. everything below uses
standard
primitives only, so a vault opens without protocol-7 -- with the script, or
by hand from this text.

## directory

```
<vault>/            0700   default ~/.n/vault [ P7_VAULT_DIR ]
  vault.key.B32     0600   key file : vault id, kdf, wrapped vault key
  entries/          0700
    <id>.<version>.vlt.B32   one file per entry VERSION, never rewritten
  blobs/            0700
    <name>.vlb      one file per file CONTENT, never rewritten
```

- `<id>` : 16 base32 chars [ 80 random bits ]. file names carry no title,
  url or user name -- the list of sites stays private even in a public copy
- `<version>` : `<ntime, 14 decimal digits>.<8 base32 chars>`. sorted as
  text = sorted in time. the random tail keeps two devices that edit the
  same entry offline from colliding ; a sync is a plain union of files
- an edit or a delete ADDS a version. the newest version is the entry ;
  a newest version with `"deleted":1` hides it. nothing is overwritten,
  `restore` writes an older version again as the newest
- harmony : generated values that name files [ vault id, entry ids,
  version tails ] or that the owner sees [ the recovery code -- grouped AND
  plain form --, generated passwords, entry codes ] are drawn again until
  `AMOS7::Assert::Truth::is_true` accepts them [ ~28 % pass ; < 4 of the
  recovery code's 160 bits ]. only generating needs that module : reading
  never checks harmony, so a copy without it opens every vault [ and
  generates unfiltered ]

## encodings

- base32 : rfc 4648 alphabet `A-Z2-7`, upper case, no `=` padding
- network time [ ntime ] : `( unix seconds - 1023228000 ) * 4200`
  [ 1023228000 = 2002-06-05 ]. decimal in version names, an unsigned
  64 bit integer in the key file ; the record's `updated` : base32 of perl
  `pack( 'w', <integer ntime> )` [ ber compressed integer ], the same
  stamps as protocol-7 logs [ `bin/ntime <stamp>`, no backend needed ]
- every file is ONE base32 block in protocol-7's inline format [ the
  frame of the inline subroutines in `bin/Protocol-7`'s `__DATA__` ], in
  its one-entry-per-file form : every frame line space-prefixed [ 2026-10-11 ]

```
 .:[ p7-vault entry ]:.                  [ 'p7-vault key' in vault.key.B32 ]
 :
 : <75 base32 chars>                      payload lines : ' : ' + 75 = 78
 : 0000<last chars>0000                   short last line centred with '0'
 :.
```

  the payload closes directly with ` :.` -- a bare ` :` line after the
  payload would announce further elements or metadata [ as the size and
  checksum line of the inline subroutines ], and a vault file has none.
  files written before 2026-10-11 use the column-0 frame with 76 chars per
  line and a `:` line before `:.` ; they stay valid. the key file and
  archives get the new frame on their next write ; entry versions are
  never rewritten, so older versions keep the older frame.

  reading : take every line matching `^\s*: ([0-9A-Z]+)\s*$` [ any
  indentation, both frames, crlf ], keep the captured characters, delete
  every `0` and `1` [ outside the base32 alphabet ], join, base32 decode.
  the result is the binary layout below. integers are big endian

## cascade : two ciphers, every layer of the file

the key file and every entry version are encrypted twice, with independent
keys -- a break of either cipher alone reveals nothing and changes nothing.
the key file is cascaded too : with only the entries cascaded, breaking
chacha20 on `vault.key.B32` would yield the vault key and with it both layers.

`cascade( root, salt, label, ad, plaintext )` :

- twofish key \ nonce = hkdf-blake2b-512 [ rfc 5869 with blake2b, 64 byte
  output -- the hash argon2id is built on ; no sha-2 anywhere ] : key
  material = root, salt = salt, info = `<label> twofish-gcm`, 44 bytes ->
  key = bytes 0..31, nonce = bytes 32..43
- chacha key = hkdf-blake2b-512 : key material = root, salt = salt,
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
hkdf-blake2b-512, which both layers' keys pass through.

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
  ignored, `0 1 8` read as `O L B` ], `passphrase-file` [ a passphrase
  plus any file the owner picks -- see archive ]
- root = argon2id [ rfc 9106, version 0x13 ] of the secret [ utf-8 bytes ;
  the recovery code in its normalized form ; for `passphrase-file` : the
  file's length [ 4 bytes ], the file's bytes, then the passphrase -- no
  hash before argon2id ], salt = `<salt>` [ 16 bytes ],
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
{ "type": "login", "code": .., "title": .., "url": .., "username": ..,
  "password": .., "totp": .., "notes": .., "updated": "<ntime base32>"
  [, "deleted": 1 ] }
```

types and fields : `login` [ title url username password totp notes ],
`note` [ title body ], `contact` [ title name phone email address notes ],
`file` [ title blob size origins ]. absent fields are left out. unknown
fields are kept as they are.

- `file` records a stored file's content : `blob` is the blob name [ the
  content's keyed mac, below ], `size` its plaintext length, `origins` a
  list of `{ host, path, mode, uid, gid, user, mtime, imported }` --
  every import of the same content on a new host+path appends one origin
  as a new entry version. deleting a `file` entry leaves its blob :
  other entries may share it, and a garbage collection of unreferenced
  blobs is out of scope for format 1
- an archive [ `p7-vault import -a <dir> [ -x <glob> ]...` ] is a `file`
  record of a different shape : `archive` is `tar`, `blob` names the tar
  stream of the whole directory [ archived with the recorded `--exclude`
  globs, kept in `excludes` ], `size` its bytes, `origins` holds the one
  directory. archives do NOT dedup -- the blob name is random, so two
  imports of the same directory are two blobs. the random name reveals
  nothing about the content and the stream is read once, so the
  keyed-mac name of a plain import is neither possible nor needed.
  unreadable paths refuse the import before anything is written ; with
  `-i` they are left out as exact member names and listed in `skipped`
  [ an export names them : the archive is not the whole directory ]. a
  tar failure [ exit >= 2 ] saves no entry and removes its stream blob
  at once -- unreferenced and never synced, nothing else could hold it

- `code` : the 3-char display code of the entry [ bin/todo's chk3 shape :
  a random seed through AMOS7::CHKSUM, 3 chars ], collision-checked
  against the codes of all live entries and harmony-checked like the
  other generated values. it lives INSIDE the encrypted record, never
  in a file name -- the list of sites stays private in a public copy.
  every record carries one : an entry saved without it [ a vault
  written by an older p7-vault ] gets it on its next save, and
  `p7-vault codes` assigns codes to all entries lacking one [ one new
  version each ]. an exact 3-char code match resolves an entry before
  any title rule

## blob files : stored file content

`p7-vault import` stores a file's content as one blob : `<name>.vlb` in
`blobs/`, binary. `<name>` : 32 base32 chars [ no padding ] of the first
20 bytes of a keyed blake2b-256 mac [ rfc 7693 ] over the content,
streamed 1 MiB at a time. the mac key = hkdf-blake2b-512 : key material
= vault key, salt = `p7 blob name`, 32 bytes, info = `p7 blob name key`.
a plain content checksum is NOT allowed -- with one, anyone holding the
blob directory could confirm a known file. the key is vault-bound, so
the same content names differently in two vaults, and deterministic, so
one vault deduplicates to one blob

```
 0   4  'P7VB'
 4   1  format                 1
 5   4  chunk size             N, big endian, 1048576
 9  ..  chunks, back to back, until eof
```

chunk i [ from 0 ] holds up to `chunk size` bytes of the plaintext. the
file is read one chunk at a time -- the whole file is never in memory.
the import walks the file twice : first the name mac, then the
encryption, and aborts when size or mtime changed between the
passes. a STREAM import [ `blob_import_stream`, the archive path ] is
single pass with a RANDOM 32-char name instead -- no mac, no dedup [
see the archive record, above ]; the chunk frames, the chunk keys and
the write are exactly the same

- blob key = hkdf-blake2b-512 : key material = vault key, salt =
  `<name>`, 32 bytes, info = `p7 blob key` -- deterministic, so the same
  content in one vault is one blob
- chunk i encrypts its plaintext with the cascade : root = blob key,
  salt = `pack( 'N C', i, <last> )`, label `p7 blob chunk`, associated
  data `P7VB <format> <vault id> <name> <i> <last>` [ single spaces ].
  `<last>` is 1 only on the final chunk ; an empty file is one empty
  chunk with last = 1. the twofish nonce is derived with the key, and
the blob key and the salt are fixed for a given chunk -- safe only
because the same content encrypts to the same chunk : never reuse the
scheme with a per-file random salt
- stored per chunk : `pack( 'N', length <ct> )` , nonce [ 12 ] ,
  ciphertext , tag [ 16 ] -- the outer chacha20-poly1305 frame
- `<last>` is not stored in the frame : it is read out of the position
  [ a final chunk that is not at eof, or eof before a final chunk, fails
  the tag or reads as truncation ]
- decrypting : sequential, the index from the position. rejects : bad
  magic or format, a chunk failing either layer, a final chunk not at
  eof, eof without a final chunk [ truncation ], trailing bytes
- a blob writes like an entry : a temp file inside `blobs/`, synced,
  then renamed only when the target is absent. an existing blob of that
  name means deduplication -- nothing is written
- written by root into a vault a user owns [ `sudo p7-vault -d
  ~user/.n/vault` ] : every new file and directory takes the owner of the
  directory it is created in, so the user keeps reading and writing it.
  nothing changes for other users or a root-owned vault

## archive : one file for untrusted copies

the vault directory shows how many entries exist and when each was edited
[ the file names ]. for copies in untrusted places -- the public DATA repo
above all -- `p7-vault archive <file>` writes ONE file that shows neither.
`p7-vault -d <dir> restore-archive <file>` makes a working vault of it
[ a new directory, or the same vault : missing versions added, nothing
replaced, an existing key file kept ].

same base32 block, title `p7-vault archive`. binary inside :

```
 0   4  'P7VA'
 4   1  format                 1
 5   4  key file length
 9  ..  key file               the binary key file, IN THE CLEAR, with ITS
                               OWN choice of wraps [ below ]
 ..  16  salt
 ..  12  nonce                 outer layer
 ..  16  tag                   outer layer
 ..  ..  ciphertext            outer layer, to the end
```

- the key file in an archive carries, by default, ONLY the `recovery`
  wrap : 160 random bits, a public copy cannot be brute forced through it.
  `archive -f <file>` adds a `passphrase-file` wrap [ asked for anew ; the
  file's git blob id is shown, base32, for the owner's notes ] ; `-p`
  keeps the plain `passphrase` wrap [ a weak passphrase stays exposed ].
  one version of one file in protocol-7's history [ ~106000 of them ]
  adds ~17 bits : every passphrase guess costs ~100000 argon2id runs
- payload = cascade decrypt : root = vault key, salt, label
  `p7-vault-archive 1`, associated data `p7-vault-archive 1 <vault id>`
- payload layout : `'P7VP'`, record count [ 4 ], then per record : name
  length [ 1 ], name [ the entry file name ], data length [ 4 ], data [ the
  entry file's binary content ], then zero filler. every version of every
  entry is in it
- size classes : the payload is filled to 13312 bytes, times 3 while it
  does not fit [ the keys archive's classes ]. a few entries more or less
  do not change the size
- a restore takes only names of the entry file form, checked before the
  first write ; a different vault id in the target is refused

**a public copy keeps every archive ever pushed** [ git history ] :

- a later passphrase or recovery code change does NOT protect older
  archives there -- a weak or exposed passphrase stays exposed for them
- each archive still shows its size class [ coarse growth ] and, through
  the commit, when it was made

## sync : a manual union of the entry and blob files

`p7-vault sync <ssh-host>[:<remote dir>]...` [ several hosts : one after
the other, a refused one does not stop the rest ] unites a vault with a copy on
another host [ remote dir default : `.n/vault` in the remote home ].
entry version and blob files are opaque and never change, so a sync is a
plain file union -- never overwrite, never delete. `entries/` and
`blobs/` unite with the same rules, reported on two lines :

- ONE ssh call [ the command comes from `P7_VAULT_SSH`, default `ssh`,
  so ControlMaster or a wrapper can stand in ] lists the remote vault id
  [ read out of the remote key file, which sits in the clear ], the
  remote `entries/` names with their sha1 sums [ the conflict check --
  the probe hashes entries with `find entries -maxdepth 1 -type f -exec
  sha1sum {} +`, no shell glob ] and the `blobs/` names ALONE : a blob
  name is a keyed mac or random, so the same name IS the same content
  and blobs are never hashed. a different vault id is refused ; no
  remote vault is refused with a hint to copy the key file first
- push : local files missing remotely travel as ONE tar stream over
  ssh per directory kind, the validated names in a temp list file [
  `tar -C <dir> -cf - -T <list>` ], extracted into a temp dir inside the
  remote vault, and each file is moved into the remote `entries/`
  \ `blobs/` only when absent. pull : the same the other way -- the name
  list goes to the remote on ITS stdin [ `tar -cf - -T -` ], the local
  tar extracts only the listed names, then the vault's own
  write-new-file rule [ temp file, checked rename, directory sync ] per
  file. no file list ever sits on a command line [ E2BIG at some 100k
  names ]
- only names matching the entry \ blob file pattern are transferred
  [ strict regex on both sides -- a hostile remote name never reaches a
  path join ]. a file present on both sides with different content is
  reported as a conflict and left alone ; identical content needs no
  transfer at all, so a second sync moves nothing
- the key files are NEVER transferred. differing key file content means
  a passphrase change on one side : a warning says to copy
  `vault.key.B32` over by hand, once. no unlock is needed -- the files
  are opaque
- report : `pushed n, pulled m, conflicts k` for the entries, then the
  same for the blobs

## opening a vault by hand

needs perl with CryptX >= 0.088 [ or CryptX + Crypt::Argon2 :
debian `libcryptx-perl libcrypt-argon2-perl` -- CryptX carries twofish and
gcm too ], or any argon2id + hkdf-blake2b-512 + chacha20-poly1305 +
twofish-gcm implementation [ twofish : CryptX \ libtomcrypt, libgcrypt,
botan ; NOT python's `cryptography` package ] :

1. read `kdf` and a wrap from `vault.key.B32` [ `passphrase`, or from an
   archive `recovery` \ `passphrase-file` ], derive the root with argon2id,
   cascade decrypt the vault key [ label, ad as above ]
2. for each newest `entries/<id>.*.vlt.B32` : cascade decrypt with the
   vault key as root and the entry's salt, parse the json
3. for a stored file [ a `file` record ] : name the blob as above, blob
   key = hkdf [ salt = name, info `p7 blob key` ], then cascade decrypt
   each chunk in order [ salt, label, ad as above, last from the
   position ] and concat the plaintext chunks

`bin/p7-vault -d <copy> verify` does both for every version. from an
archive : take the key file out of its header for step 1, cascade decrypt
the payload with the vault key, then step 2 for each record's data.

## not in format 1 [ later ]

a session agent [ unlock once per login ], the vault-edit form ui,
totp code display, purging old versions.

#,,.,,...,.,.,..,,.,,,,..,.,,,,,,,..,,,,.,.,,,..,,...,...,,..,,,.,..,,,,.,,,,,
#MPDPCYAP56R6UCETK55APLSWERDC2W5ZH2Z7K2LEGMVFZBTDDXPPBFP5B4O3TWR246MJQUDKYPDWI
#\\\|NFOP6XPDG3SK7WMTXYB7R6Y64I7UYJUW4V7EMLD6JOPZOM3CU5G \ / AMOS7 \ YOURUM ::
#\[7]HCU3VVH4R4ITX4TPTQA6E5GUU6U4YP4R6DVKSPYADW3U75C7EUAI 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
