# N7FS format 1 : as built

2026-10-18. the byte-level record of what `bin/n7fs` and
`data/lib-path/pm/AMOS7/N7FS*` write, next to the decisions in
[ `N7FS-SPEC.md` ]. a second implementation reads a store from this file
alone. deviations from the spec are marked **[ deviation ]**, stand-ins
**[ stand-in ]**.

## paths

```
<root>/<disk>/.n7fs/id.record                 parent-signed identity
                    id.amos                   '<disk>\n'
                    id.l13                    '<l13 stand-in>\n'
                    mounts/<ntime14>.<mount>  host-signed attach \ detach
                    state/<ntime14>.state     store format, epochs
<root>/<disk>/<epoch>/<amos>/<bmw>/content
                                  /meta/<ntime14>.<tail8>.meta

<host dir>/stores/<disk>.store.key            delegated store key [ 0600 ]
           mounts/<disk>/<ntime14>.<mount>    the host's copy, same bytes
           witness/<disk>/<ntime14>.use       first \ last use
           trusted-parents                    base32 parent keys, 1 per line
           host.key  parent.key               cli defaults [ key files ]
```

- `<root>` : `/N7FS`, overridden by `-root` or `N7FS_ROOT`. the cli never
  creates it [ a missing root is refused ]
- `<host dir>` : `~/.n/n7fs`, overridden by `-host-dir` or `N7FS_HOST_DIR`
- `<disk>`, `<amos>`, `<mount>` : 7 chars `[A-Z2-7]` ; `<epoch>` : `V7` + 5
  chars -- the SAME 7-char shape as an amos, position decides [ the spec
  expected 'low count' ; the base32 form of base.ntime.epoch_timestamp is
  always 7 chars ]
- `<bmw>` : 77 chars ; `<ntime14>` : decimal ntime, 14 digits zero padded
  [ whole units ; no fraction in format 1 ] ; `<tail8>` : 8 random base32
- temp names end in `.tmp.<8 base32>` and are ignored by every reader ;
  any other unexpected entry makes a reader refuse

## encodings

- base32 : rfc 4648 `A-Z2-7`, no `=` padding
- ntime : `( unix - 1023228000 ) * 4200`, truncated [ AMOS7::NTIME ]
- **bmw** : BMW384 [ Digest::BMW ] of the bytes, base32 -> 77 chars
- **amos** **[ deviation ]** : `amos_chksum( <bmw base32 text> )` -- the
  7-char amos-7 checksum OVER THE BMW TEXT, never over raw bytes.
  reason : `AMOS7::CHKSUM::amos_chksum` decodes non-utf8 input as utf-8
  [ lossy for binary content ] and needs the whole input in memory. rule
  name `amos7-of-bmw384-b32`, kept in the state record. `amos-chksum <
  file` does NOT give an address
- **l13** **[ stand-in ]** : there is no BMW-L13 in an AMOS7 module [ it
  exists as `src/base.chk-sum.bmw.L13-str`, zenka code, and as a script
  copy in `bin/bmw-L13` -- neither importable, neither ported ].
  `id.l13` holds `stand-in:bmw384-b32-head13:` + the first 13 chars of the
  bmw. a converter step replaces it once L13 exists in AMOS7
- **epoch** [ a port of `base.ntime.epoch_dec` + `epoch_timestamp` ] :
  `e = ntime / ( 4200 * 86400 * 365 / 13 )`, `int( e ) mod 385280` ; the
  path form `base32( pack( 'w', 99999999 - int e ) )`. `epoch_num` in meta
  : the float, 13 fraction digits

## records

every record starts with 4 magic bytes + 1 format byte. two containers,
integers big endian :

```
signed : magic[4] format[1] label[n/a*] payload[N/a*] signer_pub[32] sig[64]
plain  : magic[4] format[1] label[n/a*] payload[N/a*]
```

- `payload` : canonical json [ sorted keys, utf-8 ], verified over the
  stored bytes
- `sig` : ed25519 [ rfc 8032 ] by `signer_pub` over every byte before it
- a reader refuses : wrong magic, an unknown format, a wrong label, any
  length mismatch or trailing byte, a payload that is not a json object

| kind  | magic  | label                   | container | signer |
|-------|--------|-------------------------|-----------|--------|
| id    | `P7FS` | `p7 n7fs disk id v1`    | signed    | parent |
| mount | `P7FA` | `p7 n7fs mount v1`      | signed    | host   |
| use   | `P7FU` | `p7 n7fs use window v1` | signed    | host   |
| state | `P7FT` | `p7 n7fs state v1`      | plain     | --     |
| meta  | `P7FN` | `p7 n7fs meta v1`       | plain     | --     |

