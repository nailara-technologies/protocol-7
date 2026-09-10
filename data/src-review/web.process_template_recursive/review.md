---
module: web.process_template_recursive
generated_at: 2026-09-09T23:32:48
generator: llm
status: llm-generated, NOT hand-verified -- generated draft, not documentation fact
model: Qwen3.8-9B-heretic-uncensored.i1-Q4_K_M.gguf
model_amos_id: OFSQC4I:QDBKEXY
model_endpoint: http://127.0.0.1:8000/v1/chat/completions [ ik_llama.cpp llama-server, local ]
prompt_version: src-review-v1
source_sha1: f6191cf422cf64b917f60a3a658a521b7bdbcce9
source_lines: 198
dep_graph_callers: 6
dep_graph_caveat: static literal calls only; conditional/dynamic dispatch invisible to the graph
usage_prompt_tokens: 2167
usage_completion_tokens: 744
---

# review: web.process_template_recursive

## Purpose
This module recursively processes template content containing nested commands, extracting and executing them in depth-first order while enforcing a maximum recursion depth to prevent infinite loops.

## Interface
**Input:** A hashref with keys `content` (template string), `meta` (hashref of variables), `depth` (current recursion level), `template_id`, and `session_id`.
**Output:** A hashref with `status` (success/error), `content` (processed template string), and optionally `depth`.

## Role & Dependencies
Serves as the recursive engine for template processing. It depends on `base.parser.pattern_split` for command extraction, `web.execute_template_command` for command execution, and `base.log` for logging. It is called by 6 other modules (static literal calls).

## Observations
- **Double-execution bug (Step 3 → Step 4):** In Step 3, `$cmd->{raw}` is replaced with the nested result. In Step 4, the same `$cmd->{raw}` is passed to `web.execute_template_command`. This means nested command results get executed again as top-level commands, likely causing incorrect behavior or infinite loops.
- **Substitution order issue (Step 5):** The final substitution loop replaces `<<COMMAND:...>>` placeholders with results. If a command result itself contains `<<COMMAND:...>>` markers, they won't be processed — only the outermost recursion handles them.
- **`format.log_singular` violations:** The code uses `qw| error |` and `qw| success |` (plural) when the checker expects singular forms.
- **`pattern_split` contract:** The code correctly handles the `pattern_split` returning an array of scalar refs, but this is a fragile dependency on an internal implementation detail.
- **No whitelist registration:** The module is not in the subroutine whitelist, which may cause runtime failures in strict AMOS7 deployments.

## Confidence
Unclear whether the double-execution in Step 3/4 is intentional (e.g., nested results should be re-parsed for new commands) or a bug. The recursion in Step 6 suggests re-parsing is expected, but the logic flow is ambiguous.

---

## deterministic check outputs [ verbatim ground truth ]

### module_convention_check

```
<!-- no violations found in 1 files [ max_line=78 max_descr=55 ] -->
```

### validate_module

```
Validation PASSED for 'web.process_template_recursive'

WARNINGS:
  ⚠ format.log_singular : 8 occurrences [ first at line 19 ]
  ⚠ module not found in subroutine whitelist
```

#,,,.,.,.,...,..,,..,,.,.,,..,..,,,..,,,,,,..,..,,...,...,..,,,..,,,.,,..,,.,,
#XXBT7YV3Q5W6WOYCCXNYJI2NRNF5B7WOMAPRISPYF7IBDS6FEIMGGH46M6774J4ZPD34I2J54V5IM
#\\\|4OOLYVBBTUHX27NKECYNWZPL43SBCHTYSVJ2MEDP6K6RWHUVZOL \ / AMOS7 \ YOURUM ::
#\[7]Z2YP5POGM6IWFFRXLGHWBUGIRQLQPXHKQNW2IRDIZXSP566CY4BQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
