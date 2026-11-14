---
name: kimi-restores-files-it-did-not-touch
description: kimi git-restored my uncommitted notes TWICE and DELETED an untracked memory file in one run [ 2026-11-14 ] -- every prompt must forbid touching files it did not change ; commit my own notes before a kimi run
metadata:
  type: feedback
---

2026-11-14, n7fs cleanup run : kimi saw `data/ai-mem/claude/topic-checksum-parenting-namespace-trees.md`
modified, decided its own tests had caused it and ran `git restore` -- twice, once mid-run and once
at the end, wiping notes I re-added in between. it also DELETED an untracked new memory file
[ this one ] and reset `MEMORY.md`. the prompt said "leave data/md/ and data/ai-mem/ untouched",
which kimi read as "make them clean".

**Why:** concurrent work in the tree is normal here [ I write notes while kimi runs ] ; an agent
reverting or deleting files it did not create destroys uncommitted work.

**How to apply:**
- every kimi prompt : "other modified \ untracked files are the owner's work in progress : NEVER
  git restore \ checkout \ stash \ reset \ clean them or delete them ; only revert files YOU changed
  in this run". never phrase it as "leave X clean \ untouched".
- commit my own note \ memory edits BEFORE starting a kimi run, or write them only after it ends.
- after every kimi run, check that my uncommitted files still exist before reviewing its diff.
[[kimi-wrapper-exit-not-done]] [[kimi-specs-forbid-stash-and-real-runs]]

#,,.,,..,,.,,,...,,,.,..,,,..,,,.,,..,,,.,,,,,..,,...,...,.,,,...,,,,,..,,,,,,
#5RYRRN7MG2HGQJCJX3SFAWLSDXB3PU6N35BVVYFTWW4KLKXJNWFUPDSSOKM47JMRY67PX4JHCGAVA
#\\\|5TAZKSRJQ52ZEZFIUFGH7XLFOWFQSWJC7CVY4G3746EH3HD3YKW \ / AMOS7 \ YOURUM ::
#\[7]F2FJZ7CTLUAPBTKMLRQ2KY4O357I5SB2TF7P335RBHOEICOQC6CA 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
