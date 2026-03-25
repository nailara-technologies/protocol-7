---
name: host-migration-priority
description: Windows 11 host is unstable — migration to KVM/Debian is a priority that may influence feature work
type: project
---

## Host Migration: Windows 11 → KVM on Debian

The development host runs Windows 11 (WSL2). Windows itself is the problem — not hardware
instability. Windows Update reboots the machine without user consent, including while the user
is away (e.g. during sleep). This:
- Wipes `/tmp/` and terminates all WSL2/Debian VM processes mid-session
- Required ~10 reboots and disabling software to restore a functional desktop (March 2026)
- Cannot be reliably mitigated: disabling updates is a security risk, so Windows as a
  development host is simply not suitable. The conclusion is straightforward.

**Migration is in progress** — planning document:
`data/html/tutorials/win-11-to-KVM-on-debian.guide.html`

### Feature Prioritization Impact
- Never use `/tmp/` for anything that must persist — it can vanish at any time
- Any "save for later" artifacts go into the repo (`data/asc/`, `data/yaml/`) not `/tmp/`
- Features that reduce Windows dependency or support the KVM/Debian target environment
  may be prioritized over lower-urgency work

#,,,,,...,,.,,,.,,,..,.,.,,,,,,.,,.,.,..,,.,,,..,,...,...,...,.,.,,,.,.,,,,.,,
#RBCBWBYMAJ5T24CB55KF4OMBT5XO7C4G4XTZIQVE7YUKYDKE7TVITVGB7OEKNSUB7QIQPQF2N2HBO
#\\\|CIXRGRLKBTOIJAXHL3HLV26UQ6EKDKGKXZTPVWJ36DI2HGKYOFL \ / AMOS7 \ YOURUM ::
#\[7]SVHPMYDA4GQD7OZTEROTSANJG472OKK6XSVN4Z3A3RLCDTFFOUCQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
