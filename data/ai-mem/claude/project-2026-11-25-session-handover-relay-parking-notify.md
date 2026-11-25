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

#,,,,,,,.,..,,,,,,.,.,..,,,,.,.,.,.,.,,,,,.,.,..,,...,..,,,,.,,..,...,...,,..,
#3VUHORK6LEUNG4IIB6EEO3WGYW4A5J4ZTM2YKWGXG7FNN326P7GISQ65TO3P2BUOYQA4DFLQE7AE2
#\\\|W3RZAILBJYKQFT4R7Y5MAWZKJ5N2S3P7LHVSEJET5EPUA4DFWPK \ / AMOS7 \ YOURUM ::
#\[7]PM6K6NZTG5SHBPJ2YID5DZ6AWMJBJGDZBMJAKSUJG7OF7BNIW6BI 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
