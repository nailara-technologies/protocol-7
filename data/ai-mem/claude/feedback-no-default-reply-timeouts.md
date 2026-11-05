---
name: feedback-no-default-reply-timeouts
description: never a default or global reply timeout : routed commands take however long they take ; timeouts only requested by the caller or assigned in context ; a stuck target is a liveness problem
metadata:
  type: feedback
---

owner 2026-11-05 [ pri : `::: pri taeki.name` hung on a stuck nshell session ] : a reply timeout is never
the default and never one global value. the default assumption is 'however long it takes' -- on failure
the command route collapses and the caller is notified anyway. a timeout collapses it too, but changes the
resilience and can make long-running tasks uncompletable.

**Why:** timeouts cut slow-but-healthy work ; the hang came from a target that was stuck but still
connected [ user sessions have no heartbeat ], not from a missing timeout.

**per hop, not per route :** a timeout can sit on ONE hop only -- assigned in the target zone by the
zenka around the activity, OR by the calling zenka from the range it knows the request needs plus a safe
margin. it makes sense only when that zenka knows it signals task failure without
false positives, or when it is coordinated with other zenki and network cycles. later collapse kinds
[ not applicable yet ] : max hops on the route exceeded, request no longer completable.

**relapse the same day [ c68fb26d9 ] :** the cube liveness probe shipped ACTIVE with built-in 30 s x 3
misses -- a default timeout in all but name, the exact thing ruled out an hour earlier ; it also closed
clients that can never answer `heart` [ bin/nshell, socat ]. corrected : runs only with configured
`cube.cfg.liveness.interval` + `.misses`, no fallback values. a liveness check that CLOSES things is a
timeout : no default activation, no default values, ever -- check that before the first commit.

**How to apply:** the `# [LLL] set up reply timeout` placeholder in base.handler.command becomes an
OPT-IN : requested by the caller [ call args \ client option ] or assigned by a handler that knows its
command. fix stuck targets with liveness detection [ heartbeat \ session checks ] so the route collapses
the normal way. same spirit : [[feedback-no-ack-for-absolute-state-signals]],
[[feedback-changed-established-behavior-silently]].

#,,..,.,.,,.,,...,..,,,.,,..,,,..,,,.,...,,.,,..,,...,...,,,,,,..,.,,,...,..,,
#GXSZHXJ6BISHKUSBV5GNI3HJ4YNHIPUWDDFGTRC5L3QTUPR6J27EDQZ4VNF6L3KFIJQCM74GLMB7S
#\\\|ANTBVRIOVI4FPVZOF5TKJOCSFO35C533WEPJWSDRNCOQ3MFLJDE \ / AMOS7 \ YOURUM ::
#\[7]7PXXMFPH4UZGS4DRAHTXMNCXM6O46O6JDORFF3YQRUKSNFEHOADA 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
