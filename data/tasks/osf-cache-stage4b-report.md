# osf-cache stage 4b : report — holders reached over external links

status : IMPLEMENTED, harness green [ 228 checks, exit 0 ].
no zenka started \ restarted \ reloaded, no sudo, no commit, no
signing. nothing under `cfg/zenki/cube/` or `cfg/zenki/external/`
was touched.

## files touched

new src modules :

- `src/osf-cache.holder.cmp` — the ONE holder ordering rule :
  string-safe compare, local holders first [ numeric by sid ],
  then remote ones [ by link name, then numeric by sid ].
  anything that is not a well-formed route falls back to a plain
  string compare [ the merge_replies test nodes ]. carries the
  stage 4b security note.
- `src/osf-cache.peers.parse` — the factored-out table parser :
  one 'list sessions osf-cache' table -> holder route strings.
  own-sid filter applies to the LOCAL listing only. carries the
  security note where remote holders are born.
- `src/osf-cache.peers.deliver` — the single completion path of a
  multi-listing discovery : sort, cancel the collect timer, delete
  the collect state, ONE callback [ explicit dispatch, never a
  stored code ref ].
- `src/osf-cache.peers.collect_timeout` — the lookup_timeout-
  length timer armed when links are configured; unanswered
  listings become failed links; hands over to peers.deliver.

modified src modules :

- `src/osf-cache.peers.list` — with `<osf-cache.cfg.remote_links>`
  set it now sends the local `list` AND one
  `external.<link>.list sessions osf-cache` per link, all into one
  `<osf-cache.peers.collecting>` state ; without links the stage 2c
  single-query behavior is byte-identical.
- `src/osf-cache.handler.peers_list` — uses osf-cache.peers.parse;
  feeds the collect state [ or, with no links, the callback
  directly, old behavior kept ]; records a failed remote link.
- `src/osf-cache.init_code` — `<osf-cache.cfg.remote_links> //= ''`.
- `src/osf-cache.lookup.with_peers` — takes the optional `failed`
  list [ failed links stored on the lookup state ] ; every command
  goes to `"<holder>.<cmd>"` with the holder route string ;
  security note where holders are fanned out.
- `src/osf-cache.lookup.complete` — appends the failed remote
  links to the merged `failed_nodes` [ sorted with holder.cmp ] in
  both the text-reply and the internal [ fetch ] path.
- `src/osf-cache.lookup.merge_replies` — holder sets, bmw_conflict
  node lists and failed_nodes sorted with holder.cmp instead of
  `sort` \ `sort { $a <=> $b }`.
- `src/osf-cache.merkle.quorum` — asked \ answers iteration, the
  winner tie-break and `eligible` all use holder.cmp [ a numeric
  `<=>` would numify a route to 0 ].
- `src/osf-cache.fetch.lookup_done` — holders stored sorted via
  holder.cmp.
- `src/osf-cache.fetch.holder_fail` + `src/osf-cache.fetch.leaves_next`
  — exclusion compares `ne` [ route strings ], never `!=`.
- `src/osf-cache.fetch.complete` — the 'used holders' list sorted
  via holder.cmp.

harness + config :

- `bin/test-scripts/test-osf-cache-debian.pl` — compiles the 4 new
  modules ; a `$holder_re` accepts both `<sid>` and
  `external.<link>.<sid>` in every command matcher
  [ deliver_segments, segment_sends, has_sends, merkle_sends,
  drive_control ] ; new section 25 with 6 stage 4b flows.
- `cfg/zenki/osf-cache/subroutines.load-early` — regenerated with
  `bin/dev/gen-sub-whitelist osf-cache` ONLY [ 533 subs, the 4 new
  modules included, unsigned as the tool leaves it ].

all touched files pass `bin/format-code -c` [ syntax valid, no
reflow pending ] ; plain `perl -c` was never used.

## how holders are ordered and compared

a holder is a ROUTE PREFIX string, never a number :

- local : `<sid>`                                   [ unchanged ]
- remote : `external.<link>.<sid>`

every command is `"<holder>.<cmd>"` — `4301.has` reaches the local
cube session 4301, `external.self.4500.segment` routes over the
named link `self` to that host's session 4500. `sort { $a <=> $b }`,
`==` and `!=` on holder ids were replaced everywhere : sorting and
tie-breaks go through `osf-cache.holder.cmp` [ locals first, numeric
by sid ; then remotes by link name, numeric by sid ; plain `cmp`
fallback for non-route strings ], exclusions and phase checks use
`ne` \ hash-key existence. peers discovery sorts at the single
deliver point, so every consumer [ lookup fan-out, quorum, pump,
reply texts ] sees the documented order.

