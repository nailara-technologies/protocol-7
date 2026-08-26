---
name: rename-scope-policy
description: "project policy — large namespace/file renames are judged purely on whether they're an improvement, never avoided for being large; reversals of past renames are fully in scope too"
metadata: 
  node_type: memory
  type: feedback
  originSessionId: e81d6781-e404-4cb2-9bd8-c1b6d0c366ef
  modified: 2026-08-20T22:56:51.112Z
---

protocol-7 project policy, stated directly by the user: large namespace
changes should not be avoided just because they are large. the only
criterion is whether the change is an improvement — including reversing
or re-changing something that turned out not to be better after all.

**why:** the repo has a real history of exactly this — `agents` → `zenki`,
`./src` → `configuration` → `code` → `modules` → `./src` (full circle),
`./cfg` → `configuration` → `cfg` (also full circle). none of these were
treated as too costly to redo; each was judged on its own merits at the
time. see the 2021-03-27 commit `B4389CC644...` ("rename 'agents' to
zenki, './cfg' > 'configuration', './src' > './base-code'") for the
oldest documented instance of this pattern. also: there are commercial appliances at former employers running builds
of protocol-7, but those forked off `base` years ago and no longer track
it — so nobody is pulling `base` who would be disrupted by renaming on
it now. the fallout cost of a rename on `base` today is cheap in a way
it would not be if something currently tracked `base` and depended on
stable paths/names — this is a current-phase-of-the-project reason, not
a permanent one. the last sync point with those forked-off deployments
is commit `3115d344d2e8965a72089b84ff341dff25041fe9` (2021-04-22,
"renamed ',.zenki/nroot/start-setup.basic' --> 'start-set-up.base'") —
fittingly, itself a rename of a start-config file in the same family
being renamed now (`zenka.v7`/`start.cfg`, see [[zenka-naming-cleanup]]).

**how to apply:** when proposing or reviewing a rename (file, directory,
module namespace, zenka name), do not raise scope/blast-radius as a reason
to hesitate or recommend against it — surface it only as a mechanical
fact (how many files, what tooling handles it), not as a caution. the
actual tool that makes large renames tractable is `bin/ncode`
(`ncode -ai-friendly -confirm replace <target> <old> <new>` over
`%targets` entries) — see [[zenka-naming-cleanup]] for the concrete
workflow and division of labor (agent stages ncode targets, user
typically runs the actual src/cfg/module rename pass).

#,,..,.,,,.,.,,,.,.,.,,..,,..,,,,,.,.,.,.,,.,,..,,...,...,,..,.,.,.,.,...,,.,,
#5SKOVGRQRSPO7RTIHAIZCJGE3V2U5PHWHHF4B5UNSGCRABCLQOLKJTA6EVBGVH26I3UW2V6J6ULWQ
#\\\|75M5QD4EREFISYRMYAQIZ6NGQWIHOPABBQBJY7AWKEIYRF3M3ML \ / AMOS7 \ YOURUM ::
#\[7]C4A6SIY2VLLDZODR67LUHC75FDPX7GNZYAAUH2GIBLIG227SQQDI 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
