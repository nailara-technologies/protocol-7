
 .:[  lm-vision : add http backend via llama-server  ]:.

## Context

ik_llama.cpp commit `7978f0499` (Nov 2025) added vision support directly in
`llama-server` via the `/v1/chat/completions` endpoint with image data. The
Mar 2026 rebuild (version 4266, `344688ce5`) includes this plus Kimi 2.5 Vision
(#1280), Qwen3.5 vision (#1345), mmproj quantization (#1367), and reduced memory
for large images (#1349).

The `lm-vision` zenka currently uses `llama-mtmd-cli-cuda-fa` via `IPC::Open3`
(see `lm-vision.cmd.analyze_image:233`). This works well and was hard-won — it
should be kept as a fallback.

## Goal

Add an HTTP backend path to `lm-vision` that routes vision requests through the
already-running `llama-server-cuda-fa` instance (managed by the coding zenka),
using the same `/v1/chat/completions` endpoint with base64-encoded image data.

The CLI path becomes the fallback: used when the HTTP server is unavailable or
when explicitly requested.

## HTTP API Format

llama-server vision endpoint (OpenAI-compatible):

```
POST http://localhost:8000/v1/chat/completions
Content-Type: application/json

{
  "model": "...",
  "messages": [
    {
      "role": "user",
      "content": [
        { "type": "text", "text": "describe this image" },
        { "type": "image_url", "image_url": { "url": "data:image/jpeg;base64,..." } }
      ]
    }
  ],
  "max_tokens": 4096
}
```

Image must be base64-encoded. MIME type from file extension: jpeg/png/gif/webp.

## Design

### Backend Selection

```
lm-vision.cmd.analyze_image
  → check if coding zenka gpu server is ready
      [ <coding.inference_servers>->{'gpu'}->{'status'} eq 'ready' ]
  → if ready: route via http [ new: lm-vision.handler.http_analyze ]
  → if not:   route via cli  [ existing: IPC::Open3 path, unchanged ]
```

Config override to force CLI: `lm-vision.backend = cli`

### New Modules

```
modules/lm-vision.handler.http_analyze      ## encode image, POST, parse response
modules/lm-vision.handler.http_read_output  ## non-blocking result handling
```

### Existing Modules — Unchanged as CLI Path

```
modules/lm-vision.cmd.analyze_image         ## add backend selection at top
modules/lm-vision.handler.read_output       ## cli stdout watcher, keep as-is
modules/lm-vision.handler.check_completion  ## cli completion handler, keep
```

### Shared

```
modules/lm-vision.handler.check-completion-chain  ## already generic, reuse
modules/lm-vision.parser.process_chunk            ## already generic, reuse
```

## Key Notes

- `libmtmd.so` is now extracted alongside the server binary — vision models
  load correctly via http server without needing the CLI
- The coding zenka already manages server lifecycle (spawn, monitor, restart)
  so lm-vision http path gets server management for free
- mmproj path must be passed to the server at spawn time (coding zenka already
  does this via `coding.spawn_inference_server` `--mmproj` flag)
- The CLI binary (`llama-mtmd-cli-cuda-fa`) and its IPC::Open3 infrastructure
  should not be removed — it handles edge cases and was carefully debugged

## CLI Binary Status

```
/data/source/ik_llama.cpp/llama-mtmd-cli-cuda-fa   ## needs rebuild from new source
```

The CLI binary was not rebuilt in the Mar 2026 build session (only `llama-server`
was targeted). A separate build pass is needed if the CLI fallback is to be
kept current. Low priority since the http path is the new primary.

## Implementation Phases

1. Add `lm-vision.handler.http_analyze`: base64-encode image, POST to server,
   return response text [ blocking LWP first, refactor to non-blocking later ]
2. Add backend selection to `lm-vision.cmd.analyze_image`: check server status,
   dispatch to http or cli handler
3. Test with a vision model (Qwen3.5-9B or equivalent) via `lm-vision.analyze_image`
4. Verify CLI fallback still works when server is not running
5. [ optional ] Rebuild `llama-mtmd-cli-cuda-fa` from new source for parity

#,,,.,,,,,,..,.,,,.,,,,,.,,,.,,,.,,,,,.,.,,..,..,,...,...,.,.,,,.,.,,,,..,,.,,

#,,,.,..,,,,,,,,,,,.,,,..,.,,,..,,,..,..,,,,.,..,,...,...,.,,,...,,,,,,,.,..,,
#Y6CN275SHEFPFDOO7COA2KHCSJGNYZCOENTBUO3XRXZWTH6WCV73TCQJWHKM5TNHPKYI4WS4CSOYQ
#\\\|EX6P6XDTTYMLFCFNTBQS5HRQJDHH34OMVWUWC5DXUWGBOBTLQMP \ / AMOS7 \ YOURUM ::
#\[7]2ZNJBOHWV6Z5K763E6EZVKOYATKZYJQ7MPRCGC322XFOLMXQYOCY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
