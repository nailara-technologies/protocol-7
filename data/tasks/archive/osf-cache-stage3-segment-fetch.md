# osf-cache stage 3 : single-source segment fetch + verify

follows stage 2c [ `d180d43b0`, `cb6e0ac8c`, live : main + `osf-cache[peer]`,
lookup via `<sid>.lookup` works ]. design : `data/md/design/OSF-CACHE-ZENKA.md`
[ acquisition flow steps 3-5, `## hash layers` ].

transport decided with the user : **segment command** -- one request
per segment, the segment comes back B32-encoded in the reply's args.
round trip per segment, but cube is never blocked by a long stream ;
the segment is already the unit stage 4 [ several sources ] and the
per-file merkle tree need.

do NOT start, restart or reload any zenka, no sudo, no commit.

## 1. `osf-cache.cmd.segment <bmw384> <offset> <length>`

- bmw384 : 77 chars of `[A-Z2-7]` ; offset, length : integers ;
  length 1 .. `<osf-cache.cfg.segment_max>` [ //= 65536 ]
- serves ONLY a file in `<osf-cache.holdings>` whose `digests.bmw384`
  matches AND `anchored` is true -- the path is `cache_dir/<entry
  name>`, never anything taken from the request
- before reading : `CORE::stat` the file ; size, mtime, inode must still
  equal the holdings entry, else mode false `changed since scan`
  [ never serve bytes the recorded digests do not describe ]
- read with `'<:raw'` + sysseek \ sysread ; offset beyond the end ->
  mode false ; the last segment may be shorter
- reply : mode true, data `<offset> <bytes> <b32>` where b32 is
  `Crypt::Misc::encode_b32r` of the raw bytes [ `require Crypt::Misc` ;
  check how other src modules call it ]. one line, no newlines

## 2. lookup with an internal caller

today `osf-cache.lookup.complete` always answers a cmd reply. add an
optional `on_done` [ module name, explicit dispatch like
`osf-cache.handler.peers_list` does -- keep the static dependency graph
intact ] so fetch can run a lookup and get the merged result
`{ holders, bmw384, missing, failed_nodes, conflicts, bmw_conflicts }`
instead of a text reply. existing `lookup` behaviour and tests stay
unchanged.

## 3. `osf-cache.cmd.fetch <algo>:<hex>` [ deferred reply ]

- anchor must be in the local index [ size + filename known ] ; refuse
  sizes above `<osf-cache.cfg.fetch_max>` [ //= 512 MiB ]
- target dir : this instance's `cache_dir` ; must be writable by the
  zenka [ the main instance's `/var/cache/apt/archives` is root's ->
  mode false `cache dir not writable`, the live test fetches INTO the
  peer ] ; already held -> mode true `already held`
- one fetch per anchor at a time [ second request -> mode false
  `fetch already running` ]
- run the lookup [ section 2 ] ; no holder -> mode false with the
  missing \ failed summary ; an anchor in `bmw_conflicts` -> mode false
  [ stage 4 resolves those ]
- pick the holders in sorted sid order ; request segments sequentially
  [ ONE outstanding request ] via `<[protocol-7.route-send]>` to
  `<sid>.segment <bmw384> <offset> <len>` with a reply handler ; per
  segment timeout `<osf-cache.cfg.segment_timeout>` [ //= 10 s ] ; a
  failed \ timed out \ malformed segment -> retry once, then switch to
  the next holder from the current offset ; no holders left -> fail
- write to `<cache_dir>/partial/<deb filename>.partial` [ create
  `partial/` with `<[file.make_path]>` if missing ] opened `'>:raw'`,
  check each reply's offset and byte count against what was asked
- complete : size == index size, anchor digest [ sha256 \ sha512 per
  the anchor algo ] == anchor, bmw384 == the holders' bmw384 -> rename
  into `<cache_dir>/<deb filename>` [ filename = basename of the index
  entry's `filename` ] ; any mismatch -> unlink the partial, mode false
  `verification failed : <which>` -- an unverified byte never reaches
  the cache dir
- then add the file to holdings [ `scan_file` on it, push, state_save ]
- reply : `fetched <filename> <size> bytes from <sid> [ <n> segments,
  <secs> s ]`
- every exit path cleans up : pending state, timers, partial file

## 4. access

- `cfg/zenki/osf-cache/zenka.v7` : peers [ `access.cmd.usr.osf-cache` ]
  may call `segment` too ; cube users get `fetch`
- `cfg/zenki/cube/access.zenki` : osf-cache may send `osf-cache.segment`
  [ the name grant covers `<sid>.segment` -- has_access maps sids to
  names, verified live in stage 2c ]

## pitfalls found in this codebase today [ do not repeat ]

- the harness mirrors the zenka : utf-8 open layer [ binary reads need
  `:raw` ], File::stat [ use `CORE::stat` ], `.cmd.` `$call` \ `$reply`
  header [ never `my $reply` in a .cmd. module ], multi-line replies
  `mode => size`. see `data/ai-mem/claude/feedback-standalone-test-harness-zenka-environment.md`
- `qw| two words |` is a LIST -- use a quoted string for multi-word
  values [ it shifted hash pairs in stage 2c ]
- `<word>` without a dot is perl readline, not `%data` -- use
  `$data{...}` or a dotted `<a.b>`
- every new package in the test needs its own `use English` for `@ARG`
- `# descr` lines : 55 chars max [ pre-commit hook ]
- `$ARG` not `$_`, lowercase comments, `[ ]` not `( )`

## tests

- segment : happy path, last short segment, offset past end, unknown
  bmw384, unanchored file refused, file changed since scan refused,
  length cap, b32 round trip of binary bytes [ every byte value ]
- fetch with stubbed lookup \ route-send \ timers : happy path places
  the verified file and updates holdings ; corrupted segment -> verify
  fails, nothing placed, partial gone ; holder timeout twice -> next
  holder continues at the same offset ; no holders ; bmw conflict ;
  already held ; fetch already running ; cache dir not writable
- `bin/format-code -c` clean, never plain `perl -c`
- regenerate the whitelist : `bin/dev/gen-sub-whitelist osf-cache`
  [ ONLY osf-cache -- not the other zenki ]

## report

files touched, test output, the B32 functions used and how decode is
checked, every exit path of fetch and its cleanup, what only a live run
can confirm.

#,,,,,.,,,,,,,,,.,,,.,.,.,.,.,,.,,,,.,,..,,..,..,,...,...,.,,,.,,,...,,.,,.,.,
#4JLEHTQMV5OFZIAHJLITPARNA5YDH3QEZL2WACUCRZ2MG4MF6A5IVLMYJFYGVUBMZDT7C3QXKWWWI
#\\\|IUSHN5ZT36FXJUIKQDZQ6MKL3QCZ6YFYTPVPGCJPYGD2XFMR2WD \ / AMOS7 \ YOURUM ::
#\[7]D7UL3PMCA2BR7RWKC5GNPSCVV6A3QKU2GUZR2UO5KNMQLDS3J4CY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
