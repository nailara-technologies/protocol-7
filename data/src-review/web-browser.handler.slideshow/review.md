---
module: web-browser.handler.slideshow
generated_at: 2026-09-09T23:18:41
generator: llm
status: llm-generated, NOT hand-verified -- generated draft, not documentation fact
model: Qwen3.8-9B-heretic-uncensored.i1-Q4_K_M.gguf
model_amos_id: OFSQC4I:QDBKEXY
model_endpoint: http://127.0.0.1:8000/v1/chat/completions [ ik_llama.cpp llama-server, local ]
prompt_version: src-review-v1
source_sha1: e3f62473101984d990d2662fd97613decc163d22
source_lines: 133
dep_graph_callers: 7
dep_graph_caveat: static literal calls only; conditional/dynamic dispatch invisible to the graph
usage_prompt_tokens: 1849
usage_completion_tokens: 575
---

# review: web-browser.handler.slideshow

## Purpose

This module orchestrates a slideshow by iterating through a URL list, loading each page, handling pause commands, and managing timing between transitions. It coordinates with timers and logging to control the slideshow lifecycle.

## Interface

No explicit arguments or return values. It operates as a state machine driven by internal variables (`<web-browser.slideshow.status>`, `<web-browser.slideshow.url_index>`, etc.) and external events (timers, log messages).

## Role & dependencies

It fits into the `web-browser` subsystem as a handler module. Notable callees include:
- `<web-browser.load_uri>` — loads a URL
- `<event.add_timer>` — schedules the next iteration
- `<[base.log]>` — logs status messages
- `<[file.slurp]>` — reads local files for SKIP detection
- `<system.zenka.mode>` — checks for universal-child mode

## Observations

- **Fragility**: The `format.log_singular` warning (4 occurrences) suggests inconsistent pluralization in log messages, which may indicate a template or formatting issue.
- **Coupling**: Heavy reliance on global state variables (`<web-browser.slideshow.*>`) makes the module tightly coupled to the `web-browser` namespace.
- **Style**: The AMOS7 `<var>` syntax is domain-specific and opaque to readers unfamiliar with the Protocol-7 convention.
- **Potential issue**: The SKIP detection (`File::stat::stat($1)->size == 12`) is brittle — a 12-byte file is an arbitrary magic number that could break with minor content changes.
- **Missing metadata**: The `descr` field is absent, reducing discoverability.

## Confidence

Unclear whether `<web-browser.slideshow.status>` is ever set to `load_finished` externally, or whether the `no_switch` flag is ever toggled — these paths appear to be entry points from other modules.

---

## deterministic check outputs [ verbatim ground truth ]

### module_convention_check

```
<!-- no violations found in 1 files [ max_line=78 max_descr=55 ] -->
```

### validate_module

```
Validation FAILED for 'web-browser.handler.slideshow':

ERRORS:
  ✗ missing or invalid metadata field 'descr'

WARNINGS:
  ⚠ format.log_singular : 4 occurrences [ first at line 18 ]
  ⚠ module not found in subroutine whitelist
```

#,,.,,..,,.,,,.,.,.,,,,.,,,.,,.,.,.,,,,,.,...,..,,...,...,.,,,,.,,,,,,,,.,.,,,
#EIFIPMT4OZVYR526DL3ONLZSGFV7LGM6LDVABOSZN64H2G7RO4TKIN3TVYJVMDGHP536QIRCLR7GU
#\\\|PQGNSQ6QDY4TE7MMGIAR56IW4GENYLHUXJPUQ5RXRS4WJCXGXRU \ / AMOS7 \ YOURUM ::
#\[7]DDNUNWE6KSPLCHS6WEOOUGV7WZQAU3SG2E24ZJDVZVI736PDKKCQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
