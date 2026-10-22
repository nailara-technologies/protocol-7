# signed statements : one record for signed lists and signature relationships

draft 2026-10-22. design only -- no code, config or todo changes come with
this file. it answers the stalled question of
`data/ai-mem/claude/project-keys-zenka-integration-direction.md` [ 'clean
signature trees' ] : the FORMAT and LOCATION of generic signature lists.

the owner's key requirement shapes everything below : a v1 in project
style that can be used right away, so adoption never waits on refinement.
refinement comes only as new labels or versions, never by changing v1.

builds on [ do not rebuild ] : the AMOS7 data signature footer
[ `src/source.*` ], N7FS-SPEC.md + N7FS-FORMAT-1.md [ labelled records,
newest-is-state, a damaged newest refuses ], HOST-ROOT-DELEGATION.md
[ key id = bmw384 of the public key, `p7 delegation v1` ],
TRUST-CHAIN-STEP2.md + `src/trust.*` + `src/discover.*` [ chains, pins,
distrust -- built ], data/tasks/footer-line4-field-reconciliation.md
[ the planned `#:::` row fields ],
AUTH-LINK-BINDING.md [ one label per message and role ],
PRIVACY-PRESERVING-IDENTITY-CREDENTIALS.md [ parent signs child pub,
mode A \ mode B ], ZENKA-IDENTITY-COMPONENT.md [ vouching edges,
lineage vs membership ], FILES-ZENKA.md [ records, manifests, section 9
capabilities, open question 19 ].

## what exists [ read 2026-10-22, base 49a2f5d3 ]

- **the footer** [ `source.fill_source_template`, `source.init_code`
  `sign_template`, `source.create_harmonic_footer` ] : five lines of 78
  bytes at the end of every signed file :
  - line 1 : the AMOS header, a bit frame that encodes the payload's AMOS
    checksum, the endline state and an iteration counter
  - line 2 : `#` + BMW-384 base32 [ 77 characters ] over the payload, then
    line 1, then `#`
  - lines 3 + 4 : the Ed25519 signature, 103 base32 characters split
    51 + 52, with fixed decoration `\ / AMOS7 \ YOURUM ::` and
    `7  DATA SIGNATURE ::`
  - line 5 : `#:::..`
- **what is actually signed** : `source.signature_valid` verifies over
  `substr( footer, 0, 163 )` = line 1 + line 2 + `#\\\|`.
  `sign_full_payload = 0` in `fill_source_template` : the payload is
  bound only through BMW-384. statement integrity therefore rests on
  BMW-384 collision resistance plus Ed25519, the same as for every src
  module today.
- **the footer names no signer.** `AMOS7 \ YOURUM` is a constant
  [ `my $sig_name_str = 'AMOS7 \ YOURUM'` ], written at byte 219 -- after
  byte 163, outside the signed bytes. it is still not tamperable : in
  strict mode `source.extract_sig_body` blanks the BMW and signature
  positions and requires the rest of the footer to EQUAL the template
  byte for byte [ lines 547-670 ] -- an edited slot fails as 'template
  mismatch'. there is one template, so the slots are pinned. the
  verifier picks the key :
  `crypt.C25519.verify_sign( msg, sig, key_name )` ; the
  `verify-p7-signatures` run hardcodes `proto-7.sourcecode`, loaded from
  the `base.protocol-7.source-key` data block of `bin/Protocol-7`.
- **other keys work already** : `source.load_signature_key( <name> )`
  and `crypt.C25519.sign_data( msg, <key> )` take any key name ;
  `sourcecode.console.test-sign-with-temp-key` and
  `test-verify-with-temp-key` sign and verify footers with a key other
  than the sourcecode key.
- **signing is a search** : `create_harmonic_footer` repeats until the
  footer lines and both signature halves pass the ELF truth checks.
  measured over 5060 files
  [ `bin/test-scripts/sig-iter-cnt-style-chk/quality/iterations.tsv` ] :
  the median is 14142 iterations, p90 48117, max 178667. not every
  iteration signs [ the signature step runs only after lines 1 + 2 pass ],
  but a signer is asked for many signatures per file.
- **the pre-commit check** [ `bin/dev/git-hooks/pre-commit` ] : line 358
  tests that a footer is PRESENT [ substring `YOURUM` \
  `AMOS7.*DATA.*SIGNATURE` ] on files that need one, then line 431 runs
  `sourcecode verify-p7-signatures` on the staged set -- real
  verification [ corrected in review : an earlier draft said it verifies
  nothing ]. it knows no statements yet.
- **`src/base.list.subroutines`** : a perl module returning 6200 module
  NAMES, exactly the 6200 files of `src/` at 49a2f5d3. it is written by
  `sourcecode.console.update-sub-list`, read by
  `sourcecode.console.subroutine-list` and loaded early by the
  `sourcecode`, `work` and `template` zenki. **nothing enforces it at
  load.** it refuses nothing at runtime today. even if enforced, names
  alone miss a rollback of a still-listed module to an older, validly
  signed version [ the reason this file adds per-member content ids ].
- **binary labelled signatures** : `p7 delegation v1` [ host-root,
  `pack 'Z* a32 a32 n/a* N N n/a*'` ], the N7FS records [ magic + format
  byte + label + canonical json + `signer_pub` + sig ], the files cap
  [ `p7 files cap v1`, designed ], `crypt.C25519.sign_keys` [ signs the
  RAW 32-byte subject pub : no label, no time, no action -- cannot be
  ordered or revoked ].
- **shm permissions** [ `data.mount.shm.permission.*`, `AMOS7::SHM` ] :
  `sign_permission` is a 32-bit polynomial hash of the canonical string,
  times the key length. **it is not a signature** : anyone can compute
  it. the header is 512 bytes for up to 16 permissions.
- **signed key chains are built** [ TRUST-CHAIN-STEP2, live ] :
  `trust.statement` [ exact bytes of `p7 delegation v1` : issuer, subject,
  name, not_before, not_after, scope ], `trust.chain` [ b32 wires joined
  with `.`, leaf first, at most 4, at most 2048 chars ], `trust.verify`
  [ walks from a pinned anchor to a subject : sig, time window, name,
  scope only narrowing, a distrust list ], `trust.key_id`,
  `trust.pin_decide`. pin stores under `~/.n/remote-keys/` : `servers/`
  [ host-root key ids ], `owners/` [ owner key ids, set by command only ],
  `distrust` [ local, fail closed ]. tools : `p7-keys certify-host \
  owner-pin \ distrust ..`, `p7c v7-zenki.delegation-issue`.
- **discover uses them for signed packets** : `format_discover_mcast_packet`
  signs `[:<|TYPE|<host pub>` + a `dlg:` chain line + payload + ntime with
  the host key [ raw Ed25519, no truth search ] ;
  `process_incoming_packet` verifies under the pub in the header, refuses
  an ntime behind a per-sender watermark [ in memory, keyed by the L13 of
  the sender key ] ; `process_host_packet` runs `trust.verify` on the
  chain with the distrust list, then pinned [ `read_host_root_pins`, read
  only ] or owner-covered ; the orbital part appends a `p7ref` line.
  missing for statements : revocation beyond expiry [ TRUST-CHAIN-STEP2
  'still none beyond expiry' ], which LABELS a certified key may sign, a
  per-key role marker, a watermark that survives a restart [ section 6 ].
- **the `#:::` row is being planned** [ footer-line4-field-reconciliation.md,
  harmonic-transit-vision-architecture.md ] : positions 3-5 the litter bitmap
  [ 3 base32 chars, 15 bits ], 7-46 open [ a 3 x 5-bit zenki chain logged as a
  candidate only ], 47-77 the harmonic 15-bit coordinate [ `.` \ `:`
  interlaced ]. the row lies after byte 163 and is pinned only by the template
  compare [ all `:` today ] : filling it needs a template change and, once its
  values vary, binding [ section 3 ]. **row numbers differ between docs** :
  real footers have five rows [ `sign_template` : row 5 starts at byte 316 ].
  the reconciliation file calls `#:::` 'line 4' and says no fifth line
  exists ; SIGNED-COMMAND-INTERFACE's 'line 4' is the `#\[7]` row. this file names
  rows by their start [ `#,.` `#<bmw>` `#\\\|` `#\[7]` `#:::` ] so the two
  'line 4's are not merged.
- **no reverse index exists** : `index.contributions` holds character \
  sequence delta vectors per checksum, not 'who references this'.
  `storage.cmd.lookup-checksum` maps checksum -> files. the lookup this
  design needs is new [ small, below ].

## 1. the decision : v1 = plain text + the existing footer

two candidate forms were already in the tree :

| | text + AMOS7 footer | N7FS binary container |
|---|---|---|
| sign \ verify tools today | yes [ any key, by name ] | `AMOS7::N7FS` only |
| readable, diffable in git | yes | no [ base32 \ binary ] |
| signer in the record | no -> put it in the body | yes [ `signer_pub` ] |
| size of the signature part | 395 bytes [ the footer ] | 96 bytes |
| fits a 512-byte shm header | no [ carry the id ] | only a small one |

v1 takes the text form : the owner's project-style choice, the footer
code is mature, and a statement can be read, reviewed and diffed like
any other file. the binary container stays the N7FS record format ; a
binary statement, if ever needed for size, is `p7 statement 2` beside
v1, never a change to it.

**the smallest change : none to the footer LAYOUT.** the signer's public
key goes into the signed body ; the signed message grows by the slots
[ def 1, section 3 ]. a verifier :

1. parses the body [ section 2 ] and refuses anything not canonical
2. loads the `signer` pub with `crypt.C25519.load_from_string` under a
   derived name [ `stmt.<first 13 of key id>` ]
3. calls `source.signature_valid` with that key name, strict mode, with
   the truth checks of the declared footer type [ section 3 ]
4. checks the signer with `trust.verify` against the existing pin
   stores, as discover does for a packet [ section 6 ]

the new code is that wrapper, the parser and the def 1 message. the
footer layout and the sign loop stay as they are. the footer's signer
slot holds only a short recognizer [ section 3 ] ; the key itself is in
the body.

**footer expansion** : everything that COUNTS lives in the signed body :
signer, label, version and footer type. the footer adds one thing, the kind
word [ `DATA` for statements, `CODE` for code, section 3 ] -- and the kind is
bound into the signature [ def 1 ]. the AMOS header row [ AMOS checksum,
endline state, iteration count ] stays the footer machinery's own. the `#:::`
row gets one layout PER KIND [ section 3 ] : the DATA layout carries statement
hints [ label, signer, version ], the CODE layout the planned litter bitmap,
the open middle span and the harmonic coordinate. in def 1 the row is signed ;
statement hints are still checked against the body and never decide anything
on their own.

**reconcile** : SIGNED-COMMAND-INTERFACE.md [ and the rotation example
in ZENKA-IDENTITY-COMPONENT.md layer 3 ] place a key fingerprint on
the `#\[7]` row. that cannot fit the real template : that row holds the
second half of the 103-character signature. statements do not build on
that layout ; the signer lives in the body.

## 2. v1 : exact text

### encoding

- utf-8, LF only, no CR, no tab, no BOM, no trailing space on any line
- every line at most 4096 bytes ; the body at most 16 MiB [ larger sets
  use the tree form, section 7 ]
- base32 : rfc 4648 `A-Z2-7`, no `=` padding [ the project's
  `encode_b32r` ]
- `<bmw>` : BMW-384 of bytes, base32, 77 characters [ the N7FS content
  id ]
- `<pub>` : a raw 32-byte Ed25519 public key, base32, 52 characters
- **key id** of a pub = `<bmw>` of its 32 raw bytes [ HOST-ROOT-
  DELEGATION's pin format ]
- `<ntime14>` : decimal ntime, 14 digits zero padded,
  `( unix - 1023228000 ) * 4200` truncated [ N7FS-FORMAT-1 ]
- `<name>` : `[0-9A-Za-z_-][0-9A-Za-z._-]{0,254}` [ the
  `crypt.C25519.delegation_file` name rule ; all 6200 src names fit ]

### layout

```
p7 statement 1                       <- line 1 : magic + format version
label : <label>                      <- required fields, this order
subject : <text>
signer : <pub>
role : name | function
version : <decimal>
ntime : <ntime14>
previous : <bmw> | none
footer : full | form
<field> : <value>                    <- other fields, sorted by name
members : <count>                    <- always the last header line
<kind> [<name> ]<id>                 <- exactly <count> member lines,
..                                      sorted bytewise, no duplicates

#..... AMOS7 data signature footer [ as the sign run writes it ]
```

- header line : `<field> : <value>`, ONE space each side of the colon,
  no alignment padding. field names `[a-z][a-z0-9-]{0,62}`, each at most
  once. values : printable utf-8, no leading or trailing space
- `label` : `p7 <words> v<n>` [ lowercase ascii words, `[a-z0-9 .-]` ].
  the label says what is asserted AND fixes how members and extra fields
  are read. labels double as domain separation
- `subject` : what the statement is about [ a key id, a disk id, a
  group name, `protocol-7 src` ], at most 255 bytes, defined per label
- `version` : decimal, no leading zero, 1 .. 2^63-1. strictly higher
  for each new statement of the same state key [ section 4 ]
- `previous` : the id [ section 4 ] of the statement this one replaces,
  or `none` for the first. the label says whether `none` is allowed
  after version 1 [ PRIVACY-PRESERVING-IDENTITY-CREDENTIALS' mode B ]
- `footer` : the footer type the signer produced [ section 3 ]
- `members : 0` is allowed : the empty set [ how a set is withdrawn ]
- member line : `<kind> <id>` or `<kind> <name> <id>`, the id always
  last. v1 kinds :
  - `content <bmw>` : bytes with that BMW-384 [ a file, an N7FS node ]
  - `statement <bmw>` : another statement, by its id
  - `key <pub>` : a public key
- the body ends with exactly one LF after the last member line [ after
  `members : 0` when empty ]. the sign run then adds the separator LF
  and the footer
- **the canonical form is the only form** : a verifier checks the bytes
  as stored and refuses any other spelling [ wrong order, padding,
  unsorted members, a missing or extra LF ]. it never normalizes and then
  verifies. so the sign run's endline harmonization never changes a
  statement : the bytes the signer reviewed are the bytes signed

### fields every v1 verifier knows

required : `label subject signer role version ntime previous footer
members`. defined optional fields, understood by every v1 verifier when
present :

- `not-before : <ntime14>`, `not-after : <ntime14>` : validity window,
  both inclusive
- `chain : <trust.chain field>` : the signer's `p7 delegation v1` chain,
  leaf first, `.`-joined, at most 2048 chars -- the same bytes as
  discover's `dlg:` line [ section 6 ]
- `signer-name : <name>` : display only. a name in a statement is a
  claim ; names that count come from verified delegations [ section 6 ]
- `critical : <field>[ <field> ..]` : extension fields that a verifier
  MUST understand [ below ]
- `note : <text>` : free text, ignored

### extension rules [ fixed in v1 ]

1. line 1 other than `p7 statement 1` : refused [ an unknown format ]
2. an unknown `label` : refused. a verifier only accepts labels it
   implements
3. an unknown member kind : refused
4. an unknown field : ignored, unless named in `critical` -- then
   refused. the same rule as JOSE `crit` [ rfc 7515 section 4.1.11 ] and
   X.509 critical extensions. `critical` naming a defined v1 field, or a
   field that is absent, is refused
5. fields a LABEL defines [ e.g. `action` of a key event ] are part of
   that label : a verifier that implements the label knows them, and one
   that does not refuses the label anyway
6. a meaning change comes only through a new label [ `p7 module set v2` ]
   or a new format [ `p7 statement 2` ]. a v1 label's meaning is never
   changed in place, not even to 'fix' it
7. an unknown `footer` value : refused. new footer types are new values,
   accepted only where a label lists them
8. a statement's footer kind word is `DATA`. any other word [ `CODE`, or
   one not defined ] : refused before anything is hashed

## 3. footer types and footer kinds

two independent axes : the TYPE [ how many truth criteria, named in the
body ] and the KIND [ code or data, named and bound in the footer ].

### types : full and form

for speed the owner allows footers with fewer truth criteria. v1 defines
two types, named in the signed body :

| type | sign side | verify side | signing cost |
|---|---|---|---|
| `full` | as today : `create_harmonic_footer` searches until the rows, the BMW line and both signature halves pass the ELF truth checks | binding checks + the ELF truth of the whole payload with footer [ `entire-payload`, essential ] | the search [ median 14142 iterations ] |
| `form` | the same five rows, the same signed message, no truth search | binding checks only ; truth results report-only | one pass : one BMW, one signature |

the **binding checks** are the same for both and never relaxed : the
AMOS checksum of the payload matches row 1, the BMW line matches, the
Ed25519 signature verifies. in strict mode `source.signature_valid`
returns FALSE at once on any of the three, outside its truth map. the
statement wrapper verifies strict mode only and additionally requires
`AMOS-chksum-matches`, `bmw-chksum-matches` and `signature-is-valid`
TRUE in the returned report -- never the overall return value alone.

- **what the strength is, truthfully** : both types rest on the same
  BMW-384 + Ed25519. the truth checks add no forgery resistance -- a
  forger needs the private key for either. `form` gives up the harmonic
  truth property of the footer, not cryptographic strength. verify cost
  is close for both [ one BMW pass, one Ed25519 verify, plus the checks ] ;
  the large saving is on the signing side.
- **two small code changes, not ready today** :
  - `source.signature_valid` takes a truth map parameter [ `RQ` \ `OP` ]
    and fills it with defaults [ line 75 ], but the checks then read its
    own `$truth_check_settings` [ lines 403, 420, 624, 638 ] : a caller's
    map has NO effect. a `form` verify needs the passed map honoured --
    for the truth checks only, the binding checks stay outside it.
  - `create_harmonic_footer` has its truth switches as constants : a
    `form` sign needs them as a parameter.
- **no downgrade by relabeling** : the type is the `footer` field of the
  signed body, never footer text. the verifier returns the type it
  checked, `footer-checked : <declared type>`. a `full` declaration whose
  truth checks fail is refused, never accepted as `form`. a `form`
  declaration never counts as `full`, even when its footer happens to
  pass every truth check -- strength is never inferred from how a footer
  looks.
- **per label minimum** : every label states the weakest type it accepts
  [ the table in section 10 ]. `p7 module set v1`, `p7 upgrade v1`,
  `p7 disk nodes v1`, `p7 key event v1`, `p7 capability v1`,
  `p7 revoke v1` : `full` only. `p7 set part v1` : `form` allowed [ its id
  is fixed by a `full` root ]. high-rate labels [ status \ presence
  announcements, none defined yet ] : `form` allowed.
- **no type marker in the footer** : the `data-type` slot [ byte 298 ]
  holds the KIND [ below ], never the type -- `full` and `form` footers
  of one kind look the same ; the type is read from the body only.
- even cheaper forms [ no footer at all, a raw signature as discover
  signs packets ] are not statements. if needed, a new footer type or
  `p7 statement 2`.

### kinds : CODE and DATA [ owner plan ]

today every footer says `DATA SIGNATURE`, code included. the plan : code
files carry `CODE SIGNATURE`, which frees `DATA SIGNATURE` for real
data -- statements first. it is a VALUE change, not a layout change :
`source.fill_source_template` already has a fixed 4-character
`data-type` slot [ footer offset 298, the `#\[7]` row, column 61, value
`DATA` ], and `CODE` fits it. `source.extract_sig_body` already lists
`CODE-SIGNATURE` [ next to `TEXT-` and `TRANSIT-` ] among its patterns,
but nothing writes it, and the hyphen forms do not match the real
`DATA SIGNATURE` text [ the generic `SIGNATURE` pattern catches it ].
`TEXT` and `TRANSIT` stay reserved : refused until defined.

**why the kind must be bound [ owner, checked against the code ]** : the
footer has two meaning-shaped slots, and neither is in the signed
bytes :

| slot | offset | today | written by |
|---|---|---|---|
| `signature-type` [ the signer slot ] | 219-232, right-aligned to end before 233 | `AMOS7 \ YOURUM`, a constant | `$sig_name_str` in `fill_source_template` |
| `data-type` [ the kind ] | 298-301 | `DATA`, a constant | `fill_source_template` |
| the `#:::` row | 316-394 | all `:` | the template |

the sign buffer is the header row + `#` + the BMW row + the 5 template
characters at 158 [ `$sig_template_prefix` = `#\\\|` ] -- 163 bytes ;
`source.signature_valid` verifies over `substr( footer, 0, 163 )`. the
slots enter the `entire-payload` ELF truth check [ the whole footer
string is added ] -- a truth property, not a signature.

**no current weakness** : strict extraction compares the footer with the
ONE template [ BMW and signature positions blanked ], so a changed slot
is refused today. the forward point : once two valid templates, kinds or
signers exist, template validation accepts EITHER, and a flipped slot
would pass both the compare and the signature. so the kind and the
signer must be bound to the signature BEFORE a second value exists --
by signed bytes [ def 1 below ] or by a per-kind template the signature
commits to [ the same thing : def 1 signs the slot values ].

**v1 rule : a footer slot may carry meaning only once it is signed.**
v1 defines two signed-message definitions :

| definition | Ed25519 message | allowed slot values |
|---|---|---|
| **def 0** [ today ] | the 163 bytes | only the one template's constants : `AMOS7 \ YOURUM`, `DATA`, a row of `:` -- pinned by the template compare |
| **def 1** | the 163 bytes . kind slot [ 4 ] . signer slot [ 14 ] . the signed copy of the `#:::` row [ 77 ] = 258 bytes | any defined value |

- the signed copy of the row = its 77 characters after `#`, with every
  field the kind's layout marks as set in transit [ after signing, e.g.
  by a router ] replaced by `:`. the v1 layouts mark none ; any later transit
  field is explicitly unsigned and never carries trust.
- **the signer slot in def 1** : `AMOS7 \ ` + the first 6 characters of
  the signer key id [ 30 bits ]. a footer can hold only a short
  RECOGNIZER, never the key [ a pub is 52 characters ] : it selects which
  key to try, cheaply, and the signature confirms it. the full key comes
  from the body [ statements ] or from the anchors \ pins [ code ].
- **no downgrade, no upgrade** : a def 1 signature checked as def 0 is
  checked over 163 bytes it never signed, a def 0 signature as def 1 over
  258. the lengths differ, so neither message can equal the other. a
  verifier may try both definitions where both are allowed : each is
  checked cryptographically, and def 0 is allowed only where every slot
  holds its constant, which carries no meaning.
- **kinds by definition** : `CODE` exists only in def 1 [ nothing carries
  it today ]. statements are always def 1 [ there are no old statements ]
  -- kind, signer recognizer and row hints of a statement are signed from
  the first one. other data files keep def 0 until re-signed, and may
  move to def 1 freely.
- one key [ the sourcecode key ] may sign both kinds safely : the kind is
  inside its def 1 message.

this is domain separation at footer level, BELOW the statement label : a
code footer is never accepted where a data statement is required, and
the reverse.

**the verifier, cheapest test first** :

1. read the 4 bytes at footer offset 298 -- a fixed-offset compare, no
   hashing, no parsing. `DATA` or `CODE`, anything else refused.
2. compare with the kind the CALLER requires : the module loader and the
   code verify runs require `CODE` [ or legacy def 0 `DATA` inside the
   window below ] ; the statement verifier and data verify runs require
   `DATA`. a mismatch is refused here, before the payload is read.
3. pick the key by the signer slot [ def 1 ] or by context [ def 0 :
   the expected key, as today ], then verify the definitions allowed for
   that kind and path, then the binding checks [ above ].

the word only selects which definition to try ; what the caller accepts
never comes from the footer.

**the sign tools** decide the kind by PATH CLASS, never by content and
never by a flag on a whole-tree run : `sourcecode.source_path_set_up`
gets a class per entry. code : `src`, `bin` and `bin/**`. data : the
rest [ `data/md`, `data/yaml`, `data/ai-mem`, `data/tasks` .. ].
`data/lib-path/pm/` [ perl modules ] and `cfg/zenki/*/zenka.v7`
[ interpreted start files ] are code by what they do -- open question 12.
the statement signer always writes `DATA` def 1 and refuses `CODE`.

**transition** :

1. **tools first** : `fill_source_template` takes kind, signer slot and
   row, and signs the def 1 message ; `signature_valid` verifies both
   definitions [ the 163 at line 569 becomes per definition ] ;
   `extract_sig_body` compares the fixed decoration with the template and
   checks each slot's syntax per kind [ the compare can no longer pin
   values that vary -- the signature does, in def 1 ]. code paths
   accept `CODE` def 1 and legacy `DATA` def 0. sign runs still write def 0
   for existing files -- no file changes yet. statements start as def 1.
