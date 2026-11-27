---
name: session-handover-hotspot-keepalive-drills
description: 2026-11-27 handover -- hotspot plugin, reset activity fix, session cache keep-alive, drill notices from azurum, remote pull counters, heartbeat timeouts 19 \ 27 ; tier A drills running
metadata:
  type: project
---

state is in git [ base, pushed up to 9af778e5b7 ; later commits local until the next push ].
this note : decisions, lessons, what is open.

## landed 2026-11-27 [ newest last ]

- 085ffec1ae v7-zenki.hotspot plugin [ gdb PL_curcop samples, :core: ] -- first run on cube :
  idle in Event.pm. needs gdb [ p7-deps profile v7-zenki-hotspot ], servers have none
- d48f665445 usage : `not defined X ? ..` parsed as not( .. ) -> activity was EMPTY, every
  window reset woke sessions [ my own 6e3d22026a ] ; unknown activity = level none ; X-11
  nvidia-smi '[Invalid Argument]' [ wsl temperature ] one level 1 line
- 6020c4818d + d6c0f74c64 session cache keep-alive [ kimi built, reviewed ] : open items
  [ open.dispatch.* \ open.wait.* ] in coding.sessions.store ; mcp server registers its
  dispatches [ needs /mcp reconnect after changes ], p7-sign-wait its sign job [ sid lookup,
  no P7_SESSION_NAME needed ] ; plugin.events.cache-keepalive sends ~54 min after last
  activity, only while something is open ; `coding.session-cache-keepalive on|off sid=<sid>`
  = my own switch. coding.keepalive.* untouched, retire later by decision. NOT yet proven
  live : the first sign wait > 54 min shows it
- 9af778e5b7 drill.complete like place.complete [ target = holder alias . tree ] ; deployed
  to azurum [ pull-git zenka via `v7-zenki.start_once :wait-down: pull-git` ] ; this host's
  overlay /etc/protocol-7/host-config/events.cfg pull list now `place.complete drill.complete`
  [ owner edited, root file ]
- f1046d0aad remote pull : refused \ invalid were never reset per run -> 3 old refusals made
  every pull a level 0 failure ; refusals now named in the line
- ceb8924e0a remote pull 'ended' + exit 0 = normal end [ child gone before stdout eof read ]
- heartbeat : 27 s for events X-11 task discover system [ start.cfg ], invoke-web 47 s ;
  3078c5f990 base set-up global 19 s [ was the 17 s built-in -- owner : raise slowly, next
  step 24 if timeouts continue ]
- 3caf109a67 task note : v7-zenki's own loop stalled 4.2 s under critical pressure
  [ late-timer log ] -> plan : a late timer reads input first or extends by its lateness

## open

- tier A drills on azurum : 4 runs [ yourum + zulum x rescue-W520-tierA \ rescue-X220T-tierA,
  -max-bytes 2G ], owner runs them by hand [ passphrase each ]. drill -from needs the holder
  SPEC [ `n7fs holder list` ], not the name. results decide the intel 240G wipe rule
  [ private note laptop-disk-rescue ]. then : new 512G ssd -> p7-host-build first live test
  -> place onto its /data -> intel free -> rescue system + debian on the X220T
- test-notify-wiring.pl crashes [ undefined sub ref ] on the committed version too
- test-coding-sessions.pl : one flaky failure seen once, not reproduced
- claim \ lease rework, quiet retries to external zulum, pressure branch -> plugin,
  late-timer rule [ data/tasks/claim-lease-and-quiet-retries.md ]
- keep-alive plugin is loaded with all plugin.events.* [ no separate off switch ]

## lessons [ details in feedback files ]

- sign runs : run format-code -r first, read the WHOLE -c output [ descr max 55 bytes ],
  never edit a file while its run awaits approval [[feedback-sign-gate-and-pending-edits]]
- cube access.zenki changes need `p7c reload config` [ reload source does not re-read it ]
- reload replies are multi-line : grep success \ fail, never tail
- `sudo -iu <user> bash -c '...'` mangles loop variables : one command per line
- the 'events' cross-session messages come through THIS session's own inbox socket

#,,.,,...,,..,,.,,,,.,,,.,,,.,,,.,...,,.,,...,..,,...,..,,...,...,,.,,.,.,..,,
#FRLBV3B4KDTX6XKDQCPSVOZBX2HHUBM62OHMVMKWVUKRST6MNVJTB6C7AHIDAG7O5WLV3FNNHAAFW
#\\\|HVME5DXL7BPHLRTEN4Z7V7U5B3HBXG66EA52CNWMJONA5PCNBQG \ / AMOS7 \ YOURUM ::
#\[7]JG3R4WI5GL5WBS6S5EM6BZULTGMLMSVXC27Y7PTHKREEUZKHXCCQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
