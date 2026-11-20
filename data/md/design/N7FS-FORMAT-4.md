# N7FS format 4 : no json anywhere, and the way there

2026-11-16. design only. nothing here is built, nothing live is changed by
it. it names the json that format 3 still carries, fixes one canonical record
form for all of it, and lays out a migration for a live store with four sealed
remote holders.

marks used below : **checked** = read in the code or measured for this
document ; **assumed** = follows from the design documents, to be confirmed by
the stage that touches it.

sources : `N7FS-FORMAT-3.md`, `N7FS-SPEC.md`, `N7FS-SEALING.md`,
`N7FS-SYNC.md`, the modules below `data/lib-path/pm/AMOS7/N7FS/` [ read
only ], `RESOURCE-ACCOUNTING-UNIFIED.md` [ section 5, canon form ;
contradiction 12 ; owner question 13 ], `SUBSTRATE-SYNTHESIS.md`
[ contradictions 16, 17 and 21, owner question 12 ].

revised the same day, after the owner's answers to questions 1, 5 and 17,
the K3.1 review of the synthesis, and two commits :

- **decided** [ owner ] : this canon form is also the ledger journal form,
  unless a better matching one is found [ 1 ] ; both disk upgrade paths are
  offered, through the epoch window and in place with stable addresses [ 5 ] ;
  receipts move to the new form before the ledger's stage 2 [ 17 ]
- **new in this revision** : section 2.5 is a decision, no longer a proposal ;
  the in-place path and its rollback [ section 4.3.3 ] ; the switch to the
  exact epoch grid as a versioned step [ section 4.6 ] ; a recommended home
  for the shared parser [ section 5, question 2 ]
- **facts used** : `AMOS7::cell::time` is the exact Y grid [ 3bef478fe ] ;
  the float `epoch_int` \ `epoch_num` differ from it at 10082 level 1
  boundaries of the 385280 wrap, the first about 13.5 years ahead

words shared with the two other documents : the **canon form** is section 2
of this document ; a **kind table** is the fixed key list of one kind and
version ; a **frame** is an index on the exact Y grid, an **epoch** is the
level 1 frame modulo 385280, a **window** is the three valid epochs ; a
**cell** is the shape of `SUBSTRATE-SYNTHESIS.md` section 1.

## 1. what is json today

**checked** : 116 lines in 12 modules name the codec, plus `bin/n7fs`
[ relay lists, a second copy of the `Cycle.pm` code ] and `bin/n7fs-push`
[ reads the relay list on the holder ]. 13 test scripts below
`bin/test-scripts/test-n7fs-*` build or read json. `bin/n7fs-receive` holds no
json of its own ; it reaches it through `Receiver.pm`.

the largest single fact : **every signed disk record is json inside a binary
container.** `signed_record_pack` in `N7FS.pm` writes magic, format byte,
label, a canonical json payload, the signer key and the signature. so the 17
record kinds of the store are json, although only `Journal.pm`,
`Reference.pm` and `Convert.pm` show it [ through `JSON::PP::true` ].

38 record kinds, by where they live :

| # | kind | written \ read in | role | signed | hashed | sealed |
|---|---|---|---|---|---|---|
| 1 | `id` | `Disk.pm` | disk identity | parent key | **the disk id is the amos checksum of the record bytes** | no |
| 2 | `mount` | `Disk.pm` | attach \ detach history, disk and host copy | host key | no | no |
| 3 | `use` | `Disk.pm` | witness : first \ last use, highest format, `journal_seq` | host key | no | no |
| 4 | `state` | `Disk.pm` | store format, epochs | store key [ plain in format 1 ] | no | no |
| 5 | `meta` | `Store.pm` | one per import : name, size, mtime, `epoch_num` [ a float ] | store key [ plain in format 1 ] | no | no |
| 6 | `journal` | `Journal.pm` | expected-set operations | store key | `prev` = BMW384 of the exact bytes of the entry before | no |
| 7 | `reference` | `Reference.pm` | live source reference | store key | no | no |
| 8 | `drop` | `Reference.pm` | reference drop | store key | no | no |
| 9 | `tombstone` | `Release.pm`, `Sync.pm` | released address | store key | no | no |
| 10 | `tree` | `Tree.pm` | named tree, names its manifest address | store key | no | no |
| 11 | `tree_drop` | `Tree.pm`, `Release.pm` | tree removal | store key | no | no |
| 12 | `category` | `Category.pm` | versioned policy | store key | no | no |
| 13 | `assignment` | `Category.pm` | per-reference category | store key | no | no |
| 14 | `batch` | `Batch.pm` | batched assignments | store key | no | no |
| 15 | `sync_cursor` | `Sync.pm` | per-source position | store key | `source_hash` = BMW384 of a source journal entry's bytes | no |
| 16 | `sync_conflict` | `Sync.pm` | unresolved concurrent change | store key | no | no |
| 17 | `hold` | `Hold.pm` | pre-change restore hold | store key | no | no |
| 18 | tree manifest | `Tree.pm`, `Sync.pm`, `Seal.pm` | json lines, one entry per path | no | **it is a content node : its address is BMW384 of its bytes** | as a node |
| 19 | seal-root binding | `Seal.pm`, `Drill.pm` | binds a disk to a sealing root | root key, over `disk \0 root_id` [ not over the json ] | no | no |
| 20 | sealed head | `Seal.pm` | root id, writer, version, map, journal, peers | root key, **over a re-serialization**, no label ; plus the binary exterior signature | no | yes |
| 21 | map root | `Seal.pm` | categories, retention, pins, superseded, shard descriptors | by the head | BMW384 of the plaintext in its descriptor | yes |
| 22 | map shard | `Seal.pm` | up to 1024, node address -> entry. **the hot path** | by the map root | same | yes |
| 23 | map tree blob | `Seal.pm` | tree table when over 1 MiB | by the map root | same | yes |
| 24 | manifest index | `Seal.pm` | chunk list of one sealed tree manifest | by the map | same | yes |
| 25 | manifest chunk | `Seal.pm` | decoded manifest entries of one directory slice | by the index | same | yes |
| 26 | sealed journal | `Seal.pm` | writer, version, map, operation | by the head | no | yes |
| 27 | receipt | `Placement.pm` | holder-check result | root key, **over a re-serialization** | coverage digest inside | no |
| 28 | drill record | `Drill.pm` | restore drill result, one line each in `drills.json` | root key, **over a re-serialization** | no | no |
| 29 | covered cache | `Placement.pm` | addresses a receipt covered | no | bound by the receipt digest | no |
| 30 | seal state | `Seal.pm`, `Keys.pm` | writer id, version, holders, last time | no | no | no |
| 31 | version reservation | `Seal.pm` | next head version, written before use | no | no | no |
| 32 | pending node key | `Seal.pm` | node id and wrapped keys of an upload in flight | no | no | wrap inside |
| 33 | request counter | `Receiver.pm` | home side counter per root and holder | no | no | no |
| 34 | relay pending list | `Cycle.pm`, `bin/n7fs` | blobs still to relay | no | no | no |
| 35 | vault registry note | `Placement.pm` | holder registry of a vault root | no | no | in the vault |
| 36 | root file header | `Keys.pm` | argon2id parameters and salt in `P7RK\x01` | no | no | no |
| 37 | holder request token | `Receiver.pm`, `bin/n7fs-receive` | a signed change request, parsed on the holder | root key, over `domain \0 json` | no | no |
| 38 | relay list | `Cycle.pm`, `bin/n7fs`, `bin/n7fs-push` | blob names on the holder | by `put-list` | no | no |

