---
name: coding-zenka-edit-failures
description: coding zenka LLM often fails to apply edits — describes changes instead of writing them
type: feedback
---

**2026-10-24 correction :** many edit failures since 2026-09-18 came from the SAMPLER, not the model -- DRY + repeat_penalty broke every exact copy [ paths, old_string ]. see [[sampler-penalties-break-exact-copy]] and [[project-2026-10-24-local-model-edit-comparison]] before blaming a model.

The local LLM (Qwen3.5-9B) frequently fails to use edit_file with apply=true. It reads modules correctly but then describes the changes in prose instead of calling edit_file to apply them. It also invents non-existent P7 APIs (e.g. context.json.decode, file.write).

**Why:** The model may not understand the edit_file tool's apply parameter, or preview mode (default) confuses it into thinking the edit was applied. API hallucination is a known small-model issue.

**How to apply:** When reviewing coding zenka task results, check if edits were actually applied (look for file modifications) vs just described. For critical edits, implement manually after reviewing the model's plan. Consider adding edit_file usage examples to the system-base template, or forcing apply=true as default.

#,,.,,,,.,,..,,,,,,,.,...,,,.,,.,,...,.,,,..,,..,,...,...,...,...,..,,.,,,,,.,
#A622WGFAX5XQGYSFFWSSC2EYH6XSIEK66VTSZB3C6Y3S6I4LT2JUVC7VUAP5R7PALK4SEVDSCWRQ2
#\\\|KSNUWEPGHLDN3OCVJM76IYDB5T6QJBCWTIR5WDXECCACBKNDJIO \ / AMOS7 \ YOURUM ::
#\[7]JLRTIDYPHTXHL2U5UAEJ4FIHDUVO47UIFX3KNNA6EYMRJHKQJKDA 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
