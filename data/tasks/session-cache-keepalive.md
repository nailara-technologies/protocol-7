# session cache keep-alive + sensible reset notices

status : PART 2 BUILT 2026-11-27 -- narrowed owner-agreed scope, not loaded live.

## why

a claude session's prompt cache lives one hour. a session waiting on something [ a sign
approval waited 2 h on 2026-11-27, a kimi run, a background wait ] loses its cache unless
something wakes it ; today only usage window reset notices arrive, timed by the provider's
window, not by the cache -- and they also arrive for windows nobody used.

## part 1 : reset notices only when they mean something

- `usage.window.reset` carries `activity` = used \ idle \ unknown [ usage.watch.observe,
  usage.handler.window_reset ]. cfg/zenki/events/notify.map : `.idle` = level none, but
  `unknown` falls through to the full notice -- fail open. on 2026-11-27 an unused kimi
  window still announced its reset. check the events log for the activity of those signals.
- wanted : `unknown` = no session notice [ log line only ] ; a notice to a session only when
  the window was used AND the session was held back by it [ a limit hit, a deferred dispatch ].
  whether 'held back' is recorded today : find out, else used = notice as now.

## part 2 : cache keep-alive [ an events plugin ]

- intent, not polling : a keep-alive goes to a session only while it has something OPEN
  [ a pending sign job, a running kimi \ claude dispatch, a registered background wait ].
  nothing open = silent, the cache may expire.
- rhythm : ~54 min after the session's LAST activity [ any real message resets it ], from
  base.interval.next with a type [ eg. `session-cache-keepalive` ] -- not the clock hour.
- one notice : `cache keep-alive : still waiting on <what>`, to=session, sound none.
- source of 'open' : the mcp server knows sign jobs and dispatches ; background waits
  [ bin/dev/p7-sign-wait ] register and unregister themselves with events. find the existing
  session registry [ notify `to=session`, the live session record ] and extend it -- no
  second registry.
- a plugin : plugin.events.cache-keepalive.* , one narrow hook, off = not loaded, nothing else
  changes [ principles : data/tasks/claim-lease-and-quiet-retries.md ].

## rules for the implementer

no sha, no json internally ; lowercase comments with [ ] brackets ; perl floor 5.32 ;
bin/format-code -c for every changed src file ; new commands need their zenka.v7 list,
gen-sub-whitelist and access entries ; no commit, no sign, no reload ; never touch files you
did not change, no git restore.

## findings [ kimi ]

part 1 is changed : `notify.on.usage.window.reset.unknown = level=none`. the used rule
stays as it was. `/var/protocol-7/events/signal.journal` records today's kimi resets at
00:15:34 without an `activity` field, and at 05:15:38 and 10:15:36 with `activity=-`
[ the journal encoding of an empty value ] ; none carries literal `activity=unknown`.
the running usage zenka therefore predates the current source's used \ idle \ unknown
classification, or has not supplied it on those paths. no reload was done.

'held back by the limit' is not recorded for a session. the usage state has readings,
reset epochs and requery counts only. the mcp server has no usage-limit dispatch deferral
state ; its `deferred` replies are command \ wait plumbing. `events.notify.apply` uses
'held back' only for its own repeat-rate-limited cues, unrelated to provider limits.
consequently `activity=used` keeps the existing notice behavior ; no hold detector was
invented.

### part 2 stopped at the open-work ownership choice

- the reusable session registry is `coding.sessions.store` : activity, stable sid, type,
  dispatch count and the existing free-form `pending` marker. `bin/mcp-server-p7` already
  reports to it through `coding.session-touch` [ `_session_report` ], and its
  `_session_dispatch_count` covers this server's live kimi workers and claude runs.
- the separate `claude.live.sessions` closure is only the inbox socket \ token registry.
  `events.notify.send` asks `claude.sessions`, then `events.handler.notify_sessions`
  targets `claude.session-post`. duplicating activity or open work there would split the
  session state ; the coding registry is the one to extend.
- a p7_sign job is double-forked and survives its mcp server. the server returns only its
  id and later reads that job's state file ; it keeps no in-memory sign-job ownership map.
  `bin/dev/p7-sign-wait` only polls that state and currently registers nothing. thus a
  sign job cannot yet be attributed safely to a session after an mcp restart.
- `coding.keepalive.*` already has a 54-minute rhythm, but it is an opt-in switch with a
  six-message cutoff and a request for an answer. its pending source mixes global sign
  queue and reminder state into every session, so it is not the requested per-session,
  open-work-only notice and should not be silently repurposed.

### concrete proposal

extend the existing coding session record with keyed open-work items, for example
`open.dispatch.<id>` and `open.wait.<id>` [ descriptions only, no tokens ]. add a narrow
state-report path alongside `session-touch` : mcp dispatch start \ finish updates its own
session's dispatch items ; `p7-sign-wait` registers its job with the session name \ sid at
start and removes it in an exit guard. that wait registration is the durable ownership
handoff for an orphaned sign job, rather than scanning all state files and guessing an
owner. a final status read can clear an item early, but clearing must match both session
sid and item id.

load `plugin.events.cache-keepalive.*` only as an events feature. its single core hook
obtains the due session state from the coding registry through a narrow query command
[ with the required zenka.v7, generated-subroutine whitelist and access entries ] ; it
does not copy the records into events. when a record has open items and its real
`last` activity is at least the returned delay old, send exactly
`cache keep-alive : still waiting on <what>` with `to=session:<resolved name>` and
`sound=none`, through `events.notify.send`. arm the next timer from
`base.interval.next` type `session-cache-keepalive`, configured at 54 minutes, anchored
to `last` ; activity and open-work changes re-arm it. no open items means no timer and no
notice. keep this independent of the opt-in `coding.keepalive.*` switch until the owner
chooses whether that older mechanism is replaced.

## implementation status [ 2026-11-27 ]

- `coding.session-open` stores only `open.dispatch.<id>` and `open.wait.<id>`
  descriptions in the existing registry. updates and clears require the session sid and
  item id. the mcp server reports its local kimi \ claude dispatch start and finish ;
  `p7-sign-wait` registers sign jobs only and clears them in an exit-status-preserving
  guard. no other open-work source was added.
- the loaded events feature queries `coding.session-cache-keepalive`, keeps no session
  copy, sends the agreed silent notice and re-arms from `session-cache-keepalive` at 54
  minutes. activity and item changes re-arm ; no open items leaves no timer. command,
  access and generated whitelist entries are included. `coding.keepalive.*` is unchanged.
- focused existing-script tests cover persistence, sid-matched clearing, one-query
  delivery, timer removal and sign-wait registration. no commit, sign or reload was done ;
  live `<zenka>.commands` verification therefore remains for the later reload.

#,,,.,,..,.,.,,,.,,.,,.,.,.,,,.,,,...,.,.,,,,,..,,...,...,,..,,,,,,,.,,,.,..,,
#2GK57N6E2XRRFCJIQYSUNHK2VHVPQV4GADOCGM35J3IDPNPC44WX5WZECBB2NTMZWWTNYEEGI2VN6
#\\\|LAZW3KVXQOUIJ6IZWMC4NX4V2B5TFRBXLYNB7YEQU6H65PBG25O \ / AMOS7 \ YOURUM ::
#\[7]FNJCHAICGO3MOCDJG5M45QE56VCBJ2F4MCUOLVCLGWGW3OFJVSCY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
