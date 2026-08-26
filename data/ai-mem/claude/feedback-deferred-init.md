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

#,,.,,,,,,,,,,.,.,,,,,,,.,,..,,,.,,,,,,,.,.,.,..,,...,..,,...,..,,,,.,.,.,.,.,
#STNIINUF6QDFPXEG5B3HZJ5R2DYHOT2H6O7OINUXM45OVRXBCTYSM774L2Z6KXPG4TI3MWBVKT3HG
#\\\|KAUF5SCMKB67NXP3ICFGRLF7E3MI56ODNDQXVZV63O7AWY2XKJP \ / AMOS7 \ YOURUM ::
#\[7]EF7UUZRXNGEWDCQN4VDWAW7U6D4QEOEFGYXTYDCOBASUJRP4NOBY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
