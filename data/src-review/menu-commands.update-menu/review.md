---
module: menu-commands.update-menu
generated_at: 2026-09-09T23:15:00
generator: llm
status: llm-generated, NOT hand-verified -- generated draft, not documentation fact
model: Qwen3.8-9B-heretic-uncensored.i1-Q4_K_M.gguf
model_amos_id: OFSQC4I:QDBKEXY
model_endpoint: http://127.0.0.1:8000/v1/chat/completions [ ik_llama.cpp llama-server, local ]
prompt_version: src-review-v1
source_sha1: 4b36af4232bead661d4c9643e1abb6541adf891f
source_lines: 52
dep_graph_callers: 7
dep_graph_caveat: static literal calls only; conditional/dynamic dispatch invisible to the graph
usage_prompt_tokens: 1007
usage_completion_tokens: 638
---

# review: menu-commands.update-menu

## Purpose
This module notifies the `protocol-7-menu` component of a menu update using a handler-based fetch pattern. It generates a timestamp reference, counts menu items, sends a local command notification, and evaluates the response to determine success.

## Interface
**Input:** None — the module uses internal state (`<menu-commands.mappings>`) and generates its own timestamp.
**Return:** `TRUE` on successful notification, `FALSE` if no clients are present, `undef` on protocol mismatch or unexpected return values.

## Role & dependencies
This module acts as a bridge between menu data and the `protocol-7-menu` service. It depends on:
- `<[base.ntime.b32]>` — timestamp generation
- `<menu-commands.mappings>` — menu item data store
- `<[base.logs]>` / `<[base.log]>` / `<[base.s_warn]>` — logging utilities
- `<[protocol-7.command.send.local]>` — local command dispatch
- `<menu-commands.handler.menu-update-reply>` — reply handler for the notification

## Observations
- **Fragility:** The module relies on `<menu-commands.mappings>->%*` to determine item count. If the mappings structure changes, this breaks silently.
- **Coupling:** Tight coupling to `protocol-7-menu` via the command send mechanism; the module assumes this service is always available and responsive.
- **Style:** The `format.log_singular` warning at line 32 suggests inconsistent pluralization in log messages (e.g., "menu items" vs singular context).
- **Whitelist issue:** The module is not in the subroutine whitelist, which may indicate it was added recently or the whitelist is stale.
- **Error handling:** The `-2` return case handles protocol mismatch, but the `else` branch only warns without structured logging.

## Confidence
Unclear whether `<menu-commands.mappings>` is a shared global or a module-scoped variable — the `->%*` syntax suggests a hash dereference, but the exact binding is not explicit in the source. Also unclear whether the `protocol-7.command.send.local` call is synchronous or asynchronous, which affects how the return value should be interpreted.

---

## deterministic check outputs [ verbatim ground truth ]

### module_convention_check

```
<!-- no violations found in 1 files [ max_line=78 max_descr=55 ] -->
```

### validate_module

```
Validation PASSED for 'menu-commands.update-menu'

WARNINGS:
  ⚠ format.log_singular : 2 occurrences [ first at line 32 ]
  ⚠ module not found in subroutine whitelist
```

#,,.,,,.,,.,.,,..,,,.,,..,.,.,..,,..,,...,...,..,,...,...,...,..,,...,,,,,,..,
#ODWPJ7T7WIMSRSJK6RE24477CG3OANRWN7IXRF65XOG3CXEY2BRM3RN3CCNKEKI3TOZEMKD5UN37A
#\\\|IDRPE7IR7IF5K25V5SEGCSELCLRIWYIIQUUVJBSW2PTMPTD5LVZ \ / AMOS7 \ YOURUM ::
#\[7]37ZB4O2ONIHQYKI4A4J2AP3WXHDLZCBDNMTOB2V6Y6FGK3SS2OAA 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
