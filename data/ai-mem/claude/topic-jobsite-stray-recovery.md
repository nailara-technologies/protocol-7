---
name: topic-jobsite-stray-recovery
description: jobsite/site-yaml cross-zenka stray-job recovery feature — LANDED commit a52a6a4b8, 2026-06-25
metadata:
  type: project
  originSessionId: 47367c65-b043-47a7-be00-11d29ff7b99d
---

## what landed (commit a52a6a4b8)

Root cause chain this session: httpd route-arg parser bug (comma-swallowing)
→ unfinished browser-auth gate on /jobs-sync → `web` zenka never started
(now on-demand) → site-yaml running stale pre-fix code wrote 367 job files
under its own var dir instead of jobsite's canonical store (desync) →
jobsite's assessment dispatcher never saw them since they weren't in its
own store, even after files were recovered, since recovery and dispatch
are separate steps.

**Generic recovery primitive** (reusable pattern, see
[[feedback-no-unsolicited-cross-zenka-push]] for the why):
- `site-yaml.job.scan_stray` — builds manifest, id = AMOS checksum over
  `size:ntime`, collision-chained as `id:size:ntime` re-hash (per user
  spec, matches `amos-chksum 'A5MOLSQ:<size>:<ntime>'` CLI demo). Caches
  id→{name,status} in `<site-yaml.stray_manifest>` so a later fetch-by-id
  is a lookup not a recompute.
- `site-yaml.cmd.list-stray-jobs` — passive read-only manifest export.
- `site-yaml.cmd.export-stray-job` / `confirm-stray-claimed` — per-item
  pull + delete-on-confirm.
- `jobsite.stray.check` (fired 2s after jobsite's own init, also re-fires
  on every `jobsite.reload init`) — polls configured zenki
  (`jobsite.cfg.stray_check_targets`, default `site-yaml`).
- `jobsite.handler.stray-jobs-listed` / `stray-job-exported` — claim queue,
  sequential one-item-per-route-send (see
  [[feedback-p7-route-send-wire-protocol]] for why sequential, not batched).
- `jobsite.stray.claim_next`'s drain branch now calls
  `jobsite.dispatch.assessments` automatically — closes the gap where
  recovered jobs sat at status=new but nothing told the assessment
  dispatcher to look.

**Cross-zenka access wiring needed for this**: both
`cube/access.zenki` (`access.cmd.usr.jobsite` listing site-yaml commands)
AND `site-yaml/start`'s own `access.cmd.usr.cube` (listing the same
commands again) — see [[feedback-p7-route-send-wire-protocol]].

## verified end-to-end
922 → 1289 jobs after recovery; `jobsite.status` showed `cycle=assessing`,
`new=361` draining as coding zenka processed them. Confirmed via real
timestamped log evidence (lazy-load line for the called module), not
assumption — file-mtime-unchanged is NOT proof a no-op poll didn't run.

## open / not done
- `jobsite.cfg.stray_check_targets` currently hardcoded default
  `site-yaml`; fine for now, no other zenka uses this pattern yet.
- The repeated "loading p7-source : <module>" lazy-reload-on-every-call
  noise (separate pre-existing issue, user flagged as known/separate,
  not fixed this session).

#,,,,,,..,.,,,,,.,.,,,.,,,,.,,.,.,,,.,..,,,,.,..,,...,...,.,.,,,,,...,.,,,,.,,
#GJUOQPDSCZDYFLAXKU6PA5OFUZUPFP6QIUKQAOPVTGIWMP4S26ZDBSBQT63NFFDR7X4EJNDNAA4Z6
#\\\|MYVSR4TCXC4A4GK2M3XANVBCJR5FUZWEOKPQMB4XVJTXAGQC22Z \ / AMOS7 \ YOURUM ::
#\[7]IEIWQECG5HVZVTFHSBIB7HR5T42J6BT4PX7K6GLXA3UBRPDD5YAA 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
