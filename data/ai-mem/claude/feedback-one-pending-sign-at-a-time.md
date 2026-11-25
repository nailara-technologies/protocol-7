---
name: one-pending-sign-at-a-time
description: never start a second p7_sign while one waits for approval -- the agent serves the newest, the older job ends 'agent run denied' although the owner approved
metadata:
  type: feedback
---

2026-11-23 : a DNS sign waited ~30 min ; I started a brief sign meanwhile. the owner approved
in the p7-sign-agent terminal, the approval went to the newer job and the older one ended
`aborted` with 'agent run denied' [ updated 27 s after the second job started ]. the owner
confirmed it looked that way in the terminal too.

**Why:** the sign agent handles one pending request ; a second request supersedes the first and
reports it as denied, which reads like an owner refusal.

**How to apply [ until the agent is fixed ] :** start a p7_sign only when no other sign job is waiting ; queue the next set
in my notes instead. a 'denied' right after starting another sign = superseded, not refused --
re-run it [ version files already bumped stay staged ]. follow-up idea : the agent should say
'superseded' instead of 'denied'. related : [[mcp-sign-commit-workflow]]

#,,..,,..,,..,.,,,.,.,...,...,,.,,,.,,,,.,.,.,..,,...,...,.,.,,,,,.,,,.,,,,,,,
#D2JNBC2TBGGR7Z3T3GQRB7C64BNQX3BDNC7XAQBLBNSHMH2R2M6WYKARZ6ORYM25QUGOGZZHOY26U
#\\\|6MDW5MNKC72TSZFRYLGNYIRXQ6TRP3DZ5GNVABYPZFYWHJDPTYO \ / AMOS7 \ YOURUM ::
#\[7]EMBUHQ57PC5YPGH66MSVC5ORJXIYJZFM5RTXLMZQNHZFRMGYAUAQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
