---
name: tool-suggestions
description: LLM-suggested tools and improvements, prioritized for implementation
type: project
---

## Implemented

- **replace_in_file** — content-based find/replace, no line numbers (2026-03-29)
- **validate_module_format** — P7 format checker: header, metadata, forbidden patterns (2026-03-29)
- **list_inline_subs** — scan module for sub declarations, return names/lines/counts (2026-03-29)
- **replace_in_file replace_all** — flag for replacing all occurrences (2026-03-29)

## Ready to Implement

- **replace_in_file dry_run** — preview mode, show what would change without writing.
  **Why:** model can verify replacement before committing. Low effort.
- **replace_in_file line_numbers** — report which lines were changed in result.
  **Why:** helps model verify edits landed in the right place. Low effort.

## Deferred — Good Ideas, Not Yet Needed

- **extract_single_sub** — one-call extraction: write new module + update source + validate.
  **Why:** full automation of the extraction cycle. Premature while model is succeeding
  with write_new_file + replace_in_file + validate_module_format workflow.
  **When:** after extraction workflow is stable and well-tested across namespaces.
- **analyze_sub_complexity** — analyze sub body for extraction suitability (lines, nesting, closures).
  **Why:** model can eyeball this from read_module currently. Useful when extraction
  becomes fully autonomous without human review.
- **generate_extraction_plan** — output prioritized plan for a module's inline subs.
  **Why:** model already does this in the template workflow. Tool version would be
  useful for batch/scheduled extraction runs.
- **module_usage / check_sub_usage** — cross-reference: which modules call a given sub.
  **Why:** helps decide extract vs leave, identifies dedup candidates like _normalize_checksum.
  search_code / ncode_search partially covers this today.
- **ptd_check dependency graph** — verify all <[module.name]> calls resolve to existing modules.
  **Why:** catches broken references after extraction. Could run as post-extraction validation.
- **batch_validate** — validate multiple modules in one call.
  **Why:** saves rounds when extracting many subs. Low priority since validate is fast.
- **diff_preview** — show what edit_file/replace_in_file would change before applying.
  **Why:** model requested this for debugging content mismatches. Partially addressed
  by replace_in_file which is more reliable than edit_file.

## Template Improvements Suggested

- Add edge case handling section: recursive subs, closures, same-name disambiguation
- Add pre-flight checklist per extraction
- Clarify what modifications ARE allowed during verbatim copy ($_ → $ARG, whitespace)
- Add explicit success criteria per workflow step

## Sources

- task-EMU3JSQ (2026-03-29): first meta-reflection, suggested validate_module_format,
  module_extract, diff_preview, module_usage
- task-63KH5CQ (2026-03-29): second meta-reflection with tool access, suggested
  extract_single_sub, analyze_sub_complexity, replace_all, list_inline_subs

#,,,.,,.,,,,.,,.,,,,.,..,,,.,,.,,,,..,,.,,,.,,..,,...,...,.,,,...,,,.,,,.,,,,,
#LZWIHT7JPR4QYQZQV7YK6IBE6KM5HGFAYZTS3VTHZUVOMFPP4TQW4FCO2B53XFNAOICM3SEA5ZIL2
#\\\|HJ55PB2772VWHJJC6DO3HQIANQM4BAAZ22FRQDVFFYKDMJB36AC \ / AMOS7 \ YOURUM ::
#\[7]UNQJHZ4JBSB4BSDRD2LEBQ2FM5LB2CRD3DGMTKIXUXYRSLMPDSDY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
