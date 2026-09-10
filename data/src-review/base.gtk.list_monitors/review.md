---
module: base.gtk.list_monitors
generated_at: 2026-09-09T22:56:28
generator: llm
status: llm-generated, NOT hand-verified -- generated draft, not documentation fact
model: Qwen3.8-9B-heretic-uncensored.i1-Q4_K_M.gguf
model_amos_id: OFSQC4I:QDBKEXY
model_endpoint: http://127.0.0.1:8000/v1/chat/completions [ ik_llama.cpp llama-server, local ]
prompt_version: src-review-v1
source_sha1: caeeb987b7df87b02438dd2c960e6bd4af9ef2bd
source_lines: 54
dep_graph_callers: 9
dep_graph_caveat: static literal calls only; conditional/dynamic dispatch invisible to the graph
usage_prompt_tokens: 1031
usage_completion_tokens: 506
---

# review: base.gtk.list_monitors

## Purpose
Enumerates all Gdk monitors on the default display, returning their geometry (x, y, width, height), name, and primary status as an array of hash references. Assumes the default Gdk display is already open.

## Interface
**Input:** None (relies on the default Gdk display being open).
**Output:** A reference to an array of hash references, each containing `index`, `x`, `y`, `width`, `height`, `name`, and `primary` keys. Returns `undef` if no default display is available.

## Role & dependencies
Serves as a shared monitor source for Zenka's placement and layout code. Depends on `Gtk3::Gdk::Display` and calls `<[base.log]>` for error reporting. The module is called statically by 9 other modules (per the dep-graph).

## Observations
- **Fragility:** The `eval` blocks silently swallow errors (e.g., if `get_monitor($i)` fails mid-loop), potentially returning incomplete data without raising an exception.
- **Coupling:** Tightly coupled to Gtk3::Gdk; not portable to non-Gtk3 environments.
- **Style:** The `format.log_singular` warning at line 11 suggests the log message may not handle pluralization correctly. The module is also not in the subroutine whitelist, which may indicate a governance or audit concern.
- **Data handling:** The `+ 0` coercion on numeric fields is defensive but unnecessary if the geometry is guaranteed numeric.

## Confidence
Unclear whether the `eval` blocks are intentional (graceful degradation) or a bug (silent failure). The `format.log_singular` warning's practical impact is unclear without seeing the log format.

---

## deterministic check outputs [ verbatim ground truth ]

### module_convention_check

```
<!-- no violations found in 1 files [ max_line=78 max_descr=55 ] -->
```

### validate_module

```
Validation PASSED for 'base.gtk.list_monitors'

WARNINGS:
  ⚠ format.log_singular : 1 occurrence [ first at line 11 ]
  ⚠ module not found in subroutine whitelist
```

#,,..,.,.,,,.,...,,,.,,.,,,.,,..,,,,,,,,,,.,.,..,,...,..,,...,,.,,.,,,...,,.,,
#CTPM7L7GCKTSE53BGX6FLM7XHIOIC55BMF6OGHMXM7JRRET5VNBJOVR5UGCM5OCT4QSVQVE5F3YZO
#\\\|JQ5ZYHDOUZPHD32R6D257RRKICALOMSHRSGXJMMJQS6TM6BK4JP \ / AMOS7 \ YOURUM ::
#\[7]JMCP3JZ6MC5IJPMMIDYPL6UBCISF65MDH2EA2QDEDT4MDM73F6DI 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