one label per kind : no signature is valid as another kind, none as a
host-root `p7 delegation v1` statement.

### id.record [ P7FS 1 ]

payload `{ store_pub, init_ntime, name, intent }` : the delegated store
public key [ base32, 32 bytes ], ntime14, name or type [ printable ascii,
1..255 ], intent [ 1..1024 ]. the parent's public key is `signer_pub`.

**[ deviation ]** the parent signs MORE than the spec names [ intent +
ntime + delegated key ] : also name and its own public key -- every field
of the identity is bound.

`<disk>` = amos over the whole record [ signature included ]. init : a
taken `<disk>` under the root -> ntime + 1, sign again, recompute.

the store's secret key is written to the host dir, never into the store
[ a holder cannot sign as the store ]. format 1 does not use it yet.

### mount record [ P7FA 1 ]

payload `{ disk, mount, event, ntime, mount_ntime, host_name }` : event
`attach` \ `detach`, `ntime` = the file name's ntime14, `mount_ntime` = the
attach ntime of that mount [ equal for an attach ]. `mount` =
amos over `pack( 'a7 a32 a14', disk, host_pub, mount_ntime )` -- a detach
carries the handle of its attach. file name `<ntime>.<mount>`.

### use record [ P7FU 1 ]

payload `{ disk, first, last, last_record, last_event }` : ntime14 first
\ last use by THIS host, the file name of the last mount record it wrote.
file name `<last>.use`. only records signed by the current host key count.

### state record [ P7FT 1 ]

payload `{ store_format, epochs, sums, device, written [, previous,
confirmed, converted ] }`. the NEWEST file is the state ; a damaged newest
state refuses [ no silent fallback ]. `device` : st_dev, mount point, fs
type, source of the filesystem below the store [ informational ; one id
per filesystem ].

### meta record [ P7FN 1 ]

payload `{ name, format, size, mtime, import_ntime, epoch_num, source,
host, amos, bmw, disk [, index_chksum, index_name ] }` -- `format` : png
jpeg gif webp pdf by magic, else the lower-case extension, else `unknown`.
`index_chksum` : the invoke-web index's own checksum [ BMW-L13 there,
opaque here ].

### content

the file's bytes, mode 0400. no chunking in format 1 [ spec : open ].

## writes

- a new file : `<path>.tmp.<8>` created O_EXCL, written, flushed, fsynced,
  closed ; `link` to the final name [ fails on an existing name ], else a
  checked `rename` ; the directory fsynced ; read back and compared
- a new directory : every created level's parent fsynced
- a node or a new disk : built under a temp name, published by ONE rename
  after checking the target is absent [ rename onto an empty directory
  succeeds on linux ]
- nothing is ever rewritten : a second import of a content adds a meta
  file ; a state change adds a state file
- **[ deviation ]** the spec lets a damaged newest version fall back to
  the older one. format 1 REFUSES instead for the records that decide
  trust or layout -- the newest state, the newest witness record, any
  mount record : a fallback there is exactly what a rollback or a
  planted file wants. a damaged content node is reported by `verify`
  and refused as a dedup target ; no automatic fallback either

## attach \ detach

checks, all before the first write :

1. `<disk>` has the 7-char shape and is a directory under the root
2. id.record parses ; `amos( id.record ) == <disk> == id.amos` ;
   `id.l13` matches ; the parent signature verifies ; with anchors
   [ `-trust`, `trusted-parents` ] the parent key must be one of them --
   **without anchors the parent is trust on first use**
3. every mount record parses, verifies, matches its file name and
   recomputes its mount handle -- one bad record refuses
4. the witness window [ below ]
5. attach : this host's newest record is not an attach ; detach : it is

writes : the disk's record, the host's copy, then the witness. the new
ntime is above the disk's newest record and the witness's last.

### window [ the presented state = the disk's newest record ntime ]

| presented vs witness                 | result                     |
|--------------------------------------|----------------------------|
| no witness record                    | first contact [ accepted ] |
| = last                               | current                    |
| > last, last record in its history   | travelled                  |
| >= last, last record NOT in history  | refused : diverging clone  |
| inside [ first, last )               | refused : rollback [ `-allow-rollback` ] |
| < first [ incl. a wiped history ]    | refused : foreign          |
| witness unsigned \ field missing     | refused                    |

## assimilate

