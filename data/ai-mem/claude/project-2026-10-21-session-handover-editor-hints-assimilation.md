---
name: project-2026-10-21-session-handover-editor-hints-assimilation
description: START HERE -- session 2026-10-21 handover [ last b892e2707 ] : shared editor hardened end to end, coding model-pin hang fixed, hints.* detection layer [ 4 sources ], managed-abstraction principle, assimilation design ; open : nameserv \ letsencr steps on the remotes, remote links [ 3W5 ], ranking layer [ Q7O ]
metadata:
  type: project
---

previous : [[project-2026-10-18-session-handover-n7fs-truth-pri]]. the
nameserv \ letsencr \ web-auth session in between [ claude 782d4de8 ] wrote
no handover -- its open steps are below [ from a session_catchup summary ].
budget at the end : claude 7d low [ fresh window ], kimi 7d ~98 % [ resets
2026-10-21 evening ], cloud credits ~$55 [ expire 2026-11-05 ].

## landed [ pushed up to a0cad6995 ; b892e2707 not yet pushed at writing ]

- **AMOS7::TERM::Editor** [ todo + p7-vault share it ] :
  - c1035a538 characters end to end : utf-8 key assembly ; review fixed a
    lone latin-1 byte swallowing the next keys + single-slot pushback
  - dc221d40c resilience [ kimi audit, pty-reproduced ] : EINTR retry
    [ resize cut pastes into keystrokes ], lost tty = EIO -> abort [ was
    100 % cpu spin ], TSTP \ CONT [ STOP inside the handler ], cursor shape
    on every exit ; bin/test-scripts/test-term-editor-pty.pl [ 13 ]
  - 37b8c9e3e ctrl-s saves through `on_save` [ ctrl-o alias ] ; todo writes
    via the ctrl-x path ; p7-vault deliberately WITHOUT on_save [ new notes
    have no id, edits save all fields at once ] ; todo's SIGINT message ran
    on the success path since before 2026-08
  - 290e00653 a literal "\e[201~" inside pasted text stays content
    [ terminator only ends a paste when nothing more is pending ]
- **coding zenka** 7cf4d9c98 : a content-only pin `:model::<content>:` for
  a model not loaded stayed unresolved, switch-model refused it BY REPLY,
  the in-flight flag stuck -> tasks parked forever [ hung every
  session_catchup ]. registry fallback in coding.mode.local_model_id ; a
  refusal fails the task. regression from e9bca5fe9
- **hints.\*** [ d83925614, a0cad6995, b892e2707 ] : candidates with their
  source for host records -- ssh_config [ Include conditional, %h, Match
  skipped + `shadowed_by_match` only when an EARLIER Match sets the
  keyword ], etc_hosts, known_hosts [ hashed entries, @revoked = conflict,
  corroboration only ], server_pins [ file names only ]. sanity + candidate
  + conflicts. tests test-hints 39, test-hints-sources 29. NOT wired into
  any zenka yet
- **principle** [[managed-abstraction]] [ e8b622ae5 ] : layers settle what
  they can know, the user enters only where a decision remains ; context
  ranks options ; inference zenki get a clean context + a refined
  situational summary ; identity \ memory as continuation
- **assimilation** : data/md/design/ASSIMILATION-DEPTHS.md [ b892e2707 ] --
  file- \ setup- \ key-import, depths 0 observe .. 4 host, "a source goes
  away by default only when getting it back is proven", hybrid links
  reflink > hardlink > symlink. the sourcecode checksum-symlink pair was
  REMOVED [ non-functional ; last in a0cad6995 ]

## verified facts worth keeping

- `ssh -G` RUNS `Match exec` commands [ OpenSSH 10.5p1, fixture test ] --
  use -G as a source only on configs without Match exec
- host-edit add-host works live over ssh : atom record saved with
  transports ssh, `done : pinned` [ key TWVQ6QL ]. records : atom [ no roles
  \ link_user ], pri [ name + ssh only ] ; delta \ yourum none [ pins exist ]
- the sign run regenerates base.list.subroutines, subroutines.load-early
  and the module dependency graph for new \ removed modules

## open, next steps

1. **remotes [ user leads, from the 782d4de8 handover ]** : pull-git on
   pri, yourum, delta ; on yourum + delta replace the exact acme.jobsite
   grant with `zone:acme.*.<domain>` patterns, `nameserv.reload config` ;
   wait for the letsencr retry [ <= 15 min ], else
   `httpsd.reload-certificates` ; registrar records for jobsite :
   `_acme-challenge.jobsite` CNAME + `acme.jobsite` NS ; on pri reload cube
   config, restart web \ httpd \ httpsd \ jobsite ; mint a ui token
   [ web.auth-issue ], check the 23 jobs, one real assessment ; retire the
   old jobs vhost on atom
2. **todo 3W5** : stepstone WAF blocks both contabo servers -> site-yaml
   [ fetching ] on delta + new us nodes [ dallas, then east coast ],
   coding on pri \ yourum. permanent links = host-edit records [ roles,
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

#,,..,,.,,.,.,..,,.,.,...,,,.,,,.,,..,,,.,...,..,,...,...,..,,,.,,,,,,,,,,,..,
#BP3FQ4YUSU6TKMPN3G6756E6FND3IITAF2BIGYM2I6WK6OBRIIO65RDX4B6S4MIU3PMUJQKKNJTFY
#\\\|KO4DTPNFWXZWAHFHTMEMRH2PCSXXIC76FUJLX6ONAX7FSGQ2YHT \ / AMOS7 \ YOURUM ::
#\[7]BB5IORR7CDNXQ752LWWEEMDFW23H7UBPDGJHCM3H6G2ZD5J3VGCI 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
