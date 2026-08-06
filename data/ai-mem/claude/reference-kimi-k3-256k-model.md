---
name: reference-kimi-k3-256k-model
description: kimi-code/k3-256k -- confirmed ~2x cheaper quota-wise than full K3 within the 256k ceiling (forum-sourced, not just a feeling), no video_in, image_in still works
metadata:
  node_type: memory
  type: reference
  originSessionId: 8a65c64f-bcd4-43e6-9d47-e37ee5dc8750
  modified: 2026-08-06
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

**First real use, 2026-07-31**: `coding-task-append-backend-lock-leak-fix.md`
(committed `ea2406122`) — a single-file, well-scoped bug fix requiring a
deep call-chain trace across 8+ files plus live reload-and-reproduce
verification against the running coding zenka. Worked well, no signs of
context pressure or degraded reasoning vs full `k3` on comparable prior
tasks. No further data yet on where the 256k ceiling actually bites. `bin/mcp-server-p7`'s `kimi_dispatch`/`kimi_continue` model
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

**Second data point, larger task, 2026-08-04**: the `amos-term-
interaction-plugin.yaml` prototype dispatch (`bin/kimi-task`, ran on the
`kimi` zenka's default model, `kimi-code/k3`, per
[[project-kimi-k2.7-vs-k3-tier-economics]]'s real-API-name note) — new
plugin-type design decision resolved, 6 new modules written, 2 real bugs
found and fixed in `amos-term.buffer-create`/`buffer-write` (an SHM
`Sys::Mmap` detach bug and a header-offset bug affecting *all* SHM
consumers, not just this feature) — used **126k tokens total (12.1% context utilized at completion), roughly
half of `k3-256k`'s 262144 ceiling still unused** — for a real diff of
1000 lines added, 95 removed, across 34 files touched. This was a
substantially larger, more open-ended task than the single-file bug fix
above (new subsystem, live SHM debugging across process boundaries, a
genuine design decision to resolve), and it still fit comfortably under
`k3-256k`. Raises the bar on what "well-scoped enough for 256k" actually
covers — this class of multi-file prototype-plus-real-bug-hunting task
may not need full `k3`'s 1M context by default either; worth defaulting
to `k3-256k` more aggressively and only reaching for full `k3` when a
task is concretely expected to approach the 256k ceiling, not just
because it sounds large.

**Pricing confirmed, 2026-08-06** — no official published price for
`k3-256k` separately (only regular K3's $3/$15 per 1M in/out was found
anywhere), but a Kimi-user forum thread gives a direct data point: "k3-256k
is now available. Within 256k context, it delivers the same results. k3
(1M) consumes about **twice as much quota** as k3-256k." Matches the
already-observed dispatches here: this session's resumed task-archive
audit (74-file review, `840b069f`) cost only 5% session / 1% weekly
budget on `k3-256k`. Not a controlled A/B (no matched k3 run on the same
task), but consistent with the 2x figure and with the earlier low-cost
data points above.

Revises the "same reasoning model, just less context" framing above: the
video_in capability gap doesn't reduce to a context-ceiling parameter —
video tokenization needs its own encoder path, so dropping it implies a
genuinely different model config/checkpoint, not `k3` served with a
smaller context window. A forum poster's explanation fits better: likely a
separate model/serving tier for load-balancing and bimodal usage patterns
(most users stay well under 256k; a minority push to 1M), priced/
provisioned differently rather than being the same weights with a dial
turned down. Practical implication unchanged either way — default to
`k3-256k` unless a task concretely needs video input or is expected to
approach the 256k ceiling.

#,,..,,,.,,..,,,,,,..,.,.,,,,,.,.,.,.,...,...,.,.,...,...,.,.,...,,..,..,,.,,,
#566OHRIZTWYFFBX27ZQA3L7J5FENNZO7EU6QWIHH3D5LD3XO5VJ5RJ7RVCI2UQCPQJWI7VGCX6P6Q
#\\\|IRWYUEG7NDXPN5KR36ELVDX4NAUGFEE2ZFAXZL6WPB3VD35G3FG \ / AMOS7 \ YOURUM ::
#\[7]CNKDHOWGAFKTTU3SLNN4NG4XWL66IYX3Q3M2MF4RWWQKYCMF4KDA 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
