---
name: coding zenka inject-message for mid-task redirect
description: use p7c coding.inject-message to redirect a stuck local LLM without stopping the task
type: feedback
originSessionId: d051f522-26a3-4bbc-acf8-b2a05b2cc83e
---
When the local LLM is stuck searching for something (visible via `p7c coding.show-buffer model_output`), inject a targeted hint rather than stopping and restarting.

**Why:** stopping wastes the rounds already completed; injection lands as a user turn and the model picks it up on the next round.

**How to apply:**
- Watch `show-buffer model_output` for repetitive "let me search for..." rounds (3+ in a row on same topic)
- Use `p7c coding.inject-message <task_id> <message>` with a specific redirect: "stop searching for X — read modules/Y.Z now, that is the relevant module"
- If the model ignores the inject after 2 more rounds, stop the task and complete manually
- Include explicit file paths and module names in the inject — vague hints don't help the local model

#,,..,.,,,,.,,,,,,...,...,..,,,.,,,..,..,,,,,,..,,...,...,,..,..,,.,,,.,,,.,.,
#2FXIN42C5YI22MXQIS74GTGE4P6QT6L5IL4BPZW6EPNA2PNYSYCORAOX4G3C5P2LYEHXMCIMDBC6Q
#\\\|GCOYM3CWSANMHE6SDLVZDHZ35VGJMKH6EPYK2VC3TWORGOO55JC \ / AMOS7 \ YOURUM ::
#\[7]7VNIHJES632WC3H2PF7FRRLXHJVO2EHHFUUC6EGBEE5I3E5WLOBI 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
