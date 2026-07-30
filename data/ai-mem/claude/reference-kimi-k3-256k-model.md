---
name: reference-kimi-k3-256k-model
description: kimi-code/k3-256k model is configured and available for kimi_dispatch/kimi_continue but has never actually been used yet -- cheaper than full K3, no video_in, image_in still works
metadata:
  node_type: memory
  type: reference
  originSessionId: 8a65c64f-bcd4-43e6-9d47-e37ee5dc8750
  modified: 2026-07-31
---

`~/.kimi-code/config.toml` has a `[models."kimi-code/k3-256k"]` entry
already configured, alongside the default `kimi-code/k3`:

```
[models."kimi-code/k3"]
max_context_size = 1048576
capabilities = [ "thinking", "always_thinking", "image_in", "video_in", "tool_use" ]

[models."kimi-code/k3-256k"]
max_context_size = 262144
capabilities = [ "thinking", "always_thinking", "image_in", "tool_use" ]   ## no video_in ##
```

Same reasoning model, 1/4 the context (256k vs 1M), cheaper — no other
capability loss besides `video_in` (`image_in` still present).

**Not yet used in any real dispatch as of 2026-07-31**, despite being
configured. `bin/mcp-server-p7`'s `kimi_dispatch`/`kimi_continue` model
alias table (~line 3569) only maps the short names `k3`/`k2.7`/
`k2.7-fast` to their `kimi-code/*` targets — `k3-256k` has no short
alias. Unmapped model strings pass through verbatim (`// $args->{'model'}`
fallback), so it's usable *today* without any code change by passing the
full string: `kimi_dispatch(..., model: "kimi-code/k3-256k")`.

**How to apply**: default to `k3-256k` for single/few-file, well-scoped
dispatch tasks (bug fixes, small feature additions) where the task +
touched files clearly fit well under 256k tokens and no video input is
needed — both true of most task-file-driven dispatches seen so far.
Reserve full `k3` for tasks needing wide context (large multi-file
sweeps, long log/session analysis) or video input. If it proves out,
worth adding a proper `k3-256k` short alias to `mcp-server-p7` for
convenience.

#,,,,,.,,,,..,,,.,...,,,.,.,,,..,,,,.,..,,,..,.,.,...,...,...,,.,,...,.,,,,,,,
#5TA2UBPNJVWCWXZSXWDIQHKDLPO24MOIYE7QCO6TEMHYUTRCJVJF3CKL35CVQ2TL7ID6ZZENVAX7Y
#\\\|AKZ32344YL42AKJOOP4LXUOMSQIWET4BDI365QSFCXWZ5TBKW5W \ / AMOS7 \ YOURUM ::
#\[7]EBHU6MMYJRLMK576CQGV5BSO5BZU2ZS32XA7BUONZJD2PJWP6KCY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