## how link failures surface

peer discovery collects every listing in
`<osf-cache.peers.collecting>` keyed by a collect id :

- the callback fires ONCE — after ALL listings answered, or when
  the `<osf-cache.cfg.lookup_timeout>` [ //= 5 s ] collect timer
  fires [ `osf-cache.peers.collect_timeout` ]. no crash, no hang :
  a never-answering link only burns one timer.
- a link answering something that is not SIZE \ TRUE, or timing
  out, is recorded as `external.<link>` in the callback's `failed`
  list [ and logged with the link name ].
- an empty but well-formed table is a VALID answer [ a host with
  no osf-cache sessions ] — not a failure.
- `osf-cache.lookup.with_peers` stores `failed_links` on the lookup
  state ; `osf-cache.lookup.complete` merges them into
  `failed_nodes`, so they show up exactly like failed peers :
  `failed peers : external.self` in the text reply, and inside the
  `failed_nodes` of the internal fetch result [ the 'no holders'
  summary of fetch.fail includes them ].
- the loopback case from the spec is covered : the remote listing
  repeats the local sessions, the own-sid filter applies to the
  LOCAL listing only, so a fetch may hold both `4301` and
  `external.self.4301` [ same data, two transports ].

## what only a live run can confirm

the harness stubs route-send and answers by hand ; only a live run
verifies :

- `external.<link>.list sessions osf-cache` actually reaching the
  REMOTE host's cube over the encrypted named link [ link up,
  session registered, reply routed back — the c26bfb171 handshake
  on a real socket ].
- the remote rows being that host's real osf-cache sessions and the
  route strings resolving there [ session ids exist remotely ].
- a mixed fetch pulling real segments through the link with the
  real segment \ merkle latency, and the link dying MID-fetch [
  the harness only models a dead link at discovery time ].
- the end-to-end security posture : the link authenticates us but
  does not yet prove the server's identity — content integrity
  holds [ merkle leaves + signed anchor ], but commands over the
  link are not authenticated end to end, so this stays localhost \
  own nodes until the trust chain work lands. access grants need
  the reviewer's cube config reload [ we touched nothing under
  cfg/zenki/cube/ or cfg/zenki/external/ ].

## full test output

