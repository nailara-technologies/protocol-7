---
name: feedback-feed-closure-not-reloadable
description: a handler that passes an anonymous sub to thermal.feed.register [ or any subscription ] keeps the OLD closure after reload source -- try a full reload [ init phase too ] first, restart only if that fails
metadata:
  type: feedback
---

2026-10-30 : task.handler.gpu_temp_update hands thermal.feed.register a `sub { }` ; `task.reload source` loaded the new module [ verified via task.eval-code ] but the feed kept calling the old closure -> new gate keys never appeared. a task restart re-subscribed and it worked [ 35d3fff67 ].

**Why:** reload replaces %code entries, not closures already stored in data structures.
**How to apply:** after changing code inside a registered closure [ feeds, subscriptions, stored callbacks ], FIRST a full reload that reruns the init phase [ `<zenka>.reload` -- no keyword = all ] -- owner 2026-10-30 : zenki should be reload safe in general ; a zenka that is not is a bug to fix [ see init-phase idempotency invariant ], a restart is the fallback, not the default ; verify the live effect, never trust 'reload [ success ]'. related [[reload-success-doesnt-guarantee-new-file-loaded]]

#,,.,,.,.,.,,,,..,,.,,.,,,...,,,,,..,,.,.,.,,,..,,...,...,.,,,,,.,,..,,,.,,,,,
#7L4SKTLFYDCDMXZRO2DKKRZPC7SLUHEWRAVJKDKT4Y5J26P7LPJJ6QMFIGZPGR5GYE7ZZSMZVFZO6
#\\\|RFZJCACWZBBN5Z5RWPI3PHYG6JTIBAZZAEEWGHTVTQGD4KVRXRD \ / AMOS7 \ YOURUM ::
#\[7]Y6KBVGGJOHURB2AE3NLTG5MMGZILA6OCGCXSRHTGWWF6AOFB7KAA 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
