---
name: topic-httpd-route-arg-parsing-fix
description: httpd route-config arg parser bug + web zenka on-demand fix — LANDED commit 20bdf36ff, 2026-06-25
metadata:
  type: project
  originSessionId: 47367c65-b043-47a7-be00-11d29ff7b99d
---

`httpd.route.init_code`'s bracket-arg regex was greedy and didn't stop a
value at a comma, so `[command=web.jobs-sync,auth.required=1]` swallowed
the whole string into `command`'s value (matching the
`protocol mismatch ['cube.web.jobs-sync,auth.required=1']` error seen
live) and silently dropped `auth.required` entirely.

Fixed by switching to directive syntax `[command:value,key=value,...]`
(first pair colon-separated like `[load_modules:<modules.load>]`, rest
comma+equals) — comma-split then per-pair parse instead of one greedy
regex. Also dropped the `auth.required=1` flag from `/jobs-sync` entirely:
it called `plugin.web.auth.verify_session` directly from httpd's relay
handler, but `plugin.web.auth` is never loaded into httpd (by design,
httpd doesn't load `plugin.web.*`) — a half-finished feature from a
previous session ([[feedback-httpd-deferred-reply]] is the related "httpd
stays thin proxy" precedent), not something to complete here.

Separately: `web` zenka simply wasn't running (not in the `base` profile's
`zenki.enabled`, not manually started) — that's what caused the 502s
after the parser fix landed. Made it on-demand
(`start.on-demand = 1` in `start.cfg`, no `set_ondemand_timeout`
call = never idles out, mirroring `tile`'s setup) rather than adding it to
a profile's always-on list.

Leads into [[topic-jobsite-stray-recovery]] same session: starting `web`
on-demand exposed that `jobsite`'s periodic `/jobs-sync` push had been
silently failing, which is what surfaced the site-yaml/jobsite desync.

#,,,,,.,.,.,,,,,.,,,.,.,,,.,.,,.,,,,.,...,..,,..,,...,.,.,.,,,,,.,...,.,,,,.,,
#LUB52VQKNWPM33HPILCXTXWXI2DSSDFKLMWUALIQB2ACJUIK52YJOV2XT37RFSWBATJPL6YSUCQMM
#\\\|XAQ4FI3L6ETJDOM2NWPD54T4Y4SGNVYDO6RQSWUDMXXO3PICTFK \ / AMOS7 \ YOURUM ::
#\[7]QYUTJQXTO76T6GQX5AYFSXMDALORY3QZEXDJ7W4PM6RFORNYVYDA 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
