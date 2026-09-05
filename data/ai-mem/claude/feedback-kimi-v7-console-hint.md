---
name: kimi-v7-console-hint
description: combined v7 zenka console output is readable at /dev/shm/.7/STDOUT/NIW7OAQ — give kimi this path for live verification instead of ad-hoc reload/grep
metadata: 
  node_type: memory
  type: reference
  originSessionId: f868a396-75dc-4799-8328-ff97ebc7b708
---

`/dev/shm/.7/STDOUT/NIW7OAQ` is the combined v7-zenki console output
(all zenki STDOUT, ASCII with CRLF/CR/LF), live-tailable. Suggested
2026-06-12 right after a kimi dispatch did an elaborate git-stash
baseline comparison ([[feedback-kimi-reload-baseline-noise]]) to check
whether a `reload` error was pre-existing. Zenka was `v7` at the time;
renamed to `v7-zenki` 2026-08-31/09-02 (commits 23a0e8d53/3f1d6b40f) —
still the same live socket-id (`NIW7OAQ` confirmed live 2026-09-05),
just the zenka's own name changed. Re-verify the socket-id is still
current with `ls -la /dev/shm/.7/STDOUT/` before trusting it in a new
session — it can rotate on a v7-zenki restart.

**How to apply:** when dispatching tasks to kimi that need to verify
`p7c <zenka>.reload` output or other live zenka behavior, mention this
path so kimi can `tail`/`grep` it directly instead of re-running
commands and reasoning about baselines. This is now baked into
`data/yaml/context-templates/kimi-dispatch-workflow.yaml` itself (2026-09-05)
so every kimi_dispatch using that template gets it automatically —
no need to hand-add it per task file anymore, but still worth
double-checking the socket-id is fresh before dispatch, and correcting
any stale `v7.<cmd>` references in an older reference doc the task
points at (translate to `v7-zenki.<cmd>`) since kimi has no way to know
about the rename on its own.

#,,,,,,,,,...,,,.,...,,.,,..,,.,.,,,.,,,.,,,,,..,,...,...,,,.,.,,,...,.,.,,..,
#C5XCWU5M6JW2TNIUOXJDAIM6FWBV2GSVEN7J3QOZX4VGUEHJLNXSFBKLEQ2VGNM5U25JFE3D3JXDK
#\\\|SHJSXQHH2QVS5RZVEMU7SQ32H6TD3TQA7MKOBLO7V7DEVMJ7ZLL \ / AMOS7 \ YOURUM ::
#\[7]TG64MRCLX2V33SP54V6IBITCQEGNZCYITV4GY34D5RZOXWLKHUBI 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
