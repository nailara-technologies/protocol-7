---
name: session-handover-native-hub-watchers
description: 2026-11-25 pm handover [ new form : pointer + decisions + lessons + next ] -- shard fix, session registry \ keep-alive \ stable ids, unless= reminders, native writer, watcher stage 1 ; tier A place running on azurum
metadata:
  type: project
---

**the current state is derived, not written here** : run `p7c coding.handover` [ or read
data/ai-mem/claude/handover-live.md, refreshed by `p7c coding.handover write` ] and
`p7c coding.sessions`, `p7c coding.reminders`, `p7c usage.plan`, `::: azurum system.watches`.
base pushed up to 71ba3f9d2a ; azurum deployed at 71ba3f9d2a.

## decisions of the day [ owner ]

- NATIVE IS THE HUB [ memory p7-config-style-not-json ] : extend native, never a classic format
  inside ; converters at the edges, inward exact, outward may simplify ; native may evolve
- persistence follows reality ; bare timers never carried over ; a session may detach early ;
  the handover is DERIVED -- this file is the new form [ pointer + what cannot be derived ]
- task elements, thinking as content-addressed nodes, the dedup tree first, the always current
  tree language, one node across languages and senders, privacy by addressee, contexts as
  branched node selections with targeted compaction as a model tool [ data/tasks/task-elements.md ]
- sessions started by signals [ claude-zenka.md item 8 ] ; system detects, events routes,
  channels carries, transports as registered backends [ data/tasks/watcher-registry.md ]

## lessons

- review every dispatch : today caught a token leak [ kimi runs inherited the inbox socket and
  token -> fixed in _sanitize_agent_env ], a broken whitelist [ unless modules ], a test suite
  missed after the ntime switch [ test-usage-budget ] -- run EVERY suite touching changed code
- the commit hook's restore-permissions cut ACL masks [ data/ai-mem/claude lost protocol-7 write ]
  -> fixed, masks kept ; the script runs with `local $/ = undef`
- core module changes [ AMOS7::Config, base.sig_chld ] : prove them broadly -- Config was compared
  over 5488 cfg files [ deep Data::Dumper compare, two separate subs ], no real config changed
- WSL crashed twice : stable session id [ CLAUDE_CODE_SESSION_ID ] now carries session state ;
  /var/run is tmpfs [ never persist there ]

## running \ waiting

- tier A place on azurum [ tmux tierB:placement, as taeki ], watched : watch.place.complete fires
  on azurum when it ends [ rc=unknown : not a child ] ; then verify, then the intel disk rule
- reminders : 30.11 16:00 + 01.12 11:30 [ owner's video call, to=notify ], 20:42 kimi
  [ unless=budget:kimi:7d>=100 ]
- the 512 GB PM871 disk is arriving

## next [ ideas, each a small step ]

1. n7fs place \ placement raise their own completion signal with the real rc [ p7c events.signal ]
2. a session-start action plugin [ claude \ kimi, prompt file, context template ]
3. watcher stage 2 : events -> channels, p7-link as first transport backend [ place.complete@azurum ]
4. a context.handover provider for the dynamic context templates
5. the first native extension : multi-line values [ the writer reports the gap ]
6. kimi wire.jsonl normaliser for the session archive [ notes in session-archive.md ]
7. small : handover write error names the real cause [ said ENOENT on EACCES ]

#,,..,..,,...,...,.,,,.,.,.,.,...,...,..,,.,,,..,,...,...,...,.,,,,.,,..,,,.,,
#56QOUAYE2NWJDXHZ5VADV5Q2KK7AV4SV3N2OTIPUP4XGPHZGGLB7DO3S6QND7UXNXQHGDCFOSPNX2
#\\\|K7LIFP3UNJCGPT37T4DGSB4HJXXJ4L7KS2CX5FXD2PFOREEDVGD \ / AMOS7 \ YOURUM ::
#\[7]ZA4ISAMN635B3E7UATOI4BC23MLYHOI7JROIV3AMNKL5DI2Z4YDY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