2. **the sweep** : one sign run re-signs every code-class file as `CODE`
   def 1, in one commit ; the module set statement is regenerated right
   after [ its member ids change with the footers ]. the word matchers move
   in the same commit : `coding.validate.module` [ line 113, requires
   `DATA SIGNATURE` ], `coding.helper.strip_signature`, the
   `extract_sig_body` pattern lists, the pre-commit test [ line 358 ;
   `YOURUM` matches both until the signer slot changes -- the test must
   match `SIGNATURE ::` on the `#\[7]` row instead ].
3. **the window** : a legacy def 0 `DATA` footer on a code-class path is
   accepted AS CODE from step 1 until the window closes. it closes at a
   fixed source version : a constant in the verifier, `legacy DATA code
   footers until src-ver <sweep + 1 release>` [ proposal ]. after it, def 0
   on a code path is refused, and the pre-commit hook refuses a staged
   code file without `CODE`. `CODE` on a data path is refused from step 1
   on -- nothing carries it today, so that direction needs no window.
4. inside the window LEGACY code and data footers share def 0 and are not
   separated by the footer. what still holds : a statement must start
   `p7 statement 1`, is def 1 and is never a module set member ; a module
   never parses as a statement. the window opens no gap beyond today's,
   where everything is def 0 `DATA`.
