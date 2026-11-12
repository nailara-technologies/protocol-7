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

commits dc11284dd 0351433f7 743009ce7 7b0d6efbe 2850a90ef. srv-A got its first cert
[ add-vhost + request-certificate ] ; an old employer vhost removed on srv-F.
kimi K2.8 Preview [ 50 % rate ] did the first draft : 7d +1 \ 5h +2, good quality.
test harness : scratchpad certtest/run.pl [ openssl -not_after certs, stubs ].

TO CONFIRM [ 2026-11-13 ] : on each host events.show-buffer shows letsencr.renew sent at
the jittered time, no 'no perm.' in the cube log, letsencr exited on its idle timeout.
open : srv-U's postponed cert issue ; letsencr status 'parseable' section unused yet ;
httpsd.wait_for_certificate has no caller. [[n7fs-first-live-round]]

#,,,,,,..,,,.,,,.,.,,,.,,,,.,,...,..,,...,.,.,..,,...,...,,..,...,..,,..,,,,.,
#7SAUSGNYH4WXEAS6IYGGN5MYZU3JBH45XC7N72HXCULBFMB3ZXPNL3CJPX55XKUBOWQSB2RABAVZU
#\\\|JL37YR7ZG77MA6Y3B3GW52W4HAKM62Y6XUGDQKI26ZCNLHBTJRJ \ / AMOS7 \ YOURUM ::
#\[7]5VNLC2ABT74ZJZKVUS63ZEQDJUJGSR672VOGM7VZ6RFOVMU4Z4CY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