already free of json and unchanged here : the holder registry and the cycle
config and state [ p7 config style, 3e613a33a ], the sealed registry copy, the
holder side counter [ one decimal line ], the holder session protocol, and the
binary records `P7SW`, `P7SB`, `P7SP`, `P7SH`.

four findings that shape the design :

1. **signatures over a re-serialization.** receipts, drill records and the
   inner head signature are checked by decoding the json and encoding it again
   [ **checked** : `receipt_fresh`, `_record_verify`, `_head_open` ]. this is
   sound only while every codec writes the same bytes for the same value, a
   number that became a string breaks it. the benchmark for this document hit
   exactly that. format 4 signs and checks stored bytes only.
2. **a content address over json bytes.** the tree manifest is a node. the
   sealed side stores decoded entries and rebuilds the manifest by encoding
   them again, then compares the address [ **checked** : `_manifest_verify` ].
   a changed manifest form is a new node and a new tree record, not a re-wrap.
3. **the disk id is made of json bytes.** the id record cannot be rewritten
   without a new disk identity.
4. **content blobs carry no json.** a node blob is named by BMW384 of its
   ciphertext and its keys are random. a holder moves to the new form by new
   map blobs and a new head. no content byte is sealed or sent again.

## 2. the canonical form

one form for every record : the **canon form**. it is also the form of the
ledger journal [ owner, question 1 ; `RESOURCE-ACCOUNTING-UNIFIED.md` section
5 defines no bytes of its own any more ], so one parser serves the n7fs
records, the ledger journal and any later log. what is shared is the parser
and the signed envelope, not the rules of a journal [ section 2.5 ].

### 2.1 anatomy

    p7 n7fs journal v4
    disk  = <disk id>
    seq   = 1042
    prev  = <address of entry 1041>
    was   = 0
    flags = -
    rows  = 3
    body  = <BMW384 of the body bytes>
    pub   = <signer key>
    sig   = <signature>

    + node V7AAAAA/BBBBBBB/<bmw>
    + meta V7AAAAA/BBBBBBB/<bmw> 00031703855078.ABCDEFGH.meta
    - release V7AAAAA/CCCCCCC/<bmw>

a record is a **head** and an optional **body**.

- the head is the label line, then field lines, then one empty line
- the body is row lines up to the end of the container. a record with a body
  is the only record in its file or blob. records without a body may follow
  each other in one file [ a journal file, the drill log ]

### 2.2 exact bytes of the head

- octets are UTF-8, in practice ASCII : every byte of a head is `0x0a` or
  `0x20` to `0x7e`. no CR, no tab, no BOM
- **label line** : `p7 <domain> <kind> v<number>` and LF. it is stored, it is
  the first line, and it is the magic of the record
- **field line** : key, padding, ` = `, value, LF. the key is
  `[a-z][a-z0-9-]*`. padding is spaces up to the longest key **of that kind
  and version**, so the separators stand in one column and the width is fixed
  by the kind table, never chosen by a writer
- **value** : one or more bytes `0x21` to `0x7e`, single inner spaces allowed
  only in the type `text`. never empty, no leading or trailing space
- every kind and version has a fixed list of keys in a fixed order. all are
  required. an unknown key, a missing key, a repeated key, another order,
  other padding, a second space, a missing final LF : each is refused
- the head ends with exactly one empty line
- a reader checks a head by parsing it and packing it again : the bytes must
  be equal. heads are small, this costs nothing

value types, each with one spelling :

