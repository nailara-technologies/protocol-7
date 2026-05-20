---
name: fetch-files-zenka
description: fetch-files on-demand zenka — HuggingFace model downloads via huggingface.* namespace; LAN-first pattern; cmd wrappers live
metadata: 
  node_type: memory
  type: project
  originSessionId: cdd64615-ffac-4aad-8bb6-53bd6445a768
---

## Status: LIVE — commands working, on-demand startup pending (session 36)

Zenka starts cleanly: 74 subs, no errors, cube authorized, 33s on-demand timeout.
Commands listing aligned and correct. On-demand auto-start not yet wired.

## Namespace design — COMMITTED

`fetch.file.huggingface` renamed to `fetch.file.huggingface.download` (ncode rename).
`fetch.file.huggingface.pre_init` created with swap_subs:
```perl
<[base.swap_subs]>->( 'fetch.file.huggingface', 'huggingface' );
```
Result: `<[huggingface.download]>->()`, `<[huggingface.list]>->()` etc.
cmd wrappers already updated to call `<[huggingface.download]>->($args)` etc.
Available to any zenka that loads the `fetch.file` source namespace.

## Modules

Internal (`fetch.file.huggingface.*` → `huggingface.*` after swap):
- `huggingface` — download GGUF, huggingface-cli/wget fallback
- `huggingface.list` — HF API query for quantizations in a repo
- `huggingface.search` — search HF for GGUF models by query
- `huggingface.lan-check` — check LAN hosts before HF download
- `huggingface.status` — real-time download progress
- `huggingface.handler.download_progress/stderr/list_response/search_response`

Public commands (`fetch-files.cmd.*`):
- `hf-download`, `hf-list`, `hf-search`, `hf-lan-check`, `hf-status`
- Called as: `p7 fetch-files.hf-list '{"repo":"bartowski/gemma-3-4b-it-GGUF"}'`

## Key P7 patterns learned

- `$call` only implicitly available in `.cmd.*` and `.console.*` modules
  → Other modules need: `my $call = shift;` at top
- JSON decode: `JSON::PP::decode_json($str)` (not `base.json.decode`)
- Command naming: too many dots fails routing → use `zenka.cmd.short-name`
- `p7 fetch-files.hf-list` ✓ vs `p7 fetch.file.huggingface.list` ✗
- modules.load uses namespace prefix: `fetch.file` loads all `fetch.file.*`
- access.cmd.usr.cube: list short command names explicitly (or `*` during dev)
- fetch-files = 5-1-5 character symmetry → harmonically TRUE [:<

## Configuration

```
configuration/zenki/fetch-files/start
configuration/zenki/fetch-files/zenka-startup.v7  (on-demand, 33s timeout)
```

modules.load: `auth net protocol io.unix fetch.file fetch-files.cmd devmod`

## Tasks

- `data/tasks/hf-download-zenka.md` — full implementation spec (kimi pending)
- `data/tasks/sourcecode-recently-modified.md` — duration+filepath history command

**How to apply:** `p7 fetch-files.hf-search '{"query":"gemma 4b GGUF"}'` to find models,
`p7 fetch-files.hf-list '{"repo":"..."}` to see quantizations, then download with hf-download.
LAN check happens automatically before HF download.

#,,..,,.,,,.,,,.,,.,.,...,,.,,,,.,,,,,.,,,...,..,,...,...,,..,,,.,..,,.,,,,.,,
#VJORYXVMCYI3OJ54Z5SARMQVVI6Z463URADWTCHWKNNTIALU5CCZFI3ZKBSIUE4HHXQWB4SQ26XJW
#\\\|Y5BZZMBMBA72SLZUUZNQAUINMQS3L4DCKA66NWKRBJIZT6XZ3I5 \ / AMOS7 \ YOURUM ::
#\[7]HM3HNTGTPFWGWCCOUFRRHEBS4HT2RWTMNBCSEMJOTB5R6H7AUIAA 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
