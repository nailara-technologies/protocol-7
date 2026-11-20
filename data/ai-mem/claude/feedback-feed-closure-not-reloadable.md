---
name: feedback-feed-closure-not-reloadable
description: a handler that passes an anonymous sub to thermal.feed.register [ or any subscription ] keeps the OLD closure after reload source -- try a full reload [ init phase too ] first, restart only if that fails
metadata:
  type: feedback
---

2026-10-30 : task.handler.gpu_temp_update hands thermal.feed.register a `sub { }` ; `task.reload source` loaded the new module [ verified via task.eval-code ] but the feed kept calling the old closure -> new gate keys never appeared. a task restart re-subscribed and it worked [ 19807cb93 ].

**Why:** reload replaces %code entries, not closures already stored in data structures.
**How to apply:** after changing code inside a registered closure [ feeds, subscriptions, stored callbacks ], FIRST a full reload that reruns the init phase [ `<zenka>.reload` -- no keyword = all ] -- owner 2026-10-30 : zenki should be reload safe in general ; a zenka that is not is a bug to fix [ see init-phase idempotency invariant ], a restart is the fallback, not the default ; verify the live effect, never trust 'reload [ success ]'. related [[reload-success-doesnt-guarantee-new-file-loaded]]

#,,,.,,,,,...,.,,,..,,,,.,..,,.,,,,..,,,,,,..,..,,...,.,.,..,,.,.,,,,,,,.,.,.,
#GI5RUOBNIB22LZYIQSHO73DFNRY5EF3TOLU46CXHGHA2HEPIRHYDLBUTDWBX25WH2YGSGCPN7NXJS
#\\\|TQRSYKZBHIVMQZZOGSMW2TPIF6K7U2HTFRMHDHTKY7GPXV2HX4H \ / AMOS7 \ YOURUM ::
#\[7]YA4NZG3AG3667L6L227MF2YL4YZZS4BTAQHXMNKLQ34VETAQFIBQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