5. data files move to def 1 when they are next signed, or in a later
   sweep [ open question 14 ] ; def 0 stays valid for data while its slots
   hold the constants.

### the `#:::` row : one layout per kind

the expansion bits are read only AFTER the kind word, through that
kind's own table. a field definition belongs to exactly one table ; both
tables may use the same positions with different meanings, and neither
borrows the other's definitions. positions as in
footer-line4-field-reconciliation.md [ `#` = 1 ].

CODE row v1 = the reconciliation's composed layout, unchanged [ its
fields were designed for modules ] :

| positions | field |
|---|---|
| 3-5 | litter bitmap, 15 bits : zenka involvement 0-6, transport 7, trunks 8-14 |
| 7-46 | open : load facts [ owner examples : load-early, floor perl, start class -- not fixed ] |
| 47-77 | harmonic 15-bit coordinate [ `.` \ `:` interlaced, validation from position 7 ; signed -- if it is set after signing it becomes a transit field, open question 13 ] |

DATA row v1 [ proposal ] :

| positions | field |
|---|---|
| 3-9 | label hint : `amos_of_bytes( label )` [ AMOS7::N7FS::Sum, the N7FS content rule ] |
| 11-17 | signer hint : the first 7 chars of the signer key id [ TRUST-CHAIN-STEP2's recognizer 'label' ] |
| 19-25 | version hint : base32 of `version` mod 2^35 |
| 27-46 | open |
| 47-77 | reserved : a data coordinate only if the DATA table defines one, by its own definition |

- `:` at 2, 10, 18, 26 delimit the fields ; a data file that is no
  statement leaves every DATA field as `:`.
- **hints, never authority** [ signed in def 1, still only hints ] : after
  full verification the statement verifier compares each filled hint with the
  body, and a mismatch refuses the statement. a scanner may pre-select
  candidates by hint [ 'module sets by this signer' without parsing bodies ] ;
  a lying hint can only make it skip one -- a denial, never an acceptance.
- **layout versions** : a DATA layout change comes with a new footer
  type [ the body names it ]. CODE files have no body, so a CODE layout
  change needs an in-row marker -- open question 13 [ proposal :
  position 2, `:` = layout 1 ].

## 4. ids, state, current set

- **statement id** = `<bmw>` of the whole file, footer included -- its
  N7FS content id. it is not a second id next to the N7FS address.
- **state key** = ( `label`, signer key id, `subject` ).
- **current** : the valid statement with the highest `version` for a
  state key is the state. older ones are history.
- **equivocation** : two valid statements with the same state key and
  the same `version` but different payload bytes. refused BOTH, and
  reported as signer misuse : the state key stays refused until a higher
  version arrives, or an issuer of the signer's delegation issues a key
  event [ open question 3 ].
- **the witness** [ anti-rollback ] : each verifying host keeps, per
  state key, the highest ( version, id ) it accepted :
  `<var_P7>/statements/seen` [ 0600, outside the repo and outside any
  N7FS disk ]. a statement below that version, or at that version with a
  different payload, is refused. first contact [ no witness entry ] accepts
  the presented newest -- trust on first use, as in N7FS-FORMAT-1.
- **damaged newest refuses** : if the statement the witness or the
  publication slot names as newest is missing, unparseable or fails
  verification, the state key is refused. there is no fallback to an
  older version [ N7FS-FORMAT-1 'deviation' : a fallback there is exactly
  what a rollback or a planted file wants ].
- `previous` gives the audit chain [ mode A ]. it is checked when the
  previous statement is at hand [ it must have the same state key and a
  lower version ] ; a missing previous is not an error, the version
  number carries anti-rollback. a statement whose `previous` is already
  named by another valid statement of the state key is a fork : the
  higher version wins, the fork is logged.

## 5. location : nowhere specific

- a statement is content-addressed : its id is its checksum. it can be
  a plain file anywhere, or an N7FS content node [ a format 1 reader
  takes it as plain content : no new magic row in v1 ].
- a path is only a publication slot, never meaning : the verifier takes
  label, signer and subject from the signed body, never from a file name
  or directory.
- **the repo slot** : `data/statements/`. it is not in
  `sourcecode.source_path_set_up` and not matched by the pre-commit
  unsigned-file test [ `.pl .pm .yaml .sh`, `src\ bin\ cfg`, `.md` ], so
  the sourcecode sign run never re-signs an owner- or release-signed
  statement with the sourcecode key, and never reports it invalid. the
  module set's slot : `data/statements/p7-module-set.statement`, replaced
  in place ; git history holds the old versions [ git itself is not
  trusted : the witness is ].
- **parallel signatures** = more statements naming the same subject or
  member : nothing is attached to a key directory, no key directory
  grows [ the owner's 'clean signature trees' ].
- **finding statements about X** = an index lookup, never a directory
  scan : `<var_P7>/statements/index`, rebuilt from the statements a
  host holds, maps subject -> ids, member id -> ids [ 'which sets is
  this in' ], state key -> newest id. like files' heads index it is never
  the authority for 'newest' : the witness and the signatures are. when
  N7FS `references/` lands, the index moves into the disk.

## 6. signers : the trust chain discover already uses

**reused as built, nothing designed anew** :

- **activation** = a `p7 delegation v1` statement [ `trust.statement` ] :
  issuer, subject pub, dot name, not_before \ not_after, scope. that IS
  the owner's parent-signs-( subkey, time, action = activate ), with an
  expiry on top [ 30 days host-root, 365 days owner ]. no second
  activate format.
- **the chain** travels in the statement's optional `chain` field, the
  same bytes as discover's `dlg:` line ; `trust.chain split` parses it.
- **verification** is discover's path, with the statement as the
  packet : the signer pub comes from the signed body [ discover : the
  header pub ], the footer verifies under it [ discover : raw Ed25519 ],
  then `trust.verify { chain, anchors, subject => signer pub, now,
  distrust }` -- scope narrowing per hop, chain length 4, the local
  distrust list read fail closed [ `auth.client.distrust_list` ].
- **anchors** = the existing pin stores : owner key ids
  [ `auth.client.owner_pins` ], host-root key ids
  [ `discover.read_host_root_pins`, read only ], plus the sourcecode key
  id from the `bin/Protocol-7` data block. a signer whose own key id is
  an anchor for the label needs no chain. a statement verifier NEVER
  writes a pin [ as discover ].
- **names** : the verified name of the last delegation [ `trust.verify`
  returns it ] is the signer's name. `signer-name` in the body is only
  display.

**missing, added as statement labels or local files** :

1. **label rights** : a delegation says which NAMES a key may certify,
   not which labels it may sign. -> the label policy : per label the
   accepted signer name pattern [ the scope grammar : `<name>`,
   `<prefix>.*` ], the role, the minimum footer type. defaults live in a
   `src/` module [ name open ], so the module set covers them ; a host's
   `<var_P7>/statements/policy` [ 0600 ] can only NARROW them. the parser
   and verifier as AMOS7 code under `data/lib-path/pm/` are OUTSIDE the
   module set : trusted base, like `bin/Protocol-7` [ a `p7 lib set v1`
   over `data/lib-path/pm` is open question 11 ]. example :
   `p7 module set v1` <- the sourcecode anchor, or a name below
   `<owner>.release.*` [ owner choice, open question 1 ].
2. **role** [ name authority vs delegated function ] : delegation v1 has no
   marker. -> `p7 key event v1` with `action : role` and `key-role : name
   | function`, signed by an issuer of the key's delegation [ subject = the key
   id ]. without one, a key's role is the role the label policy grants its
   name. the statement's own `role` field must equal it :
   - `name` : vouches 'this key belongs under this name'. signs only
     delegations, key events and `p7 group v1`. no right to act.
   - `function` : passes down permission to act, within the label
     policy.
3. **removal before expiry** : TRUST-CHAIN-STEP2 has only expiry plus a LOCAL
   distrust file. -> `p7 key event v1` with `action : remove` by an issuer of
   one of the key's delegations, or by the key itself : a distrust entry that
   travels. a verifier adds every current remove event it holds to the
   `distrust` input of `trust.verify` -- one code path for both.
4. **a persistent watermark** : discover's per-sender ntime watermark
   lives in memory and resets on restart. statements need it per state
   key and on disk : the witness [ section 4 ].
5. **name-role signers are not leaves** : `trust.verify` requires the
   LAST statement's own scope to be `''`. a `name` key certifies names,
   so its delegation has a non-empty scope and `trust.verify( subject =>
   signer )` refuses it. -> a verify mode for issuer keys [ a code mode
   of `trust.verify` : the last scope may be non-empty, the statement's
   subject must then fall inside it -- a key event's or group's names
   under the signer's scope ]. a code change, no format change.
6. **announcing heads** : discover shares orbital p7refs ; it has no
   packet that announces a statement's newest id. a later `p7ref`-style
   line [ `p7://checksum:<id>` ] fits there -- TRUST-CHAIN-STEP2's
   'self-propagating statements', not needed for v1.

`p7 key event v1` fields : `subject` = the key id, `action : remove |
role`, `key-role` [ with `role` ], members : one `key <name> <pub>`. the
old `.ks` \ `.sk` edges of `crypt.C25519.sign_keys` are not read [ no
label, no time ; TRUST-CHAIN-STEP2 migrates `sign-key` to delegations ].

## 7. multiple memberships, cycles, tree form

- **memberships in all directions** : a key, content or statement is a
  member of as many sets as name it ; nothing is exclusive. 'which sets
  is X in' is the member index lookup. a group is a statement
  [ `p7 group v1`, subject = the group name ] whose members are keys and
  other group statements.
- **cycles** : a statement cannot contain its own id, and a cycle of
  content ids would need a checksum fixpoint, so `statement` members
  form a dag by construction. cycles among KEYS [ A certifies B, B
  certifies A ] and among groups named by subject are possible : every
  walk carries a visited set and the depth limit, and a cycle never adds
  standing.
- **tree form** [ for large sets ] : label `p7 set part v1` -- the same
  signer, `subject` = the parent's subject, members = one range of the
  set. the root statement lists its parts as `statement <bmw>` members,
  sorted, and its id fixes the whole tree : a checksum tree, as N7FS-SPEC
  and FILES-ZENKA open question 19 ask. a verifier fetches only the parts
  it needs ; each part is checked against its id from the root.
  the module set needs no tree : about 710 KB inline [ 6200 lines ].

## 8. what is signed : the canonical bytes

- the **payload** = every byte from `p7 statement 1` to the separator LF
  before the footer, as stored.
- the footer's BMW line = BMW-384( payload . line 1 . `#` ) ; the
  Ed25519 signature is over line 1 + line 2 + `#\\\|` [ 163 bytes, def 0 ]
  or those 163 bytes + kind + signer slot + the `#:::` row [ 258 bytes,
  def 1 -- every statement ].
- **cross-type confusion is impossible by shape** :

| signed message | starts with | length |
|---|---|---|
| AMOS7 footer def 0 [ today's files ] | `#` + `,` \ `.` | 163 bytes |
| AMOS7 footer def 1 [ `CODE`, statements ] | `#` + `,` \ `.` | 258 bytes |
| `crypt.C25519.sign_keys` | raw pub | 32 bytes |
| `p7 delegation v1` | `p7 delegation v1\0` | variable |
| N7FS records | `P7FS P7FA P7FU` + format byte | variable |
| files cap v1 [ designed ] | `p7 files cap v1\0` | variable |
| discover packet | `[:<|` + type | variable |

  under def 1 a code footer and a statement footer differ in the signed
  kind word. under def 0 [ legacy code inside the window ] they are the
  same kind of signature, and the payload keeps them apart. a
  statement starts with `p7 statement 1`, a module with `## [:< ##` ; a
  statement verifier refuses anything else on line 1. inside statements,
  the label separates kinds.
- **the sourcecode key signs only `p7 module set v1`** among statements.
  other labels go to their own keys : that limits what a stolen
  sourcecode key can assert.
- **the signing oracle** : a signer outside the process [ host-root
  through `p7c v7-zenki.*`, a hardware token ] receives the WHOLE
  statement, parses it, checks the label against its allow-list, and
  runs the footer loop itself. it never offers 'sign these 163 \ 258
  bytes' :
  that would sign footers for anything, src modules included
  [ N7FS-FORMAT-1 : host-root never becomes a general signing oracle ].

## 9. first adopter : the signed module set

label `p7 module set v1` :

- `subject : protocol-7 src`
- signer : the sourcecode key, `role : function` [ anchor on day one ]
- label fields : `src-ver : <cfg/protocol-7.src-ver line>` [ ties the set
  to the source version ]
- members : one `content <module name> <bmw>` per file of `src/`. the
  bmw is over the WHOLE module file, footer included [ the N7FS content
  id ]. module names unique. the set does not list itself [ it lives in
  `data/statements/`, not in `src/` ].
- **load rule** : a module loads only if its name is a member AND the
  bytes on disk hash to the member's id. a restored deleted module is not
  a member ; a restored OLD version of a listed module has the wrong id.
  both refused -- the second case is the gap the name-only list leaves.

the example below is complete and consistent but cut to 5 members [ the real
statement lists all 6200 ]. **real values** : the signer is the sourcecode
public key from `bin/Protocol-7` [ `base.protocol-7.source-key`, key id
`2B2Z7RK33UXXAFH7X7BNEI7A27V6JMGCKS4QWZU76URYYH5UYF3LFENHBSLBIJWUOMHPKOXDU24SC` ],
the member ids are BMW-384 of the files at 49a2f5d3 [ they change on every
re-sign ], `src-ver` is `cfg/protocol-7.src-ver` at 49a2f5d3, and the ntime
was computed 2026-10-22 03:18 utc. **example values** : the member count of 5
and `version : 1`. `footer : full` is the label's minimum. the footer is the
`sign_template` of `source.init_code` with the def 1 slots filled -- real
values : the signer slot `AMOS7 \ 2B2Z7R` [ first 6 of the key id ], and the
DATA row hints `LRPXVLQ` [ the label, `AMOS7::N7FS::Sum::amos_of_bytes` ],
`2B2Z7RK` [ signer ], `AAAAAAB` [ version 1 ]. the AMOS, BMW and signature
positions stay unfilled : NOT a valid signature.

```
p7 statement 1
label : p7 module set v1
subject : protocol-7 src
signer : JXA7AXE6PUORNNRI2F6PEFQKZSGUL2PKIOTXIGMHDUI6GHA4YWRA
role : function
version : 1
ntime : 03231526582200
previous : none
footer : full
signer-name : proto-7.sourcecode
src-ver : 32DK5W4TEA-10156.0
members : 5
content base.init V7WZYD5K75TQVAYH47ZCSRAEIHNWM6GLTKAMLJ26QM5JNI44NJWDEAOR7VJBXQ5PQMAM2L46RYGSA
content base.list.subroutines EICHT3QFTPVHTWDFGTNJE6B3QEDMS7HJ2QTPRP2WXDDPV7RXULBHPKJI5IXXZ2ENKVQ37HQ3B2H72
content base.log Q5D4UZH57AMBMGTE4PJDZ4QRI46L2DYWRED6EOWEUVUI4IBRXQLPFABJL4UYRTDQNY5KPFSTYPGLG
content note.tag LHMBQ3RCCOA6BIAF35YIMRIALG7CQUAJI626RYCVA2FICVMPTZT2NPZYPNEYZZ7Y4I56TYDMRPFLC
content ui.fold F2KNOPEWM2AAQOTYAFLKTFY3T2SWINST5NVL6JGJIM6X2UIGKPRZJT7KW7XLAAJEVQQ3KNFVTO3KA

#..........,..........,..........,..........,..........,..........,..........,
#_____________________________________________________________________________
#\\\|___________________________________________________ \ / AMOS7 \ 2B2Z7R ::
#\[7]____________________________________________________ 7  DATA SIGNATURE ::
#:LRPXVLQ:2B2Z7RK:AAAAAAB:::::::::::::::::::::::::::::::::::::::::::::::::::::
```

the next version : `version : 2`, `previous : <id of this file>`, new
member lines for every changed module.

## 10. the other users, as v1 labels

each is a label table entry, not a new format.

| label | subject | members | signer | min footer | replaces |
|---|---|---|---|---|---|
| `p7 key event v1` | key id | one `key` | the key's issuer \ the key | full | expiry-only revocation ; the missing role marker |
| `p7 group v1` | group name | `key`, `statement` | group key | full | ZENKA-IDENTITY 'membership' edges |
| `p7 disk nodes v1` | N7FS disk id | `content` [ tree form ] | store key \ release key | full | FILES q19 : the signed node set |
| `p7 upgrade v1` | appliance class | one `statement` [ a disk nodes root ] | release key | full | FILES q19 : the signed upgrade stick |
| `p7 capability v1` | holder identity | `content` [ optional ] | owner \ host-root | full | files cap v1 + shm permissions |
| `p7 shm permissions v1` | mapping id | `statement` [ capabilities ] | mapping owner | full | the shm header permission list |
| `p7 revoke v1` | issuer key id | `statement` [ caps revoked ] | the issuer | full | files `cap-revoke` records |
| `p7 set part v1` | the root's subject | one range | the root's signer | form | -- [ tree form ] |

- **capability** [ one format for files section 9 and the shm
  permissions ] : label fields `host`, `path-prefix` or `branch`,
  `rights`, `cap-id`, `max-uses`, with `not-before` \ `not-after` from
  v1. the shm header [ 512 bytes ] carries ONE id : the current
  `p7 shm permissions v1` statement of the mapping [ 77 bytes ]. the
  placeholder hash in `AMOS7::SHM` goes ; until then shm permissions
  protect nothing against a writer of the header.
- **group manifests** of files stay unsigned content nodes [ their id is
  fixed by the group record ] ; they can use the member line grammar
  now and become `p7 group v1` statements when a group needs a signer.
- **privacy credentials** [ PRIVACY-PRESERVING-IDENTITY-CREDENTIALS ]
  stay outside this format : a statement names its signer and is meant
  to be linkable. unlinkable credentials keep their own opaque form.

## 11. revocation

- **of a statement** : publish a higher version of its state key -- with
  new members, or `members : 0` to withdraw the set. the witness makes
  the older version unacceptable on every host that has seen the newer.
- **across state keys** [ capabilities ] : `p7 revoke v1` by the issuer
  lists the revoked statement ids ; it counts until each one's own
  `not-after`.
- **of a signer** : a `p7 key event v1` with `action : remove` by the issuer
  of the key's delegation ; it enters `trust.verify` as a distrust entry
  [ section 6 ]. a delegation also simply expires. from then on NO statement of
  that key verifies, whatever its ntime : ntime is asserted by the signer, and
  a stolen key can backdate. statements that must survive are re-signed by the
  successor key [ a sign run, cheap ]. 'accepted before removal' exists only
  as witness entries made before the removal [ open question 2 ].
- **self-removal** : a key may sign `action : remove` for its own key id.
  a thief can do that too, which only helps.
- **anchors** are changed only out of band [ the pin stores, by command
  only, as today ] : nothing signed can remove the root of trust it hangs
  from. a local `p7-keys distrust` stays the emergency path.

## 12. threat model

| attack | what stops it | limit |
|---|---|---|
| restore a deleted module | not a member of the current set | needs the load rule [ stage 4 ] |
| restore an old version of a listed module | member id mismatch | same |
| restore an old set + old modules together | witness version | first contact is trust on first use |
| edit `AMOS7 \ YOURUM`, `DATA` or the `#:::` row | def 0 : the template compare ; def 1 : signed slots | -- |
| a footer relabeled CODE <-> DATA | the kind is in the def 1 message ; def 0 allows only `DATA` | legacy code files inside the window |
| re-label : a statement read as another kind | label in the signed body ; unknown label refused | -- |
| a statement read as a module or the reverse | line 1 ; the set never lists statements | -- |
| footer signature reused as delegation \ N7FS \ key sig | message shape [ section 8 ] | -- |
| non-canonical twin parsed differently | stored bytes only, refuse any other spelling | -- |
| signer key stolen | key event `remove`, delegation expiry ; the label policy limits the labels | until the removal reaches the verifier |
| equivocation [ two version N ] | both refused, reported | open question 3 |
| rollback of the witness | outside the repo, 0600 | a local root can reset it |
| damaged or missing newest | refused, no fallback | denial of service by deleting it |
| signer as oracle | whole-statement signer, label allow-list | the in-process sourcecode sign run |
| BMW-384 collision | none beyond BMW-384 | the whole footer scheme shares it |
| pre-commit lets a broken statement pass | statements are outside its file set today | stage 2 verifies staged statements |
| a `form` footer taken as `full` | type in the signed body ; the checked type is returned ; label minimum | -- |
| meaning planted in the `#:::` row | signed in def 1 ; hints compared with the body | TRANSIT fields [ none in v1 ] stay unsigned |
| a policy file widened | the local file can only narrow the code defaults | -- |
| the verifier code or its anchors replaced | out of scope : they are the trusted base | a writer of `bin/Protocol-7` or `data/lib-path/pm/` owns the verifier |
| a `form` verify that skips payload binding | binding checks outside the truth map ; the wrapper requires them in the report | -- |

## 13. adoption order

1. **v1 module set** : the sign run [ `update-signatures`, after all
   modules are signed : the ids include footers ] writes
   `data/statements/p7-module-set.statement` from the same file walk
   `update-sub-list` uses, and signs it with the sourcecode key it already
   loaded. the parser + verifier wrapper [ section 1 ] land as AMOS7
   module code, usable by zenki and scripts. prerequisite : def 1 in
   `fill_source_template` \ `signature_valid` \ `extract_sig_body`
   [ section 3, transition step 1 ] -- statements are def 1 from the
   first one. the `form` type waits for
   its two code changes [ section 3 ] ; the module set needs only `full`
   and starts without them.
2. **verify** : a `sourcecode verify-module-set` command [ name open ] ;
   the pre-commit hook calls it on a staged statement, next to its
   existing `verify-p7-signatures` run.
3. **the CODE sweep** [ section 3 ] : every code-class file re-signed as
   `CODE` def 1 in one commit, the module set regenerated after it, the
   window constant set.
4. **enforce at load** : the module loader checks name + id against the
   current set. THIS step closes the restore attack ; steps 1 to 3 only
   prepare it.
5. **retire `base.list.subroutines`** : `subroutine-list` reads the
   statement ; the three `subroutines.load-early` lists drop the entry ;
   the module goes. until then it is regenerated as today.
6. **signers beyond the sourcecode key** : the label policy ; a release
   key certified by the owner key with a `p7 delegation v1` [ the
   `p7-keys` certify tools ] ; `p7 key event v1` for remove \ role. the
   module set moves to the release key if the owner wants [ open
   question 1 ].
7. **capabilities** : files' cap v1 is written as `p7 capability v1`
   before its first line of code ; the shm permissions switch to it.
8. **disk nodes + upgrade** : `p7 disk nodes v1` with the tree form, then
   `p7 upgrade v1` [ FILES open question 19 ].
9. **groups** : `p7 group v1` when the users \ user-edit work needs
   group keys [ ZENKA-IDENTITY-COMPONENT open question 3 : custody ].

## open questions for the owner

1. **the module set signer** : the sourcecode key [ zero setup, today ]
   or a release key activated by the owner key [ stage 6 ]. proposal :
   sourcecode key now, the label stays the same when the signer changes.
   a new signer starts a new state key, so the witness needs one
   'successor' rule : a statement by the old key naming the new one
   lets its last version carry over.
2. **removal and history** : after `remove`, should statements the
   witness accepted BEFORE the removal stay valid on that host ?
   proposal : no -- re-sign instead ; it is simpler and backdating-proof.
3. **equivocation** : refuse the state key until a higher version, or
   until a parent key event ? proposal : until a parent key event --
   two version N statements mean the key is no longer trusted.
4. **witness signing** : a plain 0600 file in v1 ; signed by the host key
   [ as the N7FS use window ] later ?
5. **first contact** : trust on first use for the module set, or require
   the presented set to match a version shipped inside `bin/Protocol-7` ?
6. **the slot name** `data/statements/` and the file suffix
   `.statement`.
7. **`src-ver` vs `version`** : keep both [ proposal ], or make the
   statement version the src-ver counter ?
8. **load-time cost** : enforcing the set hashes all of `src/` [ 15.4 MB at
   49a2f5d3 ] at each zenka start, or only the modules a zenka loads
   [ proposal ] -- measure before choosing.
9. **footer type names** : `full` \ `form`.
10. **label rights by name** : the policy maps labels to certified NAME
    patterns [ e.g. `<owner>.release.*` ]. enough, or should a delegation
    carry label rights itself [ a new label, never a change to
    `p7 delegation v1` ] ?
11. **the AMOS7 library** : `data/lib-path/pm/` [ parser, verifier,
    `AMOS7::*` ] stays outside the module set. a `p7 lib set v1` over it,
    signed like the module set, or trusted base as now ?
12. **path classes** : `data/lib-path/pm/` and `cfg/zenki/*/zenka.v7`
    execute -- `CODE` [ proposal ] although they are not under `src\ bin` ?
13. **CODE row layout versions** : an in-row marker [ proposal :
    position 2, `:` = layout 1 ] or a new kind word per layout ? and is
    the harmonic coordinate fixed at signing [ signed ] or set in transit
    [ unsigned, never trusted ] ?
14. **data files to def 1** : when next signed [ proposal ], or one data
    sweep as for code ? and the window length for legacy code footers
    [ proposal : until one release after the sweep ].
15. **the signer slot** : `AMOS7 \ ` + 6 key id characters [ 30 bits,
    a selector only ], or another 14-character form ?

## not in this design

- a binary statement format [ `p7 statement 2`, only if size demands ]
- block-level verification [ dm-verity, FILES q19 'below the filesystem' ]
- the network witness [ N7FS-SPEC section 4 ]
- unlinkable credentials [ their own design ]

#,,,,,.,,,,,,,..,,,,,,,.,,..,,.,,,,,.,...,.,,,..,,...,...,.,,,.,,,...,..,,..,,
#64IJXZEU2A4LW3WYFKGW6O2JMPFPKYFM24GEZEO2UORCC4QJME7HDX6N3TZUU33G5MEJTR2UWE5RK
#\\\|UQV7XAKVTTBJ3ZQVR2EV2ODJXESGL4S563K4AR3SX4AE3O67S6E \ / AMOS7 \ YOURUM ::
#\[7]YE5MHQCPQGL7RAN2YJUHTHXRITJXVEFC343CC5JN7BMR24XNL2BY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
