---
name: feedback-network-command-omits-cmd-infix
description: "when calling a zenka command over the network (p7c / cube routing), omit the '.cmd.' infix that the src/ filename has — categorical rule, not per-command"
metadata:
  type: feedback
---

`src/X-11.cmd.xvfb-start` is the module FILE name. The routable command, called via
`p7c`/cube routing, is `X-11.xvfb-start` — no `.cmd.`. This is categorical: applies to
every `Zenka.cmd.foo` file in `src/`, not just X-11's.

**Why this matters**: got a `command not known or no permission for 'cmd.xvfb-start'`
error and spent a long diagnostic detour (2026-08-28) assuming it was a cube
access-control gap — read through `cfg/zenki/cube/access.zenki`, `access.users`,
`auth.users`, `plugin.auth.unix`, `base.access.special-user-map`, `base.parser.config`'s
template-key expansion, confirmed the wildcard grant (`access.cmd.usr.<unix-admin>` →
`unix-taeki` → `** ..*.**`) really was live for the session — all of that was correct and
irrelevant. The error was just a wrong command name. The user's own test
(`X-11.commands xvfb` successfully listing the xvfb commands) was the tell: a session
without real access wouldn't see that listing at all, so the block had to be something
narrower than a routing-permission gap — it was the literal string, not a permission.

**How to apply**: when a `command not known or no permission` error appears for a call
built directly from a `src/Zenka.cmd.foo` filename, try stripping `.cmd.` FIRST, before
reading any access-control config. Only chase the auth/access system if the
no-`.cmd.`-infix form also fails.

#,,..,,.,,,,.,,.,,.,,,.,.,,.,,,,,,..,,,,,,,..,..,,...,...,,,,,..,,,.,,...,...,
#BJCZDBA466DXNSD4RXULRATIUXPOEQXSISMNUEZ5AAPTSUDEQ5SBFL476EKSP2H63OQPN5ZZTO3X6
#\\\|5M6RRO5JIULI7R2Y4EMOYPZPDDSLLMGZLQ7HDKTM27BM52WBAPR \ / AMOS7 \ YOURUM ::
#\[7]A23CQNAH7D5YCYG6XFGSV6JD7SEBFQGBXRPDJBI6WGLETDQJOCBA 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
