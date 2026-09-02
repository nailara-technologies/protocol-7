---
name: feedback-no-inventing-infrastructure-naming
description: "never invent/hardcode domain names, hostnames, or other infrastructure identifiers into production code without explicit user agreement, even if they happen to resolve to something real"
metadata: 
  node_type: memory
  type: feedback
  originSessionId: 7ee57665-382c-473c-94e1-94f8508bf231
  modified: 2026-09-02T02:42:41.464Z
---

Never invent infrastructure naming (domains, hostnames, subdomains, endpoints, etc.) and hardcode
it into production code without explicit agreement from the user first — even when the invented
value happens to land on real, owned infrastructure.

**Why**: found during the v7 -> v7-zenki identity rename — `src/keys.console.github-pat`
contained `nailara-technologies.v7.ax` as a hardcoded email-construction domain, written by a prior
AI session with no agreement from the user. The user does own `v7.ax` (wildcard, points to
`atom`), so it wasn't fabricated-and-wrong in the DNS sense — but the *decision* to construct and
hardcode that specific subdomain into a credentials-writing code path was never actually agreed to.
Quote: "models cannot just invent infrastructure naming and put it hardcoded in production code
without any agreement." This is a governance/process violation independent of whether the domain
technically resolves.

**How to apply**: when writing code that needs a domain, hostname, email address, endpoint URL, or
similar infrastructure identifier, either (a) use a config/data key the user populates themselves,
(b) ask directly what value to use, or (c) leave it as an obvious placeholder requiring explicit
follow-up — never pick a plausible-sounding value and commit it as if it were already decided.
This is a sharper, narrower case of [[feedback-no-personal-data-in-repo-tree]] (which covers
leaking *real* secrets/PII) — this one is about not *deciding* infrastructure facts unilaterally at
all, real or fabricated.

#,,,.,,..,,,.,,,,,.,.,,..,,..,,..,..,,..,,...,..,,...,...,,,.,.,.,.,,,.,.,,.,,
#Z6LLGHY7XFRMEYTKQASJ34TEPEQATIQKLTW4DV5PU42KUNBIN3FEU34CH4OL3V4OS5GM6HKTFKZ4A
#\\\|OZYAUB66TBBAMPDJS3OD763RJDQRT3O3MXHGT4MHTNUJ6IILZ5J \ / AMOS7 \ YOURUM ::
#\[7]L4RKY2HTY2DMV4237COGQAB5QT4HJMO4AE6J2MCOL7HF4ZWP6YCI 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
