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

**How to apply:** `nessus-agent.md` (data/tasks/) can now be dispatched
assuming full live-verification is possible against this real instance
— no more "build-only, can't test" caveat. The license is time-limited
though (2026-08-05) — don't assume it's still active in a future session
without checking `systemctl status nessusd` first. If it has expired,
either fall back to build-only verification again or note that a fresh
trial/license would be needed to re-verify.

#,,..,..,,..,,,,.,,,,,,,.,.,.,.,.,..,,,,.,,..,..,,...,...,..,,..,,,,,,..,,..,,
#PMVGOGUK2CDM2DCCOD34OALGP525DEIWCN2BXZUNZZ4XBMK3TIPNSIFQSDVAUSRPN3INM7MZ5M2H6
#\\\|IDTOLBPS3VCQ7JG3PYEOR2465AEKNEAU7W3QPN6UV3I2RE2YLBK \ / AMOS7 \ YOURUM ::
#\[7]2KJAWJI25UCTXQTHCTQM6U2AH66WUCJI65G35PSKPC34EG4R3CCQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
