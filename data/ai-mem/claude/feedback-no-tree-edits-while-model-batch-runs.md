---
name: no-tree-edits-while-model-batch-runs
description: a running model-batch reverts EVERY change to the repo tree after each task -- my own src/ edits and new files included, for any zenka ; stage work in the scratchpad until the batch is done
metadata:
  type: feedback
---

A running `coding.model-batch` treats every difference from its baseline manifest as the task's output and reverts it after each task [ capture -> revert -> reverify ]. That includes edits I make to `src/` meanwhile -- not only coding modules : on 2026-10-10 a new `base.chmod_child.*` pair, `fetch-files.init_code` and an edit to `fetch.file.huggingface.download` all vanished mid-batch, although they had nothing to do with the coding zenka. The user signing during a batch is hit the same way [ version files, signatures ].

**Why:** the harness cannot tell a model's edit from mine ; reverting is its whole job. Before 2026-10-10 the revert path was broken [ no baseline blobs ], so this never showed -- once fixed, it reverts reliably.

**How to apply:** while `model-batch-status` shows a batch running, write new work to the scratchpad [ `scratchpad/pending/` ] and move it into `src/` after `batch complete` ; or cancel the batch first and restart it with `:restart:` [ fresh baseline ]. Reading, testing outside the tree and downloads to `/mnt` are fine. See [[project-2026-09-21-model-batch-harness-implemented]].

#,,,,,.,.,,,,,..,,...,,..,.,,,,.,,.,,,,..,,..,..,,...,..,,...,.,.,...,.,,,,..,
#BLDLJ7UG7SVC4EO75MVP7KINM3BZWG43INFZIR4HZ3N576VRLROXXCRMDT45IVBWWICVI2TASYSPW
#\\\|6MXSL4JOPBFKBSJSCEIDQCDLKDFTV4ZZF5LJSY3B3MI3V5O75K4 \ / AMOS7 \ YOURUM ::
#\[7]YNTMZORFS6YAUNS3N4UQ2MW2HPBIMKN62UG5LMS546W65TZR5OBQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
