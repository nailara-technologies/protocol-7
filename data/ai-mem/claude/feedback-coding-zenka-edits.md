---
name: coding-zenka-edit-failures
description: coding zenka LLM often fails to apply edits — describes changes instead of writing them
type: feedback
---

The local LLM (Qwen3.5-9B) frequently fails to use edit_file with apply=true. It reads modules correctly but then describes the changes in prose instead of calling edit_file to apply them. It also invents non-existent P7 APIs (e.g. context.json.decode, file.write).

**Why:** The model may not understand the edit_file tool's apply parameter, or preview mode (default) confuses it into thinking the edit was applied. API hallucination is a known small-model issue.

**How to apply:** When reviewing coding zenka task results, check if edits were actually applied (look for file modifications) vs just described. For critical edits, implement manually after reviewing the model's plan. Consider adding edit_file usage examples to the system-base template, or forcing apply=true as default.

#,,..,,..,,..,.,,,,.,,,..,...,,,.,,,.,,,.,,,.,..,,...,...,.,.,,..,..,,,..,,,,,
#4YRDUVCHVQXRIE7J6C2ZBX72DNL5LTDLE7PF3MUIN42A4AFLVWXOC52UR4GW4FIXE3WE4P4Q62Y4M
#\\\|TSIBJH7UIYAFH3C7BVZQAVTOGPY5FUPAH44RIQGGBUT6263352L \ / AMOS7 \ YOURUM ::
#\[7]KFX3XEAW7F45ZDBSMC2VOAOM55MYAU52MXRJI3ZWWNQYOMP3FOCA 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
