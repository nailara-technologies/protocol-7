# Test: plugin.web.jobs.* endpoint migration to web zenka

The plugin.web.jobs.* modules were recently migrated from httpd to the web zenka.
Cross-zenka file access violations have been fixed (cache now at var_P7/web/jobs/
not httpd/jobs/). Verify the endpoints work correctly end-to-end.

## What was changed

- plugin.web.jobs.cache.path: now returns var_P7/web/jobs/ (was httpd/jobs/)
- plugin.web.jobs.state.save: fixed to read from web cache, not jobsite files
- plugin.web.jobs.init_code: creates var_P7/web/jobs/ dir on startup
- web.jobs.data: reads from plugin.web.jobs.cache.read_all (web cache)
- web.jobs.sync: reads/writes web cache, queues reverse changes

## Routes (cfg/zenki/httpd/routes)

```
GET  /jobs.json  -> httpd.route.handler.web-relay [command=web.jobs.data]
POST /jobs-sync  -> httpd.route.handler.web-relay [command=web.jobs.sync]
```

## Web zenka start file loads

- modules: jobsite.job (for write-back via jobsite.job.write)
- plugins: plugin.web (covers plugin.web.jobs.*)

## Test steps

1. Restart web and httpd zenki:
   p7c v7.restart web
   p7c v7.restart httpd

2. Verify web/jobs cache dir was created:
   ls -la /var/protocol-7/web/jobs/

3. Seed a test job via POST (jobsite-style push):
   curl -s -X POST http://localhost/jobs-sync \
     -H 'Content-Type: application/json' \
     -d '{"id":"test-001","title":"Test Job","company":"ACME","score":8,"fetched_at":1234567890}'
   Expected: {"ok":true,"reverse":[]}

4. Fetch jobs list:
   curl -s http://localhost/jobs.json
   Expected: JSON array containing test-001

5. Send a browser update:
   curl -s -X POST http://localhost/jobs-sync \
     -H 'Content-Type: application/json' \
     -d '{"id":"test-001","stage":"applied","notes":"sent cv"}'
   Expected: {"ok":true,"reverse":[{"id":"test-001","stage":"applied","notes":"sent cv"}]}

6. Fetch again and confirm stage+notes are present in the response

7. Check no direct access to /var/protocol-7/jobsite/ paths occurred during test

Report what passed, what failed, and any relevant log output.

## Signatures note

Do NOT modify any module files. Leave signature blocks (lines starting with
#,,,  #\\\|  #\[7]) completely untouched — the signing system manages these.

#,,.,,,,.,...,,.,,,,,,,,.,.,.,,,,,...,.,,,..,,..,,...,...,..,,..,,.,.,,,,,,,.,
#KDIBULTKC6EYIQ7M7V7ZJ7M3HFBUZ4SSSWQXFL25NRWY4YOPX3K7UDSRDZDAXO7MNMNPP6QS3SQIS
#\\\|OHPMIQL3I47QBFYKZYLU2C43C3L6ME6NRY6XK4PVK7XMBIDPIXC \ / AMOS7 \ YOURUM ::
#\[7]I73BPJO67L44QQWPZSBRRZYCTJSBE5SBLSKMV47OKZ5WEIMXMKBQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
