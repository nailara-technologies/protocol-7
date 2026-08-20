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
- Use `p7c coding.inject-message <task_id> <message>` with a specific redirect: "stop searching for X — read src/Y.Z now, that is the relevant module"
- If the model ignores the inject after 2 more rounds, stop the task and complete manually
- Include explicit file paths and module names in the inject — vague hints don't help the local model

#,,,,,,.,,,.,,.,,,.,,,.,,,.,,,,,.,.,,,,,,,,.,,..,,...,...,..,,,..,,,.,,,.,...,
#QXZR72TWHULATQFBI5TBRCTV34WVZI2AYHS52KVIDCOHALL37A5PFSEMHWK4TOMYK2BJIKL5KUSH6
#\\\|VXWLF7OSO6MJET7WDD3MEN6R7HGKAWFMBMOHXINXOXUHTMJMMTH \ / AMOS7 \ YOURUM ::
#\[7]6O3PBAN45TR7XW6IVCZKOLKEZE2YE72NL4TUUJPESV4AIWNX6KAQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
