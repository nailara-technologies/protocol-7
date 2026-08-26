---
name: project-nessus-trial-installed-2026-07-29
description: "Nessus Professional trial installed, activated, and running on this host as of 2026-07-29 -- systemd service nessusd on https://localhost:8834/, license valid until 2026-08-05, enabling live-verified nessus-agent development instead of build-only/blind"
metadata:
  type: project
---

**Why:** motivated by an ethical-hacker job application the user
submitted, which accelerated the security agent task tree
([[bug-ntime-b32-2-unix-missing-compint-float-support]] and the
forensics-agent landing both came out of this same push) — having
openvas + nessus + forensics agents actually working demonstrates
relevant capability to a prospective employer. nessus-agent specifically
was originally deprioritized as "needs a proprietary license, can't be
live-tested" until Tenable's trial signup unexpectedly delivered a
direct `.deb` download plus an activation email
(`nessus@taeki.v7.ax`) with a working code.

**State as of 2026-07-29 ~21:00**: `Nessus-10.12.2-debian10_amd64.deb`
installed via `dpkg`, `nessusd` systemd service running, activation code
`GLL6-3RLM-DYOP-7Y6W` applied (**expires 2026-08-05** — this is a
trial, not a permanent license), plugin feed downloaded, setup wizard
completed. Scanner is live and reachable at `https://localhost:8834/`
(self-signed cert — see
[[feedback-web-browser-tls-ignore-and-proxy-no-proxy]] for what it took
to even view the setup UI through the web-browser zenka).

**Known cost**: first-boot plugin compilation pinned `nessusd` at
~220% CPU for 12+ minutes. Settled down afterward. Worth remembering if
CPU contention shows up again during/after a real scan — this is a
known one-time (or per-feed-update) Nessus cost, not necessarily a bug.

**UPDATE 2026-07-29 22:12 (kimi, commit `a47ac3659`) — important
limitation found**: this trial license has `scan_api: false`
(`GET /server/properties`) — **scan creation via the REST API is
blocked entirely**, UI-driven scanning only. `nessus.cmd.scan-run`
(the zenka's REST-API wrapper) is verified end-to-end up to this exact
boundary: login works, template resolution works, `POST /scans` always
returns `412 "API is not available"` for every template. This is a hard
license-tier restriction, not a bug — a real scan round-trip is **not
achievable** with this trial via the API path no matter what the code
does. A paid tier (or a different trial type) with `scan_api: true`
would be needed for that. Side quirk also documented: the gated endpoint
resets the connection for python urllib/http.client clients specifically
(`ECONNRESET`) while curl and raw `openssl s_client` get a clean `412`
body — verified deterministically, cause not fully identified (not TLS
version, not HTTP/1.1-vs-h2, not headers/body bytes), the helper now
converts it to a clean error either way.

**How to apply:** `nessus-agent.md` phase 1 (zenka scaffold +
`nessus.cmd.scan-run`) is DONE and properly live-verified up to the
license boundary — don't re-dispatch expecting a different result on
this same trial. Any future phase-2/enrichment work should assume no
real scan data will ever come from this instance unless the license
changes. The license itself is still time-limited (2026-08-05) — check
`systemctl status nessusd` before assuming it's even running in a
future session.

#,,.,,.,,,..,,,,,,,..,,,.,,.,,,,.,.,.,.,.,..,,..,,...,..,,.,.,.,,,,,,,.,,,.,,,
#HSKFFZMUOSKFBZ65PQXJJ72BVP6FKROSPVNOTTJAVSB6YEW5FA4UOEEWJDEQSKEBJGRPDMHVZQ546
#\\\|BJE56AMGPOU34U66AEUKYIDJK6UZSSS5Y5YCG5I7M7VI5EP4PYB \ / AMOS7 \ YOURUM ::
#\[7]D3TLYESGL7EVRZJGLVEG6FI3IVYIE5MRJOOUP5DYBFSLKMMVJICI 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
