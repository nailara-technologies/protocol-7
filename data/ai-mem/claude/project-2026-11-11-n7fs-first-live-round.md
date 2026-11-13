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

commits [ base, pushed ] : 19654d999 disk ids, c07e775c9 holder-prune + relay merge,
7d55c55f7 holder rename, 54053a5ea ssh mux, 3b911d67d relay 2 workers, 96ed48d21
download short read \ resume, 55f3ac287 receive arg order, 92e1ea9a0 holder-check by
name, 3335f5f42 push retry, 10db93039 keepalive 77 s. the relay got ~10x faster ;
workers share ONE mux tcp stream, so a second worker only helps on a clean route.

events [ same day ] : timetable key `jitter = <seconds> [harmonic]` [ fc69f9225,
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
[ Fable finding 5 ] ; 1 + 4 done [ 4 = 02327836a : coverage, keyless holder-scrub, drain needs full receipts ], 2 done [ e317e4eb6 lock, e1bc31c26 grace + trash + per-root r-<tag>/ + holder-migrate, then receiver mode : ssh-receiver: holders, root-signed requests + replay counter, P7SH head signature -- hosts must upgrade together, migrate before receiver mode ], 3 partly [ 22f334d32 pending ], 6 7 8 9 open, of ~/.n/private-notes/fable-n7fs-review-2026-11-11.md ;
a transport of its own [ UDT idea ] ; n7fs-push could reuse one ssh connection too.
[[n7fs-relay-fanout-filters]] [[n7fs-host-migration-goal]]

#,,,,,,..,,.,,,..,,.,,.,,,...,..,,,,.,,..,,,.,..,,...,...,...,,.,,.,,,,,,,,,.,
#TXRSWIPSWY6GGDVMFF2XBSYGWIQVCCKMRECR2E5BTH7NOIER3XZEH74YE5JBWC6HYKX5ATFLATSQK
#\\\|RHIFJCSEQ7B7NSQ7GHDA7YII7O5LOT4VT76ITTSM5ZYOPQZXG45 \ / AMOS7 \ YOURUM ::
#\[7]67NF2L5YAZJH3SRZCB6LB57TBHDSOM3OGQFDZUMAGGH6LBKLZOCY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
