# osf-cache stage 4b : holders reached over external links

follows stage 4 [ `1c15c65d9`, live : multi-source fetch from main +
`osf-cache[peer]` into `osf-cache[peer2]` ] and the external links
[ `c26bfb171` : `external.connect <name> <host[:port]>` opens an
encrypted named link, then `external.<name>.<zenka>.<command>` reaches
that host's cube -- verified on localhost as `external.self.list
sessions` ].

goal : osf-cache also finds holders behind configured external links and
fetches from them exactly like from local peers -- one fetch may mix
local and remote holders.

do NOT start, restart or reload any zenka, no sudo, no commit, do NOT try
to sign files. do NOT edit anything under `cfg/zenki/cube/` or
`cfg/zenki/external/` [ access grants are done by the reviewer, they need
a cube config reload ].

## 1. holder ids become routes

today a holder is a bare cube sid : sorted with `<=>`, compared with
`!=` \ `==`, turned into a command as `"$sid.cmd"`. from now on a holder
is a ROUTE PREFIX string :

- local holder : `<sid>`                      [ unchanged ]
- remote holder : `external.<link>.<sid>`

every command goes to `"<holder>.<cmd>"`. replace every numeric
compare \ sort of holders with string-safe ones ; sort order : local
holders first [ numeric by sid ], then remote ones [ by link name, then
numeric by sid ]. the quorum module, holder exclusion [ `holder_fail` ],
the pump, segment \ merkle \ leaves requests, `lookup.merge_replies`,
`fetch.lookup_done`, the reply texts and `has` reply parsing all take
holder strings. grep for `<=>`, `!=`, `==` on sids in `src/osf-cache.*`
-- every one is a candidate.

## 2. peer discovery over links

- new config `<osf-cache.cfg.remote_links>` [ //= '' in init_code,
  space-separated link names, e.g. `self` ]
- `osf-cache.peers.list` stays the single place peers come from : it
  asks local cube as today AND, for each configured link,
  `external.<link>.list sessions osf-cache` ; each answer is parsed with
  the existing table parser [ `osf-cache.handler.peers_list` logic --
  factor the parsing out so both use it ] ; remote rows become
  `external.<link>.<usid>` ; the own-sid filter applies to the LOCAL
  listing only
- the callback fires once, after ALL listings answered or a timeout
  [ `<osf-cache.cfg.lookup_timeout>` ] ; a link that fails \ times out is
  reported like a failed peer [ never a crash, never a hang ] and the
  lookup goes on with what answered
- the callback contract stays `{ peers => [ holder strings ], params }`

loopback note : with `external.self` pointing at this host's own cube,
the remote listing repeats the local osf-cache instances -> a local
holder appears twice [ `<sid>` and `external.self.<sid>` ]. that is
fine [ same data, two transports ] and is the live test : a fetch that
uses both.

## 3. tests [ bin/test-scripts/test-osf-cache-debian.pl ]

stub route-send so `external.<link>.*` commands are recorded like the
others :

- peers.list with one link : local + remote holders in the documented
  order, own sid filtered only locally
- a link that times out : lookup completes, link listed as failed
- a link answering malformed \ empty : no crash, no holders from it
- fetch with one local and one remote holder : both get segment
  requests [ `<sid>.segment` and `external.self.<sid>.segment` ], file
  placed and verified ; the stage 3 \ 4 tests stay green
- holder exclusion with a remote holder [ bad leaf ] : excluded by its
  route string, the local one finishes
- `bin/format-code -c` clean, never plain `perl -c`
- `bin/dev/gen-sub-whitelist osf-cache` [ ONLY osf-cache ]

## pitfalls [ this codebase ]

- harness mirrors the zenka : utf-8 open layer [ binary needs `:raw` ],
  `CORE::stat`, `.cmd.` `$call` \ `$reply` header [ never `my $reply` in a
  .cmd. module ], multi-line replies `mode => size`
- `qw| two words |` is a LIST ; `<word>` without a dot is readline
- `my $x = a and b` parses as `( my $x = a ) and b` -- use if-conditions
  [ bit kimi in stage 4 ]
- every new test package needs its own `use English`
- `# descr` max 55 chars ; `$ARG` not `$_` ; lowercase comments, `[ ]`
- named handlers [ strings ], never stored code refs [ reload safety ]

## security note [ state it in comments where holders are chosen ]

the external link authenticates US to the remote cube but does not yet
prove the SERVER's identity [ open : the trust chain work ]. content
stays safe [ every segment checked against the agreed merkle leaf, the
file against the signed anchor ] ; commands over the link are not yet
authenticated end to end -> localhost \ own nodes only for now.

## report

files touched, full test output, how holders are ordered and compared,
how link failures surface, what only a live run can confirm. write the
report as soon as tests pass -- the last run hit its quota during
cleanup.

#,,..,,,,,,,,,,..,.,.,,..,,,.,,,.,..,,,..,,..,..,,...,...,.,.,.,.,..,,,.,,.,.,
#2QYH53RB6ZNN3MCOCBVYRPED4ZBOBVHC6JHGEKV7DIZUC4HITADDOQ3CTNUJKGWBC2HLURQVW2H62
#\\\|Y5NOS2N53RQ4CTXH5WTYPEKINTUITOQ4XS6VM5UNXQDU2H6NXQE \ / AMOS7 \ YOURUM ::
#\[7]XRH3QLXMGOKJ77F5X7OOMPY3IOBHUMSSMQ2TEQZT73X3M74J44AQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