per source : lstat [ symlinks and non-regular files skipped ] -> open
O_NOFOLLOW, fstat must equal lstat -> hash [ bmw + size ] -> address in
the write epoch -> new node built + published, or the existing node
verified and a meta file added -> the stored node verified [ full re-hash
] -> the source re-hashed, dev \ inode \ size \ mtime unchanged -> ONLY
with `-remove` : lstat once more, then unlink. default KEEP. any failure
: the source is untouched, a temp node is removed, the entry reported
`failed`. `-dry-run` hashes and lists, writes nothing. never taken as a
source : anything inside the root, the host dir [ keys, witness -- a
holder must not get the store key, a removal must not reset the use
window ] or a configured key file. replication to N holders is NOT in
format 1. secrets are NOT detected : 'secrets enter only as ciphertext'
is not enforced -- assimilating `~/.ssh` stores the keys as they are.

write epoch : the current epoch, never older than the newest active one
[ after a conversion ], never one of `previous`.

`-index <db>` : the `sources` table of the invoke-web image index
[ `src/invoke-web.index.db` ], opened read-only ; rows without a checksum
or with a relative path are skipped and listed. rows are untrusted : with
`-remove` an `-index-base <dir>` is required, rows resolving outside it
are skipped.

the amos collision test uses two real fixtures found offline [ a bounded
single-process search ] : `n7fs amos collision fixture 2042` and
`n7fs amos collision fixture 8794` share the 7-char amos `FKMWSSI` over
different BMW384 digests -- two `<bmw>` siblings under one `<amos>`.

## conversion

a converter step = `register_step( from, transform )` + the target format's
codec [ `read_node`, `write_node`, `verify_node`, `write_meta` ]. upgrade :

1. refused while a previous upgrade is unconfirmed
2. a confirmed previous is released once it leaves the window [ below ] ;
   while it is still in the window the upgrade refuses
   [ 'still in the window' ]
3. the chain of steps from the store format
4. every old node verifies and reads [ before any write ]
5. the new form is written into NEXT of the {previous, current, next}
   epoch window [ `data/tasks/epoch-validity-search-protocol.md` ;
   `src/base.ntime.epoch_dec` : previous = current - 1, next =
   current + 1, wrapping at 0 \ 385280 -- never raw arithmetic ] -- the
   current epoch may hold data, that is the point of the window.
   `-epoch <n>` stays as a test override ; a target that belongs to the
   store already refuses
6. each node : transformed through the chain, written under the next
   epoch [ temp + publish ], verified ; then the whole new epoch
   re-listed and verified
7. the switch : a new state `{ store_format: new, epochs: [ next ],
   previous: { old }, confirmed: false }`
8. any failure before 7 removes the new epoch [ created by this run ] ;
   the state stays on the old format

`confirm` re-verifies the new form and records `confirmed`. while the old
epoch is the window's previous the old form stays on disk, readable ; a
later `upgrade` \ `confirm`, once the window moved, releases it -- the
directory is removed and the state forgets `previous`. the old form is
released only after a confirmed switch. format 1 ships no step -- the
proof is `bin/test-scripts/test-n7fs-convert.pl` [ a test-only format 2 ].

## the parent signer plug [ host-root ]

the signer interface is `public()` [ 32 bytes ] + `sign( msg )` [ 64
bytes ] ; secret key bytes never cross it. `-parent-cmd '<argv>'` runs an
external signer, list-form exec, no shell : `<argv> public` prints the
base32 public key, `<argv> sign <label>` reads the base32 message on stdin
and prints the base32 signature. host-root plugs in as a v7-zenki command
behind p7c [ e.g. `-parent-cmd 'p7c v7-zenki.n7fs-sign'` -- not written
yet ] that MUST accept only the n7fs labels above : host-root never becomes
a general signing oracle. anchors then = the host-root public key.

## open

- bmw width : BMW384, the decision after version 1
- the amos rule [ over the bmw text ] -- or a streaming amos of the raw
  bytes in AMOS7::CHKSUM
- BMW-L13 at the AMOS7 level [ replaces the stand-in through a step ]
- chunking, packing small files, a prefix level for large `<amos>` dirs
- what the store key signs [ meta, nodes ]
- witness beyond this host [ the network's view, spec section 4 ]

#,,..,,..,.,,,,..,.,.,.,,,.,.,.,,,,.,,..,,,,,,..,,...,...,..,,...,,,.,..,,,,,,
#EKWW4P2RPS7ERL662M4CHYWJI62OCWKV6CHF7NVMW5JRSVKHH25GQURENEFXMKATQU5SHPQ45COQQ
#\\\|ORRGILKQIE3PHISED7XBFONYC5L3TE2TPK2UFBIUTXKAXPAX5XD \ / AMOS7 \ YOURUM ::
#\[7]FFDC2GQL2P7XNUFVABYEHFDKJNONZEYHHSU6YKETJ5PRGEH7WMDY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
