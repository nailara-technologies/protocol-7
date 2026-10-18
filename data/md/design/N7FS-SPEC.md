# N7FS : format specification, version 1

the first version need not be perfect -- it must be CONVERTIBLE [ format
version everywhere, converters per step ]. decisions come from the N7FS
entry in data/yaml/todo/base.yaml [ 4EO ] ; this file fixes them so a
second implementation can read a store [ the vault lesson ].

## 1. path layout

```
/N7FS/<disk>/<epoch>/<amos>/<bmw>/<key>[ /... ]
```

- `/N7FS/` : the fixed entry point ; a directory or a symlink, per host
- `<disk>` : the disk-id [ 7-char amos, section 3 ]. the directory under
  /N7FS is always the disk, never a mount
- `<epoch>` : the epoch in its base32 form [ low count, read by value ]
- `<amos>` : 7-char amos checksum of the content ; a collision is not an
  error -- two `<bmw>` siblings under one `<amos>`
- `<bmw>` : the full bmw checksum of the content [ verify-by-path ]
- `<key>` : lowercase key words [ `content`, `chunks/`, `meta/`,
  `references/`, `source`, `signature` .. ] -- depth stays open

every segment is classifiable by SHAPE : base32 epoch, 7-char amos, long
bmw, lowercase key word, decimal ntime. a reader walks any depth without
a schema. `<disk>` and `<amos>` share a shape -- position decides.

addresses are ROOT-FREE : `<epoch>/<amos>/<bmw>` is identical on every
disk ; resolution looks under each attached disk.

## 2. timestamps in paths

- high resolution [ references, mount records, versions ] : DECIMAL
  ntime, the integer part zero-padded to 14 digits, optional `.fraction`
  -- fixed width, so a plain listing sorts in EXACT time order. base32
  ntime sorts too, but with JITTER [ not strictly monotonic at fine
  resolution ] -- fine for coarse grouping, not where exact order counts
- epochs : base32 form as the directory ; the float value [ `epoch-num`,
  e.g. 317.0385507875957 ] is the high-resolution epoch inside records

```
references/<ntime-dec>/<amos>/<bmw>/addr
```

## 3. disk identity

created once at `init` ; stored at `/N7FS/<disk>/.n7fs/` :

```
id.record    magic 'P7FS' + format byte + fields :
             public key [ delegated store key ] , ntime of init ,
             name or type , context intent ,
             parent signature [ e.g. host-root ] over intent + ntime +
             delegated key
id.amos      7-char amos over the record    -> the directory name
id.l13       BMW-L13 over the record        -> proof at link set-up
```

- collision at init : take the next ntime and recompute
- on attach : the directory name must equal `id.amos` recomputed from
  `id.record`, and the parent signature must verify -- else refuse
  [ before any change ]
- one id per FILESYSTEM ; meta records the physical device [ two
  partitions of one drive are no redundancy ]

## 4. mounts and use

- `<mount>` : amos over disk-id + host key + mount ntime ; new per attach.
  full form `<mount>:<disk>`. the mount alone is the local handle
- each attach appends a signed record `.n7fs/mounts/<ntime-dec>.<mount>`
  [ the disk's travel history ] ; the host keeps its own copy
- the witness keeps a signed FIRST-use and LAST-use timestamp per
  identity : equal to last = current, inside [ first, last ) = a genuine
  earlier state [ rollback -- policy ], before first or unsigned =
  foreign. a missing timestamp fails like a failed signature
- clone awareness : one disk-id with diverging signed histories

## 5. writes

- one IMMUTABLE file per version ; sync = union of files
- synced write : tmp + fsync + link \ rename + dir fsync ; read back and
  compare ; a damaged newest version falls back to the older one
- every check happens BEFORE the first change [ refusals never leave a
  half state ]
- secrets enter only as ciphertext [ p7-vault format ]

## 6. format version and conversion

- every binary header : 4-byte magic + 1 format byte
- an upgrade : read the old form, write the new BESIDE it [ e.g. a new
  epoch ], verify, switch -- the old form stays until confirmed
- one converter per version step, chained for older stores

## 7. assimilate

```
assimilate <source paths | index>
```

per file : chunk -> address -> write content + meta [ name, format,
size, mtime, import ntime, source ] -> verify -> replicate to N holders
when configured -> remove the source ONLY after every copy is confirmed.
any failure leaves the source in place. the first source list : the
invoke-web image index [ invoke-web.index.backup_path ].

## open

- chunk size and packing [ small files : inode cost ]
- an optional prefix level for very large `<amos>` directories
- sub-bit distribution and group computation : later layers

#,,.,,,..,,,,,,,.,,.,,.,.,,,.,,,,,,.,,,,,,,,.,..,,...,...,...,,,,,,,.,,,.,,..,
#A3NR5UIIARPGFCUVR6DPDDSGBO2TNI5GS6RB7H2KTXOCJU66VKKXOWOSLOKDZTU3WHAD5JLT3CCF2
#\\\|TT4MBW35DRXM364O4QEMPNQXN2P4OBFCGIZWPGMP76PV7ACGECS \ / AMOS7 \ YOURUM ::
#\[7]ZC2F42G54D4PA7Z73LMQS7KG7ASXYQZXE5T2DCLBAUBUJWIXGKDA 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
