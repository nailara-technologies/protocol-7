---
name: feedback-httpd-deferred-reply
description: deferred P7 reply from httpd request handlers causes crashes — web zenka is the right relay
metadata: 
  node_type: memory
  type: feedback
  originSessionId: 095ef9b6-c744-46c5-bac8-4d54a2d5ce45
---

Attempting deferred P7 reply from within an httpd request handler (route-send to
another zenka, reply handler writes HTTP response) is fragile and caused crashes:
- `flush` vs `flush_shutdown` distinction — wrong key = response never sent
- Session lifetime: client may disconnect before reply arrives
- Crashes loop: IO::Async keeps firing, zenka restarts repeatedly

**Why:** httpd request handlers are synchronous callbacks in the event loop.
Holding a session open waiting for a cross-zenka reply fights the architecture.

**How to apply:** For cross-host data in HTTP responses, use HTTP push — jobsite
POSTs updated YAML to an httpd endpoint on write; httpd caches locally and serves
synchronously. route-send only works within an existing P7 network (same cube),
not cross-host. Deferred reply works fine in non-HTTP zenki where there's no
open client socket to worry about.

#,,..,,,,,,,,,..,,.,.,..,,,,.,,.,,.,.,.,.,,..,..,,...,...,...,.,.,...,,,.,..,,
#DGIKIDG2BB77GZOMGLG4EXSEUKNMNVRTSBLN232OVFZGWZMKWTOWALZIDXV4XHNXEMYRPKL3IVKWC
#\\\|ETB54RHHTMTQRDIB4XKTFWHRJ6GQ5GGQXWZ4LNVQRHMFOKPL3PY \ / AMOS7 \ YOURUM ::
#\[7]6RAXTDBRONRJD34E3F3VBKBP6RS47QPLOSRB32KENEPCIRWB5GBQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
