---
name: plugin-web-jobs-web-jobs-data-plugin
description: plugin.web.jobs.* for bi-directional job pipeline sync via web zenka
metadata: 
  node_type: memory
  type: project
  originSessionId: 095ef9b6-c744-46c5-bac8-4d54a2d5ce45
---

## Current State (session 25, 2026-05-15)

**Working**: GET /jobs.json and POST /jobs-sync served by httpd directly via
route registry. Direct file reads from /var/protocol-7/jobsite/jobs/ — correct
for single-server deployment where httpd and jobsite share a host.

## Module layout

- `plugin.web.jobs.init_code` — preloads JSON::XS + YAML::XS once at startup (no per-call autoload)
- `plugin.web.jobs.data` — GET handler: reads jobsite YAML files, encodes JSON, writes to session buffer
- `plugin.web.jobs.sync` — POST handler: reads session input buffer, merges browser fields, calls jobsite.job.write
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

#,,,,,.,,,...,,.,,..,,.,,,,.,,,.,,,,.,.,.,,.,,..,,...,..,,,,.,,.,,,..,.,.,.,.,
#XRWB66C4KKEACPEAWRCQBLPTQR5DQJC5JUPD7ERMD2CMX7QERZC4ETMRRL5NGDRAISY3GICIGPQR6
#\\\|3QGBGDCTQEFDRIXQWKKESA3QBFFZSN4RUGJ4MGS4KXEAR422QZU \ / AMOS7 \ YOURUM ::
#\[7]HO5QPIJIQ5GBXZL6TVTHBZ7MBQY4AR2IO775RADE2NPIOSRGV4BY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
