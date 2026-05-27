---
name: feedback-deferred-init
description: correct pattern for deferring work until after zenka verification completes
metadata: 
  node_type: memory
  type: feedback
  originSessionId: 4ffce75b-8148-4209-bf51-e550e77dd5ce
---

Use `push @{ <system.callbacks.initialized> //= [] }, 'handler.name'` to defer work until after zenka verification completes.

**Why:** `event.add_var` on `system.zenka.initialized` fires during the verification handshake itself, before the reply is sent — causing a verification timeout. `system.callbacks.initialized` is consumed by `base.cmd.verify-instance` which fires each entry as an `after=>0` timer, guaranteeing execution after the verification reply has been sent.

**How to apply:** Any zenka init_code that needs to run code post-verification (e.g., corpus restore, heavy I/O) should check `<system.zenka.initialized>` — if already true (in-process reload), call directly; otherwise push onto `system.callbacks.initialized`.

#,,,,,,,,,,.,,,,.,...,...,,,.,.,,,,,.,,.,,,,.,..,,...,..,,.,.,,.,,,.,,,.,,,,,,
#VW2SFIORH4TSLELHCYXM7JBPPRFV6ERPYITT64DV7TYFD4XVYIEPU2MJXFUF2B5W4Z65BQS5SWSV6
#\\\|WHBEROQB2BVNNBHRXIZ4GEBT3RVUD4O5WX2AI6YQF6PDDEEKW4R \ / AMOS7 \ YOURUM ::
#\[7]H2D7J6FWCPM7WBWEA55XWEWTNT4ZRC7RXZTDET5QFNSU675KLICY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
