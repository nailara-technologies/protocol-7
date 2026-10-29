---
name: project-2026-10-29-jobsite-live-update-chain
description: LANDED 2026-10-29 [ fc2ea1712 .. 00afc97c8, owner-confirmed 7 round trips ] : jobsite -> web -> browser live updates -- push_soon 3 s, the web's sync-soon nudge for ui deletes, SSE /jobs-events [ change signal only ], browser refresh timers ; plus the remote queue-depth and rescan-owed fixes behind WY5
metadata:
  type: project
---

**the chain [ all live on pri, owner-confirmed ]**

1. **jobsite -> web cache** : `jobsite.sync.push_soon` arms ONE debounced
   one-shot [ `jobsite.cfg.sync_soon_delay = 3` ] after rescue \ trash \
   web-side changes ; `jobsite.handler.sync-soon` re-arms while a push runs.
   `jobsite.sync.apply_reverse` pushes only when entries came back --
   `push_chunk` calls it after EVERY push [ an unconditional call looped ]
2. **ui delete -> jobsite** : the web's reverse entries ride back on the
   REPLY to jobsite's next push. `plugin.web.jobs.reverse.queue` sends
   `jobsite.sync-soon` [ fire and forget ] -- grants in cube
   `access.cmd.usr.web` AND jobsite's own `access.cmd.usr.cube`
3. **web -> browser** : `GET /jobs-events` -> `web.jobs-events`, a STRM
   stream through `httpd.handler.web-relay.strm_open` [ the radio
   pattern : base.stream.open\push, mode deferred ]. carries only
   `event: jobs` -- the browser runs its existing syncPipeline. subscribers
   keyed `sid:cmd_id`, 1 event \ s with a trailing event, `: ping` 25 s
4. **browser** [ data/web-root/vhosts/jobsite.vhost/index.html ] : events
   THROTTLE [ armed once, 1.2 s -- a resetting debounce starved under a
   backlog's event stream ] ; actions own a timer : rescue 3.1 s, delete
   4.2 s, sync button 1.2 s. each pull also reloads an open trash panel
   [ a delete left the list locally, the pull found nothing, skipped render ]

**gotchas met on the way**
- httpd routes : only the FIRST option is `key:value`, the rest `key=value`
  -- `content_type:text/event-stream` was dropped silently, EventSource
  refuses application/json
- httpd routes load in init_code ; `reload config` \ `reload init` did not
  pick up a new route -> restart httpd
- `plugin.*` needs `<zenka>.reload plugins` [ or all ], `reload source`
  skips it
- test pri loopback with `curl --noproxy '*'` [ owner : no_proxy ]
- host overlays httpd \ httpsd \ web.cfg hold web.auth.secret, root 0600 by
  design : reload config now keeps the start-up values
  [ base.load_host_config + base.reload_config skip, 00afc97c8 ]

**behind WY5 [ fetch + assessment ]**
- `jobsite.handler.queue-depth-reply` read `$call->{data}` with `// 0` :
  every REMOTE depth reply = drained 3 s after the import. now
  `base.reply.value( $call, 'int' )` [ never a default ]
- `jobsite.handler.rescan-timer` dropped a scan while assessing -> owed,
  run 30 s after the cycle turns idle [ dispatch.consume_slot ]
- first full fetch after WY5 : ~1100 queued, a hidden backlog [ the 4-page
  cap + one-id skip list scraped the surface only ]

related : [[feedback-new-module-whitelist-and-resign-version-files]],
[[feedback-route-send-buffers-timer-gets-event]],
[[feedback-reload-success-doesnt-guarantee-new-file-loaded]]

#,,.,,,,.,.,,,.,.,...,.,.,,,.,,..,,.,,.,.,,.,,..,,...,...,,..,,.,,,..,,..,..,,
#OCZJVDMBAWGJ2ORUM5XRSYCLYMC5PZQY6VVBJ3BOZUSI7QTIMPGNI5PNLTN6N2F5Y7JMEIORITXI2
#\\\|CMAURIZ35HCQ3ZCWKIIV2TSGAFITPUN53RZPO4KTLKO23VHE3E7 \ / AMOS7 \ YOURUM ::
#\[7]EKGU4NWFV75OKP575ZN7CI7H5XAPJHW64C3JZSPNR5T4K6YROSBA 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
