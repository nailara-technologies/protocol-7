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

#,,,.,,..,,..,,,.,...,,,.,..,,,,,,,,,,.,,,,,.,..,,...,...,,,,,..,,,,.,,,.,...,
#2PPVNWFVT7UYKXRBD7DET6E5NZSA6X3DC4OKOYMJHGNRQ2AV7MDIKHTNFTF5RYE2NHSRR7ONIGDRQ
#\\\|ASNERP3BNMGSUQNSXKSAE7A77O72IM2FJW4Y73T6C5NYPM7R73S \ / AMOS7 \ YOURUM ::
#\[7]P4T4RGQOWNOTCQ677D2JZ75FOVQUKTGAFNQMRHDW4KCD3VEVTCAA 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
