---
name: kimi-v7-console-hint
description: combined v7 zenka console output is readable at /dev/shm/.7/STDOUT/NIW7OAQ — give kimi this path for live verification instead of ad-hoc reload/grep
metadata: 
  node_type: memory
  type: reference
  originSessionId: f868a396-75dc-4799-8328-ff97ebc7b708
---

`/dev/shm/.7/STDOUT/NIW7OAQ` is the combined v7 zenka console output
(all zenki STDOUT, ASCII with CRLF/CR/LF), live-tailable. Suggested
2026-06-12 right after a kimi dispatch did an elaborate git-stash
baseline comparison ([[feedback-kimi-reload-baseline-noise]]) to check
whether a `reload` error was pre-existing.

**How to apply:** when dispatching tasks to kimi that need to verify
`p7c <zenka>.reload` output or other live zenka behavior, mention this
path so kimi can `tail`/`grep` it directly instead of re-running
commands and reasoning about baselines.

#,,.,,,,.,.,.,,,.,,,.,.,,,,..,.,,,.,.,,.,,,..,..,,...,...,...,.,,,,,.,,.,,,..,
#IIXURJVRRZMHTGHA47A3PXIFFHSWOG5RJEIYRHLE5I5SQMTDAUGKJB4HLIIVD6NPR4P436WIIDB7A
#\\\|FQCZOU5YISNEBW6STQBN2YG7ASNSLU2FS7SPLJOLRIDAA3EF7IP \ / AMOS7 \ YOURUM ::
#\[7]73DAVNKP7XHEEB6UFSAPBI7BIR4QTVMLJOIO5YGOCER3XBHBC6BQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
