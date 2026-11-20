---
name: n7fs-first-live-round
description: 2026-11-11 first live N7FS round done, all holders checked ; disk ids, prune, rename, transport fixes ; events jitter + list ; open items
metadata:
  type: project
---

2026-11-11 : the first full live round of N7FS is done : relay home -> hub, push hub ->
two more holders, adopt + holder-check on all three ; every holder maps the whole set
[ 762 blobs, 3 trees ] and holds a fresh receipt. set-up details :
~/.n/private-notes/n7fs-transport-local.md [ not tracked ].

commits [ base, pushed ] : 920843a83 disk ids, 553ae847b holder-prune + relay merge,
0e2d2f635 holder rename, 35444ceae ssh mux, 61bce9256 relay 2 workers, 0609c4ff0
download short read \ resume, 1448e4314 receive arg order, ec5502d16 holder-check by
name, c1ed14003 push retry, 39381a0ac keepalive 77 s. the relay got ~10x faster ;
workers share ONE mux tcp stream, so a second worker only helps on a clean route.

events [ same day ] : timetable key `jitter = <seconds> [harmonic]` [ 7aa9f6e3a,
events.jitter_offset ] : a random offset per run at ms precision, harmonic = a filter
on the drawn values [ is_true, as base.gen_id ] ; 780 s harmonic on dist-upgrade,
forensics, jobsite-scan in base \ jobsite \ letsencr setups. `list events` shows
next run [ centered ], jitter [ right-2 ], in [ base.parser.duration via
events.parser.time_left, right ]. a new src module needs `bin/dev/gen-sub-whitelist
<zenka>` ; test the events zenka locally with v7-zenki.start \ terminate events
[ stop it again : it would run its nightly jobs here ]. still to confirm : the
nightly runs fire at the jittered times.

kimi : weekly quota hit 2026-11-11 mid-task ; a read-only review cost ~1 % \ 5h on K2.8.

open : the hourly jobsite timer \ place round ; map sharding + tree retention
[ Fable finding 5 ] ; 1 + 4 done [ 4 = 48cc93e93 : coverage, keyless holder-scrub, drain needs full receipts ], 2 done [ f5bd660d6 lock, 7f61d11f4 grace + trash + per-root r-<tag>/ + holder-migrate, then receiver mode : ssh-receiver: holders, root-signed requests + replay counter, P7SH head signature -- hosts must upgrade together, migrate before receiver mode ], 3 done [ b5ca2fd31 pending, then incremental receipts : entry added-version + covered digest, place ends with holder-check, 2 d unreachable grace ], 6 done [ disk \ category root binding ], 7 8 9 open, of ~/.n/private-notes/fable-n7fs-review-2026-11-11.md ;
a transport of its own [ UDT idea ] ; n7fs-push could reuse one ssh connection too.
[[n7fs-relay-fanout-filters]] [[n7fs-host-migration-goal]]

#,,..,.,,,...,,..,.,,,...,,.,,,.,,...,.,.,,,,,..,,...,...,...,,,,,,,.,..,,,,.,
#BV6BN2FQWPZHF7BMIR6B2O5DFYGJRPD2K6ELLOG3N42RGBVZKAP5IITT2DA4F4CGDRDMJV7IUPWFW
#\\\|GCE53EBYAIPAG7PBIZDUO5C4WRHL656ZTGHBSPG3UCQN47YZORK \ / AMOS7 \ YOURUM ::
#\[7]QS6UTF7ATXQ6AW6VYDTBJTJPA4DAGPL7REALJT5XXRPG32JPC6BY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
