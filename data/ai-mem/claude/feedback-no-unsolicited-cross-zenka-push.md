---
name: feedback-no-unsolicited-cross-zenka-push
description: cross-zenka data recovery/sync must be pull-initiated by the trusted/consuming side, never an unsolicited push from the data-holding side
metadata:
  type: feedback
  originSessionId: 47367c65-b043-47a7-be00-11d29ff7b99d
---

Initial design had site-yaml (external-network-facing scraper) detect its
own stale data and immediately push a full payload to jobsite unprompted.
Corrected by the user: that's a security-boundary violation, not just an
architecture preference.

**Why:** the zenka with external network access is the less-trusted side.
Letting it decide when and what to hand to the more-trusted processing
zenka means an external-facing process controls the timing and content of
writes into the trusted store. Also relevant when the two zenki run on
separate hosts (one with internet access, one without) — same pattern as
[[feedback-source-identity-spoofing]]: don't let the periphery dictate to
the core.

**Correct pattern:** the data-holding zenka only exposes a passive,
read-only listing/announce command (count + recency, or a lightweight
manifest). The consuming zenka decides on its own schedule (its own
startup, a timer, or a manual admin command) whether to call that listing,
then pulls items one at a time via its own explicit request, confirming
each one back so the source can clean up.

**How to apply:** any time a zenka with broader/external access is about
to call into a more-trusted zenka uninvited, stop — flip it so the trusted
side initiates. See `jobsite.stray.check` / `site-yaml.cmd.list-stray-jobs`
for the landed example (commit a52a6a4b8).

#,,,.,,,,,,.,,,,.,..,,,..,..,,,.,,.,,,,,.,,..,..,,...,..,,.,,,...,,.,,..,,...,
#DCHCTW77WWAYY4ABLVCCDTFCXPF6EZSXBXRIFNAGFN2TX4GZIYIWMGH5XCZ3CTCXWPCCYPOCWOW72
#\\\|S7ES3RW6A7I5BYVY4WU36XRDHBU47POMSGR5BD7VRATKLC7X6TU \ / AMOS7 \ YOURUM ::
#\[7]O6MQGWFY3N6SCVKBDHF6LUFOAZYH6WMUGJ2INPJMUQTSJEKA42DA 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
