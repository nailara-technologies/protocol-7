---
module: base.parser.timestamp
generated_at: 2026-09-09T22:38:54
generator: llm
status: llm-generated, NOT hand-verified -- generated draft, not documentation fact
model: Qwen3.8-9B-heretic-uncensored.i1-Q4_K_M.gguf
model_amos_id: OFSQC4I:QDBKEXY
model_endpoint: http://127.0.0.1:8000/v1/chat/completions [ ik_llama.cpp llama-server, local ]
prompt_version: src-review-v1
source_sha1: 343cd1e701b517fceea4a318c6af8db258dcdc81
source_lines: 34
dep_graph_callers: 16
dep_graph_caveat: static literal calls only; conditional/dynamic dispatch invisible to the graph
usage_prompt_tokens: 886
usage_completion_tokens: 593
---

# review: base.parser.timestamp

## Purpose
This module parses a time or timestamp string (Unix epoch or ntime value) and formats it as a date, time, or combined timestamp string. It accepts numeric inputs (network time format) and converts them to human-readable output.

## Interface
- **Arguments**: `$mode` (default: `qw| time-stamp |`, accepts `time`, `time-stamp`, or `date`); `$time` (default: `<[base.time]>`, numeric epoch or ntime string)
- **Return**: A space-separated string of formatted date and/or time components

## Role & dependencies
Serves as a utility parser for time values across the codebase (16 modules call it statically). It depends on:
- `<[base.time]>` — default time value
- `<[base.n2u_time]>` — network time to Unix conversion
- `localtime` — Perl built-in for epoch conversion

## Observations
- **Fragility**: The numeric mode detection regex `m|^(\d+)(\.\d+)?$|` only accepts integers or decimals; fractional seconds are stripped. The ntime check `length( int($time) ) >= 13` is brittle — it assumes ntime values are always ≥13 digits, which may not hold for all implementations.
- **Coupling**: The module tightly couples to `<[base.n2u_time]>` for network time handling, making it less portable if that module changes.
- **Style**: The module uses AMOS7's custom syntax (`<[]>`, `qw| |`, `//` for defaults). The comment `##  <-- network time ?  ##` indicates uncertainty in the original author's intent.
- **Deterministic checks passed** — no convention or validation issues detected.

## Confidence
Unclear whether `<[base.time]>` is always a numeric value or could be a string requiring parsing. The `int($time)` call on a non-numeric string would silently produce `0`, potentially causing incorrect output without raising an error.

---

## deterministic check outputs [ verbatim ground truth ]

### module_convention_check

```
<!-- no violations found in 1 files [ max_line=78 max_descr=55 ] -->
```

### validate_module

```
Validation PASSED for 'base.parser.timestamp'
No issues found.
```

#,,.,,..,,,,.,.,,,,.,,,..,,,,,..,,.,.,.,,,,..,..,,...,...,.,.,,..,,,.,,.,,.,.,
#JUCHTPWQ75CPSJGOHIJMMAUUNWX5U2R4OX7DNGBGYZ47LFOFBQSEZPPIXKHWWPOV4A6NBROY3GHOE
#\\\|4FVEAXGCNDNXOYTUXBBE6K7VTOWE7X6MQRUPPYKWTBV53AQJRFT \ / AMOS7 \ YOURUM ::
#\[7]3BS2NPTVOUIH6BQLQW4BYYBGBRLMMI73HYWVIAG7HXHIUVLHGYBI 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
