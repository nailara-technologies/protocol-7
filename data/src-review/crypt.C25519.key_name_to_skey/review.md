---
module: crypt.C25519.key_name_to_skey
generated_at: 2026-09-09T23:43:59
generator: llm
status: llm-generated, NOT hand-verified -- generated draft, not documentation fact
model: Qwen3.8-9B-heretic-uncensored.i1-Q4_K_M.gguf
model_amos_id: OFSQC4I:QDBKEXY
model_endpoint: http://127.0.0.1:8000/v1/chat/completions [ ik_llama.cpp llama-server, local ]
prompt_version: src-review-v1
source_sha1: 0e99635a607f7b9d12d04193077556f336579e1e
source_lines: 41
dep_graph_callers: 6
dep_graph_caveat: static literal calls only; conditional/dynamic dispatch invisible to the graph
usage_prompt_tokens: 916
usage_completion_tokens: 630
---

# review: crypt.C25519.key_name_to_skey

## Purpose

This module converts a key name into a signature key name file suffix format. It uppercases the input, replaces dots with underscores, and validates the result against a regex pattern before returning the converted string.

## Interface

- **Input:** A single string parameter `$name` (default empty string)
- **Output:** Returns the converted uppercase string with dots replaced by underscores, or `undef` on validation failure

## Role & dependencies

The module is called by 6 other modules (per the dep-graph). It depends on `crypt.C25519.name_from_skey_name` for a reverse conversion check, creating a bidirectional validation relationship. The module is part of the `crypt.C25519` namespace, suggesting it belongs to a cryptographic key management subsystem.

## Observations

- **Placeholder regexes:** The regex patterns `<crypt.C25519.regex.signature_key_name>` and `<crypt.C25519.regex.key_name>` are clearly placeholder text that must be replaced with actual patterns. This is a critical fragility — the module will fail at runtime with these literal strings.
- **Coupling:** The reverse conversion check tightly couples this module to `name_from_skey_name`, creating a circular dependency risk if that module also depends on this one.
- **Style:** The `##` comments are non-standard Perl documentation style (likely AMOS7-specific). The `caller(0)` introspection for reverse conversion checks is fragile and may break under certain execution contexts.
- **Validation:** The module warns but does not throw exceptions, which may be intentional for the AMOS7 error-handling model.

## Confidence

Unclear what the actual regex patterns should be — the placeholders `<crypt.C25519.regex.signature_key_name>` and `<crypt.C25519.regex.key_name>` are not defined anywhere in the provided source. Unclear whether the reverse conversion check is intended to be a hard requirement or a soft validation hint.

---

## deterministic check outputs [ verbatim ground truth ]

### module_convention_check

```
<!-- no violations found in 1 files [ max_line=78 max_descr=55 ] -->
```

### validate_module

```
Validation PASSED for 'crypt.C25519.key_name_to_skey'
No issues found.
```

#,,.,,.,.,..,,,..,,.,,,,.,,.,,,..,.,.,,,.,.,,,..,,...,...,..,,..,,,.,,..,,.,,,
#WY4MGY5CEP74ALGLYIWO3FKENQLG5OAQPQCUC6HH5DGTVLLRX2RTGV4E77UQTM5D5PRC2PN3JO3QU
#\\\|DTBOPWXAA7YQ4ULN5GL3O56X3GWFVS42JAJ55XZ4V5MIPWLTOJP \ / AMOS7 \ YOURUM ::
#\[7]7ZSEQBDIMHOMLZJPIBAJUKBIYKO4YNDYCE3RAEXRGHTEW6XL4WCI 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
