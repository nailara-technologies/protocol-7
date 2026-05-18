---
name: plugin-web-jobs-web-jobs-data-plugin
description: plugin.web.jobs.* for bi-directional job pipeline sync via web zenka
metadata: 
  node_type: memory
  type: project
  originSessionId: 095ef9b6-c744-46c5-bac8-4d54a2d5ce45
---

## Current State (session 33, 2026-05-19) — SYNC WIRED END-TO-END

**jobsite → httpd sync now uses clients.http.post** (non-blocking, no fork).
sync.push → sync.push_next → clients.http.post → handler.sync-response chain.
sync_url config stays as-is (http:// for now, switch to https:// + ssl_verify=>0
for self-signed when deploying to remote). LWP removed from jobsite.

## Previous state (session 32, 2026-05-18) — WORKING END-TO-END

**Working**: GET /jobs.json and POST /jobs-sync fully operational via web zenka.
Verified with curl. Cache at var_P7/web/jobs/ (web zenka owns it, not httpd).

## Route flow

httpd route registry → httpd.route.handler.web-relay → route-send to web zenka
→ web.cmd.jobs-data / web.cmd.jobs-sync → plugin.web.jobs.data/sync → SIZE reply
→ httpd.handler.web-relay.response → flush_shutdown → client

Key fix: reply handler reads params from `$reply->{'params'}` not second shift arg.
`shift // {}` was silently masking missing http_sid causing early return with no response.

## Module layout

- `plugin.web.jobs.init_code` — preloads JSON::XS + YAML::XS, creates var_P7/web/jobs/
- `plugin.web.jobs.data` — SIZE reply handler: reads web cache, returns JSON array
- `plugin.web.jobs.sync` — SIZE reply handler: merges browser/jobsite fields, writes cache
- `plugin.web.jobs.state.save` — merge browser-owned fields into a job record
- `plugin.web.jobs.state.load` — thin pass-through to jobsite.job.load_all
- `plugin.web.jobs.list` / `.stats` — utility commands

## Storage (jobsite zenka owns)

```
/var/protocol-7/jobsite/jobs/{job_id}.yaml   # one file per job
/var/protocol-7/jobsite/index.yaml           # lightweight index
```

Path always hardcoded as `var_P7 + '/jobsite'` in jobsite.job.* modules —
NOT using file.zenka_dir.data_path because modules are called cross-zenka
(from httpd context where zenka.name would be 'httpd' not 'jobsite').

## Route registry

`configuration/zenki/httpd/routes`:
```
GET   /jobs.json    plugin.web.jobs.data
POST  /jobs-sync    plugin.web.jobs.sync
```

Plugin registered in httpd start via `[base.white-list.register:'plugin.web.jobs']`
because plugin.web.* belongs to web module namespace (dep graph doesn't auto-pull
it into httpd). plugin.httpd.* work without explicit registration.

## httpd route registry (new, session 25)

`httpd.route.init_code` parses `configuration/zenki/httpd/routes` at startup.
Route 0 in route_dispatcher — checked before ACME/radio/template/static.
Format: `METHOD PATH SUBROUTINE` with ANY wildcard and prefix: prefix routes.
Context/cursor also moved here from http_post hardcoded branches.

## Merge strategy

Pipeline owns: score, score_reason, score_summary, fetched_at, status
Browser owns: stage, notes, date_applied

## Client-side sync (session 25)

- `lastNtime = 0` watermark in JS (in-memory, not localStorage)
- Full fetch on first load; `?since=lastNtime` on polls (server-side filtering NOT YET implemented)
- `pushChange(id, fields)` async POST to /jobs-sync on stage/note/date changes
- 30s auto-poll via `startPoll()`
- localStorage = reload cache only, server is source of truth

## Distributed deployment — open design question

Current: httpd + jobsite on same host → direct file reads work.
Future (separate hosts): jobsite pushes job YAML via HTTP(S) to an httpd
endpoint after each write. httpd/web zenka caches it locally. GET /jobs.json
served from cache — synchronous, no deferred reply needed.

**NOT route-send**: route-send requires both ends connected to the same cube
(existing P7 network connection). Cross-host push must use HTTP since that
link doesn't exist yet. Same sync channel as browser but from server side.

**nameserv integration**: nameserv zenka runs on remote hosts, handles service
discovery + key storage. jobsite asks nameserv for the remote httpd's public key
and endpoint → no hardcoded addresses or manually distributed keys. Zero-config:
new host registers with nameserv, existing nodes discover and trust it automatically.
HTTP is the transport; auth + discovery are fully P7-native via nameserv.
Link-upgrade can later promote the HTTP push to a native P7 connection.

## Toolbar UI (session 25)

- Two-row layout: stats+slider|manuell top, sort|export|reset+sync bottom
- Sync button: `min-width` + label span — icon stays, only text flips to '…'
- Score slider: custom webkit/moz pseudo-elements, dark track, blue glow thumb
- Buttons: 0.72rem to match filter tab visual weight (tabs stay at 0.78rem)

## Remaining work

- Server-side `?since=N` delta filtering (index.yaml needs last_modified per entry)
- ntime watermark in POST sync response
- Deploy jobs.vhost to remote server (DNS + letsencr cert install)
- When jobsite distributes: web zenka push/cache model

#,,.,,,.,,..,,...,,,.,,..,,,,,.,,...,,.,,.,.,..,,...,..,,...,,...,,,.,,,,,.,,,,

#,,.,,,.,,.,.,.,.,.,.,.,,,,,,,.,.,,,,,.,,,,,,,..,,...,...,..,,.,,,..,,.,.,,..,
#XK6LUA2Z47K4KHFYJYNV7I76FD47ZUD4TJ2KWDVBIVYHL7B2WXS2XQJX77EPND4ML3KB4SJZABDXA
#\\\|SJENJAJICHBXHQCDTQBDRJOC5DQMMEV2U2O2YQXT56GBDKXDN6Y \ / AMOS7 \ YOURUM ::
#\[7]2MBUNOCXVVMPTSDOCJNLKCP54AWBOE6QHZY4KLU4Z4RNI2HO5SDA 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
