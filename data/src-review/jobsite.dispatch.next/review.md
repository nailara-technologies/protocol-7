---
module: jobsite.dispatch.next
generated_at: 2026-09-09T23:06:41
generator: llm
status: llm-generated, NOT hand-verified -- generated draft, not documentation fact
model: Qwen3.8-9B-heretic-uncensored.i1-Q4_K_M.gguf
model_amos_id: OFSQC4I:QDBKEXY
model_endpoint: http://127.0.0.1:8000/v1/chat/completions [ ik_llama.cpp llama-server, local ]
prompt_version: src-review-v1
source_sha1: b4f875fd5a90a7d4c42e14709998344357382338
source_lines: 112
dep_graph_callers: 8
dep_graph_caveat: static literal calls only; conditional/dynamic dispatch invisible to the graph
usage_prompt_tokens: 1758
usage_completion_tokens: 896
---

# review: jobsite.dispatch.next

## Purpose
This module dispatches the next assessment task from a queue by extracting pending job entries, validating they haven't been superseded or terminated, encoding the description, and sending a `task.create` command via the protocol-7 routing layer. It also sets up a watchdog timer to detect lost replies from the task round trip.

## Interface
No explicit arguments or return value. It operates on global state (`jobsite.assess_queue`, `jobsite.tasks`, etc.) and logs messages via `<base.logs>`. The module is invoked as a subroutine call (evidenced by `<[jobsite.dispatch.consume_slot]>` and the dep-graph showing 8 callers).

## Role & dependencies
Called by 8 modules (static literal calls per dep-graph). Key dependencies: `<jobsite.assess_queue>` (queue source), `<jobsite.job.read>` (job state lookup), `<jobsite.tasks>` (task metadata), `<protocol-7.route-send>` (network dispatch), `<event.add_timer>` (watchdog), and `<jobsite.dispatch.consume_slot>` (queue slot management).

## Observations
- **Stale detection**: Two independent checks — terminal status (`trash|deleted|blocked`) and generation mismatch — either alone is fatal. This is robust.
- **Encoding**: `:B32:` prefix with `:no_tools:` prefix avoids tool use during encoding; base32 avoids protocol framing issues.
- **Watchdog**: Cancels old timers before setting a new one, preventing stale timers under hash key clobbering.
- **Warning**: Module not found in subroutine whitelist — may indicate it's not properly registered or is an internal utility.
- **Potential fragility**: `<jobsite.assess_queue> // []` assumes the queue accessor returns a hashref; if it returns `undef`, the default `[]` (arrayref) could cause type errors downstream.
- **Style**: The long comment block at the bottom (data signature) is unusual but appears intentional for protocol framing.

## Confidence
Unclear whether `<jobsite.assess_queue>` reliably returns a hashref or could return `undef` — the `// []` default may mask a deeper issue. Also unclear if the `// []` on line 4 is a typo (should perhaps be `// {}` if it's a hash-based queue).

---

## deterministic check outputs [ verbatim ground truth ]

### module_convention_check

```
<!-- no violations found in 1 files [ max_line=78 max_descr=55 ] -->
```

### validate_module

```
Validation PASSED for 'jobsite.dispatch.next'

WARNINGS:
  ⚠ module not found in subroutine whitelist
```

#,,.,,...,..,,...,,,,,,,.,,..,...,.,,,,.,,,,.,..,,...,...,..,,,.,,,,.,.,,,,.,,
#VXPYOTZDHCATF2JFAZWWWKX7YXPJ5J4W5CNDJJHS474NCSU4A45GT4OBSW4JBVA6QTZHTB4ZJOG5E
#\\\|N7LIHPNDA3WXWCVOEIMN66XLMD2WJJ5P3NDNHBOORY3OLTZV7KG \ / AMOS7 \ YOURUM ::
#\[7]J34PHJFNA33NOJBLKXH6QSDVZ6QK57RESFLO7RQMVTSWTW54Z2CQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
