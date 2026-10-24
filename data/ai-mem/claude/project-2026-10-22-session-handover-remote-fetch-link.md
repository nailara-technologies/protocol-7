---
name: project-2026-10-22-session-handover-remote-fetch-link
description: previous handover -- session 2026-10-21..22 handover [ last b6a6ed425 ] : jobsite cert + nameserv fixes, web secret rotation, optional dependencies, remote fetch srv-U -> srv-V over an encrypted link WORKS [ 279 new jobs ] ; open : coding 'depending' queue on srv-U, link not yet permanent, 3 cloud design docs pending
metadata:
  type: project
---

previous : [[project-2026-10-21-session-handover-editor-hints-assimilation]].
budget at the end : claude 7d ~15 % [ window resets ~2026-10-28 ], kimi 7d
reset 2026-10-21 23:00 [ one k2.8 job used ], cloud credits ~$55 of 100
minus 6 design sessions [ expire 2026-11-05 ].

## landed [ all pushed, all deployed to srv-U srv-A srv-V ]

- 74dec9f91 \ 8d1a010c0 : v7-zenki.rotate-web-auth-secret [ :force-now: \
  :no-restart: ; File::stat gotcha : stat list slice is undef in zenki ]
  -- srv-U rotated 2026-10-21 22:27 [ 0 sessions ; the old secret leaked into
  the transcript earlier, now dead ]
- d098e4a0e nameserv sync : bounded long-poll hold [ max_hold 390 ] +
  reap half-open waits [ srv-A sat on a dead v6 socket since 10-19 ]
- bd289c62a nameserv : echo the question exactly as received [ 0x20 ;
  lowercased echo = SERVFAIL at lets encrypt ] -> jobsite.taute.re cert
  issued 2026-10-21 22:26
- e12d9b6ac + 9b9be909a : start.cfg optional_dependencies ; a dependency
  the start profile refuses [ disabled OR not in the on-demand allow list,
  v7-zenki.zenka.profile_refusal ] refuses the dependent ; external :
  discover optional
- 07239e1f7 reload config re-applies the host overlay last [ srv-U fell
  from remote-server to base and started discover \ debian on a server ;
  see [[feedback-config-reload-clobber]] ]
- aa8b39cb5 + b6a6ed425 remote fetch : jobsite.cfg.fetch_zenka, site-yaml
  handler=:hold: outbox + subscribe-fetched STRM [ backlog first, ends when
  queue + imports + outbox are done ], jobsite subscribes [ also 6 s after
  start ] and confirms only stored jobs. kimi-built, reviewed
- 6282454b8 \ 35387ca02 \ e09c0c1ba : external.authorize-link \ revoke-link
  [ fixed ssh restrictions, pin in incoming/ + authorizing SYMLINK -- the
  auth-keypair convention, a plain file is not enough ], access.users
  remote-fetch grant, external routes *.site-yaml.*
- bin/mcp-server-p7 : cloud preamble asks for 'p7-session-status :
  in-progress \ paused \ blocked \ completed' trailers

## live state

- srv-U jobsite fetches through srv-V : host.cfg jobsite.cfg.fetch_zenka =
  external.srv-V.site-yaml [ backup .bak-before-fetch-zenka ]. first run :
  630 records delivered, 1376 -> 1654 jobs, 279 new
- [ SUPERSEDED 2026-10-24 : now a managed link, see
  [[project-2026-10-24-delta-link-managed]] ] the link WAS by hand : `ssh -4 -N -L 127.0.0.1:4243:127.0.0.1:42` as
  protocol-7 on srv-U [ key ~protocol-7/.ssh/id_ed25519_link ] +
  `external.connect srv-V 127.0.0.1:4243 remote-fetch`. a srv-U restart ends
  both -- redo them [ -4 : srv-U <-> srv-V and srv-U <-> srv-A ipv6 is broken ]
- srv-V host.cfg : v7-zenki.host.zenki.on-demand += external site-yaml
  nodes [ backup .bak-before-remote-fetch ]

## open, next steps

1. **coding on srv-U** : jobsite dispatched [ task SP6GUHA, 277 remaining ],
   coding moved the job into its 'depending' queue -- find what it waits on
   [ level-1 logs do not say ]. suspects : assessment_model OFSQC4I vs
   loaded KMUVFQQ [ model switch ], or a jobqueue dependency. backend is
   cpu [ ttft 60-106 s ] : 277 assessments take many hours
2. **permanent link** : cloud doc LINK-ZENKI-AND-TRANSPORTS.md [ session
   011tbj7p : link as a v7-zenki-managed zenka per host record = the 3W5
   supervisor ; transports incl. the ssh zenka -- its 'fix' hash 2D64177A
   is in no ref, cause unverified ]
3. **cloud docs** : landed V7-ZENKI-DEPENDENCIES-AND-RESTART, PROXY-EXIT-
   ROUTING, VAULT-TYPES-AND-CONVERSION [ reviewed for structure only ;
   their open questions need the owner ]. pending : CREDENTIAL-LAYERS,
   SESSIONS-ZENKA, LINK-ZENKI-AND-TRANSPORTS [ fetch with
   claude_cloud_result, `git checkout hub/<branch> -- <file>` ]. vault doc
   flags host vs host_record against CREDENTIAL-LAYERS section 5
4. **correct** : cube answers refused on-demand callers with the fixed
   template IRW7V6A, the reason only reaches its log [ found by the v7-zenki
   design doc, stage 0 ] -- commit e12d9b6ac's message overstates this
5. todos added : R4F session classes, B4C dependencies part 2, FEQ
   backend-restart [ execve, drain, :keep-zenki: ], 6VV letsencr \ nameserv
   leftovers, 6C6 credential layers, DKX vault sealed import, CSR cloud
   completion notices, HS4 + 3W5 appends
6. still open from before : web.auth-issue ui token [ owner runs it :
   token must not pass the transcript ], retire the old jobs vhost on srv-F,
   srv-A ipv6 [ provider side ? ], todo Q7O \ YBX

## lessons

- the auto-mode classifier blocks writing authorized_keys \ trust entries
  even with owner approval : build a command with fixed restrictions and
  let the owner run it [ external.authorize-link ]
- never print a host.cfg whole -- grep keys, hash values
- a cloud session pushes an empty dev/<topic> branch first [ push-path
  proof ] and sometimes a claude/<topic>-<suffix> branch too : a new branch
  is never 'done'

#,,..,,.,,,..,...,,,,,,,.,,..,,,.,.,.,,,.,,,,,..,,...,..,,.,.,.,.,,,,,.,.,.,,,
#6ABSRYZ4DJX4MU4URI3WTN5D4URO3VSVUG2YH3FADFR5DB6DV4YDM6KOZ6GQQQ53V7UNV5EGNLOQE
#\\\|DQG5GIQTFLUCZCX2GWABYP6JKOA4ATZSRAMVWDHSYOJMYTUTR4E \ / AMOS7 \ YOURUM ::
#\[7]TAQSG7T4TFIS7GIYHD7O7BH5JOKK5F7TJ45AXGM7HEHJ3HEWXWCA 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
