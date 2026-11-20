---
name: cert-watch-daily-renew
description: 2026-11-12 letsencr daily renew + httpsd cert_watch live on srv-V U A F ; confirm the first nightly renew ; open items
metadata:
  type: project
---

2026-11-12 : the hourly 'letsencr-renewal' event was a watchdog workaround [ zenka-present
start_once, letsencr has restart.disabled ]. replaced, deployed on srv-V srv-U srv-A srv-F :

- letsencr : renew \ force-renew commands [ were whitelisted, never existed ],
  check-interval 3900, idle exit 1300 held during renewals [ renewal_idle_hold \ release ]
- events : letsencr-renewal = daily send-command letsencr.renew 04:31:07, jitter 780 harmonic
- httpsd.cert_watch.* : per vhost like SNI [ exact, parent, else default ] ; states
  ok \ margin [ 21 d ] \ expired \ missing \ default ; interval 3900 -> 1300 -> 433 floor ;
  renew via zenka.push [ queue_max 1 ] ; a missing default cert only asks when a real
  domain exists ; first check after 0 [ post drop_privs ] ; 'httpsd.list certificates'
- cube grants : httpsd + events letsencr.renew, httpsd request-certificate + notify_online
  [ missed at first : srv-A cube logged 'no perm.' ]
- fixed : httpsd.request_certificate_from_letsencr sent a module name via send.local

commits e8308df02 9e50c0c9b d3975d7dd b0225c668 999ec1596. srv-A got its first cert
[ add-vhost + request-certificate ] ; an old employer vhost removed on srv-F.
kimi K2.8 Preview [ 50 % rate ] did the first draft : 7d +1 \ 5h +2, good quality.
test harness : scratchpad certtest/run.pl [ openssl -not_after certs, stubs ].

CONFIRMED 2026-11-13 : first nightly renew sent on all 4 [ starts 04:39 - 04:44 ], 0 needed,
no 'no perm.' in any cube log, letsencr gone by 05:01 - 05:10 [ 'present letsencr' gives last seen ].
first REAL renew due ~2026-11-20 on srv-U [ exp 2026-12-20 ] + srv-F [ exp 2026-12-21 ] : check it then.
open : srv-U's postponed cert issue ; letsencr status 'parseable' section unused yet ;
httpsd.wait_for_certificate has no caller. [[n7fs-first-live-round]]

#,,.,,,,.,,,,,,..,.,,,...,...,,,,,.,.,.,,,,..,..,,...,...,..,,...,,,,,.,,,,.,,
#W336FRHSNHNIYUNFKISSWRZYUQPJYMC26G4WUAB2KLG3AX32XUI6QYDFPHXLUUZN4UI3DPA67LCCC
#\\\|PX7F62OIQT6CBIMT5AXNZSWQJLDP2QJ4EMGHBONE6SD27Q7SOOE \ / AMOS7 \ YOURUM ::
#\[7]J2MKZZJOROA4OGU4ACTAEVU2AFBRDO7R2HL7JRHBE3J6JJATPABA 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
