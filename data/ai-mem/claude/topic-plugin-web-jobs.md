---
name: plugin.web.jobs — web jobs data plugin
description: plugin.web.jobs.* for bi-directional job pipeline sync via web zenka
type: project
originSessionId: 5557aaa4-3476-4c66-9002-955c73ae92a1
---
## Design

Replaces manual `bin/dev/export-jobs-json` + scp with a proper plugin that:
- serves jobs JSON to the browser interface (GET)
- accepts browser state updates (POST sync)
- is the single source of truth shared by job-site-scan and the web interface
- creates B32 ntime-stamped backups on every write

## Storage layout

```
/var/protocol-7/web/jobs-data/store.yaml          # live state
/var/protocol-7/web/jobs-data/store.NTIME_B32.yaml # rolling backups (one per write)
/etc/protocol-7/web/jobs-data/config.yaml          # threshold, categories, profile path
```

Uses zenka_dir routines for both paths. Backup created before every write —
no separate daemon, no cron, just atomic snap-then-write.

## Plugin modules

- `plugin.web.jobs.init_code` — load state at startup, register template commands
- `plugin.web.jobs.state.load` — zenka_dir load from /var/
- `plugin.web.jobs.state.save` — save + B32 ntime backup of prior state
- `plugin.web.jobs.handler.get` — GET endpoint: render store as jobs JSON
- `plugin.web.jobs.handler.sync` — POST endpoint: receive browser delta,
  merge into store, save, optionally notify job-site-scan of stage changes

## Merge strategy — two authoritative domains

Pipeline owns (job-site-scan writes, browser reads):
  score, score_reason, score_summary, fetched_at

Browser owns (browser writes via sync, pipeline reads):
  stage, notes, date_applied, manual entries

Conflict resolution: latest ntime timestamp wins per field.
Both sides write their own fields; neither overwrites the other's domain.

## Bi-directional flow

Assessment completes:
  job-site-scan → plugin.web.jobs.state.save → GET endpoint serves updated JSON

Browser status change (applied, rejected, notes):
  POST /jobs-sync → plugin.web.jobs.handler.sync → merge → save → notify job-site-scan

## Template integration

Web zenka template commands registered by init_code:
  <[web.jobs.data]>     — returns jobs JSON for inline embedding or as endpoint
  <[web.jobs.stats]>    — summary counts per stage (reuses existing jobs.html.tmpl cmd)
  <[web.jobs.sync]>     — handles POST body, returns merge result

## Replaces

- `bin/dev/export-jobs-json` — export script
- manual scp to atom
- localStorage as primary state (becomes cache/override layer only)
- `data/web-root/vhosts/jobs.vhost/` static jobs.json file

## Connection to existing infrastructure

- Follows `plugin.web.space.*` pattern (space.v7.ax already uses this)
- job-site-scan assess-done writes through plugin instead of direct YAML::XS
- jobs.vhost index.html fetches /jobs.json from web zenka endpoint
- B32 backup naming uses `<[base.ntime.b32]>` — same as task/event timestamps

#,,.,,,..,,,,,,,.,,..,,,,,.,,,...,.,,,,..,..,,..,,...,...,...,.,.,,.,,..,,...,
#W33QBIIIMDBFMKRCPGAE7SOLRF5N56VS7AJQEE2UVSR75C652EHOWXHTWLAMYQ3B6KMK43XOZRTRK
#\\\|EGZ2GIPQAEVZYPJO4YFZYNHEMTYXSDAWVOKRG5GV4HAQY6X6G2S \ / AMOS7 \ YOURUM ::
#\[7]2URHGCAN6KHHS2FEN3QPS74NHB7N6HZHIUS2F3MMQXDXJ4PMPUCY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
