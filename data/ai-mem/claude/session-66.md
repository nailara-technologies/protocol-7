---
name: session-66
description: "delta sync /jobs.json, browser UI polish, sort NaN fix, double-plugin-load fix, inline sub extraction"
metadata:
  type: project
  originSessionId: session-66
---

## commits this session

- `088222331` — feat: jobs delta sync + browser UI polish
- `5fc01f160` — refactor: extract inline _synthetic_zenka_node sub to own module
- `c2bb7fc1a` — fix: exclude plugin.* from source reload pass in base.cmd.reload

## delta sync (/jobs.json) — DONE ✓

three bugs fixed to get working:

1. **call_args key doesn't travel over route-send wire** — only `args` field is
   serialized into the command string (`base.protocol-7.command.send.local` line 116).
   fix: pass query string as `$cmd_args = length($body) ? $body : $query_str` in
   `httpd.route.handler.web-relay`; GET handlers get query string as args.

2. **ntime `gt` string comparison** in `plugin.web.jobs.sync` reverse queue filter —
   `encode_b32r` is reverse-byte-order; replaced with `base.ntime_BASE32_to_numerical`
   numerical comparison.

3. **`lastNtime > 0` in browser JS** — after first sync, `lastNtime` is a B32 string;
   `"3TBL..." > 0` coerces to `NaN > 0 = false`, `?since=` was never sent.
   fix: changed to truthy check `lastNtime ? ... : ...`.

server: `plugin.web.jobs.data` now parses `since=<B32>` from args, filters by
`last_modified > since_num` via `base.ntime_BASE32_to_numerical`, returns
`{jobs: [...], ntime: "..."}` wrapped format. `base.ntime.b32` for current ntime.

## browser UI polish (jobs vhost) — all DONE ✓

- title renamed `application tracker` (harmony TRUE), color `#60a8d0`
- button text `#7898b8` / hover `#a0c4de` (was near-white `rgba(224,255,255,0.85)`)
- `.btn-note-toggle` quiet blue, renamed label `note` (harmony TRUE; "notiz" FALSE)
- card hover: `.card-summary`/`.card-reason`/`.card-note-preview` lift ~12% toward
  neon blue (`#5a8cac` / `#6496b2` / `#5a8aaa`), 0.25s transition
- title link: `text-decoration: none` on hover, `transition: color 0.15s`
- score slider: default 7, persisted in localStorage (`minScore` added to saveCache),
  inverted direction (left=10/strict, right=0/open), diamond knob 6×6px rotated 45°,
  value label left of track, color `#8cb4f0`
- slider bug: `minScoreInput.addEventListener('input')` was not calling `saveCache()` —
  added; `loadCache()` now restores `minScore` and syncs slider + label in init

## sort NaN fix — DONE ✓

366 web cache files had `score: ''`; `parseFloat('')` = NaN; NaN in comparator
poisons entire sort. fix: `isFinite(parseFloat(v))` guard + `fetched_at` tiebreaker.

## inline sub extraction — DONE ✓

`plugin.web.space.orbital.json.context` had inline `sub _synthetic_zenka_node`
(lines 34–70); loaded by both reload-source and reload-plugins → redefined warning.
extracted to `src/plugin.web.space.orbital.synthetic-zenka-node`, added to
web zenka whitelist (`cfg/zenki/web/subroutines.load-early`).

## double-plugin-load fix — DONE ✓

`base.cmd.reload` `arg=all` path: `base.clear_p7_mods` returns ALL loaded modules
including `plugin.*`; `base.load_modules` loaded them during source stage, then
`base.reload_plugins` loaded them again. fix: one-line grep filter in `base.cmd.reload`
line 57: `grep { $ARG !~ m{^plugin\.} } <[base.clear_p7_mods]>`. `web.reload` now
all 5 stages clean with no warnings.

## related
- [[session-65]] — data recovery, scan started
- [[plugin-web-jobs]] — sync pipeline

#,,..,,.,,..,,...,,.,,,,.,,,,,,.,,.,.,,,.,,,,,..,,...,..,,.,.,...,..,,.,.,,,,,
#SCYEENAYB5CJTE3RCIOA3TJ5ERUVQXUOQNAFMOKQFSE2BKEJI5XHDGX6VGKZ3GZWISBJ4PPQMH7BC
#\\\|REZ6JQAG2WJ4XS4ORCOV3YAKYVKTEKMIPHAXPBI2FODJEU7FC3X \ / AMOS7 \ YOURUM ::
#\[7]QINYDMHXNKFZ3AYVQUXFPD76SHKRXQFBG5BPI5GCRE5JJQ3XNCBI 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