| type | spelling |
|---|---|
| `count` | decimal, no sign, no leading zeros : `0` or `[1-9][0-9]*` |
| `stamp` | whole ntime as exactly 14 digits [ the `ntime14` of paths ] |
| `decimal` | `<count>.<digits>`, copied as text and never computed again [ `epoch-num` ] |
| `word` | a name with its own pattern in the kind table [ disk id, category, operation ] |
| `address` | `<epoch>/<amos>/<bmw>`, or a BMW384 base32 of 77 characters |
| `key` \ `sig` | base32 of 32 \ 64 bytes |
| `octets` | base32 of raw bytes [ the project's `b32`, upper case, no padding ] |
| `text` | written bare when the bytes are `0x20` to `0x7e`, do not begin or end with a space, do not begin with `:` and are not `-` ; otherwise `:` and the base32 of the bytes. a reader refuses the `:` form when the bare form was allowed |
| `list` | words joined by `,`, sorted by bytes, no repeats |
| `flags` | a `list` of the flag words of the kind |

absent values : `0` for a count or an address [ as the ledger writes
`prev = 0` ], `-` for everything else, and for an empty list. a kind whose
word pattern would admit a bare `-` refuses that one name.

there are no booleans, no floats and no nesting in a head. a json `true`
becomes a flag word. a nested object becomes keys with a common prefix
[ `origin-disk`, `origin-id` ] or a body.

### 2.3 exact bytes of the body

- one row per line : fields of bytes `0x21` to `0x7e`, separated by exactly
  one space, closed by LF. no empty line, no trailing space, no empty field
- two body shapes, fixed by the kind :
  - **table** : every row has the same columns. the head names them in
    `columns`, the reader refuses any list but the one it knows. rows are
    sorted by bytes and the first column is unique, so a repeated key is
    refused by the same comparison that checks the order
  - **operations** : the first field is a class word [ `+ node`, `- release`
    are sign and class ], the field count is fixed per class, rows keep the
    order the writer gave them. a kind may fix the order in its kind table
    instead, and a reader then refuses any other [ the ledger `transaction`
    does : `-` rows before `+` rows, each group sorted by bytes ]. a class
    may be the bare sign
- inside one field `,` separates items and `:` separates the two parts of a
  pair, both sorted by bytes : `incoming:<wrap>,photos:<wrap>`
- a field that may hold any bytes is `octets`, always base32, with `-` for
  none. there is no bare form in rows : one spelling, no test on the hot path
- the head binds the body : `rows` is the row count, `body` is the BMW384
  base32 of the body bytes, `0` and `rows = 0` when there is none

### 2.4 what a signature covers, what an address is

- **signed bytes** : the label line with its LF, then every head line before
  `sig`, each with its LF. `pub` is the line before `sig` and so inside. the
  body is covered through `body`. the kind and its version are inside through
  the label, so a signature never fits another kind, version or domain
- the signature is ed25519, `sig` is its base32
- a signature is always checked over the **stored** bytes. nothing is decoded
  and encoded again to check anything
- **address of a record** : BMW384 base32 over the stored head from the label
  line through the LF of the `sig` line [ through the last field line for an
  unsigned kind ]. the closing empty line and the body are not in it ; the
  body is in it through `body`
- `prev` is the address of the record before, `0` for the first

sealed plaintexts [ head, map, shards, manifests, sealed journal ] use the
same form inside the unchanged two-layer suite. their descriptors keep
`checksum` = BMW384 of the plaintext. the sealed head keeps both signatures :
the inner one now over stored bytes with a label, the binary exterior one as
built.

### 2.5 one form with the ledger [ decided ]

owner, 2026-11-16 : this form **is** the ledger journal form, unless a better
matching one is found. the ledger text names this section and adds only its
kind tables [ `RESOURCE-ACCOUNTING-UNIFIED.md` section 5 ].

what the ledger took over, each a difference to its first text :

1. **the label line is stored** : `p7 nrt <kind> v1` is the first line of
   every ledger record. the ledger computed it from a `kind = ` line and
   stored no version. a stored label is magic, domain separation and version
   in one line
2. **padding is part of the form** : aligned to the longest key of the kind
   and version. the ledger text said exactly one space on each side of `=`,
   and its acceptance check refused two ; that check is turned around
3. **`pub` stands before `sig`**, inside the signed bytes. the ledger
   resolved the signer from the kind and stored no key. it still resolves
   it : replay compares the stored `pub` with the key the kind's signer rule
   names and refuses another. `pub` says who signed ; it authorizes nothing
4. **a body** : the ledger `transaction` is an operations body, one `-` row
   per giving account and one `+` row per receiving account, so a
   transaction with several parties is one record. `pool`, `share` and
   `slot` carry tables. flat ledger kinds leave `rows` and `body` out by
   their kind table

what was the same from the start : UTF-8, LF, `key = value`, fixed keys in
fixed order, all required, strict refusal, decimal counts, BMW384 base32
addresses, `prev = 0`, the kind inside the signed bytes, one empty line
closing a head.

what stays apart, on purpose :

- **kind tables.** each domain owns its kinds and their versions. the parser
  knows none ; a kind table is handed to it
- **the rules of a journal.** one parser and one signed envelope do not make
  one journal mechanism [ synthesis contradiction 21 ]. the n7fs journal is
  ordered by sequence and a BMW chain under the store key, with its fork
  rules. the ledger adds a witness, the settle pass and the `void` record.
  an add-only writer [ design only, `N7FS-SEALED-REPLICAS.md` "open" ] needs
  outside anchors and a forward ratchet that no envelope gives. the form
  carries all three ; it secures none of them by itself

the separator question of the synthesis [ contradiction 17 ] is not touched :
this form hashes stored bytes, never `parent . name`.

### 2.6 hand-editable files

unchanged rule : a file a person opens is p7 config style, `=` and `:` both
accepted on reading, aligned on writing, and it is never signed over its
bytes. the registry and the cycle files already are. format 4 adds the vault
registry note [ 35 ] to them. signed heads look the same to the eye, but they
are strict : one byte changed by hand and the record is refused.

### 2.7 the kinds

label versions : the 17 store kinds take `v4`, equal to the store format. the
others take the number after their last json form.

| kind | label | body | notes |
|---|---|---|---|
| state, meta, reference, drop, tombstone, tree_drop, category, assignment, sync_cursor, sync_conflict, hold, mount, use | `p7 n7fs <kind> v4` | none | flat heads. `origin` becomes `origin-disk`, `origin-id`. `converted`, `baseline`, `repaired` become flags |
| journal | `p7 n7fs journal v4` | operations | one row per added or dropped item, classes as the json lists of today. `was` holds the address of the format 3 entry it was written from, `0` for a native entry |
| tree, batch | `p7 n7fs <kind> v4` | table | the reference list becomes rows |
| tree manifest | `p7 n7fs manifest v2` | table | no `rows` \ `body` \ `sig` : it is content, addressed as a whole and written as a stream. one row per path : path, type, mode, uid, gid, mtime, mtime-ns, size, address, link, user, group, xattrs, why |
| seal-root binding | `p7 n7fs seal root binding v2` | none | the signature of today stays valid, it never covered the json |
| sealed head | `p7 n7fs sealed head v3` | table | the peers are rows |
| map root | `p7 n7fs sealed map v2` | operations | classes `category`, `retention`, `pin`, `superseded`, `shard`, `tree` |
| map shard | `p7 n7fs sealed map shard v2` | table | section 3 |
| map tree blob | `p7 n7fs sealed map trees v2` | table | |
| manifest index | `p7 n7fs sealed manifest index v2` | table | one row per chunk |
| manifest chunk | `p7 n7fs sealed manifest chunk v2` | rows are **the exact manifest lines** of the slice | the rebuild joins bytes, nothing is encoded again. this also carries a format 3 manifest unchanged [ `lines = json3` in the head ] |
| sealed journal | `p7 n7fs sealed journal v2` | none | `operation` as fixed keys per operation |
| receipt | `p7 n7fs receipt v3` | none | the covered cache [ 29 ] becomes a table record beside it |
| drill record | `p7 n7fs drill v2` | none | appended to `drills`, one record after another |
| request token | `p7 n7fs holder request v2` | none | `op`, `root-id`, `holder`, `counter`, `nonce`, then the fixed argument keys of that operation. carried as `b32( head ) . b32( sig )` as today |
| relay list | `p7 n7fs relay list v2` | table | one blob name per row |
| seal state, reservation, pending key, request counter, relay pending | `p7 n7fs <kind> v2` | none or table | unsigned local state, written new on the next change |
| root file | `P7RK\x02` | | binary : `t`, `m`, `p` as 32 bit counts and the 16 salt bytes. no text in the header at all |
| switch | `p7 n7fs switch v4` | none | path B only : disk, `from`, `to`, direction, row count, BMW384 of the switch list [ section 4.3.3 ]. the list itself is a table file beside it |
| id | | | **frozen**, section 4.3.1 |

a later field is a new version of that kind : `v5` beside `v4`, one table per
version, the reader knows both. nothing is ever added inside a version.

`state v4` carries one key that format 3 has no word for : `grid`, the rule
that turns a time into an epoch, `float` or `exact` [ section 4.6 ]. it is in
the first version of the kind so that the later switch changes a value, not
a kind.

## 3. performance

the hot spot was decoding 1024 map shards : 23.8 s with JSON::PP, 0.16 s with
JSON::XS on the live map.

**measured for this document** on generated entries of the shard shape, never
on n7fs data or code : 1024 shards, 92160 entries, 68.5 MB as canonical json,
54.5 MB as the table form. perl 5.42.3 and the floor perl 5.32.1 gave the
same picture.

| step | time | against JSON::XS |
|---|---|---|
| JSON::XS decode | 0.26 to 0.36 s | 1 |
| JSON::PP decode [ scaled from 51 shards ] | 27 to 39 s | about 100 times slower |
| table : index, address -> row [ one `split`, one `substr` per row ] | 0.07 s | about 4 times faster |
| table : every row split into a flat array | 0.19 to 0.20 s | faster |
| table : strict whole-shard pattern, then index | 0.22 to 0.34 s | equal |
| table : every entry rebuilt as the nested hash json gave | 0.8 to 1.0 s | about 3 times slower |
| binary rows [ `unpack '(n/a*)*'` ], index | 0.06 s | no real gain over text |
| JSON::XS encode | 0.38 to 0.46 s | 1 |
| table encode, every row packed again | 0.45 s | about 15 % slower |

what follows :

- **the form is text everywhere.** a binary shard gains 0.01 s on the whole
  map and loses readability and the shared parser. the brief allowed a binary
  hot part ; it is not needed
- **the shard reader must not rebuild nested hashes for the whole map.** it
  keeps `address -> row` and splits a row when the entry is asked for. the
  shape handed to the callers of today [ the tied `LazyNodes` hash ] stays,
  built per entry on `FETCH`. walking only the addresses costs the index. a
  full walk through every entry as flat rows is still faster than JSON::XS
- **a writer keeps rows as strings.** a commit packs only the entries it
  changed and joins the rest. the 15 % above is the worst case, where every
  row is packed again ; the usual commit is far below JSON::XS because
  unchanged entries are never encoded
- row checks move to the moment an entry is used. the shard as a whole is
  already authenticated twice [ outer tag, plaintext checksum ] before a byte
  is parsed, so a bad row is a writer bug, not an attack, and it is refused
  with its address when touched. `holder-check` and the conversion check
  every row
- the speed no longer depends on an installed JSON::XS. a holder or a fresh
  host is fast with core perl alone

the local journal replay over 92k nodes is the other single-core start cost.
it decodes one json payload per entry and per signed record today. rows that
are split only when used should help there too ; that is **assumed** and is an
acceptance check of stage 5a, not a claim of this document.

the benchmark script is not in the repository. stage 1 rebuilds it as a test
with the same seven rows and fails when the index or the flat row walk is
slower than JSON::XS on the same generated shards.

## 4. migration

### 4.1 principle

**a disk or a holder is in one format as a whole. the code reads both and
writes the one it finds.** this is how n7fs already treats formats 1, 2 and
3. there are no mixed journals and no mixed maps.

the json reader moves into one module [ `AMOS7::N7FS::Prior`, section 5 ]
that only reads. after the last store and the last holder are converted, the
only caller left is the converter.

dual reader or re-seal, per side :

| side | choice | why |
|---|---|---|
| holders | **maps-only conversion, per holder, in either direction** | content blobs carry no json [ finding 4 ]. only the map, shards, tree table, manifest index and chunks, the sealed journal and the head are written again. no second copy of the data on any holder |
| disks | **dual reader, then `upgrade` 3 -> 4, by one of two paths** [ owner, question 5 ] | path A, through the epoch window : the built path, the new form in the next epoch, every address changes its epoch part. path B, in place : new records under the same names, addresses stable, a rollback designed here [ section 4.3 ] |
| holder side code | **dual acceptance** of request tokens and relay lists | a holder must understand the new token before home sends the first one |
| home state | read both, write new | small files, rewritten by their next change |

telling the forms apart needs no guess : a format 3 record starts with a
binary magic `P7F?`, json state with `{` or `[`, a format 4 record with the
bytes `p7 n7fs `.

### 4.2 holders

`n7fs holder-convert <holder> -root-key <key> [ -to 4 | -to 3 ] [ -dry-run ]`

1. takes the host lock that every holder-writing command takes. the hourly
   cycle is paused for the roll-out
2. reads the head and the whole map with the reader of the holder's form
3. writes every shard, the tree table, the map root, every manifest index
   and chunk and the sealed journal in the target form. shard membership does
   not change [ a shard is chosen by two characters of the bmw part,
   **checked** in `_node_shard` ], so each shard converts by itself and a
   stopped run resumes
4. publishes map blobs first, the head last, as every commit does. the head
   is the single commit point
5. checks : every converted shard read back and compared in meaning with its
   source [ section 4.5 ], then `holder-check -scrub`, then a restore drill
   from that holder

what it costs : the map of 92486 nodes is about 55 MB in the new form
[ **measured** on generated entries ; the live figure may differ ], sent once
per holder over the pipelined session. no content blob is read, sealed or
sent.

space : the old map blobs become unreferenced. `holder-gc` moves them to the
trash after its grace age, `holder-trash-purge` removes them after the trash
age. until then they are the first rollback.

code that predates format 4 refuses a converted holder : it tries to decode
the head plaintext as json and stops with `head payload is invalid`
[ **checked** in `_head_open` ]. fail-closed, and the reason every home that
writes [ the main root, a service root, the cycle host ] runs the dual
reader before the first holder is converted.

**what a holder must do** : run the new `bin/n7fs-receive` and its modules
before home sends a v2 token. nothing else. no data on the holder is
converted by the holder, its counter files are already plain, and
`put-head` checks only the exterior signature, which does not change
[ **checked** : it is made over the sealed bytes ]. counters continue across
the token forms ; the rule "above the last accepted" does not care which
form carried the number.

order : one holder at a time. three copies stay on the proven form until the
last one, and the next holder starts only when the one before has a full
scrub receipt and a passed drill in the new form.

### 4.3 disks

`n7fs upgrade <disk>` gains the step 3 -> 4, registered like 2 -> 3. the
owner decided that **both** paths are offered [ question 5 ] :

    n7fs upgrade <disk>               path A : through the epoch window
    n7fs upgrade <disk> -in-place     path B : in place, addresses stable

both end in the same format 4 disk : the same kinds, the same record names,
the same bytes apart from the epoch part of the addresses and the lines that
follow from it. the dual reader does not know which path a disk took.

#### 4.3.1 what both paths do

- every signed record is written fresh in the canon form and signed by the
  store key. no record is patched
- the journal is **transcribed, not replaced by a baseline** : entry by entry,
  same sequence, same operations, new `prev` chain. each entry carries `was`,
  the address of the format 3 entry it came from. release history, tombstones
  and remembered origins survive, which a baseline would lose
- **sync cursors on other disks** hold a hash of the old entry bytes. sync
  accepts a cursor whose hash equals the `was` of that sequence and writes the
  new address with its next cursor. both disks of a sync must be format 4 ;
  format 3 with format 4 refuses and names `upgrade`
- **tree manifests** are issued again as `manifest v2`. they must be, on
  either path : a manifest is a content node whose bytes are json lines
  [ finding 2 ], so a manifest without json is another node with another
  address. the tree record keeps its origin, so sync still sees the same
  tree, and names the old manifest address in `was-manifest`
- **the id record stays as it is, for ever.** it is the format 1 container
  whose bytes are the disk id. format 4 reads its four fields [ `init_ntime`,
  `intent`, `name`, `store_pub` ] with one fixed pattern over the stored
  bytes, not with a json reader : four known keys in sorted order, string
  values, and only the escapes `\"` and `\\` can occur because `intent` is
  printable ASCII [ **assumed** from the `init` checks ; stage 2 proves it on
  fixtures ]. the alternative is a new disk identity, which unbinds every
  seal-root binding, every `disks` field in the maps and every sync origin
- the new `state` record names `grid = float` : the upgrade changes the form,
  never the epoch rule [ section 4.6 ]
- the witness pins format 4 once the upgrade is confirmed. older code then
  refuses the disk

#### 4.3.2 path A : through the epoch window

the built path of 1 -> 2 and 2 -> 3, with its built rollback.

- content is hard-linked into the next epoch where the filesystem allows, as
  built ; records are written there. the whole new epoch verifies before the
  state switches. the state switch is **one** commit point
- until `confirm` the previous form is intact in its own epoch and the state
  switches back. after `confirm` it stays until it leaves the window or
  `release-epoch` removes it
- every node address changes its epoch part, the manifests name the new
  addresses

**what that means for the holders** : the sealed maps are keyed by the full
address [ **checked** ]. so the disk upgrade and the holder conversion belong
together : `holder-convert` takes the address map of the upgrade and writes
each entry under its new address in the same pass. receipts name covered
addresses and are renewed by the scrub of section 4.2 step 5. placement and
cycle state that name addresses are rebuilt from the journal.

this coupling has **never been exercised** : holders did not exist at the
2 -> 3 conversion. it is the largest risk of path A and the reason stage 6 is
a full rehearsal.

#### 4.3.3 path B : in place, addresses stable

no node moves, no directory moves, no content byte is linked, copied or
read. only records change, each under the name it has today. so every
address stays what it is, the sealed maps keep their keys, receipts stay
valid, and no address map exists.

**three places**, all inside the disk and so on one filesystem [ directory
names are proposals ] :

| place | holds |
|---|---|
| in place | the record under its name of today : below `.n7fs/`, or inside its node directory [ `<epoch>/<amos>/<bmw>/meta/..`, `references/..` ] |
| `.n7fs/next-4/<relative path>` | the format 4 record before the switch |
| `.n7fs/prior-3/<relative path>` | the format 3 record after the switch |

**which sibling counts** : one name holds one record, and the `state` record
says which form counts. a disk whose state names 3 counts format 3 records
in place and nothing else ; a disk whose state names 4 counts format 4
records in place and nothing else. the form of a record is told by its first
bytes [ section 4.1 ]. records below `next-4` and `prior-3` never count :
`find`, `get`, sync, seal and the meaning checks of `verify` do not read
them. `verify` only reports them, counted, and checks them against the
switch list while a way back exists. a record of the other form in place is
an error, except while a switch is open, and then only `upgrade` reads the
disk.

the steps, under the per-disk lock every state-changing command takes, with
the cycle paused :

1. **prepare.** write the complete format 4 record set below `next-4`,
   mirroring the relative paths. new `manifest v2` nodes are written as new
   content nodes in the current epoch ; they are the only additions in
   place, and the switch list names them. nothing that exists in place is
   changed. giving up here is removing `next-4` and the listed new nodes
2. **verify.** `form-compare` [ section 4.5 ] between in place and `next-4`,
   record for record. no address map : the exempt lines are `pub`, `sig`,
   `prev`, `was` and the manifest addresses. the transcribed journal replays
   to the same expected set. the content is not touched, so it needs no new
   checksum pass ; a `verify` of the format 3 disk before prepare is the
   gate
3. **the switch list and the switch record.** the list is a table, one row
   per record, sorted by path : relative path, BMW384 of the format 3 bytes,
   BMW384 of the format 4 bytes, plus one row per new manifest node. the
   switch record `p7 n7fs switch v4` is signed by the store key and names
   the disk, `from = 3`, `to = 4`, the row count and the BMW384 of the list.
   it is written as `.n7fs/switch` before the first rename. **while that
   file exists every command refuses the disk and names it**, except
   `upgrade -in-place` [ go on ] and `upgrade -back` [ return ]
4. **switch.** per row : link the record in place to `prior-3`, then rename
   the `next-4` record over the name in place. the `state` record is the
   last row. each step is decided by what is found, never by a counter : the
   bytes at the three places are compared with the two checksums of the row,
   so a run stopped anywhere goes on from what it finds. bytes that match
   neither checksum stop the run and name the path ; nothing is guessed.
   after the last row `.n7fs/switch` is moved to `prior-3`
5. **check, do not confirm yet.** `verify` on the format 4 disk. between
   the switch and `confirm` the disk refuses every change of the expected
   set [ assimilate, drop, release, sync into it ] ; reading, `find`, `get`
   and restore work. so nothing exists in format 4 that format 3 lacks, and
   the way back is exact
6. **confirm.** complete journal-and-disk verification as for any upgrade.
   the witness pin is raised here, not at the switch, so a return never has
   to lower a pin. changes are accepted again
7. **release.** `n7fs release-prior <disk> -now` removes `prior-3`. without
   `-now`, or before `confirm`, it is refused, as `release-epoch` is

**the rollback** : `n7fs upgrade <disk> -back`, any time from step 3 until
`confirm`.

- it writes the switch record again with the direction `back` and walks the
  same list from the last row : link the format 4 record in place to
  `next-4`, rename the `prior-3` record over the name in place
- the format 3 bytes that return are the very files that were there :
  linked, never rewritten, their signatures are those of before. the `state`
  record of before returns the same way, and with it the disk is format 3
- stopped anywhere, it goes on by the same comparison. forward and back can
  follow each other any number of times ; `next-4` stays complete, so going
  forward again signs nothing new
- **the proof of a clean return** : a digest over every record in place,
  `relative path` and BMW384 of the bytes, sorted, taken before prepare and
  after `-back`, is equal. `verify` passes as format 3 with the code of
  before
- after `confirm` the exact way back has ended : new changes exist in
  format 4 only. `prior-3` then is an archive of the format 3 records until
  `release-prior`, not a state to return to. this is the same line path A
  draws at `confirm`

what code from before sees on a half-switched disk : a format 3 `state`
record and, under some names, bytes that begin with `p7 n7fs ` instead of
the `P7F?` magic. it refuses the record [ **assumed** from the magic check ;
stage 5b proves it with the code of today on a half-switched fixture ]. fail
closed, and one more reason why the dual reader is deployed first.

**the manifests** on path B : the `manifest v2` nodes are new content in the
current epoch, the tree records name them. the old manifest nodes are
content and stay ; they become unreferenced when `prior-3` is released, and
removing them then is an ordinary release.

**the holders** on path B : nothing. the maps keep their keys and the
receipts their covered addresses. `holder-convert` [ section 4.2 ] runs
without an address map, before or after the disk, in any order. the new
manifest nodes are sealed by the next cycle like any new node ; a sealed
manifest of before is carried unchanged by `lines = json3`.

what path B cannot do : a filesystem without hard links. it refuses and
names path A, which falls back to copying.

#### 4.3.4 the two paths side by side

| | path A : epoch window | path B : in place |
|---|---|---|
| addresses | every node address changes its epoch part | stable ; only the manifests are new nodes |
| commit point | one : the state switch | one rename per record, guarded by the open switch record |
| rollback before `confirm` | built : switch the state back | designed here, new code : `upgrade -back` over the switch list |
| what the way back restores | the previous epoch, untouched | the same record files, linked back |
| holders | coupled : address map, maps rekeyed, receipts renewed. never exercised | not coupled |
| content | hard-linked into the next epoch, checksummed again | not touched |
| space | a second directory tree of links, a second record set | a second record set |
| kept until | `release-epoch` | `release-prior` |
| new code | the 3 -> 4 step, the address map through `holder-convert` | the switch, its resume, `-back`, `release-prior`, the sibling rule |
| largest risk | the holder coupling | a stopped switch ; it is local to one disk and fully rehearsable without a holder |

a recommendation, not a decision : for a disk with sealed holders attached,
path B, once stage 6 has passed for both paths. it removes the one coupling
that has never run, renews no receipt, and its own risk can be rehearsed to
the end on a scratch disk. path A where an epoch move is wanted anyway, and
wherever hard links are missing. which path the live store takes is owner
question 18.

### 4.4 order of the live roll-out, and rollback

| step | what | rollback |
|---|---|---|
| 1 | deploy the dual reader everywhere home writes, between runs, never into a tree a live n7fs runs from. it still writes format 3 | check out the commit before |
| 2 | deploy `bin/n7fs-receive` with dual acceptance on the four holders | same ; home still sends v1 tokens |
| 3 | home state, receipts, drills, tokens and relay lists in the new form | the old files are kept beside the new ones until step 7 ; the reader takes either |
| 4 | pause the cycle. `upgrade` the disk by path A or B, `verify`, compare [ 4.5 ]. do **not** `confirm` yet | A : the previous form is intact, switch the state back, as for any unconfirmed upgrade. B : `upgrade -back` |
| 5 | `holder-convert` holder 1, with the address map on path A, without one on path B. scrub, drill | `holder-convert -to 3` writes the old form again from the current map ; or a head naming the old map blobs while they are in place or in the trash |
| 6 | holders 2, 3, 4, one at a time, each gated by scrub and drill | per holder, as step 5 |
| 7 | `confirm` the disk. resume the cycle. later `release-epoch` [ A ] or `release-prior` [ B ], `holder-gc`, purge | after `confirm` the exact way back has ended. A : a conversion 4 -> 3 of the maps and the kept previous epoch. B : `prior-3` is an archive only. after the release there is none |
| 8 | remove json from every module but `Prior` | code only |
| 9 | the exact grid : `upgrade -grid exact` on every disk [ section 4.6 ] | `upgrade -grid float`, for as long as no epoch was stamped where the two rules differ |

between step 4 and step 7 the disk can go back and every holder can go back.
on path B the two are independent : steps 5 and 6 may also run before step
4, or weeks after step 7. on path A a disk that goes back takes its holders
with it, because their maps were rekeyed with the address map ; each
converted holder is converted back with the reverse map first. the form 3
**writer** for maps stays in the code until step 8 for exactly this. a
rollback of a holder after new nodes were sealed loses nothing : `-to 3`
converts the current map, it does not restore an old one.

the root file : new roots are `P7RK\x02`. an existing root is rewritten by
`root convert`, which already changes only the wrapping. offline copies in the
old form stay readable ; whether they are made again is owner question 8.

### 4.5 proving that old and new mean the same

one rule, applied to every kind : **read the old record with `Prior`, pack
what it means in the new form, and compare with the stored new bytes.** equal
bytes, no tolerance. per kind a short list of lines is exempt because they
must differ : `pub`, `sig`, `prev`, `was`, the manifest addresses, and on
path A the addresses whose epoch moved, which are compared through the
address map. on path B there is no address map and no moved address.

- **types are checked on the way in.** every json value must fit the type of
  its field : a count that arrives as a float, a string with leading zeros, a
  `true` where a word is expected stops the conversion and names the record.
  nothing is guessed or rounded
- **which bytes a json string means** is fixed per field and written into the
  kind table. n7fs handed filesystem octets to the codec, so a decoded string
  with every character below 256 means those bytes, and a string with a
  higher character is refused until the field's rule says otherwise. a
  read-only report lists every field value outside ASCII before any
  conversion runs
- **floats** : `epoch_num` is carried as the text perl prints for it, which is
  the text the codec wrote [ both use 15 significant digits, **assumed** ;
  stage 2 checks it on every meta of the fixtures ]
- **journal** : entry by entry as above, and the replayed state of both
  journals must be the same set under the address map
- **shards** : every shard, as tables. this is the check of step 5
- **manifests** : every entry as a row, and a tree restored from the old and
  from the new manifest must be the same tree
- **end to end** : `verify` on the upgraded disk, a full scrub of each
  holder, and a restore drill from each converted holder compared byte for
  byte with the local content

`n7fs form-compare <disk | holder>` runs these read-only and prints one line
per kind : records, equal, differing, exempt lines.

### 4.6 the exact epoch grid, a versioned step

the fact : an n7fs epoch is computed in floats today [ `epoch_num`,
`epoch_int` in `AMOS7::N7FS::Sum` ; `base.ntime.epoch_dec` on the zenka
side ]. the exact grid exists since 3bef478fe :

    AMOS7::cell::time::frame( ntime, 1 )  =  floor( ntime x 13 / 132451200000 )
    epoch                                 =  that frame modulo 385280

its test walks every level 1 boundary of the whole wrap. the float functions
give another epoch at **10082** of them, off by one : a quotient of x.9999..
is cut down. the first lies about 13.5 years ahead. so every address n7fs
has written, and every one it writes for years, is the same under both
rules. nothing stored is wrong today ; without a change something will be.

that is why the switch is a step with a version, and not a quiet
replacement of a function :

- two hosts on two rules would name two epochs for the same instant at one
  of those boundaries, and two windows. a window decides what is valid and
  what an upgrade may remove
- "which rule wrote this epoch" must be answerable from the disk, for ever

**the rule is named in the `state` record** : `grid = float` or
`grid = exact` [ section 2.7 ].

| value | the epoch of an ntime | where |
|---|---|---|
| `float` | the rule as built, in native doubles | every format 1 to 3 disk, by definition ; a format 4 disk right after its upgrade |
| `exact` | `AMOS7::cell::time::frame( ntime, 1 )` modulo 385280, window by `AMOS7::cell::time::window` | after the step below ; every disk initialized by code that knows it |

**the step** : `n7fs upgrade <disk> -grid exact`, registered like a format
step and run under the same lock.

- it writes one new `state` record and nothing else. no address, no
  content, no other record changes
- the witness pins the grid as it pins the format : a disk that was `exact`
  is refused when its state says `float`, unless the witness was moved back
  on purpose
- code that does not know `grid` cannot read a format 4 state at all. code
  that knows it refuses a value it does not know
- **the way back** : `upgrade -grid float` is allowed while no epoch was
  stamped at an instant where the two rules differ. that is every instant
  before the first of the 10082 boundaries, so for years the step can be
  undone by one record. after that boundary it is refused and says why
- the step is taken at the latest before that boundary. the plan takes it
  right after the roll-out [ step 9 of section 4.4 ], when every writing
  host runs code that knows both rules

what the rule is used for, and what never recomputes :

- stamping a new address [ `epoch_int( ntime_now() )` at import ] and the
  window [ `epoch_window` ] : by the disk's rule
- a stored address carries its epoch. it is read, never derived again from
  a time [ **assumed** ; the stage lists every caller of the epoch functions
  and proves it per caller ]
- addresses are root-free, and one content may already stand under two
  epochs on two disks. so sync does not refuse two disks on two rules ; each
  stamps by its own. the holders compute no epoch
- **`epoch-num`** : the high resolution epoch inside `meta`, a `decimal`
  copied as text. under `float` it is the text of today. under `exact` it is
  the exact quotient cut, not rounded, to 13 digits after the point, so its
  whole part is always the epoch of the address. old values are never
  written again
- n7fs stamps from whole ntimes [ **assumed** ; checked by the stage ]. the
  10082 were measured on whole ntimes ; for a fractional ntime very near a
  boundary the two rules may differ earlier [ not measured ], so a caller
  that passes fractions is listed by the stage and moved to the exact rule
  first

what it removes at the end : once no disk names `float`, `epoch_int` and
`epoch_num` leave `AMOS7::N7FS::Sum`, and one frozen copy of the float rule
stays with the reader of prior forms. `base.ntime.epoch_dec` and
`AMOS7::NTIME::y_level_ntime` are outside n7fs and move by their own word
from the owner ; `y_level_ntime` returns a length, not a frame, so it gets
an adapter, not a replacement [ synthesis section 7 ].

## 5. stage plan

sized for one kimi task each. rules for every stage :

- work in a git worktree. never in a tree a live n7fs runs from, never
  against `/N7FS`, a real holder, a real root key or a real host directory.
  tests run in scratch directories with the sandboxed fake ssh
- BMW \ AMOS checksums only, no sha. no json outside `Prior`
- lowercase comments, `[ word ]` annotations. `bin/format-code -c` is clean,
  the tests pass under the floor perl
- the task touches, restores and reformats only the files it changed
- no commit without the owner's signed version

names, checked with `bin/harmony` as a hint only. **the shared parser** is
question 2, and this document recommends a home that belongs to neither
user :

| module | holds | harmony |
|---|---|---|
| `AMOS7::cell::canon` | the canon form : parse and pack a head, signed bytes, address, strictness | TRUE |
| `AMOS7::cell::canon::list` | the body : index, row, pack, both body shapes | TRUE |
| `AMOS7::N7FS::Canon` | the n7fs kind tables, every kind of section 2.7 | TRUE |
| `AMOS7::NRT::journal::canon` | the ledger kind tables [ built by ledger stage 1a ] | TRUE |
| `AMOS7::N7FS::Prior` | every json read of format 3, read only | TRUE |

why a home of its own : the owner accepted `AMOS7::cell` as the namespace
root, and the canon form is the journal part of a cell, for whoever keeps
one. the ledger must not load n7fs code, n7fs must not load the ledger, and
neither should wait for the other's stage. tried and FALSE, as a hint :
every `AMOS7::canon*` name, `AMOS7::cell::canon::table`, `::rows`, `::body`,
`::row`, `::head`, `AMOS7::cell::record`, `AMOS7::cell::journal`,
`AMOS7::cell::envelope`. also TRUE and free : `AMOS7::cell::canon::kind`,
`AMOS7::cell::form`. if the owner chooses another home, the move is a
rename ; no check below changes.

**stage 1 : the form.** `AMOS7::cell::canon` [ head : parse, pack, signed
bytes, address ] and `AMOS7::cell::canon::list` [ body : index, row, pack ].
new files only. **ledger stage 1a starts after this stage is accepted** and
builds nothing of the form itself.

- it knows no kind and no domain : a kind table is an argument. the test
  uses fixture kinds of two domains [ `p7 n7fs ..` and `p7 nrt ..` ], and
  the module loads nothing of n7fs or of the ledger beyond the BMW and
  base32 functions
- every strictness case of section 2.2 is refused and named : repeated,
  unknown, missing key, order, padding [ too little and too much ], two
  spaces, trailing space, CR, missing final LF, empty value, a `:` form
  where bare was allowed, a label line that is missing or malformed
- a signature made for one kind, version or domain is refused under another
- a stored `pub` other than the key the caller names is refused
- a changed body byte, a wrong `rows`, an unsorted or repeated table row
  fail ; an operations body in another order than its kind fixes fails
- pack of parse is the same bytes for every fixture ; the address is stable
- the benchmark of section 3 as a test : index and flat row walk not slower
  than JSON::XS on 1024 generated shards, on both perls
- a scanner lists the new files and finds no json and no sha module in them

**stage 2 : the kinds and the old reader.** `AMOS7::N7FS::Canon` with the
table of every kind in section 2.7 [ `state v4` with its `grid` key, the
`switch` record of path B ], and `Prior` holding every json read of format 3.
no existing module changes yet.

- frozen format 3 fixtures made by the code of today : a small disk with
  every record kind, a sealed holder with several shards, packs and a tree
- for every fixture record : `Prior` reads it, the canon form packs it and
  reads that, and the meaning is equal field by field
- the type and string checks of section 4.5 refuse prepared bad values
- the id record pattern reads every fixture id and refuses a changed byte
- `epoch_num` text is equal on every fixture meta

**stage 3 : wire and home state.** request tokens v2 with dual acceptance in
`Receiver.pm` and `bin/n7fs-receive` ; relay lists in `Cycle.pm`, `bin/n7fs`
[ one copy of that code instead of two ] and `bin/n7fs-push` ; receipts,
covered cache, drills, seal state, reservations, pending keys, counters, the
seal-root binding, the vault registry note, the root file suite 2.

- `test-n7fs-receiver.pl` passes with v1 and with v2 tokens ; a counter
  accepted in one form is a replay in the other
- every old state fixture is read, and the next write leaves the new form
- receipts and drills are checked over stored bytes : a re-ordered or
  re-spaced copy with the same meaning is refused
- a root file of suite 1 opens, `root convert` writes suite 2, both open
- **this stage lands before the ledger's stage 2** [ owner, question 17 ] :
  the ledger's `store` proof reader then reads receipts in the canon form
  and never holds a json reader

**stage 4 : the sealed side.** head v3, map v2, shards as tables behind the
same `LazyNodes` interface, tree table, manifest index and chunks as byte
rows, sealed journal ; `holder-convert` in both directions with an optional
address map.

- the sharded-map, head, registry-sealed, retain, holder and seal tests pass
  on format 4 holders and still pass on format 3 holders
- a fault at every blob class of the conversion resumes ; the head is last
- code from before this stage refuses a converted holder
- convert 3 -> 4 -> 3 gives a map equal in meaning to the first
- no content blob is read or written by a conversion [ counted in the fake ]
- the 1024 shard fixture loads no slower than with JSON::XS

**stage 5a : the disk side, path A.** store format 4 : codec, records,
`manifest v2`, journal transcription with `was`, the step 3 -> 4 in `upgrade`
through the epoch window, the cursor rule in sync, `verify` \ `repair` \
`find` \ `get` on format 4. the new state names `grid = float`.

- every existing disk test passes on a format 4 disk
- upgrade, then every fault point, then `repair` and retry, then `verify`
- an unconfirmed upgrade switches back and verifies as format 3
- a sync cursor written before the upgrade is accepted after it once, and
  rewritten ; a wrong `was` is refused as rewritten
- the replayed state before and after is the same set under the address map
- journal replay of a 92k node fixture is timed against format 3 with
  JSON::XS and reported

**stage 5b : the disk side, path B.** after 5a, which holds the format 4
store code. `upgrade -in-place` : prepare, the switch list and record, the
switch with its resume, `upgrade -back`, `confirm`, `release-prior`, the
sibling rule in every reader.

- a disk upgraded in place and a copy of it upgraded through the epoch
  window hold the same records, compared through the address map of the
  copy : equal apart from the epoch parts
- no address changes : the set of node addresses before and after is equal,
  apart from the manifest nodes named in the switch list
- the switch killed after every single link and every single rename, then
  `upgrade -in-place` again : the disk verifies as format 4. the same kills,
  then `upgrade -back` : the digest over every record in place equals the
  digest taken before prepare, and `verify` passes as format 3
- forward, back, forward : no record is signed twice
- while `.n7fs/switch` exists every other command refuses and names it
- bytes at a listed path that match neither checksum stop the run and name
  the path ; nothing is overwritten
- between the switch and `confirm` every change of the expected set is
  refused ; `find`, `get` and a restore work
- records below `next-4` and `prior-3` change no answer of `find`, `get`,
  sync, seal or `verify`
- the code of today refuses a half-switched fixture disk
- `release-prior` is refused before `confirm` and without `-now`
- a sealed holder of the disk, untouched, passes `holder-check -scrub`
  after the in-place upgrade : no map entry and no receipt names an address
  that moved
- a filesystem without hard links [ simulated ] refuses and names path A

**stage 6 : rehearsal.** `n7fs form-compare`, and one script that builds a
format 3 world with the code of today [ a disk, two local holders, one
receiver holder ], then runs section 4.4 from step 1 to step 7 on it,
**once for each path**, including one rollback of the disk and one of a
holder on each. on path A the rolled-back disk takes its converted holder
back through the reverse address map ; on path B the holders are converted
once before and once after the disk.

- every line of `form-compare` reports no difference
- a tree restored from each converted holder is byte equal to the source
- the script leaves a runbook per path : each live command in order, its
  gate, its way back

**stage 7 : the live roll-out.** not a kimi task. the owner runs the runbook,
passphrase steps as at go-live.

**stage 8 : the removal.** every json use left in the modules is deleted or
moved into `Prior` ; the map writer for format 3 goes ; `json_codec` goes.

- a scanner over `AMOS7/N7FS*` and `bin/n7fs*` finds a json module only in
  `Prior`, and `Prior` is loaded only by `upgrade` and `holder-convert`
- every test passes with JSON::XS not installed and with no warning

**stage 9 : the exact grid.** one task, independent of the json work once
stage 5a exists. `upgrade -grid exact` and `-grid float`, the witness pin,
the `exact` rule through `AMOS7::cell::time`, `epoch-num` under `exact`.

- every caller of `epoch_int`, `epoch_num` and `epoch_window` in n7fs is
  listed with what it does : stamps, computes a window, or only formats. no
  reader derives the epoch of a stored address from a time
- on a disk with `grid = exact` the epoch of every one of the 10082 known
  boundary instants is the exact one, and on a `float` disk the float one :
  both rules are tested against the list of 3bef478fe's test
- at every level 1 boundary of the next ten years, one unit before it, at
  it and one unit after it, the two rules give the same epoch and the same
  window, so the step changes no address today
- the step writes one record. node addresses, content and every other
  record are byte-identical before and after
- `-grid float` after `-grid exact` returns the state of before ; with a
  test clock set past the first differing boundary and one import there, it
  is refused
- a witness that saw `exact` refuses a state that says `float`
- `epoch-num` under `exact` : its whole part equals the address epoch at
  every boundary instant, 13 digits after the point, cut
- the float rule exists in one place afterwards

## 6. what this unblocks

- **the ledger never needs a json boundary** [ owner, question 17 ]. stage 3
  moves receipts to the canon form before the ledger's stage 2 ; the
  ledger's contradiction 12 and its owner question 13 are closed, and
  synthesis contradiction 16 with them
- **one envelope** for n7fs, the ledger and a later log [ decided, question
  1 ] : one parser, one signature rule, one address rule. each journal keeps
  its own order and security rules [ section 2.5 ]
- **ledger stage 1a** waits for stage 1 here and for nothing else of this
  document
- no speed cliff on a host without JSON::XS
- the exact grid for n7fs epochs, with a way back, years before the first
  boundary where the float rule is wrong [ section 4.6 ]

## 7. what this document does not claim

- no line of n7fs was run or changed for it. the timings are from generated
  data shaped like a shard, not from the live map
- an upgrade through the epoch window with sealed holders attached has never
  been done. section 4.3.2 says what it must do, not that it works
- path B is a design. its switch, its resume and its rollback are new code
  with no built predecessor ; section 4.3.3 says what they must hold, stage
  5b and stage 6 are where it is shown
- that the float epoch rule ever wrote a wrong address. it did not, and
  will not for years ; section 4.6 is about the day it would
- the field lists of section 2.7 are by kind, not by key. stage 2 writes the
  exact key list of every kind from the code and the fixtures
- conversion does not make old bytes unrecoverable : previous epochs, trash
  and backups keep json until they are released, as format 3 says of release

## 8. owner questions

1. **decided** [ owner, 2026-11-16 ] : this canon form is also the ledger
   journal form, with its stored label line, padding to the longest key and
   optional body of rows, unless a better matching one is found
   [ section 2.5 ].
2. **where the shared parser lives.** recommended : a home of its own,
   `AMOS7::cell::canon` with `AMOS7::cell::canon::list`, the kind tables in
   `AMOS7::N7FS::Canon` and `AMOS7::NRT::journal::canon` [ section 5 ]. or
   inside n7fs with the ledger calling it, or inside the ledger ?
3. **decided with 1** : padding is inside the signed bytes, aligned to the
   longest key of the kind and version.
4. **key spelling.** `root-id` as the ledger writes keys [ proposed ], or
   `root_id` as n7fs writes them today ?
5. **decided** [ owner, 2026-11-16 ] : both paths are offered, through the
   epoch window and in place with stable addresses [ section 4.3 ]. which of
   them the live store takes is question 18.
6. **the id record.** keep the format 1 record as the frozen anchor, read by
   one fixed pattern [ proposed ], or give disks a new identity in format 4 ?
7. **free text.** bare when it is printable ASCII and base32 otherwise in
   heads, always base32 in rows [ proposed ] ; or base32 everywhere ; or a
   readable escape form in rows at some cost on the hot path ?
8. **root files.** rewrite existing roots as `P7RK\x02` and make the offline
   copies again, or leave them and read suite 1 for ever ?
9. **how long `Prior` stays.** as the converter step for good [ the spec
   wants one converter per version step ], or deleted once no format 3 store
   or holder is left ?
10. **holder order and gate.** which holder is first, and is a full scrub
    receipt plus one passed drill the right gate before the next ?
11. **rollback window.** how long does the format 3 map writer stay : until
    all four holders have a new receipt, or a fixed time after `confirm` ?
12. **the drill log.** leave `drills.json` as an archive read only by
    `Prior`, or write its records again in the new form under the root key
    [ new signatures, the old record address kept in `was` ] ?
13. **text everywhere.** the measured gain of a binary shard is 0.01 s on the
    whole map. agree to no binary record form at all in format 4 ?
14. **other stores and writers.** are there further format 3 disks or
    writing hosts [ a service root, a second machine ] that must take the
    dual reader and the upgrade together ? sync refuses mixed formats
15. **the vault registry note.** move its body to the config style the file
    registry already has, at its next save ?
16. **JSON::XS afterwards.** drop it from the dependency profiles after
    stage 8, or keep it for `Prior` ?
17. **decided** [ owner, 2026-11-16 ] : receipts move to the new form
    [ stage 3 ] before the ledger's stage 2. the ledger never needs a json
    boundary.

new in this revision :

18. **the path of the live store.** path B, in place, once stage 6 passed
    for both paths [ recommended, section 4.3.4 ] ; or path A, with the
    address map through four holders ?
19. **the frozen window on path B.** between the switch and `confirm` the
    disk accepts no change of the expected set, so that the way back is
    exact [ proposed ]. or should changes be accepted and a return
    transcribe them back to format 3 ?
20. **the exact grid.** take the step `-grid exact` right after the roll-out
    [ proposed, step 9 ], or wait ? and may a new format 4 disk be
    initialized as `exact` from the first day ?
21. **`epoch-num` under the exact rule.** the exact quotient cut to 13
    digits after the point [ proposed ], or drop the key from `meta` in a
    later version of the kind ?
22. **the zenka side of the grid.** may `base.ntime.epoch_dec` move to
    `AMOS7::cell::time` in the same step, or does it stay on floats until
    its own task ?

#,,.,,,,.,.,.,..,,,.,,..,,..,,...,,.,,..,,..,,..,,...,...,..,,...,,,,,.,.,,.,,
#ZGUDZ3CXAYDDMT7FP7KUW2YV6TEBBPNZ6VFNEHPBXMQZ3EZQROHND6WQDHDCYRPEUOQDRYB65KBZC
#\\\|Q6Z7CLFKUCADQSLXZYJYTTEA2FK6D6CEBIS45AFJ572ED4G2MTW \ / AMOS7 \ YOURUM ::
#\[7]C4GAM2E6I5L5OHFXA7HO3DWARR3MOH4OQH6ZQXHQY2P46AASJIAY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
