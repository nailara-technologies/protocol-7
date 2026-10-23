---
name: project-2026-10-21-session-handover-editor-hints-assimilation
description: START HERE -- session 2026-10-21 handover [ last b4815589c ] : shared editor hardened end to end, coding model-pin hang fixed, hints.* detection layer [ 4 sources ], managed-abstraction principle, assimilation design ; open : nameserv \ letsencr steps on the remotes, remote links [ 3W5 ], ranking layer [ Q7O ]
metadata:
  type: project
---

previous : [[project-2026-10-18-session-handover-n7fs-truth-srv-U]]. the
nameserv \ letsencr \ web-auth session in between [ claude 782d4de8 ] wrote
no handover -- its open steps are below [ from a session_catchup summary ].
budget at the end : claude 7d low [ fresh window ], kimi 7d ~98 % [ resets
2026-10-21 evening ], cloud credits ~$55 [ expire 2026-11-05 ].

## landed [ pushed up to 50aaec5ae ; b4815589c not yet pushed at writing ]

- **AMOS7::TERM::Editor** [ todo + p7-vault share it ] :
  - b7630b4e0 characters end to end : utf-8 key assembly ; review fixed a
    lone latin-1 byte swallowing the next keys + single-slot pushback
  - 19d1e54dc resilience [ kimi audit, pty-reproduced ] : EINTR retry
    [ resize cut pastes into keystrokes ], lost tty = EIO -> abort [ was
    100 % cpu spin ], TSTP \ CONT [ STOP inside the handler ], cursor shape
    on every exit ; bin/test-scripts/test-term-editor-pty.pl [ 13 ]
  - 2d6dc6650 ctrl-s saves through `on_save` [ ctrl-o alias ] ; todo writes
    via the ctrl-x path ; p7-vault deliberately WITHOUT on_save [ new notes
    have no id, edits save all fields at once ] ; todo's SIGINT message ran
    on the success path since before 2026-08
  - 14e44a93f a literal "\e[201~" inside pasted text stays content
    [ terminator only ends a paste when nothing more is pending ]
- **coding zenka** cd20d4b70 : a content-only pin `:model::<content>:` for
  a model not loaded stayed unresolved, switch-model refused it BY REPLY,
  the in-flight flag stuck -> tasks parked forever [ hung every
  session_catchup ]. registry fallback in coding.mode.local_model_id ; a
  refusal fails the task. regression from d33c0fcf9
- **hints.\*** [ 9b4878b44, 50aaec5ae, b4815589c ] : candidates with their
  source for host records -- ssh_config [ Include conditional, %h, Match
  skipped + `shadowed_by_match` only when an EARLIER Match sets the
  keyword ], etc_hosts, known_hosts [ hashed entries, @revoked = conflict,
  corroboration only ], server_pins [ file names only ]. sanity + candidate
  + conflicts. tests test-hints 39, test-hints-sources 29. NOT wired into
  any zenka yet
- **principle** [[managed-abstraction]] [ 7ccd5a032 ] : layers settle what
  they can know, the user enters only where a decision remains ; context
  ranks options ; inference zenki get a clean context + a refined
  situational summary ; identity \ memory as continuation
- **assimilation** : data/md/design/ASSIMILATION-DEPTHS.md [ b4815589c ] --
  file- \ setup- \ key-import, depths 0 observe .. 4 host, "a source goes
  away by default only when getting it back is proven", hybrid links
  reflink > hardlink > symlink. the sourcecode checksum-symlink pair was
  REMOVED [ non-functional ; last in 50aaec5ae ]

## verified facts worth keeping

- `ssh -G` RUNS `Match exec` commands [ OpenSSH 10.5p1, fixture test ] --
  use -G as a source only on configs without Match exec
- host-edit add-host works live over ssh : srv-F record saved with
  transports ssh, `done : pinned` [ key TWVQ6QL ]. records : srv-F [ no roles
  \ link_user ], srv-U [ name + ssh only ] ; srv-V \ srv-A none [ pins exist ]
- the sign run regenerates base.list.subroutines, subroutines.load-early
  and the module dependency graph for new \ removed modules

## open, next steps

1. **remotes [ user leads, from the 782d4de8 handover ]** : pull-git on
   srv-U, srv-A, srv-V ; on srv-A + srv-V replace the exact acme.jobsite
   grant with `zone:acme.*.<domain>` patterns, `nameserv.reload config` ;
   wait for the letsencr retry [ <= 15 min ], else
   `httpsd.reload-certificates` ; registrar records for jobsite :
   `_acme-challenge.jobsite` CNAME + `acme.jobsite` NS ; on srv-U reload cube
   config, restart web \ httpd \ httpsd \ jobsite ; mint a ui token
   [ web.auth-issue ], check the 23 jobs, one real assessment ; retire the
   old jobs vhost on srv-F
2. **todo 3W5** : stepstone WAF blocks both contabo servers -> site-yaml
   [ fetching ] on srv-V + new us nodes [ dallas, then east coast ],
   coding on srv-U \ srv-A. permanent links = host-edit records [ roles,
   link_user ] + a supervisor : ssh forward -> external.link.open ->
   reconnect with backoff ; nodes zenka reports up \ down ; resolve the old
   nodes.cmd.add-tronk path first ; unattended ssh key restricted
   [ permitopen=127.0.0.1:42 ]. good cloud-credit candidate
3. **todo Q7O** : ranking layer on hints.* [ order : ssh -G safe > two
   sources > one > match-only marker ; pins = trust check ], then wire into
   host-edit as prefilled, explained defaults
4. **todo YBX** : automatic session handovers on cache timeout [ phases in
   the item ]
5. editor audit leftovers : cosmetic only [ tiny terminals, alt-keys ]

#,,,.,,,,,,.,,,.,,,,,,.,,,,,,,.,.,...,,.,,,..,..,,...,...,...,...,...,,,.,...,
#3YGBZTUAMOPMTVVBYTJKO55XERPZT4DS3LHQQQA7KKOW6WNMKWIQKZHLVVO5C6JTDIWCHMPSF3SNO
#\\\|TCD66KYFAZ62F7HQ4A2PPYKLKXUPEJRD2NOPRUO75JFO4KUYJYL \ / AMOS7 \ YOURUM ::
#\[7]BYBGL2OG3N7YKLIP6VDSQNBTQXPMDZ4CTJM455JQEO5LJ5IDZGCQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
