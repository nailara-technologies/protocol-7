# osf-cache stage 2 : hash lookup [ offline part ]

design : `data/md/design/OSF-CACHE-ZENKA.md` [ stage 2 : who holds H ?
no transfer yet ]. stage 1 landed in `b82629df3` :
`osf-cache.debian.read_inrelease` \ `read_packages` \
`holdings.scan_apt_cache`, `bin/dev/osf-holdings`,
`bin/test-scripts/test-osf-cache-debian.pl`.

this task = the pure, offline-testable part. NO zenka config, NO
`.cmd.` module, NO init_code, NO live system change -- the zenka
wiring and the cross-node fan-out are done afterwards in the main
session with the user.

## trust rule [ do not weaken ]

only ANCHORED files [ sha256 found in a signed + hash-matched index ]
are ever announced or answered positively. an unanchored cached .deb
is never reported as held, even if its hash is asked for.

## 1. incremental scan [ modify `osf-cache.holdings.scan_apt_cache` ]

- add `mtime` to every file entry
- new optional param `previous => \@files` [ a previous result's
  `files` list ] : when an entry with the same name, size AND mtime
  exists there, reuse its sha256 instead of re-reading the file
- re-anchor reused entries against the CURRENT index [ the index may
  have changed ; never copy `anchored` from previous ]
- add `rehashed` [ count of files actually read ] to the result data

## 2. `osf-cache.holdings.state_save` \ `osf-cache.holdings.state_load`

- param `{ path, holdings }` \ `{ path }` ; holdings = the scan result data
- YAML through the `format.yaml` wrapper modules [ the zenka will load
  `format.yaml` in its zenka.v7 ] : `<[format.yaml.write_file]>->( $path,
  $data )` and `<[format.yaml.load_file]>->( $path )` -- both return
  `( value, err )` in list context ; `format.yaml.pre_init` must have run.
  no json, no direct YAML::XS calls in osf-cache modules
- write_file is not atomic itself -> write_file to `<path>.tmp.<pid>`,
  then rename
- test harness : compile `format.yaml.pre_init` \ `load_file` \
  `write_file` too [ they use `<format.yaml.*>` = `%data` and call
  `base.logs`, `base.perlmod.autoload`, `base.buffer.add_line`,
  `base.str.eval_error` -> provide `our %data` and minimal stubs for those
  four in the test script, run pre_init once ]
- save atomically : write `<path>.tmp.<pid>`, then rename
- load : missing file -> mode true with empty holdings [ first run ],
  corrupt yaml -> mode false with a clear message
- state file carries a `version => 1` field ; load refuses other versions

## 3. `osf-cache.lookup.query_local`

- param `{ hashes => [ ... ], holdings => <scan result data> }`
- validate each hash : exactly 64 hex chars, lowercase it ; any invalid
  -> mode false, data names the first bad one
- cap : more than 1024 hashes -> mode false
- result data : `{ held => { sha256 => size } }` -- anchored entries only

## 4. wire format [ for the later `.cmd.has` ]

- `osf-cache.lookup.format_has_reply` : `{ sha256 => size }` -> STRING,
  one line `<sha256> <size>` per hash, sorted by hash, `''` when empty
- `osf-cache.lookup.parse_has_reply` : STRING -> `{ sha256 => size }` ;
  malformed lines are counted in `bad_lines`, never silently accepted
  into the map
- round trip must be exact

## 5. `osf-cache.lookup.merge_replies`

- param `{ replies => { node => STRING or undef }, expect =>
  { sha256 => size } }` -- `expect` = the size from the signed index
- undef reply -> node listed in `failed_nodes`
- a node reporting a size different from `expect` for a hash is NOT
  counted as a holder ; it is listed in `conflicts => [ { node, sha256,
  size } ]` [ corrupt or lying node ]
- hashes reported but not asked for are ignored [ count them in
  `unrequested` per node ]
- result data : `{ holders => { sha256 => [ nodes sorted ] }, missing =>
  [ asked hashes with no holder, sorted ], failed_nodes => [ sorted ],
  conflicts => [ ... ], unrequested => { node => count } }`

## 6. `bin/dev/osf-holdings`

- add `--state <path>` : load previous state, pass `previous` to the
  scan, save the new state, print `rehashed N of M`
- default without `--state` stays exactly as today

## tests

extend `bin/test-scripts/test-osf-cache-debian.pl` or add
`test-osf-cache-lookup.pl` in the same harness shape. fixtures in a
temp dir only -- NEVER write into /var/cache/apt or /var/lib/apt.
cover :
- incremental scan : second scan rehashes 0 ; touching one file's mtime
  rehashes exactly 1 ; a previously anchored file becomes unanchored
  when the index no longer has it
- state save \ load round trip, missing file, corrupt file, wrong version
- query_local : unanchored file never in `held`, uppercase hash accepted,
  63-char hash rejected, 1025 hashes rejected
- format \ parse round trip, malformed line counted
- merge : two holders, one failed node, one size conflict, one
  unrequested hash, one missing hash

## done when

- all tests pass, `bin/format-code -c` clean on every touched src file
  [ never plain `perl -c` -- see repo memory ]
- module headers follow the existing `## [:< ##` + `# name` \ `# descr` \
  `# param` form ; comments lowercase, `[ ]` not `( )`
- return contract : `{ mode => 'true'|'false', data => ... }` like the
  stage 1 modules
