---
module: base.validate.data_key_syntax
generated_at: 2026-09-09T22:42:39
generator: llm
status: llm-generated, NOT hand-verified -- generated draft, not documentation fact
model: Qwen3.8-9B-heretic-uncensored.i1-Q4_K_M.gguf
model_amos_id: OFSQC4I:QDBKEXY
model_endpoint: http://127.0.0.1:8000/v1/chat/completions [ ik_llama.cpp llama-server, local ]
prompt_version: src-review-v1
source_sha1: 99032d1c546db4c9eff4cc54a53b974af816ec61
source_lines: 67
dep_graph_callers: 13
dep_graph_caveat: static literal calls only; conditional/dynamic dispatch invisible to the graph
usage_prompt_tokens: 1098
usage_completion_tokens: 759
---

# review: base.validate.data_key_syntax

## Purpose
This module validates data key parameters, checking that the key name is non-empty, does not exceed 255 characters, contains only allowed characters, and properly handles quote and bracket syntax transformations.

## Interface
**Input:** A single string argument (the data key name), passed via `shift`.
**Output:** Returns `TRUE` on success, or `FALSE` with an optional error message string (when `wantarray` is true).

## Role & dependencies
This module is called by 13 other modules in the codebase. It has no external dependencies and is a pure validation utility. Notable internal patterns include use of `wantarray` for flexible return types and experimental Perl features like variable-width lookbehind.

## Observations
- **Critical bug:** `$MATCH` is referenced in error messages but never captured by any regex. The `=~ m|\.+$|` and `=~ $allowed_chars_regex` matches are not captured, so `$MATCH` is undefined. This will produce "Use of uninitialized value" warnings or empty error messages.
- **Fragile regex idiom:** The substitution `s,'(([^']|\.)+)', my $k=$1; $k=~s|\.|_|g; $k,ge;` is an unusual Perl idiom that embeds a regex substitution in the replacement string. This is brittle and hard to read.
- **Inconsistent quoting:** The `index` check uses `qw| . |` (space character) but the regex uses `.` (literal dot). These don't match.
- **Style:** The module uses `warn` instead of `die` or `croak` for validation failures, which may be intentional but is unusual for a validation module.
- **The `(*plb:(^|\.))` lookbehind** is experimental and may not work in all Perl versions.

## Confidence
I am confident about the `$MATCH` bug — it is a clear oversight where the regex match is not captured but the variable is used. The `index` vs regex mismatch is also clear. The `(*plb:)` syntax is a known Perl 5.10+ feature but its portability is unclear without knowing the target Perl version.

---

## deterministic check outputs [ verbatim ground truth ]

### module_convention_check

```
<!-- no violations found in 1 files [ max_line=78 max_descr=55 ] -->
```

### validate_module

```
Validation PASSED for 'base.validate.data_key_syntax'
No issues found.
```

#,,,.,,,.,,,,,,.,,,.,,,,,,.,,,..,,,.,,.,,,,,.,..,,...,...,,.,,.,,,.,,,.,,,.,,,
#FTZSC5P554QXRFJAIAITXHFU2U47MW7IQBC5CD7CF2HUHSOT3NZELQ4UTGL4OHDQNDO44BWYCHT2I
#\\\|6UNMZDIJGBNRR46UIGTN6RXRFSWQO5PUL4XCGDJUX77E4YQY5UQ \ / AMOS7 \ YOURUM ::
#\[7]EJWKCZNHAJ6EMTF363OEISCLXF3QKKPSXNNIRAXUYIISBEB2TGCQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
