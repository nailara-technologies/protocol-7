---
name: feedback-verify-symptom-shape-before-hypothesis
description: "off overnight" / "stops working" is ambiguous between a process actually dying and a process staying alive but getting stuck — check which one it is (ps/logs) before investing in a hypothesis-driven diagnosis, don't let an available memory-documented failure class (e.g. v7 crash-restart gaps) substitute for confirming the actual symptom
metadata:
  type: feedback
---

During the radio-zenka resilience session ([[topic-radio-relay-zenka]]'s
"playback resilience phase 2" section), the user opened with "it frequently
happens that i go to sleep and it is off when waking up again." I read that
as a process-death symptom and spent a real chunk of the session chasing it
as one: checked whether the radio zenka was v7-managed, read
`v7.handler.zenka_status`'s restart/heartbeat logic in detail, checked `ps`
parent-child relationships, grepped the zenka's log for crash signatures —
all before the user corrected me: "the issue is not the zenka
disappearing.. only the playback.."

**Why this happened**: "off in the morning" is genuinely ambiguous between
two very different failure classes — (a) the process actually exited/crashed
and nothing restarted it, or (b) the process and its dependents are still
alive and online, but some piece of internal state got stuck so nothing
audible is happening. These need completely different fixes (process
supervision/restart config vs. application-level state-machine bugs). I
picked (a) because a prior memory-documented incident class
([[topic-mpv-x11-dependency-cascade-restart]], general v7 restart-cascade
behavior) was fresh and available to reason about, not because the evidence
actually pointed there — the log I eventually pulled (`ps` uptimes,
`v7.zenka.start`/`v7.handler.zenka_status` source) never showed an actual
crash-and-stay-down pattern, it showed a zenka that had just been manually
restarted that day, which is at best weak circumstantial evidence, not
confirmation.

**How to apply**: before building a diagnosis (and definitely before
drafting a fix or a dispatch task) around "X stopped happening," check the
literal shape of the symptom first — is the process/PID still running? Is it
still connected/online per its own status command? If yes to both, the bug
is almost certainly in application/session state, not process lifecycle —
don't reach for process-supervision fixes (v7 start-set-up membership,
heartbeat/restart config, crash forensics) until a real crash is confirmed
(missing PID, a genuine "shutdown"/"error" status transition in logs, or the
user explicitly says the process/window/UI is gone). Cheap to check
(`ps`/a status command) relative to the cost of a wrong hypothesis eating
significant investigation time before the user has to correct it.

#,,.,,,,,,...,,,,,,..,...,.,,,,,,,,..,.,,,,,,,..,,...,..,,.,,,,..,.,.,,,.,,.,,

#,,,.,.,,,,,,,.,.,,..,...,.,.,.,,,,..,,.,,.,,,..,,...,...,.,.,.,.,,..,,.,,,,,,
#B3LJI4KZICITKJXJAZZ5IFVISTOT4Q735QKAOOP2BZG7YDRFWSZEBLX4TSPBTQBKJR2DDF6W6XNGG
#\\\|NIELIQGARTI5W7S4VTRAFWJPQBW27ACRGTQ3NO5EVNMK3QCFVQ3 \ / AMOS7 \ YOURUM ::
#\[7]J5SMWOC574IQN3EP2MTGHMK365H6NTL64JL4KQ46EVN6SUQ42WBY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
