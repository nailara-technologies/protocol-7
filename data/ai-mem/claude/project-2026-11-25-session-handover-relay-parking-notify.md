---
name: session-handover-relay-parking-notify
description: 2026-11-25 handover -- parking, claude \ kimi zenki, chat relay into the live session, usage.plan pace, notify, coding handover \ reminders \ sign queue ; tier A place pending ; C: space
metadata:
  type: project
---

session 2026-11-24 \ 25 [ base 615d528080 .. afffd90525, all pushed ]. read
data/ai-mem/claude/handover-live.md first [ `p7c coding.handover write` refreshes it ].

## built and live on the wsl host

- parking : task.park \ coding.park [ at \ after \ on \ depends \ budget=<p>:<w><op><pct> ],
  woken once through the events buckets ; events always-on in base \ desktop-login \ local-models
- claude zenka [ owner mode : admin user ] + kimi acp adapter, shared stream_child.* ; resume
  works live for both ; run.done \ run.start signals granted [ access.signals : keys are
  `events.signal.<zenka> = names` ]
- chat relay : `chat -m claude` into the LIVE session [ inbox socket registered by the mcp
  server, token in memory only, leak-checked ], kimi over acp ; `-relay off|on [-for]` loses
  nothing. dispatched runs get P7_SESSION_REGISTER=no ; several sessions -> name one, never guess
- usage.plan : 7d \ 5h bars, windows left, share per window, pace on both scales
- notify stage 1+1b : notify.map in cfg/zenki/events/, ticker status lines, dnd on disk,
  AMOS7::Switch, rate limit ; bin/warning-sound -profile soft [ 0.24 ] + cfg/warning-sound
- coding zenka : ask \ answer \ open [ menu pending questions, persisted ], sign-queue +
  commit-plan [ requests signs, commits after approval ], handover [ write ], remind [ to=session:<name> ]
- usage.token-leak-check : 0 hits live ; protocol-7-owned dirs not readable as taeki
- n7fs : place \ placement -only-category \ -only-holder ; batch-read names, exit status kept
  on failed uploads, import estimate from sizes ; AMOS7::TERM password read without a console

## after the first sync [ 05:25 ]

- commits since : 2beb90a03c memory, 9ef8dbca36 session continuity stage 1 [ claude \ kimi
  session-export \ -import \ -lease ] + n7fs profile, 9ddbc51d1b usage.plan [ nearer reset as
  horizon, fixed window budget, stable 5h \ 7d ratio ]
- the real tier A place was STOPPED by the owner during its planning phase [ nothing written ] :
  data/tasks/n7fs-place-parallel.md -- the holder map shard cache thrashes [ 16 of up to 1024
  shards cached, random order ; 10.8 s -> 1.4 s with no eviction ] ; holder_check and
  _tree_inventory share the pattern. FIRST in the new week : the shard fix, then the place again
- azurum is at afffd90525 [ pulled, no cube restart yet ]
- BUG [ open ] : reminder remind-179557841566601 [ at 05:30, added 04:46 after a cube restart,
  43 min ahead ] stayed `waiting` past its time and never fired ; a 2 min one at 00:17 fired.
  suspect : its timer is cancelled when other entries of the coding bucket are re-armed
  [ coding.handover re-arms its 3 watch entries after every event ] or long `at` timers are
  lost. check plugin.events.source.timetable arm \ events.cmd.bucket-add re-arm scope first
- list [ owner 2026-11-25 ] : event buckets store `at` \ `added` as unix time
  [ entry.<id>.at = 1795581000 ] -- switch to ntime, at least numerical ntime, in the bucket
  files and journals ; with the reminder bug above, same code paths
- shard fix run cr-1125-052842-1568-7 [ opus ] started 05:28 -- resume it if the 7d limit stopped it

## pending

- tier A place on azurum [ tmux tierB:placement, as taeki ] : `place JXO355A -root-key vault:main
  -only-category rescue -only-holder yourum,zulum` -- dry run was running [ single core, slow ] ;
  164327 rescue nodes at 0 copies, 104 G. then the intel disk [ W520's, still tier A's second
  copy ] may be wiped [ private notes rule ] ; home-packed needs ~235 G [ azurum /data 58 G free ]
  -> intel disk or the 512 GB PM871 [ arriving ]
- azurum is at e18ec8f942 : pull + cube restart for afffd90525
- C: had 2.6 G free [ vhdx host ] ; now ~22 G+ ; verified model delete
  [ ~/rescue-manifests/c-models-delete.* , cmp per file, 7 partly-unique model dirs kept whole ]
  was interrupted by a wsl crash, resumed at low priority
- rescue manifests : /data/rescue-manifests [ azurum ], ~/rescue-manifests [ wsl ] ; 13 fuller
  videos copied to the ext disk
- briefs : data/tasks/claude-zenka.md [ coding zenka stages, relay, run-as modes, n7fs session
  continuity ], session-archive.md, notifications.md [ alarm loop on X hosts next ],
  display-hosts.md [ azurum beamer, rpi touch panel, portrait dashboards ]
- small open : format-code-cmd test fixture ; stray ./ound in the repo root [ owner to look at ] ;
  n7fs place planning single-threaded

## how this session worked [ keep ]

- dispatch with template=p7-dispatch-rules ; inbox wake-up ends waits [ no polling ]
- review every run : two real bugs caught in review [ chat base32 to session commands, HiRes sleep ]
- one sign at a time ; changed AMOS modules must join the sign set or the sign aborts
- the usage.plan pace line decides how much runs in parallel

#,,..,,,.,,,,,,.,,,.,,,.,,,,,,,,.,.,,,,.,,..,,..,,...,...,,..,.,.,.,.,...,,,,,
#7Z6YOGSZMOABDEE4JYURNYZYXQWI4446FFVHGKX3XY6KO2LH6WDGCAD6FDAAX3ZM4U2XFOLPHTF2S
#\\\|XJIGZ5QAJPYE34HC6CLOCDC2JV5JD6G6W7BTMU3LWBU67ZWPI2W \ / AMOS7 \ YOURUM ::
#\[7]EXWF5JGQ452SYLWPTIPLRYKH6VHJTYGAL3JPTR2NFLPYREE4LKAI 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
