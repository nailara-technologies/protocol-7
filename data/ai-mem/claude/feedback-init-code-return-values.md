---
name: init-code-return-values
description: init_code success check accepts BOTH TRUE(5) and FALSE(0) — only undef/exception signals failure
metadata: 
  node_type: memory
  type: feedback
  originSessionId: 540d7622-310e-4b0f-8485-ccf9ab5cebcd
---

`base.init_modules` checks an `init_code` module's return value with
`$return_code eq '5' or $return_code eq '0'` (string `eq`, see
`base.init_modules:73`) — **both `TRUE` and `FALSE` count as success**.
Only `undef` (or a thrown exception / `$EVAL_ERROR`) signals failure
("module 'X'-init not successful [ init_code != [0|5] ]").

**Why this matters:** found while fixing `transport.init_code`, which had
`return qw| true |` / `return qw| false |` (bare strings, not the
TRUE/FALSE constants — already a [[true-false-constants]] violation).
The naive fix — swap in the constants — is WRONG for an early-return-on-
real-error branch: `return FALSE` (= 0) would make the loader treat a
genuine "dependency missing, can't initialize" condition as *successful*.
The correct precedent is in `discover.mcast.init_code`: `return FALSE`
for a benign skip ("not root, skipping re-init"), `return undef` (after
logging at level 0) for a real failure ("cannot bind to multicast socket").

**How to apply:** when reviewing/writing `init_code` modules:
- `return TRUE` / `return FALSE` → both mean "ran fine, here's a status"
- `return undef` (or `die`/let it propagate) → means "actually failed,
  do not mark this module initialized"
- never use bare `qw| true |` / `qw| false |` strings — they numeric-
  compare unpredictably and mask the real success/failure signal

#,,.,,.,,,.,,,,..,,,,,,.,,..,,,,,,...,,,.,..,,..,,...,...,.,,,..,,...,.,,,..,,
#2M22DXWVBIVVBDRH7JTNX6WSHG6BPB5CUILRGKWDZFZWIM7W2E4EDE4W3RBQZC2XSCBWWJL33W4RM
#\\\|3UYO3H2JXT27NGZW3GV4YPYRNP3PTCTHMPGAWZFUNPAHPSCA5TB \ / AMOS7 \ YOURUM ::
#\[7]WJP47KSNULXYJ2OAAPB5XCWPCX5OWANQLUG43K67GRRCHQ5THQCQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
