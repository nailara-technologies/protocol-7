---
name: n7fs-first-live-round
description: 2026-11-11 first live N7FS round done, all holders checked ; disk ids, prune, rename, transport fixes ; open items
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

kimi : weekly quota hit 2026-11-11 mid-task ; a read-only review cost ~1 % \ 5h on K2.8.

open : the hourly jobsite timer \ place round ; map sharding + tree retention
[ Fable finding 5 ] ; findings 2-4, 6, 7 of ~/.n/private-notes/fable-n7fs-review-2026-11-11.md ;
a transport of its own [ UDT idea ] ; n7fs-push could reuse one ssh connection too.
[[n7fs-relay-fanout-filters]] [[n7fs-host-migration-goal]]

#,,.,,,.,,,..,...,,,,,,.,,,.,,,.,,.,.,,.,,.,.,..,,...,.,.,...,,,.,.,.,...,.,.,
#SPYX7H2JFHUCHXKAZ6HKRA5NNNJAOOSD4CZYOS3OGWPJP4SCQHWAK7F35K62JLPNYCEMSP6TTGNF4
#\\\|Y7K34HF374Z2WMD4UXBT4CFEUHYS5HOMKKZXJI5GSWLI5X2ZYSZ \ / AMOS7 \ YOURUM ::
#\[7]MFGFCBGOXHOW5BEW3COJQOMXXI7VXZ3UXPBAHTCQQ7WVTL4FBSBQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
