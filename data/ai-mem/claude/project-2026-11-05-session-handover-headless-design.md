---
name: project-2026-11-05-session-handover-headless-design
description: START HERE 2026-11-05 [ 4802120dd, pushed + pulled on all four ] : login-screen transition modes, headless X-11 \ console hardening \ host-admin log design ; open : devmod-ack, editor fixes
metadata:
  type: project
---

session 2026-11-05 [ follows [[project-2026-11-05-session-handover-transport-claims]] ] : 2 commits,
pushed to `hub`, pulled on srv-U F V A [ no stash needed any more ]. v7-zenki + cube
`reload source` on all four [ success ] : a15de54fd + 485d04329 active, no restarts.

**done**
- devmod* markers deleted on srv-V F A [ 23 each ] ; 485d04329 keeps them from coming back.
- the previous handover's "s2c \ s2b uncommitted" was stale : already in 31cf98d19 \ 11990e9b1.
- aa24edb87 login-screen.lock.transition = fade | snapshot-fade [ default ] | image
  [ + login-screen.lock.image ] : kimi K3.1 low implemented it [ ~1 task ], review found image mode
  covered by the 0.995 dark backdrop -> image mode now fades the image in, backdrop stays clear.
  known gap : unlock in image mode clears the image at once instead of dissolving. real-display check
  of image mode still open.
- 4802120dd data/md/design/HEADLESS-X11-AND-HOST-ADMINISTRATION.md [ design only ] : auto-xvfb + even \ odd
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
3. powershell on-demand start overlap [ local ] : '. powershell . base.get_session_id: socket exception'
   -- NOT the non-blocking transport [ reads stay blocking ]. cube logged 'ondemand start-up of powershell
   zenka not successful [ status=error ]', a second session key + pid followed, an older powershell got
   signal 9 : the losing instance lost its cube link mid-whoami, exit 0110. open : which request caused
   the overlap, why the first start was marked error.
- invoke-web queue watch : 'database is locked' = invoke.ai holding the sqlite write lock past the 500 ms
  busy timeout ; now an expected retry [ level 2, loud after 5 in a row ].
- not changed yet on servers : motd on srv-V [ provider template ] and srv-A [ owner's art, leave ] ;
  pam_motd 10-uname active on all four -- belongs to the console plan apply, not by hand.
- watch : delta link heartbeat timeouts ; srv-A models 'subscribe refused' towards external.pri.task.

#,,,.,,..,.,,,...,,,.,,.,,.,.,...,,..,,,.,,,,,..,,...,...,.,.,,,.,,,,,...,,,,,
#JSSBOJNMJOA4RN37YNHULFG3M5DNCCLC3RYNFWZJDLBS2NFP2AXPH56Y3AWFJRYFSV7LFR75FKU36
#\\\|CAEQ6Z7EKH44IZI7XFX6HMN6LG26XRBLAYT644GG6WFX3QBGU7H \ / AMOS7 \ YOURUM ::
#\[7]LHACAFCQJOZU7SXLVQR7PHHJHISLXW4DL7VRRJQAPQGSQUFXYSBI 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
