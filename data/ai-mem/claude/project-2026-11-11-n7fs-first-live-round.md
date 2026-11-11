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
[ Fable finding 5 ] ; findings 2-4, 6, 7 of ~/.n/private-notes/fable-n7fs-review-2026-11-11.md ;
a transport of its own [ UDT idea ] ; n7fs-push could reuse one ssh connection too.
[[n7fs-relay-fanout-filters]] [[n7fs-host-migration-goal]]

#,,.,,,,.,,,,,,.,,..,,,.,,..,,,,,,,,,,,.,,.,,,..,,...,...,,..,.,,,.,,,,..,,,.,
#N3FNZRLZ64GIFVE2AKVJHYDARDWNPWCAMWIESDYW4KZANO3GHMVYE3WWWKGITQYJ4KAXB6T75PO4M
#\\\|7GA6NJNBVQWYXJXXBCNN67TASZKYNU2HR3RJIWF36OHAV2XX2JL \ / AMOS7 \ YOURUM ::
#\[7]2QDF7BIHRQMFBFNQFZBIQMPSTMMTM2HIH7QFGD6INIKEJ3YNJQDA 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
