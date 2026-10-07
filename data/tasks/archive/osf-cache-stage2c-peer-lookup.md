# osf-cache stage 2c : peer lookup [ same host first ]

follows stage 2b [ committed `a632330eb`, running live ]. design :
`data/md/design/OSF-CACHE-ZENKA.md` [ acquisition flow step 2 : who
holds H ? ]. goal : one osf-cache instance asks the OTHER osf-cache
instances for anchors and merges the answers. no transfer yet.

do NOT start, restart or reload any zenka, no sudo, no commit -- the
live test runs in the main session.

## addressing [ decided with the user ]

- a second instance runs as `osf-cache[<subname>]` [ start syntax of
  `v7-zenki.zenka.start` ; subname never touches authorization -- read
  `data/ai-mem/claude/reference-session-subname-routing-convention.md` ]
- a peer is addressed by its cube SESSION ID : `<session-id>.has ...`
  [ the number replaces the zenka name ]. peers = cube sessions whose
  zenka is `osf-cache`, excluding this instance's own session id
  [ `<[base.get_session_id]>` \ how other zenki read their own id ].
  use cube's `list sessions osf-cache` [ the argument is a name
  pattern, user tip ] -- columns `usid protocol type mode uname since`,
  the usid column is the session id to route to. prefer a structured
  reply if cube offers one for it, else parse that table and say so in
  the report
- cross-host discovery [ the `discover` zenka, `branch.discover.*` ] is
  a LATER stage -- keep the peer source behind one module
  [ `osf-cache.peers.list` ] so it can be swapped

## 1. per-subname instance config

- `init_code` : with `<system.zenka.subname>` set [ pattern :
  `src/ticker.init_code` ], defaults become
  - state_path : `<data_path>/holdings.<subname>.yaml`
  - cache_dir  : `<osf-cache.cfg.by_subname.<subname>.cache_dir>` if
    configured, else the normal default
- add to `cfg/zenki/osf-cache/zenka.v7` :
  `osf-cache.cfg.by_subname.peer.cache_dir = /var/protocol-7/osf-cache/peer-archives`
  [ the main session fills that dir for the test ]
- reinit invariant unchanged

## 2. `osf-cache.peers.list`

returns `[ session ids ]` of the other osf-cache sessions. async if the
cube query is async [ then : callback \ handler form, see section 3 ]

## 3. `osf-cache.cmd.lookup <algo>:<hex> [ ... ]`

- validate tokens exactly like `has` [ reuse query_local's checks ]
- resolve peers, send `<sid>.has <tokens>` to each with
  `<[protocol-7.route-send]>` + a reply handler [ pattern :
  `src/invoke-web.stats.win_mem` + `invoke-web.handler.win_mem_reply` ]
- the command replies LATER [ deferred reply ] : read
  `data/ai-mem/claude/reference-p7-local-command-route-and-deferred-reply-mechanics.md`,
  `feedback-cross-zenka-deferred-reply.md` and an existing deferred
  `.cmd.` [ e.g. `src/coding.cmd.inference-status` ] first. a deferred
  reply that is never completed must be cleaned up
- per-lookup state keyed by a lookup id : pending sids, replies so far,
  started time. a timeout [ `<osf-cache.cfg.lookup_timeout>` //= 5 s ]
  completes the lookup with whatever arrived ; non-answering peers
  count as failed [ undef reply into merge_replies ]
- when the last reply or the timeout arrives : `merge_replies` with
  `expect` = the asked anchors and their sizes from THIS node's index
  [ `<osf-cache.index>` anchors -> size ] ; anchors unknown to the local
  index are refused up front [ cannot verify a size we do not know ]
- reply text [ mode size ] : one line per anchor :
  `<anchor> <n> holders : <sid> <sid> ...` plus summary lines for
  missing, failed peers, conflicts, bmw_conflicts. zero peers ->
  mode true, `no peers`

## 4. access

- `cfg/zenki/osf-cache/zenka.v7` : peers may call `has` -- add the
  grant that lets other `osf-cache` sessions call it [ find the
  `access.cmd.usr.<zenka>` form used for zenka-to-zenka grants ] and
  `lookup` for cube users
- `cfg/zenki/cube/access.zenki` : osf-cache may send `has` to osf-cache
  sessions and query the session list -- find how sid-addressed routes
  are authorized there [ the target zenka name, or the sid ? ] and grant
  the narrowest form. explain the chosen form in the report

## tests

- harness already mirrors the zenka environment [ utf-8 layer,
  File::stat, $call \ $reply ] -- keep it
- per-subname defaults [ state path, cache dir ]
- lookup state machine with stubbed route-send + peers : all answer ;
  one times out ; zero peers ; unknown anchor refused ; size conflict
  and bmw conflict surface in the reply ; timeout cleanup leaves no
  pending state and no timer
- `bin/format-code -c` clean, never plain `perl -c`

## report

files touched, test output, how the session list is obtained, the
access form chosen and why, the deferred-reply mechanics used, and
everything that only a live run can confirm.

#,,,.,,,,,.,.,..,,.,.,.,,,...,,,.,.,,,,.,,.,,,..,,...,,..,,,,,,,.,,,,,.,,,.,.,
#3556ULZEINTSPG4IVXPPG3MZVHK45LVSTAPUBY6IU7BL3PTENOKTWBRBWPX7AZPOJNWTSPNT5TYYC
#\\\|LOJ7LHC6NCNEVKYCFAXZ7AQ57KMY5FWL5IZ2YRZNXBI6UVTRCJK \ / AMOS7 \ YOURUM ::
#\[7]S4QY67DBTJD7GQ5VOPGKRHPP4KTR2TCUAX2V7QRMFF3APBZC24AQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
