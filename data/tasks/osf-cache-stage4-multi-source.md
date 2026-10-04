# osf-cache stage 4 : merkle tree + multi-source segment fetch

follows stage 3 [ `16e32691c`, `512c58752`, `30636818e`, live : the
`osf-cache[peer]` instance fetched igt-gpu-tools from main, 32 segments,
byte-identical ]. design : `data/md/design/OSF-CACHE-ZENKA.md` [ `## hash
layers`, the streaming \ merkle paragraph, acquisition flow 3-5 ].

decided with the user [ 2026-10-04 ] :

- a REAL binary merkle tree per file, built now [ a flat hash list would
  give a different root -> switching later breaks every stored tree and
  mixed-version peers ]. stage 4 uses it the simple way : the fetcher
  pulls the full leaf list, rebuilds the root, then verifies every
  segment against its leaf. per-segment proof paths come later [ fuse ]
- root trust : **all holders asked must agree** [ in practice they are
  the user's own nodes ] ; a configurable quorum `k/n` with default
  `5/7` applies once at least n holders exist [ variants may follow -
  keep the rule in ONE module ]

do NOT start, restart or reload any zenka, no sudo, no commit, do NOT
try to sign files [ the signer needs the user's interactive password ;
signing happens at commit time ].

## 1. the tree : `osf-cache.merkle.*`

- leaf size : protocol constant 65536 bytes [ NOT `segment_max`, it is
  part of the tree identity ] ; the last leaf may be shorter ; a file
  of size 0 has no tree [ refuse ]
- hashes are bmw384 over RAW bytes [ `Digest::BMW->new(384)`, `->digest`
  for the raw 48 bytes ; B32 via `<[chk-sum.bmw.encode_digest]>` only
  for storage \ wire - check how `osf-cache.holdings.scan_file` does it ]
- domain separation : leaf = bmw384( "\x00" . bytes ), inner node =
  bmw384( "\x01" . left_raw . right_raw )
- odd node at a level : PROMOTED unchanged to the next level [ never
  duplicated - duplication lets two different leaf lists share a root ]
- root of a one-leaf file = that leaf hash
- leaf_count must equal ceil( size / 65536 )
- one pure module builds the root from a leaf list [ testable alone ]

## 2. computing and storing trees

- `osf-cache.holdings.scan_file` already reads the file once in 65536
  chunks for sha + bmw384 : compute the leaf hashes in the SAME pass.
  `read` may return short mid-file -> accumulate into exact 65536-byte
  leaves, never trust chunk boundaries
- store per file at `<dirname of osf-cache.cfg.state_path>/merkle/
  <bmw384>.yaml` [ content-addressed : the same file has the same tree
  on every instance, so main and peer may share the dir ] ; write a
  temp file + rename [ atomic ] ; create the dir with `<[file.make_path]>`
  ; contents : leaf_size, size, leaf_count, root, leaves [ B32 list ]
- scan_file reuses previous digests without reading the file : an
  anchored entry whose tree file is missing must be re-read so the tree
  gets built [ the startup scan backfills today's holdings ]
- loading a tree : rebuild the root from the stored leaves and compare
  with the stored root, size and leaf_count ; mismatch -> treat as
  missing [ log it ]

## 3. `osf-cache.cmd.merkle`

- `merkle <bmw384>` -> mode true `<root> <leaf_count> <size>`
- `merkle <bmw384> leaves <from> <count>` -> mode true
  `<from> <count> <leaf> <leaf> ..` [ B32, one line ] ; count capped at
  1024 per request [ ~80 KB ]
- serves only an ANCHORED holding whose bmw384 matches and whose file
  still matches size \ mtime \ inode of the holdings entry [ same rule
  as `segment` ] ; no tree yet -> mode false `merkle not ready`

## 4. fetch : several holders in parallel [ replaces the stage 3 single
## source loop ; one holder is the degenerate case ]

1. lookup as today [ `on_done` ] -> holders [ sorted ], bmw384
2. root agreement : ask `<sid>.merkle <bmw384>` of
   - all holders if fewer than n [ default 7 ] -> ALL must answer and
     agree on root \ leaf_count \ size, else fail mode false `merkle
     conflict` [ list the roots ] or `merkle unavailable`
   - the first n holders if n or more -> at least k [ default 5 ] must
     agree ; dissenting \ silent holders are excluded from this fetch
   config `<osf-cache.cfg.root_quorum>` //= '5/7' ; the rule lives in
   ONE module
3. size and leaf_count must match the local index size, else fail
4. leaf list : pages from ONE agreeing holder [ next agreeing holder on
   failure ] ; rebuild the root -> must equal the agreed root, else that
   holder is excluded and the next one tried
5. segments : one leaf per request [ offset = i * 65536 ], ONE
   outstanding request per eligible holder, leaves handed out in order
   from a queue ; per-request `seq` [ keep the stage 3 rule : a reply
   whose seq is not the holder's current one is dropped ] and per-holder
   timeout `<osf-cache.cfg.segment_timeout>`
6. each reply : offset \ byte count as asked AND bmw384( "\x00" . bytes )
   == leaf[i] -> write at its offset [ partial opened read-write,
   `:raw`, sysseek + syswrite, segments arrive out of order ] ; a leaf
   that fails verification EXCLUDES that holder for the rest of this
   fetch and requeues the leaf ; a timeout retries once on the same
   holder, a second one excludes it
7. no eligible holder left while leaves are missing -> fail
8. all leaves in -> the stage 3 whole-file check stays [ size + anchor
   + bmw384 ] -> rename -> scan_file [ which now also writes the tree ]
   -> holdings + state_save
9. reply : `fetched <filename> <size> bytes from <n> holders [ <sids> ]
   [ <segments> segments, <secs> s ]` ; mention excluded holders if any
10. every exit path cleans up : ALL per-holder timers, pending state,
   partial file ; exactly one reply

keep `fetch already running`, `already held`, `fetch_max`, `cache dir
not writable`, the bmw conflict refusal from stage 3.

## 5. access [ live lesson from stage 3 ]

- peer calls routed via cube arrive at the target as user **cube** ->
  `merkle` goes on the `access.cmd.usr.cube` line in
  `cfg/zenki/osf-cache/zenka.v7` [ and on `access.cmd.usr.osf-cache`
  like `segment` ]
- `cfg/zenki/cube/access.zenki` : osf-cache may send `osf-cache.merkle`

## pitfalls found in this codebase [ do not repeat ]

- the test harness mirrors the zenka : utf-8 open layer [ binary needs
  `:raw` ], File::stat [ use `CORE::stat` ], `.cmd.` `$call` \ `$reply`
  header [ never `my $reply` in a .cmd. module ], multi-line replies
  `mode => size`. see
  `data/ai-mem/claude/feedback-standalone-test-harness-zenka-environment.md`
- `qw| two words |` is a LIST - quoted strings for multi-word values
- `<word>` without a dot is perl readline, not `%data`
- every new package in the test needs its own `use English`
- `# descr` lines : 55 chars max [ pre-commit hook ]
- `$ARG` not `$_`, lowercase comments, `[ ]` not `( )`
- on_done style dispatch must stay explicit [ static dependency graph ]
- stage 3 tests stay green [ adapt only where the reply text changes ]

## tests

- merkle : one leaf, two leaves, odd promotion [ 3 and 5 leaves ],
  domain separation [ a leaf hash fed as an inner node gives a
  different root ], short last leaf, short `read` chunks give the same
  leaves, tree file round trip, a tampered stored leaf -> treated as
  missing
- cmd.merkle : root reply, leaf pages + cap, unanchored \ changed file
  \ no tree refused
- fetch : 2 holders both serve segments ; a bad leaf from one holder ->
  excluded, leaf refetched from the other, file placed ; root conflict
  with 2 holders -> fail, nothing sent for segments ; 7 holders with 2
  dissenting -> proceeds without them ; 7 with 3 dissenting -> fail ;
  leaf list that does not rebuild to the root -> next holder ;
  leaf_count \ size mismatch ; timeout twice -> holder excluded, others
  continue ; late stale reply dropped ; all holders excluded -> fail +
  full cleanup [ no timer left active ]
- `bin/format-code -c` clean, never plain `perl -c`
- `bin/dev/gen-sub-whitelist osf-cache` [ ONLY osf-cache ]

## report

files touched, full test output, the exact leaf \ inner hash
construction, how the quorum rule is applied, every exit path of fetch
and its cleanup, what only a live run can confirm.

#,,.,,...,,,.,,,.,.,.,..,,.,.,.,.,,,,,,..,...,..,,...,..,,.,.,,.,,,..,..,,,.,,
#YRN65YZKGKADP5KA4MMOKNSDVFHTWERBVBK2SWQYTHQDY5JFPU67U36MDPVYPILBS4Q6THTH6KR22
#\\\|PMANOIXQLTFEAVCSPRGEGISJWVJBQRO2RMU5HT26Z4SHJL7WPWV \ / AMOS7 \ YOURUM ::
#\[7]55Q3VY4TTVOFUEU43NHHCTJVJVXNIMPXO6YQ5U2H2BOBCD5362CI 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
