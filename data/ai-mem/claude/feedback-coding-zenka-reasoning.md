---
name: feedback-coding-zenka-reasoning
description: reasoning budget affects task completion — low setting causes premature task_complete mid-investigation
type: feedback
originSessionId: 941ef93c-3dcf-4d15-8c40-ccd709e0510b
---
Low reasoning budget causes models to call `task_complete` before finishing — they exhaust their reasoning quota during the investigation phase and exit without writing code.

**Why:** The SLERP 4B model is already intense and as slow as 9B models even at low reasoning. The 9B Qwen3.5 Q8 exited on round 4 mid-investigation (result_len=254) likely due to the same low reasoning setting — it understood the codebase but didn't have budget left to act.

**How to apply:** Use medium reasoning for both SLERP 4B and 9B models when tasks require investigation + implementation in the same session. Only drop to low reasoning for pure style/format tasks where the model just needs to rewrite existing code with no discovery phase.

#,,..,...,.,.,,,,,.,.,,..,,..,,,,,.,,,.,,,...,..,,...,...,...,.,,,,.,,...,.,,,
#XFW56FPYHNUFKMBML4Q3PROBPEGNJMT5UU5C6TRX6ITEVWJPB4IHS5KYASNQ4ISX5BOQDE4QXL6II
#\\\|YAAS3ICN45OSDFQM6H6WQEG5BG4QYSMRVY5REFI2UGPZUKXX6ZM \ / AMOS7 \ YOURUM ::
#\[7]VFAFNJTGBJE56QYGYYG5V6DYLNI67XKWYEJ2RZQXFZT4ZTOUU2AQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
