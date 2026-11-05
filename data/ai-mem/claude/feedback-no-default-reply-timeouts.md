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

**How to apply:** the `# [LLL] set up reply timeout` placeholder in base.handler.command becomes an
OPT-IN : requested by the caller [ call args \ client option ] or assigned by a handler that knows its
command. fix stuck targets with liveness detection [ heartbeat \ session checks ] so the route collapses
the normal way. same spirit : [[feedback-no-ack-for-absolute-state-signals]],
[[feedback-changed-established-behavior-silently]].

#,,,.,..,,.,,,,,,,.,.,.,.,.,.,..,,,,.,..,,,,.,..,,...,...,...,.,,,...,,,.,,..,
#4K5EEB4P2RFO52YAW6VZP66VZMNHIAXNFSPMQ7DK65F65UP6277M2ZY3O223QZJ7S2JCED5U5XEOG
#\\\|ZBCMCUILFQZ3RL7AIF6X4RIIKPZMZHWLV5ARSTC5UT3K2GF2X6V \ / AMOS7 \ YOURUM ::
#\[7]JENVATZQZ5JHU2DPSZGLXAIFOYSEYTENMVSNQTZGNL76MDSEXYAI 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
