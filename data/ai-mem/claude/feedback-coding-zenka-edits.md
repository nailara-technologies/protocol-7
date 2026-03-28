---
name: coding-zenka-edit-failures
description: coding zenka LLM often fails to apply edits — describes changes instead of writing them
type: feedback
---

The local LLM (Qwen3.5-9B) frequently fails to use edit_file with apply=true. It reads modules correctly but then describes the changes in prose instead of calling edit_file to apply them. It also invents non-existent P7 APIs (e.g. context.json.decode, file.write).

**Why:** The model may not understand the edit_file tool's apply parameter, or preview mode (default) confuses it into thinking the edit was applied. API hallucination is a known small-model issue.

**How to apply:** When reviewing coding zenka task results, check if edits were actually applied (look for file modifications) vs just described. For critical edits, implement manually after reviewing the model's plan. Consider adding edit_file usage examples to the system-base template, or forcing apply=true as default.

#,,.,,.,,,,,.,.,.,.,,,...,,.,,,..,.,,,,,,,.,,,..,,...,...,..,,.,,,.,,,...,.,,,
#AIKAESIOWMAVX3LYIXVM3LDKS4YHNWY5Q7ELWWKNNSDO4LWDVWQQJEQOVR6FZ22KA7ZVYIZ3G25SC
#\\\|UVP4CRRB2IUMHHQN2QSFJG3R6TYBTEAA42QCDVN5AWPX6ZPAWK2 \ / AMOS7 \ YOURUM ::
#\[7]PEZ4PC22LZUZXJ63SPU7U6CEJNGGYSLM7MJXKKJ54ANWDEUOVKDI 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