- do NOT commit [ commits need a signed version from the user ]
- report : files touched, test output, and anything in this spec you
  had to interpret

#,,.,,...,..,,...,...,...,.,.,,.,,.,.,...,,..,..,,...,...,,,,,.,.,..,,.,,,..,,
#WH2EO232FX2E5VI5LEI5D5P2H5HPRSKY2RLBMOLJFFBFTPMBW7WINFUNB3OX72TO6ERJ5ONVF6S4Q
#\\\|I3NRC5UPQWRHBSCEP2ZOWUTT4BU5FG25Y3B2YLFISYFEFKK2PO3 \ / AMOS7 \ YOURUM ::
#\[7]O52AFSD3NXFGM7EMZZONCPILPIRXJRJVBBGQWKCS2RCYNRP6LQCI 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::

## 7. hash layers [ added 2026-10-04, second round ]

read the new `## hash layers` section in the design doc first. sha256
is the distribution's choice and stays at the boundary only ; bmw384
[ B32 ] is the internal id. the trust rule above is unchanged -- only
"sha256" becomes "the anchored hash, whatever its algo".

a. **anchor keys** : everywhere an anchored hash is a key or a wire
   token it is `<algo>:<hex>` [ `sha256:…` 64 hex, `sha512:…` 128 hex ].
   no field or variable named `sha256` for the anchor any more.
b. `read_inrelease` : `files => { relpath => { algo, hash, size } }` --
   sha256 section preferred, sha512 used when no sha256 section exists
   [ fixes today's bug : sha512 values stored under a `sha256` key ].
   `read_packages` : expect param becomes `expect => { algo, hash }`.
c. `read_packages` : read BOTH `SHA256:` and `SHA512:` stanza fields ;
   index `by_anchor => { '<algo>:<hex>' => { package, version,
   architecture, filename, size } }` -- a stanza with both fields is
   indexed under both keys. also return `algos => [ sorted algos seen ]`.
d. `scan_apt_cache` : ONE read pass per file computes every algo listed
   in the index's algos plus bmw384. streaming context :
   `require Digest::BMW ; Digest::BMW->new(384)`, encoded with
   `<[chk-sum.bmw.encode_digest]>->( $ctx )` [ no `base.` prefix in calls : `base.chk-sum.bmw.pre_init` aliases the family via swap_subs ] [ B32, 77 chars ].
   entry fields : `anchor => '<algo>:<hex>'` or undef, `digests =>
   { sha256 => hex, …, bmw384 => b32 }`, `anchored`. the unchanged-file
   reuse [ name, size, mtime, ctime, inode -- keep ALL five ] reuses all
   digests ; if the current index needs an algo the previous entry lacks,
   rehash that file.
e. `query_local` : takes `<algo>:<hex>` tokens ; accept only sha256 [ 64 ]
   and sha512 [ 128 ], lowercase the hex. `held => { anchor => { size,
   bmw384 } }`.
f. wire format : one line `<algo>:<hex> <size> <bmw384>` per held file,
   sorted ; parse validates all three fields [ bmw384 = 77 chars of the
   B32 alphabet `encode_b32r` emits -- check the alphabet against a real
   digest in the test, do not guess it ] ; malformed -> `bad_lines`.
g. `merge_replies` : `expect => { anchor => size }`. size mismatch ->
   `conflicts` as today. holders of one anchor that disagree on bmw384
   -> that anchor goes to `bmw_conflicts => { anchor => { bmw384 =>
   [ nodes sorted ] } }` and is NOT in `holders` [ the fetch stage
   resolves it by verifying against the anchor ]. otherwise `holders =>
   { anchor => [ nodes ] }` plus `bmw384 => { anchor => b32 }`.
h. state file : `version => 2` ; a version 1 state loads as "no previous
   state" [ mode true, empty holdings -> one full rehash ], any other
   version is refused.
i. `bin/dev/osf-holdings` : show the anchor algo and the bmw384 [ short
   prefix is fine ] per file.
j. tests : update all sections ; add a sha512-only fixture pair
   [ InRelease with only a SHA512 section, Packages with only SHA512
   fields, placeholders filled at runtime like the sha256 pair ] that
   anchors the fixture .deb ; bmw384 of the fixture .deb checked against
   `<[chk-sum.bmw.384.B32]>` [ the in-memory variant, new module ]
   -- both must match ; a bmw384 disagreement case in merge ; version 1
   state -> empty. the harness compiles `base.chk-sum.bmw.encode_digest`
   and `base.chk-sum.bmw.384.B32` [ files are named base.* , register them in
   %code under the short `chk-sum.bmw.*` names the modules call ] and imports `encode_b32r` from
   `Crypt::Misc` into main.

#,,.,,...,..,,,,.,,..,,.,,,.,,.,,,.,.,..,,,,,,..,,...,...,..,,,.,,.,.,,..,..,,
#E2SNXA3XWEZOSGMCACBVKIVSMWKMR6Z6P34CYUPECUIXWWAH2AFTYT3I6D2SDQ7GMCZQ4WBJCB2NQ
#\\\|G5OPXVCKMBTMZTS7V3SN7AHMJ7EVJAW5LR25OGU6T6UROQJSK47 \ / AMOS7 \ YOURUM ::
#\[7]GRPAG6457ZLOY3TACHMYLX4SC5W6PZULTO6MHNQ5DZAK7ZCAMCDI 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