```
: InRelease parse + signature
  ok   : bmw384 B32 alphabet verified against a real digest [ A-Z 2-7, 77 ]
  ok   : mode true
  ok   : origin parsed
  ok   : suite parsed
  ok   : codename parsed
  ok   : date parsed
  ok   : valid-until parsed
  ok   : exactly one sha256 section entry
  ok   : entry carries its algo [ sha256 ]
  ok   : Packages relpath anchored to the runtime-computed sha256
  ok   : Packages size parsed
  ok   : fixture signature is not good [ bad or unverified ]
  ok   : signature verdict is 'bad'
  ok   : missing file returns mode false
: Packages streaming parse
  ok   : mode true
  ok   : three stanzas indexed
  ok   : computed file sha256 matches reference digest
  ok   : computed file sha512 matches reference digest
  ok   : anchored 0 without expect
  ok   : index holds three anchor keys
  ok   : algos lists the sorted algos seen
  ok   : hello entry : package, version, arch, filename, size
  ok   : goodbye entry indexed by its anchor token
: apt archive name
  ok   : archive name : the epoch colon becomes %3a [ apt QuoteString ]
  ok   : archive name : no epoch -> same as the pool basename
  ok   : archive name : missing fields fall back to the pool basename
: anchoring
  ok   : anchored 1 when the digest of the expect algo matches
  ok   : anchored 0 on tampered expect hash
  ok   : anchored 1 when expect carries the file sha512
: sha512-only fixture pair
  ok   : sha512-only InRelease : entry carries algo sha512 + runtime hash
  ok   : sha512-only Packages : hello indexed under its sha512 anchor
  ok   : sha512-only Packages : algos lists sha512
  ok   : sha512-only pair anchors with its own sha512
  ok   : scan anchors the fixture .deb through the sha512 token
  ok   : the unanchored .deb stays unanchored under the sha512 index
: holdings scan
  ok   : mode true
  ok   : two .deb files scanned
  ok   : listed .deb anchored under its sha256 anchor token
  ok   : one pass records the sha256 digest
  ok   : bmw384 of the fixture .deb matches <[chk-sum.bmw.384.B32]>
  ok   : unlisted .deb not anchored, name parsed from file name
  ok   : unanchored .deb still carries its bmw384 internal id
  ok   : anchored_count is 1
  ok   : total_bytes is the sum of both files
  ok   : anchored_bytes is the listed .deb only
  ok   : missing cache dir returns mode false
: large index streaming
  ok   : 20000 stanzas streamed and indexed
  ok   : large file sha256 matches reference digest
  ok   : large index holds one anchor key per stanza
  ok   : large file anchored with its own hash
  ok   : holdings scan runs against large index
: stage 2 - incremental scan
  ok   : first scan rehashes both files
  ok   : entries carry mtime, ctime and inode
  ok   : second scan rehashes 0 [ digests reused ]
  ok   : reused digests match the first scan
  ok   : touched file rehashes exactly 1
  ok   : index needing a new algo rehashes every file lacking it
  ok   : the wide index records the sha512 digest
  ok   : hash still reused when the index no longer carries it
  ok   : previously anchored file becomes unanchored when the index changed
: stage 2 - state save / load
  ok   : state save mode true
  ok   : state round trip preserves the scan result incl. bmw384
  ok   : missing state file -> mode true with empty holdings
  ok   : corrupt state file -> mode false
  ok   : version 1 state -> mode true with empty holdings [ full rehash ]
  ok   : state file with version != 1 or 2 -> mode false
: stage 2 - query_local
  ok   : anchored token answered with size and bmw384
  ok   : unanchored cached .deb never reported as held
  ok   : uppercase hex accepted and lowercased
  ok   : valid sha512 token of a sha256-anchored file is not held
  ok   : 63-char hash rejected
  ok   : non-sha algo token rejected
  ok   : 1025 hashes rejected
: stage 2 - wire format
  ok   : format : one sorted line per anchor, three fields
  ok   : format / parse round trip is exact
  ok   : empty map round trips to empty string
  ok   : malformed lines counted [ bad line, bad bmw, wrong algo ]
: stage 2 - merge_replies
  ok   : merge mode true
  ok   : anchor with two agreeing holders lists both + the agreed bmw384
  ok   : anchor with one holder
  ok   : undef reply listed in failed_nodes
  ok   : size mismatch is a conflict, not a holder
  ok   : unrequested anchor counted per node
  ok   : bmw384 disagreement -> bmw_conflicts, not holders
  ok   : anchors without a size-agreeing holder are missing [ conflicts count ]
: stage 2b - scan_file split
  ok   : scan_file hashes + anchors one .deb [ rehashed 1 ]
  ok   : scan_file reuses the previous entry [ rehashed 0 ]
  ok   : scan_file rehashes when the previous entry lacks an algo
  ok   : scan_file returns undef for a missing file
: stage 2b - index.build
  ok   : index.build reports one source per InRelease
  ok   : not-good signature : sources listed, zero contributing anchors
  ok   : source carries inrelease, entries and the Packages anchor state
  ok   : missing lists dir returns mode false
: stage 2b - zenka flow
  ok   : init_code sets the config defaults [ pre-drop shape ]
  ok   : reinit keeps the existing config and holdings untouched
  ok   : cmd.has refuses before the first rescan finished
Use of uninitialized value $label in concatenation (.) or string at bin/test-scripts/test-osf-cache-debian.pl line 319.
  ok   : startup builds the index and arms exactly one rescan timer
  ok   : cmd.rescan answers [ startup scan or fresh start ]
  ok   : rescan tick hashes scan_slice files and re-arms the timer
  ok   : last tick swaps holdings in, state_saves, no re-arm [ timer count flat ]
  ok   : cmd.has answers after the rescan [ no anchors : bad signature ]
  ok   : cmd.status reports holdings, scan progress and state path
  ok   : second rescan reuses the saved state [ rehashed 0 ]
: binary content [ every byte value, utf-8 default layer active ]
  ok   : scan_file hashes raw bytes, not utf-8 decoded characters
: stage 2c - per-subname instance config
  ok   : subname peer : by_subname cache dir, subnamed state, lookup timeout
  ok   : subname without by_subname : default cache dir, subnamed state path
  ok   : no subname : the original defaults
: stage 2c - peer discovery
  ok   : peers.list asks cube for list sessions osf-cache [ async ]
  ok   : table parse : own sid excluded, [subname] peer in, other zenki out
: stage 2c - lookup state machine
  ok   : lookup defers : state keyed by lookup id, one 5s timeout timer
  ok   : fan-out : <sid>.has <tokens> to each peer with a reply handler
  ok   : no completion while a peer is still pending
  ok   : last reply completes : holders lines, state + timer + entry gone
  ok   : timeout completes with what arrived : silent peer is a failed peer
  ok   : timeout cleanup : no pending state, no new timer armed
  ok   : zero peers : mode true no peers, lookup cleaned up
  ok   : unknown anchor refused before any state, send or timer
  ok   : all anchors unknown : refused, every unknown anchor listed
  ok   : mixed lookup : only the known anchor goes out to the peers
  ok   : mixed lookup : holders for the known, unknown line for the rest
  ok   : invalid token fails with the query_local message
  ok   : size mismatch : holder from the agreeing peer, conflict line
  ok   : bmw disagreement : bmw conflict lines, anchor also in missing
  ok   : unresolved peer list fails the lookup instead of faking missing
  ok   : failed peer query completes as no peers
  ok   : empty replies : anchor missing, no failed peers
: stage 3 - cmd.segment
  ok   : segment : mode true, one line <offset> <bytes> <b32>
  ok   : segment : decode_b32r round trips the served bytes
  ok   : segment : the last segment comes back shorter
  ok   : segment : offset at or beyond the end refused
  ok   : segment : unknown bmw384 refused
  ok   : segment : a matching but unanchored file is refused
  ok   : segment : length above segment_max refused
  ok   : segment : length 0 refused
  ok   : segment : a malformed bmw384 refused
  ok   : b32 : every byte value round trips encode_b32r/decode_b32r
  ok   : segment : a file changed since the scan is never served
  ok   : segment : size + mtime + inode match again -> served
: stage 3 - cmd.fetch
  ok   : fetch : mode deferred, per-anchor state registered
  ok   : fetch : the internal lookup fans out to both peers
  ok   : fetch : merkle root asked of every holder [ below n : ALL ]
  ok   : fetch : leaf list agreed, ONE segment request [ offset 0 len 500 ]
  ok   : fetch : fetched reply [ holders list, segments, seconds ]
  ok   : fetch : the verified file landed in the cache dir [ byte exact ]
  ok   : fetch : the placed file has the archive mode 0644 [ not the umask ]
  ok   : fetch : no partial file left behind
  ok   : fetch : holdings updated [ anchored entry, bmw384 ] + state saved
  ok   : fetch : scan_file stored the merkle tree of the fetched file
  ok   : fetch : pending state, timers and the cmd_reply entry cleaned up
  ok   : fetch : corrupted content fails the anchor verification
  ok   : fetch : nothing placed, the partial is gone, state cleaned
  ok   : fetch : the segment request goes to the first holder
  ok   : fetch : first timeout retries the same holder, same leaf
  ok   : fetch : second timeout excludes the holder, 4302 gets the leaf
  ok   : fetch : a late reply to a timed-out request is dropped
  ok   : fetch : the remaining holder serves, the excluded one is named
  ok   : fetch : no holder -> mode false with the missing summary
  ok   : fetch : no-holder cleanup
  ok   : fetch : disagreeing bmw384 reports fail the fetch [ stage 4 ]
  ok   : fetch : bmw conflict cleans up before any segment request
  ok   : fetch : already held answers without any lookup
  ok   : fetch : a second request for the running anchor is refused
  ok   : fetch : an unwritable cache dir is refused
  ok   : fetch : an anchor outside the local index is refused
  ok   : fetch : sizes above fetch_max [ 512 MiB ] are refused
: stage 4 - merkle tree [ pure modules ]
  ok   : leaf : bmw384( "\x00" . bytes ), raw 48 bytes
  ok   : leaf : the "\x00" domain prefix changes the digest
  ok   : root of a one-leaf file is that leaf hash
  ok   : two leaves : bmw384( "\x01" . left . right )
  ok   : three leaves : the odd node is PROMOTED unchanged
  ok   : three leaves : never duplicated [ a different root ]
  ok   : five leaves : promotion at every odd level
  ok   : domain separation : a leaf hash fed as an inner node differs
  ok   : no leaves : no root [ a file of size 0 has no tree ]
  ok   : short read chunks give the same leaves
  ok   : the last leaf may be shorter [ 1000 bytes ]
  ok   : tree stored at <state_path dir>/merkle/<bmw384>.yaml
  ok   : tree file round trip : leaf_size, size, leaf_count, root, leaves
  ok   : merkle.have sees the stored tree
  ok   : a tampered stored leaf is treated as missing [ logged ]
  ok   : a file of size 0 has no tree [ store refuses ]
: stage 4 - scan_file stores the tree
  ok   : init_code defaults root_quorum to 5/7
  ok   : an anchored scan stores the tree in the same pass
  ok   : the stored tree rebuilds to the content root [ 3 leaves ]
  ok   : reuse with a present tree reads nothing
  ok   : anchored reuse with a missing tree re-reads + backfills
  ok   : unanchored files get no tree
: stage 4 - cmd.merkle
  ok   : cmd.merkle : mode true "<root> <leaf_count> <size>"
  ok   : cmd.merkle leaves : "<from> <count> <leaf> <leaf>" one line
  ok   : cmd.merkle leaves : the page clamps at leaf_count
  ok   : cmd.merkle leaves : count is capped at 1024 per request
  ok   : cmd.merkle leaves : from beyond leaf_count refused
  ok   : cmd.merkle : no tree yet -> merkle not ready
  ok   : cmd.merkle : an unanchored match is refused
  ok   : cmd.merkle : a file changed since the scan is never served
: stage 4 - multi-source fetch
  ok   : multi : leaves handed out in order, ONE outstanding per holder
  ok   : 
  ok   : multi : file byte-exact, nothing left behind
  ok   : multi : bad leaf -> holder excluded, leaf refetched, file placed
  ok   : multi : the refetched file is byte-exact
  ok   : multi : root conflict -> fail [ roots listed ], no segments sent
  ok   : multi : 7 holders asked [ the first n ]
  ok   : multi : 5 of 7 agree -> proceeds, dissenting holders excluded
  ok   : multi : 4 of 7 agree [ below k ] -> merkle conflict, fail
  ok   : multi : bad leaf list -> the next agreeing holder is tried
  ok   : multi : the good list wins, the bad-list holder is excluded
  ok   : multi : a tree size that differs from the index fails
  ok   : multi : a leaf_count that differs from the index fails
  ok   : multi : all holders excluded -> fail, no timer left active
: stage 4b - holders behind external links
  ok   : one link : local list + external.self.list sent
  ok   : one link : a 5 s collect timeout is armed
  ok   : one link : no fan-out before every listing answered
  ok   : holders : local first by sid, then the link by sid
  ok   : own sid filtered in the local listing only
  ok   : all listings answered : the collect timer is cancelled
  ok   : link timeout : the lookup defers first
  ok   : link still pending : no fan-out yet
  ok   : link timeout : the lookup goes on with the local holders
  ok   : link timeout : completes, the link listed as failed
  ok   : malformed link answer : no crash, no holders from it
  ok   : malformed link answer : the failed link is listed
  ok   : empty link answer : valid, no failed entry
  ok   : fetch : the merkle round reaches remote holders by route
  ok   : fetch : local and remote holders get segment requests
  ok   : fetch : one fetch mixed local + remote holders
  ok   : fetch : the mixed-source file is byte-exact, state cleaned
  ok   : bad leaf : remote holder excluded by its route
  ok   : bad leaf : the local holder finishes byte-exact

all checks passed

```

#,,.,,,,.,.,.,..,,...,.,,,,.,,,..,..,,.,.,,.,,..,,...,...,,..,.,,,.,,,..,,.,.,
#5HENMA3KFGULLNX5LT3MFIHAIJJVVQV5YVNCT74OJDBAB3SKVFFXXWVPYU4Q24T4RQ7S63HZ2P43K
#\\\|WLQHWIB3NTURGHTAYU2N53WNWBJ3YNTQQ3GD6FTRJHFNWEEGD6M \ / AMOS7 \ YOURUM ::
#\[7]AOU2S2HQKOL3IDMHIGFNRP3IQPRPVCVD6PWEDBCVARFHEMODWQAI 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
