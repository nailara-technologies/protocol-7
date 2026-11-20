---
name: project-2026-11-05-session-handover-headless-design
description: START HERE 2026-11-05 [ bf926a491, pushed + pulled on all four ] : login-screen transition modes, headless X-11 \ console hardening \ host-admin log design ; open : devmod-ack, editor fixes
metadata:
  type: project
---

session 2026-11-05 [ follows [[project-2026-11-05-session-handover-transport-claims]] ] : 2 commits,
pushed to `hub`, pulled on srv-U F V A [ no stash needed any more ]. v7-zenki + cube
`reload source` on all four [ success ] : 2b73d5537 + 0d60550d7 active, no restarts.

**done**
- devmod* markers deleted on srv-V F A [ 23 each ] ; 0d60550d7 keeps them from coming back.
- the previous handover's "s2c \ s2b uncommitted" was stale : already in f767bb1cf \ 0f351474a.
- fcdd0b7bd login-screen.lock.transition = fade | snapshot-fade [ default ] | image
  [ + login-screen.lock.image ] : kimi K3.1 low implemented it [ ~1 task ], review found image mode
  covered by the 0.995 dark backdrop -> image mode now fades the image in, backdrop stays clear.
  known gap : unlock in image mode clears the image at once instead of dissolving. real-display check
  of image mode still open.
- bf926a491 data/md/design/HEADLESS-X11-AND-HOST-ADMINISTRATION.md [ design only ] : auto-xvfb + even \ odd
  display numbers by role [ even = host \ parent, odd = child ; lock-file retry ], xvnc admin sessions over
  ssh, provider-console X opt-in [ lowram start set ], vt-switching rules [ locked, on at any failure or
  repeated failed logins + security log entry ], intended sysrq \ getty \ grub \ login surface
  [ motd + pam_motd 10-uname + agetty hostname + DebianBanner ], check-console audit, xz backup + one-command
  restore, /var/protocol-7/host-admin log [ v7-zenki writer -> later host-admin zenka owns it ],
  append-only /var/protocol-7/forensics/security-log [ forensics zenka anchors chain heads ; never
  p7-log compaction ]. section 5 = proposed build order.
- owner decisions in that doc : /var/log/protocol-7 is p7-log's alone ; bolder automatic decisions only
  when logged with their detection + one-command undo exists ; irreversible \ access-cutting stays a question.

**open, in order**
1. devmod-ack [ design ] : '. weather . send.local: unknown target : cube [ cmd : v7-zenki.devmod-ack ]'
   -- devmod requests WITHOUT network ; current version races + is noisy everywhere.
2. owner's editor fixes [ separate topic ] -- includes issues of the todo list command itself.
3. powershell exit 0110 [ CLOSED, follow-up session ] : NOT an overlap. 5567aa7fa [ 11-04 23:17, cube
   socket non-blocking after auth ] broke its blocking whoami read ; 9220834b9 [ 00:18 ] restored it.
   failures 23:29 .. 00:11 exactly in that window. max_concurrency = 1 kept anyway.
- invoke-web queue watch : 'database is locked' = invoke.ai holding the sqlite write lock past the 500 ms
  busy timeout ; now an expected retry [ level 2, loud after 5 in a row ].
- not changed yet on servers : motd on srv-V [ provider template ] and srv-A [ owner's art, leave ] ;
  pam_motd 10-uname active on all four -- belongs to the console plan apply, not by hand.
- watch : delta link heartbeat timeouts ; srv-A models 'subscribe refused' towards external.pri.task.

#,,..,,,.,,.,,..,,.,.,.,.,,,.,,,.,..,,..,,,..,..,,...,...,.,.,,,.,..,,,,,,...,
#WEINTVY6QKRR3Z66PQYT7V76DWNDIRV5QITMSTD7SI2NNXNE7RPAIDH3GHZEIEVX4MLPZHGXM4YEU
#\\\|P4SI2H5ULKYVYLQQBN53R526ZKOVNYXMD3VBQVIVI2QW5HHJGRP \ / AMOS7 \ YOURUM ::
#\[7]AH3CWAIKNUFRRRVAA4NS2XFJBAVQLMHSWS66YJRP6PHQ32BEGAAQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
