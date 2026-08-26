---
name: stop-and-revert
description: "don't chain speculative fixes — stop, revert, understand first"
metadata:
  node_type: memory
  type: feedback
  originSessionId: 9673d387-d522-4dcb-9938-56cc0137481a
---

Stop making changes when the root cause is not confirmed. Several times this session changes were applied, made things worse, then had to be reverted one by one while the actual cause was still unknown.

**Why:** speculative fixes to a running system obscure the real cause and make diagnosis harder. the user had to say "stop" explicitly.

**How to apply:** if a fix doesn't clearly address a confirmed root cause, stop and ask rather than trying the next idea. revert cleanly before investigating further. only one change at a time when debugging.

#,,.,,,.,,,..,,,.,,,.,.,,,.,.,,,.,.,.,.,,,,,.,..,,...,...,.,.,,.,,...,,.,,,,,,
#2NAOU6TATTXJPQDH3W6FYL7BTH2IMVNNUTLFRXSYXBZ7J4ZNUBJAMS7LAFN2Q2ITMGABWX7GAALMM
#\\\|RFGA5LYIA6YRWS4QP44RQDBMFJNHJ5AUOULMBU7BMHO3WOJPIA6 \ / AMOS7 \ YOURUM ::
#\[7]BRXJPGALNLFL2GW4F3E652F4T4IQ2JMKW3GAIBX7JHMTH7ZZDEBI 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
