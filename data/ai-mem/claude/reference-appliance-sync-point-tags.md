---
name: appliance-sync-point-tags
description: git tags matching D-<code> mark points where a commercial appliance release was cut from this codebase for former employers; how to find them and the last one before the permanent fork
metadata: 
  node_type: memory
  type: reference
  originSessionId: e81d6781-e404-4cb2-9bd8-c1b6d0c366ef
  modified: 2026-08-20T22:59:21.443Z
---

commits tagged `D-<code>` (`git tag -l 'D-*'`) mark sync points where a
next commercial-appliance release was built from this codebase, for
former-employer deployments. `<code>` is either sequential (`D-0000`,
`D-0010`, ... `D-0110`) or an AMOS-checksum-style string (`D-IOIF2AY`,
`D-RNTBZAQ`) — the scheme itself changed mid-stream, all still within
March–April 2021.

verified in-repo (`git tag -l 'D-*'` + `git log -1 --format='%ad %s'`
per tag): 12 tags total, all dated 2021-03-22 through 2021-04-22. the
**last one is `D-RNTBZAQ`**, commit `3115d344d2e8965a72089b84ff341dff25041fe9`,
2021-04-22, "renamed ',.zenki/nroot/start-setup.basic' --> 'start-set-up.base'".
no `D-*` tags exist after this — the appliance codebases forked
permanently around here and stopped tracking `base`. see
[[rename-scope-policy]] for why this matters: nobody pulling `base` today
was ever going to see anything past this point anyway.

**how to apply:** if investigating "what did the last shared/synced state
look like" or "when did X diverge from appliance builds," diff or browse
from `D-RNTBZAQ` rather than guessing a date range.

#,,,.,,,,,,..,.,,,..,,...,.,,,.,.,,,.,,..,.,,,..,,...,...,.,.,,.,,,.,,,,.,,,,,
#AVVCWTDDIMIRTZLT6267H4WLSEXEZ4KZCIZISGHPDU4C7XDC6OVORZMTGWTNDOXCIENR5X5DCOFI2
#\\\|DJXSGNEF2THRDCKVWNFNU7VLSAK6VGYPWFP5R26W6DT2UFJMQYE \ / AMOS7 \ YOURUM ::
#\[7]KRBXLQQ6OZ5GUPUPQ6Y3KJBK42LCCFPM6XTGCS5LKXZI3XOEDQDI 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
