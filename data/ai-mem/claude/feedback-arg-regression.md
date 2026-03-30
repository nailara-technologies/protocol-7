---
name: $ARG regression in local model edits
description: local LLM (Qwen 9B) reverts $ARG to $_ in P7 code — always verify and correct
type: feedback
---

Local model consistently reverts `$ARG` to `$_` and `@ARG` to `@_` when editing P7 code,
because standard Perl conventions use the short forms. In P7, `use English` is always loaded
by bin/Protocol-7, making `$ARG` and `$_` true aliases (the SAME variable).

**Why:** The model's training data overwhelmingly uses `$_`. By round 40+, system-base context
is compacted and the convention reminder is lost. The model then "fixes" what it sees as wrong.

**How to apply:**
- Added `** PRESERVE $ARG and @ARG **` reminder to all 12 code-editing templates, placed at the
  action step (not in includes that get compacted early)
- Added to system-review include as well (belt and suspenders)
- After any autonomous code-editing task, run `post-task-verify` template to catch regressions
- When reviewing model edits manually, grep for `$_` and `@_` in the diff
- The observations stash may contain false "bugs" claiming $ARG should be $_ — dismiss these

#,,..,...,,,,,,,,,...,.,,,..,,,,.,,.,,,..,,,.,..,,...,...,,,.,,,.,.,,,,,,,..,,
#QRBEOVBTDAU2MPVXVJGJVENQ5DYEBOVJFXJAWGLS7EOF5643ZHJ52AH7IKXYUL6WQYZPKBSMLD62O
#\\\|IRZ3XRCO66V2QPBU5L5YFOOGROKN5YZUSBCS7KEB5AMFA5HSOCS \ / AMOS7 \ YOURUM ::
#\[7]DDULHDCUS4JXKSI5W4DS6VRTE23RBBTLLM2FD3PEYWDUYAXZ5CAI 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
