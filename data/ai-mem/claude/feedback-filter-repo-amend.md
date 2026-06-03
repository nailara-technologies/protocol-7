---
name: feedback-filter-repo-amend
description: git filter-repo requires AMEND=1 env prefix to work with the Protocol-7 pre-commit hook
metadata: 
  node_type: memory
  type: feedback
  originSessionId: f5b14fde-ecec-4f58-b7f2-95aaab875b62
---

`AMEND=1 git filter-repo ...` — the pre-commit hook requires this prefix for filter-repo commands to work.

**Why:** the Protocol-7 pre-commit hook blocks history-rewriting operations without the AMEND=1 flag; without it filter-repo fails at the hook stage.

**How to apply:** any time `git filter-repo` is used (path removal, history scrubbing, ref rewriting), prefix with `AMEND=1`. Also clear `.git/filter-repo/already_ran` if a previous run was interrupted.

#,,.,,,..,.,.,..,,,,,,,,.,..,,.,,,,,.,.,,,,..,..,,...,..,,..,,,,.,.,.,...,,.,,
#6AOTC4KGXWQYCJQYLE6KKOSNXKHNQQYBME4HNCR22NOLBUITHDH32BTO6T6WH3PCM5XL33GXFKQJW
#\\\|TZ7JCJVXIPRC7TGMJTLXE7JUHYLHYX7CYQAHEB3QJNGCBKM5P7K \ / AMOS7 \ YOURUM ::
#\[7]QAZG5KKRK4FYQPJQHWARIXYREWBYTNR53NMQSU5WIDGCWF2RRICQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
